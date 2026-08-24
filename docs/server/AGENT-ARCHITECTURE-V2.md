# Agent Architecture v2 — Streaming CC Agent + Mid-flight Correction

**Status**: design ✓ (2026-05-25) → core ✅ landed → P0-P2 polish ✅ landed (2026-05-26: long-lived CC reuse, R-3 ripout, per-session cost rollup, Insight skeleton, archive filter)
**Supersedes**: DESIGN.md §"Cortex Router" planning model. Router demoted to
single-shot bounded-single-call planner; CC promoted to primary agent for any multi-step / research / drafting ask. v0.5 selector role narrows.
**Trigger**: Zack's reflection — "我感觉越设计越复杂了… 是否真的需要自己从零搓
一堆工具调用… 能不能直接甩给 CC… 不要被现有不合理设计所限制的视野…
我能看到过程而不是直接看到结果… 我每隔几秒就能看到它在运作、它在干嘛、
我表达不对还能纠正修改"

---

## 0. First-principles restatement

Four non-negotiables, weighted now that Zack elevated the third:

| #  | Invariant                                                  | Weight |
|----|------------------------------------------------------------|--------|
| 1  | Always-on Glass UX (voice in, card out)                    | hard   |
| 2  | HITL preview gate before any side effect (SoT C-9/C-10)    | hard   |
| 3  | **Visible process + mid-flight correction**                | hard ★ |
| 4  | Receipts / audit in Twin                                   | hard   |

★ is new. 30-second "thinking…" is unacceptable. Every 2–3s the user must
see *what* the agent is doing, and at any moment a spoken correction can
redirect it.

Everything else (Router round-based multi-step, 12 hand-built adapters,
two-pass Twin selector, schema enumerations) is **implementation detail
subject to revision**.

---

## 1. What v0.5 got wrong

- **Cortex Router IS an agent runtime in disguise.** Multi-step rounds,
  pending preview state, 12 tool adapters — this is a mini-CC. Reinventing
  what CC already does well, with a dumber LLM.
- **Round-based latency model is incompatible with invariant 3.** Each
  round = ~5s LLM call + dispatch + back-to-user. 5 rounds = 25s of
  "thinking…" with no signal in between. User can't redirect.
- **Most adapters are read/search/list tools that CC does better via
  osascript / shell.** Building them was a waste.
- **The selector pass (v0.5) is solving the wrong problem.** It picks Twin
  slices for *Router* to read — but Router shouldn't be reasoning at all
  for complex tasks. The selector still has value, but for picking what
  to inline into CC's brief.

---

## 2. v2 architecture

```
                       ╔════════════ Glass / HUD ════════════╗
                       ║                                      ║
  voice/text invoke ──▶║  preview cards · progress timeline · ║◀── streaming progress
                       ║  always-on mic for corrections       ║
                       ╚══════╦═══════════════════════════════╝
                              │                ▲
                              ▼                │ corrections (voice → text)
                       ┌──────────────────────────────┐
                       │      Cortex (thin)           │
                       │                              │
                       │   ① classify ask:            │
                       │      simple  → fast adapter  │
                       │      complex → CC agent      │
                       │      query   → fast adapter  │
                       │                              │
                       │   ② if CC: assemble brief    │
                       │      (Twin slice inline)     │
                       │                              │
                       │   ③ stream CC events:        │
                       │      distill → progress      │
                       │      msg → Glass             │
                       │                              │
                       │   ④ on CC done:              │
                       │      parse structured JSON   │
                       │      → preview_action card   │
                       │      → SEND → executors      │
                       │                              │
                       │   ⑤ user correction:         │
                       │      voice text → inject     │
                       │      into CC stdin           │
                       └─────────────┬────────────────┘
                              │      │
                ┌─────────────┘      └─────────────┐
                ▼                                  ▼
       ┌──────────────────┐                ┌─────────────────────┐
       │ Fast executors   │                │ Claude Code         │
       │ (7-ish adapters) │                │   --output-format=  │
       │  reminders.add   │                │     stream-json     │
       │  calendar.add    │                │   --input-format=   │
       │  mail.send       │                │     stream-json     │
       │  fs.write        │                │   --json-schema=... │
       │  imessage.send   │                │   --add-dir ~/twin  │
       │  shortcuts.run   │                │                     │
       │  system_status   │                │   uses osascript +  │
       │  safari current  │                │   shell + edit for  │
       └──────────────────┘                │   any research /    │
                                           │   compose / search  │
                                           └─────────────────────┘
```

### Cortex's new (much smaller) job

```python
async def handle_user_invoke(event):
    # 1. classify
    intent = await classify(event.text)
    
    if intent.kind == "fast_query":              # battery / time / focus
        result = await dispatch_fast(intent)
        await glass.send(hud_show_card(result))
        return
    
    if intent.kind == "simple_action":           # explicit single-step
        plan = simple_plan(intent)               # no LLM; direct from intent
        await glass.send(preview_card(plan))
        # SEND → execute via 1 executor adapter
        return
    
    # else: complex agentic
    brief = build_brief(event, twin_slices=v05_selector.pick(event))
    schema = pick_output_schema(intent)          # email | reminder | actions[]
    
    async for ev in cc_agent.stream(brief, schema=schema):
        progress = distill(ev)
        if progress:
            await glass.send_progress(progress, parent_event_id=event.id)
        # listen for user correction on the side; inject into cc.stdin
    
    final = cc_agent.last_result
    plan = parse(final, schema)
    await glass.send(preview_card(plan))
    # SEND → execute each action via the relevant executor adapter
```

### What survives

| Component                       | Status v0.5 → v2 |
|----------------------------------|-----|
| Glass WSS protocol               | ✓ + new `progress` frame |
| Edge proxy (auth, REST, WSS, SSE)| ✓ unchanged |
| Console UI                       | ✓ + HUD progress timeline + Tasks drill-down (was already planned) |
| Preview cards / SEND gate / Receipts / Confirm-policies | ✓ unchanged |
| Twin storage + selector logic    | ✓ — selector now picks slices to inline into **CC's brief**, not Router's prompt |
| 7 executor adapters              | ✓ retained (reminders.add, calendar.add, mail.send, fs.write, imessage.send, shortcuts.run, system_status) |
| CC live pane (3a.5)              | ✓ — becomes core debug tool: watch CC actually work |
| **Cortex Router round-based multi-step** | ✗ **removed**. CC now owns multi-step internally. |
| **8+ read/search adapters**      | ✗ removed from Router's tool catalog (CC does via osascript/shell). Code kept in tool_agent for now in case of regression. |
| **v0.5 Router system prompt**    | mostly retired. New micro-classifier prompt. |

---

## 3. The streaming + correction loop

### ⚠ Critical: TUI mode (tmux), not `claude -p` (per Zack 2026-05-25)

`claude -p` bills from a separate API quota — at ~$0.10/Kao-style task, this
hits user's pocketbook hard at scale (>10 such asks/day = $30/mo just here).
The TUI (interactive `claude`) uses the user's existing Pro/Max subscription
quota, which is bundled and effectively free at our usage.

**Phase 5a verified pivot**: TUI in tmux + tail of CC's session.jsonl file is
functionally equivalent to `--output-format=stream-json` for our purposes,
but at zero marginal cost.

CC writes every event to `~/.claude/projects/<sanitised-cwd>/<session-id>.jsonl`
the moment it happens. By pre-allocating a UUID via `--session-id` we know
the path before launch and can tail it immediately.

Per-event format (`assistant`, `user`, `system`, internal types) is similar
to `-p` stream-json — same `message.content[]` shape with tool_use, text,
tool_result blocks. The `_distill_jsonl_event` helper handles both shapes.

Mid-flight correction: `tmux send-keys` into the agent's tmux session — CC's
TUI accepts the text as a new user message at the next prompt boundary.

`/tmp` on macOS is a symlink to `/private/tmp` — CC follows it, so the
session.jsonl ends up at `~/.claude/projects/-private-tmp/<uuid>.jsonl`.
Adapter resolves `Path(...).resolve()` to handle this.

### CC stream-json events Cortex cares about

| event.type                            | distilled progress for HUD                       |
|---|---|
| `system.subtype=init`                | "Agent online" + session_id                      |
| `stream_event` / `content_block_start` / `tool_use` | "Using BashTool…" / "Reading file…"        |
| `assistant` with tool_use.input.command (Bash) | the actual shell line, truncated to 120c   |
| `user` with `tool_result`            | "✓ N matches" / "✗ command not found"            |
| `assistant` with text content        | model's reasoning blurb (truncated)              |
| `result` (final)                     | "Done in 12.3s ($0.06). Plan ready for review." |

### Mid-flight correction

```
HUD always-on mic captures user voice (or typed)
       ↓
Cortex receives glass `user_decision { decision: "correct", feedback_text: "..." }`
       ↓
Cortex writes to CC's stdin as stream-json:
  {"type":"user","message":{"role":"user","content":[{"type":"text","text":"<correction>"}]}}
       ↓
CC sees on next turn boundary (≤3s usually)
       ↓
CC adjusts course; next stream events reflect new direction
       ↓
HUD shows: "Correction received: <text>" then continues
```

Hard-stop: SIGINT to CC + acknowledgement card. Not destructive — CC sessions
auto-persist; user can `claude --resume <id>` later.

### What the user actually sees (Kao example)

```
t=0.0s  User says:  "去 Kao 邮件找项目..."
                                                 [HUD: send invoke icon]
t=0.4s                                           [HUD: 🤖 Agent online — "researching"]
t=1.2s                                           [HUD: 📨 osascript Mail: searching for Kao]
t=2.5s                                           [HUD: ✓ Found 4 threads with Kao (most recent: 5/24)]
t=3.0s                                           [HUD: 📜 Reading email body...]
t=4.5s                                           [HUD: Found project mention: "PhotoRig"]
t=5.0s  User says:  "PhotoRing 不是 PhotoRig"
                                                 [HUD: 💬 Correction injected: "PhotoRing not PhotoRig"]
t=6.2s                                           [HUD: 📁 Searching ~/Code/Projects for PhotoRing...]
t=7.0s                                           [HUD: ✓ Located ~/Code/Projects/PhotoRing]
t=8.5s                                           [HUD: 📜 Finding most recent CC session...]
t=10.0s                                          [HUD: ✓ Session 544393b6 (2 hours ago)]
t=11.5s                                          [HUD: 📖 Reading session summary…]
t=15.0s                                          [HUD: ✍️ Composing email draft…]
t=18.0s                                          [HUD: ✓ Done (17.6s, $0.08)]
                                                 [HUD: ─── preview card ───
                                                       To: kao@...
                                                       Subj: PhotoRing 进度 + 后天碰一下？
                                                       Body: ...
                                                       Reminder: meet kao @ 5/27 14:00
                                                       [Send all] [Edit] [Cancel] ]
t=22.0s User taps Send → mail.send + reminder.add → both done by t=23s
```

Total ~23s end-to-end. **User saw something every 1-2s.** When they said
"PhotoRing not PhotoRig" at t=5s, the agent course-corrected without
restarting. User in the loop, never anxious.

vs v0.5: 7 rounds × 5s = 35s of opaque "thinking", with no chance to
correct mid-task. User has to wait, see the final wrong project, FEEDBACK,
wait again.

---

## 4. The structured output schema CC must conform to

Cortex tells CC the SHAPE via `--json-schema`. For v1 we have ~3 schemas:

```json
// schema: "actions"  — most general, multi-step preview
{
  "type": "object",
  "required": ["actions"],
  "properties": {
    "actions": {
      "type": "array",
      "items": {
        "oneOf": [
          { "type": "object", "required": ["type", "to", "subject", "body"],
            "properties": {
              "type": {"const": "email"},
              "to": {"type": "string"},
              "subject": {"type": "string"},
              "body": {"type": "string"},
              "reply_to_message_id": {"type": "string"}
            }},
          { "type": "object", "required": ["type", "title", "due_iso"],
            "properties": {
              "type": {"const": "reminder"},
              "title": {"type": "string"},
              "due_iso": {"type": "string", "format": "date-time"}
            }},
          { "type": "object", "required": ["type", "title", "start_iso", "end_iso"],
            "properties": {
              "type": {"const": "calendar_event"},
              "title": {"type": "string"},
              "start_iso": {"type": "string", "format": "date-time"},
              "end_iso": {"type": "string", "format": "date-time"},
              "location": {"type": "string"}
            }},
          { "type": "object", "required": ["type", "to", "body"],
            "properties": {
              "type": {"const": "imessage"},
              "to": {"type": "string"},
              "body": {"type": "string"}
            }},
          { "type": "object", "required": ["type", "path", "content"],
            "properties": {
              "type": {"const": "fs_write"},
              "path": {"type": "string"},
              "content": {"type": "string"}
            }}
        ]
      }
    },
    "summary": {"type": "string", "description": "Brief human-readable summary"},
    "notes": {"type": "string", "description": "Anything user should know"}
  }
}
```

Cortex iterates `actions[]` → each action maps to an executor adapter →
each gets a preview row in the card → SEND fires them all.

---

## 5b. Multi-phase checkpoint pattern (v2.6, ★ added 2026-05-25)

Per Zack 2026-05-25: "more blocking checkpoints in the flow". Mid-flight
correction via send_keys is unreliable when CC is in extended thinking;
but **phase boundaries are reliable** because CC has explicitly ended its
turn and is waiting for input.

So instead of running straight from invoke → final actions[], CC can break
multi-phase tasks into stages and PAUSE between them. Each pause surfaces
to the HUD as a blocking preview card; user replies via the composer
(Continue / Adjust+text / Cancel) and Cortex resumes CC.

### When CC checkpoints

The brief (`cortex.agent_brief.build_agent_brief`) tells CC:

> If your work has 2+ distinct phases (e.g. "check emails THEN find dir
> THEN draft reply"), CHECKPOINT between phases instead of running straight
> through. This lets Zack confirm or redirect before each phase — critical
> for sensitive operations or when a wrong keyword could send research the
> wrong direction.

Schema for a checkpoint output (vs final):

```json
{
  "phase_done": true,
  "summary":    "Read latest Kao email — project is PhotoRing",  // HUD title
  "found":      "Latest email from Kao asks PhotoRing progress…", // body context
  "next":       "On confirm: propose fs_write reply + reminder",
  "actions":    []
}
```

vs final (no more phases):

```json
{
  "actions": [{...}, {...}],
  "summary": "PhotoRing reply + reminder",
  "notes":   "Optional caveats"
}
```

Cortex's `_is_checkpoint(structured)` returns True iff `phase_done` is
truthy AND `next` is non-empty.

### Flow

```
user_invoke
  → http _send_agent_card → claude_code.agent (TUI in tmux, --session-id <uuid>)
      → CC runs Phase 1
      → emits {phase_done:true, next:"…"} + end_turn
  → adapter sees checkpoint output: KEEP tmux alive, return is_checkpoint=true
  → Cortex builds ⏸ "Phase pause" card with [Continue/Adjust/Cancel]
      → user taps Continue
  → Cortex._resume_agent_phase → claude_code.agent_continue(tmux_session, "continue")
      → adapter paste-buffers "continue" into existing tmux, tails new jsonl from
        previous EOF, returns next output
      → if checkpoint: another ⏸ card; if final: ✦ actions[] preview
  → Cortex._send_agent_card_for_decision builds the next card
  → user taps Send all → existing _execute_remaining path fires executors
```

### Why the phase send_keys works (vs mid-thinking)

At a checkpoint, CC has explicitly ended its turn — the TUI is parked at
its input prompt waiting for a user message. `tmux paste-buffer` + Enter
reliably submits that message and CC processes it on its next turn.

(Contrast: mid-thinking send_keys often gets swallowed because CC's TUI
is busy rendering thinking deltas / tool output and doesn't have a stable
input cursor. The Phase 5b/5d "best-effort mid-flight correction" is kept
for the rare case where CC's between-tool window catches it; the phase
checkpoint is the GUARANTEED correction surface.)

### Cancel

User taps Cancel on a checkpoint card → Cortex dispatches
`claude_code.agent_kill` which `tmux kill-session`s the paused agent. The
CC session.jsonl on disk persists; user can `claude --resume <uuid>` later
if they want.

### Verified e2e (2026-05-25)

`/private/tmp/multi_phase_e2e.py` PASSES through edge.example.com:
  - 2-phase Kao brief
  - Phase 1: read inbox, identify PhotoRing → ⏸ card
  - "Continue" → CC resumes within ~7s
  - Phase 2: final actions card with fs_write + reminder, 28s total
  - 11 progress events, glance-friendly throughout
  - 1 checkpoint + 1 final command card

---

## 5. Brief template (v2 — info-dense, partial-OK, bounded)

v1 brief failed the Kao test: CC hit the 25K-token-per-file limit reading a
big session.jsonl, didn't know it was allowed to give up gracefully, and
wrapped with prose instead of emitting `actions[]`. v2 fixes the framing.

### Design principles (same rigor as v0.5 Router selector)

1. **Critical info at head + tail.** Anthropic models attend most strongly to
   the start and end of long contexts. So: ASK first; OUTPUT CONTRACT in the
   first ~300 tokens; CONSTRAINTS at the end. Reference material in the
   middle.
2. **Don't teach CC its own tools.** No "use osascript like this" or "the
   shell has grep". CC's harness already documents this. Lecturing adds tokens
   without adding signal.
3. **Explicit partial-OK path.** Tell CC: when research hits a wall (file too
   big, data missing, budget tight), STILL emit `actions[]` based on what's
   known + a `notes:` field explaining the gap. The default "I'll try harder"
   loop is what bricks long tasks.
4. **Soft budget hint.** "≤8 tool calls ideal, then commit." Not a hard cap,
   but it shapes CC away from rabbit holes.
5. **Twin selector still applies.** v0.5's selector picks 1-3 paths to
   *inline* into the brief — same as before, but now consumed by CC, not
   v0.5 Router. Everything else stays at `--add-dir` for on-demand reads.
6. **Single-line, prominent mid-flight contract.** CC needs to know that
   a new "user" message in its stream = real-time Zack correction, not the
   typical conversation continuation it's used to.

### v2 brief layout

```
ASK
"<Zack's words, verbatim>"
NOW: <iso + tz>            PHOTO: <yes|no>

OUTPUT (the only thing your final message must contain — raw JSON, no fence)
<inline minified JSON schema — actions[] shape from §4>

If you cannot fully complete the research (e.g., file too large, info
missing, time running out), STILL emit actions[] based on what you DO
know, and use `notes:` to explain the gap. Empty actions[] is acceptable
ONLY for asks that are genuinely unsupported (e.g., a Mac-local action
when there's no plausible candidate); in that case put the reason in
`notes:`.

APPROACH
1. Plan in 1-2 sentences (your "thinking" block — won't be shown to Zack).
2. Execute ≤8 tool calls ideally; commit and emit when you have enough.
3. Emit the final JSON.

CONSTRAINTS
- Do not execute side effects (no osascript that SENDS mail / ADDS reminder
  / ADDS calendar / SENDS imessage; no fs.write outside /tmp/).
  Cortex runs the preview gate on your JSON and dispatches after Zack
  confirms. You PROPOSE only.
- Read ops on Mail/Reminders/Calendar/Messages are fine.
- If a new "user" message appears in your conversation while you're working,
  it is Zack correcting you in real time (mic always-on). Integrate the
  correction immediately; don't ask him to repeat.

CONTEXT (selector-picked, inlined; don't re-read)
=== identity.md ===
<content>
=== skills/<picked>.md ===
<content>
=== people/core/<picked>.md ===
<content>

ALSO ACCESSIBLE (via --add-dir; pull only if needed)
- ~/constellation/twin/      # full Twin (other skills, people, commitments)
- ~/Code/Projects/           # Zack's repos
- ~/.claude/projects/        # past CC sessions
```

The schema is referenced TWICE — once explicitly as the output contract
(at the head), and the schema dict itself is what gets validated. Repetition
of "this is what you must output" is high-leverage; it costs ~150 tokens and
materially raises compliance.

The "partial-OK" clause is the single biggest fix vs v1 — it changes CC's
failure mode from "silent prose" to "honest partial actions[]".

---

## 6. Classifier — Cortex's only LLM call ahead of the planner

**Landed 2026-05-25** as [`cortex/cortex/classifier.py`](../../../Constellation-Server/cortex/cortex/classifier.py). Simpler than the original design: one bit + a 15-word reason.

```
SYSTEM:
You're Cortex's intent classifier. Route Zack's ask to either the
research-agent path (Claude Code in tmux) or the direct-adapter path.

Output JSON ONLY: {"complex": true|false, "why": "≤15 words"}

complex = true  WHEN the ask needs ANY of:
  - reading/finding/searching multiple sources (emails, files, sessions, web)
  - composition / drafting / summarising
  - multiple side-effect actions in one ask
  - keywords: find / look at / search / summarise / draft / check / 看 / 找 / 起草

complex = false WHEN it's a SINGLE explicit step:
  - bounded reminder: "remind me to X at 3pm" (title + time both given)
  - bounded calendar: "add a 4pm meeting with Y tomorrow"
  - bounded message: "send 'on my way' to Mike" (recipient + content both given)
  - pure state query: "battery?", "what time?", "focus mode?", "current tab?"
  - bounded file write: "write 'X' to /tmp/y.txt"

When ambiguous, prefer complex=true — the agent path can degrade to a single
action; the direct path can't escalate to research.

USER:
Ask: "<event.text>"
```

**Why one bit, not three classes**:
- A separate `fast_query` bucket would route to the same `system_status.get`
  /`safari_state.current_tab`/`applescript_calendar.list_today` adapters that
  `simple_action` would. The planner already picks the right tool from the
  pruned catalog — the classifier doesn't need to pre-select.
- A `schema` field would constrain CC's structured output, but CC's brief
  already pins the schema (`actions[]` + optional `phase_done`/`next`). One
  fewer decision means less classifier surface to drift.

**Model** — currently `gpt-5.2` (Cortex already has an OpenAI key). Swap to
a haiku alias via `CORTEX_CLASSIFIER_MODEL=claude-haiku-…` once an Anthropic
API key is plumbed (haiku ≈ $0.0001/call + sub-second; gpt-5.2 ≈ $0.001/call).

**Defensive failure mode** — any error (parse / API / network) returns
`complex=True`. Agent path handles simple asks too (slower); direct path can't
escalate. Fail-closed to capability.

**Verified e2e 2026-05-25**:
- `"battery?"` → complex=false, latency 1.5s → v0.5 simple path → preview_action
- `"look at my last Kao email and propose a reply"` → complex=true, latency 1.3s → agent dispatch + tmux session live

---

## 7. Migration phases

| Phase | Scope | Status |
|---|---|---|
| **5a** | New `claude_code.agent` action in Tool Agent with stream-json subscription + distillation | ✅ done 2026-05-25 |
| **5b** | Glass protocol: `agent_progress`/`progress_feedback` event handlers + filler/substantive classifier + HUD progress ticker render | ✅ done 2026-05-25 |
| **5c** | Auto-routing classifier (one LLM call ahead of planner; `complex=true` → shared `_dispatch_complex_agent`) | ✅ done 2026-05-25 |
| **5d** | Mid-flight correction wire-up | ⤳ **mitigated by 5f** — multi-phase checkpoint pattern provides reliable phase-boundary correction; free-form mid-thinking send_keys remains best-effort |
| **5e** | Output schema enforcement (`actions[]` array) + executor mapper + multi-row preview card + SEND iterates | ✅ done 2026-05-25 |
| **5f** | Multi-phase checkpoint pattern (`phase_done`/`next` → ⏸ blocking card → `agent_continue` resumes same tmux) | ✅ done 2026-05-25 — see §5b; verified `multi_phase_e2e.py` (1 checkpoint + 1 final, 28s, 11 progress events) |
| **5g** | Prune `AVAILABLE_TOOLS` catalog to executor + bounded-state-query set (10 tools, 11 actions); keep adapter code for regression safety | ✅ done 2026-05-25 |
| **5h** | **3-button card contract** (Approve / Modify / Kill). Server enforces; client renders exactly 3; classifier maps free-text feedback to same outcomes. | ✅ done 2026-05-26 |
| **5i** | **Modify-on-FINAL resume**: when user clicks Modify on an agent FINAL card (after tmux killed at end_turn), spawn fresh tmux with `claude --resume <prior_cc_session_id>` so CC rehydrates its prior research. Revised draft in ~10-15s vs full re-research. Deterministic seek via user-message marker. | ✅ done 2026-05-26 |
| **5j** | **Twin v2**: 4-slot layout (`identity.md` / `people/core/<slug>.md` / `receipts/<date>.md` / `.claude/skills/<name>/SKILL.md`); minimal frontmatter; placeholders removed; `~/constellation/twin/README.md` is the contract agents read before writing; legacy `skills/` migrated/deleted; `_system/confirm-policies.md` is Cortex runtime config (moved out of skills/). | ✅ done 2026-05-26 |
| **5k** | **Auto-distiller** ([cortex.distiller.Distiller](../../../Constellation-Server/cortex/cortex/distiller.py)): background process triggered after Modify decisions accumulate (`DISTILL_MIN_MODIFIES=2`, `DISTILL_COOLDOWN=30min`). Reads recent learning queue entries, dispatches CC agent with custom distillation brief, surfaces preview_action card only when stable pattern emerges. End-to-end run on a real learning_queue identified a 3× correction pattern (reminders shouldn't carry notes section) and proposed updating `reminder-style/SKILL.md`. Soft `distiller_quiet` progress when no pattern emerges. `/api/dev/distill_now` for forced testing. | ✅ done 2026-05-26 |
| **5l** | **Long-lived CC per HUD session (P0.1)**: tmux is kept alive after FINAL (`keep_alive_on_final` flag). The next invoke in the same HUD session routes through `agent_continue` paste into the live TUI instead of spawning a fresh CC. **20.9s cold → 10.9s reuse (-47.7%).** 30-min TTL via `_active_hud_session_tmux` registry. Modify-on-FINAL prefers the live tmux too; `--resume` spawn is the TTL-expired fallback. | ✅ done 2026-05-26 |
| **5m** | **R-3 multi-step machinery ripout (P1.1)**: deleted `_advance_task`, `task_history`, `task_continues`, `MAX_TASK_ROUNDS`, related helpers. Replaced with one-shot `_replan_with_feedback` for Modify-on-simple-path + `ResumeFailed` fallback. Multi-step is now strictly CC's job (via checkpoint pause / agent_continue). | ✅ done 2026-05-26 |
| **5n** | **Per-session cost/latency rollup (P0.3)**: `current_session_id` ContextVar in `sessions.py`. LLM observer forwards calls to `sessions.append(kind="llm_call", ...)`. Index entries include `llm_latency_ms`, `llm_by_purpose`, `n_tool_uses`, `total_wallclock_ms`. Web Sessions list + detail surface the rollup. | ✅ done 2026-05-26 |
| **5o** | **Phase 7a Insight Engine skeleton (P1.4)**: `cortex/insight_engine.py` periodic loop, `Insight` type with dedup_key + cooldown, hud_show surface (info-only — must not interrupt agency). Default OFF via `CONSTELLATION_INSIGHT_ENGINE=1`. Starter provider `upcoming_reminders_provider`. `/api/dev/insight_tick` for forced testing. `applescript_reminders.list` returns ISO due dates. | ✅ done 2026-05-26 |
| **5p** | **Session archive filter + HUD search (P2.1+P2.6)**: `/api/sessions?status=active|archived|killed|all`. Sessions >7 days old derive `archived: true`. Web Sessions has filter chips + text search (title + session_id). | ✅ done 2026-05-26 |

**All Phase 5 sub-phases landed.** Implementation lives across two repos:
- `Constellation-Server`: cortex/{classifier,server,router,http,agent_brief,distiller,sessions}.py +
  tool-agent/tool_agent/adapters/claude_code.py
- `Constellation-Console`: web/edge HUD progress ticker + preview card rendering + Sessions / Claude Code archive UI

What's next: see the roadmap for the P0/P1/P2 roadmap. **Before any architecture refactor, read [ARCHITECTURE-REFLECTION.md](../constitution/ARCHITECTURE-REFLECTION.md)** for honest critique of what's brittle / over-engineered.

---

## 8. What about v0.5 selector

It survives but with a narrower role: **pick which Twin slices to INLINE
into CC's brief** (so CC doesn't waste turns re-reading identity/style
files). Same TOC + same first-pass LLM, just the consumer changes from
Router → CC's brief.

For the simple/query path, no selector — those paths don't need Twin.

---

## 9. Cost & latency model

| Path | LLM cost | Latency-to-first-update | Total wall-clock |
|---|---|---|---|
| fast_query (battery)        | ~$0.0001 (haiku classifier) | < 200ms | < 1s |
| simple_action (reminder)    | ~$0.0001 (haiku) | < 200ms (preview) | < 2s (after SEND) |
| complex (Kao example)       | ~$0.10 (CC opus + haiku) | < 1s (first stream event) | 15-30s |
| complex with corrections    | +$0.01 per correction round | live | extends total |

Note: v0.5 averaged ~$0.05 + 8-12s for any non-trivial ask. v2 is comparable
in cost, faster in latency-to-first-visible-action, and far better at long
research tasks (which v0.5 couldn't really do at all without 5-round breaks).

---

## 10. Test cases (per Zack's "deep test" directive)

Will run after 5a–5f land:

1. **Kao multi-tool** (the original) — Mail search + project lookup + CC
   session read + draft + reminder. **MUST have a mid-flight correction**
   that the agent honours.

2. **Fast query** — "电池多少" — verify CC NOT invoked (haiku classifier
   only).

3. **Simple action** — "提醒我 5 点喝水" — verify single executor adapter
   dispatched after preview SEND.

4. **Complex, no Twin** — "什么时候是日落，给我加个出门 reminder" — CC
   uses web to look up sunset, then proposes reminder. Validate `actions[]`
   schema.

5. **Correction redirects mid-task** — start a Kao-like task, halfway
   through say "skip the email, just remind me to follow up tomorrow" —
   verify final preview has only reminder action.

6. **Hard stop** — say "stop, cancel that" — verify CC killed, no actions
   in preview, no side effects.

7. **Schema violation** — induce CC to emit malformed JSON — verify
   Cortex falls back to a recoverable error card, not silent failure.

---

## 11. Out of scope (this revision)

- Removing the executor adapter code entirely (keep dormant for safety)
- Migrating to a single LLM for both classifier + agent (latency dies)
- Replacing CC with the Anthropic SDK directly (CC's pre-built tool harness
  is what we want)
- Custom Cortex-side parsing of CC's pane (stream-json is the source of
  truth; pane is for human debugging via console)
- Multi-CC-agent orchestration (single agent per invoke for now)

---

*End of AGENT-ARCHITECTURE V2. Phase 5a starts immediately.*
