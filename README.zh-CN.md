# Constellation · 星座

> *A constellation of senses, one mind.* — 「万象皆星，一念至此」

[English](README.md) · **简体中文**

Constellation 是一个面向**全天候可穿戴助理**的个人 AI 框架。AR 眼镜负责采集意图——语音、
一帧画面、一次按键——交给家里那台常开的 Mac 上运行的 agent。agent 判断你想做什么，把活儿
分发给你本来就在用的工具（Claude Code、邮件、日历、提醒事项、备忘录、文件系统），再把结果
推回眼镜的 HUD。它关于你的一切认知，存在一堆你可以直接用 `vim` 打开的 Markdown 里。

本仓库是**设计中枢**：宪法、架构、接口契约。运行时代码在另外两个仓库。

> **它到底是什么，说实话。** Constellation 是一个给一个人日常使用的研究原型，不是产品。它
> 假设单用户、一台地址固定的 Mac、一副特定型号的 AR 眼镜；prompt 和 Twin 路径里直接写死了
> 作者的名字。开源它，是因为其中的设计取舍和踩过的坑值得一读，**不是**因为它能开箱即用。
> 见 [已知局限](#已知局限)。

## 一张图说清楚

```
     Rokid 眼镜                      Mac（常开）                      你的工具
 ┌────────────────┐            ┌──────────────────────┐         ┌──────────────────┐
 │ 麦克风（按键   │  音频 +    │  Cortex              │  RPC    │ Claude Code CLI  │
 │ 触发，15s 上限）│  图像      │  ├ Whisper 语音转写  │────────▶│ 邮件 / 日历      │
 │ 摄像头         │───WSS─────▶│  ├ 意图分类器        │         │ 提醒 / 备忘录    │
 │ 480×640 HUD    │            │  ├ router / planner  │         │ iMessage/Safari  │
 │ 触摸 + 按键    │◀──卡片─────│  └ Claude Agent SDK  │◀────────│ 文件系统         │
 └────────────────┘            └──────────┬───────────┘         └──────────────────┘
                                          │
                                  ┌───────▼────────┐
                                  │  数字孪生 Twin │  纯 Markdown：
                                  │ ~/constellation│  identity · people · projects
                                  │     /twin/     │  memos · receipts · skills
                                  └────────────────┘
```

## 七条承诺

框架由它**保证什么**来定义，而不是由某一个用例定义。简述：

1. **统一意图入口**——你身上哪个设备接住意图都行，背后是同一个大脑。
2. **Twin 属于你**——一个你能手工读、改、删的 Markdown 库。
3. **默认受监督**——任何有副作用的动作（发送、发布、删除）都要你先点头。
4. **能耗诚实**——麦克风只在物理按键时开启，且有硬上限。没有唤醒词，不做环境监听。
5. **嵌进工具栈，而不是取代它**——Constellation 驱动你已有的工具。
6. **双向唤醒**——你能叫醒它，长时间运行的工具也能反过来叫醒你。
7. **框架高于用例**——新能力以 adapter 的形式加入，而不是 fork 出一套新的。

完整表述、以及每条承诺各自付出的代价，见
[docs/constitution/DESIGN.md](docs/constitution/DESIGN.md)。

## 仓库分布

| 仓库 | 内容 |
|---|---|
| **[Constellation](https://github.com/MRziyi/Constellation)**（本仓库） | 设计宪法、架构、接口契约、路线图 |
| [Constellation-Server](https://github.com/MRziyi/Constellation-Server) | Cortex（大脑）+ Tool Agent（双手）+ Twin 种子——Python |
| [Constellation-Glass](https://github.com/MRziyi/Constellation-Glasses) | 眼镜端客户端——Kotlin / Jetpack Compose，Android |

## 从哪读起

| 你想… | 读 |
|---|---|
| 理解整个框架 | [docs/constitution/DESIGN.md](docs/constitution/DESIGN.md) —— 主设计文档 |
| 搞清每条需求的来历 | [docs/constitution/SOURCE-OF-TRUTH.md](docs/constitution/SOURCE-OF-TRUTH.md) —— 锁定的原始意图 + 修订记录 |
| 看它长什么样 | [docs/assets/ui-mockup.html](docs/assets/ui-mockup.html) —— 用浏览器打开 |
| 对着协议写代码 | [docs/server/INTERFACE-CONTRACTS.md](docs/server/INTERFACE-CONTRACTS.md) |
| 理解 agent 运行时 | [docs/server/AGENT-ARCHITECTURE-V2.md](docs/server/AGENT-ARCHITECTURE-V2.md) |
| 写眼镜端代码 | [docs/glass/GLASS-SDK-REFERENCE.md](docs/glass/GLASS-SDK-REFERENCE.md) —— 这台设备上真正能跑通的东西 |

### 文档索引

**宪法** —— [`docs/constitution/`](docs/constitution/)
- [SOURCE-OF-TRUTH.md](docs/constitution/SOURCE-OF-TRUTH.md) —— 原始需求原文保留，加上历次修订。项目里任何东西都不允许悄悄违背这个文件。
- [DESIGN.md](docs/constitution/DESIGN.md) —— 主框架规格：七条承诺、架构、已定论的设计问题。
- [ARCHITECTURE-REFLECTION.md](docs/constitution/ARCHITECTURE-REFLECTION.md) —— 对架构对错的复盘。

**服务端设计** —— [`docs/server/`](docs/server/)
- [AGENT-ARCHITECTURE-V2.md](docs/server/AGENT-ARCHITECTURE-V2.md) —— 当前权威的 agent 运行时：分类器、agent 路径、阶段检查点。先读这篇。
- [COMPONENT-DESIGN.md](docs/server/COMPONENT-DESIGN.md) —— Cortex / Tool Agent 内部结构。
- [DATA-MODEL.md](docs/server/DATA-MODEL.md) —— Twin 的 Markdown 数据模型、receipt、上下文打包。
- [INTERFACE-CONTRACTS.md](docs/server/INTERFACE-CONTRACTS.md) —— 全部线上协议（Glass↔Cortex、Cortex↔Tool、Twin、MCP）。
- [TOOL-ADAPTERS.md](docs/server/TOOL-ADAPTERS.md) —— adapter 目录及各自的动作面。
- [PROMPT-DESIGN-V2.md](docs/server/PROMPT-DESIGN-V2.md) · [CORTEX-ROUTER-PROMPT.md](docs/server/CORTEX-ROUTER-PROMPT.md) —— prompt 架构与 Twin 两遍加载。
- [Q4.5-VISION-PASSTHROUGH.md](docs/server/Q4.5-VISION-PASSTHROUGH.md) —— 摄像头画面如何直达多模态模型，而不经过有损的「先描述成文字」这一步。
- [MAIL-INBOUND-RULE.md](docs/server/MAIL-INBOUND-RULE.md) —— 收到邮件 → HUD 卡片 → 口述回复并正确挂进原线程。
- [DEPLOYMENT-mac-mini-migration.md](docs/server/DEPLOYMENT-mac-mini-migration.md) —— 无显示器跑 Mac 端，含「SSH 下如何授予 macOS TCC 权限」这个难点。

**眼镜端设计** —— [`docs/glass/`](docs/glass/)
- [GLASS-CLIENT-DESIGN.md](docs/glass/GLASS-CLIENT-DESIGN.md) —— 裸机 Android 客户端设计（v2.1）。
- [GLASS-SDK-REFERENCE.md](docs/glass/GLASS-SDK-REFERENCE.md) —— 音频、按键、显示、前台服务、相机、二维码：硬件的真实行为。
- [IN-APP-UI-DESIGN.md](docs/glass/IN-APP-UI-DESIGN.md) —— 应用内各界面与扫码配对流程。
- [UI-UX.md](docs/glass/UI-UX.md) —— HUD 视觉语言，以及 480×640 单色绿屏对它的约束。
- [NETWORK-ALTERNATIVES.md](docs/glass/NETWORK-ALTERNATIVES.md) —— 让眼镜联网的各种方案，以及哪些在现实中活了下来。
- [PAIRING-AND-AUTH-RECOVERY.md](docs/glass/PAIRING-AND-AUTH-RECOVERY.md) · [P1.6-COMPOSE-MIGRATION.md](docs/glass/P1.6-COMPOSE-MIGRATION.md) · [P1.8-MEMORY-ENERGY-PROFILE.md](docs/glass/P1.8-MEMORY-ENERGY-PROFILE.md) · [MIGRATION-PLAN.md](docs/glass/MIGRATION-PLAN.md)

**路线图** —— [`docs/roadmap/`](docs/roadmap/)
- [IMPLEMENTATION-PLAN.md](docs/roadmap/IMPLEMENTATION-PLAN.md) · [USE-CASE-AUDIT.md](docs/roadmap/USE-CASE-AUDIT.md) · [TOOL-IDEAS.md](docs/roadmap/TOOL-IDEAS.md)

**跨设备** —— [`docs/cross-device/`](docs/cross-device/)
- [halo-ring-plugin-protocol.md](docs/cross-device/halo-ring-plugin-protocol.md) —— 来自配套智能戒指的可选手势输入。

**素材** —— [`docs/assets/`](docs/assets/)（UI mockup）· [`docs/brand/`](docs/brand/)（logo）

## 硬件

| 部件 | 我们跑在什么上 |
|---|---|
| 眼镜 | Rokid Glasses —— JBD4020 单色绿 micro-LED，480×640 竖屏，右眼；YodaOS-Sprite（Android 12 Go，API 32） |
| 大脑 | 任意常开 Mac（Apple Silicon；Whisper 与人脸识别走 CoreML） |
| 链路 | 公网 TLS 中继，或 Tailscale，或经手机热点的蓝牙 PAN |
| 戒指（可选） | [Halo Ring](https://github.com/MRziyi/Halo-Ring) —— 提供手势输入；没有它系统靠语音也完整 |

第三方 SDK 文档**不在**本仓库转载。[reference/INDEX.md](reference/INDEX.md)
列出了权威来源和自行获取的方式。

## 状态

| 领域 | 状态 |
|---|---|
| 设计宪法 | 稳定；经 SOURCE-OF-TRUTH.md 的修订记录持续修正 |
| Mac 主干 —— Cortex + Tool Agent + Twin，launchd 托管 | 可用，日常在跑 |
| 13 个工具 adapter + 副作用受监督 | 可用 |
| 眼镜端 —— Compose HUD、应用内设置、扫码配对、相机 | 真机可用 |
| 本地语音转写（whisper.cpp 双档）+ 端上人脸识别 | 可用 |
| Claude Agent SDK 进程内 agent 路径 | flag 后可用；正在取代旧的 tmux 方案 |
| 眼镜与戒指之外的多设备扩散 | 已设计，未实现 |

## 已知局限

明说，因为设计文档本身就要求诚实列出代价：

- **结构上就是单用户。** 作者的名字直接写进了系统 prompt 和 Twin 路径。要做成多租户是一次真正的重构，不是改个配置。
- **没有做隐私加固。** v1 明确用隐私工作换了速度。任务内容会送到云端模型。Twin 留在本地、人脸识别在端上——但别把它当成 privacy-by-design 的系统。
- **只支持 macOS。** adapter 通过 AppleScript 驱动邮件、日历、提醒、备忘录、iMessage、Safari，需要 macOS 的 TCC 授权。
- **强绑定特定硬件。** 眼镜端针对的是这一台设备的脾气——它的声道掩码、它的按键广播、它的 AppOps 相机行为。
- **部分设计文档是中文**或中英混排，宪法和眼镜端笔记尤其如此。

## 许可

采用 [Apache License 2.0](LICENSE)。

Constellation 是自由开源软件。如果有人为此向你收费，你被骗了。

---

*Where your senses go, your mind follows.*
