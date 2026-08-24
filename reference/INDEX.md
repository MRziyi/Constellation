# `reference/` — third-party SDK & documentation index

This directory is a **local working area**, not part of the published repository.

Constellation is built against several vendor SDKs and their documentation. Those
materials are copyrighted by their respective owners and are **not redistributed
here**. This file records *what* we depend on and *where the authoritative source
is*, so anyone reproducing this work can fetch the same material themselves.

Everything under `reference/` except this file is `.gitignore`d.

## Hardware anchor

All glass-side work targets **Rokid Glasses** (the AR Lite eyewear):

| Property | Value |
|---|---|
| Display | JBD4020 micro-LED, 480×640 portrait, monochrome green, right eye |
| OS | YodaOS-Sprite (Android 12 Go), API 32 |
| SoC | Qualcomm 8250 + NXP RT600 DSP |
| Mic channel mask | `0x6000FC` (8-channel array with vendor front-end) |

> These are **not** the older Rokid Glass 1 / Glass 2 / Dock / AR Studio devices.
> Documentation for those products describes different hardware and does not apply.

## Sources we read

| Source | Where to get it |
|---|---|
| Rokid bare-metal (眼镜端裸机开发) docs | <https://developerdoc.rokid.com/sdk> |
| Rokid CXR-L SDK docs + Android/iOS samples | <https://developerdoc.rokid.com/sdk> |
| Rokid CXR-M SDK docs | Rokid business channel (not publicly published) |
| YodaOS-Sprite community notes | <https://github.com/buildwithfenna> |
| whisper.cpp | <https://github.com/ggml-org/whisper.cpp> |
| InsightFace (`buffalo_l`) | <https://github.com/deepinsight/insightface> |

## The one decision worth stating here

Constellation-Glass runs **bare-metal**: a plain Android app installed on the
glasses themselves, using stock `AudioRecord` / system key broadcasts / a
`SYSTEM_ALERT_WINDOW` overlay. It does **not** link the CXR-L AAR and does not
run as a phone-side bridge.

Rationale, and what that costs us, is in
[`docs/glass/GLASS-CLIENT-DESIGN.md`](../docs/glass/GLASS-CLIENT-DESIGN.md) and
[`docs/glass/GLASS-SDK-REFERENCE.md`](../docs/glass/GLASS-SDK-REFERENCE.md) — the
latter is the practical "what actually works on this device" layer written from
real on-device verification, and is the file to read before writing glass code.
