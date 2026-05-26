# Constellation `reference/` — SDK 与文档总索引

**Updated**: 2026-05-26
**Purpose**: 把所有跟眼镜端开发相关的 SDK 源码、官方文档、参考样本拉到本地，作为 `GLASS-CLIENT-DESIGN.md` 的事实依据。

> ⚠️ **核心结论**：Constellation-Glass 应该走 **裸机开发** 路径，不用 CXR-L SDK。
> 详情见 [rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md](rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md)。

---

## 重要：先读

如果你刚加入这个项目，按以下顺序读：

1. **[rokid-glass/bare-metal-docs/](rokid-glass/bare-metal-docs/)** ← 我们要走的路径（裸机开发）
   - `00-overview.md` — 总述
   - `01-key-events.md` — 系统按键广播 + KeyEvent
   - `02-audio-recording.md` — AudioRecord + ChannelMask 0x6000FC
   - `03-developerdoc-sdk-page.md` — 各 SDK 总览
   - `04-cxrl-vs-baremetal-decisive.md` — 路径选择
2. **[rokid-glass/glass2-docs/zh/](rokid-glass/glass2-docs/zh/)** ← Glass 2（R08 一代）官方文档
3. **[rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/](rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/)** ← YodaOS 硬件文档（audio.md / display.md / thermal.md / speech-sdk.md 必读）

---

## 一、Rokid Glass SDK（眼镜端）

### `rokid-glass/bare-metal-docs/` — **我们要走的路径**
本地整理的官方裸机开发文档（从 `custom.rokid.com` 抓取，因为是 SPA 单页应用，原 URL 直接 fetch 会得到空内容）。

- 屏幕：480×640 pixels（竖屏 4:3）
- 系统：YodaOS-Sprite 基于 Android Go
- 按键事件以 BroadcastReceiver 形式接收（Service 也能拿）
- AudioRecord 用 `ChannelMask=0x6000FC`，取通道 0（算法后音频）

### `rokid-glass/glass2-docs/` — Glass 2（R08 一代）官方文档（GitHub: RokidGlass/glass2-docs）
最新的 Rokid Glasses 2 文档，覆盖：
- `zh/1-system/` — 系统使用：按键键值、launcher、auto-start、系统应用清单、相机
- `zh/2-sdk/1-face-sdk/` — 离线人脸识别 SDK
- `zh/2-sdk/2-lpr-sdk/` — 车牌识别 SDK
- `zh/2-sdk/3-voice-sdk/` — **包含 InstructSdk v1.6.1**（离线语音指令）+ AccessibilityInstruct（百灵鸟无侵入式语音控制）
- `zh/2-sdk/5-ui-sdk/` — UI SDK
- `zh/2-sdk/8-imu-sdk/` — IMU SDK
- `zh/2-sdk/9-scenerecognize-sdk/` — 场景识别

⚠️ 注意：InstructSdk 的工作前提是用户在系统设置中打开"语音助手激活"开关——也就是 Sprite 长按触控板。在我们项目能效约束下**不可用**。

### `rokid-glass/glass-docs/` — 老 Glass 1 文档（GitHub: Rokid/glass-docs）
更老的 Rokid Glass 1 文档，部分内容 outdate。InstructSdk v1.1.4（vs Glass 2 的 v1.6.1）。
我们参考用，不作为权威。

### `rokid-glass/rokid-docs-buildwithfenna/` — 社区整理的 Rokid 内部文档（GitHub: buildwithfenna/rokid-docs）
**最有价值的部分是 `yodaos/docs/`**——硬件层的反编译文档：
- `hardware/audio.md` — 4 路 mic 阵列、AEC/NR 详情
- `hardware/display.md` — JBD4020 panel、thermal-fps 表
- `hardware/thermal.md` — 热管理
- `hardware/sensors.md` — IMU/PPG/光传感器
- `hardware/product-variants.md` — 硬件版本差异
- `platform/speech-sdk.md` — **NXP RT600 协处理器、iFlytek 前端、Rokid KWS**（这是 audio 路径的硬件真相）
- `cxr-l/api-reference.md` — CXR-L v0.0.1 反编译参考（**已过时**，v1.0.1 API 不同）
- `cxr-m/`、`cxr-s/` — CXR-M、CXR-S SDK 反编译

### `rokid-glass/cxrl-sample-android/` — CXR-L Android 官方 Sample (cxrlsample101)
Kotlin + Compose 写的 CXR-L 演示 app。**v1.0.1 真实 API 参考**：
- `app/src/main/java/com/rokid/cxrlsample/activities/audio/AudioUsageViewModel.kt` — 真实 IAudioStreamCbk 签名（与 v0.0.1 不同）
- `app/src/main/java/com/rokid/cxrlsample/dataBean/selfView/` — CustomView JSON schema 验证规则（gravity 不能用 top_start 等）
- `app/src/main/java/com/rokid/cxrlsample/utils/Samples.kt` — 工具

虽然我们不用 CXR-L，但这个 sample 是反推 CXR-L v1.0.1 行为的最权威源。

### `rokid-glass/cxrl-sample-ios/` — CXR-L iOS 官方 Sample
Swift 写的 iOS 端 CXR-L 演示。我们不做 iOS，仅作完整性归档。

### `rokid-glass/UXR-docs/` — UXR SDK 文档（Unity / OpenXR for Rokid AR Studio）
桌面 XR 设备（AR Studio/Max/Station/Air）的 Unity SDK 文档。**跟我们的 R08 眼镜无关**，但跟 Rokid 生态相关，保留参考。

### `rokid-glass/armazpro-module-sdk-sample/` — Armaz Pro Module SDK Sample
Unity 工程。同上，桌面 XR 设备相关，跟我们无关。**490+ MB，可清理**（如果空间紧张）。

---

## 二、Rokid Mobile SDK（手机端 — 我们不直接用）

### `rokid-mobile/cxrm-sdk/` — CXR-M SDK 工程
手机 App 通过蓝牙跟 Rokid Glasses 直接通信的 SDK。我们不走这条路（我们走"眼镜端裸机 + WSS"），但这个 sample 演示了 BT 协议、消息封包等。

### `rokid-mobile/RokidMobileSDKAndroidDemo/` — Rokid Mobile SDK
更老的 mobile SDK（2018-2025 维护），主要用于设备绑定、账号管理。我们的 Cortex 不通过这个走，仅作参考。

---

## 三、Rokid Voice / Speech SDK

### `rokid-voice/RokidVoiceAISDK/` — Voice AI 安卓全链路 SDK
Rokid 云端 ASR + TTS + NLP SDK（2021-08-05 最后更新）。**我们决定不走 Rokid 云端**（详见 GLASS-CLIENT-DESIGN §2.4），用 Mac/whisper.cpp 替代。仅作竞品/参考保留。

### `rokid-voice/RokidVoiceAIDemo/` — 同上的 Demo 工程

### `rokid-voice/RokidAiSdkDemo/` — Rokid AI SDK Demo（更早期）
2019-05-16 最后更新。早期语音 SDK 演示。

### `rokid-voice/speech-python-demo/` — Python 调用 Rokid 云语音 demo
WSS + protobuf 演示，证明 Rokid 云端不适合（高延迟、丢包高）。完整性归档。

---

## 四、Halo Ring（用户自己的项目）

### `halo-ring/Halo-Ring/` — Halo Ring 工程
- `Doc/02-hardware-and-protocol.md` — 硬件 + BT 协议
- `Doc/04-architecture.md` — 架构
- `Doc/11-verification-checklists.md` — 验证清单
- `Doc/12-research-and-references.md` — 研究参考
- `Doc/15-A2-spake2-tls-guide.md` — SPAKE2 + TLS

我们设计文档里"Halo Ring 集成"假设的协议依据。但当前能效优先方向下，Halo Ring 是 **optional**，物理按键已经能覆盖所有交互。

---

## 五、Whisper STT

### `whisper/whisper.cpp/` — whisper.cpp 源码（GitHub: ggml-org/whisper.cpp）
Cortex 端 STT 走 `whisper-cli` 命令行工具的源码。可以查：
- `examples/cli/cli.cpp` — whisper-cli 实现，理解参数细节
- `examples/stream/stream.cpp` — **streaming whisper 实现**，对 Level 2 部分转写有参考价值
- `models/download-ggml-model.sh` — 下载脚本（如果要换模型）
- README — 模型大小 / 性能基准

---

## 六、其他（占位，将来补）

### `jbd-display/` — Jade Bird Display JBD4020 资料（暂未填充）
JBD4020 micro-LED panel datasheet（未在 GitHub 找到，等查到官方途径再填）。
关键参数确认：480×640 像素、单色绿（来自裸机开发文档）。

---

## 远程仓库来源（git origin 记录）

| 本地路径 | 远程 |
|---|---|
| `rokid-glass/glass-docs` | https://github.com/Rokid/glass-docs |
| `rokid-glass/glass2-docs` | https://github.com/RokidGlass/glass2-docs |
| `rokid-glass/UXR-docs` | https://github.com/RokidGlass/UXR-docs |
| `rokid-glass/rokid-docs-buildwithfenna` | https://github.com/buildwithfenna/rokid-docs |
| `rokid-glass/armazpro-module-sdk-sample` | https://github.com/Rokid/armazpro-module-sdk-sample |
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
