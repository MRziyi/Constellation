# Constellation Tool Adapters — Action Catalog

**Version**: v0.2 (frozen 2026-05-24); **planner-visible subset narrowed by Phase 5g as of 2026-05-25**
**Status**: 设计阶段 → 实现同步 (Phase 2 Slice A/B/C 完成 12 个 adapter live; Phase 5g planner catalog pruned to 10 tools / 11 actions)
**关联文档**: **[AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md)** · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md)
**Last updated**: 2026-05-25 (added Phase 5g supersedes banner)

> ⚠ **Reader pointer (2026-05-25)**: This doc catalogs all **12 adapter implementations** that live in `tool-agent/tool_agent/adapters/`. After Phase 5g, only a **pruned subset** is visible to the planner ([`cortex.router.AVAILABLE_TOOLS`](../../../Constellation-Server/cortex/cortex/router.py)). The full adapter set is still loaded — used by:
> 1. The **agent path** (Claude Code in tmux gets `--add-dir` access to Twin/projects and uses its own native tools — Bash, Read, etc. — for research; on completion the structured `actions[]` is mapped back to executor adapters by `cortex.server._action_to_subtask`).
> 2. Direct `/api/dev/dispatch` calls (dev/test bypass).
> 3. Regression safety — adapter code paths are still tested end-to-end.
>
> **Planner-visible 10 tools / 11 actions** (the only entries the v0.5 Router can NAME in a dispatch plan):
>
> | Tool | Actions visible |
> |---|---|
> | `echo` | echo |
> | `applescript_reminders` | add |
> | `applescript_calendar` | add_event, list_today |
> | `applescript_mail` | send |
> | `fs` | write |
> | `system_status` | get |
> | `safari_state` | current_tab |
> | `apple_shortcuts` | run |
> | `imessage` | send |
> | `claude_code` | agent (orchestration uses `agent_continue` / `agent_kill` directly, not via planner) |
>
> Adapters **hidden from the planner but kept in tool_agent**: full `applescript_mail` (read_current/list_inbox/find_messages/draft/get_thread), full `applescript_calendar` (list_range/find_conflict/get_event), full `fs` (read/append/grep/list/delete), full `apple_notes` (create/list/read/append/search), full `applescript_reminders` (list/complete/delete), full `apple_shortcuts` (list), full `imessage` (list_recent), full `safari_state` (all_tabs/recent_history), full `twin_query` (ask), full `claude_code` Track A (draft/run/continue_/list_sessions) + Track B (run_interactive/get_pane/send_keys/kill/list_tmux/start_watcher/stop_watcher). All still callable by the agent path's actions[] → executor mapper or by `/api/dev/dispatch`.
>
> §-by-§ adapter specs below remain accurate as **implementation** docs. The "Cortex Router will pick this" framing is what changed.

Reference catalog of every Tool Agent adapter — its actions, args, return shapes, side-effects level. Cortex Router uses this catalog (via system prompt) to compose dispatch plans; Tool Agent implements one adapter class per entry.

---

## Adapter contract (all adapters)

```python
class ToolAdapter:
    name: str  # stable, snake_case identifier matching what Cortex Router uses

    async def dispatch(
        self,
        action: str,
        args: dict,
        context_pack: list[str],   # Twin paths to inject as context
        result_format: str          # "draft" | "execute" | "query"
    ) -> dict:
        ...

    # Optional: opt-in event push channel (used by long-running watchers like claude_code)
    def attach_event_pusher(self, pusher: Callable[[dict], Awaitable[None]]) -> None:
        ...
```

`pusher` lets adapters send unsolicited events to Cortex (e.g., `tool_reverse_wake`). Wired by `ToolAgentServer` at startup; see [COMPONENT-DESIGN §2.4](COMPONENT-DESIGN.md).

Tool Agent server returns `{id, ts, status, result, diagnostics}` per [INTERFACE-CONTRACTS §3.2](INTERFACE-CONTRACTS.md).

Side-effects taxonomy (informs `confirm-policies.md` defaults):
- **none** — pure read; never needs preview
- **low** — write to user-owned local app, easily reversible (Reminders, Calendar, Notes)
- **medium** — write to user-owned local app, harder to reverse (Mail send, file write, iMessage send)
- **high** — irreversible or external effect (delete, kill process, CC interactive sessions)

---

## 1. `claude_code` — Anthropic's Claude Code CLI controller (dual-track)

**Side-effects**: high — can spawn long-running processes, modify files via CC's own tools, send keys to live sessions.

**Two tracks**:

### TRACK A — non-interactive `claude -p` mode (no tmux)

Used for one-shot or session-resumed prompts that return text. Each call is a `claude -p` subprocess that exits when done. Session IDs are tracked in adapter memory for `--resume`.

Defaults: `--permission-mode dontAsk`, `--max-budget-usd 0.50`, `--output-format json`, 5min timeout.

#### `draft(prompt, working_dir?, add_dirs?, model?, max_budget_usd?, allowed_tools?, disallowed_tools?, timeout_s?) → DraftResult`
One-shot prompt; CC may use its own tools (Read/Bash/Grep/WebFetch). Returns the final text. Per [SoT N-9](../constitution/SOURCE-OF-TRUTH.md), this is the routing target for web/paper search intents (CC has WebFetch).

**Result**:
```json
{
  "ok": true, "rc": 0,
  "text": "<CC's final answer>",
  "cost_usd": 0.04,
  "num_turns": 3,
  "started_at": "...", "finished_at": "...",
  "cwd": "<working_dir>"
}
```

#### `run(prompt, working_dir?, session_id?, ...) → RunResult`
Same as `draft` but assigns a `session_id` (UUID) so the user can resume later with `continue_`.

#### `continue_(session_id, prompt, ...) → Result`
Resume a tracked session: `claude -p --resume <session_id> "<prompt>"`. CC has full conversation context.

#### `list_sessions() → SessionList`
Returns in-memory tracked Track A sessions: `{count, sessions: [{session_id, working_dir, started_at, last_activity, last_prompt, turn_count, total_cost_usd}, ...]}`.

### TRACK B — interactive `claude` in tmux session (with reverse-wake watcher)

Used for long-running CC tasks where the user supervises asynchronously. UC2's primary path.

Isolated tmux socket: `/tmp/cortex-tool-agent-cc.sock`. Session name prefix: `cc-<10hex>`.

Auto-starts a **reverse-wake watcher** (1.5s poll) per session that detects permission prompts and pushes `tool_reverse_wake` events to Cortex via `event_pusher`.

#### `run_interactive(prompt?, working_dir?, session_name?, model?, add_dirs?, permission_mode?, watch?) → SessionMeta`
Spawn a detached tmux session running `claude` (interactive TUI). If `prompt` given, sent as initial input after the TUI renders. If `watch=true` (default), starts the reverse-wake watcher.

**Result**:
```json
{
  "session_id": "cc-f4c8526e71",
  "started_at": "2026-05-24T20:31:54Z",
  "last_activity": "...",
  "cwd": "<working_dir>",
  "claude_args": ["claude", ...],
  "state": "running",
  "initial_prompt": "...",
  "watcher_running": true
}
```

#### `get_pane(session_id, lines?=200) → PaneCapture`
`tmux capture-pane -t <id> -p -S -<lines>`. Returns the live TUI content as text.

#### `send_keys(session_id, keys, literal?=true) → SendResult`
- `literal=true` (default): plain text; `\n` splits into segments with Enter between
- `literal=false`: tmux named-key mode; `keys` is a list like `["Down", "Down", "Enter"]` or `["C-c"]`

For CC v2.x permission menus, use named-key mode (cursor navigation):
- option 1 (Yes) → `["Enter"]`
- option 2 (Always allow) → `["Down", "Enter"]`
- option 3 (No) → `["Down", "Down", "Enter"]`

#### `kill(session_id) → KillResult`
Stops the watcher first, then `tmux kill-session`. Idempotent.

#### `list_tmux() → TmuxList`
Reconciliation view: `{actual: [<tmux session names>], tracked: [<adapter-tracked metas>]}`. Mark stale tracked sessions as `state: "gone"`.

#### `start_watcher(session_id) / stop_watcher(session_id)`
Manual control of the reverse-wake watcher per session. Normally `run_interactive` auto-starts; these are escape hatches.

### Reverse-wake watcher patterns (CC v2.1.x verified 2026-05-24)

Patterns inlined in `tool_agent/adapters/claude_code.py` (hot-reload from `twin-seed/skills/claude-code-control.md` is Phase 7 polish):

```python
PERMISSION_PATTERNS = [
    re.compile(r"Do you want to proceed\?", re.IGNORECASE),   # CC v2 modern
    re.compile(r"❯\s*1\.\s+Yes", re.MULTILINE),               # CC v2 menu cursor
    # Legacy patterns retained as fallbacks:
    re.compile(r"Do you want to .*\?\s*\(y/n\)", re.IGNORECASE),
    re.compile(r"Approve this action\?\s*\[y/N\]", re.IGNORECASE),
    re.compile(r"Allow .*\?\s*\[y/N\]", re.IGNORECASE),
    re.compile(r"Do you want to allow .*\?", re.IGNORECASE),
]
COMPLETION_PATTERNS = [re.compile(r"✓ Task complete", re.IGNORECASE), re.compile(r"✔ Done\.", re.IGNORECASE)]
ERROR_PATTERNS = [re.compile(r"^Error:", re.MULTILINE), re.compile(r"^Traceback", re.MULTILINE), re.compile(r"^fatal: ", re.MULTILINE)]
```

On match, emits to Cortex:
```json
{
  "kind": "tool_reverse_wake",
  "payload": {
    "from_tool": "claude_code",
    "wake_kind": "permission_request" | "completion_notice" | "error",
    "context": "<last 5 lines around match>",
    "session_id": "cc-...",
    "options": [{"id": "allow_once", "label": "Allow once"},
                {"id": "allow_always", "label": "Always allow"},
                {"id": "deny", "label": "Deny"}]
  }
}
```

Deduped on (kind, last ~120 chars of match) so a stable permission prompt doesn't refire.

### Test-only action

#### `__test_inject_wake__(session_id?, wake_kind?, context?) → InjectResult`
Synthesize a `tool_reverse_wake` event for end-to-end wiring tests without needing a real CC permission to trigger. Used by `test-harness/reverse_wake_flow.py`.

---

## 2. `applescript_mail` — Mail.app via AppleScript

**Side-effects**: read=none, draft=low, send=medium (irreversible).

**Three intent modes** (per SoT R-2 / C-19):

### REPLY (sender account auto-determined by Mail.app)

| Variant | Args |
|---|---|
| Reply to currently-selected | `{reply_to_current: true, body}` |
| Reply by RFC Message-ID | `{reply_to_message_id: "<id>", body}` |

Adapter calls Mail's `reply` action which auto-routes through the receiving account. **Never pass `account` for replies — would be ignored or conflict.**

### COMPOSE (sender account explicit)

| Args | Effect |
|---|---|
| `{to: [...], subject, body, account?: "iCloud" \| "Google" \| "QQ" \| "UIUC"}` | New message; if `account` set, resolves to first email address of that Mail.app account |
| Same + `dry_run: true` | Routes internally to `draft` action (saves to Drafts instead of sending) — safety pattern |

### SEARCH (cross-mailbox find for "回忆我跟 X 的邮件" intents)

#### `find_messages(participant?, subject_contains?, body_contains?, account?, mailbox?=both, limit?=20) → Found`
Uses AppleScript `whose` clause to push filtering into Mail.app (orders of magnitude faster than userland loop). `body_contains` is post-filtered (slower).

Default scope: inbox + sent across all 4 accounts. Account name limits scope.

**Result**:
```json
{
  "filters": {...},
  "count": 2,
  "items": [{"message_id": "<RFC>", "subject": "...", "sender": "...", "date": "..."}, ...]
}
```

### Other actions

#### `read_current() → Email`
Returns currently-selected message in Mail UI: `{found, message_id, subject, sender, date, body_text}`.

#### `list_inbox(limit?=20, unread_only?=false) → InboxList`

#### `draft(to, subject?, body, account?) → DraftId`
Saves to Drafts; `account` works same as compose.

#### `send(...)` — multi-variant overload
- Variant A: `{reply_to_current: true, body}` — reply to selection
- Variant B: `{reply_to_message_id, body}` — reply by id
- Variant C: `{to: [...], subject, body, account?}` — compose
- `{dry_run: true}` on any send → routes to draft instead

#### `get_thread(message_id) → Email[]`
v1 stub (returns single-message metadata only); proper thread walking deferred.

### Push notifications: NOT managed

Per SoT C-18 / N-11: Constellation does NOT subscribe to IMAP IDLE / poll for new mail / push mail notifications. Zack's iPhone + Glass handle that via Apple ecosystem.

---

## 3. `applescript_calendar` — Calendar.app via AppleScript

**Side-effects**: read = none, add = low.

Default calendar: `个人`. Override via `args.calendar`.

#### `list_today() → Event[]`
#### `list_range(start, end) → Event[]` — args are ISO 8601
#### `add_event(title, start, end, calendar?, location?, notes?) → EventId`
Returns `{uid, title, start, end, calendar, location}`. Side-effects: low. confirm-policies: **preview-always**.

#### `find_conflict(start, end, calendar?) → ConflictList`
Returns existing events overlapping the window: `{window_start, window_end, conflicts, has_conflict}`.

#### `get_event(uid, calendar?) → Event`

ISO → AppleScript date conversion handled internally (`Month D, YYYY H:MM:SS AM/PM` long form).

---

## 4. `applescript_reminders` — Reminders.app via AppleScript

**Side-effects**: read=none, add=low, delete=medium.

#### `add(title, due?, list?='Reminders', notes?) → ReminderId`
ISO datetime in `due`. Adapter normalises ISO → AppleScript `date "Month D, YYYY H:MM:SS AM/PM"`.

confirm-policies: **auto** (low risk + frequent).

#### `list(list?='Reminders', completed?=false) → Reminder[]`
#### `complete(reminder_id) → void`
#### `delete(reminder_id) → void` (preview-always)

Defensive guard: `add` / `complete` / `delete` refuse `result_format=draft` (no draft semantics for side-effecting actions).

---

## 5. `fs` — Local filesystem

**Side-effects**: read=none, write/append=low-medium, delete=high.

**Safety model** (v0.2):

- **Reads** (read / list / grep) — anywhere on filesystem; user-driven
- **Writes** (write / append) — restricted to whitelisted roots: `~/constellation/`, `~/Code/Projects/`, `/tmp/`
- **Delete** — restricted to `~/constellation/twin/` AND non-recursive only (recursive requires explicit `recursive=true` flag; outside that root always refused)

#### `read(path, max_bytes?=200000) → Content`
`{path, exists, size_bytes, mtime, content, truncated}`.

#### `list(path, glob?='*', recursive?=false, max_items?=500) → PathList`

#### `grep(pattern, paths, case_sensitive?=false, regex?=true, max_matches?=200, include_vendored?=false) → MatchList`
Prefers ripgrep when available; falls back to grep. **Default excludes** (override via `include_vendored=true`): `.venv`, `node_modules`, `.git`, `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `dist`, `build`, `.next`, `.nuxt`.

#### `write(path, content, mode?='overwrite' | 'create_only') → void` (preview-always)

#### `append(path, content) → void` (auto — appends are safer than overwrites)

#### `delete(path, recursive?=false) → void` (preview-always; restricted root)

Per Zack 2026-05-24: this adapter's biggest use is **letting Claude Code go look at directories** — pair `fs.read` / `fs.grep` to pre-survey, then `claude_code.draft` with the right `working_dir` + `add_dirs`.

---

## 6. `apple_notes` — Notes.app via osascript

**Side-effects**: create=low, append=low, list/read/search=none.

Default account `iCloud`, default folder `Notes`. No delete action in v1 (Notes is "drop a thought" surface; manual deletion in Notes.app avoids surprise data loss).

#### `create(title, body?, folder?, account?) → NoteRef`
`{note_id, title, account, folder}`. Body becomes HTML internally (`<h1>{title}</h1><div>{line}</div>...`).

#### `list(folder?, account?, limit?=30) → NoteList`
#### `read(note_id) → NoteContent`
Returns `{note_id, title, body_html, plaintext, modified}`. `plaintext` is best-effort HTML→text strip.

#### `append(note_id, content) → AppendResult`
Reads body, concatenates new HTML, writes back.

#### `search(query, limit?=20) → NoteList`
v1 title-only search (Notes' AppleScript surface limited). Body search deferred (would need SQLite path or scripting bridge).

---

## 7. `system_status` — Mac state snapshot for context-aware routing

Single action: `get`.

**Returns**:
```json
{
  "battery_pct": 49,            // null if no battery
  "on_ac": true,
  "focus_mode": "off",          // "off" / "do_not_disturb" / "work" / etc. — best effort
  "frontmost_app": "Code",
  "wifi_ssid": "NetworkName",   // null if disconnected
  "tailscale": false,
  "now_iso": "2026-05-24T15:11:22.96Z",
  "tz": "America/Chicago"
}
```

All reads via concurrent subprocess (pmset / defaults / osascript / networksetup / tailscale). Side-effects: none. Confirm: auto.

Consumers: enrich Router's USER STATE block, gate P6 pulses by focus_mode, choose tool by frontmost_app, defer image-heavy vision when battery low.

---

## 8. `apple_shortcuts` — invoke any user-defined Apple Shortcut

#### `list(folder?) → ShortcutList`
`shortcuts list [--folder-name X]` → list of shortcut names.

#### `run(name, input?, timeout_s?=30) → RunResult`
`shortcuts run "<name>" --input-path -` with `input` piped to stdin. Returns `{name, rc, output, stderr}`.

**Side-effects**: highly variable (depends on what each Shortcut does). Default policy: preview-always. Specific shortcuts user trusts can be downgraded to `auto` by name in `confirm-policies.md`.

Massive leverage: Zack's existing 9 Shortcuts (`Feed Control`, `智能语音记账`, `Show my sleep rings`, etc.) become Cortex-callable.

---

## 9. `twin_query` — semantic Q&A over Digital Twin (RAG)

Single action: `ask`.

**Only Tool Agent adapter that calls an LLM.** Tool Agent loads `.env` for `OPENAI_API_KEY`.

#### `ask(question, max_snippets?=20, model?='gpt-5.4') → Answer`
1. Extract keywords from question (cheap stopword filter)
2. Run ripgrep over `~/constellation/twin/` (falls back to grep if no rg)
3. Collect snippets (deduped)
4. GPT-5.4 synthesizes answer using ONLY snippets as ground truth, with `[[path]]` citations

**Result**:
```json
{
  "question": "...",
  "keywords": [...],
  "answer": "You prefer emails that are casual, direct... [[identity.md]][[skills/email-style.md]]",
  "snippet_count": 14,
  "snippets": [...]
}
```

Cost: ~1k-5k input tokens + ~200 output per call.

Phase 8 MCP server will reuse this engine (per [INTERFACE-CONTRACTS §5.1](INTERFACE-CONTRACTS.md)).

---

## 10. `imessage` — Messages.app

#### `send(to, body, service?='iMessage') → SendResult` (preview-always)
`to` is phone (e.g. `+12025551234`) or Apple ID email. AppleScript `tell application "Messages"`.

#### `list_recent(limit?=20, contact?, since_hours?) → MessageList`
Reads `~/Library/Messages/chat.db` SQLite (read-only mode).

**Requires Full Disk Access TCC** for the cortex python binary. If not granted, returns a soft error (no crash):
```json
{"error": "cannot open chat.db: ... Full Disk Access TCC required.", "items": []}
```

No `read_by_id` / `reply_to_message` in v1 — Messages' AppleScript surface lacks clean reply primitive. To respond, just `send` to same buddy.

---

## 11. `safari_state` — Safari awareness

#### `current_tab() → Tab`
AppleScript `URL of current tab of front window`. Returns `{found, url, title}`. Basic TCC for System Events.

#### `all_tabs() → TabList`
Lists every open tab across windows.

#### `recent_history(hours?=24, limit?=30) → HistoryList`
Reads `~/Library/Safari/History.db` SQLite. **Requires FDA TCC**; soft error if not granted.

All read-only; confirm: auto.

---

## 12. `local_face_recognition` — local face model (Phase 6, not yet enabled)

Side-effects: read-only inference; embedding writes are low (to `Twin/memories/faces/`).

Library TBD per [OQ-D7](DATA-MODEL.md). Candidates: `face_recognition` (dlib), `insightface`, `face-api`.

Actions per v0.1 spec: `detect(image) → Face[]`, `embed(face_crop) → Embedding`, `match(image, candidates_dir?, threshold?=0.6) → MatchResult[]`. Storage layout: `Twin/memories/faces/{person-slug}/face-{ts}.jpg` + `embeddings.json`.

Not enabled in `adapters.yaml` yet; turned on at Phase 6 start.

---

## 13. `echo` — Phase 1 debug stub

Trivial: `echo(text) → {echoed: text}`. Kept enabled across phases as a smoke-test target.

---

## 14. Adapter discovery + registry

Tool Agent's `ToolRegistry` (see [COMPONENT-DESIGN §2.2](COMPONENT-DESIGN.md)) loads adapters at startup from `adapters.yaml`:

```yaml
adapters:
  - name: echo
    class: tool_agent.adapters.echo.EchoAdapter
    enabled: true

  - name: applescript_reminders
    class: tool_agent.adapters.applescript_reminders.RemindersAdapter
    enabled: true

  - name: applescript_calendar
    class: tool_agent.adapters.applescript_calendar.CalendarAdapter
    enabled: true

  - name: applescript_mail
    class: tool_agent.adapters.applescript_mail.MailAdapter
    enabled: true

  - name: fs
    class: tool_agent.adapters.fs.FsAdapter
    enabled: true

  - name: apple_notes
    class: tool_agent.adapters.apple_notes.AppleNotesAdapter
    enabled: true

  - name: system_status
    class: tool_agent.adapters.system_status.SystemStatusAdapter
    enabled: true

  - name: apple_shortcuts
    class: tool_agent.adapters.apple_shortcuts.AppleShortcutsAdapter
    enabled: true

  - name: twin_query
    class: tool_agent.adapters.twin_query.TwinQueryAdapter
    enabled: true   # needs OPENAI_API_KEY

  - name: imessage
    class: tool_agent.adapters.imessage.IMessageAdapter
    enabled: true

  - name: safari_state
    class: tool_agent.adapters.safari_state.SafariStateAdapter
    enabled: true

  - name: claude_code
    class: tool_agent.adapters.claude_code.ClaudeCodeAdapter
    enabled: true

  # Phase 6:
  # - name: local_face_recognition
  #   class: tool_agent.adapters.face.LocalFaceRecognitionAdapter
  #   enabled: false
```

Disabled adapters don't appear in `AVAILABLE TOOLS` for the Router prompt — keeps prompt size down and prevents hallucinated dispatches.

Cortex's enabled-tool whitelist mirrors this set; see `server.py` `_tools_block, _allowed_tools = available_tools_block(enabled={...})`.

---

## 15. v1 Open Questions

| # | Question | Status |
|---|---|---|
| OQ-T1 | applescript_mail Variant B `send(draft_id)` exists | unverified; using Variant A/C/D covers UC1 |
| OQ-T2 | applescript_reminders `due` natural-language parsing | resolved: Router pre-parses to ISO; adapter normalises |
| OQ-T3 | fs.delete recursive restrict | resolved: only under `~/constellation/twin/` |
| OQ-T4 | Local face-recognition lib | deferred Phase 6 |
| OQ-T5 | Long task polling interval | 1.5s active (claude_code watcher); not yet exposed for other long tasks |
| OQ-T6 | imessage / safari_state FDA grants | manual user prompt when first needed |
| OQ-T7 | Hot-reload PERMISSION_PATTERNS from twin-seed/skills/claude-code-control.md | Phase 7 polish |

---

## 16. Document Status

- **Version**: v0.2
- **Last updated**: 2026-05-24
- **Based on**: live `tool-agent/tool_agent/adapters/*.py` (12 adapters live + face placeholder) + verified flows from `test-harness/*.py`
- **Companion**: [COMPONENT-DESIGN.md §2 Tool Agent](COMPONENT-DESIGN.md) for internals; [TOOL-IDEAS.md](../roadmap/TOOL-IDEAS.md) v0.2 for Zack-ratified roadmap of further adapters

### Revision Log

| Version | Changes |
|---|---|
| v0.1 | First version: 6 adapter contracts (claude_code / applescript_mail / applescript_calendar / applescript_reminders / fs / local_face_recognition) + adapter discovery + OQs |
| v0.2 | Comprehensive expansion to **12 live adapters**. New sections: §6 apple_notes, §7 system_status, §8 apple_shortcuts, §9 twin_query, §10 imessage, §11 safari_state, §13 echo. Major rewrites: §1 claude_code (dual-track — Track A `claude -p` non-interactive + Track B tmux interactive + reverse-wake watcher with verified CC v2.1.x patterns + test_inject); §2 applescript_mail (REPLY/COMPOSE/SEARCH three modes per SoT R-2 + `account` arg + `find_messages` via `whose` clause + `reply_to_message_id` + dry_run + push-not-managed per C-18); §5 fs (whitelisted write roots + default vendored-dir exclusion + Zack-noted "CC + fs" pairing). Adapter contract gains optional `attach_event_pusher` for unsolicited event channel. Registry list updated. OQ status updated. |

---

*End of Constellation Tool Adapters v0.2.*
