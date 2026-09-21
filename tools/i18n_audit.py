#!/usr/bin/env python3
"""Rim i18n 审计脚本: 新增 / 改查 / 覆盖率 / 硬编码残留 / 占位一致性.

用法:
    python tools/i18n_audit.py [audit] [--format text|json] [--check] [--strict] [--include-plugins]
    python tools/i18n_audit.py stats
    python tools/i18n_audit.py query <key>
    python tools/i18n_audit.py scaffold <lang>        # 打印某语言缺的 key (复制去翻译)
    python tools/i18n_audit.py add <key> --zh <v> --en <v> [--ja <v> ...]
    python tools/i18n_audit.py set <lang> <key> <value>

约定 (见 Core/I18n.ahk):
    - 语言包 Lang/<bcp47>.ini, [Strings] 段, key=value, UTF-8, 转义 \\n \\t \\\\
    - 第一语言 zh-CN / en 全量; 其余占位, 缺键运行时回落英文
    - UI 文案一律走 T("key") / T("key", arg...), 占位符 {1} {2}...
    - g_WindowName ("RunZ    ") 是窗口匹配哨兵, 永不翻译

退出码: 0 通过; 1 --check 发现缺键/占位不一致(硬编码残留仅 --strict 才失败); 2 脚本错误.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANG_DIR = ROOT / "Lang"
CORE_LANGS = ("zh-CN", "en")

CJK_RE = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef]")
T_CALL_RE = re.compile(r"""\bT\(\s*(?:"((?:[^"]|"")*)"|'([^']*)')""")
PLACEHOLDER_RE = re.compile(r"\{(\d+)\}")

# 默认审计范围 (P0 已迁移完). Plugins/* 是 P2 (动作描述), 默认跳过, 加 --include-plugins 纳入.
DEFAULT_EXCLUDES = ("Backup/", ".git/", "debug_", "test_", "zz_")
PLUGIN_PREFIX = "Plugins/"


def parse_lang_file(path):
    """解析 Lang/*.ini 的 [Strings] 段. 返回 {key: (value, lineno)}."""
    out = {}
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError:
        return out
    in_strings = False
    for i, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_strings = line[1:-1].strip() == "Strings"
            continue
        if not in_strings or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        if k and k not in out:
            out[k] = (v.strip(), i)
    return out


def load_all_langs():
    langs = {}
    if LANG_DIR.is_dir():
        for p in sorted(LANG_DIR.glob("*.ini")):
            langs[p.stem] = parse_lang_file(p)
    return langs


def ahk_files(include_plugins=False):
    files = []
    for p in sorted(ROOT.rglob("*.ahk")):
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith(".git/") or rel.startswith("Backup/"):
            continue
        name = p.name
        if name.startswith(("debug_", "test_", "zz_")):
            continue
        if not include_plugins and rel.startswith(PLUGIN_PREFIX):
            continue
        files.append(p)
    return files


def strip_trailing_comment(line):
    """砍掉 AHK 行尾注释: 字符串外的、前面是空白(或行首)的 ; 起注释."""
    in_dq = in_sq = False
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if in_dq:
            if c == '"':
                if i + 1 < n and line[i + 1] == '"':
                    i += 2
                    continue
                in_dq = False
        elif in_sq:
            if c == "'":
                in_sq = False
        else:
            if c == '"':
                in_dq = True
            elif c == "'":
                in_sq = True
            elif c == ";" and (i == 0 or line[i - 1] in " \t"):
                return line[:i]
        i += 1
    return line


def string_spans(code):
    """返回代码行中字符串字面量的 (start, end, text) 列表. text 为去引号内容."""
    spans = []
    i, n = 0, len(code)
    while i < n:
        c = code[i]
        if c == '"':
            j = i + 1
            buf = []
            while j < n:
                if code[j] == '"':
                    if j + 1 < n and code[j + 1] == '"':
                        buf.append('"')
                        j += 2
                        continue
                    break
                buf.append(code[j])
                j += 1
            spans.append((i, min(j + 1, n), "".join(buf)))
            i = min(j + 1, n)
        elif c == "'":
            j = code.find("'", i + 1)
            if j == -1:
                break
            spans.append((i, j + 1, code[i + 1:j]))
            i = j + 1
        else:
            i += 1
    return spans


def scan_t_usage(files):
    """返回 (used: {key: [(file, line)]}, dynamic: [(file, line, text)])."""
    used = {}
    dynamic = []
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        try:
            lines = p.read_text(encoding="utf-8-sig").splitlines()
        except OSError:
            continue
        for ln, raw in enumerate(lines, 1):
            code = strip_trailing_comment(raw)
            if not code.strip():
                continue
            for m in T_CALL_RE.finditer(code):
                key = m.group(1) if m.group(1) is not None else m.group(2)
                key = key.replace('""', '"')
                if key:
                    used.setdefault(key, []).append((rel, ln))
            # T( 后面跟的不是引号: 变量/表达式 key, 审计跟不住, 单列提醒
            # (排除 T() 自己的函数定义行 `T(key, args*) {`)
            stripped = code.strip()
            if re.match(r"^T\s*\([^)]*\)\s*\{\s*$", stripped):
                continue
            for m in re.finditer(r"""\bT\(\s*(?![\"'\s])""", code):
                dynamic.append((rel, ln, code.strip()[:100]))
    return used, dynamic


def scan_hardcoded(files):
    """返回 [(file, line, text)] : 字符串字面量里残留 CJK, 且不是 T() 的 key 参数."""
    hits = []
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        try:
            lines = p.read_text(encoding="utf-8-sig").splitlines()
        except OSError:
            continue
        for ln, raw in enumerate(lines, 1):
            # 白名单: 语种自称必须用母语写 (I18nDisplayName), 窗口哨兵永不翻译
            if "names := Map(" in raw or "g_WindowName" in raw:
                continue
            code = strip_trailing_comment(raw)
            if not code.strip():
                continue
            t_key_spans = [(m.start(), m.end()) for m in T_CALL_RE.finditer(code)]
            for s, e, text in string_spans(code):
                if not CJK_RE.search(text):
                    continue
                # T("key") 自身的字面量不算硬编码
                if any(s >= ts and e <= te + 2 for ts, te in t_key_spans):
                    continue
                hits.append((rel, ln, text.strip()[:80]))
    return hits


def analyze(include_plugins=False):
    langs = load_all_langs()
    files = ahk_files(include_plugins)
    used, dynamic = scan_t_usage(files)
    hardcoded = scan_hardcoded(files)

    base = set(langs.get("en", {}))
    missing_in = {}   # lang -> [keys used but undefined]
    for lang, kv in langs.items():
        missing_in[lang] = sorted(k for k in used if k not in kv)
    undefined_core = sorted(k for k in used if k not in langs.get("zh-CN", {}) or k not in langs.get("en", {}))

    unused = {}       # lang -> [keys defined but never used]
    for lang, kv in langs.items():
        unused[lang] = sorted(k for k in kv if k not in used)

    ph_mismatch = []  # [(key, lang, base_ph, lang_ph)]
    en_ph = {k: sorted(set(PLACEHOLDER_RE.findall(v))) for k, (v, _) in langs.get("en", {}).items()}
    for lang, kv in langs.items():
        if lang == "en":
            continue
        for k, (v, _) in kv.items():
            if k in en_ph and sorted(set(PLACEHOLDER_RE.findall(v))) != en_ph[k]:
                ph_mismatch.append((k, lang, en_ph[k], sorted(set(PLACEHOLDER_RE.findall(v)))))

    coverage = {}
    for lang, kv in langs.items():
        keys = set(kv)
        coverage[lang] = {
            "keys": len(keys),
            "vs_en": round(len(keys & base) / len(base) * 100, 1) if base else 100.0,
            "used_covered": round(len(set(used) & keys) / len(used) * 100, 1) if used else 100.0,
        }

    return {
        "langs": sorted(langs),
        "used_keys": len(used),
        "missing_core": undefined_core,
        "missing_in": missing_in,
        "unused": unused,
        "placeholder_mismatch": ph_mismatch,
        "dynamic_keys": dynamic,
        "hardcoded": [(f, ln, t) for f, ln, t in hardcoded],
        "coverage": coverage,
        "used": {k: v for k, v in used.items()},
    }


def cmd_audit(args):
    rep = analyze(args.include_plugins)
    if args.format == "json":
        slim = {k: v for k, v in rep.items() if k != "used"}
        print(json.dumps(slim, ensure_ascii=False, indent=2))
    else:
        print(f"语言包: {', '.join(rep['langs'])}   T() 引用 key: {rep['used_keys']}")
        print("覆盖率 (vs en / 已用key覆盖):")
        for lang in rep["langs"]:
            c = rep["coverage"][lang]
            print(f"  {lang:8s} keys={c['keys']:4d}  vs_en={c['vs_en']:5.1f}%  used={c['used_covered']:5.1f}%")
        if rep["missing_core"]:
            print(f"\n[缺键-核心] T() 用了但 zh-CN/en 缺定义 ({len(rep['missing_core'])}):")
            for k in rep["missing_core"]:
                locs = ", ".join(f"{f}:{ln}" for f, ln in rep["used"][k][:3])
                print(f"  {k}   <- {locs}")
        else:
            print("\n[缺键-核心] 无 (zh-CN/en 全量覆盖)")
        others = [(l, ks) for l, ks in rep["missing_in"].items() if l not in CORE_LANGS and ks]
        if others:
            print(f"\n[缺键-占位语言] (运行时回落英文, 翻译后补, 共 {sum(len(ks) for _, ks in others)}):")
            for l, ks in others:
                print(f"  {l}: 缺 {len(ks)} 个, 例: {', '.join(ks[:5])}")
        if rep["placeholder_mismatch"]:
            print(f"\n[占位符不一致] ({len(rep['placeholder_mismatch'])}):")
            for k, lang, bp, lp in rep["placeholder_mismatch"]:
                print(f"  {k} [{lang}]: en={bp} vs {lang}={lp}")
        else:
            print("\n[占位符] 一致")
        if rep["dynamic_keys"]:
            print(f"\n[动态key] T() 首参非字面量, 审计跟不住 ({len(rep['dynamic_keys'])}):")
            for f, ln, t in rep["dynamic_keys"][:20]:
                print(f"  {f}:{ln}: {t}")
        if rep["hardcoded"]:
            scope = "全仓库(含 Plugins)" if args.include_plugins else "P0 范围 (Rim/Core/Gui/Lib; Plugins 用 --include-plugins 查)"
            print(f"\n[硬编码CJK残留] {scope} ({len(rep['hardcoded'])}):")
            for f, ln, t in rep["hardcoded"][:60]:
                print(f"  {f}:{ln}: {t}")
            if len(rep["hardcoded"]) > 60:
                print(f"  ... 另有 {len(rep['hardcoded']) - 60} 处 (json 格式看全量)")
        else:
            print("\n[硬编码CJK残留] 无")
        unused_core = [k for k in rep["unused"].get("en", []) if k in rep["unused"].get("zh-CN", [])]
        if unused_core:
            print(f"\n[疑似无用key] en+zh-CN 都有但无 T() 引用 ({len(unused_core)}): {', '.join(unused_core[:15])}")

    if args.check:
        fail = bool(rep["missing_core"] or rep["placeholder_mismatch"])
        if args.strict and rep["hardcoded"]:
            fail = True
        return 1 if fail else 0
    return 0


def cmd_stats(args):
    del args
    rep = analyze(True)
    print(f"T() 引用 key 总数: {rep['used_keys']}")
    for lang in rep["langs"]:
        c = rep["coverage"][lang]
        print(f"  {lang:8s} keys={c['keys']:4d} vs_en={c['vs_en']:5.1f}% used={c['used_covered']:5.1f}%")
    print(f"硬编码CJK残留(全仓库): {len(rep['hardcoded'])}")
    return 0


def cmd_query(args):
    rep = analyze(True)
    key = args.key
    print(f"key: {key}")
    langs = load_all_langs()
    for lang in sorted(langs):
        if key in langs[lang]:
            print(f"  [{lang}] {langs[lang][key][0]}")
        else:
            print(f"  [{lang}] (缺失 -> 回落英文)")
    locs = rep["used"].get(key, [])
    if locs:
        print(f"引用 ({len(locs)}):")
        for f, ln in locs:
            print(f"  {f}:{ln}")
    else:
        print("引用: 无 (新增 key 先确认真的被 T() 调用, 否则是死 key)")
    return 0


def cmd_scaffold(args):
    langs = load_all_langs()
    if "en" not in langs:
        print("缺少 Lang/en.ini", file=sys.stderr)
        return 2
    target = langs.get(args.lang, {})
    missing = [k for k in langs["en"] if k not in target]
    print(f"; {args.lang}: 缺 {len(missing)} 个 key (共 {len(langs['en'])}) — 翻译后追加到 [Strings] 段")
    for k in missing:
        print(f"{k}={langs['en'][k][0]}")
    return 0


def upsert_key(path, key, value):
    """key 存在则更新, 否则追加到 [Strings] 段 (没有该段则建)."""
    lines = []
    if path.exists():
        lines = path.read_text(encoding="utf-8-sig").splitlines()
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
        done = True
    if not done:
        out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def cmd_add(args):
    vals = {k: v for k, v in vars(args).items() if k not in ("cmd", "key") and v is not None}
    if "zh" not in vals or "en" not in vals:
        print("新增 key 必须同时给 --zh 和 --en (第一语言)", file=sys.stderr)
        return 2
    alias = {"zh": "zh-CN"}
    for short, val in vals.items():
        lang = alias.get(short, short)
        upsert_key(LANG_DIR / f"{lang}.ini", args.key, val)
        print(f"已写入 {lang}.ini: {args.key}")
    print("下一步: 在代码里用 T(\"" + args.key + "\") 引用, 再跑 audit 确认.")
    return 0


def cmd_set(args):
    upsert_key(LANG_DIR / f"{args.lang}.ini", args.key, args.value)
    print(f"已写入 {args.lang}.ini: {args.key}")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Rim i18n 审计: 新增/改查/覆盖率/残留扫描")
    sub = ap.add_subparsers(dest="cmd")
    a = sub.add_parser("audit", help="完整审计 (默认)")
    a.add_argument("--format", choices=("text", "json"), default="text")
    a.add_argument("--check", action="store_true", help="CI 模式: 缺键/占位不一致则退出 1")
    a.add_argument("--strict", action="store_true", help="连硬编码残留也视为失败 (需配合 --check)")
    a.add_argument("--include-plugins", action="store_true", help="把 Plugins/* 纳入残留扫描 (P2)")
    s = sub.add_parser("stats", help="覆盖率速览")
    q = sub.add_parser("query", help="查一个 key 的各语言值 + 引用位置")
    q.add_argument("key")
    sc = sub.add_parser("scaffold", help="打印某语言缺的 key (拿去翻译)")
    sc.add_argument("lang")
    ad = sub.add_parser("add", help="新增 key (--zh/--en 必填, 其余语言可选)")
    ad.add_argument("key")
    ad.add_argument("--zh"); ad.add_argument("--en"); ad.add_argument("--ja")
    ad.add_argument("--de"); ad.add_argument("--fr"); ad.add_argument("--es")
    st = sub.add_parser("set", help="改一个语言的 key 值")
    st.add_argument("lang"); st.add_argument("key"); st.add_argument("value")
    # 兼容无子命令: 直接 audit
    if argv is None:
        argv = sys.argv[1:]
    if not argv or argv[0].startswith("-"):
        args = ap.parse_args(["audit"] + argv)
    else:
        args = ap.parse_args(argv)
    handlers = {"audit": cmd_audit, "stats": cmd_stats, "query": cmd_query,
                "scaffold": cmd_scaffold, "add": cmd_add, "set": cmd_set}
    try:
        return handlers[args.cmd](args)
    except (OSError, UnicodeError) as e:
        print(f"错误: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
