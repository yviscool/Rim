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

### 3.1 Global hotkeys (defaults)

| Hotkey | Action |
| --- | --- |
| `Win+J` / ``Win+` `` / `Win+Esc` / `Alt+Space` | Show/hide launcher |
| `Alt+E` | Open/switch to Total Commander |
| `Win+W` | Toggle the VimEditor integration |
| `Alt+H` | Center the active window |

### 3.2 Total Commander (`TTOTAL_CMD`, highlights)

Move: `h` parent dir, `j`/`k` up/down, `l` enter (super return), `a` select all; files: `c` new folder, `i` new file, `e` edit, `d` mark list, `o` context menu, `p` pack, `b` unpack, `u` close current tab; `zz`/`zh` 50/100% panel splits; `f2` rename, `f5` restart TC, `f9`/`f10` queued copy/move, `f11`/`f12` prev/next tab; `Shift+A–Z` a batch of `cm_` commands (view/search/sync/compare…); `Ctrl+letter` jumps (`Ctrl+T` open dir in new tab, `Ctrl+Q` command picker…). Full map: `Conf/rim.ini [TTOTAL_CMD]`.

### 3.3 Explorer (`CabinetWClass`)

`h` back, `l` Enter, `j`/`k` up/down, `t` switch focus with Tab, `f` throw the current folder to TC.

### 3.4 Notepad family (`Notepad` / `Notepad++`)

`i` insert mode, `Esc` back to normal; in normal mode `h/j/k/l` move, `w/b/e` word jumps, `0`/`Shift+4` line ends, `dd` delete line, `yy` yank line, `p` paste, `u` undo, `Ctrl+R` redo, `x` delete char, `a/o/I/A/O` insert variants, `v` visual mode, `/` search, `n/N` next/previous match.

Typora / Sublime / console sections exist as match-ready placeholders with no default keys yet — add your own.

Customize in the config UI, or as `key=<action>[=mode]` ini lines such as `dd=<deletedLine>[=normal]`. Action names come from the General plugin (arrows/window/tab/mouse actions) and per-app plugins.

## 4. Tray and Config Center

Right-click tray: show launcher, gesture manager, config center, StatsBall toggle, suspend, restart, quit. The config center edits launcher, hotkeys, plugin switches, TC, and Vim maps; `[Plugins]` toggles each plugin individually (18 active entries: MicrosoftExcel ships disabled pending a COM re-port; see `Conf/rim.template.ini`).

## 5. StatsBall

Floating desktop radar: CPU / memory / network speed, refreshed every second, alerts past a threshold; refresh interval, opacity, always-on-top, and position lock are adjustable. Toggle from the tray; turn it off if unwanted.

## 6. Language

`[Config] Language`: `auto` follows the system, `zh-CN` / `en` are fully maintained; Japanese/German/French/Spanish carry few entries and fall back to English.
