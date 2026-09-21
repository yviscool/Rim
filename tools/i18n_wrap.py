#!/usr/bin/env python3
"""一次性迁移工具: 把 RegisterAction/RegisterCommand/Host 描述参数包成 T("key").

只处理单行调用中含 CJK 的描述字面量:
    RegisterAction("name", "中文描述")            -> RegisterAction("name", T("act.<Plug>.<slug>"))
    [this.]RegisterAction('name', '...中文...')    -> 同上 (单引号/含引号内容均支持)
    RegisterCommand("n", "t", "c", "中文")        -> RegisterCommand("n", "t", "c", T("cmd.<Plug>.<slug>"))
    Host("RegisterCommand", "n", "t", "c", "中文") -> Host(..., T("cmd.<Plug>.<slug>"))

用法:
    python tools/i18n_wrap.py --dry-run                 # 只统计, 不写文件
    python tools/i18n_wrap.py --apply                   # 改写 Plugins/*.ahk + zh-CN 入库, 输出 mapping TSV
    python tools/i18n_wrap.py --import-en mapping_en.tsv  # key\\ten 导入 en.ini

key 命名: slug 取自动作/命令名 (去 <>/非法字符), 同插件内冲突加 _2; 同 (插件,文本) 复用同 key.
zh 值原样入库 Lang/zh-CN.ini; en 由人工按 mapping TSV 翻译后 --import-en 入库.
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGIN_DIR = ROOT / "Plugins"
ZH_PATH = ROOT / "Lang" / "zh-CN.ini"
EN_PATH = ROOT / "Lang" / "en.ini"

CJK_RE = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")

DQ = r'"((?:[^"]|"")*)"'
SQ = r"'([^']*)'"
STR = rf"(?:{DQ}|{SQ})"


def _unquote(q, body):
    if q == '"':
        return body.replace('""', '"')
    return body


def _str_text(m, q_idx, dq_idx, sq_idx):
    """取字符串字面量匹配组的去引号文本. q_idx=外层(whole), dq/sq=内层."""
    if m.group(dq_idx) is not None:
        return _unquote('"', m.group(dq_idx))
    return _unquote("'", m.group(sq_idx))


def _str_span(m, q_idx, dq_idx, sq_idx):
    return (m.start(q_idx), m.end(q_idx))


def find_desc_spans(line):
    """返回 [(start, end, kind, name, desc)] ; start/end 为描述字面量(含引号)区间."""
    out = []

    # this.RegisterAction("name", "desc") / ('name', 'desc')
    # groups: 1,2=name(DQ,SQ) 3=desc外层 4,5=desc内层(DQ,SQ)
    for m in re.finditer(rf"(?:this\.)?RegisterAction\(\s*{STR}\s*,\s*({DQ}|{SQ})\s*\)", line):
        text = _str_text(m, 3, 4, 5)
        if CJK_RE.search(text):
            out.append((_str_span(m, 3, 4, 5)[0], _str_span(m, 3, 4, 5)[1], "act",
                        _str_text(m, 1, 1, 2), text))
    # RegisterCommand("n","t","c","desc"): name=1,2 desc外层=7 内层=8,9
    for m in re.finditer(rf"RegisterCommand\(\s*{STR}\s*,\s*{STR}\s*,\s*{STR}\s*,\s*({DQ}|{SQ})\s*\)", line):
        text = _str_text(m, 7, 8, 9)
        if CJK_RE.search(text):
            out.append((m.start(7), m.end(7), "cmd", _str_text(m, 1, 1, 2), text))
    # Host("RegisterCommand","n","t","c","desc"): name=1,2 desc外层=7 内层=8,9
    for m in re.finditer(rf"Host\(\s*\"RegisterCommand\"\s*,\s*{STR}\s*,\s*{STR}\s*,\s*{STR}\s*,\s*({DQ}|{SQ})\s*\)", line):
        text = _str_text(m, 7, 8, 9)
        if CJK_RE.search(text):
            out.append((m.start(7), m.end(7), "cmd", _str_text(m, 1, 1, 2), text))
    # 去重叠 (一行多匹配时理论上不应重叠, 保守过滤)
    out.sort()
    filt = []
    for s, e, k, n, t in out:
        if filt and s < filt[-1][1]:
            continue
        filt.append((s, e, k, n, t))
    return filt


def slug(name):
    s = re.sub(r"[^A-Za-z0-9_]+", "_", name).strip("_")
    return s or "x"


def upsert_key(path, key, value):
    lines = path.read_text(encoding="utf-8-sig").splitlines() if path.exists() else []
    pat = re.compile(rf"^\s*{re.escape(key)}\s*=")
    in_strings, done, has_section = False, False, False
    out = []
    for raw in lines:
        s = raw.strip()
        if s.startswith("[") and s.endswith("]"):
            if in_strings and not done:
                out.append(f"{key}={value}")
                done = True
            in_strings = s[1:-1].strip() == "Strings"
            has_section = has_section or in_strings
            out.append(raw)
            continue
        if in_strings and pat.match(raw):
            out.append(f"{key}={value}")
            done = True
        else:
            out.append(raw)
    if not has_section:
        out += ["", "[Strings]", f"{key}={value}"]
    elif not done:
        out.append(f"{key}={value}")
    # 保持仓库 CRLF (ini)
    path.write_bytes(("\n".join(out) + "\n").replace("\n", "\r\n").encode("utf-8"))


def collect(dry_run=False):
    """扫描全部插件, 返回 rows [(file, line, key, kind, name, zh)]. dry_run 时不写文件."""
    rows = []
    key_by_pair = {}   # (plugin, zh) -> key
    used_keys = set()
    files = sorted(PLUGIN_DIR.glob("*.ahk"))
    for path in files:
        plugin = path.stem
        text = path.read_text(encoding="utf-8-sig")
        lines = text.splitlines()
        for i, ln in enumerate(lines, 1):
            for s, e, kind, name, zh in find_desc_spans(ln):
                pair = (plugin, zh)
                if pair in key_by_pair:
                    key = key_by_pair[pair]
                else:
                    base = slug(name)
                    prefix = "act." if kind == "act" else "cmd."
                    key = f"{prefix}{plugin}.{base}"
                    n = 2
                    while key in used_keys:
                        key = f"{prefix}{plugin}.{base}_{n}"
                        n += 1
                    key_by_pair[pair] = key
                    used_keys.add(key)
                rows.append((path.name, i, key, kind, name, zh))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description="Register* 描述批量 T() 化")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--import-en", dest="import_en", metavar="TSV")
    args = ap.parse_args(argv)

    if args.import_en:
        n = 0
        for raw in Path(args.import_en).read_text(encoding="utf-8-sig").splitlines():
            if not raw.strip() or raw.startswith("#"):
                continue
            key, _, en = raw.partition("\t")
            key, en = key.strip(), en.strip()
            if key and en:
                upsert_key(EN_PATH, key, en)
                n += 1
        print(f"imported {n} en keys")
        return 0

    rows = collect(dry_run=args.dry_run)
    kinds = {}
    for _, _, key, kind, _, _ in rows:
        kinds[kind] = kinds.get(kind, 0) + 1
    print(f"desc literals: {len(rows)} {kinds}, distinct keys: {len(set(r[2] for r in rows))}")

    if args.dry_run:
        return 0

    if not args.apply:
        print("加 --apply 才写文件 (先看 --dry-run 统计)")
        return 0

    # 按文件分组改写 (从后往前替换, 行列号稳定)
    by_file = {}
    for fname, ln, key, kind, name, zh in rows:
        by_file.setdefault(fname, []).append((ln, key))
    for fname, items in by_file.items():
        path = PLUGIN_DIR / fname
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        per_line = {}
        for ln, key in items:
            per_line.setdefault(ln, []).append(key)
        for ln, keys in per_line.items():
            idx = ln - 1
            spans = find_desc_spans(lines[idx])
            if len(spans) != len(keys):
                print(f"WARN skip {fname}:{ln} (spans {len(spans)} != keys {len(keys)})")
                continue
            new = lines[idx]
            for (s, e, _, _, _), key in sorted(zip(spans, keys), reverse=True):
                new = new[:s] + f'T("{key}")' + new[e:]
            lines[idx] = new
        eol = "\r\n" if b"\r\n" in path.read_bytes()[:8192] else "\n"
        data = eol.join(lines) + eol
        enc = "utf-8-sig" if path.read_bytes()[:3] == b"\xef\xbb\xbf" else "utf-8"
        path.write_text(data, encoding=enc)

    # zh 入库 + mapping TSV 输出 (stdout 重定向保存)
    seen = set()
    for _, _, key, _, _, zh in rows:
        if key not in seen:
            upsert_key(ZH_PATH, key, zh)
            seen.add(key)
    print(f"rewrote {len(by_file)} files, zh keys: {len(seen)}")
    print("# mapping TSV (key \\t kind \\t action \\t zh) below:")
    shown = set()
    for fname, ln, key, kind, name, zh in rows:
        if key in shown:
            continue
        shown.add(key)
        print(f"{key}\t{kind}\t{name}\t{zh}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
