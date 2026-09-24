# Unified Gesture Model

## Reference repositories

Local research clones are pinned to `StrokesPlus` `f7788b1`, `Stroke` `cc72a7a`, `OpenMouseGesture` `9fab0bc`, and `StrokesPlus.net_archive` `9e08323`. The first three separate recognition data from actions; the archive has no recognizer source.

## Rim configuration

```ini
[GestureDefinitions]
V=template
DR_UR=direction

[Gestures]
V=key|{F5}
DR_UR=key|{F5}

[GestureApp:Browsers]
set_file=chrome.exe|firefox.exe
V=key|^r
```

`GestureDefinitions` stores `direction`, `template`, or `auto`. Global and application sections store actions only. `[GestureTemplates]` stores points and no action string.

`U`, `R`, `D`, and `L` are reserved for straight direction gestures. Their letter shapes use `LETTER_U`, `LETTER_R`, `LETTER_D`, and `LETTER_L`. Shapes such as `V`, `B`, `Z`, `J`, and `3` keep their natural names.

## Recognition flow

1. Direction and template recognizers produce candidates.
2. Candidates are filtered by definition and disabled state.
3. Every candidate uses the same application/global action lookup.
4. The highest scoring bound candidate wins. Close template scores are rejected.
5. OSD and try mode show the top candidates and scores.

The manager now presents gesture samples, lets a new gesture choose direction, shape, or automatic recognition, keeps actions separate from samples, and supports appending or deleting samples while retaining at least one.

`tools/probe_gesture_unified.ahk` covers browser, music-player, global, `noglobal`, candidate selection, sample storage, deletion, and package export. Existing recognition, store, UI, relay, and parse probes pass locally.

This work is intentionally uncommitted. Manual testing is required before commit or push.
