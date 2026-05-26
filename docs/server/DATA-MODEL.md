# Constellation — Data Model

**Version**: v0.2
**Status**: 设计阶段 → 实现同步 (step receipt format + people/core 实施 + eager-load context_pack 现状)
**关联文档**: [DESIGN.md](../constitution/DESIGN.md) · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [SOURCE-OF-TRUTH.md](../constitution/SOURCE-OF-TRUTH.md)
**Last updated**: 2026-05-24

本文档定义 Digital Twin 的详细数据模型。Twin 是 Constellation 的核心承载（P1 + P5 + P6 共同基底），SoT C-7 锁定"markdown + skill-style，让大模型按需自索引"。本文件聚焦 Twin 长什么样、怎么写、怎么读、怎么演化。

---

## 1. Twin 的本质 (the reframe)

**Twin 不是关于你的档案库。Twin 是"AI 应该怎么作为我做事"的指令集 + 我的实体网络 + 我的行为记录。**

最终愿景（用户原话）：
> "我只要给一句我的需求；之后它 dispatch 出去任务，就能按照我想要的风格满足我的偏好，各方面都是。它作为一个数字化的我，我只需要给最简单的一些话，那这个最终系统给出的结果就能满足我的需求，我不需要跟它迭代，因为我的模型就已经非常真实地是我了。"

所以 Twin 同时承载三层：

| 层 | 性质 | 写者 |
|---|---|---|
| **Skills** | Prescriptive（AI 应该怎么做事）| Cortex implicit 学习；用户偶尔 vim |
| **Identity + Entities** | Mixed（关于"我"和"我的世界"的事实 + 我希望 AI 假设的我的 voice / taste）| Cortex implicit + 用户偶尔 |
| **Records** | Descriptive（发生了什么）| Cortex append-only |

**Twin 不是用户主动维护的**。它通过 **Implicit Learning Loop**（§9）从用户的 interaction 中演化——用户感知不强，但 Twin 越来越像他。

---

## 2. 设计哲学（综合 best practice）

参考的设计：

| 系统 | 借鉴的部分 |
|---|---|
| **Anthropic Skills** | SKILL.md frontmatter `description` → LLM 按需加载；文件夹 + nested 文件结构 |
| **MemGPT / Letta** | Tiered memory: core (always loaded) + recall (on demand) |
| **Atomic Notes / Zettelkasten / Obsidian** | 一个 entity 一个文件 + `[[wikilink]]` 织网 |
| **避免** | Vector DB（SoT C-7）；单一大文件（context bloat）；极度原子化（碎片化）；强 schema（vim 不友好）|

**4 条核心原则：**

1. **粒度 = "在你脑中能想象为独立单元"的颗粒度**——不是原子事实，不是大类合集
2. **每个文件 = 一个 retrieval unit**——LLM 一次加载有意义
3. **按需加载**——`_system/TOC.md` + 文件 `description` → LLM 选要拉的 paths
4. **存在的才建档**——偶遇的人 / 一次性话题不强建档；recurring 才 promote

---

## 3. 目录布局

```
~/constellation/twin/                  (普通目录，非 git repo)
├── README.md                          # 顶层概览
├── CHANGELOG.md                       # Cortex 修改 Twin 的累积日志（替代 git）
├── identity.md                        # 你的核心档案
│
├── skills/                            # ★ Prescriptive: AI 应该怎么作为我做事
│   ├── README.md                      # skill 索引 (一行一 skill: name + description)
│   ├── email-style.md                 # 简单 skill: 单文件 markdown
│   ├── code-review.md
│   ├── dispatch-policy.md             # meta-skill: Cortex 怎么分发任务
│   ├── confirm-policies.md            # 何时 preview 何时 auto
│   ├── pulse-feedback.md              # P6 Insight Engine 学到的偏好
│   ├── claude-code-control.md         # tmux regex
│   ├── twin-write-policy.md           # confidence 阈值
│   ├── transcript-to-insights/        # 复杂 skill: 文件夹（Anthropic Skill 标准）
│   │   ├── SKILL.md
│   │   └── examples/
│   └── ...
│
├── people/
│   ├── core/                          # 核心人物 (一人一档)
│   │   └── {slug}.md
│   └── encounters.md                  # 偶遇 (一文件多 section)
│
├── projects/                          # 项目档 (一项目一档)
│   └── {slug}.md
│
├── conversations/                     # 按日组织
│   └── {YYYY-MM-DD}/{HH-MM}-{slug}.md
│
├── receipts/                          # 按日聚合
│   └── {YYYY-MM-DD}.md
│
├── commitments/                       # 一承诺一档 (P6 扫描)
│   └── {slug}.md
│
├── interests/                         # 长期话题 (P6 扫描)
│   └── {slug}.md
│
├── memories/
│   └── faces/                         # Tool Agent 本地人脸模型管理
│       └── {person-slug}/
│           ├── face-{ts}.jpg
│           └── embeddings.json
│
└── _system/
    ├── schema.md                      # type 字段约定 (meta-skill: how to write Twin)
    ├── TOC.md                         # 自动维护的 path 索引
    ├── pending/
    │   ├── skill-updates/             # implicit learning 候选
    │   └── entity-updates/            # 低 confidence 实体更新
    └── learnings-log.md               # Cortex 自审"今天学到了什么"
```

---

## 4. 文件 type 大类

| type | 性质 | 数量 (典型) |
|---|---|---|
| `identity` | 你的核心档案（1 个）| 1 |
| `skill` | Prescriptive 指令文档 | 数十 |
| `person` | 人物档（core tier）| 数十 ~ 一百 |
| `encounters` | 偶遇汇总（一个大文件）| 1 |
| `project` | 项目档 | < 20 |
| `conversation` | 对话/会议转写 | 日积月累 |
| `receipt` | 一天的动作 audit log | 日积月累 |
| `commitment` | 你说过要做但未做的事 | 数十 |
| `interest` | 长期关心的话题 | < 20 |
| `memory` | 非文本记忆容器（人脸图等）| 跟 person 同步 |
| `schema` | `_system/` 元层级 | 少数几个 |

---

## 5. Skill 文件形态（自由密度）

**核心**：skill 是 **prescriptive 的指令文档**——告诉 AI"如果是你作为我做这件事，你会怎么做"。

**密度按内容自适应，不强求格式**：

### 5.1 简单 skill (几行 bullet points)

```yaml
---
type: skill
name: email-greeting
description: 我邮件开头怎么写
created: 2026-05-23
share: [claude, gpt]
---

# Email Greeting

- "Hey {name}" 给熟人/同事
- "Hi {name}" 给陌生人或更正式场合
- 不要 "Dear", "To whom it may concern", "I hope this email finds you well"
- 中文邮件：开头不写 "您好" 这种 generic，直接进入话题
```

### 5.2 中等 skill (规则 + 反例)

```yaml
---
type: skill
name: code-review-comments
description: 我做 PR review 的 comment 风格
share: [claude]
---

# Code Review Comments

## Default tone
直接 + 解释 why，不只说 what。

## Rules
- 永远附 reason: ✓ "这里 race condition because X" / ✗ "should fix this"
- 不批评作者，批评代码: ✓ "这个 abstraction 太宽" / ✗ "你这写得不对"
- 建议不强 push: "Consider..." not "You must..."
- 大改动用单独 comment thread，小 nit 行内
```

### 5.3 复杂 skill (Anthropic Skill style，文件夹)

参考：`~/Documents/.../transcript-to-insights/SKILL.md`——8 条 Rules + Procedure + Self-check + Canonical examples。

复杂 skill 用文件夹 + SKILL.md 入口 + nested examples / references。**这种密度只在需要时才达到**，多数 skill 不必。

### 5.4 关键的是 `description`

无论简单还是复杂，**frontmatter `description` 字段必须写得让 LLM 一眼判断要不要加载**。这是 Anthropic Skill 设计的核心，Twin 完全继承。

---

## 6. identity.md 维度

`identity` 是 Twin 中唯一的核心档案，Cortex Router 几乎每次都加载它。

**关键设计**：identity 不是纯 descriptive 简介，**核心是 prescriptive 部分**——"voice & taste" + "operating philosophy"：这是 AI 作为你做事时应该假设的"你"。

```yaml
---
type: identity
created: 2026-05-23
updated: 2026-05-23
share: [claude, gpt]
---

# Zack Zhang

## Basic
- Name: Zack Zhang
- Pronouns: he/him
- Languages: 中文 (native), English (technical fluent)
- Email: you@example.com

## Currently doing
- PhD / researcher at UIUC (HCI · AR · AI personal agents)
- Building: [[projects/constellation]] · [[projects/r08-halo-ring]] · [[projects/chrono]]

## Operating philosophy (the way I want decisions made)
- "实现是胜利的宣告而非冲刺的号角"——设计先于实现
- Framework > use cases (永远捍卫框架，不让 cases 扭曲它)
- Honest trade-offs > padding/marketing
- Cool prototype 优先 paper publication
- 在已有工具栈**之上**加智能，不替代我现有工具

## Voice & taste (how AI should communicate as me)
- 中文为主 + 英文技术词混排；技术上下文 OK 全英
- 直接、紧凑；不要 "I hope this email finds you well"
- 避免 emoji（口语 OK，文字不要）
- 邮件 default: brief, 2-4 sentences (详见 [[skills/email-style]])
- 决策时喜欢看 "A 取了什么 / 牺牲了什么"

## How I think (cognitive style)
- 优先抽象到框架层；不被 case-level 噪音带走
- 反 framing trap——常主动拒绝错的 framing
- 喜欢 explicit 标注（"这是 assumption" / "这是 trade-off"）
- 不容忍"伪装确信"

## Network (high-level)
- See [[people/core/]]

## Long-term interests
- See [[interests/]]

## Health / Lifestyle
- (按需补)

## AI usage stack
- Cortex 用 GPT API 驱动 (OpenAI)
- 本地工具底盘：Claude Code (Anthropic), AppleScript, Mail/Calendar/Reminders
- 人脸识别：本地模型 (Tool Agent)
- 苹果全家桶 = 常规提醒源（Cortex 写入，不当 push 源）
```

**维度可增可减**——v1 这是 draft 起点，用着用着会丰富。

---

## 7. 实体档案 (entities)

### 7.1 People

按 **Core / Encounters tier** 分（解决"是不是每个人一个文件"的质疑）：

| Tier | 位置 | 粒度 | 何时进 |
|---|---|---|---|
| **Core** | `people/core/{slug}.md` | 一人一档 | (a) 持续关系；(b) 关联到 commitment；(c) ≥ 3 次出现 receipts/conversations；(d) 用户显式 promote |
| **Encounters** | `people/encounters.md` | 一文件多 section | 默认所有新人进 |

**自动 promote**：满足条件时 Cortex 拆出 `people/core/{slug}.md` 并在 encounters.md 留 `[[promoted: people/core/{slug}]]` 标记。CHANGELOG 记一行。

**person frontmatter (core)**:

```yaml
---
type: person
created, updated, share, confidence, sources: ...
aliases: [Jane, Jane D]
relation: friend                 # friend | colleague | family | student | ...
fields: [HCI, AR, education]
affiliation: MIT Media Lab
last_seen: 2026-04-12
last_contact: 2026-05-15
preferred_contact: email
---

# Jane Doe

{自由 markdown body，按需 section}
```

### 7.2 Projects

```yaml
---
type: project
status: active                   # active | archived | paused | shipped
repo_path: ~/Code/Projects/Constellation
collaborators: [...]
---
```

### 7.3 Commitments (P6 扫描目标)

```yaml
---
type: commitment
due: 2026-04-30
to: jane-doe                     # optional, person slug
status: open                     # open | done | abandoned
priority: medium
source_conversation: conversations/2026-04-12/19-30-cmu-meetup
---
```

### 7.4 Interests (P6 扫描目标)

```yaml
---
type: interest
topic: Reinforcement Learning
signal_strength: 0.75
last_signal_at: 2026-05-20
aliases: [RL, deep RL]
---
```

`signal_strength` 由 Cortex 维护——每次 interest 被触及 (mentioned in conversation / read paper / asked Cortex about) 时增；衰减规则在 `skills/insight-engine.md`。

---

## 8. 记录 (records)

### 8.1 Receipts (按日聚合)

**v1 implementation** writes receipts as time-ordered sections in `receipts/{YYYY-MM-DD}.md`. The format is intentionally simple (Cortex `_write_receipt` in `cortex/cortex/server.py`):

```markdown
---
type: receipt
created: 2026-05-24T18:48:31.682554+00:00
date: 2026-05-24
share: none
confidence: 1.0
---

# Receipts — 2026-05-24


## 18:48:31 — echo [rcpt_0d0eabc27d27bd8c]
- evt: evt_3e42a20428054450
- subtasks: 1
- reasoning: Phase 1 stub — echoes the input.
  - [0] echo.echo (draft) → {"echoed": "hello cortex"}
```

### 8.2 Step receipts for multi-step tasks (v0.2 per R-3)

Multi-step tasks write per-step receipts during the task plus a final receipt at completion. Step receipts are tagged `[step N]` in the header:

```markdown
## 21:25:22 — [step 0] multistep-read-name-then-add-reminder [rcpt_6d0e6912ccf329e8]
- evt: evt_c30ec12e2e889c48
- task_continues: true
- next_step_hint: "after user confirms display name, add reminder"
- reasoning: "First surface the extracted name for confirmation before any side-effecting action."
  - [0] fs.read (query) → {"path": ".../identity.md", "content": "..."}

## 21:25:22 — [step 1] multistep-read-name-then-add-reminder [rcpt_<...>]
- evt: <same evt>
- task_continues: false
- reasoning: "User confirmed; now add reminder."
  - [0] applescript_reminders.add (execute) → {"reminder_id": "x-apple-reminder://..."}
```

Final task receipt (without `[step N]` prefix) terminates the chain at the last step.

OQ-R3-1 deferred: "should multi-step tasks write a single consolidated receipt instead of one-per-step?" — v1 keeps per-step for real-time auditability; Phase 7 polish may add a `[summary]` synthesised receipt at completion.

### 8.2 Conversations (按日 + slot)

```yaml
---
type: conversation
date: 2026-04-12
participants: [jane-doe, michael-zhang, you]
topic: CMU AR meetup
duration_minutes: 45
location: CMU GHC 7th floor
---

# CMU AR Meetup — 2026-04-12 19:30

## Topic
AR + LLM tutors

## Key discussion points
- ...

## Commitments
- I → Jane: review her CHI draft by 2026-04-30 [[commitments/review-jane-paper]]
```

---

## 9. Implicit Learning Loop (核心机制)

**用户不主动更新 Twin**。Cortex 通过 interaction loop 学习：

```
Per task (after completion or abandonment):
  1. Cortex 异步用 GPT 自审 the interaction loop:
     - 用户接受了什么？拒绝了什么？
     - 反馈是规则性 ("以后都这样") 还是一次性？
     - 有 candidate skill update / new skill / skill correction 吗？
  
  2. 输出 LearningCandidate(s) → _system/learnings-log.md
  
  3. 对每个 candidate:
     - if confidence ≥ 0.8 AND 是已有 skill 微小补充
       → 直接 append 到对应 skill (CHANGELOG 记一行)
     - else
       → 写到 _system/pending/skill-updates/
  
  4. 用户偶尔 HUD: "N skill updates pending"
     → 一句话 yes/no → Cortex promote 或丢弃
```

**反馈类型 → 学习类型 的映射示例**：

| 用户行为 | Cortex 推断 → 写入 |
|---|---|
| "不要 emoji 在邮件里" | `skills/email-style.md` 追加：✗ emoji |
| 三次拒绝 GPT 草稿、接受 Claude 的 | `skills/dispatch-policy.md` 加 hint："email reply intents → prefer claude_code" |
| 改了 3 版才满意的会议 brief | Cortex 反推：满意版本 vs 中间版本变了什么 → 抽象成新 `skills/meeting-brief.md` |
| 用户 vim 改了某 skill | 检测 mtime → 尊重；后续在那个 skill 上的 learning confidence 阈值临时调高 |

**v1 关键约束**：
- 不上 RL / fine-tuning
- 纯 LLM 自审 + pending review 兜底
- 易于审计：所有 learning 都进 `_system/learnings-log.md` + CHANGELOG

---

## 10. 写入策略

```
Cortex 想写 Twin path:

1. 决定 path (含人物 core vs encounters 判定)
2. 读 _system/TOC.md 看 path 是否存在

3. path 不存在
   → 创建 + 写 CHANGELOG entry + 更新 TOC.md

4. path 存在:
   a. 读 current content + 检查 mtime
      (比 Cortex 上次读后晚 = 用户改过)
   b. LLM 生成新版本
   c. if confidence ≥ 0.7 AND mtime 没冲突:
        覆写 + 写 CHANGELOG (含字段 diff) + 更新 TOC.md
   d. else:
        写 _system/pending/{date}-{slug}.diff.md
        next morning HUD: "N pending Twin reviews"
```

confidence 阈值在 `skills/twin-write-policy.md`，可调。

---

## 11. 按需加载 (Skill-style 核心机制)

### 11.1 Original spec (target form)

Cortex Router 在准备 context_pack 时：

```
1. ALWAYS 加载: identity.md + 任务直接相关的 skills/*.md
   (e.g., 邮件意图 → skills/email-style.md, skills/email-greeting.md)

2. 让 GPT 看 _system/TOC.md
   (path | type | description | last_updated)

3. GPT 决定要加载哪些 paths (按 description 选)

4. Cortex 加载这些 paths + 展开 [[wikilink]] (resolve depth=1)

5. 整套 context_pack 传给下游工具调用
```

### 11.2 v1 implementation (eager-load simplification, v0.2)

`cortex/cortex/twin.Twin.assemble_context_pack()` currently **eager-loads** everything (no two-pass GPT-picks):

- `identity.md` (always)
- All files in `skills/` (typically ~8-10 .md files, < 15 KB total)
- All files in `people/core/` (one-per-core-contact; small)

Rationale: at Phase 2 scale (~10-20 small files, < 15 KB total) eager-load fits comfortably in one prompt window and is dramatically simpler than two-pass routing. Cost: ~3-6 K extra prompt tokens per Router call — acceptable.

**When this becomes a problem** (Phase 7 trigger): Twin grows to 30+ skills or 50+ people/core; prompt window pressure becomes noticeable; cost per call > $0.05.

**Migration path to two-pass**: `twin_query.ask` adapter already exists and works (verified in Phase 2 deep test). Router can dispatch `twin_query.ask` mid-plan to fetch slices on demand instead of upfront. Two-pass GPT-picks-from-TOC is the long-term ideal but isn't needed yet.

**`_system/TOC.md`** still exists and is human-readable but currently NOT consulted by Router (eager-load doesn't need it). Phase 7 will revive it.

**`_system/TOC.md` 示例**:

```markdown
# Twin TOC (auto-maintained)

## skills/
| path | description | updated |
|---|---|---|
| skills/email-style.md | 我邮件怎么写（tone, length, sign-off, don'ts）| 2026-05-23 |
| skills/code-review.md | 我做 PR review 的 comment 风格 | 2026-05-20 |
| skills/transcript-to-insights/SKILL.md | Convert raw interview transcript to polished insights doc (ChronoFork house style) | 2026-05-11 |
| ... | | |

## people/core/
| path | description | updated |
|---|---|---|
| people/core/jane-doe.md | HCI researcher at MIT Media Lab | 2026-05-23 |
| ... | | |

## interests/
| path | topic | signal_strength | last_signal |
|---|---|---|---|
| interests/rl.md | Reinforcement Learning | 0.75 | 2026-05-20 |
```

Cortex 每次写入 Twin → 增量更新 TOC.md 对应行。

---

## 12. CHANGELOG.md (替代 git)

按用户决议：**Twin 不入 git，不 push GitHub**。维护 `CHANGELOG.md` append-only 人可读日志：

```markdown
# Twin Changelog

## 2026-05-23

### 19:30 — email reply to Jane [src:evt_001]
- Added: receipts/2026-05-23.md (new file)
- Updated: people/core/jane-doe.md
  - last_contact: 2026-05-15 → 2026-05-23
  - Added "Recent interactions" entry

### 14:20 — promoted Mike Chen to core [src:evt_042]
- Promoted: people/encounters.md "Mike Chen" section
  → people/core/mike-chen.md
- Reason: 3rd appearance + 关联到 [[commitments/follow-up-mike]]

### 11:00 — implicit learning [src:pulse_003 + dismiss]
- pulse_003 (Sutton 新论文) → user dismissed
- Updated: skills/pulse-feedback.md
  - Added rule: "Sutton 类话题在工作时段 dismiss 率高，建议非工作时段推"
```

**特性**:
- append-only
- 人可读 markdown（`vim CHANGELOG.md`）
- 每条 entry: 时间 + 动作 + 文件 + diff + source

**不做**:
- ❌ Git commit / GitHub backup
- ❌ 历史版本（v1 不存改前 vs 改后全文）
- ❌ Undo（如未来需要，加 `_system/snapshots/` 作 v1.5+）

**改坏了怎么办**:
- 看 CHANGELOG 知道什么时候改了什么
- 手动 vim 改回去
- pending 机制兜底（low-conf 改动不直接落地）

---

## 13. 人脸图 (Tool Agent 本地模型)

**按用户决议**：人脸识别用本地模型，不用 GPT-4V。

**架构调整**（修订 OQ-C5）:

| Vision 任务 | 归属 | 模型 |
|---|---|---|
| **人脸识别 / embedding / 匹配** | **Tool Agent** | 本地（实施时调研，OQ-D7）|
| OCR / 场景理解 / 一般 vision QA | Cortex | GPT-4V |

**Twin/memories/faces/ 结构**:

```
memories/faces/{person-slug}/
├── face-20260412-200015.jpg
├── face-20260515-150300.jpg
└── embeddings.json    ← Tool Agent 维护，不进 CHANGELOG.md
```

**人脸识别流程**:
1. Glass 发 `user_invoke {image, text}`
2. Cortex Router 判断需要人脸识别 → dispatch `rpc(tool=local_face_recognition, action=identify)`
3. Tool Agent 跑本地模型 → 返回 match (person-slug, confidence)
4. Cortex 拉对应 `people/core/{slug}.md` → HUD 显示

---

## 14. Markdown body 约定

- **`[[wikilink]]`** 交叉引用：`[[jane-doe]]` 按上下文猜（`people/core/` 内默认匹配 person）；`[[receipts/2026-05-23#14:30]]` 指 section anchor
- **标题**：`# Title` (一级，与 frontmatter 配套) → `## Section` → `### Subsection`
- **任务列表**：`- [ ]` / `- [x]`
- **frontmatter 给 LLM 看；body 给人看**——结构化检索 + 自由叙事互补

---

## 15. v1 不做的事

| 项 | 理由 |
|---|---|
| Vector DB / embedding 数据库 | SoT C-7 明确不用 |
| Git 版本控制 / GitHub backup | 用户决议 |
| Schema migration | v1 freeze |
| 多用户 | SoT N-5 |
| 人脸 embedding cloud sync | 全本地 |
| Snapshot / undo (v1) | need-driven，跳到 v1.5+ |
| GPT-4V 做人脸识别 | 改用本地模型 |
| RL / fine-tuning for implicit learning | 纯 LLM 自审 + pending review |

---

## 16. Open Questions

| # | 问题 | 推荐 / 状态 |
|---|---|---|
| OQ-D1 | TOC.md 维护时机 | 每次 Twin 写入 → 增量；daily verify |
| OQ-D2 | `[[wikilink]]` resolve 谁做 | Cortex 在 context_pack 准备时展开 (depth=1) |
| OQ-D3 | receipt 按天聚合 vs 按 evt | 按天聚合 |
| OQ-D4 | identity 9 个维度够 / 多 / 错 | v1 draft 起点，用着用着丰富 |
| OQ-D5 | encounters.md 千 section 时怎么办 | v1 暂不分；need-driven 时按年/字母分 |
| OQ-D6 | implicit learning 异步触发时机 | task 完成后 (新鲜度高) |
| OQ-D7 | local face recognition 库选型 | 实施时调研 |
| OQ-D8 | learning confidence 阈值 0.8 是否合适 | 默认 0.8，写在 `skills/twin-write-policy.md` 可调 |
| OQ-D9 | 用户 vim 改 skill 后 Cortex 怎么"尊重" | mtime 检查 + 那个 skill 上后续 learning 阈值临时调高 |
| OQ-D10 | 大 skill 跨多文件时 LLM 怎么找入口 | 同 Anthropic 标准：SKILL.md 是入口，子文件通过 [[link]] 引用 |

---

## 17. 关键 trade-offs explicit 标注

| 取舍 | 选了什么 | 牺牲什么 |
|---|---|---|
| **粒度** | 人物 core / encounters 两层 | 偶遇细节被合并（缓解：encounters.md 内完整 capture）|
| **去 git** | CHANGELOG append-only 日志 | 无 version history / undo（缓解：pending 机制 + 未来可加 snapshots）|
| **人脸归 Tool Agent** | 本地模型 | 本地 setup 一次性成本 |
| **Implicit learning 不用 RL** | LLM 自审 + pending | 学习速度受 LLM 提炼能力限制 |
| **skill 不强 schema** | 密度自适应（简单 3 行，复杂 SKILL.md style）| 没有统一 template，consistency 靠 frontmatter description |
| **identity 维度自由扩** | v1 draft 起点，逐步丰富 | bootstrap 期 AI 对"你"理解可能不足 |

---

## 18. Document Status

- **Version**: v0.2
- **Last updated**: 2026-05-24
- **Based on**: v0.1 spec + Phase 2 实现实际行为 (eager-load context_pack + step receipts for multi-step)
- **Companion**: [DESIGN.md](../constitution/DESIGN.md) · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md)
- **Next**: Phase 7 — revive `_system/TOC.md` for two-pass context_pack; promote eager-load to fallback; add `[summary]` receipt for multi-step tasks

### Revision Log

| Version | Changes |
|---|---|
| v0.1 | First version: Twin layout + skill / person / project / receipt / commitment / interest types + 按需加载 spec + Implicit Learning Loop |
| v0.2 | **Phase 2 实现同步**: §8.1 receipt format spelled out to match `cortex.server._write_receipt` actual output; §8.2 new — multi-step `[step N]` receipt format per R-3; §11 split into §11.1 spec target + §11.2 v1 eager-load simplification (assemble_context_pack loads identity + all skills + all people/core; two-pass picks deferred to Phase 7; `twin_query.ask` adapter is the bridge mechanism) |

---

*End of Constellation Data Model v0.2.*
