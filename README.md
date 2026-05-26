# Constellation · 星座

> *A constellation of senses, one mind.* / 「万象皆星，一念至此」
> by Zack 紫意 · companion to [Halo Ring](~/Code/Projects/R08-dev/)

A personal AI framework that lives on your Mac mini, takes intent from a constellation of
wearable sensors (AR glasses primary, Halo Ring + future devices), routes work through your
local Mac toolset (Claude Code + AppleScript + 10 more adapters), and is supervised at every
step. Your "self" lives in a markdown library (the Digital Twin) you can `vim`.

Complex intents are handled by an agent path (Claude Code in tmux) with multi-phase
checkpoints; the user yields between phases. The Glass mic is energy-budgeted: it only
records on a physical button click (15s hard cap) — no wake word, no background listening.

## Where to start

If you're a human: open [DESIGN.md](docs/constitution/DESIGN.md) (v0.8) for the framework + 7 promises, then
[Doc/ui-mockup.html](Doc/ui-mockup.html) in a browser for the visual feel.

If you're an AI agent picking this up after a context handoff: **open [HANDOFF.md](HANDOFF.md) first**, then follow the cold-start reading order there.

Repo layout (post-2026-05-26 reorg): top-level entry points (`README.md`, `HANDOFF.md`, `TODO.md`) live at root; everything else is grouped under [docs/](docs/) by subsystem (`constitution/`, `server/`, `glass/`, `cross-device/`, `roadmap/`). Visual assets in [Doc/](Doc/); SDK reference material in [reference/](reference/).

## Document index

### Constitution & framework
- [SOURCE-OF-TRUTH.md](docs/constitution/SOURCE-OF-TRUTH.md) — Zack's locked intent. The constitution (incl. R-1/R-2/R-3 revisions).
- [DESIGN.md](docs/constitution/DESIGN.md) v0.8 — master framework spec (7 promises + architecture + decisions Q-1~Q-9)
- [USE-CASE-AUDIT.md](docs/roadmap/USE-CASE-AUDIT.md) — pre-Phase-1 audit (3 use cases + 9 cool examples)
- [TOOL-IDEAS.md](docs/roadmap/TOOL-IDEAS.md) v0.2 — Zack-triaged roadmap of further adapter ideas

### Server-side design (Cortex + Tool Agent + Twin)
- [AGENT-ARCHITECTURE-V2.md](docs/server/AGENT-ARCHITECTURE-V2.md) — current authoritative agent runtime (CC-in-tmux + multi-phase checkpoints). Read before any other server doc.
- [COMPONENT-DESIGN.md](docs/server/COMPONENT-DESIGN.md) — Cortex / Tool Agent / MCP internals + 12 live adapters. (§1 Router-as-planner is historical; see V2.)
- [DATA-MODEL.md](docs/server/DATA-MODEL.md) — Twin (markdown) data model + step receipts + context_pack.
- [INTERFACE-CONTRACTS.md](docs/server/INTERFACE-CONTRACTS.md) — wire schemas (Glass↔Cortex, Cortex↔Tool, Twin, MCP).
- [CORTEX-ROUTER-PROMPT.md](docs/server/CORTEX-ROUTER-PROMPT.md) — Router system prompt (single-round dispatch; multi-step lives in V2 agent path).
- [PROMPT-DESIGN-V2.md](docs/server/PROMPT-DESIGN-V2.md) — two-pass Twin loading (TOC → selective inline).
- [TOOL-ADAPTERS.md](docs/server/TOOL-ADAPTERS.md) — catalog of 12 live adapters (claude_code dual-track / 4 AppleScript / fs / apple_notes / system_status / apple_shortcuts / twin_query / imessage / safari_state / echo).

### Glass client (Phase 3b — in progress 🔥)
- [GLASS-CLIENT-DESIGN.md](docs/glass/GLASS-CLIENT-DESIGN.md) v2.1 — bare-metal Android Go app design (supersedes the older CXR-L bridge plan).
- [MIGRATION-PLAN.md](docs/glass/MIGRATION-PLAN.md) — v2.0 → v2.1 migration steps + verification checklist.
- [UI-UX.md](docs/glass/UI-UX.md) — HUD design + visual language (v2.1 annotations applied).
- [reference/INDEX.md](reference/INDEX.md) — local mirror of Rokid + whisper + Halo Ring SDK source, plus curated bare-metal docs.

### Cross-app integration
- [halo-ring-plugin-protocol.md](docs/cross-device/halo-ring-plugin-protocol.md) — protocol for Constellation to register actions with Halo Ring (Halo Ring side ✓ shipped; v2.1 makes it **optional**, not required).

### Visual + brand
- [Doc/ui-mockup.html](Doc/ui-mockup.html) — visual ground truth (HUD + app surfaces).
- [Doc/brand/](Doc/brand/) — master SVG + brand README.

### Implementation (lives in sibling repos)
This repo is design + docs only. Runtime code:
- `~/Code/Projects/Constellation-Server/cortex/` — Cortex Agent (Python asyncio).
- `~/Code/Projects/Constellation-Server/tool-agent/` — Tool Agent (Python WebSocket + 12 adapters).
- `~/Code/Projects/Constellation-Console/web/` — React HUD.
- `~/Code/Projects/Constellation-Console/edge/console_edge/` — FastAPI WSS proxy (DigitalOcean).
- `~/Code/Projects/Constellation-Glass/` — eyewear client (branch `pivot/baremetal-v2.1`).
- Twin seed + install scripts also live under `Constellation-Server/`.

## Status (2026-05-26)

| Phase | Status |
|---|---|
| Design (SoT through Revision 7 + GLASS-CLIENT-DESIGN v2.1) | ✓ green |
| Halo Ring plugin protocol | ✓ shipped (now optional companion per v2.1) |
| Phase 1 (Mac spine + launchd cycle) | ✓ verified end-to-end |
| Phase 2 (12 adapters + UC1 wall-clock + confirm-policies enforced) | ✓ verified end-to-end |
| **R-3 paradigm** (multi-step + always-mic + free-form feedback) | ⚠️ superseded — multi-step moved to V2 agent checkpoints; mic now physical-button-only (C-37) |
| Phase 5 UC2 reverse-wake | ✓ demoed early end-to-end |
| **Phase 3b Glass client** | 🟡 in progress — bare-metal pivot (v2.1) on branch `pivot/baremetal-v2.1` in `Constellation-Glass`; both `glass` + `phoneDebug` flavors build; protocol verified via phoneDebug; real-device deploy pending (P1.5) |
| Cortex Level 2 streaming partials | ✓ shipped |
| Phases 4 / 6 / 7 / 8 / 9 | ⏸ pending |

Detailed status: [HANDOFF.md §1](HANDOFF.md) + [TODO.md](TODO.md) + [SOURCE-OF-TRUTH.md Revision 7](docs/constitution/SOURCE-OF-TRUTH.md).

## Project paths

| What | Where |
|---|---|
| This repo | `~/Code/Projects/Constellation/` |
| Twin (after seed) | `~/constellation/twin/` |
| Halo Ring (sibling project) | `~/Code/Projects/R08-dev/` |

## License / open-source

Constellation is **free & open-source** (planned). If you paid anyone for it, you were scammed.

*Where your senses go, your mind follows.*
