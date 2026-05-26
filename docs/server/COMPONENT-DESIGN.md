# Constellation — Component Design

**Version**: v0.3 (frozen 2026-05-24); **Cortex internals superseded by [AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md) §2 as of 2026-05-25**
**Status**: 设计阶段 → Phase 1+2 + R-3 + Phase 3a Web Console + Phase 5 v2 全部落地
**关联文档**: [DESIGN.md](../constitution/DESIGN.md) · **[AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md)** · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [DATA-MODEL.md](DATA-MODEL.md) · [SOURCE-OF-TRUTH.md](../constitution/SOURCE-OF-TRUTH.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md)
**Last updated**: 2026-05-25 (added V2 supersedes banner)

> ⚠ **Reader pointer (2026-05-25)**: §1 below describes Cortex with Router-as-multi-step-planner. That model is historical. After Phase 5 v2:
> - **Cortex.classifier** ([cortex/cortex/classifier.py](../../../Constellation-Server/cortex/cortex/classifier.py)) runs first; one bit decides simple vs complex.
> - **Cortex.router** (planner pass) only sees a pruned **10-tool / 11-action** catalog; multi-step rounds (R-3) are deprecated — the agent path handles all multi-step now.
> - **Cortex.agent_brief** ([cortex/cortex/agent_brief.py](../../../Constellation-Server/cortex/cortex/agent_brief.py)) assembles the brief that CC sees; v0.5 selector picks Twin slices to inline.
> - **CortexServer._dispatch_complex_agent** is the shared dispatch path (used by both classifier-routed `user_invoke` and dev `/api/dev/agent_invoke`).
> - **Multi-phase checkpoint orchestrator** (server-side) detects `{phase_done:true, next, ...}` from CC, surfaces ⏸ blocking card, dispatches `claude_code.agent_continue` on user reply.
> - **Thinking heartbeat** (tool_agent-side, in `claude_code._tail_jsonl_until_idle_from`) emits `💭 still thinking…` every 8s of jsonl silence.
>
> §1 still has accurate descriptions of: event bus, schema validation, confirm-policies, receipts, Twin reader/writer. Just don't take "Router does the planning round" literally.

本文档定义 Constellation 各组件**内部**的实现结构。Glass / R08 内部设计推迟到 #8 UI/UX session（按 SoT §7 "两个客户端各自的内部设计 = 之后再考虑"）。本文件聚焦 Mac mini 上的三个进程：**Cortex Agent / Tool Agent / MCP Server**。

---

## 0. Scope

| 组件 | 本文档涵盖 | 推迟到 |
|---|---|---|
| Cortex Agent | ✓ §1 | — |
| Tool Agent | ✓ §2 | — |
| MCP Server | ✓ §3 | — |
| Glass Client | — | #8 UI/UX |
| R08 Ring | — | #8 UI/UX (作为 Glass 的遥控器) |
| Digital Twin | 形态见 [INTERFACE-CONTRACTS §4](INTERFACE-CONTRACTS.md)；详细数据模型 | #6 Data Model |

---

## 1. Cortex Agent (脑)

### 1.1 进程模型

- 单一 Python `asyncio` 服务
- `launchd` 用户级服务，开机自启
- **GPT API** 驱动 Router 决策（SoT C-8 + 本 session 明确）
- 调 **GPT-4V** 处理**场景 vision**（OCR / 场景理解）；**人脸识别**归 Tool Agent 本地模型（v0.4 修订 OQ-C5）
- 含 **Implicit Learning Loop** 异步循环（参 [DATA-MODEL §9](DATA-MODEL.md)）

### 1.2 内部 Modules (v0.3 — reflects Phase 1+2 implementation)

```
┌──────────────────────────────────────────────┐
│              Cortex Agent                     │
│                                               │
│  Glass (WSS)  ────►  Transport Layer          │
│                       ├─ wss server (Glass)   │
│                       └─ wss client + reader  │
│                          (Tool Agent persistent,│
│                           demux RPCResult/Event)│
│  Push svc  ◄──── Push Notifier (Phase 3+)    │
│                            │                  │
│                            ▼                  │
│                       Event Bus               │
│                       (assigns evt_*,         │
│                        dispatches handlers:   │
│                        user_invoke,           │
│                        user_decision,         │
│                        tool_reverse_wake)     │
│                            │                  │
│                            ▼                  │
│                       Router (GPT-5.4)        │
│                       ├─ context_pack assembly│
│                       │  (eager: identity +   │
│                       │  skills + people/core)│
│                       ├─ vision (GPT-4V)      │
│                       └─ dispatch plan output │
│                          (+ task_continues +  │
│                          next_step_hint R-3)  │
│                            │                  │
│                            ▼                  │
│            _apply_confirm_policies (Q-9)      │
│             ├─ override requires_confirm      │
│             ├─ force preview_action if task_  │
│             │   continues OR preview-always   │
│             └─ deny → abort plan              │
│                            │                  │
│                            ▼                  │
│              Preview/Confirm Orchestrator     │
│              + Multi-step state machine       │
│              ├─ _pending_previews[cmd_id]:    │
│              │  { event, plan, subtask_       │
│              │    results, task_history,      │
│              │    [wake_response_map] }       │
│              ├─ sends cmd_* to Glass          │
│              ├─ waits user_decision           │
│              ├─ ttl timeout handling          │
│              ├─ _execute_remaining (final SEND)│
│              ├─ _advance_task (R-3 multi-step│
│              │   re-invoke; max 5 rounds)    │
│              └─ _handle_tool_reverse_wake     │
│                            │                  │
│                            ▼                  │
│              Tool Dispatcher  ──► Tool Agent  │
│              (uses _pending_rpcs futures      │
│               filled by reader demux)         │
│                            │                  │
│                            ▼                  │
│              Receipt Writer                    │
│              ├─ _write_receipt (final step)   │
│              ├─ _write_step_receipt (mid-task)│
│              └─ CHANGELOG.md append           │
│                                               │
│  Insight Engine (P6, Phase 7+)               │
│   ├─ Twin watcher (commitments, interests)    │
│   ├─ cron scheduler                           │
│   ├─ Mac event subscriber                     │
│   └─ emits self-events into Event Bus         │
│                                               │
│  Twin Reader/Writer                           │
│   ├─ fs ops                                   │
│   ├─ assemble_context_pack() — eager-load     │
│   │   identity.md + skills/* + people/core/*  │
│   ├─ CHANGELOG.md append (替代 git)            │
│   └─ mtime conflict check                     │
│                                               │
│  Implicit Learning Loop (Phase 7+)           │
│   ├─ post-task GPT self-audit                 │
│   ├─ candidate skill updates                  │
│   └─ _system/pending/skill-updates/ 写入       │
└──────────────────────────────────────────────┘
```

### 1.3 核心状态 (in-memory; in-process; lost on daemon restart)

| State | 内容 | 生命周期 |
|---|---|---|
| `_pending_previews` | key=`cmd_id`, value=`{event, plan, subtask_results, task_history, [wake_response_map, wake_session_id]}`. **`task_history` is the multi-step audit trail across rounds** | 直到 user_decision 或 ttl 过期; popped at terminal step |
| `_pending_rpcs` | key=`rpc_id`, value=`asyncio.Future` filled by `_tool_reader_loop` when matching RPCResult arrives | 直到 RPC result 返回 (120s timeout) |
| `_glass_conn` | 当前 WSS 句柄（idle 时为 None）| Hybrid 模型，按需 |
| `_tool_conn` + `_tool_reader_task` | 跟 Tool Agent 的**持久 WS** + 后台 reader task (demux RPCResult vs Event) | 常驻; reconnect on first dispatch after disconnect |
| `_confirm_policies` | dict parsed at startup from `Twin/skills/confirm-policies.md`: `{"tool:action" → policy}` | Phase 7 will hot-reload on Twin write |
| `_tools_block`, `_allowed_tools` | Cached AVAILABLE TOOLS prompt block + validation set | static at startup |

### 1.4 Event 流（统一 3 trigger 源；v0.3 reflects multi-step + reverse-wake demux）

#### A. user_invoke (Glass → Cortex)

```
1. Glass sends user_invoke → Cortex assigns evt_*
2. _handle_user_invoke → _route():
     - twin.assemble_context_pack() → eager-load Twin slices
     - router.route(event, context_pack, available_tools_block) → GPT-5.4 plan
3. _apply_confirm_policies(plan):
     - per subtask: lookup policy, override requires_confirm
     - if any preview-always or task_continues=true → force hud_kind=preview_action
     - if any deny → abort with hud_show error card; receipt; return
4. For each subtask: if result_format ∈ (draft, query) OR hud_kind=hud_show → dispatch now
5. _build_command(plan, results) → cmd; send to Glass
6. _pending_previews[cmd.id] = { event, plan, subtask_results, task_history=[] }
7. If hud_kind == hud_show:
     - write receipt; pop pending
     - if task_continues: history.append({...auto_advance}); _advance_task()
     (但 _apply_confirm_policies 强制 preview_action 时这条死路径)
```

#### B. user_decision (Glass → Cortex; SEND / FEEDBACK / DISMISS or option_id)

```
1. _handle_user_decision: pop pending by cmd_id
2. if wake_response_map[decision] exists (reverse-wake card):
     dispatch follow-up; write receipt; return
3. if decision == "send":
     if plan.task_continues:
       run any execute subtasks (defensive); write step receipt
       task_history.append(this_step); _advance_task()
     else:
       _execute_remaining (final step) + write receipt
4. if decision == "feedback":
     task_history.append({...with feedback_text});
     _advance_task(event, task_history, feedback_text, prior_plan)
       — Router re-invoked with PRIOR TASK HISTORY + USER FEEDBACK blocks;
         Router classifies feedback into (a) confirm / (b) correct / (c) skip / (d) inject;
         outputs next plan (may itself be task_continues=true → another round)
5. if decision == "dismiss": log and exit
```

#### C. tool_reverse_wake (Tool Agent push → Cortex demux reader)

```
1. _tool_reader_loop receives message; lacks `id+status` but has `kind` → demux as event
2. Construct Event(kind=tool_reverse_wake, id=evt_*) → _process_event
3. _handle_tool_reverse_wake:
     - parse payload (from_tool, wake_kind, context, session_id, options)
     - build wake_response_map (option_id → follow-up dispatch dict);
       for claude_code/permission_request: allow_once → send_keys [Enter], etc.
     - construct preview_action tool_card (or hud_show if no options)
     - send to Glass; store in _pending_previews
4. (Later) user_decision with decision=option_id → step 2 of flow B
```

#### Max task rounds + loop safety

`_advance_task` checks `len(task_history) >= MAX_TASK_ROUNDS (5)` → emit "Task too long" terminal hud_show, exit. Prevents Router loops.

### 1.5 Insight Engine (P6) 内部循环

```
每隔 N 分钟 (default 5 分钟，可在 preferences/insight-engine.md 调):
  candidates = []
  
  # 扫描 Twin 长记忆
  for commitment in Twin/commitments/*.md:
    if commitment.due 接近 today and commitment.status == "open":
      candidates.append(...)
  for interest in Twin/interests/*.md:
    if 有新关联（外部 events 提到此 topic）:
      candidates.append(...)
  
  # 扫描 Mac events (Calendar, Mail recent, etc.)
  scan Calendar for upcoming events with Twin/people/ matches
  scan Mac event subscriptions
  
  for candidate in candidates:
    # LLM 评估：is this surprising / interesting?
    verdict = GPT.evaluate(
      candidate, 
      context=[recent receipts, Twin/preferences/pulse-feedback.md]
    )
    if verdict == "surprising":
      # 包装成 self-event 入 Event Bus
      event_bus.emit(SelfEvent(kind="insight_pulse", payload=candidate))
```

**OQ-C1 决议**：Insight Engine 跑在 Cortex 进程内（同 asyncio loop），用 async 调度 + 限并发避免阻塞 Router。

### 1.6 Vision 处理 (v0.4 修订 OQ-C5)

收到 `user_invoke` 的 image 后，Cortex 内部决策需要哪种 vision：

| Vision 任务 | 谁处理 | 模型 |
|---|---|---|
| **场景 vision**（OCR / 场景理解 / 一般 visual QA）| **Cortex** 自己调 | GPT-4V |
| **人脸识别**（detection / embedding / match）| **Tool Agent** (`local_face_recognition`) | 本地模型 (OQ-D7 选型) |

人脸识别归 Tool Agent 是 v0.4 修订——用户明确"人脸不用视觉模型，本地跑就好"。Cortex 在需要人脸识别时通过 RPC 调 Tool Agent。

Vision call 成本控制：v1 不限制；OQ-N4 (post-implementation tuning)。

---

## 2. Tool Agent (手)

### 2.1 进程模型

- 单一 Python `asyncio` 服务
- `launchd` 用户级服务
- 跟 Cortex 同机，WebSocket on localhost 通信（Q-5 决议）
- **只调 Mac 本地工具**（不调云 API，包括 vision API）

### 2.2 内部 Modules (v0.3)

```
┌──────────────────────────────────────────────┐
│              Tool Agent (Hands)               │
│                                               │
│  Cortex ──►  WebSocket Server (localhost)     │
│              ├─ receives RPCDispatch          │
│              ├─ returns RPCResult             │
│              └─ pushes Events (e.g.           │
│                 tool_reverse_wake) via         │
│                 push_event(event) callable    │
│                            │                  │
│                            ▼                  │
│              Tool Registry                    │
│              (load adapters.yaml at startup,  │
│               attach_event_pusher to each     │
│               adapter that opts in)           │
│                            │                  │
│                            ▼                  │
│              Tool Adapters (12 live)          │
│              ├─ claude_code (dual-track)      │
│              ├─ applescript_mail              │
│              ├─ applescript_calendar          │
│              ├─ applescript_reminders         │
│              ├─ apple_notes                   │
│              ├─ apple_shortcuts               │
│              ├─ fs                            │
│              ├─ system_status                 │
│              ├─ safari_state                  │
│              ├─ imessage                      │
│              ├─ twin_query (calls GPT)        │
│              └─ echo (debug stub)             │
│                            │                  │
│                            ▼                  │
│              State Tracker (per adapter)      │
│              ├─ claude_code: Track A          │
│              │   sessions + Track B tmux      │
│              │   sessions + reverse-wake      │
│              │   watcher tasks                │
│              └─ status query handlers         │
└──────────────────────────────────────────────┘
```

### 2.3 Tool Adapter 统一接口 (v0.3)

```python
class ToolAdapter:
    name: str

    async def dispatch(
        self, action: str, args: dict,
        context_pack: list[str],   # Twin 文件路径
        result_format: str          # "draft" | "execute" | "query"
    ) -> dict:                     # raw result dict, server wraps into RPCResult
        ...

    # Optional opt-in for adapters that emit unsolicited events
    def attach_event_pusher(
        self,
        pusher: Callable[[dict], Awaitable[None]],
    ) -> None:
        """Called by ToolAgentServer at startup. Pusher writes `{kind, payload, ts}`
        events to the persistent Cortex connection."""
        ...
```

### 2.4 Tool Agent Server: dispatch + push_event

`tool-agent/tool_agent/server.py`:

```python
class ToolAgentServer:
    _cortex_conn: ServerConnection | None  # active Cortex WSS connection (1 at a time in v1)

    async def _push_event(event: dict) -> None:
        # Adapters call this via the attached callable. Sends unsolicited event
        # message {kind, payload, ts} on the existing Cortex connection.
        ...

    async def _dispatch(msg: dict) -> dict:
        # Handle RPCDispatch from Cortex; return RPCResult.
        adapter = registry.get(msg["tool"])
        result = await adapter.dispatch(...)
        return {id, ts, status, result, diagnostics}
```

Cortex's `_tool_reader_loop` demuxes by message shape: `id`+`status` → RPCResult; `kind` → Event.

### 2.5 v1 工具列表 (12 live + 1 reserved for Phase 6)

| 工具 | 用途 | confirm-policies 默认 |
|---|---|---|
| **claude_code** (dual-track) | Track A `claude -p` 一次性 + Track B tmux interactive + reverse-wake watcher | run/kill preview-always; draft auto; get_status auto |
| **applescript_mail** | Mail.app REPLY / COMPOSE / SEARCH 三模式 | send preview-always; read_current/list_inbox auto |
| **applescript_calendar** | Calendar.app | add_event preview-always; list_*/find_conflict/get_event auto |
| **applescript_reminders** | Reminders.app | add/list/complete auto; delete preview-always |
| **apple_notes** | Notes.app create/list/read/append/search | create/append auto |
| **apple_shortcuts** | invoke any Apple Shortcut | run preview-always (Shortcuts variable side-effects) |
| **fs** | 通用 fs ops + 白名单 write/delete + 默认排 .venv 等 | read/list/grep/append auto; write/delete preview-always |
| **system_status** | battery/focus/wifi/app/tailscale 状态 | auto |
| **safari_state** | current_tab/all_tabs/recent_history (FDA for history) | auto |
| **imessage** | send + list_recent (FDA for chat.db) | send preview-always |
| **twin_query** (调 GPT) | 语义 RAG over Twin | auto |
| **echo** | Phase 1 debug stub | auto |
| ── 保留 Phase 6 ── | | |
| **local_face_recognition** | 本地人脸 detection/embed/match | inference auto; embedding write low |

Detailed per-tool action catalogs in [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md).

### 2.6 Claude Code Adapter — dual-track architecture (v0.3 — supersedes v0.2 tmux-only)

The v0.2 spec assumed tmux-only. In v0.3 the adapter has **two tracks** with different use cases:

#### TRACK A — `claude -p` non-interactive (no tmux)

For one-shot or session-resumed prompts that return text. Best for: web/paper search (per SoT N-9), code gen, summaries, "go read X and tell me", any task whose answer is a textual artefact.

```
dispatch(action="draft"|"run"|"continue_") →
  build cmd = ["claude", "-p",
               "--permission-mode", "dontAsk",
               "--max-budget-usd", "0.50",
               "--output-format", "json",
               ("--session-id", session_id) if run/continue_,
               ("--resume",     session_id) if continue_,
               *for d in add_dirs: ("--add-dir", d),
               prompt]
  run subprocess (cwd=working_dir, timeout=300s)
  parse json output → {text, cost_usd, num_turns}
  if run: track session_id in adapter memory for later continue_
```

No tmux needed. Each call is one subprocess that exits cleanly.

#### TRACK B — interactive `claude` in tmux (+ reverse-wake watcher)

For long-running CC where user supervises asynchronously. UC2's primary path.

```
┌─ Tool Agent: claude_code adapter — Track B ──────────┐
│                                                       │
│ on dispatch(action="run_interactive"):               │
│   session_name = f"cc-{short_uuid}"                  │
│   tmux -S /tmp/cortex-tool-agent-cc.sock              │
│        new-session -d -s {session_name}              │
│        -c {working_dir}                              │
│        claude [--model X] [--add-dir Y]              │
│   if prompt: sleep 2s → tmux send-keys -l prompt → Enter│
│   if watch=true (default): start _watch_loop task    │
│                                                       │
│ async _watch_loop(session_id):                       │
│   every WATCHER_POLL_INTERVAL_S (1.5s):              │
│     pane = capture-pane -t {session_id} -p -S -200   │
│     classify pane against:                           │
│       PERMISSION_PATTERNS (CC v2: "Do you want to    │
│         proceed?" + "❯ 1. Yes" cursor + legacy y/N)  │
│       COMPLETION_PATTERNS / ERROR_PATTERNS           │
│     if match: dedup vs last (kind, snippet[:120]);   │
│       extract 5-line context;                        │
│       event_pusher({kind: tool_reverse_wake,         │
│         payload: {from_tool, wake_kind, context,     │
│           session_id, options[allow_once/always/deny]│
│         }})                                          │
│                                                       │
│ on dispatch(action="get_pane"):                      │
│   return tmux capture-pane -p -S -<lines>            │
│                                                       │
│ on dispatch(action="send_keys", literal=true):       │
│   split keys on \n; per segment:                     │
│     tmux send-keys -l (literal text)                 │
│     tmux send-keys "Enter" between segments          │
│                                                       │
│ on dispatch(action="send_keys", literal=false):      │
│   tmux send-keys (named keys list, e.g. [Down,Enter])│
│                                                       │
│ on dispatch(action="kill"):                          │
│   stop_watcher; tmux kill-session                    │
└──────────────────────────────────────────────────────┘
```

**Permission response (CC v2 arrow-key menu)**:
- option 1 (Yes) → `send_keys(literal=false, keys=["Enter"])`
- option 2 (Always allow) → `send_keys(literal=false, keys=["Down", "Enter"])`
- option 3 (No) → `send_keys(literal=false, keys=["Down", "Down", "Enter"])`

Cortex's `_handle_tool_reverse_wake` builds the wake_response_map accordingly.

**Regex keyword maintenance** (currently inlined in `tool_agent/adapters/claude_code.py`; Phase 7 hot-reloads from `twin-seed/skills/claude-code-control.md`):

```python
PERMISSION_PATTERNS = [
  re.compile(r"Do you want to proceed\?", re.IGNORECASE),    # CC v2 modern
  re.compile(r"❯\s*1\.\s+Yes", re.MULTILINE),               # CC v2 menu cursor
  # Legacy y/N patterns retained as fallback
  ...
]
COMPLETION_PATTERNS, ERROR_PATTERNS — similar
```

Verified live against CC v2.1.x by `test-harness/real_cc_reverse_wake.py` 2026-05-24.

### 2.7 twin_query — the only LLM-calling Tool Agent adapter

`twin_query.ask(question)` does grep + GPT synthesis. Tool Agent loads `.env` to get `OPENAI_API_KEY`. See [TOOL-ADAPTERS.md §9](TOOL-ADAPTERS.md). This adapter exists separately from Cortex's own GPT-4V calls — Tool Agent's `twin_query` is callable by Router as a normal tool dispatch.

### 2.6 Tool 失败策略 (OQ-C3 决议)

**v1 不自动重试**：
- Tool Adapter return `failure` status → Tool Agent → Cortex RPC result {status: "failure"}
- Cortex 通过 `hud_show` 推 Glass: "X 工具失败了：{diagnostics}"
- 用户决定重试（重新发 user_invoke）

**理由**: 跟 Q-6 的精神一致（出错就告诉你）；不掩盖问题。

### 2.7 长任务监控 (UC2 "做得怎么样了？")

State Tracker 维护 active 长任务列表：

```
active_tasks: dict[task_id, TaskState]

TaskState:
  tool: str
  rpc_id: str
  started_at: ts
  last_output: str  # tail of tmux buffer
  status: "running" | "paused (waiting confirm)" | "completed" | "failed"
```

UC2 query 流：
1. 用户语音 "Claude Code 做得怎么样了？"
2. Glass → Cortex (user_invoke)
3. Router 决策：是 query → dispatch rpc(tool=claude_code, action=get_status, result_format=query)
4. Tool Agent: claude_code adapter 返回 last_output + status
5. Cortex → Glass: hud_show 摘要

---

## 3. MCP Server

### 3.1 进程模型

- Python service + `launchd`
- v1: MCP over stdio (subprocess 模式) 或 HTTP（按 OQ-S4 实施时决定）
- **Read-only**（不允许外部写 Twin）

### 3.2 内部 Modules

```
┌──────────────────────────────────────┐
│           MCP Server                  │
│                                       │
│  外部 AI  ──►  MCP Protocol Handler   │
│                (stdio or HTTP)        │
│                       │               │
│                       ▼               │
│                Token Auth              │
│                (token → label match)  │
│                       │               │
│                       ▼               │
│                Twin Slice Reader       │
│                ├─ filter by share:    │
│                └─ return markdown     │
│                                       │
│  Exposed tools:                       │
│   read_twin / list_twin /             │
│   query_twin (RAG) /                  │
│   get_identity / get_preferences      │
└──────────────────────────────────────┘
```

### 3.3 query_twin 实现（v1 minimal）

- 简单 `grep` / `find` 拉相关文件路径
- 这些 markdown 内容 + question → GPT 综合答案
- **不上 vector DB / embedding 数据库**（SoT C-7 markdown skill-style，参考 Skill 不用 embedding）
- 性能不是 v1 priority

---

## 4. 跨组件 UC1 Walkthrough

用 UC1 邮件代回完整 trace 一遍，验证组件设计是否跑通：

```
T+0.0   Glass: 用户语音触发 + 同时抓照片
        发 user_invoke {image, text="回复 Jane 邮件，3 点到，简短温暖"}

T+0.1   Cortex Transport 收 → Event Bus 分配 evt_001

T+0.3   Router 拼 context pack:
        - 读 Twin/preferences/email-style.md
        - 读 Twin/people/jane-doe.md
        - 读 Twin/preferences/communication.md
        - image 给 GPT-4V (Router 判断是否需要 vision；
          本例只看 text 就够，image 仅备用)
        调 GPT API → 输出 dispatch plan:
        {
          subtasks: [
            {tool: claude_code, action: "read_current_email",
             result_format: "query"},
            {tool: claude_code, action: "draft_email_reply",
             args: {tone: "casual_warm", length: "short"},
             context_pack: [...], result_format: "draft"},
            {tool: applescript_mail, action: "send",
             args: {draft_id: <to-be-filled>},
             result_format: "execute", requires_confirm: true},
            {tool: applescript_reminders, action: "add",
             args: {due: "+3h", title: "meeting with Jane"},
             result_format: "execute"}
          ]
        }

T+0.4   Tool Dispatcher 发 rpc_001 (read_current_email) → Tool Agent
T+0.6   Tool Agent: claude_code adapter via tmux 读取 Mail.app 当前邮件
T+0.9   Cortex 收 rpc_001 result (邮件正文)

T+1.0   Tool Dispatcher 发 rpc_002 (draft_email_reply)
T+2.8   Tool Agent: claude_code 调用 Claude API 内部生成草稿
        rpc_002 result: 邮件草稿 markdown

T+2.9   Cortex Preview/Confirm:
        查 confirm-policies.md → applescript_mail:send → ALWAYS preview
        发 cmd_001 = preview_action
          { action_description: "Send to Jane",
            action_diff: "<草稿正文 markdown>",
            card_id: "email-preview-001" }
        Glass 收到 → 显示 HUD 卡

T+3.0   Glass HUD 显示草稿 + 等用户

T+8.0   用户 confirm（任意方式：Ring tap / temple tap / 语音 "Send"）
        Glass 发 user_decision {in_reply_to: cmd_001, decision: "confirm"}

T+8.1   Cortex: Tool Dispatcher 发 rpc_003 (applescript_mail send)
T+8.3   Mail.app 邮件发出 → rpc_003 result success

T+8.4   Cortex: 查 confirm-policies.md → applescript_reminders:add → auto
        Tool Dispatcher 发 rpc_004 (applescript_reminders add) 跳过 preview
T+8.5   Reminders.app 加提醒 → rpc_004 result success

T+8.6   Receipt Writer: 写 Twin/receipts/2026-05-23.md
        包含 evt_001 → cmd_001 → rpc_001/002/003/004 完整 chain
        git commit: cortex-add: receipts/2026-05-23.md — email reply +
                    reminder to Jane [src:evt_001]

T+8.7   Cortex → Glass: hud_show {body: "✓ 已发送 + 加了 3 小时后提醒"}
T+8.8   Status 回 idle，WSS 保持 30s 等可能 follow-up → 关 WSS
```

### 4.1 关键观察

- 同一 dispatch plan 可有多个 subtasks；Cortex 串行执行（v1）
- subtask 的 `requires_confirm` 由 confirm-policies.md 查询决定，**不是** dispatch plan 写死
- Receipt 一个 evt_001 对应可能多个 rpc_*，组成完整 chain
- 整条 walkthrough 没违反"Cortex 用 GPT API"+"Tool Agent 只调 Mac 本地"的边界

---

## 5. Twin Write 协议 (v0.4 修订: 去 git，改 CHANGELOG)

### 5.1 CHANGELOG.md 替代 git (用户决议)

Twin **不入 git**，**不 push GitHub**。维护一个 append-only 的人可读 `CHANGELOG.md`。详见 [DATA-MODEL §12](DATA-MODEL.md)。

### 5.2 写入策略

```
Cortex 想写 Twin path:

1. 决定 path (含人物 core vs encounters 判定)
2. 读 _system/TOC.md 看 path 是否存在
3. path 不存在 → 创建 + 写 CHANGELOG entry + 更新 TOC.md
4. path 存在:
   a. 读 current content + 检查 mtime (比 Cortex 上次读后晚 = 用户改过)
   b. LLM 生成新版本
   c. if confidence ≥ 0.7 AND mtime 没冲突:
        覆写 + 写 CHANGELOG (含字段 diff) + 更新 TOC.md
   d. else:
        写 _system/pending/{date}-{slug}.diff.md
        next morning HUD: "N pending Twin reviews"
```

confidence 阈值在 `skills/twin-write-policy.md`，用户可调。

### 5.3 CHANGELOG entry 示例

```
## 2026-05-23

### 19:30 — email reply to Jane [src:evt_001]
- Added: receipts/2026-05-23.md (new file)
- Updated: people/core/jane-doe.md
  - last_contact: 2026-05-15 → 2026-05-23
  - Added "Recent interactions" entry
```

### 5.4 Implicit Learning Loop 的写入

任务结束后异步：Cortex 自审 → LearningCandidate(s)：
- if confidence ≥ 0.8 AND 是已有 skill 微小补充 → 直接 append 到 `skills/{name}.md` + CHANGELOG
- else → 写到 `_system/pending/skill-updates/`，等用户 review

详见 [DATA-MODEL §9](DATA-MODEL.md)。

---

## 6. Confirm Policy (OQ-C2 决议)

### 6.1 默认策略

**默认全 preview**（最严守 SoT D-H）。

### 6.2 用户 opt-out 通过 `Twin/skills/confirm-policies.md`

v1 ship with 一份默认 opt-out 列表（balance 严守 vs 体感）：

```yaml
---
type: preference
---

# Confirm Policy Overrides (v1 defaults)

# 加提醒、加日历事件不烦你（轻量、低风险）
applescript_reminders:add  : auto
applescript_calendar:add   : auto

# 发邮件、改代码、写文件永远 preview（高风险）
applescript_mail:send      : preview-always
claude_code:edit           : preview-always
fs:write                   : preview-always
fs:delete                  : preview-always

# 读类操作不烦你
applescript_mail:read      : auto
applescript_calendar:read  : auto
fs:read                    : auto
fs:grep                    : auto

# 默认其他：preview-default
*                          : preview-default
```

### 6.3 解析

Cortex 的 Preview/Confirm Orchestrator 在每个 subtask 前查 confirm-policies.md：
- `auto` → 跳过 preview，直接 execute
- `preview-always` → 必须 preview，即使是低风险
- `preview-default` → preview（默认）
- 通配符 `*` → fallback 规则

---

## 7. Decisions (OQ-C1 ~ C6)

| # | 决议 |
|---|---|
| OQ-C1 | Insight Engine 跑在 Cortex 进程内（asyncio loop）|
| OQ-C2 | 默认全 preview + confirm-policies.md opt-out |
| OQ-C3 | Tool 失败不自动重试，告诉用户 |
| OQ-C4 | Claude Code 经 tmux session 控制 + regex watch |
| OQ-C5 | **(v0.4 修订)** 场景 Vision (OCR / 一般 vision) 归 Cortex (GPT-4V)；**人脸识别归 Tool Agent** 本地模型 |
| OQ-C6 | **(v0.4 修订)** Twin 去 git，改 `CHANGELOG.md` append-only 日志；按"语义单元"记录变更 |

---

## 8. Open Questions

| # | 问题 | 计划归宿 |
|---|---|---|
| OQ-N1 | Insight Engine 扫描频率（default 5min 是否合适）| implementation tuning |
| OQ-N2 | preview ttl 默认值（30s? 60s? 用户可调）| #8 UI/UX session |
| OQ-N3 | confirm-policies.md 是否支持正则匹配 / 通配符 | future need-driven |
| OQ-N4 | Vision call 成本控制（GPT-4V 价格不低）| post-implementation tuning |
| OQ-N5 | tmux session 命名冲突 / 清理策略 | adapter implementation detail |
| OQ-N6 | Tool Agent 重连 Cortex 时 active_tasks 怎么恢复 | implementation detail |

---

## 9. Document Status

- **Version**: v0.3
- **Last updated**: 2026-05-24
- **Based on**: live `cortex/cortex/*.py` + `tool-agent/tool_agent/*.py` + R-3 paradigm + verified Phase 5 UC2 reverse-wake
- **Next**: Phase 3 Glass client internals (separate doc when Android module exists)

### Revision Log

| Version | Changes |
|---|---|
| v0.1 | 首版：Cortex / Tool / MCP 内部 modules + UC1 walkthrough + OQ-C1~C6 决议 |
| v0.2 | OQ-C5 修订：人脸识别归 Tool Agent (本地模型)；Tool 列表加 `local_face_recognition`；OQ-C6 修订：Twin 去 git，改 CHANGELOG.md；Cortex 增加 Implicit Learning Loop module；§6.2 confirm-policies 路径改 `skills/` |
| v0.3 | **Phase 1+2 + R-3 实现完成 → spec 同步**: §1.2 Cortex modules 重写 (加 _apply_confirm_policies / _advance_task multi-step / _handle_tool_reverse_wake / _tool_reader_loop demux / context_pack eager-load)；§1.3 state 重写 (`_pending_previews.task_history` 跨轮 + `_pending_rpcs` futures + `_confirm_policies` parsed at startup)；§1.4 event flow 重写为 A/B/C 三种 (user_invoke + user_decision + tool_reverse_wake) + max 5 rounds 安全；§2.2 Tool Agent modules 加 push_event channel; §2.3 adapter contract 加 `attach_event_pusher` optional opt-in; §2.4 server push_event；§2.5 工具列表扩到 12 live (+1 reserved Phase 6); §2.6 **重写 claude_code 为 dual-track** (Track A `claude -p` 非交互 + Track B tmux + watcher with CC v2 patterns) — supersedes v0.2 tmux-only assumption; §2.7 加 twin_query 作为唯一 LLM-calling Tool Agent adapter |

---

*End of Constellation Component Design v0.3.*
