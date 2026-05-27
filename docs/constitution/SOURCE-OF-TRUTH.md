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

Phase 2 Slice C 收尾时，agent 写了 [TOOL-IDEAS.md](../roadmap/TOOL-IDEAS.md) v0.1，列了 18 个候选 adapter。Zack triage 时 explicit 拒绝了 T3 (`web_search`) / T4 (`arxiv`) / T11 (`whisper_local`) / T12 (`screenshot_ocr`)，并给出底层 framing 而非单点否决——这些 framing 上升到 SoT 级别。

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
- [INTERFACE-CONTRACTS.md](../server/INTERFACE-CONTRACTS.md) §1.3 已经把 `user_invoke.payload` 定义为 `{image, text}` — 已经符合 C-17，无需改。
- [TOOL-ADAPTERS.md](../server/TOOL-ADAPTERS.md): `claude_code` adapter 的 description 应该提一句 "use this when web search / paper search is needed" 让 Router 学到 N-9 的实现路径。
- [TOOL-IDEAS.md](../roadmap/TOOL-IDEAS.md) v0.2 已经记录了 triage 结果。
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

- [tool-agent/tool_agent/adapters/applescript_mail.py](../../../Constellation-Server/tool-agent/tool_agent/adapters/applescript_mail.py) v2 加 `account` arg（resolve via `_resolve_account_address`）、加 `find_messages(participant?, subject_contains?, body_contains?, account?, mailbox?, limit?)` 用 AppleScript `whose` clause、加 `send(reply_to_message_id=…)` 模式。
- [cortex/cortex/router.py](../../../Constellation-Server/cortex/cortex/router.py) `AVAILABLE_TOOLS["applescript_mail"]` description 改写为三段式 (REPLY / COMPOSE / SEARCH)，让 Router GPT 学会三种意图的映射。
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

- [cortex/cortex/router.py](../../../Constellation-Server/cortex/cortex/router.py) Plan schema 加 optional `task_continues` + `next_step_hint`. System prompt 加三段：multi-step pattern / free-form feedback interpretation / HUD body design。
- [cortex/cortex/server.py](../../../Constellation-Server/cortex/cortex/server.py): `_pending_previews` 加 `task_history` 字段；`_handle_user_decision` 重构为统一的 `_advance_task()` 路径——SEND on `task_continues:true` 或任何 FEEDBACK 都触发 Router re-invoke，把 task_history + 可选 feedback_text inline 进 prompt。Router 决定是 redo / advance / skip / inject。
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

## Revision-4: 2026-05-25: 架构转向 — CC-as-agent + visible-process invariant + multi-phase checkpoint

### 触发

Phase 2/3a 收尾后 Zack 在 v0.5 multi-step + 12-adapter 路径上做了几次复杂意图（Kao 邮件场景），观察到两个体感问题，原话：

> "我感觉越设计越复杂了… 是否真的需要自己从零搓一堆工具调用… 能不能直接甩给 CC… 不要被现有不合理设计所限制的视野…"
>
> "我能看到过程而不是直接看到结果。要是让我等三十多秒才看到结果，我会很不安。中间路径上的通知要有非常细粒度的设计。"

进一步在执行细节上 Zack 给出了三条强约束（原话）：

> "你还是要用我现在的 opus 4.7 的模型。你要调整，深入考虑这 prompt 怎么设计来避免这些问题。"
> "我每隔几秒我就能看到它在运作，它在干嘛。"
> "敏感操作，或者它要进行某些下一步… 多加一些中途的这种汇报或者控制的节点，作为一种阻塞式的行为。"

这是 framework 级的转向，必须 SoT 锁定。

### 新约束（追加到 [§8](#8-locked-constraints必须遵守的硬约束清单)）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-24** | **复杂任务的 agent runtime 用 Claude Code in TUI tmux，不是手搓多步 Router**。CC 拥有 shell + Read + Bash + WebSearch + Twin add_dir + 推理；Cortex 不再"模仿" agent，只做 classifier + HITL + 进度中继 + checkpoint orchestrator。CC 跑 TUI（用 Pro/Max 订阅配额）而非 `claude -p`（按 API 计费）。 | "能不能直接甩给 CC…" + 选择保留 Opus 4.7 而非降级到 Sonnet |
| **C-25** | **Visible process is a hard invariant**（升级至 C-9/C-10 同级）。用户每 2-3 秒必须看到 agent 在干什么——执行了哪个 tool、读了哪个文件、在想什么。30 秒 "thinking…" 不可接受。当 Opus 处于 extended thinking 不写盘时，Cortex 必须 emit "💭 still thinking… (Ns quiet)" 心跳，每 8s 一次。 | "我每隔几秒我就能看到它在运作，它在干嘛" + "如果我看到它一直在 thinking 我会很不安" |
| **C-26** | **HUD 进度必须 glanceable**（眼镜在眼前，扫一眼就知道在干嘛）。每条进度事件 distill 到 emoji + ≤80 字符标签（🔧 工具执行 / 📖 read / ✍️ write / 💭 thinking / ⏸ paused / ▶️ resuming / 🎯 plan / ✗ error / 👂 listening / 💬 user-said），HUD 渲染成有色 ticker。不是日志、不是诊断流。 | "HUD 上的信息要 glanceable" + "更密集但更可读" |
| **C-27** | **重要 / 敏感 / 多阶段任务必须支持 phase-boundary blocking checkpoints**——CC 在 phase 之间显式 yield（emit `{phase_done:true, summary, next, actions[]}` + `stop_reason=end_turn`），Cortex 弹一张 ⏸ blocking card，用户可以 Continue / Adjust / Cancel；Cortex 调 `agent_continue` 把回应 paste 进同一个 tmux session，CC 续跑。一个复杂任务可以有多个 checkpoint。**这是把 C-9 HITL 从 "执行前预览" 扩展到 "进程中分段汇报"**。 | "敏感操作，或者它要进行某些下一步… 多加一些中途的这种汇报或者控制的节点，作为一种阻塞式的行为" |

### 实施影响（落地于本次会话）

- **新组件**：
  - [cortex/cortex/classifier.py](../../../Constellation-Server/cortex/cortex/classifier.py) — 一步分类：`{complex: bool, why: str}`. 简单走 v0.5 Router；复杂走 agent path. Fail-closed 到 complex.
  - [cortex/cortex/agent_brief.py](../../../Constellation-Server/cortex/cortex/agent_brief.py) — 给 CC 的 brief 模板 v2.6: YOU MUST 强调 + R1/R2/R3 + self-check + phase pattern + inline-Twin slices（v0.5 selector 复用）。
  - [tool-agent/tool_agent/adapters/claude_code.py](../../../Constellation-Server/tool-agent/tool_agent/adapters/claude_code.py) — `_agent` / `_agent_continue` / `_agent_kill` actions; jsonl tail + 8s thinking heartbeat + end_turn 完成检测.
- **变更组件**：
  - cortex.router — `AVAILABLE_TOOLS` 11→10 tools / 50+→11 actions（只剩 bounded single-call）；catalog 之外的能力都到 agent path. Adapter code 保留为 regression 安全网.
  - cortex.server — `_handle_user_invoke` 先调 classifier；`_dispatch_complex_agent` 共享 brief + Twin selector + tmux dispatch；`_check_phase_done` 检测 checkpoint 弹 ⏸ card；`_handle_user_decision` 在 phase 上 dispatch `agent_continue`.
  - tool-agent.server — concurrent RPC dispatch（之前 sequential，长跑 agent 会 block send_keys）.
- **新事件类型**（INTERFACE-CONTRACTS 待补 §1.7 ~ §1.9）：`agent_progress`（非阻塞 ticker）、`progress_feedback`（free-form 用户中途插话，filler/substantive 分类）、`preview_action.kind="phase_checkpoint"`（⏸ blocking card with Continue/Adjust/Cancel options）.
- **R-3 multi-step machinery**: 代码保留向后兼容，但 v2 catalog 已经无法表达需要 R-3 的复杂意图（那些都走 agent path 的 multi-phase checkpoint），R-3 实际处于 deprecated 状态.
- **Mid-flight send_keys**（thinking 中途插话）: 列为已知 best-effort limitation；可靠的 mid-task 介入走 C-27 checkpoint pattern.

### Diff to existing constraints

- **C-9/C-10（HITL + preview-before-act）**: 加强——C-27 把 HITL 从 "execute-time preview" 扩展到 "phase-boundary checkpoints"；一个复杂任务现在可能有 2-3 个独立 yield 点.
- **C-13/N-7（眼镜是终端之一）**: 不变；C-25/C-26 是面向 Glass 的，未来其他终端 (Console / 手机 PWA) 用同一个进度事件流但可以不同 ergonomics.
- **C-20/C-21/C-22/C-23（R-3）**: 形式上保留，实际被 C-24/C-27 取代——Router 多步规划由 CC 的内生 agent loop + phase checkpoint 实现，而不是 Router 反复 re-invoke.
- **C-8（Dispatch policy LLM-driven）**: 不变；分发决策仍然是 LLM 做，只是分两层（classifier → 选 path；planner OR CC 内部 → 选 tool）.

### Open Questions

- **OQ-R4-1**: classifier 现在用 gpt-5.2（已有 OpenAI key）；何时切到 haiku（需要 Anthropic API key plumb）？环境变量 `CORTEX_CLASSIFIER_MODEL` 已开口；等优先级.
- **OQ-R4-2**: phase checkpoint 卡片在 Glass 上是新的 UX surface（不是 preview_action 也不是 hud_show）。Console PWA 已渲染，Glass 端 design 待 Phase 3b/4.
- **OQ-R4-3**: 当 agent 失败（CC crash / 超时 / 写出 invalid schema）时，receipt 怎么写？v1 写 partial receipt with `error` field；Phase 7 polish.
- **OQ-R4-4**: 一个 session 跨多个 user_invoke（"接着上次的继续"）目前不支持——CC 会 spawn 新 session。如果需要，加 `event.payload.continue_from=<rcpt_id>` 字段.

---

## Revision-5: 2026-05-26: 3-button 阻塞卡 · Twin v2 · 自动 distiller

### 触发

完成 Phase 5 v2 + Twin v2 重设计 + auto-distiller 实现后，Zack 对几个关键点
做了最终锁定（含原话）：

> "严格只有 approve、modify 和 kill 三个按钮"
>
> "你不仅写这些战略用的 skill，就是能普通用的 skill，它就普通...只有那种涉及到我的数字孪生了...具有我的特点、个性，对于某一类工作的做法，只有这一类有我的特点、明确个人特色的，才能成为我的 digital profile"
>
> "它的自动整理是什么时候触发的呢？不应该由我主动来触发吧。它整理完之后得告诉我"
>
> "整体我的数字孪生需要深入地重新进行设计，移除没必要的那些乱七八糟的字段，移除那些 placeholder。然后写出来这个创建新的的规则文件"

锁定为 framework 级约束。

### 新约束（追加到 [§8](#8-locked-constraints必须遵守的硬约束清单)）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-28** | **每张 blocking card 严格三个按钮: Approve / Modify / Kill**。无 Feedback / Dismiss / Send all / 任意 option label. Modify 必带文本（点了就 focus composer 等输入；提交才算 Modify 决策；空 Modify re-surface 卡片）。Kill 终止任务 + 杀 tmux + drop pending + 写 kill 学习信号。**自由文本通道** (composer 直接输入 / Glass 麦克风) 和按钮通道平行：cortex 的 classifier 把 "ok / 没问题" 映射成 approve，"停 / 算了" 映射成 kill，其他实质内容映射成 modify。 | "严格只有 approve、modify 和 kill 三个按钮" |
| **C-29** | **Twin 是 4-slot 结构 + 最小 frontmatter**。Layout: `identity.md` · `people/core/<slug>.md` · `receipts/<date>.md` · `.claude/skills/<name>/SKILL.md`. 不允许凭空 add 新的 top-level dir. Frontmatter 字段是**主动 query 用的 unambiguous key**，其他全部入 body 作为 prose. 具体: 人物文件只允许 `aliases / relation / email / phone / preferred_contact`; identity 无 frontmatter; receipts 无 frontmatter. **`~/constellation/twin/README.md` 是 agent 创建文件前必读的 contract**. | "深入地重新进行设计，移除没必要的那些乱七八糟的字段，移除那些 placeholder" |
| **C-30** | **Skill 严格 Anthropic Agent Skills 格式** (`.claude/skills/<name>/SKILL.md` with `description:` frontmatter)。Skill 只服务于"有 Zack 个人特色的某类工作"——通用能力不写 skill（让模型基模负责）。**禁止 placeholder skill**。Skill 通过 implicit-learning 从 `_system/learning_queue.jsonl` 自动 distill 出来；hand-curate 只用于真正有个性的种子 (email-style / reminder-style / code-style 三个为种子). | "skill 只...具有我的特点、个性...才能成为我的 digital profile" |
| **C-31** | **Twin 自动 distillation 是后台触发的，不由用户主动启动**. 系统观察 Modify 决策的累积，达到阈值 + 冷却时间后，自动跑 distiller agent；agent 找到稳定模式才 surface 一张 preview_action 卡片给用户. 没找到就静默. **用户必须能看见且能反馈** (Approve / Modify / Kill 同样 3-button 接口). | "它的自动整理是什么时候触发的呢？不应该由我主动来触发吧。它整理完之后得告诉我" |

### 实施影响（落地于本次会话）

**3-button (C-28)**:
- `cortex.server._THREE_OPTIONS = ["Approve", "Modify", "Kill"]`. 强制覆盖 router emit 的任何 options.
- `_classify_user_decision(decision, feedback_text)` 返回 `('approve'|'modify'|'kill', text?)`. Token sets 同时支持中英及 free-text 推断.
- `_handle_user_decision` 三分支: kill 直接 cleanup; modify 检查 from_agent_final 走 resume，否则走 v0.5 advance; approve 执行.
- Web CardView 三个按钮硬写; Modify focus composer + 紫色边框 placeholder; composer 直接输入也走 sendDecision feedback.

**Twin v2 (C-29 / C-30)**:
- 删除: `_system/TOC.md`, `_system/schema.md`, `skills/{dispatch-policy,pulse-feedback,insight-engine,twin-write-policy,claude-code-control}.md` (placeholders), 整个 `skills/` 目录.
- 迁移: `skills/{email-style,reminder-style,code-style}.md` → `.claude/skills/<name>/SKILL.md` (Anthropic 格式).
- 移动: `skills/confirm-policies.md` → `_system/confirm-policies.md` (Cortex 运行时配置，不是 skill).
- Frontmatter 瘦身: identity.md 无 frontmatter; people files 只剩 `aliases / relation / email`; receipts 无 frontmatter (filename 携带日期).
- 新文件: `~/constellation/twin/README.md` — 是 agent 创建内容前必读的 contract.
- `cortex.agent_brief` ZACK'S TWIN 段重写: 指向 README.md + 4-slot 结构 + 写入规则.

**Auto distiller (C-31)**:
- 新模块 `cortex.distiller.Distiller`. 在 `_handle_user_decision` modify 分支 hook `on_modify(has_text=...)`. 达到 `DISTILL_MIN_MODIFIES=2` + 距上次 `DISTILL_COOLDOWN=30min` 后触发. 后台异步.
- `build_distill_brief` 给 distiller agent 的 brief: 最近 N 条 learning_queue 条目 + Twin README + 输出契约 (同 `actions[]` schema). 关键约束 R1: 没有稳定模式时 emit empty actions:[], 不要硬凑.
- Distiller 输出非空 actions[] 时通过现有 `_send_agent_card_for_decision` 弹一张 preview_action 卡; 用户 Approve/Modify/Kill 都走现有 3-button 闭环.
- 没产出时 silent — 不 surface 卡片. 学习信号自身 (learning_queue.jsonl) 是 Phase-7 的训练语料.

### Diff to existing constraints

- **C-9/C-10 (HITL preview-before-act)**: 不变；distiller surface 的卡片同样 HITL.
- **C-13/N-7 (眼镜是终端之一)**: 不变；3-button 设计在 Glass 是 ring tap / 麦克风 voice channel 双路.
- **C-22 (always-on mic per card)**: 强化为 3-button 自由文本通道——分类器在 cortex 端统一映射.
- **C-25 (visible process)**: 强化——distiller 卡片也加 "🔄 reviewing N recent interactions for patterns" 进度 emit.

### Open Questions

- **OQ-R5-1**: Distiller 阈值 (2 modifies / 30 min cooldown) 是 v0.1 猜值. 真实使用一周后需要根据"产出有用 vs 误报"比例调优. **Update 2026-05-26**: `force_run()` 端到端跑通 — 在 13 entries 的 learning_queue 上 identified 一个 3× 修正模式 (reminders 不该带 notes section). 真实积累后再调.
- **OQ-R5-2**: Distiller 找到的模式如果跟现有 skill 冲突 (e.g. 它建议改 email-style，但跟现有 email-style 矛盾)，谁赢？目前 CC 看到的会做 reasonable 决定，但没显式规则. 等遇到再说.
- **OQ-R5-3**: `~/constellation/twin/README.md` 是 agent 必读 contract. 如果 README 自己被 Zack 修改了 (e.g. 加了新 field), distiller / agent 怎么知道？目前是 read-on-each-write. 没有 cache. 可能 OK.
- **OQ-R5-4**: ~~长生命周期的 tmux per HUD session~~ **CLOSED 2026-05-26 by Revision-6 / P0.1**: tmux 跨 turn 复用已实施; modify-on-FINAL 优先 `agent_continue` paste into live tmux, `--resume` 是 fallback. 见 C-32.

---

## Revision 6 — 2026-05-26 (P0-P2 sweep)

**Status**: confirmed by Zack across this session

完成 P0.1 (long-lived CC reuse) / P0.2 (distiller dogfood) / P0.3 (per-session cost rollup) / P1.1 (R-3 ripout) / P1.4 (Insight Engine skeleton) / P2.1 (archive filter) / P2.6 (HUD search) 后追加的不可逆决定。

### 新约束（追加到 §8）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-32** | **CC tmux per HUD session 是 stateful 的，跨 turn 复用**. 每次 user_invoke 如果 session_id 已有 alive tmux (TTL <30 min)，路由通过 `agent_continue` (paste into live TUI) 而非 fresh `agent` spawn. Modify-on-FINAL 同理：优先 paste into live tmux；`--resume <cc_session_id>` 仅作 TTL 过期后的 fallback. **TTL 是必须的**——长期复用 + jsonl 增长会稀释 CC 注意力. **Kill 按钮显式 tear-down tmux + 清 registry**. | 实施: P0.1 + 测试 (47.7% wallclock 降幅). |
| **C-33** | **多步任务的唯一引擎是 CC agent path (checkpoint pause / agent_continue)**. v0.5 simple path 严格单轮: classifier → router → 一组 subtasks → preview_action → Approve/Modify/Kill. Modify 只允许触发**一次** `_replan_with_feedback`. Router prompt 不再含 MULTI-STEP / `task_continues` / 多 round lore. 想要多步研究/起草 → CC. | "P1.1 ripout" — Zack 默许 + 实施 + e2e 测试通过. |
| **C-34** | **Insight Engine surface 必须是 hud_show (info-only)，不带按钮**. 主动 surface 信息 (upcoming reminder, weather, email reply) 是允许的，但 NOT 中断用户做决策. 任何需要用户决定的事都必须通过 user_invoke pipeline (走 3-button 卡片). Insight Engine 默认 OFF (env `CONSTELLATION_INSIGHT_ENGINE=1`). | 设计 reflection (proactive 不能 hijack agency). |
| **C-35** | **每个 HUD session 的 LLM cost 必须可见**. Sessions 列表 + 详情都 surface `llm_call_count / llm_latency_ms / llm_by_purpose / n_tool_uses / total_wallclock_ms`. ContextVar `current_session_id` 把 LLM 调用 attribute 到当前 turn. **没有 attribute 的 LLM 调用 (e.g. distiller 跑的)** 也必须属于它自己的 session (distiller 跑时 mint 一个 `(auto)` session). | "P0.3 — Cost & latency transparency on HUD" — 落地 + 用户验证. |

### 实施影响（落地于本次会话）

**P0.1 long-lived tmux (C-32)**:
- `tool-agent/.../claude_code.py::_agent`: `keep_alive_on_final` arg. True 时 FINAL (no checkpoint) 不 kill tmux, 只停 watcher, mark state=idle_after_final.
- `cortex/cortex/server.py`: `self._active_hud_session_tmux: dict[sid, {tmux_session, cc_session_id, last_activity, working_dir, timeout_s, last_summary}]`. 30-min TTL via lazy check (`_hud_tmux_lookup`).
- `_dispatch_complex_agent`: alive entry → dispatch `agent_continue`; else fresh `agent` with `keep_alive_on_final=True`. 失败 → evict + fall back to fresh.
- `_resume_agent_with_modify`: 同样优先 live tmux + `agent_continue`; `--resume` spawn 是 fallback.
- Kill 按钮 → `_active_hud_session_tmux.pop(sid)` 显式清.
- **Measured 47.7% wallclock 降幅** on follow-up turn.

**P1.1 R-3 ripout (C-33)**:
- 删除: `_advance_task` / `_summarize_step_for_history` / `_write_step_receipt` / `_execute_remaining_no_receipt` / `MAX_TASK_ROUNDS` / `_summarise_subtask_for_history`.
- 新增: `_replan_with_feedback` — 严格 one-shot router re-plan with feedback. 用于 Modify-on-simple-path + `ResumeFailed` fallback.
- Router prompt 删除 MULTI-STEP / FREE-FORM-FEEDBACK sections. `task_continues` / `next_step_hint` 从输出 schema 删除. `_validate_plan` 强制 `task_continues=False`.
- `pending_previews` 不再带 `task_history`. 索引 `tasks_active` 同步清.

**P1.4 Insight Engine (C-34)**:
- 新模块 `cortex/insight_engine.py` (`InsightEngine`, `Insight`, `Provider` 类型, `upcoming_reminders_provider` 实现).
- 启动: `serve()` instantiate + `start()`. 默认 OFF.
- Surface: `hud_show` only (无 options). `_insight_kind` 字段在 payload 里方便 web 端 styling.
- 冷却: per-insight `cooldown` + global `GLOBAL_COOLDOWN_S=600`.
- Dev 端点: `/api/dev/insight_tick` 强制一次 tick.
- `applescript_reminders.list` 升级返回 ISO 8601 `due` 字段.

**P0.3 per-session cost (C-35)**:
- `current_session_id` ContextVar (sessions.py). `_handle_user_invoke` + `Distiller._run` 调用 `set()`.
- `llm_cache._emit` 读取 ContextVar 注入 `session_id` 到 info dict.
- `cortex.main` 包装 `record_llm_call` 把 LLM 记录 forward 到 `sessions.append(kind='llm_call', ...)`.
- 索引 entry 新字段: `llm_latency_ms`, `llm_by_purpose: dict`, `n_tool_uses`, `total_wallclock_ms`, `archived: bool`.
- 索引 bump 触发器扩展: 增加 `card_surfaced / agent_completed / llm_call`.
- Web `Sessions.tsx` 列表行 + 详情 header 都 surface 这些字段.

### Diff to existing constraints

- **C-9/C-10 (HITL preview)**: 不变；Insight Engine 的 hud_show 因为不是 side-effecting 也不需要 HITL.
- **C-22 (always-on mic per card)**: 不变；现在适用于所有 preview_action 卡片，包括 distiller 提议的卡片.
- **C-25 (visible process)**: 强化——`reusing_agent` / `distiller_quiet` / `distiller_proposing` / Insight tick progress 都 visible.
- **C-28 (3-button)**: 强化——确认 Insight Engine surface 是无按钮的 hud_show 而非 preview_action (C-34).
- **C-31 (distiller 后台触发)**: 强化——加了 `force_run()` + `/api/dev/distill_now` 但默认仍只在阈值/冷却后自动触发.

### Open Questions

- **OQ-R6-1**: tmux TTL 设了 30 min. 这是猜的. 实际使用一周后看 (a) 一个 session 内连续 turn 间隔通常多久，(b) 超过 30 min 后用户复用率有多高，调阈值.
- **OQ-R6-2**: 进入 `archived` (>7 天) 的 session 现在只是 UI 过滤. 是否要正经搬到 `_system/sessions/archive/YYYY-MM/` 子目录？短期没必要；只读的归档子目录是长期方案 (>1000 sessions 后再考虑).
- **OQ-R6-3**: P3.1 (collapse Tool Agent into Cortex) — 时机？当 (a) tool-agent IPC 成为可观察的延迟来源 (现在不是), 或 (b) launchd 双进程管理出 bug 频次升高 (现在没出), 才开工. 现在的 cost 是一个 WSS hop ~2ms; 不值得.

---

## Revision 7 — 2026-05-26: Glass v2.1 pivot — 裸机 (bare-metal) replaces CXR-L

**Status**: confirmed by Zack; code on branch `pivot/baremetal-v2.1` in `Constellation-Glass`.

完成 Phase 3b.1–3b.4 (CXR-L 桥接版本) 后发现三处根本错误，触发 Glass 客户端架构整体重设计。

### 触发因素

1. **CXR-L SDK 是手机端 SDK，不是眼镜端**. v1.0.1 官方文档（`developerdoc.rokid.com/sdk`，2026-05-07）首句明示 "CXR-L SDK 运行在手机端". 我们的 `Constellation-Glass` 目标是装在眼镜上的 HUD app，应走 **裸机 (bare-metal)** 路径 —— 直接装到眼镜 Android Go 系统上，不通过 Rokid AI App 桥接.
2. **InstructSdk 依赖 Sprite 语音助手长开**. 官方 doc: "指令触发需要用户打开眼镜设备'设置'中'语音助手激活'开关". 这与"能效是项目第一指标"的新约束冲突.
3. **Rokid Glasses 物理输入完全暴露**. `reference/rokid-glass/bare-metal-docs/01-key-events.md`: 系统以 `ACTION_SPRITE_BUTTON_*` + `ACTION_TWO_FINGER_*` 有序广播形式投递按键事件，`BroadcastReceiver` 可在 Service 里直接接，无需 Activity 在前台. 物理键覆盖所有交互需求.

### 新约束（追加到 §8）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-36** | **Glass 客户端走裸机路径，不用 CXR-L AAR / Rokid AI App / AuthorizationHelper**. App 直接装到眼镜，标准 Android Go + Android `AudioRecord` + Activity 渲染 HUD. | 见 [reference/rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md] + Zack 决策 2026-05-26. |
| **C-37** | **能效是 Glass 端第一指标**. 后台不长开 mic; 无任何"wake word 监听"流程; mic 只在用户主动按物理键后开启; 15s hard cap 自动关闭兜底; WSS keepalive 15s 但 update-rate ≤ 4Hz; 显示 panel 在 IDLE 状态全暗. | "能效是这个项目最重要的第一指标". |
| **C-38** | **物理按键是 Glass 主输入路径**. 单击=Approve/进 Listening; 长按=Modify/wake; 双击=Kill (系统占用为返回，不可拦截); 双指前/后滑=scroll. 不依赖 InstructSdk / Sprite 语音助手. Halo Ring 为 optional 增强，缺席不影响功能. | "InstructSdk 一起死...物理键完全够". |
| **C-39** | **`reference/` 是 SDK 与官方文档的本地缓存，gitignore 屏蔽大文件，但 `reference/rokid-glass/bare-metal-docs/` + `reference/INDEX.md` 入库**. 任何 Glass 相关设计/实现争议先查 `reference/`. | 本次会话产出 1.1 GB SDK 镜像 + 5 篇本地整理的官方裸机文档. |
| **C-40** | **手机/眼镜 build 严格通过 Gradle productFlavor 隔离**. `glass` flavor: AudioRecord ChannelMask=0x6000FC + SystemKeyReceiver + GlassHudActivity. `phoneDebug` flavor: 标准 mono AudioRecord + SYSTEM_ALERT_WINDOW overlay + 通知按钮模拟输入. 共享 core 代码（state machine / WSS / cookie auth / styled runs）必须零平台依赖. **Phone 端只用于验证协议与状态机，不代表生产行为**. | 用户要求 "把 debug 用的眼镜端跟手机端分开". |

### 实施影响（落地于本次会话）

**新文档**:
- `GLASS-CLIENT-DESIGN.md` v2.1 (rewrite; v2.0 保留为 `.bak`).
- `MIGRATION-PLAN.md` (详细迁移步骤).
- `reference/INDEX.md` + `reference/rokid-glass/bare-metal-docs/` 5 篇.

**Glass 端代码 (Constellation-Glass on branch `pivot/baremetal-v2.1`)**:
- 删除: CXR-L AAR dep, `HudRenderer`, `SelfViewJson` 等 customView 渲染层, `TokenStore`, Rokid auth 流程.
- 新增: `HudPlatformAdapter` / `AudioCapture` / `InputHandler` 接口; `glass/` flavor (GlassAudioCapture 0x6000FC + SystemKeyReceiver + GlassHudActivity); `phoneDebug/` flavor (PhoneAudioCapture + DebugInputController + PhoneDebugHudSurface).
- StateMachine v2.1: 物理按键路由 (`handlePrimaryClick` 等), 15s mic hard cap, Insight TTL 自动关闭, 直接 emit `user_decision` 帧 (跳过 voice 通道).
- ScrollWindow 接入 GlassHudActivity card body viewport.

**Cortex 端**:
- 默认 `WHISPER_MODELS_DIR` 从 `/tmp/whisper-models` → `~/constellation/whisper-models` (macOS 自动清理 /tmp 会丢模型).
- 其余无变更 (协议 + Level 2 partial 转写均保留).

### Diff to existing constraints

- **C-22 (always-on mic per card)**: **撤销，由 C-37 + C-38 替代**. v2.1 mic 严格"用户主动开启 + 15s 自动关闭". CARD 的 modify 仍由 server 发 `mic_open` 触发但只在用户长按物理键发出 Modify 决策后才发.
- **C-25 (visible process)**: 不变.
- **C-28 (3-button)**: 不变, 但物理输入路径变了 (单击/长按/双击 vs. 之前的 ring/voice).
- **C-31 / C-34 / C-35**: 不变 (cortex 侧不变).

### Open Questions

- **OQ-R7-1**: GlassAudioCapture 8 通道 deinterleave 是否过滤 noise 足够好，还是需要在 cortex 端再叠一层 RNN-NS? 等真机 + 真实环境测.
- **OQ-R7-2**: GlassHudActivity 用 Android View 而非 Compose（Go 内存约束）. 字号 / 行距 / wrap-chars 都需要真机调（当前 `cardBodyWrapChars=28` 是估值）.
- **OQ-R7-3**: 双击系统返回会 finishAffinity 退到 launcher 还是仅 finish current Activity? 真机验. 取决于 Rokid Glasses 系统的 KEYCODE_BACK 默认行为.
- **OQ-R7-4**: 物理键单击在 IDLE 时直接 startListening — 但 streamId 是 fresh `fresh_<ts>`，cortex 侧需要 audio_end 后做 fresh user_invoke 而不是 modify decision. 当前 cortex code 已经做了此分支（`audio_end.intent="fresh"`），但路径没真机端到端测.
- **OQ-R7-5**: 屏幕 480×640 portrait, 但 GlassHudActivity 用了 Theme.Constellation.Hud 透明全屏. 实际渲染像素映射到 JBD4020 micro-LED panel 是 1:1 还是有 scale? 需要真机测.

### 待办（推到下个 phase）

- **3b.5 真机部署 + 功耗 profile**: 需要专门的 Rokid 开发线 (普通充电线没数据通道).
- **Halo Ring profile push 重做**: stub 还在; 优先级低 (物理键已经覆盖).
- **App settings UI (§2 in `ui-mockup.html`)**: 没动. 优先级低.
- **真机验证 phoneDebug 闭环**: protocol 层已验, 但物理按键路径要等真机.

---

## Revision 8 — 2026-05-26 (EOD): Glass UI 框架 + 能效原则 + 协议 gap 修复

**Status**: confirmed by Zack; code on branch `pivot/baremetal-v2.1` in `Constellation-Glass` (commits `63e2205` → `91622c6`, 8 commits over P1.6 + P1.6b).

### 触发因素

P1.6 (GlassHudActivity 视觉迭代) 进展中触发三件事被显式问 + 显式定:
1. **UI 框架决策**: Views 还是 Compose? Halo Ring 已经全 Compose; @Preview 是 P1.5 真机到手前唯一可视化路径.
2. **能效边缘条件**: AudioRecord 开着不读的 idle 功耗未知 — 若高需 eager close/reopen; 接受 ~200ms 冷启动延迟? 
3. **若干小判断**: 户外 HBM 不支持是否做兜底? IMU 头部姿态做辅助唤醒?

P1.6 端到端测试又触发 P1.6b 协议 gap 发现: Cortex 对 simple-path 信息响应发 `hud_show` Command, 但 glass-shaped 翻译只覆盖 insight, 不覆盖普通 info card —— 用户在 Thinking 状态卡死, 看不到结果.

### 新约束（追加到 §8）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-41** | **Glass HUD 渲染层 = Jetpack Compose + `AnnotatedString` per-run styling**. 共享 Composable 在 `app/src/main/.../hud/composables/`; `GlassHudActivity` 用 `setContent { AppStateHud(snap) }` 作 Compose host; `PhoneDebugHudSurface` 在 SYSTEM_ALERT_WINDOW 内同一 Composable + 4:3 simulator box. `HudSnapshot` 数据类提到 main/ 满足 C-40 (shared core 零 flavor 依赖). 单色绿主题, 不引 Material3. | "Halo-Ring 已经全 Compose...沿用同一栈" + "先文档更新, 然后依次实现并依次深入测试". |
| **C-42** | **AudioRecord 走 eager close/reopen 模式**. IDLE 时 AudioRecord **不**保持打开 (零 idle 功耗); CLICK 触发时新建 + start + read ≤15s + stop + release. 接受冷启动 ~200ms 延迟代价. | "不怕冷能启动, 能效最重要". |
| **C-43** | **不做户外 HBM 兜底, 不集成 IMU**. JBD4020 不支持 HBM = 强光下可读性靠用户自行调亮度 (设计层不开二级亮度策略). IMU 头部姿态作为辅助唤醒被拒 (能耗 + 漂移 + 用户头动作分类调参代价). 维持物理键 (C-38) 作为唯一主交互路径. | "完全不用考虑户外可读性, 亮度我会自己调. IMU 不用, 能效第一, IMU 太费电". |

### 协议契约修正（影响 INTERFACE-CONTRACTS）

Cortex 对 glass peer 的 frame 翻译表 (在 `_send_command()` 中) **新增一行**:

| Legacy `Command.kind` | Glass-shaped output (when peer accepts) |
|---|---|
| `preview_action` | `card` (options 非空 → mic_open + approve/modify/kill 默认) |
| `hud_show` (有 `_insight_kind` marker) | `insight` (TTL countdown, 无 buttons) |
| **`hud_show` (无 marker, 之前漏)** | **`card` with `options=[]` (info-only, footer = "double-click to dismiss · auto-close")** |

**Glass 侧**: `CardHud` composable 检测 `cardOptions.isEmpty()` 切换 footer 文案. 已添加 `@Preview` (5b) "Card — info only (no buttons)" 作为常驻验收页.

详见 [INTERFACE-CONTRACTS](../server/INTERFACE-CONTRACTS.md) (P1.6b 已落地补丁) + `Constellation-Server` commit `83bba42` + `Constellation-Glass` commit `91622c6`.

### Diff to existing constraints

- **C-37**: 不变, 但 **C-42** 是 C-37 的具体实施细则 (eager close 是落地形态).
- **C-38**: 不变.
- **C-40**: 强化, **C-41** 是 C-40 在 HUD 层的具体形态 (共享 Composable + 各 flavor host).
- **C-31 (3-button)**: 仅"actionable card"路径不变. 新增**info-only card 路径** (无 buttons), footer 退化为"double-click to dismiss · auto-close". 用户语义上不能 approve/modify/kill — 信息只读 + TTL 自闭.

### Open Questions

- **OQ-R8-1**: P1.6 在 OnePlus 9 (`854afb6b`) 上验过 Compose + simulator. 真机 Rokid Glasses 上 ComposeView 渲染性能能否撑 4Hz refresh? 内存占用增量是否可接受? 等 P1.5.
- **OQ-R8-2**: C-42 eager close 模式下用户连续短促按键 (CLICK→CLICK 间隔 < 200ms) 是否需要 debounce 否则连续 AudioRecord allocate? 当前 StateMachine 单击进 Listening 后下一次 CLICK 直接 audio_end, 不会重新 allocate — 已自然 OK.
- **OQ-R8-3**: 真机字号 / cardBodyWrapChars / densityDpi 校准 (P1.5).

### 实施影响（本次会话落地）

**新文档**:
- `docs/glass/GLASS-SDK-REFERENCE.md` (R08 Rokid Glasses 裸机 SDK 速查; 含 audio mask / key broadcast 表 / display 热级表 / 真机验证清单).
- `docs/glass/P1.6-COMPOSE-MIGRATION.md` (7-phase 实施 + 验证记录).

**文档归类整理**:
- 22 顶层 .md → `docs/{constitution,server,glass,cross-device,roadmap}/`. 删 .bak 备份. 修复 14 处 broken code refs.
- R08 术语 sweep: 仅 2 处真正错引用 (P1.6-COMPOSE-MIGRATION.md:252 + COMPONENT-DESIGN.md:18). 大多数 R08 mention 是合法的 (ring 代号 + R08-dev/ 路径).

**Constellation-Glass on branch `pivot/baremetal-v2.1`**:
- P1.6 commits A–F: 加 Compose deps (Kotlin 2.0.20 Compose Compiler plugin path), `HudTheme.kt` 集中常量, `RunStyledText` + `AppStateHud` 6 个 state Composable + 8 `@Preview`, `GlassHudActivity` Compose 化 (净 -167 行), phoneDebug 升级为 Rokid Glasses simulator (`OverlayHostOwner` 给 SYSTEM_ALERT_WINDOW 内 ComposeView 提供 lifecycle owner).
- P1.6b commit `91622c6`: `CardHud` 检测 `cardOptions.isEmpty()` 切换 footer.

**Constellation-Server**:
- `83bba42`: `_send_command` 对非 insight `hud_show` 翻译为 glass `card` with `options=[]`; `emit_card` 修复 truthiness bug (`options or [...]` 把 `[]` 当默认了, 改 `... if options is None else options`).
- `8b37888`: 把 HANDOFF 已经记载但未提交的 whisper 模型路径迁移 (`/tmp` → `~/constellation/whisper-models`) 提交完毕.

### 待办（推到下个 phase）

- **P1.5 真机部署**: 仍等 Rokid 专用开发线. 真机到手后:
  - 校 `HudTheme.kt` 各 sp/dp/wrapChars 数字
  - 验 `setChannelMask(0x6000FC)` 在我们 firmware 上不被拒
  - 测 AudioRecord eager close 模式实际能耗对比
  - 测 ComposeView 在 Rokid Glasses 上的 attach / 内存
  - 跑 [GLASS-SDK-REFERENCE §9](../glass/GLASS-SDK-REFERENCE.md) 的 10 项验证清单
- **Cortex 协议层**: 完整列出 Cortex 还可能发但 Glass 不识的 frame kind, 看是否还有类似 P1.6b 的隐藏 gap.

---


## Revision 9 — 2026-05-26 (EOD): In-app settings UI + Shortcuts + Camera + QR-pair login

**Status**: confirmed by Zack; code shipped across Constellation-Glass (`7cd9261` → `c179a42`), Constellation-Server (`83bba42` → `879587c`), Constellation-Console (`737819f`). Glass APK installed to real Rokid Glasses (<glass-serial>) for first-time hardware contact — LoginScreen renders correctly on the 480×640 panel @ density=240.

### 触发因素

P-app sequence: A (Compose NavHost + Connect screen + EndpointStore + Service handoff) → B (Cortex `/api/ping`) → C (AboutScreen) → D (Shortcuts CRUD + UI + Halo Ring plugin protocol completion) → Q (Camera + QR login). Final state:

- Full settings UI runs **on the eyewear panel** (per Zack 2026-05-26: "不可能 configure on phone, 就用现在的 HUD, 就用详细的应用内设置界面")
- Shortcuts are **one-tap fire-and-forget** (preset prompt + optional photo; no mic — explicit user clarification 2026-05-26 EOD)
- **QR-code pairing** replaces password-on-eyewear (无键盘的眼镜上根本输不进密码)
- Camera path also serves shortcut photo capture (`whats-in-front?` etc.)

### 新约束（追加到 §8）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-44** | **Shortcut = 一键 fire-and-forget**：preset prompt + optional photo，**没有 mic 字段**。若一个触发想开 mic，那就不是 shortcut，是普通的 voice invoke。 | "shortcut 就是可能点一下戒指或者按下某个快捷键，它自动填一段 prompt 发过去...我不用说话". |
| **C-45** | **CameraX 拍照走 downscale-and-recompress**：1024px longest edge + JPEG q=80。Headless（无 preview surface）；Service-mediated（不在 BroadcastReceiver 里跑 — 受 ~10s budget 限制）；FGS type 必须含 `camera`（Android 14+ block 后台 camera open without it）。 | 1.7MB → 70KB observed；user pushed for compression. |
| **C-46** | **眼镜端登录走 QR pairing，不走密码键入**：Web Console → /about 渲染 `{endpoint, cookie_name, cookie_value}` JSON QR；眼镜 `LoginScreen` SCAN QR 扫一下 → 直接进 Main。第一次登录后 cookie 永久 (per Revision 8 C-41 follow-up — no logout)。 | "眼镜扫QR码吧，QR码内部就是密码的字符串". |
| **C-47** ✅ landed 2026-05-26 EOD | **Cortex dispatcher 携带 image 不解释**：当 `user_invoke` 携带 `image_b64`，classifier/router 只读 `text` 做路由决策。image 流向**仅**由路由决定 — `cortex.server._VISION_AWARE_TOOLS = {"vision_describe"}` 是白名单门；router 路由到名单内的 tool 时 dispatcher 才把 image 注入到 args 里 (key=`_image_b64`)，其他 tool 永远拿不到。**Default-off** 是显式承诺 (无 surprise vision 费用)。Cortex `83bba42` + `1250f74` + `948bad6`；E2E 验证 OnePlus 9 真摄像头照片 → Claude vision → 干净 prose 回到 HUD card。 | "由 dispatcher 根据 prompt 来决定这个图像要不要递给下一个工具...Dispatcher 本身应该也没必要知道这个图像" + "默认绝对是不可能默认调用微认的". |

### 协议契约修正（影响 INTERFACE-CONTRACTS）

| Glass → Cortex frame | 新增字段 |
|---|---|
| `user_invoke` | `image_b64` (optional) — base64 JPEG, ≤~100 KB after Glass-side downscale. |

| Cortex → Glass frame | 不变 |

### 应用层新协议：Web Console ↔ Glass via QR

Web Console emits `GET /api/auth/pair_qr` (auth-gated, returns JSON
`{endpoint, cookie_name, cookie_value}` where endpoint is derived from
request Host header). Glass scans, parses, persists; no other endpoints
required on the Console / Edge side.

### Diff to existing constraints

- **C-37 (energy first)**: 不变. Camera open in Service (FGS) keeps it bounded; idle drain = 0 (camera closed when no shortcut firing).
- **C-38 (physical key primary)**: 不变. Shortcut fire from Halo Ring gesture is an *alternative* input modality; physical-key flow is intact.
- **C-40 (flavor split)**: 不变. CameraCapture + QrScanner live in `main/` (shared); both flavors get them.
- **C-41 (Compose only)**: 不变. CameraX preview hosted via AndroidView in Compose works correctly.
- **C-31 (3-button)**: 不变 — shortcuts bypass the 3-button decision phase (no card, fire直接走). The response card (if any) still follows the 3-button contract.

### Open Questions

- **OQ-R9-1**: Rokid Glasses 是否有 GMS? ML Kit Barcode 当前用 `com.google.mlkit:barcode-scanning:17.3.0` Play Services 路径; 若无 GMS 需切 bundled-model variant (+~2 MB APK). Q.8 真机验.
- **OQ-R9-2**: Rokid Glasses 摄像头的物理上方按钮是系统 occupied (拍照/录像). 我们的 CameraX 后台 open 是否会与系统拍照功能冲突? Q.8 真机验.
- **OQ-R9-3**: `cardBodyWrapChars=42` 在 Rokid Glasses 320 dp 内容宽 × sans-serif 上的实际字符容量? 等真机 logcat 测量.

### 实施影响

**新文档**:
- `docs/glass/IN-APP-UI-DESIGN.md` (v2 — eyewear-resident, key-driven; v3 — Phase Q + verification log)
- `docs/glass/P1.6-COMPOSE-MIGRATION.md` (历史，仍保留)
- `twin-seed/skills/shortcuts.md` — shortcut schema + 3 seed

**Constellation-Glass**:
- 完整 in-app settings UI in `app/src/main/.../app/` (NavHost) and `app/src/main/.../app/ui/` (Compose screens) — 5 screens
- `EndpointStore` (DataStore-backed runtime-editable endpoint)
- `camera/CameraCapture.kt` + `camera/QrScanner.kt`
- `ShortcutsClient` + `ShortcutsLocalCache` + `ShortcutFireClient`
- `HaloActionsProvider` returns Core + Shortcuts cursor
- `HaloTriggerReceiver` routes core actions + shortcut_* triggers
- `ConstellationService` exposes static `startListening` / `killActive` / `fireShortcut` helpers (volatile `instance` ref)

**Constellation-Server**:
- `cortex/shortcuts_store.py` + `/api/shortcuts` CRUD
- `cortex/http.py` `/api/ping` lightweight liveness probe
- `_send_command` fixes (P1.6b `hud_show` translation, `emit_card` truthiness)
- `agent-finished-card` body prefers `structured.summary` over raw `result_text`

**Constellation-Console**:
- `edge/console_edge/auth.py` `/api/auth/pair_qr` endpoint
- `web/src/routes/About.tsx` — QRCodeSVG render of pair bundle
- `App.tsx` + `Layout.tsx` `/about` nav entry

### 待办（推到下个 phase）

- ~~**Q.4.5 Cortex vision passthrough** (C-47 实施)~~ ✅ landed 2026-05-26 EOD — Cortex `83bba42 + 1250f74 + 948bad6`; vision_describe adapter + classifier prompt + router catalog + E2E verified on OnePlus 9 real camera shot.
- ~~**Q.8 Phase Q deploy + Rokid Glasses E2E**~~ ✅ landed 2026-05-26 EOD — Edge + web deployed; OnePlus 9 + Rokid Glasses 两端都通过 QR 扫码完成配对 (无密码键入); Rokid Glasses 端 cookie + endpoint 持久化跨重启验证通过。残余项：Rokid Glasses 当前 WiFi 无法解析 `edge.example.com` (Edge 公网域名)，需联网/Tailscale 配置才能完整跑通 WSS→Cortex 链路。
- **Halo Ring profile push** (P1.7) — still optional; not blocking.

---

## Revision 10 — 2026-05-28: HUD overlay pivot + camera-gate finding

**Status**: confirmed by Zack ("HUD 不要充满一个屏幕, 要让 HUD 真的是 HUD. 你要申请打开这个悬浮在其他应用上面的 overlay 权限"); code shipped Constellation-Glass `c0f8836` → `591e1d9`. Verified on real Rokid Glasses (`<glass-serial>`) — HUD card floats above Rokid Sprite launcher; first time the HUD is visually consistent with what an AR HUD should be on real hardware.

### 触发因素

Real-device EOD 2026-05-27 + start-of-day 2026-05-28: Zack wore the eyewear and noticed
1. 界面比预想大很多 (字号过大);
2. HUD 重合在应用上层 = mechanically owns the panel even though most pixels were AR-transparent — the wearer couldn't see launcher / system surfaces behind it the way a "real" HUD should;
3. HUD 没有 card visual — just bare text on the panel; lacks any "this is an overlay" affordance;
4. 屏幕熄屏后 HUD 更新不点亮屏幕 (~10s auto-lock).

These all flowed from the pre-Rev10 architecture decision (P1.6 Phase E) to use a fullscreen transparent Activity (`GlassHudActivity`) as the HUD host. The Activity *was* transparent, but it mechanically *owned* the panel and blocked everything behind it from being focusable; on the AR side the wearer's eye saw HUD pixels only.

### 新约束（追加到 §8）

| 编号 | 约束 | 用户原话依据 |
|---|---|---|
| **C-48** | **HUD = system-level floating overlay, NOT a fullscreen Activity**. Host = `SYSTEM_ALERT_WINDOW` (TYPE_APPLICATION_OVERLAY) on glass flavor; `WRAP_CONTENT` × `WRAP_CONTENT` so card sizes to content. Content wrapped in `CardFrame` Composable (rounded 12dp corners + dim green border + dark fill that is transparent on JBD4020 unlit pixels). Card content-fit height (short content = short card; bounded at `HudTheme.cardMaxHeightDp = 380dp`). User must grant SYSTEM_ALERT_WINDOW permission via Settings; we surface this at first launch. **`GlassHudActivity` deleted**. | "HUD 不要充满一个屏幕, 要让 HUD 真的是 HUD. 你要申请打开这个悬浮在其他应用上面的 overlay 权限, 然后真的悬浮在系统级的最上层." + "不能是光秃秃的文字, 应该用一个设计好看卡片给它框起来" + "按需高度变化的, 短的就短一点". |
| **C-49** | **Wake-on-while-visible**: SCREEN_BRIGHT_WAKE_LOCK + ACQUIRE_CAUSES_WAKEUP acquired on `Idle → {Listening, Thinking, Card, Insight, Offline}`, released on `→ Idle`. 5-minute hard ceiling for safety. Cards have 30s+ TTLs; ~10s auto-lock would otherwise cut card view mid-read. C-37 (energy first) is honored — wake lock only while HUD has visible content; once Idle (HUD empty) panel can auto-lock normally. | "更新时点亮屏幕 (现在默认10s熄屏)". |
| **C-50** | **Type scale calibrated for real Rokid Glasses panel** (density 240 hdpi, content area 320×426 dp): title 14sp, body 11sp, meta 10sp, footer 9sp. Side padding 10dp, top padding 8dp (inside CardFrame). `cardBodyWrapChars=40` (down from 42); `cardBodyVisibleLines=8` (up from 6 since smaller font fits more). Numbers will be tuned further as real cards render. | "界面比我预想中大多了, 所以整个字体什么的都能变小一些." |

### 协议契约修正

无 — render-layer-only redesign. Cortex emits the same frame kinds; the
StateMachine handles them the same way. Only Glass-side host + visual changed.

### Diff to existing constraints

- **C-37 (energy first)**: 不变. **C-49** is a specific implementation: wake lock only while HUD visible, not blanket.
- **C-38 (physical key primary)**: 不变. CARD double-click still maps to system back / Kill.
- **C-40 (flavor split)**: 强化. With overlay model, `glass` + `phoneDebug` now use the same `SYSTEM_ALERT_WINDOW + ComposeView` pattern; the only difference is the phoneDebug overlay wraps the same `AppStateHud` in a "GLASS SIM" simulator frame. `OverlayHostOwner` lifted from `phoneDebug/` to `main/`.
- **C-41 (Compose only)**: 不变, reinforced. Single Compose tree across both flavors via shared `CardFrame` + `AppStateHud`.
- **C-43 (no outdoor HBM fallback / no IMU)**: 不变.
- **C-44 / C-45 / C-46 / C-47 (Phase Q + vision)**: 不变 protocol-wise. CameraX usage now blocked on real eyewear (see OQ-R10-1 below).

### Open Questions

- **OQ-R10-1**: **YodaOS camera gate** — CameraX `bindToLifecycle()` fails with `ERROR_CAMERA_DISABLED` on real Rokid Glasses regardless of CAMERA runtime permission, FOREGROUND_SERVICE_CAMERA declaration, and explicit `ServiceCompat.startForeground(..., FOREGROUND_SERVICE_TYPE_CAMERA)`. Same code works on OnePlus 9. Need to find the vendor-level mechanism (Sprite exclusive reservation? `com.rokid.permission.CAMERA`? non-standard camera ID? top-temple camera button must be system-launched?). Tracked in TODO.
- **OQ-R10-2**: SYSTEM_ALERT_WINDOW permission UX — currently we don't surface a permission grant flow when first launching on a fresh device. On Rokid Glasses our overlay appeared to work without explicit grant (vendor pre-grants? auto-grant for first-party?). Need to confirm and either document or add a fallback path.
- **OQ-R10-3**: WakeLock duration ceiling — 5min is safety. If a CARD lives longer than 5min (e.g. user reading a long Cortex agent output), panel auto-locks mid-view. Probably fine — user can dismiss + re-engage; pathological case. Revisit if seen in practice.

### 实施影响（本次会话落地）

**Constellation-Glass commits**:
- `c0f8836` HUD redesign A+C (smaller fonts + CardFrame composable)
- `830d884` HUD redesign B+D (SYSTEM_ALERT_WINDOW overlay + wake-on-while-visible)
- `b5cdb97` Q.4.5b HTTP retry helper + CardHud footer copy fix
- `591e1d9` ConstellationService FGS types explicit at startForeground (Android 14 defense-in-depth)

**Constellation commits**:
- `a35a843` TODO: Rokid Glasses WiFi auto-disable workaround note

**Deleted**:
- `app/src/glass/.../glass/hud/GlassHudActivity.kt`
- `Theme.Constellation.Hud` style from `themes.xml`
- Old "fullscreen transparent Activity" architecture as a whole

**New files**:
- `app/src/main/.../hud/composables/CardFrame.kt`
- `app/src/glass/.../glass/GlassHudOverlay.kt`
- `app/src/main/.../net/HttpRetry.kt`

**Moved**:
- `OverlayHostOwner.kt` from `phoneDebug/` to `main/` (now used by both flavors)

### 待办（推到下个 phase）

- **OQ-R10-1 投入投入**: 真正解决 YodaOS camera gate (read more Rokid bare-metal docs; ask Rokid developer support; try alternative camera APIs).
- **OQ-R10-2 SYSTEM_ALERT_WINDOW permission flow**: 给 fresh-install 加 grant 引导.
- **Halo Ring profile push** (P1.7) — still optional; not blocking.

---
