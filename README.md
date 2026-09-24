<p align="center">
  <img src="Assets/RimLogo-256.png" alt="Rim logo" width="128" height="128">
</p>

<h1 align="center">Rim</h1>

<p align="center">A keyboard-driven Windows launcher, application-aware Vim-style controls, and mouse gestures in one AutoHotkey tool.</p>

<p align="center">
  <a href="docs/README.zh-CN.md">简体中文</a>
  ·
  <a href="LICENSE">MIT License</a>
</p>

[![i18n and smoke tests](https://github.com/yviscool/Rim/actions/workflows/i18n.yml/badge.svg?branch=main)](https://github.com/yviscool/Rim/actions/workflows/i18n.yml)

Rim combines three desktop workflows: a searchable command launcher, modal keyboard mappings that follow the active application, and configurable mouse-stroke gestures. It is written in AutoHotkey v2 and is distributed here as source code.

## Features

- **Launcher:** find and run indexed files, configured commands, and fallback actions. Search results can use saved history and ranking. The file index is built from configured search directories and file filters.
- **Application-aware keyboard controls:** define modes, key sequences, counts, and actions per window or process. Included mappings cover Windows Explorer, Total Commander, editors, and supported desktop applications.
- **Mouse gestures:** draw with the configured mouse button, map direction sequences or gesture templates to actions, and customize application-specific rules and exclusions.
- **Desktop monitor:** an optional floating radar displays CPU, memory, and network activity, with configurable refresh and alert settings.
- **Configuration UI:** manage launcher, hotkey, plugin, Total Commander, gesture, and related settings from the tray menu.
- **Built-in integrations:** launcher and system commands, Explorer navigation, Total Commander commands, Vim-style editing, media controls, QR-code utilities, text conversion, and integrations for selected third-party applications. Some actions require the corresponding application to be installed.
- **Localization:** English and Simplified Chinese are maintained as full UI languages. Japanese, German, French, and Spanish currently contain language labels and fall back to English for untranslated strings.

## Default Hotkeys

These global bindings come from the default `Conf/rim.ini`. They can be changed in the configuration UI or the `[GlobalHotkey]` section.

| Shortcut | Action |
| --- | --- |
| `Win+J` | Toggle the launcher |
| `Win+Backtick` | Toggle the launcher |
| `Win+Esc` | Toggle the launcher |
| `Alt+Space` | Toggle the launcher |
| `Alt+E` | Toggle Total Commander |
| `Win+W` | Toggle the VimEditor integration |

Vim-style keys such as `h`, `j`, `k`, and `l` are application-specific mappings, not global defaults. For example, the default configuration maps them for Explorer and Notepad. Right-button drag is the default gesture trigger; a short click remains an ordinary right click.

## Requirements

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/)

There is no installer or prebuilt release binary in this repository. The project is run from its checked-out source tree.

## Download

Prebuilt portable packages are published on the [Releases page](https://github.com/yviscool/Rim/releases): `*-portable.7z` / `*-portable.zip` (unzip and run `Rim.exe`), plus `*-source.zip` and `SHA256SUMS.txt`. `latest` points to the newest stable release; rolling `dev` prereleases track `main` automatically. 绿色便携包见 Releases 页，解压运行 `Rim.exe` 即可，首次运行请按自己机器填写 `Conf/rim.ini` 中的搜索目录与 TC 路径。

## Get Started

1. Install AutoHotkey v2 and clone this repository.

   ```powershell
   git clone https://github.com/yviscool/Rim.git
   cd Rim
   ```

2. Review `Conf/rim.ini` before the first launch. In particular, set `SearchFileDir`, `SearchFileType`, and `TCPath` for your machine. The checked-in defaults include developer-specific paths.

3. Review `CreateStartupLnk` and `CreateSendToLnk` in `[Config]`. Both are enabled in the sample configuration and control creation of Windows startup and Send To shortcuts. Set either to `0` to opt out.

4. Start the script:

   ```powershell
   & "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" .\Rim.ahk
   ```

   You can also launch `Rim.ahk` directly if `.ahk` files are associated with AutoHotkey v2.

5. Press `Win+J` to open the launcher. Right-click the Rim tray icon for the configuration center, gesture manager, monitor, and other commands.

## Configuration

- `Conf/rim.ini` stores launcher settings, global hotkeys, application mappings, gestures, plugins, and monitor options.
- `Conf/Skins/` contains launcher skins.
- The tray configuration center provides a UI for common settings. Changes that affect startup or low-level bindings may require a restart.
- Gesture definitions can be global or scoped to an application. The default trigger, thresholds, application rules, templates, and exclusions are in `Conf/rim.ini`.
- Language selection is under `[Config] Language`. Use `auto`, `en`, or `zh-CN` for the fully maintained languages.

## Project Layout

```text
Rim.ahk       Application entry point
Core/         Launcher, configuration, search, keyboard, gesture, and localization engines
Gui/          Configuration center and gesture management UI
Plugins/      Built-in commands and application integrations
Lib/          Shared libraries
Conf/         Main configuration and skins
Lang/         UI language files
Assets/       Application logo and Windows icon assets
docs/         Translated project documentation
tools/        Localization audit and smoke-test scripts
```

## Development and Checks

The CI workflow audits localization coverage and runs AutoHotkey parse and plugin-registration smoke tests on Windows. To run the same checks locally:

```powershell
python tools/i18n_audit.py audit --check
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tools/smoke_parse.ahk
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tools/smoke_register.ahk
```

To add an integration, place it in `Plugins/`, register its actions or commands using the existing plugin patterns, and include it from `Rim.ahk`. Keep UI strings in `Lang/en.ini` and `Lang/zh-CN.ini`; run the localization audit after changing translated strings.

## Documentation

- [Documentation index](docs/README.md)
- [简体中文文档](docs/README.zh-CN.md)
- [License](LICENSE)

## Credits

- [RunZ](https://github.com/goreliu/runz) for launcher design and implementation foundations.
- [VimDesktop](https://github.com/goreliu/vimdesktop) for modal keyboard controls and the Total Commander mapping heritage.
- [StrokesPlus](https://roblarky.github.io/) for inspiration for mouse gestures.

## License

Rim is licensed under the [MIT License](LICENSE).
