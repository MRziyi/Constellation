# Constellation — Framework Design

**Version**: v0.8 (frozen 2026-05-24); **superseded in part by [AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md) as of 2026-05-25**
**Status**: 设计阶段 → Phase 1 + Phase 2 + R-3 + Phase 3a Web Console + Phase 5 v2 architecture pivot 都已实现
**关联文档**: [SOURCE-OF-TRUTH.md](SOURCE-OF-TRUTH.md) · **[AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md)** · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [DATA-MODEL.md](DATA-MODEL.md) · [UI-UX.md](UI-UX.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) · [twin-seed/](twin-seed/) · [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) · [USE-CASE-AUDIT.md](USE-CASE-AUDIT.md) · [TOOL-IDEAS.md](TOOL-IDEAS.md) · [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) · [Doc/ui-mockup.html](Doc/ui-mockup.html) · [Doc/brand/](Doc/brand/)
**Last updated**: 2026-05-25 (added V2 supersedes banner)

> ⚠ **Reader pointer (2026-05-25)**: After Phase 5's v2 architecture pivot, **Cortex Router is no longer the agent**. The "Cortex Router does multi-step planning across 12 adapters" framing throughout this doc is historical. The agent now is Claude Code in tmux; Cortex is a thin classifier + HITL gate + glanceable progress relay + multi-phase checkpoint orchestrator. The 7 Promises (P1-P7) still hold — only the *implementation* of P7 (Multi-Step with Mid-Task Yield) and the Router internals shifted. **Read [AGENT-ARCHITECTURE-V2.md](AGENT-ARCHITECTURE-V2.md) before treating any §3+ component spec here as current.** New invariant (★) elevated: visible process + correction (see SoT addendum and V2 §0).

本文档是 Constellation 的**框架设计稿**。所有内容从 [SOURCE-OF-TRUTH.md](SOURCE-OF-TRUTH.md)（用户意图宪法）+ 设计 session 的全部讨论 derive。

---

## 1. Project Identity

**名称**: Constellation (中文：星座)

**一句话**: 一个跑在你家 Mac mini 上的 personal agent，从你身上的可穿戴设备（眼镜为 v1 主载体）接收意图，通过 Mac 上的本地工具完成任务，所有动作前置预览，记忆写在你能编辑的 markdown 数据库（Digital Twin）里。

**是什么**:
- 一个 **unified framework**，不是任意单一 app
- 一个跑在 Mac mini 的长期 agent (Cortex Agent)，用 **GPT API** 驱动
- 一个**只调 Mac 本地工具**（Claude Code、AppleScript、mail.app...）的 Tool Agent
- 一个 markdown + git 的 **Digital Twin**
- 一个**永远 human-in-the-loop** 的协作纪律

**不是什么 (v1)**:
- 不是隐私优先系统（v1 不为隐私设计，SoT N-5）
- 不是商业产品（HCI 研究原型 + 自用）
- 不是替代你现有工具的系统——是在它们**之上**加一层智能
- 不是单一硬件 app——眼镜只是终端之一（"最宏大的愿景"是多设备伴随）

---

## 2. The Seven Promises

| # | Promise | 一句话 | 主要驱动 (SoT) |
|---|---|---|---|
| **P1** | **Your Memory is Editable** | Digital Twin 是 "AI 应该怎么作为我做事" 的指令集 + 实体网络 + 行为记录的 markdown 库；你能 `vim` 浏览/编辑，Cortex 通过 implicit learning 持续画"你"；Cortex 每次任务都从 Twin 重建上下文 | C-7, C-14 |
| **P2** | **Right Tool, No UI** | 你说意图，Cortex (GPT API) 决定调哪个 Mac 本地工具；本地工具内部用什么模型是工具自己的事 | D-F |
| **P3** | **Preview Before, Receipt After** | 所有副作用动作前置预览 + 你显式 confirm 才执行；每次执行都留 receipt 可回查 | C-9, C-10 |
| **P4** | **Reachable Both Ways** | 你能唤醒 Cortex；Mac 上的工具也能反向唤醒 Cortex 找你确认 | C-6 |
| **P5** | **Your Context, Shared on Your Terms** | Twin 可被外部 AI 工具按 `share:` 字段读取 (MCP)；v1 留接口骨架，不强 demo | C-15 |
| **P6** | **Surprising Insight** | Cortex 在你已有工具栈之上，给你"有智商才能发现"的洞察 / 跨工具关联 / Twin 长记忆触发；常规提醒走 Apple 全家桶（Cortex 代你写入，不当 push 源）| 本 session 新增 |
| **P7** | **Multi-Step with Mid-Task Yield** | 复杂意图自动分多步推进：每步 yield 一张信息卡 + always-on 麦克风，用户可以默认 ring-tap 走默认路径，也可以语音任意 (a) confirm / (b) correct / (c) skip / (d) inject-info。Cortex Router 综合判断后输出下一步 plan。最多 5 步防失控。| R-3 (C-20/C-21/C-22/C-23) |

### Vision (v1 不承诺)

**Wear the Constellation**——眼镜只是众多终端之一，未来手机/耳机/麦克风/戒指都可以承担当前任务的 I/O。SoT §4 用户原话："**最宏大的愿景**"。

### 执行边界 (v1 硬约束)

- 眼镜 ↔ Mac mini **永远走公网**（不区分在家/外出）— SoT C-4
- Cortex 用 **GPT API** 做 routing 决策（实施 model: `gpt-5.4`）
- Tool Agent **只调 Mac 本地工具**，不直接调其他云 API；**例外**: `twin_query` adapter 内部调 GPT 做 RAG synthesis（Tool Agent 加载 .env 拿到 OPENAI_API_KEY）
- 本地工具内部用什么模型是工具自己的事（Claude Code 内部用 Anthropic）
- **Cortex 输入永远 `{text, image?}`，从不接收原始音频** — SoT C-17 (R-1)
- **场景 Vision** (OCR / 一般 visual QA) 归 **Cortex** 调 GPT-4V；**人脸识别**归 **Tool Agent** 本地模型 (OQ-C5)；**不主动 screenshot Mac 桌面** (N-10)
- **网络搜索 / 学术搜索** 不实现独立 adapter；通过 `claude_code.draft` 委托 CC (它有 WebFetch) — SoT N-9 (R-1)
- **邮件推送通知** Constellation 不管 — iPhone+Glass 走 Apple 生态 — SoT C-18 (R-2)
- 设计先于实现 (SoT C-16, N-6) — Phase 1 + 2 已实现；继续 design-first 节奏

---

## 3. System Architecture

### 3.1 拓扑

```
        ┌──────────────────────────────────────┐
        │  WEARABLE (你身上)                    │
        │   ┌────────────┐                     │
        │   │ Rokid Glass│  (R08 Ring 是 Glass │
        │   │ (Android)  │   的遥控器，对      │
        │   │            │   Cortex 不可见)    │
        │   └─────┬──────┘                     │
        └─────────┼────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │  Hybrid Transport:│   ─── 上行 WSS over Tailscale (用户活跃期)
        │                   │   ─── 下行 push notification → Glass wake
        │                   │       → WSS 拉 commands → 关闭
        └─────────┬─────────┘
                  │
        ┌─────────┼────────────────────────────┐
        │         │   MAC MINI (家)            │
        │         ▼                            │
        │   ┌────────────────────────────┐    │
        │   │   CORTEX AGENT             │    │
        │   │   (brain, GPT API driver)  │    │
        │   │                            │    │
        │   │ • Event bus (3 sources)    │    │
        │   │ • LLM Router (GPT)         │    │
        │   │ • Preview/Confirm protocol │    │
        │   │ • Receipt writer           │    │
        │   │ • Insight Engine (P6)      │    │
        │   │ • Vision (GPT-4V calls)    │    │
        │   │ • Push notifier            │    │
        │   └──┬──────────┬──────────────┘    │
        │  WS-IPC      fs+git                 │
        │      │          │                   │
        │      ▼          ▼                   │
        │  ┌────────┐  ┌──────────────────┐  │
        │  │ TOOL   │  │  DIGITAL TWIN    │  │
        │  │ AGENT  │  │ ~/constellation/ │  │
        │  │ "hands"│  │  markdown + git  │  │
        │  │        │  │                  │  │
        │  │• CC    │  │  ┌────────────┐  │  │
        │  │• ascr  │  │  │ MCP Server │──┼──┼──► 外部 AI (P5)
        │  │• mail  │  │  │ (read-only)│  │  │
        │  │• cal   │  │  └────────────┘  │  │
        │  │• remi  │  │ CHANGELOG.md     │  │
        │  │• fs    │  │ (替代 git)       │  │
        │  │• face  │  └──────────────────┘  │
        │  └────────┘                        │
        └────────────────────────────────────┘
```

### 3.2 组件 Responsibility Matrix

| Component | 管 | 不管 | 通信对象 |
|---|---|---|---|
| **Rokid Glass** | 拍照、内置 STT 转文字、HUD 渲染、**HUD card 出现时默认开麦** (C-22 R-3)、网络通信（Hybrid 模式）| 手势采集（Ring 处理）/ LLM 调用 / 工具调用 / Twin 读写 / Vision 推理 / 原始音频上传 (C-17) | Cortex (公网, Hybrid) |
| **R08 Ring** | 眼镜的遥控器：触发拍照 / 控制 HUD / 选择 | 对 Cortex **不可见** | 仅与 Glass 本地通信 |
| **Cortex Agent** | Event 接收、**Routing 决策 (GPT-5.4)**、Preview/Confirm 协议、**confirm-policies 强制 (defense in depth)**、**Multi-step task 编排 (R-3: task_history + _advance_task, max 5 rounds)**、**reverse-wake 接收 + tool_card 派发**、Receipt 写入 (含 step receipts)、Insight Engine (P6)、Implicit Learning Loop、场景 Vision 推理 (GPT-4V，非人脸)、Push 通知、Twin 读写 | 工具实际执行 / OS 操作 / 人脸识别 (本地模型归 Tool Agent) / 邮件 push 订阅 (C-18) | Glass (公网) · Tool Agent (WS-IPC, **持久 + demux 多消息类型**) · Twin (fs + CHANGELOG.md) · Push 服务 |
| **Tool Agent** | Mac 本地工具调用、状态查询、执行结果反馈、**反向 wake 推送 (claude_code Track B watcher → push_event → Cortex)**、本地人脸识别 (Phase 6)、**`twin_query` adapter 内调 GPT 做 RAG synthesis** | 决策 / 路由 / Twin 读写 / 场景 Vision / 跨设备通信 / 网络搜索 (走 claude_code) | Cortex (WS-IPC) · Mac 本地工具 · OpenAI (仅 twin_query) |
| **Digital Twin** | markdown 文件 + CHANGELOG.md (替代 git) + MCP 暴露 + `_system/TOC.md` 索引 + `skills/confirm-policies.md` Cortex 启动时解析 | 自我修改 / 被外部直接写 | Cortex (r/w) · MCP Server (filtered read) · Tool Agent (via `twin_query.ask`) |
| **MCP Server** | 按 `share:` 过滤的 Twin slice 暴露 (Phase 8) | 写入 / 决策 | 外部 AI clients |

### 3.3 Core Loop + 3 个 Trigger 源 + Twin 横切

```
单步 Loop (简单意图):
  Trigger ──► Router ──► Preview ──► Confirm ──► Execute ──► Receipt
     ▲                                                          │
     │                                                          │
     └────── Twin 贯穿 (读 context pack / 写 receipt / 写 hint)─┘

Multi-step Loop (R-3 paradigm, 复杂意图):
  Trigger ──► Router (R1, task_continues=true) ──► Preview ──► User SEND/FEEDBACK ──┐
                                                                                     │
       ┌─────────────────────────────────────────────────────────────────────────────┘
       ▼
  task_history.append → _advance_task → Router (R2) ──► Preview ──► User ──► ...
                                            │
                                            ▼ (up to 5 rounds)
                                       task_continues=false ──► Execute ──► Receipt
```

**3 个 Trigger 源:**

| 源 | 例子 | 路径 | 主要 Promise |
|---|---|---|---|
| **A. User** | 语音 + 照片（每次必带）；free-form feedback to existing card | Glass → 公网 → Cortex | P2 + P3 + P7 |
| **B. Tool reverse** | Claude Code 卡权限 (Track B watcher detect)、build failed、iCal 收邀请 | Tool Agent → WS push_event → Cortex demux reader → `_handle_tool_reverse_wake` → tool_card → Glass | P4 |
| **C. Cortex self** | Insight Engine 扫描 Twin / Mac events / cron | Cortex 内部 | P6 |

**Twin 横切 (cross-cutting concern):**
- 每次 Trigger 进 Cortex → 读 Twin 拼 context pack（Phase 2 现状: eager-load `identity.md` + 所有 `skills/*.md` + 所有 `people/core/*.md`；Phase 7 升级 two-pass per [DATA-MODEL §11](DATA-MODEL.md)）
- 每次 Execute 完 → 写 receipt 到 Twin + append CHANGELOG.md。**Multi-step 任务每 step 都写 `[step N]` 前缀 receipt**，最终 step 写 final receipt
- 每次 user override / correct / 满意迭代 → Implicit Learning Loop 异步提炼 → 写入 `Twin/skills/` (参 [DATA-MODEL §9](DATA-MODEL.md))
- Cortex 启动时解析 `Twin/skills/confirm-policies.md` → in-memory rules → `_apply_confirm_policies()` post-Router override

---

## 4. 关键决策 (Q-1 ~ Q-9)

| # | 决策 | 选项 | 主要理由 |
|---|---|---|---|
| **Q-1** | Transport (Glass ↔ Cortex) | **Hybrid: WSS over Tailscale (用户活跃期) + Push notification wake (idle) + WSS payload (push 后)** | Glass 长 WSS 实测 idle ~50-100mW，吃掉 30-50% 电池；Hybrid 平衡能耗与延迟：用户主动触发期响应快（WSS 保持），idle 期靠 push wake 节能 |
| **Q-2** | Proactive 机制 | **Insight Engine + 简单 LLM 评估** | 常规提醒走 Apple 全家桶；Cortex 只 push 有智商的 surprising insight；不需要 quota / tier |
| **Q-3** | R08 接入 | **作为 Glass 遥控器，对 Cortex 不可见** | 戒指只是触发眼镜动作的物理控制；不在 Cortex 视野内 |
| **Q-4** | MCP Server | **v1 留接口骨架，不强 demo** | 现在不留以后难补；P5 在 v1 工作流可能用不上 |
| **Q-5** | Cortex ↔ Tool Agent IPC | **持久 WebSocket on localhost + Cortex 端 demux reader** (区分 RPCResult vs Event by message shape) | 双向 long-lived、支持 adapter unsolicited push（reverse-wake）、Python easy |
| **Q-6** | Glass 断网 | **直接报错给用户** | 不做后台 replay / freshness 分类；simple > complete |
| **Q-7** | Push notification 服务（Hybrid 下行 wake 通道）| **TBD —— FCM (Google) / Rokid 自家 push / 其他**；按 Rokid Glass 实际支持选 | 仅作 wake 信号，payload 不经过；选型取决于 Rokid 设备生态 |
| **Q-8** | **Multi-step task 模型 (R-3)** | **Plan schema 加 `task_continues` + `next_step_hint`；Cortex 维护 `task_history` 跨轮；`_advance_task` 重 invoke Router；max 5 rounds**；FEEDBACK 永远走 Router 重判 (Router 自分类 a/b/c/d) | 用户复杂意图（"找邮件→确认→加 reminder→写回复"）需要中间 yield；不引入 Task 实体重写，复用 _pending_previews + 加 history 字段最小改动 |
| **Q-9** | **Confirm-policies 执行层** | **Cortex startup 解析 `skills/confirm-policies.md` → `_apply_confirm_policies(plan)` post-Router 强制 override**；preview-always 强制升级 hud_show→preview_action；deny 直接 abort plan | Router 自觉读 skill 是 best-effort；Cortex 层强制是 defense-in-depth。也保证 task_continues=true 一定走 preview_action (用户必有 yield 点 per C-22) |

---

## 5. Cool Examples Library

来源：本 session brainstorm。SoT N-3 锁定 cool features v1 **不实现**——这里只作为框架的"**压力测试套件**"：架构必须能容纳这 15 个 examples，但 v1 只跑 SoT §10 的三个原始 use cases。

### A. 多设备 affordance (Vision 级)

- **A1** ★ 跑步无眼镜：耳机 + 戒指 + 麦克风触发记笔记
- **A2** 会议无声手势：戒指 swipe + tap 触发"标记此人"
- **A3** 驾驶时邮件：CarPlay 念稿 + 语音 confirm

### B. Twin 长记忆 + 跨时检索

- **B1** ★ 承诺履约监控：你说过下周写信给 X，下周到了反向 wake
- **B2** 关系记忆 query："那个 MIT 的 HCI Edu 研究员叫什么？"
- **B3** 昨天的我："我昨天对那个 idea 是怎么想的？"
- **B4** ★ **多步邮件准备链路 (R-3 示范用例)**: "看前两天给云的邮件找 meeting 时间，加 reminder，再写邮件告诉她我准备好下周下午约" → R1 find+extract → 用户 confirm/correct → R2 add reminder + draft reply → 用户 SEND

### C. 多工具编排

- **C1** ★ 会议准备一条龙：Twin 拉档案 + Claude Code 搜邮件 + 综合 brief
- **C2** PR review 准备
- **C3** 白板存档：拍 → OCR → 写入 Twin

### D. P4 反向唤醒

- **D1** ★ Build failed → 反向 wake → "让 Claude Code 修？"
- **D2** 日程冲突告警
- **D3** PR 收到 review

### E. P5 Twin 共享

- **E1** 委托外部 ChatGPT 写项目计划（用你的 Twin slice 作为 context）
- **E2** 第三方 Claude.ai 读你日程

### F. HITL 反向

- **F1** ★ Cortex 反问 disambiguation："哪个 X？A 还是 B？"

打 ★ 的 5 个是框架的"signature stress test"——架构必须能容纳它们。

---

## 6. 三个原始 Use Cases (v1 实施目标)

来源：[SoT §10](SOURCE-OF-TRUTH.md). v1 框架必须能 demo 这三个用例。

1. **邮件代回** (UC1)：voice intent → Cortex routing → Claude Code 写邮件 + 调 Mail.app → 眼镜 preview → confirm → 发送 + receipt + 苹果全家桶联动（提醒等）
2. **Claude Code 双向遥控** (UC2)：Claude Code 跑着 → 卡权限 → 反向 wake → 推到眼镜 → confirm → 继续；以及 "做得怎么样了？" → Cortex 查 Claude Code 状态 → 反馈
3. **人脸记忆 + 检索** (UC3)：拍照 + 语音 annotate → 写入 Twin/people/ → 再次相遇拍照 → Twin 检索 → HUD 显示历史

---

## 7. v1 Implementation Requirements (架构层应具备能力)

这层来自 use case stress-test 时暴露的隐性需求。**不升格为 promise**，但架构必须支持。

| Requirement | 谁负责 | 来自 |
|---|---|---|
| **多工具编排** (一个意图 → 串行多工具) | Cortex Router + Tool Agent | UC1 (邮件 + 苹果提醒) |
| **执行结果反馈** (工具执行后 Cortex 拿到结果) | Tool Agent → Cortex | UC1 "我的工具再查看结果" |
| **Tool 状态查询** ("那个工具在干嘛？") | Tool Agent | UC2 "做得怎么样了？" |
| **长任务监控** (Claude Code 持续跑) | Tool Agent + Cortex (Track B tmux + reverse-wake watcher) | UC2 |
| **Twin 存非文本** (人脸图、embedding) | Twin (`memories/faces/`) | UC3 "图像一起写入" |
| **Twin query** (语义检索) | Cortex (`twin_query.ask` adapter) | UC3 "等到某天我想起" |
| **场景 Vision 推理** (OCR / 场景理解，非人脸) | Cortex (调 GPT-4V) | UC1 拍照、UC3 OCR |
| **人脸识别** (detection / embedding / match) | Tool Agent (本地模型) | UC3 |
| **Implicit Learning** (从 interaction 异步提炼 skill update) | Cortex | P1 + "Twin 不手动维护" 决议 |
| **Multi-step task chain** (一个意图分 N 步推进，中间 yield 给用户) | Cortex Router 输出 `task_continues=true` + Cortex `_advance_task` re-invoke loop | R-3 / Zack 云 email 例子 |
| **Free-form mid-task feedback interpretation** (语音任意回应 → Router 分类 a/b/c/d) | Cortex Router (GPT-5.4 prompt §1.2) | C-23 / Zack always-mic paradigm |
| **Always-on mic per HUD card** (HUD 出现即开麦，戒指 tap 跟语音并行 channel) | Glass Phase 3 客户端硬要求 | C-22 |
| **Confirm-policies enforcement** (Router 自觉读 + Cortex 强制 override + deny abort) | Cortex 启动加载 + post-Router `_apply_confirm_policies` | Q-9 |
| **Reverse-wake event push** (Tool Agent 主动推 unsolicited event 到 Cortex) | Tool Agent `push_event` callable + Cortex 持久 conn + demux reader | UC2 / Q-5 |

---

## 8. Open Questions (后续 session)

| # | 问题 | 计划归宿 |
|---|---|---|
| OQ-1 | v1 必须接入的具体 Mac 本地工具列表 | ✓ 已拍 → [COMPONENT-DESIGN §2.4](COMPONENT-DESIGN.md) |
| OQ-2 | Insight Engine 的扫描频率 / 信号源细节 | [COMPONENT-DESIGN §1.5](COMPONENT-DESIGN.md) + #6 Data Model |
| OQ-3 | Glass HUD 视觉语言 | ✓ 已落地 → [Doc/ui-mockup.html](Doc/ui-mockup.html) + [UI-UX.md](UI-UX.md) |
| OQ-4 | Twin 数据模型细节 | ✓ 已落地 → [DATA-MODEL.md](DATA-MODEL.md) |
| OQ-5 | 长任务监控的 polling vs subscription 机制 | #4 Component Design tuning |
| OQ-6 | Voice 唤醒触发的具体协议 | ✓ 已落地 → [Doc/ui-mockup.html §3](Doc/ui-mockup.html) (Voice Invoke = LP+SWIPE_UP, VAD-stop) |
| OQ-7 | Push notification 服务选型（FCM / Rokid push / 其他）| 实施前调研 Rokid 设备生态 |

---

## 9. Distribution & Operations (v1 simple)

- **Repo**: `~/Code/Projects/Constellation/` (monorepo)
- **Twin 位置**: `~/constellation/twin/`（普通目录，**不**入 git，**不** push GitHub；维护 `CHANGELOG.md` 替代 git）
- **Cortex / Tool Agent / MCP Server**: launchd plists，一行 installer
- **Glass**: sideload APK via adb
- **No CI for v1**：local dev only

---

## 10. Document Status

- **Version**: v0.8
- **Last updated**: 2026-05-24
- **Based on**: [SOURCE-OF-TRUTH.md](SOURCE-OF-TRUTH.md) (constitution + R-1/R-2/R-3) + 实现完成 Phase 1 + Phase 2 + Phase 5 早 demo
- **Companion**: [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [DATA-MODEL.md](DATA-MODEL.md) · [UI-UX.md](UI-UX.md) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) · [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md) · [twin-seed/](twin-seed/) · [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) · [TOOL-IDEAS.md](TOOL-IDEAS.md) · [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) · [Doc/ui-mockup.html](Doc/ui-mockup.html) · [Doc/brand/](Doc/brand/)
- **Next**: Phase 3 Android phone client (must implement C-22 always-on mic + Hybrid transport)

### Revision Log

| Version | Changes |
|---|---|
| v0.1 | (废弃) 初稿，由前一工具生成；已删 |
| v0.2 | 重写。6 条 Promises 锁定（P6 改 Surprising Insight）；架构 3a/3b；Q-1~Q-6 拍板 |
| v0.3 | Q-1 改 Hybrid Transport（节能考量）；新增 Q-7 Push 服务选型；OQ-1 关闭（移到 COMPONENT-DESIGN）；新增 Vision 推理 |
| v0.4 | P1 重定义为"AI 应该怎么作为我做事"的指令集 (Twin 是 Living User Spec)；preferences/ → skills/；人脸识别归 Tool Agent (本地模型，撤销之前归 Cortex 的决议)；Twin 去 git，改 CHANGELOG.md；新增 Implicit Learning Loop 作为 v1 能力；OQ-4 关闭 (移到 [DATA-MODEL.md](DATA-MODEL.md)) |
| v0.5 | #8 UI/UX 落地：[Doc/ui-mockup.html](Doc/ui-mockup.html) + [UI-UX.md](UI-UX.md)；继承 Halo Ring 视觉语言；2 个 global gesture (Quick Shortcut + Voice Invoke)；HUD options 改 Send/Feedback（不再 Reject）；新增 Feedback Loop 迭代机制（[INTERFACE-CONTRACTS §1.5](INTERFACE-CONTRACTS.md)）；OQ-3/OQ-6 关闭 |
| v0.6 | mockup 重构为"两类 surface"清晰结构（HUD atom-based + 极简 app 设置 + 强制通用 card 模板 + 加 face recognition 验证模板适配性）；手势/profile 完全推给 Halo Ring；新增 [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) 给 Halo Ring agent；brand mark 落地 [Doc/brand/v1-constellation.svg](Doc/brand/v1-constellation.svg)（asymmetric 8-star asterism，9× 放大自 mockup inline mark）；#9 Implementation Plan 落地 [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md)（9 phases + critical path + risk register） |
| v0.7 | **设计阶段收尾**：G1 [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md)（system prompt + 7 个 few-shot + 输出 schema）；G2 [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md)（6 adapters × 详细 action catalog）；G3 [twin-seed/](twin-seed/) 13 个文件（ready-to-deploy Twin 种子）；IMPLEMENTATION-PLAN bumped v0.1→v0.2（hardware no longer blocking；Mac-first → Android-phone debug → Rokid deploy 三段式；新增 §8 Greenlight checklist） |
| v0.8 | **R-1 + R-2 + R-3 paradigm 落地 + 12 adapter live + Phase 5 UC2 早 demo**: §2 加 P7 "Multi-Step with Mid-Task Yield"；§2 执行边界加 C-17 (audio never raw) / N-9 (web via CC) / N-10 (no Mac screenshot) / C-18 (mail push not managed)；§3.2 responsibility matrix 重写 Cortex (多 step 编排 + reverse-wake 接收 + confirm-policies 强制) + Tool Agent (push_event + twin_query LLM)；§3.3 加 multi-step Loop 图 + reverse-wake 路径；§4 加 Q-8 (multi-step task 模型) + Q-9 (confirm-policies 强制层)；§5 加 B4 (云 email 多步邮件 R-3 示范例)；§7 implementation requirements 加 5 项 (multi-step chain / free-form feedback / always-mic / confirm enforcement / reverse-wake push) |

---

## 11. SoT Constraint Coverage (反向追溯)

按 SoT §12 要求，每次设计稿要回到 SoT 验证所有 16+7 条约束是否被尊重。

| SoT 约束 | 本文档对应位置 | 状态 |
|---|---|---|
| C-1 Constellation 命名 | §1 | ✓ |
| C-2 Rokid Glass v1 | §1, §3.1 | ✓ |
| C-3 R08 配套 | §3.2（作为 Glass 遥控器）| ✓ |
| C-4 永远走公网 | §2 执行边界 + §4 Q-1 | ✓ |
| C-5 两客户端 + 中间 agent | §3.1 拓扑（Glass + Tool Agent + Cortex）| ✓ |
| C-6 Wake-on-Demand | §3.3 三个 trigger 源 | ✓ |
| C-7 Twin = markdown + skill-style | §2 P1 + §3.2 + [INTERFACE-CONTRACTS §4](INTERFACE-CONTRACTS.md) | ✓ |
| C-8 LLM-as-router | §2 P2（Cortex Router = GPT-5.4）| ✓ |
| C-9 全部前置预览 | §2 P3 + §4 Q-9 (Cortex 强制层) | ✓ |
| C-10 HITL | §2 P3 + P7 (multi-step yield) | ✓ |
| C-11 cool prototype > 论文 | §1 不是什么 | ✓ |
| C-12 framework 核心 | §1 是什么 | ✓ |
| C-13 眼镜是终端之一 | §2 Vision | ✓ |
| C-14 用户视角无状态 | §2 P1 | ✓ |
| C-15 Twin 可共享 | §2 P5 | ✓ |
| C-16 不写代码 | §2 执行边界 (历史；已进入实现) | ✓ |
| **C-17 Cortex 输入永远 {text, image?} (R-1)** | §2 执行边界 | ✓ |
| **C-18 Mail push 不管 (R-2)** | §2 执行边界 + §3.2 (TOOL-ADAPTERS §2) | ✓ |
| **C-19 Mail REPLY / COMPOSE / SEARCH 三模式 (R-2)** | TOOL-ADAPTERS §2 + CORTEX-ROUTER-PROMPT §1 | ✓ |
| **C-20 Multi-step task paradigm (R-3)** | §2 P7 + §3.3 + §4 Q-8 | ✓ |
| **C-21 HUD 是 info+yield card 不是 yes/no (R-3)** | §2 P7 + CORTEX-ROUTER-PROMPT §1.3 + UI-UX §3 | ✓ |
| **C-22 Glass 每张 HUD 默认开麦 (R-3)** | §2 P7 + §3.2 + Phase 3 deliverable | ✓ (Phase 3 实施) |
| **C-23 Router 综合判断 4 类 free-form feedback (R-3)** | §2 P7 + CORTEX-ROUTER-PROMPT §1.2 | ✓ |
| N-1 不 case-focus | §5 (examples 入库不实现) + §6 (UC 作为压力测试)| ✓ |
| N-2 不为论文驱动 | §1 不是什么 | ✓ |
| N-3 不实现 cool features | §5 标注 "v1 不实现" | ✓ |
| N-4 不 hands-off | §2 P3 | ✓ |
| N-5 v1 不为隐私 | §1 不是什么 + §4 Q-1 理由 | ✓ |
| N-6 不写代码 | §2 执行边界 (历史) | ✓ |
| N-7 眼镜非唯一终端 | §2 Vision | ✓ |
| **N-8 不调 ASR / Whisper (R-1)** | §2 执行边界 | ✓ |
| **N-9 不做独立 web/paper 搜索 adapter (R-1)** | §2 执行边界 + TOOL-ADAPTERS §1 (CC Track A) | ✓ |
| **N-10 不主动 screenshot Mac (R-1)** | §2 执行边界 | ✓ |
| **N-11 不订阅 / 不轮询新邮件 (R-2)** | §2 执行边界 + §3.2 | ✓ |

---

*End of Constellation Framework Design v0.3.*
