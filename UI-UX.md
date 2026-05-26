# Constellation — UI/UX Design

**Version**: v0.4 (v2.1 pivot annotation)
**Status**: Phase 3b 实施中. **Glass 端的硬件 / SDK / 交互方式已迁到 [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1** — 本文档保留 web HUD 的设计原则 + 跨 surface 共享语言。Glass 物理输入 / 渲染 / 音频细节看 GLASS-CLIENT-DESIGN.md.
**关联文档**: [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 · [DESIGN.md](DESIGN.md) · [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) · [COMPONENT-DESIGN.md](COMPONENT-DESIGN.md) · [DATA-MODEL.md](DATA-MODEL.md) · **[Doc/ui-mockup.html](Doc/ui-mockup.html)** (视觉 ground truth — v0.3 内容; §1 由 GLASS-CLIENT-DESIGN.md v2.1 supersede) · **[halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md)** (现在是 optional companion) · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md)
**Last updated**: 2026-05-26 (v2.1 pivot annotation)

> ⚠️ **v2.1 pivot note** (2026-05-26): 原 §5 "Cross-app integration (Halo Ring Plugin Protocol)" 部分内容已**降级为 optional companion** — Glass 端物理触控板按键直接覆盖所有交互需求（单击/长按/双击/双指）。Halo Ring 仍可作为额外的环形手势输入，但不再是 HUD 设计的依赖前提。详见 [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 §2.2 + `reference/rokid-glass/bare-metal-docs/01-key-events.md`.
>
> 原 §3.4 "always-on mic per card" 也已**撤销**（与 v2.1 能效约束冲突）：mic 现在只在用户主动按物理键开启，15s hard cap 自动关闭。

Constellation Glass 端的 UI/UX 文字落地。视觉细节看 [Doc/ui-mockup.html](Doc/ui-mockup.html)——它是 1:1 ground truth。**本文件只承载决策、原则、跨文档引用**，避免重复 mockup 里的视觉描述。

---

## 1. 设计前提

Constellation Glass 端**只两个 surface**：

| Surface | 占比 | 触发 |
|---|---|---|
| **HUD overlay** | **99% 的交互** | 用户主动触控（单击/长按/双击/双指）/ Cortex 主动推 / Tool 反向 wake |
| **App 设置页** | 月度调一次 | 用户手动开 app (改 Cortex IP / shortcut 内容) |

**Glass 物理触控板/按键是主输入路径**（v2.1）；Halo Ring 仍可作为 optional 增强（如果配套环装了），通过 [Plugin Protocol](halo-ring-plugin-protocol.md) 推 profile。Constellation 声明自己能做哪些 actions，被触发时接收 Intent。

---

## 2. 视觉语言 (继承 Halo Ring)

100% 继承 Halo Ring 的 8 token + type scale + focus indicator + HUD pill 样式。详 [Doc/ui-mockup.html §1 lead](Doc/ui-mockup.html)。

唯一加的语言元素：**新 icon set** (✉ ⌖ ⚙ ✦ ✓)。**不加新颜色**——单副眼镜上不再造第二套色彩 brand。

---

## 3. HUD 设计 (Atom-based)

**HUD 只有 2 个 atom**：

| Atom | 形态 | 何时用 |
|---|---|---|
| **Status pill** | 1-2 行小 pill，top-right，无 options | thinking / peek / receipt brief / 网络错误 (centered) |
| **Card** | 大 panel (max 360px wide), top-right, 1-4 options | 一切需要决策的事 |

### 3.1 Card 是通用 template (核心设计原则)

Card 不是为每个 use case 单独设计。**同一个 Compose 组件**，靠不同 content 渲染不同 case：

```
[icon] [title] [optional v2 badge]
[meta line]
[body — markdown, may include inline code / line breaks]
[divider]
[option 1] [option 2] [option 3] [option 4]    ← 1-4 options，第一个 focused
[ttl]
```

**Cards 之间的差别只有 4 个变量**:

1. **Icon** — ✉ / ⌖ / ⚙ / ✦ / ✓ (case-specific)
2. **Left stripe** — green (P6 insight) / amber (P4 tool wake) / 无 (default)
3. **Body content** — markdown，由 Cortex 决定
4. **Options array** — 1-4 个 labels，由 Cortex 决定

### 3.2 Card cases 覆盖

参 [Doc/ui-mockup.html §1](Doc/ui-mockup.html) frames 1.3 ~ 1.11.

| Case | icon | stripe | options 示例 |
|---|---|---|---|
| **A. Preview action** (邮件代回等) | ✉ | 无 | `SEND` · `FEEDBACK` |
| Listening state (Feedback 中) | ⌖ | 无 | (无 options，含 waveform) |
| Iterated preview v2 | ✉ + v2 badge | 无 | `SEND` · `FEEDBACK` |
| **B. P6 Surprising insight** | ✦ | **green** | `OPEN DRAFT` · `SNOOZE 1d` |
| **B. P4 Tool reverse-wake** | ⚙ | **amber** | `ONCE` · `SESSION` · `DENY` |
| **C. Info display (face match)** | ⌖ | 无 | `LOG ENCOUNTER` · `OPEN ARCHIVE` |
| **D. Propose add (face unknown)** | ⌖ | 无 | `ADD + DICTATE` · `SKIP` |

### 3.3 Status pill cases

| Case | dot | label |
|---|---|---|
| Cortex thinking | green pulsing | "Cortex thinking…" |
| Peek (idle 状态查询) | green | "Cortex · connected · 12 today" |
| Receipt brief | green ✓ | "✓ Sent to Jane + reminder in 3h" |
| Network error (**centered**) | red | "Cortex unreachable" |

### 3.4 Response model: always-on mic + ring tap parallel (v0.3 per SoT R-3 / C-22)

**v0.3 paradigm shift**: every HUD card opens the mic by default with VAD-stop the moment
it's shown. There's no "FEEDBACK option" the user must tap first — the mic is **always
available** as a parallel response channel to ring-tap options.

```
HUD card displayed
  │
  ├── Mic opens (VAD-stop after 2s silence; 30s hard timeout)
  └── Default option highlighted, ring nav available

User responds via ONE of:
  (a) Ring tap default option → user_decision { decision: "send" } (or option_id for tool_card)
  (b) Speak any utterance → STT → user_decision { decision: "feedback", feedback_text: "<STT>" }
  (c) Wait full ttl → Glass auto-dismisses → user_decision { decision: "dismiss" }
```

**Visual treatment** (per [Doc/ui-mockup.html](Doc/ui-mockup.html) — Phase 3 client implements):
- Card always shows a thin mic indicator (small ⌖ dot bottom-left or top-right, color-matched
  to existing focus indicator)
- Optionally show a tiny waveform when user speaks (reuse existing "Listening…" pill style)
- Don't make the user FEEL like they're "entering feedback mode" — speech is always-available
- Default option ring-focused with `❯` cursor as usual; ring nav still works in parallel

### 3.5 Free-form feedback semantics (v0.3 per R-3 / C-23)

When the user speaks, Cortex Router classifies `feedback_text` into one of four categories
(per [CORTEX-ROUTER-PROMPT.md §1.2](CORTEX-ROUTER-PROMPT.md)) and shapes the next plan
accordingly. The user doesn't have to know which category — they just speak:

| User says (示例) | Router interprets as | Result |
|---|---|---|
| "yes" / "对" / "好" | (a) CONFIRM | Same as ring-tap default; advance |
| "actually 4pm not 10am" | (b) CORRECTION | Recompute current step with fix |
| "skip the reminder" / "that's all" | (c) SKIP | Drop the relevant subtask(s); terminal hud_show |
| "the meeting is Thursday 4pm" | (d) INJECT-INFO | Use as ground truth; advance |

The mic is non-modal: tapping ring while speaking just takes whichever lands first.

### 3.6 Multi-step task visual treatment (v0.3 per R-3 / C-20)

Some intents take multiple HUD rounds. Cards in a multi-step task look identical to single-shot cards from the user's perspective — same template, same atom. The only signal that more is coming is the card body (which Router writes to make the next step obvious, e.g. "Add reminder + draft reply?" hints another card follows).

Optional Phase 3+ enhancement: tiny step indicator (e.g. `· · ·` dots top-right showing `●○○`
for "step 1 of an expected 3") IF prompt makes step-count predictable. Currently the system
doesn't predict total steps, so this is deferred.

### 3.7 Feedback iteration (legacy single-step) — still works

For simple intents that aren't multi-step, the old "preview → FEEDBACK → revised preview" loop still works via the same mechanism — `task_history` is just empty in single-step context.

**Image is not re-captured** across iterations (reuses original `user_invoke` image).

### 3.8 Streaming agent path (v0.4 per SoT R-4 / C-25 / C-26 / C-27)

When the classifier routes an ask to the agent path, the HUD experience adds three new states between "invoke" and "preview":

#### A. Glanceable progress ticker (non-blocking, C-25/C-26)

The user sees **a colored row appear every 2–3 seconds**, each one a single line:

| Icon | Kind | Example label |
|---|---|---|
| 🔧 | tool | "running osascript reminders add" |
| 📖 | read | "reading kao-2026-04-18.md" |
| ✍️ | write | "drafting reply (412 chars)" |
| 💭 | thinking | "thinking… (8s quiet)" — **heartbeat**, see below |
| ⏸ | paused | "phase 1 done — awaiting decision" |
| ▶️ | resuming | "continuing after your input" |
| 🎯 | plan | "plan: 3 steps" |
| ✗ | error | "shortcut failed: <reason>" |
| 👂 | listening | "feedback open" (mic indicator) |
| 💬 | user-said | "你听到的话: '改成下周一'" (echo of injected feedback) |

Rows accumulate top-to-bottom as a timeline. **Each label is ≤80 characters** so a single glance suffices. No row blocks — the user can keep talking, walking, watching whatever they were watching.

#### B. Thinking heartbeat (C-25)

Opus 4.7 with extended thinking can sit silent for 10–30s while it reasons. Cortex emits a synthetic 💭 row every **8 seconds of jsonl silence** so the HUD never looks dead:

```
💭 still thinking… (8s quiet)
💭 still thinking… (16s quiet)
💭 still thinking… (24s quiet)
🔧 running osascript mail send  ← real activity resumed
```

The interval is intentionally human-noticeable but not anxiety-inducing.

#### C. Phase-checkpoint card (⏸ blocking, C-27)

When CC emits `{phase_done: true, summary, next, actions?: [...]}` the HUD shifts from ticker mode to a **blocking checkpoint card**:

```
┌─────────────────────────────────────────────┐
│ ⏸ Phase 1 done                              │
│                                             │
│ Read 3 emails with Kao; latest meeting       │
│ ask is for 2026-04-25 14:00.                │
│                                             │
│ Next: draft a reply confirming + add        │
│ reminder 1h before.                         │
│                                             │
│  [Continue]   [Adjust]   [Cancel]           │
└─────────────────────────────────────────────┘
```

- **Continue** (ring-tap default) → Cortex dispatches `agent_continue` with literal "continue".
- **Adjust** → mic opens (per C-22) for free-form correction; user's words go in as `agent_continue("Adjust: <text>")`.
- **Cancel** → Cortex dispatches `agent_kill` and writes a partial receipt.

A complex task can have multiple checkpoints; they each look the same. The blocking is **reliable** (CC really has paused, end_turn already fired) — distinct from progress_feedback mid-thinking which is best-effort.

#### D. Final preview (executor-mapped actions[])

When CC emits actions without `phase_done`, Cortex builds the standard `preview_action` multi-row card (one row per action). SEND iterates the executor adapters as in v0.5. Phase 5g's pruned catalog is the executor side of this.

---

## 4. App 设置页 (只 5 个 frame)

参 [Doc/ui-mockup.html §2](Doc/ui-mockup.html) frames 2.1 ~ 2.5.

| Page | 内容 | 用途 |
|---|---|---|
| **2.1 Main** | Cortex 连接 status block + 3 个 entry rows (Shortcuts / Connect / About) | 进 app 的落地页 |
| **2.2 Shortcuts list** | 已存 shortcuts 列表 + "+ NEW SHORTCUT" | 管理 shortcut 集合 |
| **2.3 Shortcut editor** | name + preset prompt + photo toggle + mic toggle | 编辑单个 shortcut **内容** (不绑 gesture) |
| **2.4 Connect to Cortex** | Tailscale IP + push token status + test/re-register buttons | 改 Cortex 地址 |
| **2.5 About** | version + Halo Ring linked status + Cortex status + 开源声明 | 诊断 + signature |

### 4.1 故意没开放的自定义项

| 项 | 为什么不开放 |
|---|---|
| HUD 颜色 / 字号 | 视觉语言跟 Halo Ring 一致；自定义会破坏跨 app 一致性 |
| HUD ttl (30s 默认) | 没合理理由让用户调；如果有 case 需要不同 ttl，Cortex 端传 |
| HUD 位置 (top-right) | 继承 Halo Ring |
| Profile / Gesture 绑定 | **全部在 Halo Ring** —— single source of truth |
| Shortcut 的 gesture | 同上，在 Halo Ring 的 Action Picker 绑 |
| `auto_confirm` (跳过 preview) | 违反 P3 HITL，**永远不允许** |

> **核心 stance**：默认设计已经决定了大部分东西；自定义只暴露真正必要的两类——**shortcut 的 preset 内容** 和 **Cortex 连接地址**。其他都按 default 走。

---

## 5. 跨 App 集成 (Halo Ring Plugin Protocol)

**Constellation 没有任何手势 UI**。手势在 Halo Ring 改。具体协议详 [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md)。

### 5.1 触发链路

```
ring gesture → Halo Ring 识别 → 查找绑定 → 发现绑到 com.constellation.glass/voice_invoke
            → sendBroadcast(Intent "com.halo.ring.action.TRIGGER", extras={action_id: "voice_invoke"})
            → Constellation 的 TriggerReceiver 接收 → 启动 foreground service
            → service 拍照 + 开麦 + 发 user_invoke event 给 Cortex
```

### 5.2 Action 注册

Constellation 通过 ContentProvider 暴露它能被触发的 actions：

```
content://com.constellation.glass.halo_actions/list

→ voice_invoke    | Voice invoke (mic + photo)
  shortcut_1      | Quick capture person
  shortcut_2      | OCR & save to today
  shortcut_3      | Drop a thought
  hud_focus_prev  | (HUD profile only, hidden)
  hud_focus_next  | (HUD profile only, hidden)
  hud_activate    | (HUD profile only, hidden)
  hud_dismiss     | (HUD profile only, hidden)
```

Halo Ring 装载这些 actions 后，在它的 Action Picker UI 里以 **EXTERNAL APPS / CONSTELLATION** 分组显示。

### 5.3 HUD profile 切换

Constellation 显示 HUD 时，向 Halo Ring 发 `PROFILE_PUSH` Intent，临时压栈一个 `constellation_hud` profile，把 SWIPE_UP/DOWN/TAP/DOUBLE_TAP 改绑到 HUD 操作。HUD 关闭时 `PROFILE_POP`。

Halo Ring system gestures (TRIPLE_TAP / QUAD_TAP / LP+SWIPE_DOWN / 2×LP) **永远穿透**，不被 HUD profile 拦截。

---

## 6. Open Questions

| # | 问题 | 推荐 |
|---|---|---|
| OQ-U1 | Card body markdown 超过 8 行处理 | "↓ more" → TAP 展开 full-screen review；或 truncate + 完整 receipt |
| OQ-U2 | Feedback 迭代到 v4 / v5 / ... 时是否提示 "你已迭代 N 次" | v1 不提示；multi-step 已有 5 rounds 上限保底 |
| OQ-U3 | HUD 主动 dismiss 后是否要 receipt | 是：写 "user dismissed at T+X" 进 receipt |
| OQ-U4 | Status pill `pulsing` 动画是否太耗电 | 用 alpha 而非颜色切换；GPU 接近零成本 |
| OQ-U5 | RayNeo X3 Pro 上 card 360px 宽是否撑下右眼 | 实施时测试，必要时降到 320px |
| OQ-U6 | Halo Ring plugin protocol 推到 Halo Ring agent 后，多久能 ready | ✓ Halo Ring 端已 ship (per HANDOFF) |
| OQ-U7 | **always-on mic 跟 Halo Ring SWIPE_UP gesture 冲突吗** (v0.3) | Halo Ring 用 HUD profile (PROFILE_PUSH on card show); SWIPE_UP 在 profile 内绑到 "confirm default option" — 跟 mic 不冲突 (mic 不需要手势触发) |
| OQ-U8 | **multi-step task 第 N 步是否要 visual step indicator** (v0.3) | v1 不加；Router 已经在 body 里把"还有下一步"写清楚；点击次数预测困难时强行加 dots 会误导 |
| OQ-U9 | **language detection for STT** (中/英) | Glass STT 自动 detect；不需要客户端切换 |

---

## 7. Document Status

- **Version**: v0.3
- **Last updated**: 2026-05-24
- **Companion**: [Doc/ui-mockup.html](Doc/ui-mockup.html) v0.2 · [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) v0.1 · [CORTEX-ROUTER-PROMPT.md](CORTEX-ROUTER-PROMPT.md) v0.2
- **Based on**: SoT R-3 (C-22 always-mic + C-21 HUD-as-info-card + C-20 multi-step) → spec 收敛前 Phase 3 客户端实施前最后一版

### Revision Log

| Version | Changes |
|---|---|
| v0.1 | 首版：10 principles / HUD card types / shortcut system / cross-app 描述 (但 mockup 过于 cluttered) |
| v0.2 | 重写。明确"两类 surface" 边界；HUD 显式标 atom-based 设计 (pill + card)；card 强调通用模板；加 face recognition 作为 card 模板适配性的 demo；app 砍到 5 frame；手势 / profile 完全推给 Halo Ring，配套 [halo-ring-plugin-protocol.md](halo-ring-plugin-protocol.md) 输出 |
| v0.3 | **R-3 paradigm 落地**: §3.4 重写 "Response model" — always-on mic + ring tap parallel；mic 不是 opt-in mode 是 default channel；§3.5 新增 "Free-form feedback semantics" — Router 自分类 4 类 (a/b/c/d)；§3.6 新增 "Multi-step task visual treatment" — v1 不加 step indicator；§3.7 标 legacy 单步 feedback iteration still works；OQ-U6 closed；新增 OQ-U7 (always-mic vs Halo Ring SWIPE_UP 冲突分析) + OQ-U8 (multi-step step indicator 决议) + OQ-U9 (STT language detection) |

---

*End of Constellation UI/UX Design v0.3.*
