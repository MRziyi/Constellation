# Agent Architecture v2 — Streaming CC Agent + Mid-flight Correction

**Status**: design ✓ (2026-05-25) ⇒ implementation in progress
**Supersedes**: DESIGN.md §"Cortex Router" planning model. Router demoted to
classifier; CC promoted to primary agent. v0.5 selector role narrows.
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

## 5. Brief template

What Cortex sends to CC:

```
You are operating as Zack's hands-free agent. He just said:

  "<event.text>"

NOW: <iso timestamp + tz>
PHOTO: <attached/none>

YOUR JOB
Do whatever research / reading / composition this requires, using osascript,
shell, file ops, and your existing tools. When ALL info is in hand, emit the
JSON described below.

CONTEXT (inline; you don't need to re-read these)
  === identity.md ===                # only if selector picked it
  <content>
  === skills/email-style.md ===     # selector-picked
  <content>
  === people/core/<x>.md ===        # selector-picked
  <content>

ALSO available to read on demand:
  ~/constellation/twin/             # whole twin via --add-dir
  ~/Code/Projects/                  # via --add-dir
  ~/.claude/projects/               # via --add-dir
  Mail.app, Reminders.app, Calendar.app, Messages.app, Notes.app, Shortcuts.app
  (via `osascript -e 'tell application ... to ...'`)

OUTPUT SCHEMA (you'll be validated against this)
<inline JSON schema for the picked output shape>

CORRECTION
If at any point a new user message appears in your stream from "user", that
is Zack speaking to you in real time. Adjust course; don't ask him to repeat.

DO NOT execute side-effecting actions (osascript Mail send, Reminders add,
calendar add, fs write outside /tmp, imessage send) yourself. Cortex's HITL
gate runs on the JSON you return. Your job is to PROPOSE the actions, not
to do them.
```

That last paragraph is critical. CC has the *capability* to send the email
itself; we tell it not to. The structured output is the contract that
keeps the preview gate intact.

---

## 6. Classifier — Cortex's only remaining LLM call

A tiny gpt-haiku call (was gpt-5.2 router):

```
SYSTEM:
You are Cortex's intent classifier. Output JSON: {kind, schema}.

kind ∈ {
  "fast_query",        # state lookup (battery, focus, time, frontmost app)
  "simple_action",     # one explicit side effect with all details given
  "complex"            # anything requiring reading, searching, composing,
                       # reasoning across data, OR multiple side effects
}

schema (only if kind="complex") ∈ {"actions", "single_email", "single_reminder", ...}
                       # determines what CC's --json-schema enforces

USER:
Ask: "<event.text>"

Examples:
  "battery?" → {kind: "fast_query"}
  "remind me to drink water at 3pm" → {kind: "simple_action"}
  "send 'on my way' to Mike" → {kind: "simple_action"}
  "find emails from Kao about project and reply" → {kind: "complex", schema: "actions"}
  "look at my last CC session and summarize" → {kind: "complex", schema: "actions"}
```

~300 token call, sub-second latency on haiku. Cheap enough to be on every
invoke.

---

## 7. Migration phases

| Phase | Scope | Effort |
|---|---|---|
| **5a** | New `claude_code.agent` action in Tool Agent with stream-json subscription + distillation | 1d |
| **5b** | Glass protocol: add `progress` frame; Cortex forwards distilled events; web HUD renders progress timeline | 0.5d |
| **5c** | Cortex Router rewrite as classifier; pluck the "complex" path through new agent action; KEEP simple/query path through existing adapters | 0.5d |
| **5d** | Mid-flight correction wire-up (user voice → CC stdin) | 0.5d |
| **5e** | Output schema enforcement + preview card rendering from `actions[]` array | 0.5d |
| **5f** | E2E test on Kao-style example WITH a planted mid-flight correction; measure: latency-to-first-progress, total wall-clock, correction-honoured, structured-output-valid | 0.5d |
| **5g** | Doc + commit + retire dead Router code | 0.5d |

Total: ~4 days focused work.

This turn we do: **5a + partial 5b** (the streaming + distillation
prototype with a smoke test). Subsequent turns finish the rest.

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
