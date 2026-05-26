# Constellation · 星座

> *A constellation of senses, one mind.* / 「万象皆星，一念至此」
> by Zack 紫意 · companion to [Halo Ring](~/Code/Projects/R08-dev/)

A personal AI framework that lives on your Mac mini, takes intent from a constellation of
wearable sensors (AR glasses primary, Halo Ring + future devices), routes work through your
local Mac toolset (Claude Code + AppleScript + 10 more adapters), and is supervised at every
step. Your "self" lives in a markdown library (the Digital Twin) you can `vim`.

Complex intents auto-decompose into **multi-step tasks** that yield to you between steps;
each HUD card always opens the mic so you can speak any correction / skip / new info instead
of just tapping the default option.

## Where to start

If you're a human: open [DESIGN.md](DESIGN.md) (v0.8) for the framework + 7 promises, then
[Doc/ui-mockup.html](Doc/ui-mockup.html) in a browser for the visual feel.

If you're an AI agent picking this up after a context handoff: **open [HANDOFF.md](HANDOFF.md) first**, then follow the cold-start reading order there.

## Document index

### Constitution & framework
- [SOURCE-OF-TRUTH.md](SOURCE-OF-TRUTH.md) — Zack's locked intent. The constitution (incl. R-1/R-2/R-3 revisions).
- [DESIGN.md](DESIGN.md) v0.8 — master framework spec (7 promises + architecture + decisions Q-1~Q-9)
- [USE-CASE-AUDIT.md](USE-CASE-AUDIT.md) — pre-Phase-1 audit (3 use cases + 9 cool examples)
- [TOOL-IDEAS.md](TOOL-IDEAS.md) v0.2 — Zack-triaged roadmap of further adapter ideas

### Component-level designs
- [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) v0.3 — Cortex / Tool Agent / MCP internals (incl. multi-step state machine + reverse-wake event push + 12 live adapters)
- [DATA-MODEL.md](DATA-MODEL.md) v0.2 — Twin (markdown) data model + step receipts + eager-load context_pack
- [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) v0.6 — wire schemas (Glass↔Cortex, Cortex↔Tool, Twin, MCP) + always-mic
- [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) v0.2 — GPT-5.4 Router system prompt (multi-step + free-form feedback + HUD body design)
- [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) v0.2 — catalog of 12 live adapters (claude_code dual-track / 4 AppleScript / fs / apple_notes / system_status / apple_shortcuts / twin_query / imessage / safari_state / echo)
- [UI-UX.md](UI-UX.md) v0.3 — HUD design + always-on mic + multi-step visual treatment

### Glass client (Phase 3b — in progress)
- [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 — bare-metal Android Go app design (supersedes the older CXR-L bridge plan)
- [MIGRATION-PLAN.md](MIGRATION-PLAN.md) — v2.0 → v2.1 migration steps + verification checklist
- [reference/INDEX.md](reference/INDEX.md) — local mirror of Rokid + whisper + Halo Ring SDK source, plus curated bare-metal docs

### Cross-app integration
- [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) — protocol for Constellation to register actions with Halo Ring (Halo Ring side ✓ shipped; v2.1 makes it **optional**, not required)

### Roadmap & handoff
- [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) v0.3 — 10 phases (Phase 1+2+R-3 ✓ done; Phase 5 demoed early; Phase 3b in progress)
- [HANDOFF.md](HANDOFF.md) — for the next AI agent picking up the project

### Visual + brand
- [Doc/ui-mockup.html](Doc/ui-mockup.html) — visual ground truth (HUD + app surfaces)
- [Doc/brand/](Doc/brand/) — master SVG + brand README

### Seed content
- [twin-seed/](twin-seed/) — markdown files seeded to `~/constellation/twin/` on first run (incl. jane-doe + mike-chen people archives + reminder-style skill)

### Implementation (Phase 1 + 2 + R-3 done; Phase 3 next)
- [cortex/](cortex/) — Cortex Agent (Python asyncio service)
- [tool-agent/](tool-agent/) — Tool Agent (Python WebSocket server + 12 adapters)
- [test-harness/](test-harness/) — fake-Glass simulators (12 test scripts, all PASS)
- [scripts/](scripts/) — install scripts + launchd plists

## Status (2026-05-26)

| Phase | Status |
|---|---|
| Design (SoT through Revision 7 + GLASS-CLIENT-DESIGN v2.1) | ✓ green |
| Halo Ring plugin protocol | ✓ shipped (now optional companion per v2.1) |
| Phase 1 (Mac spine + launchd cycle) | ✓ verified end-to-end |
| Phase 2 (12 adapters + UC1 wall-clock + confirm-policies enforced) | ✓ verified end-to-end |
| **R-3 paradigm** (multi-step + always-mic + free-form feedback) | ⚠️ partially superseded by C-22 ripout (P1.1) + v2.1 mic-on-button-only (C-37) |
| Phase 5 UC2 reverse-wake | ✓ demoed early end-to-end |
| **Phase 3b Glass client** | 🟡 in progress — bare-metal pivot (v2.1) on branch `pivot/baremetal-v2.1` in `Constellation-Glass`; both `glass` + `phoneDebug` flavors build; protocol verified via phoneDebug; real-device deploy pending (P1.5) |
| Cortex Level 2 streaming partials | ✓ shipped |
| Phases 4 / 6 / 7 / 8 / 9 | ⏸ pending |

Detailed status: [HANDOFF.md §1](HANDOFF.md) + [TODO.md](TODO.md) + [SOURCE-OF-TRUTH.md Revision 7](SOURCE-OF-TRUTH.md).

## Project paths

| What | Where |
|---|---|
| This repo | `~/Code/Projects/Constellation/` |
| Twin (after seed) | `~/constellation/twin/` |
| Halo Ring (sibling project) | `~/Code/Projects/R08-dev/` |

## License / open-source

Constellation is **free & open-source** (planned). If you paid anyone for it, you were scammed.

*Where your senses go, your mind follows.*
