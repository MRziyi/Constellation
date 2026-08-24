# Constellation · 星座

> *A constellation of senses, one mind.* — 「万象皆星，一念至此」

**English** · [简体中文](README.zh-CN.md)

Constellation is a personal AI framework for **all-day wearable assistance**. AR glasses
capture intent — voice, a camera frame, a button press — and hand it to an agent running
on a Mac at home. That agent decides what you meant, dispatches the work to the tools you
already use (Claude Code, Mail, Calendar, Reminders, Notes, the filesystem), and reports
back to a heads-up display on the glasses. Everything it learns about you lives in a
directory of Markdown files you can open in `vim`.

This repository is the **design hub**: the constitution, the architecture, and the specs.
The runtime lives in two sibling repositories.

> **What this is, honestly.** Constellation is a research prototype built for one person's
> daily use, not a product. It assumes a single user, a Mac at a fixed address, and a
> specific pair of AR glasses. Prompts and Twin paths are written for its author by name.
> It is published because the design decisions and the failure modes are worth reading —
> not because it will run out of the box for you. See [Known limitations](#known-limitations).

## The idea in one diagram

```
   Rokid Glasses                    Mac (always on)                  Your tools
 ┌────────────────┐            ┌──────────────────────┐         ┌──────────────────┐
 │ mic (push-to-  │  audio +   │  Cortex              │  RPC    │ Claude Code CLI  │
 │ talk, 15s cap) │  image     │  ├ Whisper STT       │────────▶│ Mail / Calendar  │
 │ camera         │───WSS─────▶│  ├ classifier        │         │ Reminders/Notes  │
 │ 480×640 HUD    │            │  ├ router / planner  │         │ iMessage/Safari  │
 │ touch + keys   │◀──cards────│  └ Claude Agent SDK  │◀────────│ filesystem       │
 └────────────────┘            └──────────┬───────────┘         └──────────────────┘
                                          │
                                  ┌───────▼────────┐
                                  │  Digital Twin  │  plain Markdown:
                                  │ ~/constellation│  identity · people · projects
                                  │     /twin/     │  memos · receipts · skills
                                  └────────────────┘
```

## The seven promises

The framework is defined by what it guarantees, not by any single use case. In short:

1. **One intent surface** — whatever device is on your body takes the intent; the brain is the same.
2. **The Twin is yours** — a Markdown library you can read, edit, and delete by hand.
3. **Supervised by default** — nothing with a side effect sends, posts, or deletes without your approval.
4. **Energy honesty** — the mic opens on a physical press with a hard cap. No wake word, no ambient listening.
5. **In-the-stack, not replacement** — Constellation drives the tools you already use.
6. **Bidirectional wake** — you can wake it, and a long-running tool can wake you.
7. **Framework over cases** — new capabilities arrive as adapters, not as forks.

The full statement, with the trade-offs each one costs, is in
[docs/constitution/DESIGN.md](docs/constitution/DESIGN.md).

## Repository map

| Repository | Contents |
|---|---|
| **[Constellation](https://github.com/MRziyi/Constellation)** (this) | Design constitution, architecture, wire contracts, roadmap |
| [Constellation-Server](https://github.com/MRziyi/Constellation-Server) | Cortex (the brain) + Tool Agent (the hands) + Twin seed — Python |
| [Constellation-Glass](https://github.com/MRziyi/Constellation-Glasses) | The eyewear client — Kotlin / Jetpack Compose, Android |

## Start here

| If you want to… | Read |
|---|---|
| Understand the framework | [docs/constitution/DESIGN.md](docs/constitution/DESIGN.md) — the master spec |
| See where every requirement came from | [docs/constitution/SOURCE-OF-TRUTH.md](docs/constitution/SOURCE-OF-TRUTH.md) — locked original intent + revision log |
| See what it looks like | [docs/assets/ui-mockup.html](docs/assets/ui-mockup.html) — open in a browser |
| Build against the wire protocol | [docs/server/INTERFACE-CONTRACTS.md](docs/server/INTERFACE-CONTRACTS.md) |
| Understand the agent runtime | [docs/server/AGENT-ARCHITECTURE-V2.md](docs/server/AGENT-ARCHITECTURE-V2.md) |
| Write glass-side code | [docs/glass/GLASS-SDK-REFERENCE.md](docs/glass/GLASS-SDK-REFERENCE.md) — what actually works on the device |

### Document index

**Constitution** — [`docs/constitution/`](docs/constitution/)
- [SOURCE-OF-TRUTH.md](docs/constitution/SOURCE-OF-TRUTH.md) — the original requirements, preserved verbatim, plus every revision that has amended them. Nothing in this project is allowed to silently contradict this file.
- [DESIGN.md](docs/constitution/DESIGN.md) — the master framework spec: seven promises, architecture, and the resolved design questions.
- [ARCHITECTURE-REFLECTION.md](docs/constitution/ARCHITECTURE-REFLECTION.md) — a retrospective on what the architecture got right and wrong.

**Server design** — [`docs/server/`](docs/server/)
- [AGENT-ARCHITECTURE-V2.md](docs/server/AGENT-ARCHITECTURE-V2.md) — the authoritative agent runtime: classifier, agent path, phase checkpoints. Read before the others.
- [COMPONENT-DESIGN.md](docs/server/COMPONENT-DESIGN.md) — Cortex / Tool Agent internals.
- [DATA-MODEL.md](docs/server/DATA-MODEL.md) — the Twin's Markdown data model, receipts, and context packing.
- [INTERFACE-CONTRACTS.md](docs/server/INTERFACE-CONTRACTS.md) — every wire schema (Glass↔Cortex, Cortex↔Tool, Twin, MCP).
- [TOOL-ADAPTERS.md](docs/server/TOOL-ADAPTERS.md) — the adapter catalog and each one's action surface.
- [PROMPT-DESIGN-V2.md](docs/server/PROMPT-DESIGN-V2.md) · [CORTEX-ROUTER-PROMPT.md](docs/server/CORTEX-ROUTER-PROMPT.md) — prompt architecture and two-pass Twin loading.
- [Q4.5-VISION-PASSTHROUGH.md](docs/server/Q4.5-VISION-PASSTHROUGH.md) — how a camera frame reaches a multimodal model without a lossy describe-to-text step.
- [MAIL-INBOUND-RULE.md](docs/server/MAIL-INBOUND-RULE.md) — inbound email → HUD card → dictated, threaded reply.
- [DEPLOYMENT-mac-mini-migration.md](docs/server/DEPLOYMENT-mac-mini-migration.md) — running the Mac side headless, including the macOS TCC permissions problem over SSH.

**Glass client design** — [`docs/glass/`](docs/glass/)
- [GLASS-CLIENT-DESIGN.md](docs/glass/GLASS-CLIENT-DESIGN.md) — the bare-metal Android client design (v2.1).
- [GLASS-SDK-REFERENCE.md](docs/glass/GLASS-SDK-REFERENCE.md) — audio, keys, display, foreground services, camera, QR: what the hardware actually does.
- [IN-APP-UI-DESIGN.md](docs/glass/IN-APP-UI-DESIGN.md) — the phone-app surfaces and QR pairing flow.
- [UI-UX.md](docs/glass/UI-UX.md) — HUD visual language, and why a 480×640 monochrome-green panel constrains it.
- [NETWORK-ALTERNATIVES.md](docs/glass/NETWORK-ALTERNATIVES.md) — every way we tried to get the glasses online, and which ones survived contact with reality.
- [PAIRING-AND-AUTH-RECOVERY.md](docs/glass/PAIRING-AND-AUTH-RECOVERY.md) · [P1.6-COMPOSE-MIGRATION.md](docs/glass/P1.6-COMPOSE-MIGRATION.md) · [P1.8-MEMORY-ENERGY-PROFILE.md](docs/glass/P1.8-MEMORY-ENERGY-PROFILE.md) · [MIGRATION-PLAN.md](docs/glass/MIGRATION-PLAN.md)

**Roadmap** — [`docs/roadmap/`](docs/roadmap/)
- [IMPLEMENTATION-PLAN.md](docs/roadmap/IMPLEMENTATION-PLAN.md) · [USE-CASE-AUDIT.md](docs/roadmap/USE-CASE-AUDIT.md) · [TOOL-IDEAS.md](docs/roadmap/TOOL-IDEAS.md)

**Cross-device** — [`docs/cross-device/`](docs/cross-device/)
- [halo-ring-plugin-protocol.md](docs/cross-device/halo-ring-plugin-protocol.md) — optional gesture input from a companion smart ring.

**Assets** — [`docs/assets/`](docs/assets/) (UI mockup) · [`docs/brand/`](docs/brand/) (logo)

## Hardware

| Piece | What we run on |
|---|---|
| Glasses | Rokid Glasses — JBD4020 monochrome-green micro-LED, 480×640 portrait, right eye; YodaOS-Sprite (Android 12 Go, API 32) |
| Brain | Any always-on Mac (Apple Silicon; Whisper and face recognition use CoreML) |
| Link | Public TLS relay, or Tailscale, or Bluetooth PAN via a phone hotspot |
| Ring (optional) | [Halo Ring](https://github.com/MRziyi/Halo-Ring) — adds gesture input; the system is voice-complete without it |

Third-party SDK documentation is **not** redistributed here. [reference/INDEX.md](reference/INDEX.md)
lists the authoritative sources and how to fetch them.

## Status

| Area | State |
|---|---|
| Design constitution | Stable; amended through the revision log in SOURCE-OF-TRUTH.md |
| Mac spine — Cortex + Tool Agent + Twin, launchd-managed | Working, in daily use |
| 13 tool adapters + supervised side effects | Working |
| Glass client — Compose HUD, in-app settings, QR pairing, camera | Working on real hardware |
| Local STT (whisper.cpp, two-tier) + on-device face recognition | Working |
| Claude Agent SDK in-process agent path | Working behind a flag; replacing the older tmux-driven path |
| Multi-device fan-out beyond glasses + ring | Designed, not built |

## Known limitations

Stated plainly, because the design docs argue for honest trade-offs:

- **Single-user by construction.** The author's name is baked into system prompts and Twin paths. Making this multi-tenant is a real refactor, not a config change.
- **Not privacy-hardened.** v1 explicitly traded privacy work for speed. Task content reaches cloud models. The Twin stays local, and face recognition is on-device — but do not treat this as a private-by-design system.
- **macOS-only tooling.** The adapters drive Mail, Calendar, Reminders, Notes, iMessage, and Safari through AppleScript and require macOS TCC grants.
- **Hardware-specific.** The glass client targets one device's quirks — its channel mask, its key broadcasts, its AppOps camera behaviour.
- **Some design documents are written in Chinese**, or mix Chinese and English. The constitution and the glass-side notes are the main ones.

## License

Licensed under the [Apache License 2.0](LICENSE).

Constellation is free and open source. If someone charged you for it, you were scammed.

---

*Where your senses go, your mind follows.*
