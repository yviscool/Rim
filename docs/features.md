# Features in Detail

[简体中文](features.zh-CN.md) · [Back to index](README.md) · [Wheel gestures](gesture-wheel.md)

This guide covers the default setup (`Conf/rim.ini` plus built-in plugins). Everything can be changed in the configuration UI or by editing the ini directly.

## 1. Launcher

Press `Win+J` (or ``Win+` ``, `Win+Esc`, `Alt+Space`) to show/hide. Type to search, Enter to run.

### 1.1 What can be found

- **File index**: files of type `SearchFileType` under `SearchFileDir` (`[Config]`), minus `SearchFileExclude` patterns. After changing the scope, press `Ctrl+R` in the launcher to rebuild the index.
- **[Commands] custom commands**: `name=type|content|description` with types `run` (programs), `url` (websites), `function` (internal functions). Defaults include `notepad`, `cmd`, plus `settings` (open config), `reload` (restart Rim), `exit` (quit); calculators, translators, and search are plugin commands (see 1.4).
- **Plugin commands**: the largest group, listed below.

### 1.2 Input box keys

| Key | Action |
| --- | --- |
| `Enter` | Run the selected item |
| `Up`/`Down`, `Ctrl+J`/`Ctrl+K` | Move selection |
| `Ctrl+F`/`Ctrl+B` | Page down/up in results |
| `Tab` / `→` | Accept ghost completion; `Ctrl+→` accepts one word |
| `Alt+↑`/`Alt+↓` | Search history by content (`↑↓` still move in the list) |
| `Space` | Result filter mode |
| `Alt+letter/number` | Run that row by first letter/position |
| `Ctrl+Enter` | Save current input as pipe argument |
| `Ctrl+H` | Show history |
| `Ctrl+N`/`Ctrl+P` | Raise/lower that command's weight (affects ranking) |
| `Ctrl+D` | Open the current file's folder in TC |
| `Ctrl+X` | Delete the current file |
| `Ctrl+S` | Show full path and copy it |
| `Ctrl+L`/`Ctrl+U` | Clear input |
| `Ctrl+I`/`Ctrl+O` | Cursor to line start/end |
| `Ctrl+R` / `Ctrl+Q` | Rebuild index / restart Rim |
| `F1` | Help; `Shift+F1` key help |
| `F2` / `F3` | Edit config / auto config |
| `Esc` | Clear input first, then close |

Input assists (`[SmartInput]`, all on by default):

- **Ghost completion**: grey suffix from history/candidates, `Tab` to accept.
- **History search**: `Alt+↑↓` filters history by what you typed.
- **Validation**: unknown command heads tint the input background (300 ms debounce).
- **Privacy**: inputs containing password/token/secret and similar words are never recorded; extend via `PrivacyExtra`.
- **Auto ranking**: `AutoRank=1` floats frequent commands up; `RunIfOnlyOne=1` runs a single result directly.

### 1.3 Command prefixes

| Prefix | Meaning | Example |
| --- | --- | --- |
| `;` | Run with AHK | `;MsgBox("hi")` |
| `:` | Run with CMD | `:dir` |
| `\|` | Pipe argument (use with `Ctrl+Enter` saved args) | save arg, then reference with `\|` |
| `@` | Jump | `@`-style commands |
| Bare URL | Open in browser | `github.com` |
| No match | Falls back to `[FallbackCommand]`: run via AHK / run via CMD / run via Win+R / run via CMD and show output / web search | offered as rows automatically |

### 1.4 Command cheat sheet

Type the name (parameters after a space for `{query}` commands):

| Group | Commands | Notes |
| --- | --- | --- |
| Search | `Google`, `Baidu`, `Bing`, `GitHub`, `Zhihu`, `Bilibili`, `Taobao`, `JD`, `Npm` | `Google xxx` searches xxx |
| Calc & translate | `Calc`, `Eval` | Evaluate expressions; `Translate`/`En2Cn`/`Cn2En`/`Dictionary` for words |
| Currency | `CNY2USD`, `USD2CNY`, `CurrencyRate` | Conversion and rates |
| Codec | `UrlEncode`, `UrlDecode` | URL encode/decode (input/clipboard) |
| Clipboard | `ClipShow`, `ClipClear`, `ClipSave`, `Clip` | View/clear/save clipboard |
| Date | `Date`, `Time`, `DateTime`, `Calendar` | Insert date/time, calendar |
| Color | `ColorPicker`, `ColorInfo` | Screen color picker |
| Network | `ShowIp`, `PubIp`, `Wifi`, `Dns`, `Ping`, `Env` | Local/public IP, WiFi, DNS, ping, env vars |
| System | `ShutdownMachine`, `RestartMachine`, `SuspendMachine`, `HibernateMachine`, `Logoff` | Power operations |
| System | `EmptyRecycle`, `ListProcess`, `KillProcess`, `ListWindow`, `ActivateWindow`, `DiskSpace`, `SystemState`, `IncreaseVolume`, `DecreaseVolume` | Recycle bin, process/window management, disk, system state, volume |
| Chinese conversion | `Kanji2S`/`T2S`, `Kanji2T`/`S2T` | Traditional/Simplified conversion |
| QR codes | `QRCode`, `QRText`, `QRClip`, `QRUrl` | Text/clipboard/URL to QR code |
| Launcher | `Help`, `KeyHelp`, `ReindexFiles`, `EditConfig`, `RunClipboard`, `ListPlugin` | Help, reindex, edit config, run clipboard, plugin list |

## 2. Mouse Gestures

Hold the right button and drag to draw; release to fire. **A quick click is still an ordinary right click**; `Esc` cancels mid-stroke. Names are built from directions (`U/D/L/R`, `UR/UL/DR/DL`, multi-stroke joined by `_`, e.g. `D_R`), plus single-letter shape templates (`G/P/N/S/M/Z/B/X`, …).

### 2.1 Common gestures (global defaults)

| Gesture | Action | Gesture | Action |
| --- | --- | --- | --- |
| `L` / `R` | Browser back/forward | `U` / `D` | Copy/paste |
| `UR` | Maximize | `DL` | Minimize |
| `UL` | Close window (Alt+F4) | `DR` | Close tab (Ctrl+W) |
| `U_D` | Refresh (F5) | `U_D_U` | Reload Rim |
| `D_R` | New tab | `D_L` | Close tab |
| `L_R` / `R_L` | Win+Left/Right snap | `R_D` | Open Chrome |
| `L_D` | Open Explorer | `L_U` | Back to top |
| `G` | Open Google | `P` / `N` | Play-pause / next track |
| `M` | Mute | `X` | Cut |
| `LETTER_U` / `LETTER_R` | Undo/redo | `Z` | Wheel-zoom combo |
| `WheelUp` / `WheelDown` | Switch taskbar windows | `Ctrl+Wheel` | System volume |

Wheel gestures have their own page ("hold R, click L for volume mode"): [Wheel gestures](gesture-wheel.md).

### 2.2 Per-app overrides

Same names do different things in specific apps (`[GestureApp:*]`), taking precedence over global:

- **Total Commander** (`TOTALCMD.EXE`): `D_R` new folder (F7), `D_L` delete (F8).
- **Browsers** (Chrome/Firefox/IE): `L`/`R` switch tabs, `U`/`D` line top/bottom, `U_D` reopen tab, `R_U` fullscreen, `B` bookmark, `H` home, `3` new tab, and more.
- **Desktop**: several diagonal gestures are swallowed to avoid accidents.

### 2.3 Management and settings

Tray → Gesture Manager: record new strokes, add shape samples, CRUD, blacklist, import/export, practice mode (shows recognition without executing). The Settings tab covers trigger button, distances, sampling, hold-still cancel, shape threshold, trail, and tip switches; saving applies live. Windows matching `[GestureBlacklist]` (e.g. game processes) bypass gestures entirely.

## 3. Vim-Style Keys

Keys are per-application (matched by process/class/title); each app section can set a multi-key timeout (`set_time_out`, 800 ms default). `h/j/k/l` and friends only take over inside configured apps.

Modes and switches (shared by all Vim windows): most windows have `normal` / `insert` states, `i` enters input, `Esc` returns to normal and passes `Esc` through; `?` pops a condensed key list inside the app (matching the tables below); numeric prefixes work on repeatable actions (e.g. `3j`); `Win+W` toggles takeover per window independently (immediate, no restart); adding `vim_enable=0` to a window section disables it persistently (survives restart).

### 3.1 Global hotkeys (defaults)

| Hotkey | Action |
| --- | --- |
| `Win+J` / ``Win+` `` / `Win+Esc` / `Alt+Space` | Show/hide launcher |
| `Alt+E` | Open/switch to Total Commander |
| `Win+W` | Toggle Vim takeover for the active window (immediate, no restart) |
| `Alt+H` | Center the active window |

### 3.2 Total Commander (`TTOTAL_CMD`, highlights)

Move: `h` parent dir, `j`/`k` up/down, `l` enter (super return), `a` select all; files: `c` new folder, `i` new file, `e` edit, `d` mark list, `o` context menu, `p` pack, `b` unpack, `u` close current tab; `zz`/`zh` 50/100% panel splits; `f2` rename, `f5` restart TC, `f9`/`f10` queued copy/move, `f11`/`f12` prev/next tab; `Shift+A–Z` a batch of `cm_` commands (view/search/sync/compare…); `Ctrl+letter` jumps (`Ctrl+T` open dir in new tab, `Ctrl+Q` command picker…). Full map: `Conf/rim.ini [TTOTAL_CMD]`.

### 3.3 Explorer (`CabinetWClass`)

`h` back, `l` Enter, `j`/`k` up/down, `t` switch focus with Tab, `f` throw the current folder to TC.

### 3.4 Notepad family (`Notepad` / `Notepad++`)

`i` insert mode, `Esc` back to normal; in normal mode `h/j/k/l` move, `w/b/e` word jumps, `0`/`Shift+4` line ends, `dd` delete line, `yy` yank line, `p` paste, `u` undo, `Ctrl+R` redo, `x` delete char, `a/o/I/A/O` insert variants, `v` visual mode, `/` search, `n/N` next/previous match.

Typora / console sections exist as match-ready placeholders with no default keys yet — add your own. To permanently disable takeover for a window, set `vim_enable=0` in its window section (survives restart, see above).

### 3.5 Browsers (Chrome / Edge / Firefox, `Browser` plugin)

Scroll: `j/k/h/l`, `d/u` half page, `Ctrl+D/U`, `Ctrl+F/B` full page, `gg/G` top/bottom, `0/$`; tabs: `t` new, `x` close, `X` reopen, `J/K` (`gn/gp` aliases) prev/next, `g1..g8`/`g0` jump; history: `H/L` back/forward, `r` reload, `R` hard reload; `o` address bar, `/` find, `n/N` next/previous match (auto-insert); `zi/zo/z0` zoom, `b` bookmark, `gh` history, `gd` downloads; `i/a` insert, `Esc` normal, `?` help. Starts in insert by default (`[Browser_*] default_mode`, changeable in the config center). `f` is deliberately unmapped and passed through, reserving it for Surfingkeys / Vimium-style link hints (they can coexist).

### 3.6 Excel (`XLMAIN`, `Excel` plugin, VimDesktop key layer replica, no COM)

Move: `h/j/k/l`, `H/J/K/L` extend selection, `gg/G` sheet start/end (`Ctrl+Home/End`), `0` first column, `$` region right edge, `gk/gj/gh/gl` (`sk/sj/sh/sl` aliases) region edges; pages: `Ctrl+D/U`, `Space/Shift+Space`; edit: `i` (sends F2 into the cell), `a` append at row end, `I` ribbon key tips; clipboard: `x` cut, `dd/D` clear, `yy/Y` copy, `yr/yc` copy entire row/column, `p` paste, `P` paste special, `yh/yl/yk/yj` copy from neighbor, `Fj/Fl` fill down/right (`Ctrl+D/R`); find: `/` find, `R` replace, `go` go-to (F5, auto-insert); sheets: `gt/gT` next/previous (`Ctrl+PgDn/PgUp`); `sr/sc/sa` select row/column/all; `or/oc/Or/Oc` insert rows/columns (Chinese-UI context-menu sequences); `ZZ` save and close, `ZQ` close only (answer the save dialog yourself, no silent COM discard). Safety: unmapped single characters are swallowed in normal mode (so nothing gets typed into cells); type with `i`; `u` undo, `Ctrl+R` redo. Deep-COM features (autofilter, colors, merge) are out of scope.

### 3.7 Everything (`EVERYTHING`, `Everything` plugin)

`j/k` move, `gg/G`/`0` first/last, `Enter` opens natively, `i` or `/` focuses the search box (auto-insert), `Esc` normal, `?` help. Everything passes through while the search/rename box is focused; unmapped letters in normal mode pass through as quick search, nothing is swallowed. Starts in insert by default (`[Everything] default_mode`, changeable in the config center).

### 3.8 PDF (SumatraPDF + Foxit, `Pdf` plugin)

SumatraPDF matched by class name; Foxit (volatile class names) matched by `FoxitReader.exe` / `FoxitPDFReader.exe` fallback. `j/k/h/l` scroll, `d/u` page (Space), `Ctrl+D/U` big page (PgDn/PgUp), `gg/G` start/end, `0/$`, `/` find (auto-insert), `n/N` next/previous match (F3), `zi/zo/z0` zoom (best-effort), `Esc` normal, `?` help.

Customize in the config UI, or as `key=<action>[=mode]` ini lines such as `dd=<deletedLine>[=normal]`. Action names come from the General plugin (arrows/window/tab/mouse actions) and per-app plugins.

Default mode: add `default_mode=insert` (or `normal`) to a window section and it starts in that mode, overriding plugin hardcoding (e.g. Everything/Browser insert defaults can be flipped back). The config center key tab has a "Default mode" dropdown following the window selection; `(follow default)` deletes the key (full revert needs a restart). Invalid values land in the restart bucket, never breaking startup.

## 4. Tray and Config Center

Right-click tray: show launcher, gesture manager, config center, StatsBall toggle, suspend, restart, quit. The config center edits launcher, radar, smart input, hotkeys, plugin switches, TC, and Vim maps; `[Plugins]` toggles each plugin individually (see `Conf/rim.template.ini`).

## 5. StatsBall

Floating desktop radar: CPU / memory / network speed, refreshed every second, alerts past a threshold; refresh interval, opacity, always-on-top, and position lock are adjustable. Toggle from the tray; turn it off if unwanted.

## 6. Language

`[Config] Language`: `auto` follows the system, `zh-CN` / `en` are fully maintained; Japanese/German/French/Spanish carry few entries and fall back to English.
