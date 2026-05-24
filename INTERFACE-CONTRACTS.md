# Constellation — Interface Contracts

**Version**: v0.6
**Status**: 设计阶段 → 实现同步 (R-3 paradigm + reverse-wake event push 落地)
**关联文档**: [DESIGN.md](DESIGN.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [DATA-MODEL.md](DATA-MODEL.md) · [SOURCE-OF-TRUTH.md](SOURCE-OF-TRUTH.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md)
**Last updated**: 2026-05-24

本文档定义 Constellation 各组件**之间**的 schema：消息、命令、RPC、Twin 文件约定、对外 API。所有 schema 从 SoT + 6 promises + [DESIGN.md §3](DESIGN.md) 架构 derive。

---

## 0. 设计原则

| 原则 | 含义 |
|---|---|
| **节能第一 (Glass)** | Glass 字段尽量少；不做内部状态判断；不生成 client-side ID；不携带可由 Cortex 推断的字段 |
| **Hybrid 连接模式 (Glass ↔ Cortex)** | 用户活跃期 WSS 保持；idle 期关 WSS，靠 push notification 唤醒。详见 §1.6 |
| **Always-on mic per HUD card (R-3 / C-22)** | Glass 每张 HUD card 出现时默认开麦 + VAD-stop；30s timeout 等戒指 tap。用户语音 → `user_decision { decision: "feedback", feedback_text: "..." }`；戒指 tap default → `user_decision { decision: "send" }` (或 option_id)。**两条 channel 完全平行**，用户自选 |
| **Multi-step task chain (R-3 / C-20)** | Plan 可标 `task_continues=true` + `next_step_hint`；Cortex 端跨轮维护 `task_history` (in-memory)；Glass 端 unchanged — 看到的就是一系列 preview_action cards |
| **JSON for messages, YAML for Twin frontmatter** | 消息走机器；Twin 走 vim |
| **ID 由接收端分配** | Glass 上传不带 id；Cortex 收到后分配 `evt_*`。Cortex 下发 Command 时分配 `cmd_*`，Glass 端后续 `user_decision` 用 `in_reply_to=cmd_id` 关联 |
| **未知字段忽略** | 向后兼容；schema 可演化不破坏 |
| **side-effecting 必有 `requires_confirm`** | P3 在 schema 层强制 + Cortex 启动加载 `confirm-policies.md` 在 `_apply_confirm_policies` 强制 override (defense in depth, Q-9) |
| **结合 Q-6（断网直接报错）** | Glass 端**无**本地 ACK / retry / 缓存机制 |
| **Cortex 输入永远 `{text, image?}` (R-1 / C-17)** | 从不接收原始音频；STT 在 Glass / phone / 客户端完成 |

---

## 1. Glass → Cortex (Event)

### 1.1 通用结构

```json
{
  "ts": "2026-05-23T19:30:00Z",
  "kind": "user_invoke" | "user_decision",
  "payload": { ... per kind ... }
}
```

### 1.2 砍掉的字段（相对早期草稿）

| 字段 | 砍掉的理由 |
|---|---|
| ~~`id`~~ | Cortex 接收端分配；Glass 不缓存不重传，client-id 用不上 |
| ~~`source.device_id`~~ | v1 只有一个 Glass |
| ~~`source.device_kind`~~ | Cortex 知道 event 从哪条 socket 进 |
| ~~`source.client_version`~~ | 握手时由 Cortex 记录；不必每条 event 携带 |
| ~~`context_hints`~~ | Glass 不做内部状态判断（节能 + 简化）|
| ~~`voice_text`~~ + ~~`photo`~~ kinds 拆分 | 合并成 `user_invoke`（每次必带 image + text）|
| ~~`touch_gesture`~~ / ~~`ring_gesture`~~ kinds | 戒指处理，对 Cortex 不可见 |

### 1.3 Event Kinds (v1 仅 2 种)

| kind | payload | 说明 |
|---|---|---|
| `user_invoke` | `{ image: <base64\|blob ref>, text: "..." }` | **每次用户触发都同时带图片 + STT 文字**。Glass 不区分"拍照场景"和"语音场景"；触发瞬间立即抓一张照片 + 开始 STT，两个一起发给 Cortex。Cortex 决定要哪个。用户没说话时 `text` 为空串 |
| `user_decision` | `{ in_reply_to: "cmd_...", decision: "send"\|"feedback"\|"dismiss", feedback_text?: "..." }` | 对 Cortex 推送的 preview / hud 的响应。`feedback` 自带 `feedback_text` (新一轮 STT 录入)，Cortex 拿到后重新生成迭代版 preview |

### 1.4 设计说明

- **Glass 不区分语音意图来源**（Ring tap / temple touch / voice keyword）—— 都是 Glass 内部的事
- **每次 `user_invoke` 必带 image + text**：为了避免漏采视觉信息，Glass 触发时立刻抓快照（节能 vs 漏信息的 trade-off 选了不漏）
- **两个 Global gesture 入口**（参 [Doc/ui-mockup.html §3](Doc/ui-mockup.html)）:
  - **Quick Shortcut**: `text` = 预置 prompt (来自 `twin/skills/shortcuts.md`)、`image` = 即刻拍照、不开麦
  - **Voice Invoke**: `text` = STT 实时转录、`image` = 即刻拍照、麦克风 + VAD-stop
- Cortex 端 Vision 推理（OCR / 场景理解）用 GPT-4V；**人脸识别归 Tool Agent 本地模型**（v0.4 修订 OQ-C5）
- **照片大小 / 编码 / 压缩** = Glass 内部决策（节能优先）
- `text` 为空串说明用户没说话；Cortex 可能只看 image 决策（如果 image 含明确意图）或忽略 event

### 1.5 Feedback Loop / Free-Form Response Channel (v0.6 升级 per R-3)

**v0.6 paradigm shift** (per SoT R-3 / C-22): feedback is NOT a special opt-in mode the user
enters by tapping a `FEEDBACK` option. It's the **default voice channel** that is implicitly
available on EVERY HUD card. Each card has a parallel set of response channels:

```
HUD card displayed → Glass UI:
  ┌──────────────────────────────────────────┐
  │ (mic opens automatically + VAD-stop)     │
  │ Card body + options                      │
  └──────────────────────────────────────────┘

User responds (whichever first):
  EITHER  Ring tap default option (戒指点) → user_decision { decision: "send" } (or option_id)
  OR      Voice (any utterance)         → user_decision { decision: "feedback", feedback_text }
  OR      No response within ttl       → Glass auto-dismisses → user_decision { decision: "dismiss" }
```

In multi-step task context (Router emitted `task_continues=true`), the `feedback_text`
can carry one of FOUR semantic intents (Router judges by content per CORTEX-ROUTER-PROMPT §1.2):

| Category | Example | Cortex/Router behavior |
|---|---|---|
| (a) CONFIRM | "yes", "对", "ok proceed" | Router proceeds per `next_step_hint` as if SEND was tapped |
| (b) CORRECTION | "actually 4pm not 10am" | Router recomputes current step with correction; emits revised plan |
| (c) SKIP | "skip the reminder", "that's all" | Router emits terminal plan; aborts the skipped subtask |
| (d) INJECT-INFO | "the meeting is Thursday 4pm" | Router uses user value as ground truth; advances |

**Implementation note (v0.6)**: The mechanism is the same as v0.5 — `user_decision.feedback_text`. What changed is:
- Glass client opens mic by **default** on every card (was: only after user tapped FEEDBACK option)
- Cortex Router's system prompt has explicit §1.2 instructions to classify feedback into 4 categories
- `_pending_previews[cmd_id]` carries `task_history` across rounds; Cortex re-invokes Router with both `task_history` + `feedback_text` blocks in the user prompt

**Legacy single-step feedback** (Slice B behavior) is a degenerate case: `task_history` is
empty, only `feedback_iteration` present. Router still works — same prompt categories apply,
just no prior step context to consult.

**Receipt chain**: same `evt_*` may produce multiple `cmd_*` (one per round), plus
step-level receipts `[step N]` for multi-step. Final receipt at last step.

**Glass client responsibility** (Phase 3 hard requirement per C-22): always-on mic + VAD per card. Implementation freedom: brief on-screen waveform indicator is fine; explicit "Listening…" pill is fine; silent mic is fine. **Required**: mic is reachable without user first tapping an option.

### 1.6 Connection Model: Hybrid (Q-1 决议)

**用户活跃期** (active phase):
1. 用户触发 → Glass 立即建 WSS over Tailscale (or 复用已有连接)
2. 发 `user_invoke`
3. WSS 保持 5-30s，等 Cortex 可能的 Command (preview / hud_show)
4. 期间用户做 follow-up → 同一 WSS 复用，发 `user_decision` 等

**Idle 期** (idle phase):
1. 用户 idle X 秒 → Glass 主动关 WSS
2. Glass 进 deep sleep，仅监听 push notification

**Cortex 主动推送** (P4 / P6 触发):
1. Cortex 想推 Command → 通过 push notification 服务（Q-7 选型，FCM 或 Rokid push）发 wake signal
2. Glass 收 push → wake → 建 WSS over Tailscale → 拉 pending commands
3. 消化完 Command + 等可能的 user_decision → 关 WSS

**关键设计**：
- Push notification **只携带 wake signal**（不携带 payload）
- 所有真实 payload 仍走 Tailscale + WSS（保持加密 + 主路径不变）
- Cortex 端：每个 user 有一个 `push_token` (Q-7 决定哪家)；Cortex 通过 push 服务的 API 发 wake
- Glass 端：注册 push token；wake 后立即建 WSS

**体感延迟**:
- 用户主动触发：~ 1-3s（WSS 已开 / 即开）
- Cortex 主动推送：~ 2-5s（push 投递 1-3s + WSS 建立 + 拉取）

---

## 2. Cortex → Glass (Command)

### 2.1 通用结构

```json
{
  "id": "cmd_01HXAA...",
  "ts": "2026-05-23T19:30:00Z",
  "kind": "hud_show" | "preview_action" | "hud_dismiss" | "hud_update",
  "payload": { ... per kind ... },
  "requires_confirm": true,
  "ttl_ms": 30000
}
```

### 2.2 砍掉的字段（相对早期草稿）

| 字段 | 砍掉的理由 |
|---|---|
| ~~`in_reply_to`~~ | 不必显式回指 event；proactive (P6) 本来就没有 |
| ~~`target_device`~~ | v1 只有一个 Glass |
| ~~`confirm_via`~~ | Glass 自决用哪种交互方式触发 confirm（Ring tap / temple tap / 语音都行）|
| ~~`haptic_pulse`~~ kind | v1 不主动振动（节能 + Ring 触觉反馈由 Ring 自己决定）|
| ~~`tts_speak`~~ kind | v1 不主动 TTS（节能 + 用户大多在 HUD 静默环境）|

### 2.3 Command Kinds (v1 仅 4 种)

| kind | payload | 说明 |
|---|---|---|
| `hud_show` | `{ title, body, icon?, card_id? }` | 显示一个 HUD 卡 |
| `preview_action` | `{ action_description, action_diff, card_id? }` | 显示待执行动作预览，等 `user_decision` |
| `hud_update` | `{ card_id, body }` | 更新已显示的卡 |
| `hud_dismiss` | `{ card_id }` | 主动撤掉卡 |

### 2.4 关键设计

- **`action_diff` 是 markdown**：Glass 渲染层只信 markdown；每个 Tool adapter 自己负责把工具调用参数渲染成可读 markdown
- **`card_id` 引用机制**：`hud_show` / `preview_action` 时 Cortex 在 payload 里给 card 命名；后续 `hud_update` / `hud_dismiss` 通过 `card_id` 引用
- **`ttl_ms` 默认 30000**（30 秒）；超时未 confirm → Glass 自动 dismiss + 上报 `user_decision { decision: "dismiss" }`（隐式 timeout，避免悬挂的 preview）

---

## 2.5 Internal: Dispatch Plan (Router output, Cortex-internal)

Plan is Router's output to Cortex (NOT a wire message visible to Glass). Glass only sees `Command`s (§2). But schema here for completeness — see CORTEX-ROUTER-PROMPT.md §1 OUTPUT SCHEMA for the authoritative shape.

```json
{
  "primary_intent": "kebab-case",
  "subtasks": [{ "tool", "action", "args", "context_pack", "result_format", "requires_confirm" }],
  "hud_response": { "kind", "icon", "title", "body_template", "options" },
  "reasoning": "...",

  // ── Multi-step (v0.6, optional; default both null/false) ──
  "task_continues": true | false,
  "next_step_hint": "..."
}
```

When `task_continues: true`:
- Cortex enforces `hud_response.kind = preview_action` (overrides `hud_show`) so the user has a yield point (C-22 always-mic doesn't help if Glass auto-closes the card)
- After SEND or any FEEDBACK, Cortex appends to `task_history` and re-invokes Router
- Maximum 5 rounds per task

---

## 3. Cortex ↔ Tool Agent (RPC + Event Push)

走 **持久** WebSocket on localhost（Q-5）。双向，long-lived。Cortex 端是 client，Tool Agent 是 server. Both directions multiplex two message shapes — Cortex `_tool_reader_loop` demuxes by presence of `id+status` (RPCResult) vs `kind` (Event).

### 3.1 Cortex → Tool Agent: dispatch

```json
{
  "id": "rpc_01HXAA...",
  "ts": "2026-05-23T19:30:00Z",
  "tool": "claude_code",
  "action": "draft_email_reply",
  "args": { ... },
  "context_pack": [
    "preferences/email-style.md",
    "people/jane-doe.md"
  ],
  "result_format": "draft"
}
```

`result_format` 三种语义：

| 值 | 语义 |
|---|---|
| `draft` | 只返回预览（用于 Cortex 拿到后推 `preview_action` 给 Glass）；**不副作用** |
| `execute` | 直接执行，返结果摘要；调用前 Cortex 已经从用户获得 confirm |
| `query` | 只读查询（如"查看 Claude Code 状态"）；无副作用 |

### 3.2 Tool Agent → Cortex: result

```json
{
  "id": "rpc_01HXAA...",
  "ts": "2026-05-23T19:30:00Z",
  "status": "success",
  "result": { ... },
  "diagnostics": null
}
```

`status` 取值：

| 值 | 语义 |
|---|---|
| `success` | 完成 |
| `failure` | 工具失败；`diagnostics` 填错误信息；**v1 不自动重试** (OQ-C3) |
| `needs_confirm` | 工具内部要求用户确认（罕见；正常 confirm 应该在 Cortex 层完成）|
| `tool_paused` | 长任务被卡住（如 Claude Code 等权限）——通常这种情况 Tool Agent 已经发了 `tool_reverse_wake` event |

### 3.3 Tool Agent → Cortex: reverse-wake (P4) — adapter push channel

Tool Agent adapters that opt into the push channel (via `attach_event_pusher` per [TOOL-ADAPTERS.md §0 contract](TOOL-ADAPTERS.md)) can emit unsolicited events on the same WS connection. Cortex's reader demuxes by message shape.

```json
{
  "ts": "2026-05-24T20:39:07Z",
  "kind": "tool_reverse_wake",
  "payload": {
    "from_tool": "claude_code",
    "wake_kind": "permission_request",
    "context": "echo 'hello' > /tmp/cc-real-reverse-wake-test.txt\nDo you want to proceed?",
    "session_id": "cc-f4c8526e71",
    "options": [
      { "id": "allow_once",   "label": "Allow once" },
      { "id": "allow_always", "label": "Always allow" },
      { "id": "deny",         "label": "Deny" }
    ]
  }
}
```

**Demux key (v0.6)**: incoming Tool-conn message has `id` + `status` → RPCResult (matches a pending dispatch future); incoming message has `kind` → Event (Cortex assigns `evt_*` and feeds to `_process_event`).

`wake_kind` 取值：

| 值 | 场景 | Cortex 处理 |
|---|---|---|
| `permission_request` | 工具要权限（UC2 主场景）| `_handle_tool_reverse_wake` 建 preview_action tool_card + wake_response_map (opt_id → follow-up send_keys dispatch); user_decision 命中 opt_id → dispatch follow-up |
| `completion_notice` | 长任务完成（如"build done"）| Build hud_show; write receipt; no follow-up |
| `error` | 工具崩溃需要用户介入 | Build hud_show w/ error icon; receipt |
| `surprising_event` | 工具察觉到值得用户知道的事（如 GitHub 收到 review）| Build hud_show; receipt; future Phase 7 Insight Engine may rank these |

**Implementation reference (Cortex)**: `cortex/cortex/server.py` `_handle_tool_reverse_wake` + `_pending_previews[cmd_id].wake_response_map` (option_id → follow-up dispatch dict). For claude_code permission menus, default `wake_response_map` is `{allow_once: send_keys([Enter]), allow_always: send_keys([Down, Enter]), deny: send_keys([Down, Down, Enter])}` (per CC v2 arrow-key menu — see [TOOL-ADAPTERS.md §1](TOOL-ADAPTERS.md)).

---

## 4. Twin Frontmatter (YAML)

### 4.1 通用字段（所有 Twin 文件）

```yaml
---
type: person
created: 2026-04-12T14:30:00Z
updated: 2026-05-23T19:30:00Z
share: [claude, gpt]
confidence: 0.85
sources:
  - evt_01HXAA...
  - rcpt_01HXAA...
---
```

**砍掉的字段**：

| 字段 | 砍掉理由 |
|---|---|
| ~~`name`~~ | == filename 去 `.md`，纯冗余 |

### 4.2 type 取值

详细 schema 见 [DATA-MODEL.md](DATA-MODEL.md)。

| type | 用途 |
|---|---|
| `identity` | 你的核心档案（1 个）|
| `skill` | **Prescriptive 指令文档**——"AI 应该怎么作为我做事"（email-style、code-review、transcript-to-insights 等；替代之前的 `preference`）|
| `person` | 人物档（core tier，一人一文件）|
| `encounters` | 偶遇汇总（一个文件多 section）|
| `project` | 项目档 |
| `receipt` | 一天的动作 audit log（按日聚合）|
| `commitment` | 你说过要做但未做的事（P6 扫描）|
| `interest` | 长期关心的话题（P6 扫描）|
| `conversation` | 对话 / 会议转写 |
| `memory` | 非文本记忆容器（人脸图等）|
| `schema` | `_system/` 元 schema |

### 4.3 Type-specific 字段（v1 关键）

| type | 字段 |
|---|---|
| `identity` | (维度自由) |
| `skill` | `name`, `description` (LLM 按需加载靠这个) |
| `person` | `relation`, `affiliation`, `fields`, `last_seen`, `aliases` |
| `commitment` | `due`, `to`, `status` (open/done/abandoned), `source_conversation` |
| `interest` | `topic`, `signal_strength`, `last_signal_at` ← **Insight Engine (P6) 扫描目标** |
| `receipt` | `date`（按日聚合，body 内每条 receipt 单独 section）|
| `project` | `repo_path`, `status` |
| `conversation` | `date`, `participants`, `topic`, `duration_minutes`, `location` |
| `memory` | `person` 等 type-specific 关联字段 |
| `schema` | （元层级，由 Cortex 写入）|

> 详细 schema + skill 形态 + Implicit Learning Loop 见 [DATA-MODEL.md](DATA-MODEL.md)。

### 4.4 `share:` 语义

| 值 | 含义 |
|---|---|
| `none` | MCP 不暴露 |
| `all` | 所有 MCP token 可读 |
| `[claude, gpt]` | 列表中标签匹配的 token 可读 |

v1 token ↔ 标签是 **手工分配**（你自己发 token 时决定它对应哪个标签）。

---

## 5. MCP API

### 5.1 暴露的 tools

| tool | 输入 | 输出 | 说明 |
|---|---|---|---|
| `read_twin` | `path: str` | markdown content | 若 `share:` 不允许返 403 |
| `list_twin` | `prefix: str` | path 列表（过滤后）| 同上规则 |
| `query_twin` | `question: str` | LLM 综合的答案 | Cortex 内部 RAG / grep + LLM |
| `get_identity` | — | identity.md content | 便捷接口 |
| `get_preferences` | `topic: str` | preferences/{topic}.md content | 便捷接口 |

### 5.2 关键设计

- **只读** (v1)：外部 AI 不能写 Twin；所有改动必须经 Cortex（保 P3 supervision）
- **Token 即身份**：每个 MCP client 一个 token；token 对应 `share:` 字段里的某个标签

---

## 6. 跨 schema 一致性

| 约定 | 描述 |
|---|---|
| **ID 命名前缀** | `evt_*` (event)、`cmd_*` (command)、`rpc_*` (RPC)、`rcpt_*` (receipt)、`pulse_*` (P6 proactive)。前缀让 Twin grep 时一眼看出来源 |
| **时间字段** | ISO 8601 UTC，全系统统一 |
| **关联追溯** | `event → command → rpc → receipt` 通过 `in_reply_to` / `sources:` 反向可查 |
| **proactive (P6) 链路** | Pulse 是 Command（kind=`hud_show` 或 `preview_action`），没有"回指 event"，但 Twin/receipts 里对应的 receipt 文件会带 `triggered_by` 指向触发它的 Twin 文件 / cron / Mac event |

---

## 7. v1 不做的事（明确暂缓）

| 项 | 理由 |
|---|---|
| Schema 版本号 / 迁移 | v1 不写代码，加 `schema_version` 字段不晚 |
| Multi-user / Multi-tenancy | SoT N-5 排除 |
| Payload-level 加密 | N-5 不为隐私；Tailscale transport 已加密 |
| **原始音频上传 (audio raw)** | C-17 (R-1) — Cortex 永远不收原始音频 |
| Streaming (长 audio / 长 video) | C-17 + v1 photo + text 单条；流式留 v2 |
| Glass 端 ACK / retry / 缓存 | Q-6: 直接报错给用户 |
| Haptic / TTS 命令 | 节能 + Ring 自己负责触觉 |
| 手势 event | Ring 不可见，Glass 不上报 |
| 永久 WSS 长连接 (Glass↔Cortex) | Q-1: Hybrid 连接，节能优先。**注意**: Cortex↔Tool Agent 是持久连接，独立机制 |
| Multi-step task state 跨 daemon restart persistence | v1: in-memory only; daemon crash mid-task = task lost. Phase 7 可加 `_system/active_tasks/{cmd_id}.json` snapshot |
| Mail push notification 订阅 | C-18/N-11: 走 iPhone+Glass Apple 生态 |

---

## 8. Open Schema Questions

| # | 问题 | 影响 |
|---|---|---|
| OQ-S1 | `user_invoke.image` 是 inline base64 还是 blob upload（先 POST 再带 ref）| 节能 vs 简单 |
| OQ-S2 | `preview_action.action_diff` 的 markdown 模板约定 | 影响 Tool adapter 接口 |
| OQ-S3 | Tool agent 内部状态查询的具体 schema（UC2 "做得怎么样了？"）| 长任务监控 |
| OQ-S4 | MCP token 怎么生成 / 管理 / 撤销 | P5 实施细节 |
| OQ-S5 | Push notification payload 是否需要带 hint（如 wake 原因，让 Glass 立刻显示什么）vs 纯 wake signal | UX vs 简洁 |

---

## 9. Document Status

- **Version**: v0.6
- **Last updated**: 2026-05-24
- **Based on**: [DESIGN.md](DESIGN.md) §3 架构 + [SOURCE-OF-TRUTH.md](SOURCE-OF-TRUTH.md) R-1/R-2/R-3 + 实现验证 (Phase 1+2 + multi-step deep test 3/3 PASS + real CC reverse-wake)
- **Companion**: [DESIGN.md](DESIGN.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md)

### Revision Log

| Version | Changes |
|---|---|
| v0.2 | 首版（设计阶段）：Event/Command/RPC/Twin/MCP 5 套 schema；Glass 简化（砍 ID/device/手势）|
| v0.3 | Event kinds 合并：`voice_text` + `photo` → `user_invoke` (image + text 一起带)；新增 §1.5 Hybrid Connection Model；明确 Vision 归 Cortex；OQ-S5 新增 push payload 问题 |
| v0.4 | type `preference` → `skill`（Twin 是 "AI 怎么作为我做事" 的指令集）；新增 `identity`/`encounters`/`memory` 三个 type；type-specific 字段更新；详细 schema 移到 [DATA-MODEL.md](DATA-MODEL.md) |
| v0.5 | `user_decision.decision` 取值从 `confirm/reject/dismiss` 改为 `send/feedback/dismiss`；feedback 类型自带 `feedback_text` (新一轮 STT)；新增 §1.5 Feedback Loop；§1.4 加入 Quick Shortcut + Voice Invoke 两个 global gesture 入口说明；配套 [Doc/ui-mockup.html](Doc/ui-mockup.html) v0.1 |
| v0.6 | **R-1 / R-2 / R-3 落地**: §0 加 always-on mic paradigm + multi-step task chain + C-17 (audio never raw) 原则；§1.5 重写 — feedback 不再是 opt-in mode，是 default voice channel；加 4 类 free-form feedback 分类 (a/b/c/d)；新增 §2.5 Internal Dispatch Plan schema (含 task_continues + next_step_hint)；§3 重写为"RPC + Event Push" — Cortex 持久 conn + demux reader; §3.3 reverse-wake 加 session_id + 3-option menu + wake_response_map 实现引用；§7 deferred list 加 audio raw / multi-step persistence / mail push 三项明确不做的事 |

---

*End of Constellation Interface Contracts v0.3.*
