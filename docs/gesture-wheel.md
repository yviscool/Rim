# Wheel Gestures: Cycle Taskbar Windows / Adjust System Volume

[简体中文](gesture-wheel.zh-CN.md) · [Back to index](README.md) · [Project overview](../README.md)

Hold the gesture trigger (right mouse button by default) and scroll the wheel for two shortcuts. A short click of the trigger remains an ordinary click.

## 1. Hold R + wheel: cycle taskbar windows

| Action | Default |
| --- | --- |
| Hold R + scroll up | Previous taskbar window (`<SP_TaskPrev>`) |
| Hold R + scroll down | Next taskbar window (`<SP_TaskNext>`) |

Behavior:

- Windows are collected with taskbar semantics and cycled with wrap-around; **minimized windows are restored**, not just flashed on the taskbar.
- Scrolls within 1.5 s share one window list and step one window per notch; after a longer pause the list is rebuilt from the currently active window.
- The target window title is shown while switching (controlled by the gesture-tips switch).
- Releasing R ends the session without opening a context menu.

## 2. Hold R + click L + wheel: system volume

1. Hold R without releasing.
2. Click L once (the click is swallowed, never reaches the window below) and wait for the "Volume mode" tip.
3. Release L and scroll to adjust system volume, continuously if you like; scrolling while holding L works too.
4. Release R to leave volume mode. No stroke gesture fires and no context menu pops up.

Notes:

- If you click L but never scroll, the session falls back to the legacy logic (strokes resolve normally; `L`/`R` strokes plus L-click still switch windows).
- Holding still never triggers the hold-still auto-cancel (`CancelDelay`) during volume sessions, and the stroke trail/recognition tips stay out of the way.
- To disable it, set `[Gesture] VolLatch` to `0` (or turn off "Volume latch" in Gesture Manager → Settings); left clicks then pass through untouched.

## 3. Customization

Wheel gestures are ordinary bindings whose gesture names are `WheelUp` / `WheelDown` (with optional `CTRL+` / `ALT+` / `SHIFT+` prefixes). Edit them in `[Gestures]` or per-app layers:

```ini
[Gestures]
WheelUp=<SP_TaskPrev>
WheelDown=<SP_TaskNext>
CTRL+WheelUp=<SP_VolUp>
CTRL+WheelDown=<SP_VolDown>
```

The Gesture Manager edits the same bindings and applies them live. Action names: `<SP_TaskNext>`, `<SP_TaskPrev>`, `<SP_VolUp>`, `<SP_VolDown>`, `<SP_Mute>`.

Related `[Gesture]` switches:

| Key | Meaning |
| --- | --- |
| `ShowOSD` | Gesture tips (recognition results, wheel actions, volume mode popups); `0` silences them all |
| `VolLatch` | Volume-latch master switch, `0` disables it |
| `NoMatch` | On unrecognized strokes: `swallow` ignores the stroke / `passthrough` replays a click / `sound` beeps |
| `CancelDelay` | Cancel the gesture after holding still this many ms (volume/zoom sessions exempt), `0` disables |
| `Trigger` | Trigger button: `RButton` / `MButton` / `XButton1` / `XButton2` |

## 4. Troubleshooting

- **Wheel does nothing**: keep the trigger held; check `[GestureBlacklist]` and app layers with `noglobal=1` overriding the global binding; use practice mode in the Gesture Manager to see recognition results.
- **A window is skipped**: title-less windows, tray/desktop hosts, child dialogs, and DWM-cloaked windows are excluded from the cycle list.
- **Volume fights with strokes**: confirm `VolLatch=1`; if an app needs raw L-clicks inside R sessions (some games), set it to `0`.
