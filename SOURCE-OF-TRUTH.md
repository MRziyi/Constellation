# Constellation — Source of Truth (用户原始需求文档)

## 文档约定

本文档是 Constellation 项目的**原始意图记录**。它的角色：

1. 完整保留用户（Zack）在最初一轮 /office-hours 中的所有原始表述。
2. 设计文档（companion file）是对本文档的**综合与具体化**——可以扩展、可以补充实现细节，但**不能改变本文档锁定的方向**。
3. 后续每次迭代设计稿之前，应该先重读本文档，确保新版本仍然符合这里记录的意图。
4. 如果迭代过程中发现本文档的某项需求需要修订，**必须显式在本文档新增一节"修订记录"，注明日期、新需求、和被修改/废止的旧需求**。绝不静默偏离。

约束摘要在文末的 §6 "Locked Constraints" 和 §7 "Explicit Non-Goals"，便于快速 diff。

---

## 1. 原始 Pitch（用户开场，完整保留）

> 用 gstack 帮我想清楚：我正在准备进行的 AR 眼镜项目的开发计划。这款眼镜上有显示屏、光波导显示、摄像头、麦克风、触摸交互，我还为它写了一个戒指应用（~/Code/Projects/R08-dev），方便操作。接下来，我需要完成真正的、我想在眼镜上实现的全天候智能助理。我的设想是，眼镜从外部获取信息后，把所有可获取的信息发送给我家里的 Mac 电脑（Mac mini），由 Mac mini 来推测我想做的事。无论是去查看某个云端代码在跑的技术，还是启动 Codex 等等，都会下发指令。眼镜会把原始指令或操作的相关信息交给云端工具处理，界面如何与电脑交互需要你来考虑。
>
> 我有几个设想的场景。第一个场景是：这个 agent 会维护一个关于我的数据库，该数据库也可以与其他 AI 工具共享。因为我会通过一个 API 来支持它，但它的目标是把任务分发出去, 我有 Claude、GPT 的订阅，重任由他们来完成。这个 agent 之后就成了一个分发任务、汇报任务的工具，同时也负责维护一个数据库，里面包含我的各类信息、个人信息、朋友、偏好等。希望它能成为我的物质孪生，拥有足够的信息来实现这一点。这个数据库会不断迭代更新，因此对我来说体验是无状态的，而这个 agent 也同样无状态。但每次得到结果时，它会按我的风格、偏好来处理。例如，我对眼镜说"对不对"，如果我突然收到一封邮件，我可以对眼镜说："你去回复这封邮件。这封邮件里问了我几点开会，我说三个小时后再去开会"，并用英语礼貌地回复。它会依据数据库内容、调动其他工具来完成任务，并用我的偏好来写邮件。邮件写好后，先用 Claude code 的工具通过我的 Mac 发送出去，然后我的工具再查看结果。眼镜会给我一个预览，看看写得怎么样，没问题就发送。接着任务会被分发给 Claude，Claude 再利用电脑中的其他工具把邮件真实发送出去。Claude 也会在我的苹果生态中添加提醒等内容。这就是第一种用法。
>
> 第二种用法是：比如我现在在电脑上跑着一个 Claude code，我让它在做一个项目。如果项目遇到权限问题，需要我确认时，眼镜可以给出提示让我允许编辑文件，或者让我让 Claude code 进入某个目录执行任务，写一些内容。Agent 会调这些工具，完成我想要的操作。过一会儿我再问：这项任务做得怎么样了？Agent 能了解我的语境，去查看 Claude 的输出。实际上这是双向的：我的 agent could 给 Claude 发出指令，请 Claude 反馈给我，或者 Claude 能通过我的 agent 向我提出需要确认的操作等。
>
> 除了文本操作，眼镜还具备摄像头等功能。比如在会议上，我看到某个人，我可以确认、拍照并记下这个人他在从事的领域（例如 HCI Education、VR 技术、MIT 等），然后把这些信息连同图像一起写入数据库。未来遇到相似的人时，我还能调出一个功能，拍照并与数据库中的记录比对，看看是不是上次见过的人，并在眼前给出记录（如上次见面的时间、研究方向等）。如果我和某人在聊天时开启了转写，相关信息也会同步到我的数据库。等到某天我想起这件事，Agent 可以在数据库中查找并 dispatch 相关任务。
>
> 上述场景的核心链路是：我的眼镜作为数据采集设备，具备视觉、听觉、触觉反馈，并通过显示屏向我输出信息；所有信息都会发送到我位于远程的电脑上运行的 Agent，由它来分发任务、写数据库、监控工具调用状态；这些工具又可以调用 Agent 来向我推送信息或请求确认。

### 注释（不修改用户意图，只标识关键概念）

- **眼镜硬件**：显示屏 + 光波导 + 摄像头 + 麦克风 + 触摸（确认载体在后续锁定为 Rokid Glass）
- **戒指应用**：已存在于 `~/Code/Projects/R08-dev`（Halo Ring 私有开发仓库）
- **核心组件**：眼镜 + Mac mini（家里）+ Agent + 数据库
- **目标**："全天候智能助理"（all-day AI assistant）
- **原始命名**：用户用了"物质孪生"，后续在第 8 条澄清这是 typo，正确说法是**"数字孪生 (Digital Twin)"**
- **三个原始用例**：
  - 用例 1：邮件代回（眼镜+语音+Agent+Claude+本地邮件工具的全链路）
  - 用例 2：双向遥控 Claude Code（眼镜接管远程跑着的 Claude Code）
  - 用例 3：人脸记忆 + 检索（视觉捕捉 + 数据库 + 再识别）
- **核心链路（用户原话总结）**：
  > 眼镜=数据采集，Agent=分发/写库/监控，工具=被调用 + 反向调 Agent 推用户

---

## 2. 项目目标（用户的"为什么"）

**问：你做这个事情的目标是什么？**
**答（用户原话）：**

> 作为 HCI 研究的原型机，会准备发表 CHI/UbiComp 论文（如果足够创新且没人有类似的思路），我自己也会用。

### 锁定含义

- 这是 **HCI 研究方向的原型机**，不是产品、不是创业。
- **可能**发 CHI/UbiComp 论文，**条件**是 "足够创新 + 没人有类似的思路"。
- **自己也会用**——self-use 是一阶目标，不是营销说辞。

---

## 3. 论文 vs 原型的优先级（用户主动澄清）

在第二轮被追问"选哪个用例作为论文 anchor demo"时，用户拒绝了这种 framing，主动澄清：

> 这个项目它不急，我想把它做成一个足够 interesting 的，然后再跟别人讨论，关于别的这个适合写成文章的维度。这个项目可能发很多文章。我现在不太想让这个项目以文章发表为主。
>
> 是要这个设计 feature，这个就按照我原来的这个思路来进行设计，然后不断地来做一个所谓的 cool prototype。我跟一些专业专家展示，然后我构思里边哪些 feature 能出来做一些文章。

### 锁定含义

- **优先级：cool prototype > 论文**。先做出有意思的系统，再讨论文章。
- 项目可能产出**多篇文章**，每篇文章对应原型的一个 dimension/feature。
- 不要让"为论文设计"扭曲原型的形状。
- **明确的工作流**：build cool prototype → 展示给专家 → 跟专家讨论哪个 dimension 可以写成文章。

---

## 4. 框架优先（用户拒绝以"单一用例"为核心）

在第三轮被追问"哪个 60 秒动作序列是 magic moment"时，用户再次主动拒绝并澄清：

> 你前面讲的都对，都是我们的重点。但我需要再次强调，我们做的这个 unified 的框架，上面这些意思只是一些用例 use case。在我们统一的框架之下，未来还会有更多有意思的 use case，这就是我们需要我们构思的，需要考虑一个设计，还有用什么 cool feature 能不能来。
>
> 然后你需要整合我上面所有想到的信息，我们来构建文档，然后来修改、更新；你也可以问我一些更多的问题，我们把这个事情想得更清楚更帅。现在就抛弃你 focus 在哪个 case 上的问答。Case 只是在我们 unified 的这个厉害的框架下，一个很帅的用法，未来还会有更多很帅的用法。

### 锁定含义

- **核心交付物 = unified framework**，不是任意单一 use case。
- 三个原始用例（邮件、Claude Code 遥控、人脸记忆）只是 **当前的几个 use cases**，未来还会有更多。
- 设计活动的形状：先设计框架 → 在框架下生出 cool features。
- 用户邀请 AI **多问问题、把事情想清楚想帅**——明确拒绝 case-level 的 Q&A。

### 用户对"愿景"的扩展（在第三问的最后一句话之前的一段中）

在第一轮的回答里用户也展开了 vision：

> 因为一个人身上在一天里戴的智能设备肯定是大于等于 1 个，有手机、耳机、智能戒指、麦克风等等。不同的设备会有不同的 affordance。能不能靠这些不同的设备来给使用者每天实时一直带在人身上，不管通过哪种设备，都能利用这些设备一直伴随在人旁边，这是最宏大的愿景。

#### 锁定含义

- **多设备伴随**是 vision：一个人身上同时戴 ≥1 个智能设备（手机、耳机、戒指、麦克风、眼镜等）。
- 不同设备有不同的 **affordance**（用户原话使用了这个概念）。
- 目标：用户身上**总有**至少一个设备能承担当前任务的 I/O。
- 眼镜只是**一个**终端，不是唯一终端。

---

## 5. 框架的设计决策（用户一次性拍板的 7 项）

在被追问"哪一个 framework promise 是 signature"的时候，用户没有挑单选，而是一次性做了 7 个设计决策：

> 你上面列出的各个描述都是我的核心 feature。另外，项目以这个 constellation（星座）作为命名。

接着：

> 离家场景：眼镜跟 Mac mini 一定是无论我是否在家，都通过公网连接。后续考虑一下怎么实现。
>
> 触发模型是 Wake On Demand，是可以被我这个客户端（不管是眼镜还是其他设备的客户端）来叫醒，也可以被电脑上正在运行的某些工具来叫醒。
>
> 数据库的 schema 要参考 Skill 来设计，用 Markdown 格式让大模型按需自索引自添加。你也可以考虑一下别人或者当前的 practice 是怎么做的。
>
> dispatch 的 policy 让大模型来决定。隐私不重要，因为这个毕竟还是我自己用的东西。
>
> confirm 的话，动作都要前置预览。比如说，参考 Claude Code，它会问我不同的东西嘛。如果我写邮件，也肯定得让我预览完、同意才能发送。还需要我来 human in the loop 来迭代，绝对不是那种我直接 hands off 它随便做的。
>
> 另外就是 cool feature，我们可以一起 brainstorm 一下，可以多列一些，就在我们上面讨论的框架之下。

### 锁定含义（逐条）

| # | 决策 | 锁定的内容 |
|---|---|---|
| D-A | **项目正式命名** | **Constellation（星座）**。不再用 "AR-Agent" 之类的代号。 |
| D-B | **核心 features（不是单一 signature）** | AI 提出的所有候选 promises（statelessness, affordance dispatch, receipts, interop substrate）**全部都是核心 feature**，不挑出单一 signature。 |
| D-C | **离家连接** | 眼镜 ↔ Mac mini **永远走公网**，不区分在家/外出。单一路径。 |
| D-D | **触发模型** | **Wake-on-Demand**。可叫醒来源：(a) 眼镜或任何设备的客户端，(b) 电脑上正在运行的某些工具。 |
| D-E | **数据库 schema** | **Markdown 文件**，参考 **Skill 的设计**，让大模型**按需自索引、自添加**。要参考别人或当前的 practice。 |
| D-F | **Dispatch policy** | **大模型决定**（LLM-as-router）。 |
| D-G | **隐私优先级** | **不重要**（v1）——因为是 "自己用的东西"。 |
| D-H | **Confirm 策略** | **所有动作都要前置预览**。参考 Claude Code 的 permission 模型。**human-in-the-loop 是绝对要求**，**不允许 hands-off**。 |
| D-I | **Cool features** | 可以 brainstorm，**多列一些**。必须在"上面讨论的框架之下"。 |

---

## 6. 实施节奏（用户对 v1 的范围控制）

被追问 cool feature slate 的时候，用户没有挑 A/B/C/D 选项，而是给了节奏指令：

> 你上面那些提的 cool feature 先不着急实现。就按照我上面给你的描述的那个框架，我们先来搓一把，然后那些 cool feature 就先记着，就不着急写。
>
> 我们接下来去看看这个系统的设计，然后以这个 AI 眼镜为我们第一个载体，来深入地进行一轮设计。先把我们的流程跑通了，我们的框架跑通了。可能涉及到的是眼镜的 Android，先以 rokid Glass 为用例，然后我 Mac mini有两个客户端 不过先不着急写代码。现在要跟我彻底定下来设计稿、界面设计方案等等，一系列架构、feature、一系列的东西，把我上面跟你提到的框架给设计出来。然后我们在讨论迭代最后的实现，是我们胜利的宣告而非冲刺的号角。

### 锁定含义

- **Cool features 先不实现**，但要**记着**。
- v1 实现内容：**就是用户上面描述的那个框架本身**。先把框架跑通、流程跑通。
- **第一个硬件载体 = Rokid Glass**（Android），不是 RayNeo。
- Mac mini 上**有两个客户端**（澄清见 §7）。
- **现在不写代码**。
- 现阶段任务：**彻底定下来设计稿、界面设计方案、一系列架构、feature**。
- 用户对这件事的态度（必须保留作为长期方针）：
  > **"实现是我们胜利的宣告而非冲刺的号角。"**
  
  Translation: "Implementation is the declaration of victory, not the sprint's call." 设计阶段不能仓促进入代码。

---

## 7. 架构澄清：两个客户端 + 一个服务器（用户最后的纠正）

被追问"Mac mini 上的两个客户端是什么"时，用户做了关键的架构澄清：

> 我意思是，我的眼镜是负责传数据的客户端，但我 Mac mini 上跑的那个 agent 是我这个客户端所连接的可能服务器或者其他的。
>
> 我说的两个客户端就是指眼镜的客户端跟我电脑上的客户端。电脑上的客户端是负责调一些工具的 agent。
>
> 具体这两个客户端分别怎么设计，眼镜和 Mac mini 两个客户端怎么设计，这个之后再考虑。
>
> 另外，我上面提到的我个人的数据库是我的数字孪生。你可能听错了，有个 typo。

### 锁定含义

#### 架构拓扑（用户视角）

```
眼镜客户端（Rokid）   ──┐
                       ├──► Cortex Agent（运行在 Mac mini 上，扮演 "server" 或类似角色）
Mac mini 客户端 ───────┘    （Cortex 本身也跑在 Mac mini 上）
（"调工具的 agent"）
```

#### 两个客户端的角色

- **Client 1（眼镜）**：负责**传数据**。捕捉感知（视觉、音频、触觉）并传给中间的 Agent。
- **Client 2（Mac mini 上的客户端）**：负责**调工具**。是一个 agent，调用各种工具（Claude Code、AppleScript、邮件、Codex 等）。

#### 中间的 Agent

- 用户原话：**"我电脑上跑的那个 agent 是我这个客户端所连接的可能服务器或者其他的"**——所以 Cortex Agent 是这两个客户端连接到的东西，扮演 server 或中介角色。
- Cortex Agent 也跑在 Mac mini 上（与 Mac mini 客户端是同机不同进程）。

#### 名词锁定

- **"个人数据库"** = **"数字孪生 (Digital Twin)"**。
- 之前 AI 错听成 "物质孪生 (Material Twin)"，**纠正为 Digital Twin**。后续所有文档统一使用 Digital Twin 一词。

#### 范围控制

- **两个客户端各自的内部设计 = 之后再考虑**。本轮只设计框架本身。

---

## 8. Locked Constraints（必须遵守的硬约束清单）

以下条目是用户已经显式拍板的，**所有后续设计/实现/迭代都必须遵守**。如要修改，需走 §11 "修订流程"。

| 编号 | 约束 |
|---|---|
| C-1 | 项目正式命名为 **Constellation（星座）**。 |
| C-2 | 第一个硬件载体是 **Rokid Glass**（Android 平台）。 |
| C-3 | 戒指应用 R08（Halo Ring）已存在于 `~/Code/Projects/R08-dev`，是配套设备。 |
| C-4 | **眼镜 ↔ Mac mini 永远走公网**，不区分在家/外出。单一代码路径。 |
| C-5 | 系统包含**两个客户端 + 一个中间 agent**：眼镜客户端（传数据）+ Mac mini 客户端（调工具）+ Cortex Agent（中间，跑在 Mac mini）。 |
| C-6 | 触发模型是 **Wake-on-Demand**。可被任何设备客户端唤醒，**也可被电脑上正在运行的工具唤醒**。 |
| C-7 | **个人数据库 = Digital Twin（数字孪生）**。用 **Markdown 文件**，**参考 Skill 的设计**，**LLM 自索引自添加**。 |
| C-8 | **Dispatch policy 由大模型决定**（LLM-as-router）。 |
| C-9 | **所有有副作用的动作都必须前置预览**。参考 Claude Code 的 permission 模型。 |
| C-10 | **human-in-the-loop 永远存在**。绝不允许 hands-off / 自动执行 mutating action。 |
| C-11 | **优先级**：cool prototype（一阶）> 论文（二阶副产物）。 |
| C-12 | **核心交付物**是 unified framework，不是任意单一 use case。 |
| C-13 | **眼镜只是众多终端之一**。框架必须支持未来接入手机/耳机/麦克风/戒指等设备。 |
| C-14 | Agent **从用户视角是无状态的**——每次任务从 Twin 重建上下文。Twin 是唯一的累积状态。 |
| C-15 | Twin 必须**可以与其他 AI 工具共享**（API 暴露）。 |
| C-16 | 第一次会话不写代码。**先彻底定下设计稿、界面设计方案、架构、feature 列表**。 |

---

## 9. Explicit Non-Goals（用户明确否决的方向）

| 编号 | 否决 | 用户原话依据 |
|---|---|---|
| N-1 | **不要 case-level focus** | "现在就抛弃你 focus 在哪个 case 上的问答" |
| N-2 | **不要以发文章为主要驱动** | "我现在不太想让这个项目以文章发表为主" |
| N-3 | **不要在 v1 实现 cool features**（虽然要记着） | "你上面那些提的 cool feature 先不着急实现" |
| N-4 | **不要 hands-off 自动执行** | "绝对不是那种我直接 hands off 它随便做的" |
| N-5 | **v1 不为隐私设计** | "隐私不重要，因为这个毕竟还是我自己用的东西" |
| N-6 | **现在不要写代码** | "先不着急写代码"+"实现是我们胜利的宣告而非冲刺的号角" |
| N-7 | **不要把眼镜当成唯一终端** | "眼镜只是众多终端之一"（综合自 vision 段落 + 第 5 节决策） |

---

## 10. 原始三个 Use Cases（保留为参考，不作为框架本身）

为了避免后续设计与原始意图脱节，三个原始用例完整保留如下。**注意：这些是用例，不是框架核心**（per §4）。

### Use Case 1: 邮件代回

> 我对眼镜说"对不对"，如果我突然收到一封邮件，我可以对眼镜说："你去回复这封邮件。这封邮件里问了我几点开会，我说三个小时后再去开会"，并用英语礼貌地回复。它会依据数据库内容、调动其他工具来完成任务，并用我的偏好来写邮件。邮件写好后，先用 Claude code 的工具通过我的 Mac 发送出去，然后我的工具再查看结果。眼镜会给我一个预览，看看写得怎么样，没问题就发送。接着任务会被分发给 Claude，Claude 再利用电脑中的其他工具把邮件真实发送出去。Claude 也会在我的苹果生态中添加提醒等内容。

**框架要素**：voice intent → Twin context pull → Claude LLM draft → Mac tool send → 苹果生态联动 → 眼镜预览 → 用户 confirm。

### Use Case 2: 双向遥控 Claude Code

> 比如我现在在电脑上跑着一个 Claude code，我让它在做一个项目。如果项目遇到权限问题，需要我确认时，眼镜可以给出提示让我允许编辑文件，或者让我让 Claude code 进入某个目录执行任务，写一些内容。Agent 会调这些工具，完成我想要的操作。过一会儿我再问：这项任务做得怎么样了？Agent 能了解我的语境，去查看 Claude 的输出。实际上这是双向的：我的 agent could 给 Claude 发出指令，请 Claude 反馈给我，或者 Claude 能通过我的 agent 向我提出需要确认的操作等。

**框架要素**：Claude Code → Cortex（反向唤醒）→ 眼镜推送 → 用户授权 → Cortex → Claude Code 继续；以及 用户问询 → Cortex → Claude Code 状态查询 → 反馈。

### Use Case 3: 人脸记忆 + 检索

> 比如在会议上，我看到某个人，我可以确认、拍照并记下这个人他在从事的领域（例如 HCI Education、VR 技术、MIT 等），然后把这些信息连同图像一起写入数据库。未来遇到相似的人时，我还能调出一个功能，拍照并与数据库中的记录比对，看看是不是上次见过的人，并在眼前给出记录（如上次见面的时间、研究方向等）。如果我和某人在聊天时开启了转写，相关信息也会同步到我的数据库。等到某天我想起这件事，Agent 可以在数据库中查找并 dispatch 相关任务。

**框架要素**：vision capture → metadata（语音 + 元数据）→ Twin 写入；以及 vision capture → Twin 检索 → 眼镜 HUD 显示历史信息；以及 ambient transcript → Twin → 跨时检索 + dispatch。

### 锁定要求

后续在设计稿中**详细解析这三个用例所触及的所有框架原语**。如果某个用例的某一步无法在当前框架中表达，**优先认为是框架缺了某个原语，需要补**——而不是 "用例不重要，跳过"。

---

## 11. 修订流程

如果在迭代过程中发现本文档某项需求需要修订：

1. 不要直接修改 §1-§10 的原始记录。
2. 在文档末尾新增一节 `## Revision-{N}: {YYYY-MM-DD}: {one-line description}`。
3. 在该节里：
   - 引用旧约束 / 旧意图（链接到 §X.Y）。
   - 说明新的需求 / 新的决定。
   - 说明**为什么**改变（什么新信息促成了改变？）。
   - 标注被废止 / 被替换的旧条目（在 §8 表格的对应条目里加 `[REVISED-in-R{N}]` 标记）。
4. 设计文档同步更新，且在 commit message 里引用 `[Source-of-Truth R{N}]`。

---

## 12. 反向追溯映射（Source of Truth ↔ Design Doc）

以便后续 diff 检查，下表把本文档的硬约束映射到 design doc 的对应段落：

| 约束 | Design Doc 对应位置 |
|---|---|
| C-1 Constellation 命名 | §1 Project Identity |
| C-2 Rokid Glass 首载 | §8 Hardware Target |
| C-3 R08 配套 | §8.5 Touch + Ring gesture model |
| C-4 永远走公网 | §4.1 Transport decision |
| C-5 两客户端 + 中间 agent | §3.1 Topology |
| C-6 Wake-on-Demand | §5.1 Wake model |
| C-7 Twin = markdown + skill-style | §6 Digital Twin |
| C-8 LLM-as-router | §7 Dispatch Policy |
| C-9 全部前置预览 | §5.4 + §10 |
| C-10 human-in-the-loop | §10 Confirmation Ladder |
| C-11 cool prototype 优先于论文 | §1 What it is/isn't |
| C-12 framework 是核心交付 | §2 Vision |
| C-13 眼镜是终端之一 | §2 + §11 Q1 |
| C-14 用户视角无状态 | §2 P1 Statelessness |
| C-15 Twin 可共享 | §6.6 Interop API |
| C-16 不写代码先设计稿 | §16 Assignment + §12 deferred design |
| N-1 不 case-focus | §13 Parked features |
| N-2 不为论文驱动 | §1 What it isn't |
| N-3 不实现 cool features | §13 Parked features |
| N-4 不 hands-off | §10 |
| N-5 v1 不为隐私 | §2 P5 deferred |
| N-6 不写代码 | §12 deferred |
| N-7 眼镜非唯一终端 | §3.2 + §8.1 |

后续每一次 design doc 改动，都要回到这张表验证所有 16+7 条约束 / 非目标是否仍然被尊重。

---

*End of Source of Truth document. 后续迭代不得偏离本文档，只能依据 §11 流程修订。*

---

## Revision-1: 2026-05-24: 锁定两条新约束 — 音频不入 Cortex；网络搜索走 Claude Code

### 触发

Phase 2 Slice C 收尾时，agent 写了 [TOOL-IDEAS.md](TOOL-IDEAS.md) v0.1，列了 18 个候选 adapter。Zack triage 时 explicit 拒绝了 T3 (`web_search`) / T4 (`arxiv`) / T11 (`whisper_local`) / T12 (`screenshot_ocr`)，并给出底层 framing 而非单点否决——这些 framing 上升到 SoT 级别。

### 新约束（追加到 [§8](#8-locked-constraints必须遵守的硬约束清单)）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-17** | **Cortex 接收的输入永远是 `{text, image?}`，从不接收原始音频。** STT 在 Glass / 手机 / 其他客户端完成后再发给 Cortex。这把 [§7 拓扑](#7-架构澄清两个客户端--一个服务器用户最后的纠正) 里"客户端负责传数据"的"数据"形态进一步锁死。 | "我发给你的东西肯定是固定的一段文本 prompt 和一张照片，然后我会用眼镜或者其他手机的其他服务来进行 STT。" + "不然我把音频传给你还挺浪费带宽的。" |

### 新非目标（追加到 [§9](#9-explicit-non-goals用户明确否决的方向)）

| 编号 | 否决 | 用户原话依据 |
|---|---|---|
| **N-8** | **Cortex 不实现/调用 long-form 音频转写（含 Whisper.cpp / Whisper API / 任何 ASR 服务）。** Constellation 永不持有音频管道。 | "我不需要搞这个长时间的 STT 服务…不用这个 Whisper 的 API。" |
| **N-9** | **Cortex 不实现独立的网络搜索 / 学术搜索 adapter（含 web_search / Tavily / arxiv / Semantic Scholar 等）。** 此类能力**通过 `claude_code` adapter 间接获得**——Claude Code 有自己的 web 工具，Cortex 只需 dispatch CC 即可。Zack 自己的 Tavily key 也是同样原则——给 CC 用，不给 Constellation 直接调。 | "T3、T4 我在想能不能直接用现成的，比如 Claude Code 能够使用这个网络工具，让它来帮我做。" |
| **N-10** | **Cortex 不主动截屏 Mac 桌面（screenshot OCR adapter 否决）。** Vision 推理只针对 Glass 拍的、用户主动 capture 的照片。 | "我不需要你有这个 screenshot 的能力，我只需要你可能根据我的 prompt，把我发给你的照片发给视觉模型就行了。" |

### 配套政策（不是 SoT 级约束，但记录在此供回溯）

- **R-1**: 当用户语音 / 文字意图需要"查 paper" / "搜 web" 时，Router 应该 dispatch `claude_code.draft` 或 `claude_code.run` 让 CC 用它自己的 web 工具完成，再把结果汇总回来。这是 N-9 的实现路径。

### 影响范围

- [DESIGN.md](DESIGN.md) §3.2 拓扑：Glass → Cortex 输入定义改 `{image, text}` 不变（已对的），但应该在 §2 执行边界加一行 "Cortex never receives audio"。
- [INTERFACE-CONTRACTS.md](INTERFACE-CONTRACTS.md) §1.3 已经把 `user_invoke.payload` 定义为 `{image, text}` — 已经符合 C-17，无需改。
- [TOOL-ADAPTERS.md](TOOL-ADAPTERS.md): `claude_code` adapter 的 description 应该提一句 "use this when web search / paper search is needed" 让 Router 学到 N-9 的实现路径。
- [TOOL-IDEAS.md](TOOL-IDEAS.md) v0.2 已经记录了 triage 结果。
- 未来 Cool Examples Library 里如果出现 audio-driven 用例 ([DESIGN.md §5 B 类的 transcript 相关](DESIGN.md))，必须改写为"STT 在客户端完成后投递文本"。

### Diff to existing constraints

无 existing constraint 被废止；纯增量。

---

## Revision-2: 2026-05-24: 邮件语义边界 — 不管推送 / 写 vs 回是两种意图

### 触发

Phase 2 Slice C 完成 mail/calendar/fs/notes/system_status/shortcuts/twin_query/imessage/safari 9 个 adapter 后，Zack 在批 TOOL-IDEAS triage 时补充了关于 mail 的核心语义：

> "我的邮件通知推送这些东西不用你管；我的手机会推送，推送会发给我的眼镜。
> 你要注意我：我要求发邮件的时候跟我要求回复发邮件的时候不一样。我要求回复什么邮件的时候，肯定是以我收到邮件的这个邮件地址来回复；但我要求发邮件的话就不一样了。我发邮件，我会说用 QQ 有想法，或者用 UIUC邮箱发，或者我会说，回忆一下我之前谁接到的邮件等等。"

这是 mail intent shape 的关键澄清，必须 SoT 级落地。

### 新约束（追加到 [§8](#8-locked-constraints必须遵守的硬约束清单)）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-18** | **Constellation 不实现/管理邮件 push notification。** 邮件到达通知由 Zack 的 iPhone 推送给 Glass，走 Apple ecosystem 现有路径。Cortex 只在 Zack 主动 invoke 时才触及 mail。 | "我的邮件通知推送这些东西不用你管；我的手机会推送，推送会发给我的眼镜。" |
| **C-19** | **Mail "回复" vs "发送" 是两个不同的 intent class，必须由 Router/adapter 严格区分**：<br><br>**REPLY** (`reply_to_current` / `reply_to_message_id`)：sender account = 该邮件被收到的账号，由 Mail.app 的 `reply` action 自动决定。Router **绝不**对 reply 显式指定 `account` arg。<br><br>**COMPOSE** (`send(to=…, account=…)`)：sender account 由用户**显式语言**指定（"用 QQ 发"/"用 UIUC 发"）。如果用户没指定，使用 Mail.app default account。<br><br>**SEARCH** (`find_messages(participant?, subject_contains?, …)`)：跨 inbox + sent 检索；用于"回忆我跟 X 的邮件"这类意图；返回 message_id 列表后才能配合 `reply_to_message_id` 进行 reply。 | "我要求发邮件的时候跟我要求回复发邮件的时候不一样。我要求回复什么邮件的时候，肯定是以我收到邮件的这个邮件地址来回复；但我要求发邮件的话就不一样了。我发邮件，我会说用 QQ 有想法，或者用 UIUC邮箱发，或者我会说，回忆一下我之前谁接到的邮件等等。" |

### 新非目标（追加到 [§9](#9-explicit-non-goals用户明确否决的方向)）

| 编号 | 否决 | 用户原话依据 |
|---|---|---|
| **N-11** | **Constellation 不订阅 IMAP IDLE / 不轮询新邮件 / 不实现任何"新邮件"推送源。** Zack 已有 iPhone+Glass 链路承担这件事。 | C-18 推论。 |

### 实施影响（已落地）

- [tool-agent/tool_agent/adapters/applescript_mail.py](tool-agent/tool_agent/adapters/applescript_mail.py) v2 加 `account` arg（resolve via `_resolve_account_address`）、加 `find_messages(participant?, subject_contains?, body_contains?, account?, mailbox?, limit?)` 用 AppleScript `whose` clause、加 `send(reply_to_message_id=…)` 模式。
- [cortex/cortex/router.py](cortex/cortex/router.py) `AVAILABLE_TOOLS["applescript_mail"]` description 改写为三段式 (REPLY / COMPOSE / SEARCH)，让 Router GPT 学会三种意图的映射。
- 没有任何代码或 Router 行为对应"新邮件 push"——符合 C-18。

### Diff to existing constraints

C-17 (Cortex 输入 `{text, image?}`) 与本次新约束一致，无冲突。

---

## Revision-3: 2026-05-24: 任务范式 — Multi-step + Always-mic + HUD-as-info-card

### 触发

Phase 2 收尾后 Zack 给出两个典型用例并 explicitly 说"还有很多类似的，你不要让我一个一个列举，你知道我背后的这种含义就行了"：

> "你去看一下我前两天给云的邮件，我好像跟她提到我们之后会有个 meeting。你告诉我这是什么时候的 meeting，然后帮我加一条 reminder，然后再写一条邮件告诉她说我已经准备好了，我们可以在下周的下午约个时间来 meeting。"

并补充：

> "那两个 HUD 的按钮其实未必是一定固定能选的。它应该是跳一条这个提醒出来，它会默认开我的麦克风。我可以直接用戒指遥控点击这个是或否按钮。对于复杂的，我可能就不会用戒指去点默认的按钮了，我会直接语音告诉你什么什么什么内容。所以你从这就能拿到我的信息，然后就根据这个信息来进一步完成这个任务。"

这是 framework 级范式补充，必须 SoT 锁定。

### 新约束（追加到 [§8](#8-locked-constraints必须遵守的硬约束清单)）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-20** | **任意意图可以是 multi-step task**，不必塞进一次 plan。Router 可以输出"中间 plan" (task_continues=true, 仅探索) + 等用户回应后再输出下一个 plan，直到 task_continues=false。N 步上限（v1=5）防失控。每个中间 step 必须 yield 一张 HUD card 让用户介入。 | "它要先找那个邮件，告诉我是什么时候，填好 reminder，告诉我是什么时候去 meeting；然后我再确认时间，再写邮件。" |
| **C-21** | **每张 HUD card 是 "info card + open-ended yield 点"，不是 "yes/no 单选题"。** Body 必须 carry 足够信息让用户判断；options 是 ergonomic shortcut；麦克风永远是 full bandwidth 通道。用户可以戒指 tap default option，也可以语音任意回应。 | "那两个 HUD 的按钮其实未必是一定固定能选的…我可以直接用戒指遥控…也直接语音告诉你什么什么什么内容。" |
| **C-22** | **Glass 客户端每张 HUD card 出现时默认开麦** (VAD-stop)。用户不说话则 timeout (30s) 等戒指 tap；说话则 STT 转 `feedback_text` 走 `user_decision{decision:"feedback"}` 回 Cortex。这是 Phase 3 客户端 deliverable 的硬要求。 | "它会默认开我的麦克风" |
| **C-23** | **Cortex Router 必须能在 multi-step 上下文 + free-form feedback_text 上下文下，综合判断用户意图四类**: (a) 单纯确认 → 走 next_step_hint, (b) 修正之前 step 的信息 → 用新信息重新走当前 step, (c) 跳过某些 step → 重排 plan, (d) 提供关键参数 → 注入下一步 args. 不是 enum routing，是 GPT-5.4 的语境理解。 | "或者我看到邮件里边，我就直接告诉：那我知道是几点几点 meeting 了，然后你就继续直接给他发邮件吧。中间这个步骤也就可以跳过了。" |

### 实施影响（落地于本次会话）

- [cortex/cortex/router.py](cortex/cortex/router.py) Plan schema 加 optional `task_continues` + `next_step_hint`. System prompt 加三段：multi-step pattern / free-form feedback interpretation / HUD body design。
- [cortex/cortex/server.py](cortex/cortex/server.py): `_pending_previews` 加 `task_history` 字段；`_handle_user_decision` 重构为统一的 `_advance_task()` 路径——SEND on `task_continues:true` 或任何 FEEDBACK 都触发 Router re-invoke，把 task_history + 可选 feedback_text inline 进 prompt。Router 决定是 redo / advance / skip / inject。
- 客户端 (Phase 3, glass-android): 每张 HUD card 渲染时 starts mic with VAD-stop; default option tap 或 mic 输入都走同一个 `user_decision` channel; C-22 是 Phase 3 deliverable 硬要求，从 day 1 设计起。
- INTERFACE-CONTRACTS §1.5 (Feedback Loop) 升级：feedback 不再是用户"主动选 FEEDBACK option"才能用的特殊路径——it's the **default channel** for any HUD card response. options 是 default-button shortcut。

### Diff to existing constraints

- C-9/C-10 (HITL + preview-before-act): 不变；multi-step 反而**加强**HITL—一个 task 现在有多个 yield 点。
- C-13/N-7 (眼镜是终端之一): 不变；C-22 always-mic 是 Glass-specific 设计，未来其他终端 (耳机 / 手机) 可以有 different ergonomics。
- 现有 `user_decision.feedback_text` 字段 (Slice B) 升级语义：在 multi-step 上下文里 carry 更多种含义 (a)-(d)，不只 "redo this step"。

### Open Questions

- **OQ-R3-1**: 中间 step 的 receipt 怎么写？v1 简单：每 step 一条 receipt + 最终 step 一条 task-level summary receipt。Phase 7 polish 可以合并。
- **OQ-R3-2**: 多 step task 跨 daemon restart 会丢 state。v1 接受；Phase 7 加 `_system/active_tasks/{id}.json` persistence。
- **OQ-R3-3**: 用户说"撤销刚才那步"——v1 不支持 undo；接受。

---
