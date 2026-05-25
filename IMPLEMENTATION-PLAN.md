# Constellation — Implementation Plan

**Version**: v0.4
**Status**: Phase 1 ✓ + Phase 2 ✓ + R-3 ✓ + Phase 5 UC2 demoed ✓ + **Phase 3a Web Console ✓ live at edge.example.com** → next: **Phase 3b Android-native**
**关联文档**: [DESIGN.md](DESIGN.md) · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [DATA-MODEL.md](DATA-MODEL.md) · [UI-UX.md](UI-UX.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) · [TOOL-IDEAS.md](TOOL-IDEAS.md) · [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) · [Doc/ui-mockup.html](Doc/ui-mockup.html) · [HANDOFF.md](HANDOFF.md)
**Last updated**: 2026-05-25

---

## 1. Approach

**10 phases**, ordered by dependency. Per Zack's direction:
- **Mac-side first**, test entirely with a `curl`-based fake-Glass simulator
- **Then rooted Android phone** as the development client (cheaper iteration than full Glass deploy)
- **Then Rokid Glass deployment** when phone client is stable

Critical path: **Phase 0 → 1 → 2 → 3 → 4 → 5 → 7 → 9**. Phases 6 (UC3) and 8 (MCP) are parallel-able with 5/7.

Each phase has: scope, deliverables, dependencies, success criteria, deferred items, time estimate.

### Status at 2026-05-25 (Phase 3a wrap)

| Phase | Status | Notes |
|---|---|---|
| 0 — Prereqs | ✓ done | OpenAI key; CC CLI 2.1.133; Twin seeded; Tailscale ✓ on Mac + Linux; edge.example.com DNS + LE cert |
| 1 — Mac spine | ✓ done | full_loop.py 4× PASS; launchd cycle verified |
| 2 — Mac UC1 + Slice A/B/C | ✓ done | 12 adapters; UC1 wall-clock 5/5 PASS mean 3.9s; confirm-policies enforced |
| 2.5 — R-3 multi-step | ✓ done | SoT R-3 (C-20~23 + N-8~11); multistep_deep.py 3/3 PASS |
| 5 — UC2 reverse-wake | ✓ demoed early | real CC permission → tool_card → allow_once → file written |
| **3a — Web Console** | **✓ done 2026-05-25** | live https://edge.example.com/; cookie auth; 9 routes incl. HUD WSS / CC live pane / Twin browser + edit / prompt inspector / SSE trace / Web Push; full workflow test PASS (auto+preview+feedback) |
| **3b — Android-native client** | **⏸ NEXT** | rooted Android phone first; inherits proven protocol from 3a; **always-on mic per SoT C-22 mandatory from day 1** |
| 4 — Rokid Glass deploy | ⏸ | post-3b; rokid build flavour of glass-android module |
| 6 — UC3 face | ⏸ | parallelisable; local face recognition lib in Tool Agent |
| 7 — Insight Engine + Implicit Learning | ⏸ | parallelisable; Cortex stops being purely reactive |
| 8 — MCP server | ⏸ | parallelisable; expose sanctioned Twin slices to external AI |
| 9 — Dogfood + cool-ex stress | ⏸ | 7-day wear; ★ list from DESIGN §5 |

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
- Push notification service decided ([Q-7](DESIGN.md)) — but **not required for Phase 1/2** (Mac-only, curl-tested)

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
  - Adapter base class per [TOOL-ADAPTERS.md §contract](TOOL-ADAPTERS.md)
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
- **Real Cortex Router**: using [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) — system prompt + user prompt template + 2–3 hand-picked few-shots. GPT API call (gpt-4o-mini for speed, or gpt-4o for quality — A/B in this phase).
- **Tool Adapters** per [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md):
  - `claude_code` adapter — tmux session model per [COMPONENT-DESIGN §2.5](COMPONENT-DESIGN.md). Actions: `run`, `draft`, `get_status`, `send_keys`, `kill`. Uses [twin-seed/skills/claude-code-control.md](twin-seed/skills/claude-code-control.md) for regex patterns.
  - `applescript_mail` adapter — actions: `read_current`, `list_inbox`, `draft`, `send`, `get_thread`
  - `applescript_reminders` adapter — actions: `add`, `list`, `complete`, `delete`
- **Feedback Loop** ([INTERFACE-CONTRACTS §1.5](INTERFACE-CONTRACTS.md)): test-harness can POST a `user_decision { feedback }` with feedback_text; Cortex re-prompts Router with the iteration context; v2 preview comes back
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

**Scope**: build the Glass client on a **rooted Android phone first** (per Zack's preferred workflow). Same code path, easier iteration. Deploy to Rokid Glass in Phase 4. **Inherits the WSS Glass protocol proven by Phase 3a** — same `user_invoke` / `Command` / `user_decision` shapes; smaller delta from web client to Kotlin client.

**Deliverables**:
- **`glass-android/`** (Android Studio module, Kotlin + Jetpack Compose):
  - Foreground service (`ConstellationService`) running an overlay `WindowManager` view
  - HUD overlay Composable rendering all atoms ([UI-UX §3](UI-UX.md)): status pill (4 variants) + card (variants by content)
  - Manifest declarations for Halo Ring plugin protocol ([halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md)):
    - `<meta-data android:name="halo.ring.plugin_version" android:value="1" />`
    - `HaloActionsProvider` ContentProvider (returns `voice_invoke` + `shortcut_*` actions from `~/constellation/twin/skills/shortcuts.md` — managed via the app-internal Shortcuts editor)
    - `HaloTriggerReceiver` BroadcastReceiver
  - Hybrid transport ([INTERFACE-CONTRACTS §1.6](INTERFACE-CONTRACTS.md)): WSS over Tailscale during active; push notification listener during idle (FCM stub OK on phone — Rokid push for Phase 4)
  - Mic + photo capture pipeline (Android `CameraX` + on-device STT — start with Android `SpeechRecognizer`; Whisper.cpp port later if needed)
  - App-internal screens per [Doc/ui-mockup.html §2](Doc/ui-mockup.html): Main / Shortcuts list / Shortcut editor / Connect to Cortex / About
  - **Profile push/pop** to Halo Ring on HUD open/close (per [halo-ring-plugin-protocol §6](halo-ring-plugin-protocol.md))

**Success criteria**:
- Phone gesture (long-press temple touch or rooted-Android button-mapped trigger): triggers Voice Invoke → photo + mic → sends `user_invoke` to Mac mini Cortex (via Tailscale)
- Within 6 s: HUD card appears on phone screen showing UC1 email preview
- Tap option (or button-mapped): sends `user_decision`; full UC1 flow completes
- **Every HUD card auto-opens the mic with VAD-stop** (SoT C-22 hard requirement); speech becomes `user_decision { decision: "feedback", feedback_text: "<STT>" }`; ring-tap default option emits `user_decision { decision: "send" }`. Both channels operate in parallel for every card
- **Multi-step task flows render naturally**: a sequence of preview_action cards, user can SEND ring-tap or speak free-form between rounds (see [UI-UX.md §3.4-3.6](UI-UX.md))
- Settings: edit a shortcut's preset prompt → Halo Ring's Action Picker (on the same phone) sees the updated description
- Stability: 1-hour wear test, no crashes, battery drain reasonable

**Hard prereqs added in v0.3**:
- Tailscale installed on Mac mini; Cortex launched with `--host <tailnet-IP>` for phone access (currently binds 127.0.0.1)
- Glass client must implement always-on mic per C-22 (Phase 3 critical-path)

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
- Visual identity matches [Doc/ui-mockup.html](Doc/ui-mockup.html) on actual waveguide
- HUD card visible + readable in typical indoor lighting
- Battery: ≥ 4 h active use with default config

**Depends on**: Phase 3, Rokid Glass hardware in hand (when ready — design doesn't block on this, Phase 4 starts when hardware is)

**Deferred**: spatial / AR-anchored HUD (explicitly out of scope per [IMPLEMENTATION-PLAN §5](#5-whats-intentionally-not-in-this-plan))

**Estimated time**: 3–5 days (port should be relatively clean since phone was the proxy)

---

### Phase 5 — UC2 (Claude Code reverse-wake + status query)

**Scope**: bidirectional supervision (P4). Build the reverse-wake event path end-to-end.

**Deliverables**:
- `claude_code` adapter's `watch_for_reverse_wake()` async loop:
  - Capture-pane polling per [twin-seed/skills/claude-code-control.md](twin-seed/skills/claude-code-control.md)
  - On permission_pattern match → emit `tool_reverse_wake` event into Cortex
- Cortex's reverse-wake event handling:
  - Re-runs Router with a different Twin context_pack
  - Outputs `tool_card` HUD response per [CORTEX-ROUTER-PROMPT.md Example 4](CORTEX-ROUTER-PROMPT.md)
  - Pushes via Hybrid transport (push notification if Glass idle)
- Status query path: Voice Invoke "how's it going" → Cortex dispatches `claude_code.get_status` → renders summary card
- Tool Agent State Tracker: maintains active long-task list, exposes via `get_status`

**Success criteria**:
- Start a long Claude Code task on Mac mini, walk away with phone/glasses
- When CC hits a permission prompt, HUD card appears within 5 s
- Tap ONCE → `claude_code.send_keys` fires `y\n` → CC continues
- "How's the build" voice query returns a status card with last 10 lines + state

**Depends on**: Phase 2 (foundation), Phase 3 (card rendering); Phase 4 if testing on Rokid

**Deferred**: build watcher / GitHub PR review reverse-wakes (those are framework-supported cool features, not v1 must)

**Estimated time**: 1 week

---

### Phase 6 — UC3 (face recognition, local model)

**Scope**: vision-based face recognition with local model. Parallel-able with Phase 5 / 7.

**Deliverables**:
- `local_face_recognition` adapter in `tool-agent/`:
  - Library decision (Phase 6 starts with picking — recommend `face_recognition` (dlib-based) for simplicity, fallback `insightface` if needed)
  - Actions per [TOOL-ADAPTERS.md §6](TOOL-ADAPTERS.md): `detect`, `embed`, `match`
- Twin face memory layout per [DATA-MODEL §13](DATA-MODEL.md): `memories/faces/{slug}/embeddings.json` + face crops
- Quick Shortcut #1 ("Quick capture person") flow:
  - Voice Invoke or LP+SWIPE → photo
  - Cortex Router dispatches `local_face_recognition.match` first
  - If match → render info card (case C from [ui-mockup §1.10](Doc/ui-mockup.html))
  - If no match → render propose-add card (case D)
  - ADD + DICTATE opens mic again → second event → Cortex composes final dispatch
- Encounters auto-promotion ([DATA-MODEL §6.2](DATA-MODEL.md)): ≥ 3 appearances OR commitment link OR explicit user promotion

**Success criteria**:
- Capture face of known person → match → archive summary displayed
- Capture unknown → ADD + DICTATE flow → saved to `people/encounters.md`
- Capture same unknown 3 times → auto-promoted to `people/core/`

**UC3 v1 partial parking — long-form transcript (UC3-D)**:

[SoT §10.3](SOURCE-OF-TRUTH.md) mentions ambient transcription ("我和某人在聊天时开启了转写")
as part of UC3. This requires a **long-form recording mode** on Glass that the v1 Voice Invoke
pipeline (short utterance + VAD-stop) does NOT provide.

Per [SoT N-3](SOURCE-OF-TRUTH.md) + [DESIGN.md §5 Cool Examples Library #1](DESIGN.md),
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
- **Insight Engine** ([COMPONENT-DESIGN §1.5](COMPONENT-DESIGN.md), config per [twin-seed/skills/insight-engine.md](twin-seed/skills/insight-engine.md)):
  - Twin watcher: scan `commitments/` (due dates) + `interests/` (signal freshness)
  - Mac event subscriber: Calendar / Mail incoming
  - Cron tick (5 min default)
  - GPT eval per candidate: surprising/interesting? → push or drop
- P6 HUD card rendering (already in Phase 3 spec; this phase wires the path)
- **Implicit Learning Loop** ([DATA-MODEL §9](DATA-MODEL.md)):
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

**Scope**: expose sanctioned Twin slices to external AI. Per [DESIGN.md Q-4](DESIGN.md), don't strongly demo — just have the interface working.

**Deliverables**:
- `mcp-server/` Python service via stdio (MCP standard); launched as subprocess on demand
- Tools per [INTERFACE-CONTRACTS §5](INTERFACE-CONTRACTS.md):
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
- Stress-test against ★ examples from [DESIGN.md §5](DESIGN.md):
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
| Cool features beyond v1 ★ list | SoT N-3; parked in [DESIGN.md §5](DESIGN.md) |
| Vector DB / embedding store for Twin | SoT C-7; markdown stays grep-only |
| RayNeo X3 Pro support | Phase 4 may include as second flavour if hardware available, but not v1 must |
| Spatial / AR-anchored HUD | Out of scope; HUD is screen-anchored |
| Schema migrations | v1 freeze ([INTERFACE-CONTRACTS §7](INTERFACE-CONTRACTS.md)) |
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
| **`claude_code` adapter regex breaks on new CC versions** | Medium | Patterns in [`twin-seed/skills/claude-code-control.md`](twin-seed/skills/claude-code-control.md) — hot-reloadable, no adapter code change. Add new patterns as CC evolves. |
| **GPT API cost gets out of hand** | Medium | Monthly cap alarm at $100/mo; Insight Engine caps daily eval count; reuse cached Router results for identical intents. |
| **Glass / phone battery drain** | Medium | Hybrid connection model already addresses idle drain. If still bad, reduce pulse frequency or move STT to platform (less battery than Whisper.cpp). |
| **Local face-recognition false positives or false negatives** | Medium | Threshold tuning (start 0.6, raise if false-positives, lower if false-negatives); the "this isn't right" feedback option demotes the match. |
| **Twin write conflicts (Cortex + you `vim`'ing simultaneously)** | Low | mtime check + pending queue per [twin-seed/skills/twin-write-policy.md](twin-seed/skills/twin-write-policy.md). |
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
