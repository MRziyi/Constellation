# Use Case Audit — Constellation v1

**Version**: v0.2 (pre-Phase-1 original v0.1 audit + post-R-3 addendum)
**Status**: 历史 audit + Post-R-3 re-audit
**关联文档**: [DESIGN.md](../constitution/DESIGN.md) · [CORTEX-ROUTER-PROMPT.md](../server/CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](../server/TOOL-ADAPTERS.md) · [DATA-MODEL.md](../server/DATA-MODEL.md) · [SOURCE-OF-TRUTH.md](../constitution/SOURCE-OF-TRUTH.md)
**Last updated**: 2026-05-24

Purpose: pressure-test the framework before Phase 1 implementation. Two parts:

1. **Original 3 UCs** (SoT §10) — verify they run on the current dispatch policy + architecture
2. **6 new cool UCs** — designed under the same framework, verify they pass

**Findings preview**: of 9 UCs audited, **8 pass** on current architecture; **1 partial** (UC3-D long-form transcript) is explicitly out of v1 scope per SoT N-3; **3 small fixes** recommended (Part 3).

---

## Part 1 — Original UC Audit

### UC1 · Email Reply (SoT §10.1)

**User intent (SoT 原话)**: 看到一封邮件，对眼镜说"回复，三个小时后开会，用英语礼貌" → Cortex 用 Claude Code 起草 → 眼镜预览 → SEND → 邮件出 + 苹果生态提醒

**Architecture trace**:

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | Glass | Voice Invoke (LP+SWIPE_UP) → photo + STT → `user_invoke {image, text: "回复这封邮件，三个小时后开会，用英语礼貌"}` | ✓ Phase 3 |
| 2 | Cortex Event Bus | Assigns `evt_001` | ✓ Phase 1 |
| 3 | Cortex Router | Reads Twin context_pack: `identity.md` + `skills/email-style.md` + (maybe) `people/core/{sender}.md` if sender is known | ✓ Phase 2 |
| 4 | Cortex Router | GPT call → dispatch plan (4 subtasks: `applescript_mail.read_current` → `claude_code.draft` → `applescript_mail.send` (preview) → `applescript_reminders.add` (auto)) | ✓ [CORTEX-ROUTER-PROMPT Example 1](../server/CORTEX-ROUTER-PROMPT.md) |
| 5 | Tool Agent | Run subtask 1 + 2 → returns draft | ✓ Phase 2 |
| 6 | Cortex | Build `preview_action` HUD card | ✓ Phase 2/3 |
| 7 | Glass | Render card → user SEND | ✓ Phase 3 |
| 8 | Tool Agent | Run subtasks 3 + 4 → mail sent + reminder added | ✓ Phase 2 |
| 9 | Cortex | Write `receipts/{date}.md` with full chain + CHANGELOG | ✓ Phase 1 |

**Verdict**: ✓ **PASS** on current architecture.

**Issue found** (small):

- User says "用英语礼貌" (English + polite). `skills/email-style.md` defaults say "casual" + warns against pleasantries. **Style conflict between user's intent and default skill.** Currently the Router prompt doesn't say which wins.
- **Fix A** (recommended): add to system prompt — "User's stated intent in the current utterance overrides default skill preferences when they conflict. Note conflict in `reasoning`."

---

### UC2 · Claude Code Two-Way Remote (SoT §10.2)

**User intent (SoT 原话)**: Claude Code 跑着，遇到权限问题 → 眼镜提示我允许 / 我也能问"做得怎么样了" → Cortex 查 CC 输出。**双向**：CC → 用户 + 用户 → CC。

UC2 has 3 sub-modes:

#### 2A. Reverse-wake (CC → user, permission request)

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | CC (in tmux) | Outputs `Do you want to write secrets/? (y/n)` | — |
| 2 | Tool Agent `claude_code` adapter | Regex match per `skills/claude-code-control.md` → emit `tool_reverse_wake` event | ✓ Phase 5 |
| 3 | Cortex Router | GPT call w/ wake event → outputs `tool_card` HUD response | ✓ [Example 4](../server/CORTEX-ROUTER-PROMPT.md) |
| 4 | Push notification (if Glass idle) → Glass wakes | ✓ Phase 5 |
| 5 | Glass | Renders P4 tool card with ONCE/SESSION/DENY options | ✓ Phase 3 |
| 6 | User taps ONCE → `user_decision` event | ✓ Phase 5 |
| 7 | Cortex Router (2nd pass) → dispatches `claude_code.send_keys` with `"y\n"` | ✓ Example 4 follow-up |
| 8 | CC continues | — |

**Verdict 2A**: ✓ **PASS**.

#### 2B. User query (user → CC, "how's it going")

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | Glass | Voice Invoke → `user_invoke {text: "how's the build"}` | ✓ Phase 3 |
| 2 | Cortex Router | Dispatches `claude_code.get_status` | ✓ [Example 3](../server/CORTEX-ROUTER-PROMPT.md) |
| 3 | Tool Agent | Returns last 10 lines + state | ✓ Phase 5 |
| 4 | Cortex | `hud_show` card with summary | ✓ |
| 5 | Glass renders | ✓ Phase 3 |

**Verdict 2B**: ✓ **PASS** — but with one constraint.

**Issue 2** (medium-importance constraint): **Tool Agent only knows about CC sessions it spawned**. If the user manually launches `claude` in Terminal outside Constellation, Tool Agent has no handle to it. This means:

- ✓ User starts CC via Voice Invoke ("用 CC 在 R08-dev 跑 refactor") → Tool Agent owns the session → `get_status` works
- ✗ User manually `claude` in iTerm → Tool Agent doesn't see it → `get_status` returns "no active sessions"

**Fix B** (recommended): make this constraint explicit in [TOOL-ADAPTERS.md §1](../server/TOOL-ADAPTERS.md) + [IMPLEMENTATION-PLAN Phase 5](IMPLEMENTATION-PLAN.md). User-facing: "If you want Cortex to remote-control Claude Code, launch it through Voice Invoke." (v2 may scan tmux globally for CC sessions, but v1 keeps the ownership model simple.)

#### 2C. User-initiated CC tasking ("用 CC 在某个目录跑 X")

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | Voice Invoke → `user_invoke {text: "用 Claude Code 在 R08-dev 重构 auth.ts"}` | ✓ Phase 3 |
| 2 | Cortex Router | Dispatches `claude_code.run(prompt, working_dir="R08-dev")` | ✓ |
| 3 | Tool Agent spawns tmux session, starts CC | ✓ Phase 2/5 |
| 4 | `preview_action` card BEFORE spawn (since `claude_code.run` is `preview-always` per [confirm-policies.md](../../../Constellation-Server/twin-seed/skills/confirm-policies.md)) | ✓ |
| 5 | User SEND → CC starts | ✓ |

**Verdict 2C**: ✓ **PASS**.

**Overall UC2 verdict**: ✓ **PASS** with one v1 constraint (Fix B).

---

### UC3 · Face Memory + Recall (SoT §10.3)

**User intent (SoT 原话)**: 拍人 + 语音备注存数据库；再次见面 → 拍 → 对比 → HUD 显示历史；聊天时开转写 → 同步到 Twin；某天想起 → 检索 + dispatch。

UC3 has 4 sub-modes:

#### 3A. Initial capture + annotation

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | Glass | Voice Invoke → `user_invoke {image, text: "这是 X，做 HCI Education，MIT"}` | ✓ |
| 2 | Cortex Router (1st pass) | Dispatches `local_face_recognition.match` to check if already known | ✓ Phase 6 |
| 3 | Tool Agent returns no match | — |
| 4 | Cortex Router (2nd pass) | Dispatches: `local_face_recognition.embed` + `fs.write memories/faces/{slug}/face-{ts}.jpg` + `fs.write memories/faces/{slug}/embeddings.json` + `fs.append people/encounters.md` | ✓ Phase 6 |
| 5 | `preview_action` card before fs writes (per confirm-policies.md `fs:write: preview-always`) | ✓ |
| 6 | User SEND → all writes happen | ✓ |
| 7 | CHANGELOG.md updated | ✓ |

**Verdict 3A**: ✓ **PASS** (uses Cortex's 2-pass routing per [CORTEX-ROUTER-PROMPT.md error-handling section](../server/CORTEX-ROUTER-PROMPT.md)).

#### 3B. Re-meet → match → show archive

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | Quick Shortcut #1 (DT+SWIPE_UP) → photo + preset prompt | ✓ Phase 3 |
| 2 | Cortex Router | `local_face_recognition.match` → returns match | ✓ Phase 6 |
| 3 | Cortex Router (2nd pass) | `fs.read people/core/{slug}.md` → synthesize summary | ✓ |
| 4 | `hud_show` info card per [ui-mockup §1.10](../../Doc/ui-mockup.html) | ✓ |
| 5 | LOG ENCOUNTER option → `fs.append people/core/{slug}.md` with new encounter timestamp | ✓ |

**Verdict 3B**: ✓ **PASS**.

#### 3C. Cross-time recall query

| Step | Component | Action | Verified |
|---|---|---|---|
| 1 | Voice Invoke → `user_invoke {text: "那个 MIT 做 HCI Edu 的人叫什么"}` | ✓ |
| 2 | Cortex Router | Dispatches `fs.grep` against `people/core/*.md` matching "MIT" + "HCI Edu" | ✓ |
| 3 | Returns 1 result | — |
| 4 | Cortex Router (2nd pass) | Dispatches `fs.read` to get full archive → `claude_code.draft` to synth answer | ✓ |
| 5 | `hud_show` answer | ✓ |

**Verdict 3C**: ✓ **PASS**.

#### 3D. Long-form transcription during conversation

| Step | Component | Action | Status |
|---|---|---|---|
| 1 | User starts a conversation → wants Glass to listen + transcribe in background | ⚠ No long-record mode |
| 2 | Glass's Voice Invoke is **short utterance only** (LP+SWIPE_UP, VAD-stop 2 s) — no long-form recording | ⚠ |
| 3 | After conversation → write transcript to `conversations/{date}/{HH-MM}-{slug}.md` | ⚠ Depends on step 1/2 |

**Verdict 3D**: ⚠ **NOT IN v1**.

**Architectural gap**: Glass client doesn't have a long-form transcription mode. The Voice Invoke pipeline (photo + short STT, VAD-stop ~2 s) doesn't support arbitrary-length recording.

**Resolution**: Per [SoT §10 D-I](../constitution/SOURCE-OF-TRUTH.md) and [DESIGN.md §5 Cool Examples Library](../constitution/DESIGN.md), "ambient transcription with diarized attribution" is **explicitly parked** as cool feature #1, not v1. This means **UC3-D was always partially out of scope**.

**Recommended action**: explicitly document this in [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) Phase 6 so it's not a surprise — UC3-D is parked, not blocked.

**Overall UC3 verdict**: ✓ A/B/C **PASS**; D **parked** (and was always parked).

---

### Part 1 Summary

| UC | Verdict | Fix |
|---|---|---|
| UC1 Email reply | ✓ PASS | Fix A — Router prompt: intent overrides default style |
| UC2-A reverse-wake | ✓ PASS | — |
| UC2-B status query | ✓ PASS w/ constraint | Fix B — CC must be launched via Voice Invoke in v1 |
| UC2-C tasking | ✓ PASS | — |
| UC3-A initial capture | ✓ PASS | — |
| UC3-B re-meet match | ✓ PASS | — |
| UC3-C cross-time recall | ✓ PASS | — |
| UC3-D long-form transcript | ⚠ parked (per N-3) | Doc clarification in IMPLEMENTATION-PLAN |

---

## Part 2 — Six New Cool Use Cases

Each designed under the existing framework constraints. Each has: architecture trace, what's cool, verdict.

### Cool UC #1 · Time-Travel Commitment Query

**Pitch**: "What did I commit to on April 12th, and to whom?"

**Trace**:

| Step | Action |
|---|---|
| 1 | Voice Invoke: "什么时候我承诺过给 Jane review 论文？" |
| 2 | Cortex Router dispatches `fs.grep` against `commitments/*.md` + `conversations/2026-04-*/`. Pattern: "Jane" |
| 3 | Returns 2 file paths |
| 4 | Cortex Router (2nd pass) dispatches `fs.read` on both + `claude_code.draft` synth |
| 5 | `hud_show` info card: "2026-04-12 CMU meetup — committed to review CHI draft by 4/30 (status: open)" + options [OPEN COMMITMENT] [DISMISS] |
| 6 | Tap OPEN COMMITMENT → Cortex opens `commitments/review-jane-paper.md` (`fs.read`) → renders full card |

**Why cool**: Twin demonstrably becomes long-term memory. Nothing else in Zack's toolkit does this — Apple Notes won't grep your conversations, your brain forgets specifics.

**Why practical**: Real PhD/work scenario — you commit to many things, forget when/to whom; Cortex remembers.

**Pass on current architecture**: ✓ **YES** — only uses `fs.grep` + `fs.read` + `claude_code.draft` + `hud_show`. No new tools, no architectural changes.

---

### Cool UC #2 · Pre-Meeting Auto Brief (P6 in action)

**Pitch**: 5 min before a calendar event, Cortex auto-pulses you with: "Meeting with Sarah at 3pm. Last 3 things she said. Open commitments to her. Recent emails."

**Trace**:

| Step | Action |
|---|---|
| 1 | Insight Engine (P6) scans Apple Calendar every 5 min (cron, per `skills/insight-engine.md`) |
| 2 | Detects: upcoming event "Sarah 3:00–3:30 R08 review" in 5 min |
| 3 | Cross-references with `people/core/sarah.md` → exists |
| 4 | Dispatches background plan (no preview, just gathering): `fs.grep "Sarah"` in `receipts/*` (last 7 days) + `fs.read commitments/*` filtered by `to: sarah` |
| 5 | `claude_code.draft` (with context_pack: gathered files) synthesizes a 4-line brief |
| 6 | GPT eval: "is this surprising / interesting?" — yes (commitment due soon to Sarah) → push |
| 7 | Push notification → Glass wake → `hud_show` insight card (✦ icon + green stripe): brief text + options [SEEN] [OPEN ARCHIVE] |
| 8 | User reads on their way to the meeting |

**Why cool**: P6 in concrete action — you walk into a meeting **already primed**, not scrambling.

**Why practical**: Anyone in research / collaboration. Removes the "what did we last discuss?" awkwardness.

**Pass on current architecture**: ✓ **YES** — Insight Engine (Phase 7) + Calendar event subscriber + existing tools. No new infrastructure.

---

### Cool UC #3 · Lock-In Mode

**Pitch**: "I need 90 minutes of deep work on Constellation. Set me up + protect the time + ask me what I got done after."

**Trace**:

| Step | Action |
|---|---|
| 1 | Voice Invoke: "lock in 90 min on Constellation" |
| 2 | Cortex Router dispatches multi-tool plan: <br>(a) `applescript_calendar.add_event("Lock-in: Constellation", now, +90min)` <br>(b) `applescript_reminders.add("Lock-in ends", due=+90min)` <br>(c) Internal: set Insight Engine `pulse_suppression_window: 90min except critical` (writes to internal state, NOT Twin — this is in-memory Cortex state) |
| 3 | `preview_action` card: shows the 3 things → user SEND |
| 4 | 90 min pass. During this window: P6 pulses suppressed except critical (build failed-level). Quick Shortcuts + Voice Invoke still work. |
| 5 | Lock-in ends → Apple Reminders fires its native notification (per ecosystem-first policy) |
| 6 | Cortex (via P6 cron) detects the calendar event just ended → pushes a follow-up insight: "Lock-in done. What did you get done? Want me to log it?" with option [DICTATE] |
| 7 | User: Voice Invoke "实现了 face recognition adapter + 写完 setup script" |
| 8 | Cortex appends to `projects/constellation.md` under a "Sessions" section + `receipts/{date}.md` |

**Why cool**: Apple Focus mode is just "don't disturb"; Lock-In coordinates *across* Calendar + Reminders + Cortex's own attention budget + post-session reflection. Single voice command, ecosystem composition.

**Why practical**: Real work pattern. Most "focus apps" only handle the do-not-disturb side, not the reflection side.

**Pass on current architecture**: ✓ **YES** — uses calendar + reminders + Insight Engine + receipt writer. Only new addition: Cortex needs an in-memory `pulse_suppression_window` (small addition to Insight Engine module, easy).

---

### Cool UC #4 · Reverse Stand-Up (daily debrief)

**Pitch**: Every evening, Cortex asks you about your day in a small way — and learns.

**Trace**:

| Step | Action |
|---|---|
| 1 | Cron tick at 22:00 (per `skills/insight-engine.md` daily scheduled events) |
| 2 | Cortex reads today's `receipts/{date}.md` + observes patterns ("3 emails to Sarah", "2 hours on R08", "no commitment updates") |
| 3 | Builds a candidate `daily_debrief_pulse` |
| 4 | GPT eval: surprising? interesting? yes → push |
| 5 | Push notification → Glass wake → `preview_action` card (✦ icon): "Today: 14 invokes, 3 emails to Sarah, 2 h on R08. Anything to add?" + options [DICTATE] [NOTHING] |
| 6 | User taps DICTATE → mic opens → "Also: had a 1:1 with Mike about R08 BLE protocol; he raised a concern about latency" |
| 7 | Cortex Router dispatches: `fs.append people/core/mike-chen.md` (new interaction note) + `fs.append projects/r08-halo-ring.md` ("Latency concern raised by Mike, 2026-05-24") + `fs.append receipts/{date}.md` (the debrief entry itself) |
| 8 | `preview_action` shows the proposed edits → user SEND |

**Why cool**: This is the **bidirectional** half of Implicit Learning Loop. You don't have to actively maintain the Twin; Cortex asks once a day, learns from what you say. Twin grows organically.

**Why practical**: 1 min/day investment, compounds into rich Twin over weeks.

**Pass on current architecture**: ✓ **YES** — Insight Engine cron + receipts/projects reads + `fs.append` (preview-always but auto-acceptable here). New: Cortex needs a `daily_debrief` trigger class in Insight Engine — trivial addition.

---

### Cool UC #5 · Project Momentum Scanner

**Pitch**: "Hey, R08 hasn't seen a real action in 14 days. You said it was active. Status?"

**Trace**:

| Step | Action |
|---|---|
| 1 | Insight Engine weekly scan (cron, every Monday 9:00 or similar) |
| 2 | For each `projects/*.md` with `status: active`: check `updated:` frontmatter + grep `CHANGELOG.md` for last mention. |
| 3 | Finds: `projects/r08-halo-ring.md` last touched 14 days ago. |
| 4 | Candidate `stale_project_pulse` |
| 5 | GPT eval: "user marked active but no recent activity — surprising? yes" → push |
| 6 | `preview_action` card: "R08 last action 14 days ago. Active? Paused? One-line status?" + options [DICTATE] [ARCHIVE] [STILL ACTIVE] |
| 7a | User picks STILL ACTIVE → Cortex appends `updated:` and a "still active" note; sets a re-scan in another 14 days |
| 7b | User picks ARCHIVE → Cortex sets `status: archived` on the project file |
| 7c | User picks DICTATE → mic opens → adds status note |

**Why cool**: Cortex notices what you don't. Status hygiene is a thing nobody does well; offloading to a pulse is genuinely useful.

**Why practical**: Researchers, PMs, anyone juggling projects. "I forgot I started that" is a real problem.

**Pass on current architecture**: ✓ **YES** — Insight Engine + project metadata reads + standard write protocol. Nothing new.

---

### Cool UC #6 · Cross-Tool Handoff (CC → Email in one breath)

**Pitch**: Claude Code is showing an error. You say: "send Sarah this stacktrace with context, ask if she's seen this before."

**Trace**:

| Step | Action |
|---|---|
| 1 | Voice Invoke: "把 Claude Code 现在的错误发给 Sarah，问她见过没" |
| 2 | Cortex Router dispatches multi-tool plan: <br>(a) `claude_code.get_status` → grabs last 50 lines of CC output (stacktrace + context) <br>(b) `applescript_mail.draft` with prompt: "compose an email to Sarah: ask if she's seen this stacktrace before. Include the stacktrace. Use Zack's email style." + context_pack including `skills/email-style.md` + `people/core/sarah.md` <br>(c) `applescript_mail.send` (preview) |
| 3 | `preview_action` card shows the drafted email (with stacktrace embedded) → user SEND |
| 4 | Email out + receipt |

**Why cool**: User stays heads-down. No copy-paste. No alt-tab. Cortex orchestrates across tools.

**Why practical**: Daily for any engineer. Stacktrace-to-colleague is a common ask.

**Pass on current architecture**: ✓ **YES** — exact multi-tool dispatch pattern shown in [CORTEX-ROUTER-PROMPT.md Example 1](../server/CORTEX-ROUTER-PROMPT.md). No new mechanisms.

---

### Part 2 Summary

| Cool UC | Verdict | Adds to framework |
|---|---|---|
| #1 Time-travel commitment query | ✓ PASS | none |
| #2 Pre-meeting auto brief | ✓ PASS | Calendar event subscriber (already planned in Phase 7) |
| #3 Lock-in mode | ✓ PASS | Cortex in-memory `pulse_suppression_window` (trivial) |
| #4 Reverse stand-up | ✓ PASS | `daily_debrief` cron trigger class (trivial) |
| #5 Project momentum scanner | ✓ PASS | none (just a new scan pattern) |
| #6 Cross-tool handoff | ✓ PASS | none |

All 6 pass. 2 of them (#3, #4) add **trivial extensions** to Insight Engine (single config / trigger class). No architectural rework needed.

---

## Part 3 — Recommended Fixes

Three small fixes from the audit. None require code (we're pre-implementation); all are doc edits.

### Fix A · Add intent-overrides-style directive to Router prompt

**Where**: [CORTEX-ROUTER-PROMPT.md §1 system prompt → PRIMARY DIRECTIVES](../server/CORTEX-ROUTER-PROMPT.md)

**Add directive 7**:

> 7. PRESERVE the user's intent over default style. When the user's stated intent (in the current event payload) conflicts with default preferences in `skills/*.md`, the user's intent in the current utterance wins. Note any conflict explicitly in the `reasoning` field.

This resolves UC1's "casual default vs user-says-polite" issue.

### Fix B · Document CC session ownership constraint

**Where**: [TOOL-ADAPTERS.md §1 `claude_code`](../server/TOOL-ADAPTERS.md) — add a "Constraint" subsection. Also add note in [IMPLEMENTATION-PLAN Phase 5](IMPLEMENTATION-PLAN.md).

**Constraint**:

> v1 constraint: Tool Agent only manages Claude Code sessions it spawned (via the `run` action). Sessions launched outside Constellation (manually in Terminal) are invisible to Tool Agent — `get_status` won't see them, `send_keys` can't reach them.
>
> To remote-control Claude Code, **launch it through Voice Invoke** ("用 Claude Code 在 X 跑 Y") so Tool Agent owns the session.
>
> v2 may add global tmux discovery + a "claim this existing CC session" command; v1 keeps the ownership model simple.

### Fix C · Document UC3-D parked status

**Where**: [IMPLEMENTATION-PLAN Phase 6](IMPLEMENTATION-PLAN.md) — explicit subsection.

**Note**:

> **UC3 partial parking**: SoT §10.3 mentions ambient transcription ("我和某人在聊天时开启了转写"). This requires a **long-form recording mode** on Glass that the v1 Voice Invoke pipeline (short utterance + VAD-stop) does not provide.
>
> Per [SoT N-3](../constitution/SOURCE-OF-TRUTH.md) and [DESIGN.md §5 Cool Examples Library](../constitution/DESIGN.md), "Ambient transcription with diarized attribution" is parked as cool feature #1, not v1.
>
> **UC3 v1 scope**: A (initial capture), B (re-meet match), C (cross-time recall). UC3-D (long-form transcript) deferred.
>
> **Workaround for v1**: user can do "Drop a thought" Quick Shortcut #3 (mic-only) to dictate a conversation summary after a meeting. Not the same as live transcription but covers most of the recall use case.

---

## Part 4 — Conclusion

**Audit result**: of 9 UCs (3 original + 6 new cool):

- **8 PASS** on current architecture without any code changes
- **1 PARKED** explicitly per existing SoT N-3 (was always parked; just documenting clearly)
- **3 doc fixes** recommended; no code or architectural rework

**The framework is robust.** Phase 1 implementation can proceed with confidence that the design supports the originally stated use cases AND a meaningful set of cool extensions discovered in this audit.

**The 6 new cool UCs are now "framework demos"**: each is a tangible, near-term-implementable showcase that Cortex's framework adds value Apple's defaults can't.

---

## Document Status

- **Version**: v0.2 (Post-R-3 addendum)
- **Last updated**: 2026-05-24
- **Original audit**: pre-Phase-1 (2026-05-24); 8/9 PASS verdict still holds
- **Post-R-3 addendum** (this version): notes paradigm shift per SoT R-3 — multi-step + always-mic + free-form feedback — and how it changes UC1/UC2 implementation shape

---

## Post-R-3 Addendum (2026-05-24)

The original audit (v0.1, §1-4 above) was done pre-Phase-1 and assumed single-shot Router dispatch per intent. **SoT R-3 (multi-step paradigm)** materially changes implementation shape for some use cases. Verdicts on PASS/PARK status are unchanged but worth re-examining the shapes:

### UC1 Email Reply — now naturally multi-step capable

The original v0.1 audit traces UC1 as a single dispatch plan (4 subtasks). Under R-3, the same intent **can also** decompose into multi-step:

- Round 1 (intermediate, task_continues=true): `applescript_mail.read_current` → preview "Here's the email — draft a reply?"
- Round 2 (terminal): `claude_code.draft` → `applescript_mail.send` (preview) → user SEND

For UC1 "回复，三个小时后开会" both shapes work. The Router judges which is cleaner — single-shot for short/clear intents, multi-step when the user mid-stream might want to look at the original email first or correct interpretation.

The "原 SoT 提到的 Jane 邮件" + style conflict issue in v0.1 audit (fix A: "user intent overrides default skill") was **resolved** in router.py SYSTEM_PROMPT and reflected in [CORTEX-ROUTER-PROMPT.md](../server/CORTEX-ROUTER-PROMPT.md) v0.2 directives + contact lookup section.

### UC1+ Extended example (canonical R-3 demo)

Zack's **云 email** example introduced 2026-05-24 is the canonical multi-step:

> "看前两天给云的邮件找 meeting 时间，加 reminder，再写邮件告诉她我准备好下周下午约"

This is genuinely impossible single-shot: the user must judge the extracted meeting time mid-task before Cortex commits to reminder time + reply content. See [CORTEX-ROUTER-PROMPT.md §3 Example 2](../server/CORTEX-ROUTER-PROMPT.md) for the 2-round Router trace.

### UC2 Reverse-wake — fully wired and verified (2026-05-24)

The original audit listed UC2 sub-modes 2A/2B as "✓ Phase 5". They were **demoed end-to-end on 2026-05-24** by `test-harness/real_cc_reverse_wake.py`: real CC v2.1.x permission UI ("Do you want to proceed? / ❯ 1. Yes / 2. Always allow / 3. No") → Tool Agent watcher detected → Cortex tool_card → fake-Glass `allow_once` → send_keys `[Enter]` → CC continued → target file written.

Patterns updated per CC v2.x menu format ([TOOL-ADAPTERS.md §1](../server/TOOL-ADAPTERS.md)). UC2 is implementation-verified, not just architecturally pass.

### UC3 — unchanged

UC3 face recognition deferred to Phase 6 as originally planned. UC3-D long-form transcript still parked per SoT N-3 + R-1 (now also N-8: no Whisper). The "Drop a thought" workaround still applies.

### New use cases from Zack's R-3 trigger (2026-05-24)

Beyond the original 9, Zack explicitly cited the **云 email scenario** + commented "还有很多类似的例子, 你不要让我一个一个列举" — meaning the multi-step + always-mic paradigm is meant to handle an **open-ended class** of intents, not a fixed list. Per SoT C-20 + C-23, Router must absorb intents in this shape without architectural changes:

- "Look at X then ask me about Y before doing Z" — multi-step with mid-step yield
- "Find A, tell me, then I'll decide what action" — investigation step + executor step
- "Do all of A B C unless I tell you to skip any" — Router-side conditional via feedback interpretation

### Re-audit verdict

The 8/9 PASS verdict from v0.1 still holds; R-3 doesn't break any use case. The framework is now richer (more shapes per intent) AND simpler from the user POV (every card is the same: speak or tap).

3 doc fixes recommended in v0.1 (CORTEX-ROUTER-PROMPT, TOOL-ADAPTERS, IMPLEMENTATION-PLAN) all done as part of the Phase 1+2+R-3 implementation.

---

*End of Use Case Audit v0.2.*
