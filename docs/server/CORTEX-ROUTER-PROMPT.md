# Cortex Router — GPT Prompt Design

**Version**: v0.4 (frozen 2026-05-24); **Router role narrowed by [AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md) §6 as of 2026-05-25**
**Status**: 实现同步 — router.py SYSTEM_PROMPT 是 ground truth；本文档跟它对齐. **gpt-5.2 default + v0.4 density pass + Phase 5g catalog prune (50+ actions → 11) + diskcache via [llm_cache.py](../../../Constellation-Server/cortex/cortex/llm_cache.py)**
**关联文档**: [DESIGN.md](../constitution/DESIGN.md) · **[AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md)** · [PROMPT-DESIGN-V2.md](PROMPT-DESIGN-V2.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) · [DATA-MODEL.md](DATA-MODEL.md) · [SOURCE-OF-TRUTH.md](../constitution/SOURCE-OF-TRUTH.md)
**Last updated**: 2026-05-25 (added V2 supersedes banner)

> ⚠ **Reader pointer (2026-05-25)**: After Phase 5 v2 + Phase 5c + Phase 5g:
> - **A new classifier runs ahead of the Router** ([`cortex/cortex/classifier.py`](../../../Constellation-Server/cortex/cortex/classifier.py)). One sub-second JSON call: `{complex: bool, why: str}`. `complex=true` → bypass Router entirely → `claude_code.agent` dispatch with brief from `cortex.agent_brief`. `complex=false` → existing v0.5 selector + Router planner path.
> - **Router's job shrank to bounded single-call asks**. Catalog pruned from 11 tools / 50+ actions to **10 tools / 11 actions** (reminders.add, calendar.add_event/list_today, mail.send, fs.write, system_status.get, safari_state.current_tab, apple_shortcuts.run, imessage.send, echo, claude_code.agent). All composition / search / multi-step lives in the agent path now.
> - **R-3 multi-step is deprecated** — `task_continues` machinery still exists in code for backward compat but the catalog can't really express asks that need it anymore. Multi-step happens in the agent path via the **multi-phase checkpoint pattern** ([V2 §5b](AGENT-ARCHITECTURE-V2.md)).
> - **`result_format=draft`** is legacy. The SYSTEM_PROMPT no longer teaches it; the validator still permits it for backward compat.
>
> The §1 SYSTEM_PROMPT below + §2 user prompt template are still the right shape for what the Router does NOW (single-round bounded dispatch). The "MULTI-STEP" and "FREE-FORM FEEDBACK" sub-blocks describe machinery that's vestigial under V2. Treat them as historical.

Cortex Router 是 Cortex Agent 的"决策核心"——每个 event 进 Event Bus 后，Router 调 GPT API 输出 **dispatch plan** (JSON)，Cortex 据此发 RPC 到 Tool Agent，最终结果渲染到 Glass HUD。

这份文档是 **Router GPT prompt 的设计 ground truth**：system prompt + user prompt 模板 + few-shot examples。**v0.2 起，[cortex/cortex/router.py](../../../Constellation-Server/cortex/cortex/router.py) 的 `SYSTEM_PROMPT` 是真正可执行的 source；本文档跟它语义同步**。

---

## 1. System Prompt (固定，每次 LLM 调用都带)

```
You are Cortex Router, the brain of "Constellation" — Zack's personal AI agent system.

ROLE
You take in an event (user voice intent, tool reverse-wake, or Cortex self-pulse), read the
relevant slices of Zack's Digital Twin (a markdown library describing how AI should act as
Zack), and output a dispatch plan as JSON. The plan gets executed by Tool Agent on Zack's
Mac mini; results render on his AR-glass HUD.

PRIMARY DIRECTIVES (non-negotiable)

1. NEVER auto-execute side-effecting actions without preview. Every dispatch plan with a
   mutating subtask MUST set requires_confirm=true OR explicitly rely on
   Twin/skills/confirm-policies.md for auto-approval. HITL is non-negotiable.

2. ONLY use tools listed in AVAILABLE TOOLS. Never invent. Never use a tool/action not
   listed. If you need a capability that doesn't exist, return primary_intent="unsupported"
   with a reasoning that names the missing capability.

3. OUTPUT valid JSON matching the schema. No prose, no commentary, no markdown fences.
   Pure JSON only. The downstream parser is strict.

4. PRESERVE the user's intent precisely. If they say "casual", make it casual. If they say
   a name, treat it as a stable reference to that person.

5. PREFER concise plans. The minimum number of subtasks that does the job.

DEFAULTS

- Confirm policy: when in doubt, set requires_confirm=true.

- HUD response kinds:
  - "preview_action" — there's something for Zack to approve (email draft, calendar add, etc.)
  - "hud_show" — pure information (query result, face match, status)
  - "tool_card" — pass-through for tool reverse-wake (P4)

- result_format semantics (CRITICAL):
  - "query"   — read-only lookup; no side effects.
  - "draft"   — tool produces a TEXTUAL artefact (email body, code snippet) WITHOUT touching
                the system. Only valid for tools with explicit draft semantics:
                claude_code.draft, applescript_mail.draft.
  - "execute" — tool runs and causes its real side effect (add reminder, send email,
                add calendar event). ALL side-effecting actions use "execute" with
                requires_confirm=true. The HUD preview body renders from your body_template
                BEFORE the user taps SEND; the side effect happens AFTER. Never use "draft"
                for an action like applescript_reminders.add — it has no draft semantics.

- Date / time fields in args: emit ISO 8601 ("2026-06-02T15:00:00"). Resolve natural
  references ("next Tuesday", "tomorrow") against the NOW value from USER STATE. Tool
  adapters parse ISO; AppleScript rejects natural-language strings.

- Contact lookups: when the user names a person by first name ("reply to Jane"), search
  TWIN CONTEXT PACK for `people/core/<slug>.md` whose `aliases:` or filename matches.
  Extract `email:` / `phone:` from frontmatter for the `to` arg. Never invent an address.
  If no match, return primary_intent="unsupported" naming the missing contact.

OUTPUT SCHEMA (strict)

{
  "primary_intent": "kebab-case-label",
  "subtasks": [
    {
      "tool":   "<must match an AVAILABLE TOOLS entry exactly>",
      "action": "<must match an action of that tool>",
      "args":   { ... tool/action-specific ... },
      "context_pack": [],
      "result_format": "draft" | "execute" | "query",
      "requires_confirm": true | false | null
    }
  ],
  "hud_response": {
    "kind":          "preview_action" | "hud_show" | "tool_card",
    "icon":          "one of: ✉ ⌖ ⚙ ✦ ✓",
    "title":         "...",
    "body_template": "markdown; use {{subtasks[i].result.field}} for interpolation",
    "options":       ["1-4 button labels"]
  },
  "reasoning": "one sentence",

  // ── Multi-step (optional; default both null/false) ──
  "task_continues": true | false,   // true = this is an intermediate step; another plan will follow
  "next_step_hint": "..."            // free-text hint to YOURSELF for the next round
}

JSON ONLY. No prose. No markdown fences.
```

### 1.1 MULTI-STEP TASK PATTERN (per SoT R-3 / C-20)

Some user intents can't be done in one plan because they need user judgment in the middle.
Example: "find my meeting time with 云 from recent emails, add a reminder, then write a
reply" — can't add the reminder until the user has confirmed the extracted meeting time,
can't write the reply until the user has decided the new proposal.

For such an intent OUTPUT A FIRST-STEP PLAN with:
- `task_continues: true`
- `subtasks`: ONLY read-only (`query` / `draft`); NEVER `execute` in an intermediate step
- `hud_response.body_template`: render findings clearly so user can judge them
- `hud_response.options`: sensible defaults (e.g. `["Proceed", "Edit", "Cancel"]`)
- `next_step_hint`: a sentence telling FUTURE-YOU what to do after the user confirms

Cortex then YIELDS a HUD card to the user. The user responds (tap default option OR speak
freely — see §1.2). Cortex re-invokes you with prior step's results + user response
inlined as PRIOR TASK HISTORY + USER FEEDBACK. You output the next step's plan.

Maximum 5 rounds per task. After round 5 set `task_continues: false`.

If the intent IS doable in one plan (simple intents like "add reminder X"), DON'T use
multi-step. Single-shot plans are faster and cheaper.

### 1.2 FREE-FORM FEEDBACK INTERPRETATION (when USER FEEDBACK present)

The user spoke freely instead of (or in addition to) tapping a default option. Per SoT C-22,
the Glass mic is always-on when a card is showing, so the user can freely substitute voice
for any option tap. Their `feedback_text` could mean any of FOUR things — judge from content:

| Category | Examples | Action |
|---|---|---|
| **(a) CONFIRM** | "yes" / "对" / "ok proceed" / "go ahead" | Follow prior `next_step_hint` as planned. |
| **(b) CORRECTION** | "no it was 5/31 not 5/29" / "actually the meeting is at 4pm not 3pm" | Redo CURRENT step or recompute affected values using the correction. Don't blindly advance. |
| **(c) SKIP** | "skip the reminder" / "don't bother with X" / "that's all I needed" / "stop there" | DO NOT execute the skipped action. Output a TERMINAL plan: `hud_show` + `task_continues:false` + empty subtasks + brief acknowledgment body. User's verbal SKIP is **authoritative** — never go ahead "just in case". |
| **(d) INJECT-INFO** | "the meeting is Thursday 4pm" (when you couldn't find it yourself) | Use the user-supplied value as ground truth. Advance with it. |

Use both `task_history` AND `feedback_text` to decide. If feedback is ambiguous, treat as
(a) CONFIRM and proceed; user can always feedback again.

### 1.3 HUD BODY DESIGN

Every HUD card is an INFO card with a yield point — not a "yes/no" question. Per SoT C-21:

- `body_template` MUST carry enough information for the user to judge: what you found,
  what you plan to do next, key parameters they might want to change.
- `options` are ergonomic shortcuts (ring tap); NOT the only response channel. Glass mic
  is always-on when a card is showing; user can speak freely.
- Don't write "Send?" / "Proceed?" — write the actual content. Example:

  | Bad | Good |
  |---|---|
  | `body="Send the reply to Jane?"` | `body="Reply ready (3 sentences):\n\nHey Jane —\n\nI'll be there at 3.\n\n— Zack"` |
  | `body="Add reminder?"` | `body="Reminder: meeting with 云, due 5/29 14:00 (from email 'CHI draft sync')"` |

- For multi-step intermediate steps: body makes discovered facts EXPLICIT so user has
  something concrete to confirm / correct / skip with.

---

## 2. User Prompt Template (v0.3 — natural-language brief, token-efficient)

Per Zack 2026-05-24: "**不要暴力地把 JSON 塞给它**，而是组织成可读的". v0.3 rewrites the user prompt as a human-readable brief composed by `cortex/cortex/router._build_user_prompt()`. Key principles:

- **No event IDs**, no timestamps, no opaque hashes — Router doesn't need them; they waste tokens
- **Compact `task_history`** — one-line summaries per subtask, not full JSON dumps
- **Natural prose section headers** ("THE ASK", "WHAT HAPPENED ALREADY", "ZACK'S WORDS ON THE PRIOR CARD", "ZACK'S DIGITAL TWIN", "YOUR TOOLS", "YOUR JOB")
- **Reasoning preamble allowed** — Router may think in plain text (2-4 sentences) before emitting JSON in a ```json``` fence; `parse_json_response` extracts the fence

### Block layout (every section is conditional except THE ASK and YOUR TOOLS/JOB)

```
THE ASK
Zack just spoke to his glasses. He said: "<text>"
A photo is attached (the glass camera captured the scene).  | No photo attached.
NOW: 2026-05-24 15:48 (CDT)

[WHAT HAPPENED ALREADY]                     # only on multi-step continuation
You're planning round N of an ongoing multi-step task. The ASK above is Zack's
original intent. Earlier rounds (oldest first):

Round 1 — "primary_intent"
  · tool.action(result_format) → compact result snippet
  · Your note for this next round: "next_step_hint"
  · Zack responded: spoke freely — "feedback text" (he tapped feedback)
                   OR ring-tap default (send)

Round 2 — ...

[ZACK'S WORDS ON THE PRIOR CARD]            # only when user spoke freely
He spoke freely (mic is always on): "<feedback_text>"
Classify per FREE-FORM FEEDBACK in your system prompt: (a) confirm / (b) correction
/ (c) skip / (d) inject-info. Then shape the next plan.

[ZACK'S DIGITAL TWIN]                       # eager-loaded identity + skills + people/core
=== identity.md ===
<content>
=== skills/email-style.md ===
<content>
=== people/core/jane-doe.md ===
<content>
...

YOUR TOOLS
echo                     actions: echo
applescript_reminders    actions: add, list, complete, delete
... (12 enabled adapters, per AVAILABLE_TOOLS dict in router.py)

YOUR JOB
Plan one round. Think briefly in plain text first if it helps you (2-4 sentences
max), then emit the dispatch plan as JSON inside a ```json code fence. Cortex
parses only the JSON; your reasoning is logged for later analysis.
```

### Compact subtask summary (for `task_history`)

Instead of full JSON dump per subtask, `_summarise_subtask_for_history` produces one line:

| Result shape | Rendered as |
|---|---|
| `{"text": "..."}` | `text(N chars): "first 120 chars..."` |
| `{"items": [...]}` | `items×N (e.g. ('first_key', first_val))` |
| `{"answer": "..."}` | `answer: "first 160 chars..."` |
| `{"content": "..."}` | `content(N chars): "first 120 chars..."` |
| `{"error": ...}` | `ERROR: ...` |
| anything else | truncated JSON |

This cuts task_history from ~2 KB/round (v0.2) to ~300 B/round.

### Token budget (v0.4 measured, chars→tokens ≈ ÷4)

For a typical Phase 2 call (UC1 single-shot):
- System prompt: 3.6 K chars / ~900 tokens (v0.3 was ~5.3 K / 1.4 K tokens)
- TWIN CONTEXT PACK (identity + 9 skills + 2 people/core): ~8 K tokens (unchanged)
- AVAILABLE TOOLS (12 adapters): 3.3 K chars / ~830 tokens (v0.3 was ~4.9 K / 1.2 K)
- THE ASK + NOW: ~50–200 tokens
- task_history per round (compact): ~80–200 tokens
- USER FEEDBACK block: ~60 tokens
- **Total**: ~9–11 K tokens input (v0.3 ~10–12 K; v0.2 ~13–16 K)

v0.4 ≈ 12-15% additional reduction on top of v0.3, achieved by:
- Removing implementation-detail prose (`"HUD body renders BEFORE the user taps SEND…"`)
- Folding redundant rules (e.g. `"draft has no semantics for X"` now implied by the
  draft entry's own enumeration of valid tools)
- Cutting user-prompt preambles that restate section meaning (`"Identity, skills, and core
  contacts. Honor them when planning:"`, `"You're planning round N of an ongoing…"`)
- Compacting the multi-line per-step subtask history into single `R<i>` lines
- Trimming AVAILABLE_TOOLS descriptions to keep routing-relevant semantics only (mail
  reply-vs-compose modes preserved; "Use to peek at READMEs before claude_code" usage
  hint removed)

See [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) for per-tool action contracts.

### LLM caching ([llm_cache.py](../../../Constellation-Server/cortex/cortex/llm_cache.py))

All Router LLM calls go through `cached_chat_create()` which:
- diskcache backed at `~/constellation/cache/llm/` (persists across daemon restarts)
- Cache key = md5(provider, model, messages, response_format)
- 3-retry with exponential backoff (1s, 2s, 4s) on transient errors
- Telemetry hook (`set_call_observer`) for session-level logging
- Same chokepoint used by `twin_query` adapter (shared cache)

In dev / repeated tests, identical prompts → instant cache hits. Different task contexts naturally produce different cache keys (Zack confirmed 2026-05-24: "不同任务时候，因为我 context 不同，肯定不会命中旧的缓存").

---

## 3. Few-Shot Examples

The implementation runs **zero-shot** (no inline few-shots) — system prompt + USER PROMPT is enough at GPT-5.4 quality. The examples below are documentation only; they show the Router's expected output shape across canonical scenarios.

### Example 1 — UC1 simple email reply (single-shot)

**Event**: `user_invoke {text: "reply to Jane, I'll be there at 3, casual"}`
**Twin in context_pack**: identity.md, skills/email-style.md, people/core/jane-doe.md

**Output**:
```json
{
  "primary_intent": "email_reply_to_jane",
  "subtasks": [
    {
      "tool": "applescript_mail", "action": "send",
      "args": {
        "reply_to_current": true,
        "body": "Hey Jane —\n\nI'll be there at 3.\n\n— Zack"
      },
      "result_format": "execute", "requires_confirm": true
    }
  ],
  "hud_response": {
    "kind": "preview_action", "icon": "✉",
    "title": "Reply to Jane",
    "body_template": "Hey Jane —\n\nI'll be there at 3.\n\n— Zack",
    "options": ["Send", "Edit", "Cancel"]
  },
  "reasoning": "Casual reply per Jane's preference for brevity + Zack's email-style sign-off."
}
```

### Example 2 — Multi-step (云 email scenario per SoT R-3 trigger)

**Round 1 Event**: `user_invoke {text: "看前两天给云的邮件找 meeting 时间，加 reminder，再写邮件告诉她我准备好下周下午约"}`

**Round 1 Output**:
```json
{
  "primary_intent": "meeting-prep-with-yun",
  "subtasks": [
    {
      "tool": "applescript_mail", "action": "find_messages",
      "args": {"participant": "云", "mailbox": "both", "limit": 10},
      "result_format": "query"
    },
    {
      "tool": "claude_code", "action": "draft",
      "args": {
        "prompt": "From these emails {{subtasks[0].result.items}}, extract the meeting time I mentioned to 云. Return JSON {meeting_iso, summary, message_id}."
      },
      "result_format": "query"
    }
  ],
  "hud_response": {
    "kind": "preview_action", "icon": "✉",
    "title": "Found meeting with 云",
    "body_template": "{{subtasks[1].result.summary}}\nTime: {{subtasks[1].result.meeting_iso}}\n\nProceed to add reminder + draft reply?",
    "options": ["Proceed", "Edit time", "Cancel"]
  },
  "reasoning": "Need to surface the extracted meeting time for user judgment before any side-effecting action.",
  "task_continues": true,
  "next_step_hint": "after user confirms meeting_iso (or corrects via feedback), add applescript_reminders for that time, then applescript_mail.send reply to 云 saying ready for next week afternoon. Use message_id from round 1 for reply."
}
```

**Round 2 Event** (after user SEND): same `user_invoke` payload but Cortex re-invokes with PRIOR TASK HISTORY containing round-1 results.

**Round 2 Output**:
```json
{
  "primary_intent": "meeting-prep-with-yun-execute",
  "subtasks": [
    {
      "tool": "applescript_reminders", "action": "add",
      "args": {"title": "meeting with 云", "due": "2026-05-29T14:00:00"},
      "result_format": "execute"
    },
    {
      "tool": "claude_code", "action": "draft",
      "args": {"prompt": "Draft reply to 云 in Zack's casual style: ready to meet, propose times next week afternoon. 2-3 sentences."},
      "result_format": "draft"
    },
    {
      "tool": "applescript_mail", "action": "send",
      "args": {
        "reply_to_message_id": "<message_id from round 1>",
        "body": "{{subtasks[1].result.text}}"
      },
      "result_format": "execute", "requires_confirm": true
    }
  ],
  "hud_response": {
    "kind": "preview_action", "icon": "✉",
    "title": "Reminder + Reply ready",
    "body_template": "Reminder: meeting with 云 @ 5/29 14:00 ✓\n\nReply draft:\n\n{{subtasks[1].result.text}}",
    "options": ["Send all", "Edit reply", "Cancel"]
  },
  "reasoning": "User confirmed meeting time; now add reminder + send reply per next_step_hint.",
  "task_continues": false
}
```

### Example 3 — Multi-step with free-form CORRECTION feedback

Same setup as Example 2 round 2, but instead of SEND, user said: "actually make the
reminder 4pm not 14:00"

**Re-invocation Output**:
```json
{
  "primary_intent": "meeting-prep-with-yun-corrected",
  "subtasks": [
    {
      "tool": "applescript_reminders", "action": "add",
      "args": {"title": "meeting with 云", "due": "2026-05-29T16:00:00"},
      "result_format": "execute"
    },
    { "tool": "claude_code", "action": "draft", "...": "(unchanged)" },
    { "tool": "applescript_mail", "action": "send", "...": "(body interpolated)" }
  ],
  "hud_response": {
    "kind": "preview_action", "icon": "✉",
    "title": "Reminder + Reply (updated time)",
    "body_template": "Reminder: meeting with 云 @ 5/29 16:00 ✓ (was 14:00)\n\nReply draft:\n\n{{subtasks[1].result.text}}",
    "options": ["Send all", "Edit", "Cancel"]
  },
  "reasoning": "User correction (b): recomputed due time to 16:00 per feedback.",
  "task_continues": false
}
```

### Example 4 — Multi-step with free-form SKIP feedback

User mid-task said: "skip the reminder, just send the email"

**Output**:
```json
{
  "primary_intent": "meeting-prep-skip-reminder",
  "subtasks": [
    { "tool": "claude_code", "action": "draft", "...": "(reply only)" },
    { "tool": "applescript_mail", "action": "send", "...": "(...)" }
  ],
  "hud_response": {
    "kind": "preview_action", "icon": "✉",
    "title": "Reply ready (reminder skipped)",
    "body_template": "Skipped: reminder add (per your request).\n\nReply draft:\n\n{{subtasks[0].result.text}}",
    "options": ["Send", "Edit", "Cancel"]
  },
  "reasoning": "User skip (c): dropped reminder subtask, kept email send.",
  "task_continues": false
}
```

### Example 5 — UC2 reverse-wake (Tool Agent → Cortex event)

**Event** (Tool Agent push, not user-initiated):
```
EVENT
  kind: tool_reverse_wake
  payload: {
    from_tool: claude_code,
    wake_kind: permission_request,
    context: "echo 'hello from cc' > /tmp/cc-real-reverse-wake-test.txt\nDo you want to proceed?",
    session_id: "cc-f4c8526e71",
    options: [
      {id: allow_once,   label: "Allow once"},
      {id: allow_always, label: "Always allow"},
      {id: deny,         label: "Deny"}
    ]
  }
```

For reverse-wake events, **Cortex builds the tool_card directly without calling the Router**
(see [COMPONENT-DESIGN §1.5](COMPONENT-DESIGN.md) `_handle_tool_reverse_wake`). Router is only
invoked for `user_invoke` / `user_decision` events that need fresh planning. The example
above is shown for completeness; the Router doesn't see it.

### Example 6 — UC3 face match (deferred to Phase 6)

(See v0.1 of this doc for the original example; unchanged.)

### Example 7 — Trivial Quick Shortcut #3 (drop a thought)

**Event**: `user_invoke {text: "remind me to grab coffee with Mike next Tuesday at 3pm"}`

Single-shot:
```json
{
  "primary_intent": "add-reminder",
  "subtasks": [
    {
      "tool": "applescript_reminders", "action": "add",
      "args": {"title": "coffee with Mike", "due": "2026-05-26T15:00:00"},
      "result_format": "execute", "requires_confirm": true
    }
  ],
  "hud_response": {
    "kind": "preview_action", "icon": "✓",
    "title": "Add reminder",
    "body_template": "Reminder: **coffee with Mike**\nDue: **2026-05-26 3:00 PM**",
    "options": ["Add", "Edit", "Cancel"]
  },
  "reasoning": "Simple reminder add; reminder-style applied (no articles, first-name only)."
}
```

---

## 4. Prompt size budget

| Section | Tokens (typical) |
|---|---|
| System prompt (including §1.1-1.3) | ~1400 |
| User prompt template (template only) | ~200 |
| Twin context pack (eager: identity + 9 skills + N people) | 2000-6000 |
| Event payload | 50-500 |
| AVAILABLE TOOLS list (12 enabled adapters) | ~400 |
| PRIOR TASK HISTORY (round N, with truncation to 800 chars per subtask result) | 500 per round (cap ~2500 at round 5) |
| USER FEEDBACK | 100-300 |
| **Total input** | **4K – 12K typical** |

Phase 7 may switch context_pack to two-pass (let GPT pick paths from `_system/TOC.md`) when Twin grows past prompt window; currently eager-load is fine.

---

## 5. Error handling

GPT must return valid JSON matching the schema. The implementation (`route()` in router.py):

1. JSON parse fail → fallback plan `hud_show {body: "I didn't catch that — try again?"}`
2. Schema validation fail (unknown tool, bad result_format, etc.) → same fallback
3. OpenAI API error / network → same fallback
4. Multi-step exceeds 5 rounds → terminal `hud_show {body: "Task too long. Restate to start fresh."}`

All fallbacks are logged (`router.failed` / `task.max_rounds_reached`) for later prompt tuning.

---

## 6. Open Prompt Questions

| # | Question | Status |
|---|---|---|
| OQ-P1 | Should system prompt be split per event kind (user_invoke vs reverse-wake) | reverse-wake bypasses Router (see Example 5); no split needed |
| OQ-P2 | Few-shot inclusion — always / never / kind-conditional | v0.2: zero-shot works; revisit if quality drops |
| OQ-P3 | Confirm-policies.md format | YAML in skills file; Cortex enforces (see [COMPONENT-DESIGN §1.7](COMPONENT-DESIGN.md)) |
| OQ-P4 | How to inject "today / weather / battery" into context | partially done: USER STATE has `now`, `active_devices`. `system_status.get` provides battery/focus on demand. Full enrichment Phase 7. |
| OQ-P5 | Multi-step plans with conditionals (if subtask result is X, run subtask Y) | v0.2 solved via multi-step + Router re-invocation; no in-plan conditionals needed |
| OQ-P6 | Should Router know multi-step rounds-remaining budget | currently no; Router just knows max=5 from system prompt. If quality matters, add explicit `round_n_of_5` to USER STATE. |

---

## 7. Document Status

- **Version**: v0.3
- **Last updated**: 2026-05-24
- **Based on**: [router.py SYSTEM_PROMPT](../../../Constellation-Server/cortex/cortex/router.py) (live ground truth) + [llm_cache.py](../../../Constellation-Server/cortex/cortex/llm_cache.py) + Zack's prompt-organization + token-efficiency directives (2026-05-24)
- **Companion**: [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) for per-tool contracts; [COMPONENT-DESIGN.md §1.2-1.4](COMPONENT-DESIGN.md) for how plans flow into Cortex

### Revision Log

| Version | Changes |
|---|---|
| v0.1 | First version: system prompt + user prompt template + 7 few-shot examples (UC1/UC2/UC3 + reverse-wake + face + trivial) |
| v0.2 | Sync with router.py SYSTEM_PROMPT (live since Phase 2/R-3 landing). Major additions: result_format semantics block; ISO date discipline; contact lookup from people/core frontmatter; **§1.1 MULTI-STEP TASK PATTERN** (task_continues / next_step_hint per SoT C-20); **§1.2 FREE-FORM FEEDBACK INTERPRETATION** (4 categories a/b/c/d per SoT C-23); **§1.3 HUD BODY DESIGN** (cards are info+yield not yes/no per SoT C-21). User prompt template adds PRIOR TASK HISTORY + USER FEEDBACK blocks. AVAILABLE TOOLS list updated to 12 enabled adapters. Examples 2-4 added for multi-step. Prompt budget updated with multi-step overhead. v0.1 examples 5 (reverse-wake) clarified: Cortex builds tool_card directly, Router not invoked. Implementation runs **zero-shot** at GPT-5.4 quality — few-shots in this doc are documentation, not in the actual prompt. |
| v0.3 | **gpt-5.4 → gpt-5.2 default + token-efficient natural-language user prompt + diskcache layer**. §1 system prompt slimmed (terser directives, condensed sections); allow reasoning preamble + JSON in ```json``` fence (no `response_format=json_object` forcing); `parse_json_response` extracts fence + falls back to `json_repair`. §2 user prompt rewritten as **THE ASK / WHAT HAPPENED ALREADY / ZACK'S WORDS ON THE PRIOR CARD / ZACK'S DIGITAL TWIN / YOUR TOOLS / YOUR JOB** — no event IDs, no timestamps, no JSON dumps of payload. `task_history` rendered as one-line subtask summaries via `_summarise_subtask_for_history` (was full JSON dumps). New §"LLM caching" — all calls go through `cached_chat_create` (diskcache at `~/constellation/cache/llm/` + 3-retry exponential backoff + telemetry observer). Twin_query adapter also routes through the shared cache. **Per-call token usage cut ~25% measured.** v0.2 examples remain illustrative; nothing functionally renamed. |
| v0.4 | **Density pass — same coverage, ~30% shorter system prompt + tools block + user prompt.** Driven by Zack's read of v0.3 ("信息密度高，不啰嗦"). Edits all in [router.py](../../../Constellation-Server/cortex/cortex/router.py); zero schema / behaviour change; multistep_deep + uc1_wallclock semantics preserved. Specific cuts: ① SYSTEM_PROMPT: dropped standalone `ROLE` paragraph (folded into opening line); compressed `PRIMARY DIRECTIVES` → `RULES` (parens, "Cortex enforces it" implementation detail removed); merged the post-schema "you may think briefly…" paragraph into the OUTPUT line; cut `"HUD body renders BEFORE the user taps SEND…"` (implementation note that doesn't affect routing); RESULT_FORMAT entry for `draft` now self-describes which tools have draft semantics (was repeated as a separate sentence). ② AVAILABLE_TOOLS: per-tool descriptions trimmed to routing-relevant semantics. Mail's 7-line description compressed to 5 while preserving REPLY-vs-COMPOSE rules + account list; claude_code's 11-line description compressed to 6 while preserving Track A vs B split; removed "use BEFORE dispatching claude_code" / "等等" example bloat. ③ `_build_user_prompt`: `"Zack just spoke to his glasses. He said:"` → `"Zack said:"`; never emit `"No photo attached."` (no signal); compressed `WHAT HAPPENED ALREADY` to `(planning round N/5)` with `R1 — "..."` per round; dropped Twin block preamble (`"Identity, skills, and core contacts. Honor them when planning:"`); shortened YOUR JOB to one sentence. From single-shot 4.9 K → 3.5 K chars; system prompt 5.3 K → 3.6 K chars. |

### Known Router Quality Notes (Post-v0.3 testing)

gpt-5.2 with the new natural-language prompt produces strong single-shot plans (UC1 wall-clock still PASS) and correctly handles correction + skip feedback in multi-step (verified `multistep_deep.py` scenarios 1+2+3 Router decisions). **Observed quality regression**: gpt-5.2 is somewhat eager to set `task_continues=true` on rounds where v0.2's gpt-5.4 would have committed to a terminal plan — e.g., scenario 2's reminder-add round may emit "let me also list current reminders to double-check" instead of stopping at the add. Resolutions for future tuning:
- Tighter "task_continues=true ONLY when the next step needs user judgment that you can't predict" guidance in system prompt
- Or accept gpt-5.2's cautious style and let user's SEND end the chain naturally
- Test-side: scenarios run back-to-back can show state interleaving when prior task's background `_advance_task` continues past WSS close. Not a production issue (single user, single Glass connection).

---

*End of Constellation Cortex Router Prompt v0.3.*
