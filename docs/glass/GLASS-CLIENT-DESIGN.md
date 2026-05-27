# Glass Client — Design v2.1 (Phase 3b · 裸机重设计)

**Status**: design **PIVOTED** (Zack 2026-05-26) — supersedes v2.0. **v2.1 + 2026-05-28 amendments** (SoT R10 + R11): HUD is now a SYSTEM_ALERT_WINDOW overlay (not fullscreen Activity); `CameraGate` workaround for AppOps `CAMERA: foreground`; control model unified (C-52). See banner below for §3 amendments.
**Target hardware**: Rokid Glasses 2 (JBD4020 monochrome-green micro-LED right-eye 480×640 panel; YodaOS-Sprite based on Android Go / Android 12 / Qualcomm 8250 + NXP RT600 DSP)

> ⚠️ **2026-05-28 amendments to §3** (post real-device feedback; constitutional in SoT R10 + R11):
> - **C-48**: `GlassHudActivity` (transparent fullscreen Activity) is **DELETED**. Replaced by `GlassHudOverlay` — a SYSTEM_ALERT_WINDOW overlay floating above launcher/other apps. Read [IN-APP-UI-DESIGN.md §12 (2026-05-28 session)](IN-APP-UI-DESIGN.md) for the actual code.
> - **C-49**: `SCREEN_BRIGHT_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP` acquired while HUD visible (5-min ceiling), released on Idle. Replaces the previous "KEEP_SCREEN_ON Activity flag" approach.
> - **C-50**: Type scale -30% for real panel density 240 (title 14sp / body 11sp / meta 10sp / footer 9sp). The "Phase 3b — 实现 GlassHudActivity (Compose + 全屏 immersive + KEEP_SCREEN_ON)" todo in §5 is **superseded** by the overlay model — keep §5 for archaeological context, but treat IN-APP-UI-DESIGN as ground truth.
> - **C-51 (CameraGate)**: any camera-using flow MUST route through `CameraGate.captureViaGate(ctx)`. Direct `CameraCapture.capture` from a Service fails on YodaOS with `Camera "0" disabled by policy`. See [GLASS-SDK-REFERENCE.md §11.6](GLASS-SDK-REFERENCE.md).
> - **C-52 (unified control)**: card semantics gate on `cardOptions.isEmpty()`. Actionable cards → emitDecision; info-only cards → local dismiss + dynamic TTL. `cardBodyWrapChars` (manual pre-pagination) is **deleted**; `BasicText(softWrap=true)` in `verticalScroll` handles wrap + scroll naturally.
> - **C-53**: InstructSdk still not used (reaffirms C-37 / C-38).

> 术语：本文档全程用 **Rokid Glasses** 指眼镜本体。R08 是配套智能戒指 ([Halo Ring](../../../Halo-Ring/)) 的代号，不是眼镜代号。Older "R08-series" / "R08-gen" wording in early drafts of this doc was wrong; corrected 2026-05-26.
**Companion devices**: Halo Ring (**optional** — adds ring gesture input when paired; system works without it because the temple touchpad+buttons handle all interactions)
**Companion server**: existing `wss://edge.example.com/ws/glass` on Linux Edge → Cortex on Mac mini (Tailscale-routed). Glasses connect to the **public TLS endpoint** over Wi-Fi.
**Path**: **裸机开发**（standard Android Go app installed directly on the glass）— NOT CXR-L

> **Important**: v2.0 was based on a misreading of `R08-dev/research/rokid-docs/cxr-l/api-reference.md` v0.0.1.
> The actual current CXR-L v1.0.1 docs make it explicit: **"CXR-L SDK runs on the phone"** — it's a bridge SDK for phone apps to talk to glass via Rokid AI App. For glass-side apps, the official path is **裸机开发** (bare-metal).
>
> Sources consulted for this revision (all in `reference/` now):
> - `reference/rokid-glass/bare-metal-docs/` — 裸机开发 official docs (captured 2026-05-26 via chrome-mcp from `custom.rokid.com` SPA)
> - `reference/rokid-glass/cxrl-sample-android/` — CXR-L v1.0.1 sample (for cross-reference; phone-side SDK)
> - `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/` — reverse-engineered YodaOS hardware docs (audio, display, thermal, speech)
> - `reference/whisper/whisper.cpp/` — whisper.cpp source (for STT)
> - `reference/halo-ring/Halo-Ring/Doc/` — Halo Ring protocol spec
>
> **Note**: `glass2-docs/` (Rokid **Glass 2**, the older product — Amlogic, 1280×720 landscape) was previously cited here but removed 2026-05-27. That product is not user's current Rokid Glasses (480×640 portrait, JBD4020, YodaOS-Sprite). See `reference/INDEX.md` for the model-applicability anchor.

---

## 0. v2.1 改了什么（vs v2.0 一行差异）

| 主题 | v2.0 | v2.1 |
|---|---|---|
| 部署形态 | CXR-L AAR + 手机 App 桥接眼镜 | **裸机** Android Go app 直接装眼镜 |
| HUD 渲染 | `cxrLink.customViewOpen(json)` | **Activity / Compose 直接渲染**（全屏 immersive） |
| 音频 | `cxrLink.startAudioStream(1)` | **AudioRecord + ChannelMask 0x6000FC**，取通道 0/1 |
| 输入 | InstructSdk 语音 + Halo Ring | **系统广播按键事件**（Service 注册），Halo Ring optional |
| 唤醒 | "Constellation" / "你好" InstructSdk wake word | **物理键单击 / 长按**（不依赖 Sprite） |
| 鉴权 | AuthorizationHelper + token | **不需要**（裸机用标准 Android 权限） |
| 屏幕规格 | 640×480（估的） | **480×640 portrait**（官方） |
| Sprite 依赖 | 强依赖（CustomView + InstructSdk） | **完全不依赖**（用户可关 Sprite，能效更优） |
| 长按触控板 | "Hi Rokid" 唤起 Sprite — 系统占用 | 同上 — **我们不用** |
| 双击右镜腿键 | 设计未涉及 | **系统占用 = 返回**，不可拦截 |

---

## 1. Non-negotiables (locked by Zack 2026-05-26, v2.1)

1. **能效是项目第一指标。** 长期常驻后台。CPU、Wi-Fi、显示、mic 全要严格节能。
2. **不用 Sprite 语音助手。** "Hi Rokid" 不用，InstructSdk 不用（因为它需要 Sprite 长开）。所有语音交互**只在用户主动按键开 mic 后**才发生，无后台监听。
3. **裸机部署。** App 直接装到眼镜，不通过 CXR-L 桥接。
4. **物理键是主输入。** 单击 / 长按 / 双指手势全可用；长按触控板和上方拍照按钮系统占用。
5. **HUD 非堆叠，update-in-place。** 一个内容区域，新内容**覆盖**旧内容。
6. **HUD 区域避开 Halo Ring pip 位**（lower-right），如果 Halo Ring 装了。
7. **长卡片绝不截断**，6 行 viewport，双指前/后滑滚动。
8. **Markdown 在服务端解析成 styled runs**，眼镜端只渲染。
9. **Insight Engine 一等公民**（保留 v2.0 §1.9 设计）。
10. **不堆栈卡片**：每个状态只显示一个东西，新内容替换。
11. **不显示"断开"按钮**：WSS drop = error overlay。
12. **Halo Ring optional**：物理键覆盖全部交互，环只是更快的备选。
13. **不能耗费物理拍照/录像键**：系统占用，外部 app 拿不到。
14. **双击右镜腿键 = 退出 Constellation**：这是系统返回，我们接受。

---

## 2. SDK 真相（v2.1 重新落实）

### 2.1 裸机开发就是普通 Android 应用

来自 `reference/rokid-glass/bare-metal-docs/00-overview.md`：

> "Rokid Glasses 裸机上的开发与 Android 应用开发**基本保持一致**"

意味着我们用：
- 普通 `Activity` / `Service` / `BroadcastReceiver` / `ContentProvider`
- 普通 `View` / Jetpack Compose（要注意 Android Go 内存压力）
- 普通 `AudioRecord`、`Camera`、`SensorManager`
- 普通运行时权限申请流程

约束：
- **Android Go**（≈1GB RAM）— 内存敏感
- **屏幕 480×640 portrait**（4:3 竖屏）
- **专用开发线** 才能 adb；通过 Rokid AI App（手机端）打开眼镜 adb
- 调试可用 SCRCPY 同屏

### 2.2 物理输入（按键广播 + KeyEvent）

来自 `reference/rokid-glass/bare-metal-docs/01-key-events.md`：

**系统广播路径**（Service 也能注册，**完美匹配我们的 FGS 设计**）：

| KeyType | Action | 我们用作 |
|---|---|---|
| `CLICK` | `ACTION_SPRITE_BUTTON_CLICK` | **主交互**：IDLE→Listening / Card→Approve |
| `LONG_PRESS` | `ACTION_SPRITE_BUTTON_LONG_PRESS` | **辅助**：Card→Modify |
| `DOUBLE_CLICK` | `ACTION_SPRITE_BUTTON_DOUBLE_CLICK` | **系统占用：返回** — 我们处理为 Kill → Idle |
| `ACTION_TWO_FINGER_SWIPE_FORWARD` | `..._TWO_FINGER_SWIPE_FORWARD` | Card 向下翻页 |
| `ACTION_TWO_FINGER_SWIPE_BACK` | `..._TWO_FINGER_SWIPE_BACK` | Card 向上翻页 |
| `ACTION_TWO_FINGER_SINGLE_TAP` | `..._TWO_FINGER_SINGLE_TAP` | Insight engage / 次选 |
| `ACTION_TWO_FINGER_DOUBLE_TAP` | `..._TWO_FINGER_DOUBLE_TAP` | Kill |
| `ACTION_SETTINGS_KEY` | `..._SETTINGS_KEY` | 进 Settings Activity |
| `AI_START` | `ACTION_AI_START` | **不用**（系统长按触控板进 Sprite） |
| `BUTTON_DOWN` / `BUTTON_UP` | 监听准备阶段 | 可选 |

广播 `priority=100` + `abortBroadcast()` 阻断系统默认处理（除 DOUBLE_CLICK 不可拦截）。

### 2.3 音频（AudioRecord + ChannelMask 0x6000FC）

来自 `reference/rokid-glass/bare-metal-docs/02-audio-recording.md` 和 `reference/rokid-glass/rokid-docs-buildwithfenna/yodaos/docs/platform/speech-sdk.md`：

**通道布局（8 通道交错）**：

| Channel | 内容 | 我们用 |
|---|---|---|
| 0 / 1 | **算法后音频**（iFlytek NR/AEC/Beamforming） | ✅ 取通道 0 给 whisper |
| 2 / 3 / 4 / 5 | 4 路原始 mic | ❌ 不用 |
| 6 / 7 | 硬件回声参考 | ❌ 不用 |

**代码骨架**：

```kotlin
val rec = AudioRecord.Builder()
    .setAudioSource(MediaRecorder.AudioSource.MIC)
    .setAudioFormat(AudioFormat.Builder()
        .setSampleRate(16000)
        .setChannelMask(0x6000FC)               // Rokid 专有 8 通道 mask
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .build())
    .build()
// read 出来是 8 通道 16-bit interleaved；deinterleave 取 channel 0 给 whisper
```

**底层管线**：
- NXP RT600 DSP 跑 iFlytek 前端（NR / AEC / beamforming）
- 输出多通道 PCM 给 Android
- 我们拿到的通道 0/1 已经过 DSP 算法处理，可以直接给 STT
- **没有硬件 VAD 暴露给应用层** — 沉默检测要么自己做 RMS 阈值，要么靠 server-side VAD

### 2.4 STT 走 Mac/whisper.cpp（保留 v2.0 决策）

未变：
- 走 Linux Edge → Cortex on Mac mini
- whisper-cli `small` for finalised utterances（~1.2s）
- `base` for Level-2 streaming partials（~0.6s/秒）

源码参考：`reference/whisper/whisper.cpp/examples/cli/cli.cpp`、`examples/stream/stream.cpp`。

### 2.5 鉴权（Edge cookie，不是 Rokid token）

未变：
- 眼镜端 App POST `/api/auth/login` `{password}` → 拿 `console_session` cookie
- 用 cookie 升级 WSS 连接
- 没有 Rokid token 那一层（裸机不需要）

### 2.6 显示渲染

裸机：直接用 Compose / Android View 在 Activity 里画。
- 屏幕 480×640 portrait
- 单色绿色彩空间（硬件 panel 限制；任何颜色会被 downsample 到绿通道）
- 全屏 immersive flag + always-on-top + keep screen on
- HUD 区上半，下半留给 Halo Ring pip（如果有）+ 系统 UI

**4 Hz 上限**：来自 `yodaos/docs/hardware/display.md` 的 `thermallevel_to_fps.xml` 表，热级 8-10 时面板 60Hz；我们不要把面板推到这个等级。但 4 Hz 是上限**指导**，实际可以 10-30Hz；要真机测才能定。

### 2.7 Halo Ring（保持 optional）

如果装了，监听 `com.halo.ring.action.TRIGGER` 广播 → 触发 `Constellation.actions.*`。
没装：物理键全覆盖。

---

## 3. 架构（v2.1, with 2026-05-28 amendments)

⚠️ The pre-2026-05-28 diagram below is **archaeological**. Actual current architecture:
- `HudActivity` is **DELETED** (was: transparent fullscreen Activity). Replaced by `GlassHudOverlay` — a SYSTEM_ALERT_WINDOW host that attaches/detaches a ComposeView on state transitions.
- `ConstellationService` FGS type is `microphone|camera` (not `connectedDevice` — that turned out to be the wrong type; `camera` is needed for the photo shortcut path).
- All HUD rendering goes through shared `app/src/main/.../hud/composables/AppStateHud.kt` (`CardFrame` wrapping per-state composables).
- Camera flows route through `CameraGate.captureViaGate(ctx)` (transparent gate Activity) — see §C-51 banner at top.

Treat the diagram below as v2.1-original; the [HANDOFF.md §3.2 module map](../../HANDOFF.md) is the up-to-date layout.

```
┌──────────── Rokid Glasses (YodaOS-Sprite / Android Go) ────────────────┐
│                                                                          │
│  ConstellationService (ForegroundService, type=microphone|camera)        │
│  ├── ⚠ HudActivity (DELETED 2026-05-28 — now GlassHudOverlay SYSTEM_ALERT_WINDOW) │
│  │   └── HudComposeView                                                  │
│  ├── SystemKeyReceiver (BroadcastReceiver — registers SPRITE_BUTTON_*)   │
│  ├── AudioPipeline (AudioRecord 8-ch 0x6000FC → deinterleave → WSS)      │
│  ├── WssClient (OkHttp WebSocket → wss://edge.example.com/ws/glass)   │
│  ├── StateMachine — IDLE / LISTENING / THINKING / CARD / INSIGHT / OFFLINE│
│  └── HaloPlugin (optional — actions provider + trigger receiver)         │
│                                                                          │
│  Module map:                                                             │
│  ─ core/         pure logic, no Android-platform deps                    │
│  ─ glass/        AudioRecord 0x6000FC, SystemKeyReceiver, HudActivity    │
│  ─ phone-debug/  AudioRecord mono, SYSTEM_ALERT_WINDOW overlay, fake keys │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                                       │
                          Wi-Fi · public TLS WSS
                                       ▼
              ┌─────────────────────────────────────────────────┐
              │  Linux Edge @ edge.example.com                │
              │   cookie-authed WSS proxy → <mac-host> (Mac) │
              └─────────────────────────────────────────────────┘
                                       │
                                       ▼
              ┌─────────────────────────────────────────────────┐
              │  Cortex (Mac mini @ <mac-host>)              │
              │   handle_glass + audio_chunk + WhisperPipeline  │
              │   + Level-2 partial transcripts                 │
              └─────────────────────────────────────────────────┘
```

### 3.1 模块拆分 — 手机调试 vs 眼镜裸机

**核心原则**：眼镜端 SDK（0x6000FC、系统按键广播）跟手机端没有的；这些走 adapter，互相隔离。

```
app/
├── src/main/                       (shared — common manifest, themes, res)
├── src/glass/                      (productFlavor=glass)
│   ├── kotlin/com/constellation/glass/
│   │   ├── audio/GlassAudioSource.kt          (0x6000FC channel mask)
│   │   ├── input/SystemKeyReceiver.kt         (broadcasts)
│   │   ├── hud/HudActivity.kt                  (fullscreen Activity)
│   │   └── HudPlatformAdapter.kt (impl)
│   └── AndroidManifest.xml                    (FGS microphone)
├── src/phoneDebug/                 (productFlavor=phoneDebug)
│   ├── kotlin/com/constellation/glass/
│   │   ├── audio/PhoneAudioSource.kt          (CHANNEL_IN_MONO)
│   │   ├── input/DebugKeyReceiver.kt          (notification-action triggers)
│   │   ├── hud/PhoneDebugOverlay.kt           (SYSTEM_ALERT_WINDOW)
│   │   └── HudPlatformAdapter.kt (impl)
│   └── AndroidManifest.xml                    (SYSTEM_ALERT_WINDOW)
└── src/main/kotlin/com/constellation/glass/
    ├── core/state/                            (StateMachine, AppState)
    ├── core/wss/                              (WssClient, Frames, Cookie)
    ├── core/audio/                            (AudioChunker, RmsCalculator)
    ├── core/hud/                              (HudSurface interface, ScrollWindow, styled runs)
    ├── core/auth/                             (CortexAuth, CookieStore)
    ├── core/HudPlatformAdapter.kt (interface)
    └── ConstellationService.kt                (calls HudPlatformAdapter.create())
```

**编译时排除**：
- `glass` flavor 不编译 phoneDebug 代码（不含 SYSTEM_ALERT_WINDOW 权限）
- `phoneDebug` flavor 不编译 glass 代码（不能用 0x6000FC，不监听系统广播——会拿不到）

**HudPlatformAdapter 接口**：

```kotlin
interface HudPlatformAdapter {
    fun createHudSurface(): HudSurface           // glass: HudActivity, phone: SYSTEM_ALERT_WINDOW
    fun createAudioSource(): AudioSource         // glass: 0x6000FC, phone: mono
    fun installInputListener(handler: InputHandler)  // glass: BroadcastReceiver, phone: notif-action
    fun displaySize(): Size                      // glass: 480×640, phone: actual
}
```

`ConstellationService.onCreate()` 调 `HudPlatformAdapter.create(applicationContext)`，里面由 flavor 决定具体实现。**core 模块不知道平台**。

**phone-debug 用途**（很重要）：
- 验证 state machine + WSS + 协议变更
- 调 HUD 样式（虽然手机不是单色绿，看个大概）
- 验证 audio_chunk / audio_end 完整路径，不依赖真机
- **不验证**：物理按键真实行为、ChannelMask 0x6000FC、显示尺寸精确性、Sprite 抢占行为、电量

### 3.2 状态机（v2.1 — 输入语义换了）

```
                  CLICK (单击右键)
                ┌──────────────────────────────────┐
                ▼                                  │
   ┌─────────┐                                 ┌──┴──────────┐
   │  IDLE   │ ◄──────── DOUBLE_CLICK ──────── │ LISTENING   │
   │ HUD off │           (系统返回)             │ mic + PCM   │
   │ mic off │                                 │ + g-wave    │
   └──┬──────┘                                 └──┬──────────┘
      │ CLICK / LONG_PRESS                        │ CLICK (确认结束 mic)
      │                                           │ → THINKING (cortex 跑 whisper)
      │                                           │
      │      (server sends card)                  │
      └─────────────── ▶ CARD ◀───────────────────┘
                          │
              CARD options:
                CLICK         → Approve
                LONG_PRESS    → Modify (open mic → listening with cmd_id)
                DOUBLE_CLICK  → 系统返回 → Kill
                TWO_FINGER_SWIPE_BACK  → 向上翻页
                TWO_FINGER_SWIPE_FORWARD → 向下翻页

  Cross-cutting:
   ─ INSIGHT (transient from IDLE) — TWO_FINGER_SINGLE_TAP = engage
   ─ OFFLINE (WSS down overlay) — auto-exit on reconnect
```

**Mic 严格生命周期**（v2.1 能效核心）：
- mic 只在 **LISTENING** 状态打开
- 进入 LISTENING 唯一方式：用户 CLICK 触发（**没有后台监听 wake word**）
- 退出 LISTENING：用户 CLICK 再确认结束 → audio_end → THINKING
- 安全网：mic 开启超过 **15s** 强制关闭（hard cap）
- WSS 断开：mic 立即关
- 退出 LISTENING 状态：mic 必关

### 3.3 修订后的能效预算

| 组件 | 时机 | 耗电 estimation |
|---|---|---|
| Wi-Fi 持久连接 | 24/7 | 大头之一；OkHttp pingInterval 15s 保活 |
| HudActivity 渲染 | 仅 LISTENING/THINKING/CARD/INSIGHT/OFFLINE 状态 | IDLE 全黑（panel pixels off） |
| AudioRecord | 仅 LISTENING（≤15s/次） | 每次 ≈400mW；总开启时间 = 用户主动触发次数 × 平均时长 |
| ForegroundService | 24/7 | LOW priority notif, 无 CPU 拉满 |
| SystemKeyReceiver | 24/7 | 0（事件驱动，无 polling） |
| WSS update rate cap | THINKING 状态 ≤30Hz；其他状态被动接受 | 远低于面板 60Hz 上限 |
| **设计目标** | 待机 24h | ≤10% 电量损耗 |
| **设计目标** | 高频使用（每天 ~20 次触发） | ≤30% 电量损耗 |

(待机/活跃数字是目标，需要真机测才能确认)

---

## 4. 服务端契约（保持 v2.0 + Level 2）

无重大变更。事件清单（Glass → Cortex）：

| `kind` | payload | 触发 |
|---|---|---|
| `user_invoke` | `{text, session_id?, image?}` | (legacy text path) |
| `user_decision` | `{in_reply_to, decision, feedback_text?}` | CARD 按钮 |
| `audio_chunk` | `{stream_id, seq, b64_pcm, sample_rate, channels}` | LISTENING 每 250ms |
| `audio_end` | `{stream_id, duration_ms, lang_hint?}` | 用户确认结束 mic / 15s hard cap |
| `decision_voice` | `{cmd_id, command}` | (3b.3+; 物理键直接 → user_decision，可能不再需要 voice 通道) |
| `image_attached` | `{req_id, image}` | R-13 / C-55: 响应 `request_image` 命令；`image` 为 base64-encoded JPEG (CameraGate 拍照)；空串=tried-but-failed (Cortex 短路 10s timeout) |

命令（Cortex → Glass）：

| `kind` | payload | 触发 |
|---|---|---|
| `hud_state` | `{stage, icon, detail_runs, meta_runs}` | THINKING 进度 + LISTENING partial 转写 |
| `card` | `{cmd_id, title_runs, body_runs, scroll_total_lines, options}` | preview_action 等价 |
| `insight` | `{title_runs, body_runs, kind, ttl_ms}` | Insight Engine |
| `mic_open` | `{stream_id, lang_hint?, ttl_ms?}` | Card modify 时 server 让眼镜开 mic |
| `mic_close` | `{stream_id}` | server 明确关 mic（也作为 audio_end 之后的 ack） |
| `request_image` | `{req_id, parent_event_id, hint?}` | R-13 / C-55: Cortex 检测到语音 prompt 是视觉问题但 event 无 image 时主动拉照。Glass 必须在 `?accept=` 握手里 advertise `request_image` 否则 Cortex 端 `_emit_glass_frame` 静默 drop. Glass 响应 → `image_attached` event. |

⚠️ 注：v2.1 下 `decision_voice` 几乎不用 — 物理按键直接合成 `user_decision`，跳过语音通道。保留以备未来 Halo Ring 长按等触发。

---

## 5. Phase 计划修订

### 已完成（v2.0 时代，部分仍可复用）
- 3b.1 Skeleton + WSS + cookie auth ✅
- 3b.2 State machine + HUD（CXR-L customView 渲染）— **要重做为 Activity 渲染**
- 3b.4 部分（Glass-side AudioPipeline + Level 1 + 2，DEV_HEADLESS 验证过）— **AudioRecord 改 0x6000FC**

### 3b-pivot — 裸机重构（**新增，必做**）
- 删 CXR-L AAR 依赖、删 AuthorizationHelper / TokenStore
- 实现 `HudPlatformAdapter` 接口 + 两个 flavor 的实现
- 把 PhoneDebugHudSurface（SYSTEM_ALERT_WINDOW）→ phoneDebug flavor
- 实现 GlassHudActivity（Compose + 全屏 immersive + KEEP_SCREEN_ON）
- AudioRecord 改 ChannelMask=0x6000FC，做 deinterleave 取通道 0
- 实现 SystemKeyReceiver，订阅 SPRITE_BUTTON_* + TWO_FINGER_* 广播
- 屏幕尺寸 480×640 portrait 配置（layouts 调整）
- Manifest 改 FGS type、minSdk 检验、Android Go target

### 3b.3-pruned — Halo Ring（**简化**）
- HaloActionsProvider + HaloTriggerReceiver 保留（已经有 stub）
- 不再做 InstructSdk（依赖 Sprite，违反能效约束）
- 不再做 InstructHost / CommandRegistry

### 3b.5 — 真机部署 + 功耗 profile
- 用 SCRCPY 同屏开发
- 测 24h 待机功耗、5min 高频使用功耗
- 调整 WSS keepalive、HUD 更新频率

---

## 6. 不再做的（撤销 v2.0 设计）

- ❌ InstructSdk 接入（依赖 Sprite 长开，能效不允许）
- ❌ "Hi Rokid / 你好 / 嘿 Cortex" 唤醒词（同上）
- ❌ CXR-L AAR 依赖
- ❌ AuthorizationHelper / 眼镜端 Rokid token 流程
- ❌ CustomView JSON 渲染层
- ❌ 自定义激活词配置 (`active_word_config.json`)
- ❌ 与系统 Sprite assistant 协调（我们假设 Sprite 可被用户关掉，但即使开着也不冲突，因为长按触控板是系统操作）

---

## 7. 主要风险 + 缓解（v2.1）

| 风险 | 缓解 |
|---|---|
| 双击右镜腿 = 退出 Constellation（系统不可拦截） | Activity `onPause` 落 Service 后台保活；用户重新单击键即可恢复 |
| 用户误长按触控板 → 跳到 Sprite | 在文档说明、HUD 角标提示"长按触控板=系统 AI" |
| Android Go 内存压力 | 用 Compose 但限制视图深度；图片资源用 vector drawable；JSON 解析用 Streaming |
| 8 通道 PCM 的 deinterleave 开销 | 在 Dispatchers.IO 做；用 byte array 直接位移，避免 short[] 装箱 |
| 需要专用开发线才能 adb | 一次性配置；后续 dev 用 `adb tcpip` over Wi-Fi 应该可以（待验证） |
| 480×640 太窄 | 单色绿 panel 本来就是这个分辨率；UI 紧凑设计而非铺满 |
| Sprite 服务被用户关了之后某些系统功能可能也跟着没（比如 Rokid AI App 在手机端的桥接） | 我们不依赖任何 Sprite 桥接路径，所以不影响 |

---

## 8. 设计决策记录（DECISIONS）

| 日期 | 决策 | 原因 |
|---|---|---|
| 2026-05-26 | v2.1 全面切裸机路径 | CXR-L 实际运行在手机端，跟我们眼镜端 HUD 目标不符；裸机更简单更节能更标准 |
| 2026-05-26 | 不用 InstructSdk | 需要 Sprite 长期监听，与能效第一冲突 |
| 2026-05-26 | 物理键为主输入 | Rokid Glasses 提供完整的 BroadcastReceiver 按键路径，Service 即可接收 |
| 2026-05-26 | 屏幕 480×640 portrait | 官方裸机文档明确数值 |
| 2026-05-26 | AudioRecord 8 通道 0x6000FC，取通道 0 | 官方裸机文档 + 利用硬件 iFlytek NR/AEC |
| 2026-05-26 | Mic 15s hard cap | 能效兜底；用户主动确认结束 mic 是默认路径 |
| 2026-05-26 | Edge cookie 鉴权保持 | 与 Console 同套基础设施 |
| 2026-05-26 | 手机 debug flavor 用 SYSTEM_ALERT_WINDOW | 验证 state machine / WSS 协议时的轻量手段，不需要真机 |

---

## 9. 上下文索引

- 完整 SDK 与文档地图：[reference/INDEX.md](../../reference/INDEX.md)
- 关键事实速查：
  - 裸机概述：[reference/rokid-glass/bare-metal-docs/00-overview.md](../../reference/rokid-glass/bare-metal-docs/00-overview.md)
  - 按键广播：[reference/rokid-glass/bare-metal-docs/01-key-events.md](../../reference/rokid-glass/bare-metal-docs/01-key-events.md)
  - 音频管线：[reference/rokid-glass/bare-metal-docs/02-audio-recording.md](../../reference/rokid-glass/bare-metal-docs/02-audio-recording.md)
  - 路径对比：[reference/rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md](../../reference/rokid-glass/bare-metal-docs/04-cxrl-vs-baremetal-decisive.md)
- v2.0 备份：已删除（2026-05-26 doc reorg）；如需查看，`git log --all --source -- GLASS-CLIENT-DESIGN.v2.0.md.bak` 可恢复。v2.0→v2.1 差异见 [MIGRATION-PLAN.md](MIGRATION-PLAN.md)。

---

**Implementation pivot: 现有 `Constellation-Glass` 代码 ~70% 复用**（state machine、WSS、audio chunking、styled runs renderer），需要重写的部分是 HUD adapter、AudioSource adapter、Input adapter，外加删除 CXR-L 依赖。详见后续 `MIGRATION-PLAN.md`（待写）。
