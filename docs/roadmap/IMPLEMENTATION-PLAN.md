# Constellation — Implementation Plan

**Version**: v0.6
**Status**: Phase 1 ✓ + Phase 2 ✓ + R-3 ✓ + Phase 3a Web Console ✓ + **Phase 5 v2 ✅ landed** + **Twin v2 ✅ landed** + **Auto-distiller wired** + **P0-P2 sweep ✅ landed 2026-05-26** (long-lived CC reuse, R-3 ripout, Insight Engine skeleton, per-session cost rollup, session archive filter). Active next: P1.3 Glass for the real glasses + P2.x leftovers + P3 architecture refactors (deferred multi-week). **Read [ARCHITECTURE-REFLECTION.md](../constitution/ARCHITECTURE-REFLECTION.md) before any refactor.**
**关联文档**: **[ARCHITECTURE-REFLECTION.md](../constitution/ARCHITECTURE-REFLECTION.md)** · [DESIGN.md](../constitution/DESIGN.md) · [HANDOFF.md](../../HANDOFF.md) · [TODO.md](../../TODO.md) · [AGENT-ARCHITECTURE-V2.md](../server/AGENT-ARCHITECTURE-V2.md) · [SOURCE-OF-TRUTH.md](../constitution/SOURCE-OF-TRUTH.md) · [INTERFACE-CONTRACTS.md](../server/INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](../server/COMPONENT-DESIGN.md) · [DATA-MODEL.md](../server/DATA-MODEL.md) · [UI-UX.md](../glass/UI-UX.md) · [CORTEX-ROUTER-PROMPT.md](../server/CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](../server/TOOL-ADAPTERS.md) · [TOOL-IDEAS.md](TOOL-IDEAS.md) · [halo-ring-plugin-protocol.md](../cross-device/halo-ring-plugin-protocol.md) · [Doc/ui-mockup.html](../../Doc/ui-mockup.html)
**Last updated**: 2026-05-26 (post P0-P2 sweep)

---

## 1. Approach

**10 phases**, ordered by dependency. Per Zack's direction:
- **Mac-side first**, test entirely with a `curl`-based fake-Glass simulator
- **Then rooted Android phone** as the development client (cheaper iteration than full Glass deploy)
- **Then Rokid Glass deployment** when phone client is stable

Critical path: **Phase 0 → 1 → 2 → 3 → 4 → 5 → 7 → 9**. Phases 6 (UC3) and 8 (MCP) are parallel-able with 5/7.

Each phase has: scope, deliverables, dependencies, success criteria, deferred items, time estimate.

### Status at 2026-05-25 (Phase 5 v2 architecture, mid-flight)

| Phase | Status | Notes |
|---|---|---|
| 0 — Prereqs | ✓ done | OpenAI key; CC CLI 2.1.133; Twin seeded; Tailscale ✓ on Mac + Linux; edge.example.com DNS + LE cert |
| 1 — Mac spine | ✓ done | full_loop.py 4× PASS; launchd cycle verified |
| 2 — Mac UC1 + Slice A/B/C | ✓ done | 12 adapters; UC1 wall-clock 5/5 PASS mean 3.9s; confirm-policies enforced |
| 2.5 — R-3 multi-step | ✓ done | (deprecated by Phase 5 v2 — CC owns multi-step now) |
| 3a — Web Console | ✓ done 2026-05-25 | https://edge.example.com/; cookie auth; 9 routes; full workflow test PASS |
| **5 (v2 pivot)** — CC-as-agent + streaming + multi-phase checkpoints | **✅ landed 2026-05-25** | per [AGENT-ARCHITECTURE-V2.md](../server/AGENT-ARCHITECTURE-V2.md). Streaming agent (TUI tmux + jsonl tail, $0 marginal cost), glanceable progress + thinking heartbeat, v2.6 brief (YOU MUST + self-check + phase pattern), actions[] preview + executor SEND, **multi-phase checkpoint pattern** (CC emits {phase_done, next} → Cortex blocking ⏸ card → user Continue/Adjust/Cancel → `agent_continue` resumes CC in same tmux). Verified e2e: `actions_e2e.py` PASS, `multi_phase_e2e.py` PASS (1 checkpoint + 1 final, 28s, 11 progress events). |
| **5c** — Auto-routing classifier ahead of planner | **✅ landed 2026-05-25** | `cortex.classifier` emits `{complex: bool, why: str}` in 1 LLM call (gpt-5.2 today, swap to haiku once Anthropic key added). On `complex=true` → shared `CortexServer._dispatch_complex_agent` (brief + Twin selector + tmux dispatch). On `complex=false` → existing v0.5 selector+planner+executor. Fails-closed to complex on any error. Verified: `"battery?"` → v0.5 path; `"look at my last Kao email and propose a reply"` → agent path + tmux live. |
| **5g** — Prune `AVAILABLE_TOOLS` catalog | **✅ landed 2026-05-25** | 11 tools / 50+ actions → **10 tools / 11 actions** all bounded single-call. |
| **5 P0-P2** — Long-lived CC + cost rollup + R-3 ripout + Insight skeleton | **✅ landed 2026-05-26** | P0.1 tmux reuse across turns in same HUD session via `agent_continue` (47.7% wallclock savings on follow-up). P0.3 per-session LLM cost/latency telemetry via ContextVar. P1.1 deleted multi-step machinery (`_advance_task`, `task_history`, etc.) — single-shot `_replan_with_feedback` replaces it. P1.4 Insight Engine skeleton with starter `upcoming_reminders_provider`. P2.1+P2.6 session archive filter + HUD search. See [TODO.md](../../TODO.md) for the per-item ledger. |
| 3b — Android-native client | ⏸ | deferred; inherits Phase 5 protocol shape |
| 4 — Rokid Glass deploy | ⏸ | post-3b |
| 6 — UC3 face | ⏸ | parallelisable |
| **7a** — Insight Engine cron skeleton | **✅ landed 2026-05-26 (default OFF)** | `cortex.insight_engine`. Periodic loop + provider registry + dedup + hud_show surface. Enable via `CONSTELLATION_INSIGHT_ENGINE=1`. Phase 7b is the *actual* implicit-learning loop (distiller — already wired 2026-05-26). |
| 8 — MCP server | ⏸ | parallelisable; ~3 days |
| 9 — Dogfood + cool-ex stress | ⏸ | final |

**The single biggest delta vs prior status table**: Phase 5 is no longer "UC2
reverse-wake demoed early" — it has expanded into the full v2 architecture
pivot. The reverse-wake demo from Phase 2 closing day is *part* of Phase 5
infra but only a slice; the meat is the streaming agent path. See
[AGENT-ARCHITECTURE-V2.md](../server/AGENT-ARCHITECTURE-V2.md) for what's actually
in Phase 5, and [TODO.md](../../TODO.md) for what's actually open.

---

## 2. Critical-path overview

```
Phase 0 ──► Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 7 ──► Phase 9
  prereqs   Mac-spine    Mac UC1    Android-     Rokid       UC2          insight     dogfood
  (curl)    (curl)       (curl)     phone        Glass       reverse-     +
                                    client       deploy      wake         learning

                                                          ┌► Phase 6 (UC3 face) ──┐
                                                          │                        │
                                                          └► Phase 8 (MCP)  ──────►┘
                                                             (parallel from Phase 5)
```

---

## 3. Phases

### Phase 0 — Prerequisites

**Scope**: software stack ready; API keys obtained; Tailscale on Mac mini; **no hardware blocking** (per Zack: hardware doesn't matter for design completion).

**Deliverables**:
- Mac mini Tailscale installed and accessible
- OpenAI API key obtained → for Cortex Router (GPT)
- Anthropic API key + Claude Code CLI installed locally → Tool Agent will spawn it
- Twin seed copied to `~/constellation/twin/`:
  ```bash
  mkdir -p ~/constellation && cp -r ~/Code/Projects/Constellation/twin-seed ~/constellation/twin
  ```
- Python 3.11+ + venv for `cortex/`, `tool-agent/`, `mcp-server/`
- Android Studio + adb working (for Phase 3 onward; can defer until Phase 3 start)
- Push notification service decided ([Q-7](../constitution/DESIGN.md)) — but **not required for Phase 1/2** (Mac-only, curl-tested)

**Success criteria**:
- `curl http://mac-mini.tailnet-name.ts.net:PORT/health` returns OK after Cortex starts (Phase 1)
- `claude --version` works on Mac mini
- Twin seed present at `~/constellation/twin/`; `tree` shows all 13 seed files

**Deferred**:
- Glass hardware (not blocking; we use Android phone first)
- Halo Ring plugin protocol on Halo Ring's side — was a Phase 0 prereq, **now ✓ done** (Halo Ring agent shipped). Not blocking.
- FCM / Rokid push setup — Phase 3 only

**Estimated time**: 0.5–1 day (mostly waiting for API key delivery if not already have)

---

### Phase 1 — Mac-side spine (curl-tested, no client)

**Scope**: end-to-end wire on Mac, tested via `curl`. No Android, no Glass. Just Cortex + Tool Agent + Twin scaffold + a basic test harness.

**Deliverables**:
- **`cortex/`** (Python asyncio service, launchd plist):
  - Event Bus with `evt_*` id allocation
  - WebSocket server listening for clients (curl will POST `user_invoke` to a `/test/invoke` endpoint that injects into Event Bus)
  - WebSocket client/server for Tool Agent IPC over localhost
  - **Stub Router**: returns hard-coded `{primary_intent: "echo", subtasks: [{tool: "echo", action: "echo", args: {text: payload.text}}], hud_response: {kind: "preview_action", title: "Echo", body_template: "{{subtasks[0].result.echo}}", options: ["SEND", "FEEDBACK"]}, reasoning: "stub"}`
  - Preview/Confirm Orchestrator (basic; ttl handling)
  - Receipt Writer appending to `receipts/{today}.md`
  - Twin Reader/Writer (read only at this phase; just `fs.read` style)
  - CHANGELOG appender
- **`tool-agent/`** (Python asyncio service, launchd plist):
  - WebSocket server on `localhost:PORT_TA`
  - Tool Registry loading `adapters.yaml`
  - Dummy `echo` tool adapter: just returns `{echo: args.text}`
  - Adapter base class per [TOOL-ADAPTERS.md §contract](../server/TOOL-ADAPTERS.md)
- **`test-harness/`**: shell script + Python utility that:
  - POSTs a fake `user_invoke` to Cortex
  - Reads Cortex's pending command queue via WebSocket
  - Posts a fake `user_decision` (SEND or FEEDBACK)
  - Asserts a receipt was written to Twin
- **`cortex/launchd/`** + **`tool-agent/launchd/`** plists + one-line installer script

**Success criteria**:
- `python test-harness/full_loop.py` exits 0
- Twin `~/constellation/twin/receipts/{today}.md` has one entry
- `~/constellation/twin/CHANGELOG.md` has one append entry
- Process model: both daemons survive a `launchctl stop && launchctl start` cycle

**Depends on**: Phase 0

**Deferred**: real LLM, real tools, Glass client, push, MCP, Insight Engine

**Estimated time**: ~5 days

---

### Phase 2 — Mac-side UC1 demo (curl-tested, real Cortex)

**Scope**: replace Phase 1's stubs with the **real** Cortex Router + the **three** tool adapters needed for UC1. Still no Glass; still curl-driven.

**Deliverables**:
- **Real Cortex Router**: using [CORTEX-ROUTER-PROMPT.md](../server/CORTEX-ROUTER-PROMPT.md) — system prompt + user prompt template + 2–3 hand-picked few-shots. GPT API call (gpt-4o-mini for speed, or gpt-4o for quality — A/B in this phase).
- **Tool Adapters** per [TOOL-ADAPTERS.md](../server/TOOL-ADAPTERS.md):
  - `claude_code` adapter — tmux session model per [COMPONENT-DESIGN §2.5](../server/COMPONENT-DESIGN.md). Actions: `run`, `draft`, `get_status`, `send_keys`, `kill`. Uses [twin-seed/skills/claude-code-control.md](../../../Constellation-Server/twin-seed/skills/claude-code-control.md) for regex patterns.
  - `applescript_mail` adapter — actions: `read_current`, `list_inbox`, `draft`, `send`, `get_thread`
  - `applescript_reminders` adapter — actions: `add`, `list`, `complete`, `delete`
- **Feedback Loop** ([INTERFACE-CONTRACTS §1.5](../server/INTERFACE-CONTRACTS.md)): test-harness can POST a `user_decision { feedback }` with feedback_text; Cortex re-prompts Router with the iteration context; v2 preview comes back
- **Confirm policy enforcement**: Cortex reads `~/constellation/twin/skills/confirm-policies.md` and applies per-subtask
- **Receipt chain**: receipts capture `evt → cmd → rpc_*[]` link
- **Hand-seed people archives**: add `~/constellation/twin/people/core/jane-doe.md` (test contact) and 1–2 others by hand so context_pack has substance

**Success criteria** (curl-tested):
- Test: POST `user_invoke {text: "reply to Jane, see you at 3, casual"}` (no image since we're testing Mac-side)
- Within 6 s: receive `preview_action` with a casual draft in Zack's style
- Test 1: POST `user_decision { SEND }` → Mail.app sends + reminder added + receipt has full chain
- Test 2: POST `user_decision { FEEDBACK, feedback_text: "shorter" }` → re-prompt → new v2 preview → POST `SEND` → done
- End-to-end wall-clock for happy path: **< 10 s** from `user_invoke` to email out
- 5 consecutive test runs all green

**Depends on**: Phase 1

**Deferred**: Glass client, push wake, face recognition, Insight Engine

**Estimated time**: 1–2 weeks

---

### Phase 3a — Web Console (✓ done 2026-05-25)

**Scope**: a public-domain SPA (`edge.example.com`) that doubles as (a) interim
Glass client (full HUD/WSS protocol so Phase 3b inherits a battle-tested wire) and
(b) the permanent **control plane** — richer than the eyewear could ever be (live CC
panes, twin browser, prompt inspector, trace stream, push notifications).

**Deliverables** (in [Constellation-Console.git](https://github.com/MRziyi/Constellation-Console)):

- `cortex/` (in [Constellation-Server](https://github.com/MRziyi/Constellation-Server)) gains
  `:8890` HTTP management surface: `control_plane.py` rings + `http.py` (16 routes:
  cc/sessions, cc/pane, cc/send_keys, cc/kill, twin/{tree,read,write}, receipts,
  changelog, tasks/active, events, dispatches, llm/calls{/id}, llm/stats, adapters,
  system/status, test/invoke, trace/stream SSE). All LLM calls flow through
  `llm_cache.set_call_observer(plane.record_llm_call)` for prompt inspector.
- `edge/` FastAPI on Linux (`edge.example.com:9100` behind nginx + Caddy-issued LE
  TLS): cookie auth + brute-force lockout + REST/SSE proxy + WSS relay + Web Push
  (pywebpush) + systemd service `console-edge.service`.
- `web/` Vite + React 19 + TS + Tailwind v4 SPA with 9 routes: HUD (default; WSS
  Glass client, text + photo composer, preview cards, multi-step inline), Claude Code
  (master-detail + live tmux pane 1.5s poll + send_keys + kill), Live Trace (SSE
  pub-sub), Active Tasks, Twin (file tree + md viewer + edit-save), Receipts (date
  picker + md render), LLM Calls (prompt inspector — system + user prompts + raw
  response), System (Mac tiles + push enable + LLM cost/cache), Adapters.
- PWA: manifest.json (scope:/, start_url:/hud, display:standalone) + apple meta tags
  + 4 icons + service worker (registers eagerly; handles push events + click-to-focus).
- Web Push: VAPID generated on Linux; edge has SSE consumer task that fires push on
  `tool_reverse_wake` events so AFK user gets phone notification when CC needs perms.

**Success criteria** (verified 2026-05-25 via end-to-end workflow test through public
domain):
- Auth: cookie flow, 401 without cookie, 200 with ✓
- AUTO policy paradigm: `reminders.add` → Router emits hud_show, real reminder added ✓
- PREVIEW policy paradigm: `fs.write` → preview_action; file empty pre-SEND; written
  post-SEND with exact content ✓
- FEEDBACK iteration: preview v1 → free-form "write X instead" → re-route → v2 preview
  reflects correction → SEND v2 → file matches v2 not v1 ✓
- All 9 REST + SSE endpoints reflect activity in real time ✓
- PWA assets (manifest, sw, icons) served with correct content-types ✓
- Tool Agent stays localhost-only (verified ConnectionRefused from Linux) ✓

**Deferred to 3a polish** (not blocking 3b):
- iOS PWA test on actual phone (user verification pending)
- Web Push reverse-wake end-to-end (mechanically works; awaits a real CC permission trigger)
- Per-event/cmd_id linkage in dispatch + llm_call rings (currently null)

**Depends on**: Phase 2 (12 adapters); Tailscale on Mac + Linux

**Estimated effort**: 1 day actual (2 days estimate)

---

### Phase 3b — Android-phone client (rooted, debug surface)

> ⚠️ **Partially superseded by v2.1 (Revision 7, 2026-05-26).** The
> always-on-mic / VAD-stop requirement (C-22) was replaced by physical-key
> mic (single-click → 15s hard cap, C-37) for energy reasons. Multi-step
> rendering moved to V2 agent checkpoints. Original phone-debug effort
> was reframed: a `phoneDebug` Gradle productFlavor now lives alongside
> the bare-metal `glass` flavor in the same `Constellation-Glass` repo.
> **Current truth: [docs/glass/GLASS-CLIENT-DESIGN.md](../glass/GLASS-CLIENT-DESIGN.md) v2.1 +
> [docs/glass/MIGRATION-PLAN.md](../glass/MIGRATION-PLAN.md).** Read those before
> acting on anything below; the section is preserved for archaeological
> context only.

**Scope** (historical): build the Glass client on a **rooted Android phone first** (per Zack's preferred workflow). Same code path, easier iteration. Deploy to Rokid Glass in Phase 4. **Inherits the WSS Glass protocol proven by Phase 3a** — same `user_invoke` / `Command` / `user_decision` shapes; smaller delta from web client to Kotlin client.

**Deliverables**:
- **`glass-android/`** (Android Studio module, Kotlin + Jetpack Compose):
  - Foreground service (`ConstellationService`) running an overlay `WindowManager` view
  - HUD overlay Composable rendering all atoms ([UI-UX §3](../glass/UI-UX.md)): status pill (4 variants) + card (variants by content)
  - Manifest declarations for Halo Ring plugin protocol ([halo-ring-plugin-protocol.md](../cross-device/halo-ring-plugin-protocol.md)):
    - `<meta-data android:name="halo.ring.plugin_version" android:value="1" />`
    - `HaloActionsProvider` ContentProvider (returns `voice_invoke` + `shortcut_*` actions from `~/constellation/twin/skills/shortcuts.md` — managed via the app-internal Shortcuts editor)
    - `HaloTriggerReceiver` BroadcastReceiver
  - Hybrid transport ([INTERFACE-CONTRACTS §1.6](../server/INTERFACE-CONTRACTS.md)): WSS over Tailscale during active; push notification listener during idle (FCM stub OK on phone — Rokid push for Phase 4)
  - Mic + photo capture pipeline (Android `CameraX` + on-device STT — start with Android `SpeechRecognizer`; Whisper.cpp port later if needed)
  - App-internal screens per [Doc/ui-mockup.html §2](../../Doc/ui-mockup.html): Main / Shortcuts list / Shortcut editor / Connect to Cortex / About
  - **Profile push/pop** to Halo Ring on HUD open/close (per [halo-ring-plugin-protocol §6](../cross-device/halo-ring-plugin-protocol.md))

**Success criteria**:
- Phone gesture (long-press temple touch or rooted-Android button-mapped trigger): triggers Voice Invoke → photo + mic → sends `user_invoke` to Mac mini Cortex (via Tailscale)
- Within 6 s: HUD card appears on phone screen showing UC1 email preview
- Tap option (or button-mapped): sends `user_decision`; full UC1 flow completes
- **Every HUD card auto-opens the mic with VAD-stop** (SoT C-22 hard requirement); speech becomes `user_decision { decision: "feedback", feedback_text: "<STT>" }`; ring-tap default option emits `user_decision { decision: "send" }`. Both channels operate in parallel for every card
- **Multi-step task flows render naturally**: a sequence of preview_action cards, user can SEND ring-tap or speak free-form between rounds (see [UI-UX.md §3.4-3.6](../glass/UI-UX.md))
- Settings: edit a shortcut's preset prompt → Halo Ring's Action Picker (on the same phone) sees the updated description
- Stability: 1-hour wear test, no crashes, battery drain reasonable

**Hard prereqs added in v0.3** (always-mic point superseded — see banner above):
- Tailscale installed on Mac mini; Cortex launched with `--host <tailnet-IP>` for phone access (currently binds 127.0.0.1)
- ~~Glass client must implement always-on mic per C-22~~ → replaced by physical-key mic (C-37, v2.1)

**Depends on**: Phase 2 (✓ done); Halo Ring plugin protocol (✓ done)

**Deferred**: Rokid-specific port (Phase 4); UC3 face recognition (Phase 6).

**Note**: Reverse-wake card rendering already proven server-side (Phase 5 demoed early via `test-harness/real_cc_reverse_wake.py`). Phase 3 must render the tool_card variant (preview_action with multi-option list).

**Estimated time**: 1.5–2 weeks

---

### Phase 4 — Rokid Glass deployment

**Scope**: port the Phase 3 phone client to Rokid Glass. Visual tuning for the waveguide; HUD anchor adjustments; deployment automation.

**Deliverables**:
- Build flavour `rokid` in `glass-android/`:
  - Optic adjustments (single projector model — same 480 × 480 content)
  - Brightness inherits system
  - Temple touch bar mapped to focus traversal (DPAD on Rokid)
- Build flavour `rayneo-x3pro` (optional; if Rokid supplies an X3 Pro for testing) — binocular re-anchor (right-eye + 160 px inset) per Halo Ring §4 audit note
- ADB sideload script: `./scripts/install-rokid.sh`
- Wear test: 4 hours on a typical day; voice-invoke / quick-shortcut / feedback / preview all work

**Success criteria**:
- Visual identity matches [Doc/ui-mockup.html](../../Doc/ui-mockup.html) on actual waveguide
- HUD card visible + readable in typical indoor lighting
- Battery: ≥ 4 h active use with default config

**Depends on**: Phase 3, Rokid Glass hardware in hand (when ready — design doesn't block on this, Phase 4 starts when hardware is)

**Deferred**: spatial / AR-anchored HUD (explicitly out of scope per [IMPLEMENTATION-PLAN §5](#5-whats-intentionally-not-in-this-plan))

**Estimated time**: 3–5 days (port should be relatively clean since phone was the proxy)

---

### Phase 5 — v2 architecture pivot (CC-as-agent backend + streaming progress) ✅ infra landed 2026-05-25

**The original Phase 5 was "UC2 Claude Code reverse-wake".** That demo
landed early in Phase 2 closing day. After Phase 3a (Web Console) Zack
re-examined the v0.5 Router prompt and asked the architectural question
that re-shaped Phase 5:

> "感觉越设计越复杂了… 我能不能直接把这些东西甩给 CC？"
> "我需要看到过程，不是直接看到结果。每 2-3s 看到 agent 在干什么；
> 我说错了也能纠正。"

This expanded Phase 5 into a **full architectural pivot**. See
[AGENT-ARCHITECTURE-V2.md](../server/AGENT-ARCHITECTURE-V2.md) for the canonical
design + [PROMPT-DESIGN-V2.md](../server/PROMPT-DESIGN-V2.md) for the brief
methodology that came with it.

**Scope (revised)**:

Cortex stops being the agent. CC becomes the agent. Cortex shrinks to:
classifier (fast_query / simple_action / complex) + HITL preview gate +
receipt writer. The 12 hand-built adapters shrink to 7 executors (preview-
always actions only; everything else CC does via osascript/shell). Progress
is streamed to Glass as non-blocking ticker frames; mid-flight corrections
inject into CC via tmux send-keys.

**Sub-phases**:

| Sub | Scope | Status |
|---|---|---|
| 5a | `claude_code.agent` action: tmux + tail CC's session.jsonl (free stream-json equivalent via subscription quota); distill events to glanceable `{icon, ≤80c}` progress; return structured JSON | ✓ done |
| 5b | Cortex `agent_progress` / `progress_feedback` event handlers + classifier (silence/OK drops; substantive injects via tmux send-keys) + HUD progress ticker render | ✓ done |
| **5c** | Auto-routing classifier ahead of planner (one LLM call, JSON `{complex, why}`; complex → shared `_dispatch_complex_agent`, simple → existing v0.5 path) | **✓ done 2026-05-25** |
| 5d | Mid-flight correction wire | **mitigated by multi-phase checkpoint pattern** (reliable phase-boundary correction); send_keys remains best-effort for free-form mid-thinking notes |
| 5e | `actions[]` schema parse + executor mapper + multi-row preview card + SEND iterates | ✓ done |
| 5f | Multi-phase checkpoint pattern (`{phase_done, summary, next, actions[]}` → ⏸ blocking card → `agent_continue`) | ✓ done 2026-05-25 (verified `multi_phase_e2e.py`) |
| **5g** | Prune `AVAILABLE_TOOLS` catalog to executor + bounded-state-query set (10 tools, 11 actions); keep adapter code for regression safety | **✓ done 2026-05-25** |

**Verified working** (commits ef6387d → 31aaa1f in Constellation-Server):

- Streaming agent: `agent_smoke.py` + `actions_e2e.py` both PASS
- $0 marginal cost (TUI subscription, not API quota)
- Median progress event gap: 2-3s (target ≤3s)
- glanceable distillation (emoji + ≤80c labels per HUD spec)
- `actions[]` → preview card with rendered rows (email / reminder /
  calendar_event / imessage / fs_write / shortcut)
- Three architectural bugs caught + fixed: tool_agent sequential RPC
  dispatch (now concurrent), `idle_after_any_assistant` false-completion
  (now `stop_reason == end_turn`), /tmp symlink path mismatch

**Status update 2026-05-25**:

- **P0.1 mid-flight send_keys**: classified as known limitation; mitigated
  by the multi-phase checkpoint pattern. CC pauses at phase boundaries
  (end_turn + `phase_done:true`), Cortex surfaces a ⏸ blocking card, user
  types corrections, Cortex resumes via `agent_continue`. Free-form
  mid-thinking send_keys remains best-effort (not load-bearing).
- **P0.2 Opus extended thinking latency**: Zack chose to keep Opus 4.7
  over Sonnet. Mitigated by the **thinking heartbeat** (8s silence → emit
  "💭 still thinking… (Ns quiet)" so HUD doesn't look dead).
- **P0.3 deep-research stalls / "never bail"**: brief v2.6 hardens this
  with YOU MUST emphasis + R1/R2/R3 + self-check + the phase pattern
  (partial-OK after one phase is better than never returning).

**Success criteria** (revised):
- A Kao-style multi-tool ask completes in ≤30s
- HUD shows a new visible event every ≤5s during the run
- A mid-flight correction (spoken/typed during a progress event) is
  honoured: the final `actions[]` reflects the correction
- The original simple-ask paradigm (A) still works through a fast path

**Depends on**: Phase 2 (executor adapters), Phase 3a (Web Console + push)

**Deferred**: anything that requires P0/P1 to land first

**Estimated time remaining**: 0 — Phase 5 (5a/5b/5c/5e/5f/5g) all landed 2026-05-25. Optional polish: HUD "Use agent" toggle to force the agent path; cheap-haiku swap-in (`CORTEX_CLASSIFIER_MODEL`) once Anthropic key is plumbed.

---

### Phase 6 — UC3 (face recognition, local model)

**Scope**: vision-based face recognition with local model. Parallel-able with Phase 5 / 7.

**Deliverables**:
- `local_face_recognition` adapter in `tool-agent/`:
  - Library decision (Phase 6 starts with picking — recommend `face_recognition` (dlib-based) for simplicity, fallback `insightface` if needed)
  - Actions per [TOOL-ADAPTERS.md §6](../server/TOOL-ADAPTERS.md): `detect`, `embed`, `match`
- Twin face memory layout per [DATA-MODEL §13](../server/DATA-MODEL.md): `memories/faces/{slug}/embeddings.json` + face crops
- Quick Shortcut #1 ("Quick capture person") flow:
  - Voice Invoke or LP+SWIPE → photo
  - Cortex Router dispatches `local_face_recognition.match` first
  - If match → render info card (case C from [ui-mockup §1.10](../../Doc/ui-mockup.html))
  - If no match → render propose-add card (case D)
  - ADD + DICTATE opens mic again → second event → Cortex composes final dispatch
- Encounters auto-promotion ([DATA-MODEL §6.2](../server/DATA-MODEL.md)): ≥ 3 appearances OR commitment link OR explicit user promotion

**Success criteria**:
- Capture face of known person → match → archive summary displayed
- Capture unknown → ADD + DICTATE flow → saved to `people/encounters.md`
- Capture same unknown 3 times → auto-promoted to `people/core/`

**UC3 v1 partial parking — long-form transcript (UC3-D)**:

[SoT §10.3](../constitution/SOURCE-OF-TRUTH.md) mentions ambient transcription ("我和某人在聊天时开启了转写")
as part of UC3. This requires a **long-form recording mode** on Glass that the v1 Voice Invoke
pipeline (short utterance + VAD-stop) does NOT provide.

Per [SoT N-3](../constitution/SOURCE-OF-TRUTH.md) + [DESIGN.md §5 Cool Examples Library #1](../constitution/DESIGN.md),
"ambient transcription with diarized attribution" is **explicitly parked** as cool feature #1,
not v1. UC3-D was always partially out of scope.

**UC3 v1 scope**: A (initial capture), B (re-meet match), C (cross-time recall).
**UC3-D**: deferred. Workaround: Quick Shortcut #3 ("Drop a thought", mic-only) lets the
wearer dictate a conversation summary after the meeting. Not live transcription, but covers
most of the recall use case.

(Confirmed in [USE-CASE-AUDIT §UC3-D](USE-CASE-AUDIT.md).)

**Depends on**: Phase 2 (Cortex foundation), Phase 3 (HUD card variant rendering — cases C/D)

**Estimated time**: 1–2 weeks (most time in face-lib selection + reliability tuning)

---

### Phase 7 — Insight Engine (P6) + Implicit Learning Loop

**Scope**: Cortex stops being purely reactive.

**Deliverables**:
- **Insight Engine** ([COMPONENT-DESIGN §1.5](../server/COMPONENT-DESIGN.md), config per [twin-seed/skills/insight-engine.md](../../../Constellation-Server/twin-seed/skills/insight-engine.md)):
  - Twin watcher: scan `commitments/` (due dates) + `interests/` (signal freshness)
  - Mac event subscriber: Calendar / Mail incoming
  - Cron tick (5 min default)
  - GPT eval per candidate: surprising/interesting? → push or drop
- P6 HUD card rendering (already in Phase 3 spec; this phase wires the path)
- **Implicit Learning Loop** ([DATA-MODEL §9](../server/DATA-MODEL.md)):
  - Post-task async GPT self-audit
  - LearningCandidate generation → skill update / new skill / correction
  - High-confidence → append to skill file + CHANGELOG
  - Low-confidence → `_system/pending/skill-updates/`
- Morning HUD peek surface: "N pending Twin reviews"

**Success criteria**:
- After ~3 days of UC1 use, `skills/dispatch.md` shows ≥ 1 auto-learned hint
- A commitment with `due: tomorrow` triggers a P6 pulse at appropriate time
- Snoozing pulse 3 times → `skills/pulse-feedback.md` shows a learned rule
- `_system/learnings-log.md` has ≥ 10 entries

**Depends on**: Phase 2 (UC1 working), Phase 5 (reverse-wake patterns share scheduler infrastructure)

**Estimated time**: 1–2 weeks

---

### Phase 8 — MCP server skeleton (P5)

**Scope**: expose sanctioned Twin slices to external AI. Per [DESIGN.md Q-4](../constitution/DESIGN.md), don't strongly demo — just have the interface working.

**Deliverables**:
- `mcp-server/` Python service via stdio (MCP standard); launched as subprocess on demand
- Tools per [INTERFACE-CONTRACTS §5](../server/INTERFACE-CONTRACTS.md):
  - `read_twin(path)` with share filter
  - `list_twin(prefix)`
  - `query_twin(question)` — grep + GPT synthesis, no vector DB
  - `get_identity()`
  - `get_preferences(topic)`
- Token-based auth (manual issuance, token → label mapping in a `mcp-tokens.yaml`)
- One sanity demo: Claude Desktop reads sanctioned slices and answers "what am I working on?"

**Success criteria**:
- Claude Desktop configured → successfully reads `identity.md` + `projects/` + `commitments/`
- Files with `share: none` correctly 403

**Depends on**: Phase 2 (Twin has content); parallel-able with 5/6/7

**Estimated time**: ~3 days

---

### Phase 9 — Dogfood + cool-example stress test

**Scope**: actually use Constellation for real work. Stress-test against ★-starred Cool Examples.

**Deliverables**:
- 7 consecutive days of wearing the glasses (or phone if Glass not yet) + using Constellation as primary intent-dispatcher
- Stress-test against ★ examples from [DESIGN.md §5](../constitution/DESIGN.md):
  - A1 跑步无眼镜 — document the gap (Vision-level, not implementable in v1)
  - B1 承诺履约监控 — Insight Engine + commitment scan, validate
  - C1 会议准备一条龙 — multi-tool orchestration, validate
  - D1 Build failed reverse-wake — write a Mac watcher script, validate
  - F1 Cortex 反问 disambiguation — issue an ambiguous voice intent, see if Cortex routes a clarification card back
- Audit document: `RETRO-PHASE9.md` listing "what broke / what surprised me / what to fix next"

**Success criteria**:
- Twin CHANGELOG.md has ≥ 100 Cortex-authored entries across 7 days
- You didn't fall back to your phone (for tasks Constellation should have handled) for ≥ 5 of the 7 days
- 1 external observer (HCI peer) has seen the demo and asked an unprompted "wait, how did it know X" question

**Depends on**: Phases 2–7 complete; Phase 8 optional

**Deferred**: paper write-up (per SoT N-2, falls out later)

**Estimated time**: 7 calendar days of use + 2 days audit

---

## 4. Critical-path budget

| Phase | Estimate | On critical path? |
|---|---|---|
| 0 — Prereqs | 0.5–1 day | ✓ |
| 1 — Mac-spine | 5 days | ✓ |
| 2 — Mac UC1 | 1–2 weeks | ✓ |
| 3 — Android phone | 1.5–2 weeks | ✓ |
| 4 — Rokid deploy | 3–5 days | ✓ |
| 5 — UC2 reverse-wake | 1 week | ✓ |
| 6 — UC3 face | 1–2 weeks | parallel |
| 7 — Insight + learning | 1–2 weeks | ✓ |
| 8 — MCP | ~3 days | parallel |
| 9 — Dogfood | 9 days | ✓ |

**Critical path serial**: ~9–12 weeks total.
**Parallelised** (6 / 8 alongside 5 / 7): ~8–11 weeks.

Phase 4 (Rokid deploy) is on the critical path only if you specifically need Rokid; Phase 3 (Android phone) is sufficient for nearly all dogfood. You can dogfood (Phase 9) on phone alone, defer Phase 4 to when Rokid arrives.

---

## 5. What's intentionally **not** in this plan

| Excluded | Reason |
|---|---|
| Multi-user / privacy hardening | SoT N-5; v2 concern |
| Paper write-up | SoT N-2; falls out of v1 if interesting |
| Cool features beyond v1 ★ list | SoT N-3; parked in [DESIGN.md §5](../constitution/DESIGN.md) |
| Vector DB / embedding store for Twin | SoT C-7; markdown stays grep-only |
| RayNeo X3 Pro support | Phase 4 may include as second flavour if hardware available, but not v1 must |
| Spatial / AR-anchored HUD | Out of scope; HUD is screen-anchored |
| Schema migrations | v1 freeze ([INTERFACE-CONTRACTS §7](../server/INTERFACE-CONTRACTS.md)) |
| Constellation-controlled gesture mapping | Owned by Halo Ring via plugin protocol |
| Snapshots / undo | v1 not; need-driven (v1.5+) |
| CI / automated tests beyond pytest | v1 manual; Phase 9 dogfood is the test |
| i18n beyond EN / ZH | EN/ZH only at launch |

---

## 6. Implementation environment

| Component | Stack | Location |
|---|---|---|
| Cortex Agent | Python 3.11 + asyncio + websockets | `cortex/` on Mac mini |
| Tool Agent | Python 3.11 + asyncio + websockets | `tool-agent/` on Mac mini |
| MCP Server | Python 3.11 (MCP stdio) | `mcp-server/` on Mac mini |
| Glass client | Android (Kotlin + Jetpack Compose) | `glass-android/` deployed first to rooted Android phone, then Rokid Glass |
| Twin | markdown files | `~/constellation/twin/` (seeded from `twin-seed/`) |
| Transport (active) | WSS over Tailscale | Cortex listens on Tailnet IP |
| Transport (wake) | Push notification (FCM or Rokid-native) | Phase 3 setup |

---

## 7. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| **Cortex Router prompt produces wrong dispatch for novel intents** | Medium | Few-shot prompt + `dispatch.md` learning loop closes this. Bootstrap with hand-seed hints if needed. |
| **`claude_code` adapter regex breaks on new CC versions** | Medium | Patterns in [`twin-seed/skills/claude-code-control.md`](../../../Constellation-Server/twin-seed/skills/claude-code-control.md) — hot-reloadable, no adapter code change. Add new patterns as CC evolves. |
| **GPT API cost gets out of hand** | Medium | Monthly cap alarm at $100/mo; Insight Engine caps daily eval count; reuse cached Router results for identical intents. |
| **Glass / phone battery drain** | Medium | Hybrid connection model already addresses idle drain. If still bad, reduce pulse frequency or move STT to platform (less battery than Whisper.cpp). |
| **Local face-recognition false positives or false negatives** | Medium | Threshold tuning (start 0.6, raise if false-positives, lower if false-negatives); the "this isn't right" feedback option demotes the match. |
| **Twin write conflicts (Cortex + you `vim`'ing simultaneously)** | Low | mtime check + pending queue per [twin-seed/skills/twin-write-policy.md](../../../Constellation-Server/twin-seed/skills/twin-write-policy.md). |
| **Halo Ring plugin protocol changes breaking Constellation** | Low | Plugin protocol version pinned at 1; breaking changes require version bump on both sides. Halo Ring agent is aware. |
| **Cool features creep into v1** | Medium | This plan + SoT N-3 are the guardrails. Re-read before each phase. |

---

## 8. Greenlight checklists

### 8.1 Phase 1+2 greenlight (historical — all done 2026-05-24)

- [x] All design docs at green (now v0.8 / v0.6 / v0.3 / v0.2 / v0.3 / v0.2 / v0.2 / v0.1 / v0.1 / **v0.3**)
- [x] All G1/G2/G3 implementation-blocking gaps closed
- [x] Halo Ring plugin protocol shipped on Halo Ring's side
- [x] OpenAI API key obtained (in `tool-agent/.env`)
- [x] Claude Code CLI installed (`2.1.133`); **Anthropic API key NOT needed** — CC uses logged-in account
- [x] Twin seed copied to `~/constellation/twin/` (incl. seeded jane-doe + mike-chen)
- [ ] Tailscale on Mac mini — **not blocking Phase 1+2 (localhost works); blocks Phase 3**

### 8.2 Phase 3 greenlight (next step)

- [ ] Tailscale installed on Mac mini; Cortex launched with `--host <tailnet-IP>`
- [ ] Verify fake-Glass over Tailscale still works before phone client work begins (smoke test from a separate machine)
- [ ] Choose push notification service (FCM / Rokid-native) per Q-7 — needed for idle-wake path
- [ ] Android Studio + adb working
- [ ] All Phase 3 deliverables in §Phase 3 above; per SoT C-22 always-on-mic is **non-negotiable** from day 1

### 8.3 Post-Phase 3 (deferred)

- Phase 4 hardware: Rokid Glass in hand
- Phase 6 face-recognition lib choice (OQ-D7)
- Phase 7 prereqs: stable signal sources (mail/calendar/git events) for Insight Engine

---

## 9. Document Status

- **Version**: v0.3
- **Last updated**: 2026-05-24
- **Based on**: actual execution of Phase 0 + 1 + 2 + R-3 + Phase 5 early demo on 2026-05-24 + Zack greenlights for Phase 3
- **Revision Log**:
  - v0.1: First version with 9 phases assuming hardware-blocking Phase 0
  - v0.2: Hardware no longer blocking (per Zack); restructured to **10 phases** with Mac-side (1+2) → Android-phone (3) → Rokid (4) sequence; integrated G1/G2/G3 references; added Greenlight checklist (§8)
  - v0.3: **Implementation status absorbed**: Phase 1 ✓, Phase 2 ✓, R-3 multi-step paradigm ✓ (insert as Phase 2.5), Phase 5 UC2 ✓ demoed early. §1 added live status table. Phase 3 success criteria rewritten with C-22 always-mic hard requirement + multi-step rendering note. §8 Greenlight checklists split — historical 8.1 (Phase 1+2 all checked except Tailscale) + new 8.2 (Phase 3 prereqs incl. Tailscale + push service choice + always-mic non-negotiable) + 8.3 (post-Phase 3 forward-looking).

---

*End of Constellation Implementation Plan v0.3.*
