# Session record — 2026-05-29 (ring-takeover)

Quick read. Full detail in [HANDOFF.md](HANDOFF.md) + [SoT Rev 15/16](docs/constitution/SOURCE-OF-TRUTH.md).

---

## 1. What I did this session

The big pivot: **the Halo Ring is now the only input; the HUD is a ring-exclusive overlay.** Side-button / temple dropped.

| # | Done | Constraint | Commits |
|---|---|---|---|
| 1 | **R-14.b/c/d** — pin/unpin escapes TTL sweeper · mid-conf (0.4–0.7) confirmation card · cross-session `context_from` bleed | C-57/58/59 | Server `7fddd57` `6ca9569` `667a5a4` |
| 2 | **Ring-exclusive HUD overlay** — `OVERLAY_ACTIVATE`(+25s keepalive)/`DEACTIVATE` + `OVERLAY_GESTURE` forwarding; launcher gets nothing while HUD up | C-60 | Glass `3120c9b`→`9ce161b` |
| 3 | **2-port wake model + voice shortcut slots** — ring exposes only `voice_invoke` + `shortcut1/2/3` (3 fixed app-local slots, voice-edited via `shortcut_config`); `sendPhoto=true` dedups the R-13 pull | C-61 | Glass `9ce161b`; Server `31ca7d1` |
| 4 | **HUD no auto-dismiss** — cards/insights close only on a ring action; mic 15s cap kept (energy) | C-62 | Glass `49a65c2` |
| 5 | **Fixed 2 R-14 bugs** — context_from drop on mid-conf path; `(untitled)` session title | (Rev 15) | Server `84f9e54` `0861c8b` |
| 6 | **Cleanup/polish** — removed orphaned `/api/shortcuts` + store + Twin seed; HUD exit slides up; hid LeakCanary "Leaks" icon; mic only opens on modify | — | Glass `173ea44` `f9c5999`; Server `95ca6b4` `dc60a46` |
| 7 | **Docs** — SoT Rev 15/16 (C-57..C-62) + HANDOFF full refresh | — | Constellation `ddfcf84` `e1dd671` |

**All device-verified on Rokid Glasses `<glass-serial>`** (real ring gestures → HUD, launcher silent; voice shortcut config; fire-by-slot + photo dedup; no-TTL persistence).

Cross-device protocol designed with the Halo Ring agent: I wrote the REQ, they shipped a cleaner exclusive-overlay protocol — see [RESP-halo-ring-overlay-protocol-v1.md](docs/cross-device/RESP-halo-ring-overlay-protocol-v1.md).

---

## 2. Current state

- **SoT baseline: Revision 16** (C-57…C-62). The side-button parts of C-38/C-52/C-54 are superseded.
- **Repos (all committed, clean):**
  - Constellation `e1dd671` (`main`)
  - Constellation-Glass `173ea44` (`pivot/baremetal-v2.1`, not merged to main)
  - Constellation-Server `0861c8b` (`main`)
  - Constellation-Console `737819f` (untouched)
- **Running:** Cortex on Mac mini `<mac-host>:8888/:8890` (`CONSTELLATION_INSIGHT_ENGINE=1`) with the latest code; Tool agent; Linux Edge `edge.example.com`.
- **Hard rules now in effect:** ring-only input · Rokid Glasses only (phoneDebug retired) · BT-PAN only (don't `svc wifi enable`) · eyewear→server via public Edge.
- **Known gotcha:** to start the Glass service use the §6 gotcha-0 recipe (force-stop → `KEYCODE_WAKEUP` → cold-start MainActivity → HOME). `server_bound:false` ≈ display was asleep.

---

## 3. Roadmap (next TODOs, by value)

1. **🔋 P1.8 Phase β–δ — energy/memory quantification** *(recommended next)*
   - 1h idle baseline · 5-cycle leak (LeakCanary) · HUD attach-vs-detach heap delta · 24h BT-PAN drain.
   - Tooling already in (`scripts/glass-profile.sh`). **Unblocks C-57 pin-count cap** (currently unbounded — a wearer can pin every session) + §6.4 hotspot tightening (ML Kit lazy-load, Compose-tooling strip from release, b64 streaming).
   - Doc: [docs/glass/P1.8-MEMORY-ENERGY-PROFILE.md](docs/glass/P1.8-MEMORY-ENERGY-PROFILE.md).

2. **R-14.c "modify" true semantics** — the confirmation card's `modify` currently == `kill` (start new). v2: re-run the router excluding the rejected candidate, or accept a fresh voice utterance.

3. **Long-body scroll feel-tune** — trigger a card whose body exceeds `cardBodyMaxHeightDp = 240dp`, ring SWIPE, tune `cardScrollPxPerSwipe` (150f guess) for natural feel.

4. **Session-name surfacing on HUD** (OQ-R14-3) — should the wearer see which session they're in (status bar / card title)?

5. **P3.x architecture refactors** (deferred, multi-week) — P3.1 collapse Tool Agent into Cortex · P3.2 single-agent path · P3.3 MCP server. Re-read [ARCHITECTURE-REFLECTION.md](docs/constitution/ARCHITECTURE-REFLECTION.md) first.

**Smaller / optional:** R-14.d "modify"-band polish · in-app slot view niceties · per-flavor release build (verify Compose-tooling + LeakCanary stripped).
