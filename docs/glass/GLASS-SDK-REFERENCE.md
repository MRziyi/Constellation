# Constellation-Glass — Rokid Glasses 裸机 SDK 速查

**Updated**: 2026-05-26 · **For**: Rokid Glasses 2 (the eyewear) · YodaOS-Sprite (Android Go, Android 12)

> **术语**：本文档全程用 "Rokid Glasses" 指眼镜本体。**R08 是配套智能戒指 [Halo Ring](../../../Halo-Ring/) 的代号**，不是眼镜代号——历史文档里偶有混淆，遇到 "R08 firmware" / "on R08" 当作 Rokid Glasses 读。`R08-dev/` 路径正确，那是戒指的 R&D 区。
**Companion**: [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 (设计层) · [MIGRATION-PLAN.md](MIGRATION-PLAN.md) · [reference/INDEX.md](../../reference/INDEX.md) (源文档大图)

> **目的**：把"为了写 Constellation-Glass 需要知道的 SDK 事实"集中在一篇，
> 免得每次回到 `reference/` 翻 5 个文件。
> 凡是带 → 标记的事实附了原始出处，便于复核。
>
> **维护策略**：reference/ 更新或真机测试出新数据 → 并入这里。
> **不**直接编辑设计文档 (`GLASS-CLIENT-DESIGN.md`) —— 这里是"事实层"，设计是"决策层"。

---

## 0. 一句话

Rokid Glasses 是 YodaOS-Sprite (Android Go base, Android 12)，**Qualcomm 8250 4 核** + **NXP RT600 DSP**。
屏 **480×640 竖屏 monochrome-green** (JBD4020 micro-LED)。
4-mic 阵列 → iFlytek DSP → 8 通道 PCM 暴露给应用 (mask `0x6000FC`)。
按键 + 触控板都走 `BroadcastReceiver`。
我们走 **裸机 Android Go 应用**路径，不挂 CXR-L、不挂 InstructSdk、不依赖 Sprite。

---

## 1. 硬件速查

| 部件 | 规格 |
|---|---|
| SoC | Qualcomm 8250 (`neo_la`)，4 核单 cluster，schedutil governor |
| GPU | 285–540 MHz |
| DSP | NXP RT600（iFlytek 前端固件 3.0.4–5.1.2） |
| 屏幕 | JBD JBD4020 micro-LED，480×640 px，竖屏 4:3，monochrome green，右眼单镜 |
| 麦克风 | 4-mic 阵列，硬件 AEC/NR/Beamforming 由 RT600 完成 |
| 系统 | YodaOS-Sprite，基于 Android Go + Android 12 |
| ADB 连接 | **必需 Rokid 专用开发线**（默认充电线无数据通道）。一次性走数据线 → adb tcpip → 之后可 Wi-Fi |

→ `reference/rokid-glass/bare-metal-docs/00-overview.md`
→ `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/hardware/power-performance.md`
→ `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/hardware/display.md`

---

## 2. 麦克风 + 音频

### 2.1 配置 (官方 sample 验证过)

| 参数 | 值 | 备注 |
|---|---|---|
| `SAMPLE_RATE` | `16000` | 16 kHz，与 whisper 对齐 |
| `CHANNEL_CONFIG` | `0x6000FC` | Rokid 专有 8 通道 mask |
| `AUDIO_FORMAT` | `ENCODING_PCM_16BIT` | |
| `AudioSource` | `MediaRecorder.AudioSource.MIC` | **不要** 用 `VOICE_RECOGNITION` |
| `BUFFER_SIZE` | `1024` bytes | sample 起点，可调 |
| 权限 | `RECORD_AUDIO` | manifest + 运行时双声明 |

### 2.2 8 通道布局

| ch | 内容 | 我们用 |
|---|---|---|
| **0 / 1** | iFlytek 前端处理后 (NR / AEC / Beamforming) | ✅ 抽 ch0 给 whisper |
| 2 / 3 / 4 / 5 | 4 路原始 mic | ❌ |
| 6 / 7 | 硬件回声参考 | ❌ |

### 2.3 标准启动代码

```kotlin
val rec = AudioRecord.Builder()
    .setAudioSource(MediaRecorder.AudioSource.MIC)
    .setAudioFormat(
        AudioFormat.Builder()
            .setSampleRate(16000)
            .setChannelMask(0x6000FC)              // Rokid 专有 mask
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .build()
    )
    .build()
rec.startRecording()
// 注意：read() 返回的是 8 通道 interleaved；需要自己 deinterleave
```

### 2.4 Deinterleave

8 通道 interleaved 存储。每 8 个 16-bit sample 取第 0 个 = ch0 单声道。
- **简化**：只抽 ch0 → 直送 whisper (我们当前做法)
- **稳**：ch0 + ch1 平均 → 一行 loop，抗 ch0 异常

### 2.5 带宽 / 能耗

- 8ch × 16k × 16-bit = **2.048 Mbps 原始** (~256 KB/s)
- deinterleave 后只发 ch0 → **256 kbps** (~32 KB/s 上网)
- ⚠️ **不要扛着 8ch 上传给 Cortex**，Tailscale 上太贵 — 客户端必须 deinterleave

### 2.6 反例 (踩过的坑 / 别再做)

- ❌ `MediaRecorder.AudioSource.VOICE_RECOGNITION` — 系统会再叠 AEC，跟 DSP 重复处理
- ❌ `CHANNEL_IN_MONO` — 拿到的是 non-DSP 路径，**仅 phoneDebug flavor 用**
- ❌ Android `SpeechRecognizer` 框架 — 走云端 + 不可控延迟

### 2.7 真机待验

- ❓ AudioRecord 开着但不 read() 的待机能耗 — 文档未给数据，需 1h idle 实测
- ❓ `setChannelMask(0x6000FC)` 在我们手上的 Rokid Glasses firmware build 是否被接受

→ `reference/rokid-glass/bare-metal-docs/02-audio-recording.md`
→ `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/hardware/audio.md`
→ `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/platform/speech-sdk.md`

---

## 3. 物理按键 / 触控板事件

### 3.1 两条接收路径

| 路径 | 谁能收 | 我们用 |
|---|---|---|
| **系统有序广播** (`BroadcastReceiver`) | Service / Activity 都行，无需前台 | ✅ |
| **标准 KeyEvent** (`onKeyDown/Up`) | 仅前台 Activity 聚焦时 | ❌ (Service 是核心) |

### 3.2 完整广播 Action 清单

| Action | 含义 | 系统占用 |
|---|---|---|
| `com.android.action.ACTION_SPRITE_BUTTON_CLICK` | 按键单击 | ✓ 可用 |
| `com.android.action.ACTION_SPRITE_BUTTON_DOWN` | 按键按下 | ✓ 可用 |
| `com.android.action.ACTION_SPRITE_BUTTON_UP` | 按键抬起 | ✓ 可用 |
| `com.android.action.ACTION_SPRITE_BUTTON_LONG_PRESS` | 按键长按 | ✓ 可用 |
| `com.android.action.ACTION_SPRITE_BUTTON_DOUBLE_CLICK` | 按键双击 | ⚠️ **系统占用为返回，`abortBroadcast()` 拦不住** |
| `com.android.action.ACTION_AI_START` | 长按触控板 → Sprite | ⚠️ 系统占用 |
| `com.android.action.ACTION_TWO_FINGER_SINGLE_TAP` | 双指单击 | ✓ 可用 |
| `com.android.action.ACTION_TWO_FINGER_DOUBLE_TAP` | 双指双击 | ✓ 可用 |
| `com.android.action.ACTION_TWO_FINGER_SWIPE_FORWARD` | 双指前滑 | ✓ 可用 |
| `com.android.action.ACTION_TWO_FINGER_SWIPE_BACK` | 双指后滑 | ✓ 可用 |
| `com.android.action.ACTION_SETTINGS_KEY` | 双指长按 = 设置键 | ✓ 可用 |

### 3.3 物理拓扑映射

| 物理位置 | 动作 | 谁拿 |
|---|---|---|
| 右镜腿**上方按钮** | CLICK | 系统拍照（**外部应用拿不到**） |
| 右镜腿**上方按钮** | LONG_PRESS | 系统录像（**外部应用拿不到**） |
| 右镜腿**侧面按键** ("Sprite button") | CLICK / LONG / DOUBLE | ✅ 我们用 |
| 右镜腿**侧面触控板** | 双指 + 长按 | ✅ 我们用 (长按除外，被 Sprite 占) |

### 3.4 Constellation 按键映射 (C-38)

| 物理动作 | 我们的语义 |
|---|---|
| **CLICK** (单击) | **主交互**：IDLE→Listening 开麦 / CARD→Approve |
| **LONG_PRESS** (长按) | **辅助**：CARD→Modify (再开麦 15s) |
| **DOUBLE_CLICK** (双击) | 系统返回 → 我们当 Kill / IDLE 处理（不抗争）|
| **TWO_FINGER_SINGLE_TAP** | Insight engage / 次选 |
| **TWO_FINGER_DOUBLE_TAP** | Kill 备用 |
| **TWO_FINGER_SWIPE_FORWARD/BACK** | CARD 翻页 |

### 3.5 注册要点

```kotlin
registerReceiver(keyReceiver, IntentFilter().apply {
    addAction(KeyType.CLICK.action)
    // ... 全部 11 个 action
    priority = 100        // 高优先级 → abortBroadcast() 才有效
}, RECEIVER_EXPORTED)     // Android 13+ 必须显式声明
```

- **程序化** `registerReceiver`，**不要** 在 manifest 注册 (manifest receiver 拿不到 abortBroadcast 能力)
- Service 内注册 (我们这样做)
- `priority=100` + `abortBroadcast()` 拦截除 DOUBLE_CLICK 外的所有按键的系统默认行为

### 3.6 ⚠ Sprite AssistServer 侧键平行劫持（2026-05-27 真机发现）

**SDK 文档没说**：右镜腿**侧面按键** **不是**纯属应用 — 系统级 `com.rokid.os.sprite.assistserver` (UID 1000, PID 一直在) 在 **WindowManager KeyEvent 层** 平行拦截 `KEYCODE_SPRITE_FUNCTION`，每次 ACTION_SPRITE_BUTTON_UP 触发**静默后台拍照** (`MSG_TAKE_PICTURE → picture_no_ui`)。

**证据**（真机 logcat，2026-05-27 14:26:41，单击侧键）：
```
WindowManager       interceptKeyTq  KEYCODE_SPRITE_FUNCTION
AssistServer        FunctionKeyReceiver → ACTION_SPRITE_BUTTON_UP
AssistServer        SpriteMediaService → MSG_TAKE_PICTURE → picture_no_ui
AssistServer        Camera2FuncImpl → openCamera: openSource=picture_no_ui
CameraService       connect "com.rokid.os.sprite.assistserver" camera ID 0
```

**含义**：
- 我们的 `SystemKeyReceiver` + `priority=100 + abortBroadcast()` 只能拦截 **有序广播链**，拦不了 KeyEvent → AssistServer 的平行路径
- 我们的 AudioRecord 已经开着 mic + AssistServer 同时抢相机 → AssistServer 报"Camera is error, couldn't take the photo now"（语音播报）+ 拍出来的照片可能损坏
- **这条路径无法用我们 app 代码消除**

**对策**（按侵入度排）：
- **A) 走戒指广播**作为 fresh voice invoke 主入口（Halo Ring → `HaloTriggerReceiver` → `voice_invoke` → ConstellationService），完全避开侧键。**当前方案 (2026-05-27)**。
- **B) 在 Card 内才用侧键**：只用 CLICK/LONG/DOUBLE 做 Approve/Modify/Kill（已在卡片状态中）— 此时 AssistServer 拍照失败更可接受（mic + camera 都占着）。
- **C) `pm disable-user com.rokid.os.sprite.assistserver`**（侵入式）— 彻底关掉 Sprite，副作用未知（可能影响其他系统功能）。**当前不做**。
- **D) Rokid AI App 手机端**：在配对眼镜的手机 app 里关"按键拍照"（如果有这个开关）— 待用户确认。

→ 在 SoT 里登记为新 finding；C-38 主输入路径维持，但 "fresh voice invoke" 实际入口改为戒指。

### 3.7 真机待验

- ❓ LONG_PRESS 的精确时长阈值 (官方未公开) — 关键 UX 数据
- ❓ 系统是 key-down 还是 key-up 时触发 LONG_PRESS
- ❓ DOUBLE_CLICK 时整个 process 被杀还是只关 Activity (我们 Service 是否还活着)
- ❓ 拍照/录像 按钮 (上方) 操作时，正在跑的 `AudioRecord` 是否被抢占
- ✅ 侧面按键 SPRITE_BUTTON_* 广播被我们收到 — **2026-05-27 实机确认**
- ✅ `setChannelMask(0x6000FC)` 真机接受 — **2026-05-27 实机确认** (`GlassAudioCapture · started · 0x6000FC 8-ch → ch0`)

→ `reference/rokid-glass/bare-metal-docs/01-key-events.md` (含完整 Kotlin sample)

---

## 4. 屏幕渲染

### 4.1 物理参数

- 480×640 px，竖屏 4:3，monochrome green
- JBD4020 micro-LED，右眼单镜
- Snapdragon Display Engine 8.x (DPU8xx)
- 硬件支持 refresh rates: 90 / 120 / 144 / 180 Hz

### 4.2 热级 ↔ FPS 上限 (来自 `thermallevel_to_fps.xml`)

| 热级 | Max FPS |
|---|---|
| 1-2 | 144 |
| 3-4 | 120 |
| 5-7 | 90 |
| 8-10 | 60 |

### 4.3 我们的策略

- **目标 ≤ 4 Hz HUD refresh**（远低于硬件下限，留出热预算）
- 用**透明 fullscreen Activity** (`GlassHudActivity`)，Service 启动 + observe `GlassHudState` snapshot
- **没有专门的 HUD overlay API**；Activity overlay 就是 YodaOS 官方推荐做法

### 4.4 亮度 / HBM

- 背光范围 1200–4095 (max 8191 OS-side)
- HBM (High Brightness Mode) **不支持** — 户外场景需评估可读性
- 摄像头开启时白 LED 自动亮 (`/sys/class/leds/white/brightness`)

### 4.5 真机待验

- ❓ `densityDpi` 实际值 (Compose 字号/padding 缩放) — 真机 log `Resources.getDisplayMetrics()`
- ❓ 户外可读性 (无 HBM)
- ❓ 480×640 上 28 char/行 (我们当前估算) 实际显示效果

→ `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/hardware/display.md`

---

## 5. 前台 Service (ForegroundService)

### 5.1 必需声明

```xml
<service
    android:name=".ConstellationService"
    android:foregroundServiceType="microphone|camera"
    android:exported="false" />

<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
```

**Why `camera` type**: Phase Q.3 (shortcut photo capture) needs the Service
to hold camera access from a background-effective context. Android 14+
blocks background camera open without `FOREGROUND_SERVICE_TYPE_CAMERA`
declared. Confirmed via `ERROR_CAMERA_DISABLED` from `Camera2CameraImpl`
the first time we tried without it.

### 5.2 启动模板

```kotlin
val nc = NotificationChannel(CHAN_ID, "Constellation", NotificationManager.IMPORTANCE_LOW)
val n  = NotificationCompat.Builder(this, CHAN_ID)
    .setContentTitle("Constellation")
    .setSmallIcon(R.drawable.ic_status)
    .setOngoing(true)
    .build()
startForeground(NOTIF_ID, n, FOREGROUND_SERVICE_TYPE_MICROPHONE or FOREGROUND_SERVICE_TYPE_CAMERA)
```

### 5.3 Doze / Standby 期间行为

- YodaOS 12 沿用标准 Android 12 Doze 规则
- FGS 期间：WebSocket + AudioRecord 不被杀
- 我们已用 FGS，标记 type=microphone+connectedDevice，**应当**穿过 Doze

### 5.4 真机待验

- ❓ FGS notification 是否被 launcher 隐藏 / 用户能否手动 swipe 走
- ❓ Doze 期间 OkHttp ping 是否真的能保活

---

## 6. 网络 / WSS

### 6.1 链路

```
Rokid Glasses  ──HTTPS/WSS──►  Linux Edge (edge.example.com, DigitalOcean)
                                      │
                                      └──Tailscale──►  Mac mini Cortex (<mac-host>:8888)
```

- TLS 终结在 Edge，眼镜走标准 Android TrustStore (Let's Encrypt cert)
- 双向认证：Cookie (`console_session`，从 password login 拿)

### 6.2 配置目标

| 参数 | 目标值 | 出处 |
|---|---|---|
| OkHttp `pingInterval` | 15s | GLASS-CLIENT-DESIGN §3.3 |
| Connect timeout | 10s | |
| Read timeout | 0 (永久，长连接) | |
| Reconnect backoff | 1s → 2s → 5s → 10s 起 | |

### 6.3 真机待验

- ❓ 当前代码里 pingInterval 实际值（grep `pingInterval`）
- ❓ Tailscale → Edge → Cortex 往返 RTT (蜂窝 / 热点 / 会议 Wi-Fi 三种网络)

---

## 7. 我们**不用**的 SDK (以及为什么)

| SDK | 状态 | 理由 |
|---|---|---|
| **InstructSdk** (离线语音指令 v1.6.1) | ❌ 拒 | 要求用户在系统打开 "语音助手激活"开关 (即长按触控板进 Sprite) + 依附 Activity 生命周期。跟 **C-37** (无后台语音) + **C-38** (物理键为主) 冲突。 |
| **AccessibilityInstruct** (百灵鸟) | ❌ 拒 | 同上链路 |
| **CXR-L AAR** (`com.rokid.cxr:client-l:1.0.1`) | ❌ 拒 | 是**手机侧** bridge SDK，不在眼镜上跑 — 见 `bare-metal-docs/04-cxrl-vs-baremetal-decisive.md` |
| **AuthorizationHelper / Rokid token** | ❌ 拒 | 裸机不需要 Sprite IPC 鉴权 |
| **Face SDK** (离线人脸识别) | ⏸ 推迟 | UC3 face recognition 在 Phase 6 — 那时再评估 |
| **LPR SDK** (车牌识别) | ❌ | 与用例无关 |
| **Scene Recognize SDK** | ⏸ 待议 | 可能给 Insight Engine 加输入 — 见 §8 |
| **IMU SDK** | 💡 待议 | 可能给"抬头唤醒"用 — 见 §8 |
| **UI SDK** | ❌ 拒 | Compose 已覆盖；UI SDK 给老 View 应用脚手架 |
| **拍照按钮** (上方 CLICK) | ❌ 拿不到 | 系统占用 |
| **录像按钮** (上方 LONG_PRESS) | ❌ 拿不到 | 系统占用 |

→ `reference/rokid-glass/glass2-docs/zh/2-sdk/` (各 SDK 官方说明)
→ `reference/rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md`

---

## 8. 可能值得重评估的 SDK 能力 (设计候选)

> 这些目前**不在** v2.1 设计内，但 SDK 能力上是有的。等真机 P1.5 拿到第一手数据后可以重谈：

| 能力 | 来源 | 潜在用途 | 风险 |
|---|---|---|---|
| **IMU 头部姿态** | `glass2-docs/2-sdk/8-imu-sdk` | "抬头看天花板 → 唤醒 HUD" 替代单击物理键 | 多一个能耗源；漂移；用户头动作分类需调 |
| **Scene Recognize** | `glass2-docs/2-sdk/9-scenerecognize-sdk` | Insight Engine 上下文增强 | 隐私 (拍照分析)；能耗未知 |
| **相机 (camera2 API)** | `yodaos/docs/apps/camera2.md` | UC3 face recognition (Phase 6) | 计划中，未提前 |
| **音频回声参考 (ch 6/7)** | `bare-metal-docs/02-audio-recording.md` | 进一步降噪 (我们目前只用 ch0) | 多数据量；DSP 已经做了大部分 |

---

## 9. 真机验证清单 (P1.5 — 等专用开发线)

按 **是否阻塞设计变更** 排序（高→低）：

| # | 验证项 | 设计风险 | 验证方法 |
|---|---|---|---|
| 1 | `setChannelMask(0x6000FC)` 不被 firmware 拒 | **是** — 拒了只能走 `CHANNEL_IN_MONO` + 丧失 DSP 链路 | `AudioRecord.getState() == STATE_INITIALIZED` |
| 2 | AudioRecord 开着不 read 的待机功耗 | **是** — 高了必须 eager close/reopen | 1h idle 对比电池 % |
| 3 | 拍照/录像 按钮被按时 `AudioRecord` 是否被抢占 | **是** — 冲突→需要约定用户不要碰那个键，或检测降级 | 录像中调 `startRecording()` 看返回值 |
| 4 | LONG_PRESS 触发时长阈值 | 否 (UX 影响) | stopwatch + `adb logcat -s SystemKeyReceiver` |
| 5 | DOUBLE_CLICK 是杀 Activity 还是杀 process | 否 (设计已两手准备) | 双击后 `adb shell ps \| grep constellation` |
| 6 | `densityDpi` 实际值 | 否 (Compose 字号) | `Resources.getDisplayMetrics()` |
| 7 | OkHttp `pingInterval` 实际值 (代码中) | 否 — 但 Doze 保活 | `grep pingInterval` in Constellation-Glass |
| 8 | TLS + Tailscale 链路 RTT | 否 | adb logcat WssClient |
| 9 | FGS notification 是否被系统折叠 | 否 (UX) | `adb shell dumpsys notification` |
| 10 | 户外无 HBM 时屏幕可读性 | 否 | 现场目测 |

---

## 10. 摄像头 (CameraX) + QR (ML Kit) — Phase Q

### 11.1 依赖

```kotlin
// app/build.gradle.kts
implementation("androidx.camera:camera-core:1.4.0")
implementation("androidx.camera:camera-camera2:1.4.0")
implementation("androidx.camera:camera-lifecycle:1.4.0")
implementation("androidx.camera:camera-view:1.4.0")
implementation("com.google.mlkit:barcode-scanning:17.3.0")
implementation("androidx.lifecycle:lifecycle-process:2.8.4")
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.9.0")
```

### 11.2 Headless 一次性拍照 (shortcut photo=true)

代码在 `app/src/main/.../camera/CameraCapture.kt`。要点：

| 项 | 值 / 实现 |
|---|---|
| Use case | `ImageCapture.Builder().setCaptureMode(CAPTURE_MODE_MINIMIZE_LATENCY)` |
| 输出 | 直接 JPEG bytes via `image.planes[0].buffer` (CAPTURE_MODE_MINIMIZE_LATENCY → JPEG, not YUV) |
| Lifecycle | `OneShotLifecycleOwner` (主线程上 INITIALIZED → CREATED → STARTED → RESUMED) → bindToLifecycle → takePicture → destroy + unbindAll |
| Camera | `CameraSelector.DEFAULT_BACK_CAMERA` |
| 后处理 | Decode JPEG → `BitmapFactory` `inSampleSize` 粗缩 → `Bitmap.createScaledBitmap` 精确到 1024 longest edge → `compress(JPEG, 80)` |

**Observed on OnePlus 9**: 4096×3072 sensor JPEG ~1.8 MB → 1024×768 ~70 KB (25× reduction). LLM vision rarely benefits from more.

**坑**：
- `LifecycleRegistry.setCurrentState()` must be called from the main thread. Stateful init in the constructor crashes when called from `Dispatchers.IO`.
- Camera bind also wants the main thread.
- BroadcastReceiver's ~10s budget can't cover full capture+upload — route via Service. We do this through `ConstellationService.fireShortcut(ctx, sid)`.

### 11.3 QR 扫码 (login pairing)

代码在 `app/src/main/.../camera/QrScanner.kt`。要点：

| 项 | 值 / 实现 |
|---|---|
| Preview | `androidx.camera.view.PreviewView` wrapped in `AndroidView` for Compose |
| Decoder | `BarcodeScanning.getClient(BarcodeScannerOptions.Builder().setBarcodeFormats(FORMAT_QR_CODE).build())` |
| Analyzer | `ImageAnalysis.Builder().setBackpressureStrategy(STRATEGY_KEEP_ONLY_LATEST)` |
| Lifecycle | `LocalLifecycleOwner.current` (the hosting Activity) |
| Fire-once | `var fired by remember mutableStateOf(false)` — first valid `QR_CODE.rawValue` triggers `onDetected`, subsequent ignored |

QR payload format (must match Edge `/api/auth/pair_qr` output):
```json
{
  "endpoint": "wss://edge.example.com/ws/glass",
  "cookie_name": "console_session",
  "cookie_value": "<token>"
}
```

### 11.4 ML Kit Barcode 模型

`com.google.mlkit:barcode-scanning:17.3.0` 是 **Google Play Services 路径**——需要 GMS。如果将来移植到无 GMS 的 Rokid Glasses build，换 `com.google.mlkit:barcode-scanning:17.3.0` → `barcode-scanning` 同名但 **bundled-model** 版本（同 group/artifact id 但有 bundled variant）—— 模型直接打进 APK，约 +2 MB，不依赖 Play Services。**Rokid Glasses 是否有 GMS 待真机验**（Q.8 任务）。

### 11.5 真机已验 (2026-05-28)

- ✅ **GMS works on Rokid Glasses** — ML Kit Barcode (Play Services variant) scanned the QR successfully. No need to switch to bundled-model variant.
- ✅ **Camera opens + captures** (after CameraGate workaround — see §11.6 below). 6 MB sensor JPEG → 165 KB downscaled @ 1024px q=80, fed to Cortex `vision_describe`, real prose description back to HUD card.
- ✅ **QR scanner preview** on the JBD4020 panel scanned QR shown on Mac screen in ~4s.

### 11.6 ⚠️ CameraX gotcha — AppOps `CAMERA: foreground` (C-51)

**The trap**: On YodaOS-Sprite (Rokid Glasses), `CameraX.bindToLifecycle()` from
a backgrounded Service fails with:

```
Camera2CameraImpl: Unable to open camera due to CAMERA_DISABLED (1):
  connectHelper:1853: Camera "0" disabled by policy
```

Even when ALL of these are in place:
- `<uses-permission android:name="android.permission.CAMERA" />` granted at runtime
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />`
- Manifest `android:foregroundServiceType="microphone|camera"`
- `ServiceCompat.startForeground(this, NOTIF_ID, notif, FOREGROUND_SERVICE_TYPE_CAMERA)` explicit

**Root cause**: AppOps `CAMERA: foreground` UID mode. YodaOS-Sprite strictly
enforces "package must have a RESUMED Activity to open camera"; FGS_CAMERA
type alone doesn't count as "in use" on this firmware (it does on AOSP / OnePlus 9).

Diagnose with: `adb shell dumpsys media.camera | grep -E "Uid mode|REJECT"`
→ expect `Uid mode: CAMERA: foreground` + `REJECT … Camera "0" disabled by policy`
when our app is backgrounded.

**Workaround (Constellation-Glass `8a2b989`)**: `CameraGate.captureViaGate(ctx)`
launches a one-shot transparent gate Activity:

```kotlin
// app/src/main/.../camera/CameraGate.kt
object CameraGate {
    private val mutex = Mutex()
    private var pending: CompletableDeferred<ByteArray?>? = null

    suspend fun captureViaGate(ctx: Context): ByteArray? = mutex.withLock {
        val deferred = CompletableDeferred<ByteArray?>()
        pending = deferred
        ctx.startActivity(Intent(ctx, CameraGateActivity::class.java).apply {
            addFlags(FLAG_ACTIVITY_NEW_TASK or FLAG_ACTIVITY_NO_ANIMATION or
                     FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        })
        deferred.await().also { pending = null }
    }
    fun complete(result: ByteArray?) { pending?.complete(result) }
}

class CameraGateActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleScope.launch {
            val bytes = runCatching { CameraCapture.capture(this@CameraGateActivity) }
                .getOrNull()
            CameraGate.complete(bytes)
            finish()
        }
    }
}
```

Manifest entry (under glass + phoneDebug shared `app/src/main/AndroidManifest.xml`):

```xml
<activity android:name=".camera.CameraGateActivity"
    android:exported="false"
    android:theme="@android:style/Theme.Translucent.NoTitleBar"
    android:excludeFromRecents="true"
    android:noHistory="true"
    android:taskAffinity=""
    android:launchMode="singleInstance" />
```

The wearer sees a sub-second panel blink while the Activity exists for ~2s
(visible because the panel briefly turns "on" for our Activity — even
though Theme.Translucent.NoTitleBar means no UI is drawn). Then the
Activity finishes and the panel returns to whatever was below.

**Pattern recognition**: Rokid's own Sprite uses the exact same pattern —
`com.rokid.os.sprite.assist.media.page.CameraActivity` is its equivalent
gate. We confirmed via `adb shell dumpsys media.camera` showing that
package "Device 0 is open" right after a top-temple-button press.

**Rule**: Any feature that needs camera access on Rokid Glasses MUST route
through `CameraGate.captureViaGate()`. Don't call `CameraCapture.capture()`
directly from a Service or non-Activity context.

---

## 11. 源文档定位 (这份速查从哪儿来)

| 主题 | 文件 |
|---|---|
| Glass 裸机入门 | `reference/rokid-glass/bare-metal-docs/00-overview.md` |
| 按键事件完整清单 + Kotlin sample | `reference/rokid-glass/bare-metal-docs/01-key-events.md` |
| 音频 8 通道 + ChannelMask sample | `reference/rokid-glass/bare-metal-docs/02-audio-recording.md` |
| Rokid SDK 总览页 | `reference/rokid-glass/bare-metal-docs/03-developerdoc-sdk-page.md` |
| **为什么不用 CXR-L** | `reference/rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md` |
| Rokid Glasses 2 官方 SDK 文档 | `reference/rokid-glass/glass2-docs/zh/` |
| YodaOS 硬件音频 (mic 阵列 / DSP) | `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/hardware/audio.md` |
| YodaOS 屏幕 + 热级表 | `.../yodaos/docs/hardware/display.md` |
| YodaOS DSP + iFlytek + KWS | `.../yodaos/docs/platform/speech-sdk.md` |
| YodaOS SoC + 电源调度 | `.../yodaos/docs/hardware/power-performance.md` |
| 传感器 (IMU / 光) | `.../yodaos/docs/hardware/sensors.md` |
| **Reference 大图 + 索引** | `reference/INDEX.md` |
| Whisper 模型 / cpp 接入 | `reference/whisper/` (我们用 small + base 双档) |
| Halo Ring 协议源码 | `reference/halo-ring/` (companion，可选) |

---

*维护人*：眼镜端开发期间持续更新。每次真机测试 (P1.5+) 把新发现并入 §9 表 + 相关章节。
设计层决策入 [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md)，硬件事实入这里。
