# Constellation `reference/` — SDK 与文档总索引

**Updated**: 2026-05-27
**Purpose**: 把跟**当前 Rokid Glasses（用户这款）开发**相关的 SDK 源码、官方文档、参考样本拉到本地，作为 [`GLASS-CLIENT-DESIGN.md`](../docs/glass/GLASS-CLIENT-DESIGN.md) + [`GLASS-SDK-REFERENCE.md`](../docs/glass/GLASS-SDK-REFERENCE.md) 的事实依据。

> ## ⚠ 设备型号锚点（避免后续 agent 又踩错）
>
> 用户实物 = **Rokid Glasses (the AR Lite eyewear)**：
> - 屏：JBD4020 micro-LED, **480×640 portrait**, monochrome green
> - 系统：**YodaOS-Sprite (Android 12 Go)**
> - SoC：Qualcomm 8250 + NXP RT600 DSP
> - mic mask：`0x6000FC` (8-ch with iFlytek front-end)
>
> **NOT** these older Rokid products (已从本地删除以避免误导)：
> - Rokid Glass 1 (`Rokid/glass-docs`) — Amlogic, Android 8
> - Rokid Glass 2 (`RokidGlass/glass2-docs`) — Amlogic S905D3, **1280×720 landscape, Android 9.0**, 320dpi
> - Rokid Dock / AR Studio / Air3S Pro (`UXR-docs`) — XR Studio + Unity SDK, 桌面/穿戴外形
>
> 历史 R-7 doc-set 在这些被误用过；终止使用并清掉本地副本，**2026-05-27**。

> **核心结论**：Constellation-Glass 走 **裸机开发** 路径，不挂 CXR-L SDK。
> 详情见 [rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md](rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md)。
> （但 CXR-L 仍可能作为"phone-bridge 网络共享"备选方案重评估——见
> [docs/glass/](../docs/glass/) 中的网络方案讨论。）

---

## 重要：先读

如果你刚加入这个项目，按以下顺序读：

1. **[rokid-glass/bare-metal-docs/](rokid-glass/bare-metal-docs/)** ← 我们要走的路径（裸机开发）
   - `00-overview.md` — 总述（YodaOS-Sprite + 480×640 panel + 物理拓扑）
   - `01-key-events.md` — 系统按键广播 + KeyEvent
   - `02-audio-recording.md` — AudioRecord + ChannelMask 0x6000FC
   - `03-developerdoc-sdk-page.md` — 各 SDK 总览
   - `04-cxrl-vs-baremetal-decisive.md` — 路径选择
2. **[rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/](rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/)** ← YodaOS 硬件文档（audio.md / display.md / thermal.md / speech-sdk.md 必读）

---

## 一、Rokid Glass SDK（眼镜端 — 当前 Rokid Glasses）

### `rokid-glass/bare-metal-docs/` — **我们要走的路径**
本地整理的官方裸机开发文档（从 `custom.rokid.com` 抓取，因为是 SPA 单页应用，原 URL 直接 fetch 会得到空内容）。

- 屏幕：480×640 pixels（竖屏 4:3）
- 系统：YodaOS-Sprite 基于 Android Go (Android 12 base)
- 按键事件以 BroadcastReceiver 形式接收（Service 也能拿），但**注意 §3.6** Sprite AssistServer 在 WindowManager KeyEvent 层平行劫持（侧键 → 自动拍照）— 2026-05-27 发现
- AudioRecord 用 `ChannelMask=0x6000FC`，取通道 0（算法后音频）

### `rokid-glass/rokid-docs-buildwithfenna/` — 社区整理的 Rokid 内部文档（GitHub: buildwithfenna/rokid-docs）
**最有价值的部分是 `yodaos/docs/`**——固件层反编译文档：
- `hardware/audio.md` — 4 路 mic 阵列、AEC/NR 详情
- `hardware/display.md` — JBD4020 panel、thermal-fps 表
- `hardware/thermal.md` — 热管理
- `hardware/sensors.md` — IMU/PPG/光传感器
- `hardware/product-variants.md` — 硬件版本差异
- `platform/speech-sdk.md` — **NXP RT600 协处理器、iFlytek 前端、Rokid KWS**（audio 路径的硬件真相）
- `apps/cxr-service.md` — eyewear-side CXR service（系统级，处理跟 Rokid AI APP 的桥接）
- `apps/sprite-launcher.md` — Sprite launcher
- `apps/sprite-assist.md` — Sprite assist（**就是 §3.6 平行劫持侧键的那个 assistserver**）
- `cxr-l/api-reference.md` — CXR-L v0.0.1 反编译参考（**已过时**，v1.0.1 API 不同；trust `cxrl-sample-android` 反推）
- `cxr-m/`、`cxr-s/` — CXR-M、CXR-S SDK 反编译

### `rokid-glass/cxrl-sample-android/` — CXR-L Android 官方 Sample (cxrlsample101)
Kotlin + Compose 写的 CXR-L 演示 app。**v1.0.1 真实 API 参考**：
- `app/src/main/java/com/rokid/cxrlsample/activities/audio/AudioUsageViewModel.kt` — 真实 `IAudioStreamCbk` 签名（与 v0.0.1 不同）
- `app/src/main/java/com/rokid/cxrlsample/dataBean/selfView/` — CustomView JSON schema 验证规则（gravity 不能用 top_start 等）
- `app/src/main/java/com/rokid/cxrlsample/utils/Samples.kt` — 工具

CXR-L 是**手机端 SDK**（详见 `bare-metal-docs/04`），让手机 app 通过 Rokid AI APP 桥接到眼镜。我们 Constellation-Glass 走裸机不走这条；但**如果要做"phone-bridge 网络共享"（眼镜 WiFi 关闭 + 数据走手机）**，这是核心参考。

### `rokid-glass/cxrl-sample-ios/` — CXR-L iOS Sample
Swift 写的 iOS 端 CXR-L 演示。如果做 iOS 配套 app，这是模板。

---

## 二、Rokid Mobile SDK（手机端）

### `rokid-mobile/cxrm-sdk/` — CXR-M SDK 工程（手机端，通过 BLE 直连眼镜）
手机 App 通过蓝牙跟 Rokid Glasses 直接通信的 SDK。**不经过 Rokid AI APP 中转**——比 CXR-L 更底层。Sample 演示了 BT 协议、消息封包等。

### `rokid-mobile/RokidMobileSDKAndroidDemo/` — Rokid Mobile SDK
Rokid 通用 mobile SDK，主要用于设备绑定、账号管理、固件升级触发。我们的 Cortex 不通过这个走，仅作参考。

---

## 三、Rokid Voice / Speech SDK（云端服务，不用）

我们决定 STT 走本地 whisper.cpp，不用 Rokid 云端 ASR（详见 GLASS-CLIENT-DESIGN §2.4 + SoT C-37 能效约束）。下面这些保留作为竞品 / 参考：

- `rokid-voice/RokidVoiceAISDK/` — Voice AI 安卓全链路 SDK（2021-08-05 最后更新，2024 不再维护）
- `rokid-voice/RokidVoiceAIDemo/` — 同上的 Demo 工程
- `rokid-voice/RokidAiSdkDemo/` — 早期 AI SDK 演示（2019-05-16）
- `rokid-voice/speech-python-demo/` — Python 调用 Rokid 云语音 demo（WSS + protobuf）

---

## 四、Halo Ring（用户的戒指项目）

### `halo-ring/Halo-Ring/` — Halo Ring 工程（GitHub: MRziyi/Halo-Ring）
- `Doc/02-hardware-and-protocol.md` — 硬件 + BT 协议
- `Doc/04-architecture.md` — 架构
- `Doc/11-verification-checklists.md` — 验证清单
- `Doc/12-research-and-references.md` — 研究参考
- `Doc/15-A2-spake2-tls-guide.md` — SPAKE2 + TLS

R08 = Halo Ring 的代号。我们设计文档里"Halo Ring 集成"假设的协议依据。当前 C-54 (R-12) 决策下，**Halo Ring 是 fresh voice invoke 的主入口**（侧键被 Sprite AssistServer 平行劫持），不再 optional。

---

## 五、Whisper STT

### `whisper/whisper.cpp/` — whisper.cpp 源码（GitHub: ggml-org/whisper.cpp）
Cortex 端 STT 走 `whisper-cli` 命令行工具。可参考：
- `examples/cli/cli.cpp` — whisper-cli 实现
- `examples/stream/stream.cpp` — streaming whisper（Level 2 部分转写参考）
- `models/download-ggml-model.sh` — 下载脚本
- README — 模型大小 / 性能基准

---

## 六、显示面板

### `jbd-display/` — Jade Bird Display JBD4020（暂未填充）
未在 GitHub 找到 datasheet。关键参数从 `yodaos/docs/hardware/display.md` 提取：480×640 单色绿 micro-LED。

---

## 远程仓库来源（git origin 记录 — 仅当前可用）

| 本地路径 | 远程 |
|---|---|
| `rokid-glass/rokid-docs-buildwithfenna` | https://github.com/buildwithfenna/rokid-docs |
| `rokid-glass/cxrl-sample-android` | 复制自 `R08-dev/refs/sdks/rokid/CXR-L SDK/cxrlsample101` |
| `rokid-glass/cxrl-sample-ios` | 复制自 `R08-dev/refs/sdks/rokid/CXR-L SDK/ios_cxr_l_sample` |
| `rokid-glass/bare-metal-docs` | 本地整理（从 custom.rokid.com SPA 通过 chrome-mcp 抓取） |
| `rokid-mobile/cxrm-sdk` | 复制自 `R08-dev/refs/sdks/rokid/CXR-M SDK` |
| `rokid-mobile/RokidMobileSDKAndroidDemo` | https://github.com/Rokid/RokidMobileSDKAndroidDemo |
| `rokid-voice/RokidVoiceAISDK` | https://github.com/Rokid/RokidVoiceAISDK |
| `rokid-voice/RokidVoiceAIDemo` | https://github.com/Rokid/RokidVoiceAIDemo |
| `rokid-voice/RokidAiSdkDemo` | https://github.com/Rokid/RokidAiSdkDemo |
| `rokid-voice/speech-python-demo` | https://github.com/Rokid/speech-python-demo |
| `halo-ring/Halo-Ring` | https://github.com/MRziyi/Halo-Ring |
| `whisper/whisper.cpp` | https://github.com/ggml-org/whisper.cpp |

## 已删除（2026-05-27 — 不是用户设备型号）

- ~~`rokid-glass/glass-docs`~~ — Glass 1 (Amlogic, Android 8)
- ~~`rokid-glass/glass2-docs`~~ — Glass 2 (Amlogic S905D3, 1280×720 横屏 Android 9.0)
- ~~`rokid-glass/UXR-docs`~~ — Dock + AR Studio Unity SDK (桌面 XR 设备)

如果将来出于"对比 / 历史考古"需要，可以重新 clone（仓库地址：`https://github.com/Rokid/glass-docs`、`https://github.com/RokidGlass/glass2-docs`、`https://github.com/RokidGlass/UXR-docs`），但**先确认是否真的需要**——之前已经因为字段名碰巧相似引发过误用。
