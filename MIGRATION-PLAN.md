# MIGRATION-PLAN — Constellation-Glass v2.0 → v2.1 (裸机)

**Status**: planning (2026-05-26)
**Companion docs**: [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 · [reference/INDEX.md](reference/INDEX.md)
**Scope**: 把现有 `Constellation-Glass` 仓库从"CXR-L 桥接路径"重构为"裸机直装路径"，同时引入 `glass` / `phoneDebug` 双 productFlavor 隔离

---

## 0. 一句话总结

**保留 70% 的代码**（state machine、WSS、audio chunking、styled runs 渲染、cookie auth）。
**删 / 重写 30%**（CXR-L 集成、AuthorizationHelper、CustomView JSON 渲染、AudioSource、Input）。
**新增**：`HudPlatformAdapter` 接口 + 两个 flavor 实现。

---

## 1. 目标仓库结构

```
Constellation-Glass/
├── app/
│   ├── build.gradle.kts                ◀── 改：productFlavors (glass, phoneDebug)
│   └── src/
│       ├── main/                       ◀── 共享代码 (core/)
│       │   ├── AndroidManifest.xml     ◀── 改：删 CXR-L meta-data
│       │   ├── kotlin/com/constellation/glass/
│       │   │   ├── core/               ◀── 新：核心逻辑，零平台依赖
│       │   │   │   ├── state/
│       │   │   │   ├── wss/
│       │   │   │   ├── audio/
│       │   │   │   │   ├── AudioSource.kt          (interface)
│       │   │   │   │   ├── AudioChunker.kt         (复用现有 base64 chunking)
│       │   │   │   │   └── RmsCalculator.kt        (Level 1 amplitude)
│       │   │   │   ├── hud/
│       │   │   │   │   ├── HudSurface.kt           (interface, 已有)
│       │   │   │   │   ├── ScrollWindow.kt         (复用)
│       │   │   │   │   ├── StyledRunsRenderer.kt   (复用)
│       │   │   │   │   └── HudLayoutSpec.kt        (新：纯数据，无 SDK)
│       │   │   │   ├── input/
│       │   │   │   │   └── InputHandler.kt         (interface)
│       │   │   │   ├── auth/
│       │   │   │   │   ├── CortexAuth.kt           (复用)
│       │   │   │   │   └── CookieStore.kt          (复用)
│       │   │   │   ├── HudPlatformAdapter.kt       (新：接口)
│       │   │   │   └── ConstellationService.kt     (改：用 adapter)
│       │   └── res/                    ◀── 改：480x640 配色 + 共享 string
│       │
│       ├── glass/                      ◀── 新：眼镜端 productFlavor
│       │   ├── AndroidManifest.xml     ◀── 新：FGS microphone, key broadcasts
│       │   └── kotlin/com/constellation/glass/glass/
│       │       ├── audio/GlassAudioSource.kt        (0x6000FC, deinterleave ch0)
│       │       ├── input/SystemKeyReceiver.kt      (BroadcastReceiver)
│       │       ├── hud/GlassHudActivity.kt          (Compose 全屏 immersive)
│       │       ├── hud/GlassHudSurface.kt           (HudSurface impl)
│       │       └── GlassPlatformAdapter.kt          (HudPlatformAdapter impl)
│       │
│       ├── phoneDebug/                 ◀── 新：手机调试 productFlavor
│       │   ├── AndroidManifest.xml     ◀── 新：SYSTEM_ALERT_WINDOW
│       │   └── kotlin/com/constellation/glass/phonedebug/
│       │       ├── audio/PhoneAudioSource.kt        (CHANNEL_IN_MONO)
│       │       ├── input/DebugKeyReceiver.kt        (notification action triggers)
│       │       ├── hud/PhoneDebugOverlay.kt         (SYSTEM_ALERT_WINDOW)
│       │       ├── hud/PhoneDebugHudSurface.kt      (现有的，迁过来)
│       │       └── PhoneDebugPlatformAdapter.kt     (HudPlatformAdapter impl)
│       │
│       └── debug/                      (Android buildType, 不动)
└── reference/                          (1.1 GB SDK clones, gitignored)
```

---

## 2. 删除清单

**必删（不再用）**：

| 文件 | 删除原因 |
|---|---|
| `app/build.gradle.kts` 里的 `com.rokid.cxr:client-l:1.0.1` dep | 不再用 CXR-L |
| `app/src/main/kotlin/com/constellation/glass/hud/HudRenderer.kt` | CXR-L customView 渲染层 |
| `app/src/main/kotlin/com/constellation/glass/hud/LinearLayoutProps.kt` | CXR-L JSON schema |
| `app/src/main/kotlin/com/constellation/glass/hud/TextViewProps.kt` | 同上 |
| `app/src/main/kotlin/com/constellation/glass/hud/SelfViewJson.kt` | 同上 |
| `app/src/main/kotlin/com/constellation/glass/TokenStore.kt` | Rokid 不需要 |
| `app/src/main/AndroidManifest.xml` 里 Rokid auth meta-data | 不需要 |
| `app/src/main/kotlin/com/constellation/glass/MainActivity.kt` 里 Rokid 授权流程分支 | 简化为只剩密码登录 |
| `app/src/main/kotlin/com/constellation/glass/hud/HudLayouts.kt` JSON 部分 | 改为纯数据 spec |

**必删（CXR-L 相关 import）**：
- 任何 `import com.rokid.cxr.link.*`
- 任何 `import com.rokid.sprite.aiapp.externalapp.auth.*`

---

## 3. 重命名 / 移动清单

| 现在 | 改后 |
|---|---|
| `hud/HeadlessHudSurface.kt` | 删除 — 手机调试用 PhoneDebugHudSurface |
| `hud/PhoneDebugHudSurface.kt` | 移到 `phoneDebug/.../hud/PhoneDebugHudSurface.kt` |
| `audio/AudioPipeline.kt` | 拆：核心 chunking 留 `core/audio/AudioChunker.kt`，AudioRecord 部分进 flavor |
| `hud/HudSurface.kt` | 移到 `core/hud/HudSurface.kt`（保持接口不变） |
| `hud/HudRenderer.kt` | 删除 |
| `hud/HudLayouts.kt` | 拆：常量 + spec 留 `core/hud/HudLayoutSpec.kt`；CXR-L JSON 生成代码删除 |
| `hud/StyledRunsRenderer.kt` | 移到 `core/hud/` |
| `hud/ScrollWindow.kt` | 移到 `core/hud/` |
| `auth/*.kt` | 移到 `core/auth/` |
| `state/*.kt` | 移到 `core/state/` |
| `wss/*.kt` | 移到 `core/wss/` |

---

## 4. 新建清单

### 4.1 核心接口（main/core/）

**`HudPlatformAdapter.kt`** — 平台抽象接口：

```kotlin
package com.constellation.glass.core

import com.constellation.glass.core.audio.AudioSource
import com.constellation.glass.core.hud.HudSurface
import com.constellation.glass.core.input.InputHandler

interface HudPlatformAdapter {
    /** Build the HUD surface (eyepiece Activity OR phone overlay). */
    fun createHudSurface(): HudSurface
    /** Build the audio source (glass: 0x6000FC, phone: mono). */
    fun createAudioSource(): AudioSource
    /** Install the input listener (glass: BroadcastReceiver, phone: stub). */
    fun installInputListener(handler: InputHandler)
    /** Detach input listener (paired with install). */
    fun uninstallInputListener()
    /** Display dimensions in dp. */
    fun displaySizeDp(): IntArray // [width, height]

    companion object {
        /** Resolved at runtime from BuildConfig.PLATFORM flavor. */
        fun create(context: android.content.Context): HudPlatformAdapter = createPlatformAdapter(context)
    }
}
```

`createPlatformAdapter(context)` 是顶级函数，由 flavor source set 提供具体实现：
- `glass/.../GlassPlatformAdapter.kt` 提供 `internal fun createPlatformAdapter(ctx) = GlassPlatformAdapter(ctx)`
- `phoneDebug/.../PhoneDebugPlatformAdapter.kt` 提供 `internal fun createPlatformAdapter(ctx) = PhoneDebugPlatformAdapter(ctx)`

### 4.2 AudioSource 接口

**`core/audio/AudioSource.kt`**：

```kotlin
package com.constellation.glass.core.audio

import kotlinx.coroutines.flow.SharedFlow

interface AudioSource {
    /** Start capture. Idempotent. */
    fun start()
    /** Stop capture. Idempotent. */
    fun stop()
    /** True while capturing. */
    val isCapturing: Boolean
    /** Chunks of mono 16kHz 16-bit PCM, deinterleaved to single channel. */
    val chunks: SharedFlow<ShortArray>  // 250ms chunks = 4000 samples
}
```

Glass impl 用 0x6000FC 拿 8 通道，每次 read 拿 N samples × 8 channels；deinterleave 取 channel 0 → 发 ShortArray。
Phone impl 用 `CHANNEL_IN_MONO` 拿单声道，直接发。

### 4.3 InputHandler 接口

**`core/input/InputHandler.kt`**：

```kotlin
package com.constellation.glass.core.input

interface InputHandler {
    /** Single primary button click. */
    fun onPrimaryClick()
    /** Long-press primary button. */
    fun onPrimaryLongPress()
    /** Double-click primary button (glass: 系统返回不可拦截; phone: 用 notification action 模拟). */
    fun onPrimaryDoubleClick()
    /** Two-finger gestures (glass only; phone stubs). */
    fun onTwoFingerSwipeForward()
    fun onTwoFingerSwipeBack()
    fun onTwoFingerSingleTap()
    fun onTwoFingerDoubleTap()
    /** Settings entry. */
    fun onSettingsKey()
}
```

`ConstellationService` 实现这个接口，路由到 `StateMachine`。

### 4.4 Glass 端实现

**`glass/.../audio/GlassAudioSource.kt`**：

```kotlin
package com.constellation.glass.glass.audio

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import com.constellation.glass.core.audio.AudioSource
// ...

class GlassAudioSource(private val ctx: Context, private val scope: CoroutineScope) : AudioSource {
    private val ROKID_CHANNEL_MASK = 0x6000FC
    private val CHANNELS_PER_FRAME = 8  // 0/1 = algo, 2-5 = raw mics, 6/7 = echo ref
    private val SAMPLE_RATE = 16000
    private val CHUNK_SAMPLES = 4000  // 250ms per channel

    override fun start() {
        val rec = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.MIC)
            .setAudioFormat(AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(ROKID_CHANNEL_MASK)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build())
            .build()
        rec.startRecording()
        scope.launch(Dispatchers.IO) {
            val raw = ShortArray(CHUNK_SAMPLES * CHANNELS_PER_FRAME)  // 8-ch interleaved
            val mono = ShortArray(CHUNK_SAMPLES)
            while (active) {
                val n = rec.read(raw, 0, raw.size)
                if (n <= 0) continue
                // Deinterleave: take channel 0 only (post-algorithm)
                val frames = n / CHANNELS_PER_FRAME
                for (i in 0 until frames) mono[i] = raw[i * CHANNELS_PER_FRAME]
                _chunks.tryEmit(mono.copyOf(frames))
            }
        }
    }
}
```

**`glass/.../input/SystemKeyReceiver.kt`**：

```kotlin
package com.constellation.glass.glass.input

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.constellation.glass.core.input.InputHandler

class SystemKeyReceiver(private val handler: InputHandler) : BroadcastReceiver() {
    companion object {
        const val A_CLICK = "com.android.action.ACTION_SPRITE_BUTTON_CLICK"
        const val A_LONG  = "com.android.action.ACTION_SPRITE_BUTTON_LONG_PRESS"
        const val A_DBL   = "com.android.action.ACTION_SPRITE_BUTTON_DOUBLE_CLICK"
        const val A_TF_TAP   = "com.android.action.ACTION_TWO_FINGER_SINGLE_TAP"
        const val A_TF_DBL   = "com.android.action.ACTION_TWO_FINGER_DOUBLE_TAP"
        const val A_TF_FWD   = "com.android.action.ACTION_TWO_FINGER_SWIPE_FORWARD"
        const val A_TF_BACK  = "com.android.action.ACTION_TWO_FINGER_SWIPE_BACK"
        const val A_SETTINGS = "com.android.action.ACTION_SETTINGS_KEY"
    }

    override fun onReceive(ctx: Context?, intent: Intent?) {
        when (intent?.action) {
            A_CLICK -> { handler.onPrimaryClick();  abortBroadcast() }
            A_LONG  -> { handler.onPrimaryLongPress(); abortBroadcast() }
            A_DBL   -> { handler.onPrimaryDoubleClick() /* 不可拦截 */ }
            A_TF_TAP   -> { handler.onTwoFingerSingleTap(); abortBroadcast() }
            A_TF_DBL   -> { handler.onTwoFingerDoubleTap(); abortBroadcast() }
            A_TF_FWD   -> { handler.onTwoFingerSwipeForward(); abortBroadcast() }
            A_TF_BACK  -> { handler.onTwoFingerSwipeBack(); abortBroadcast() }
            A_SETTINGS -> { handler.onSettingsKey(); abortBroadcast() }
        }
    }

    fun filter() = IntentFilter().apply {
        priority = 100
        addAction(A_CLICK); addAction(A_LONG); addAction(A_DBL)
        addAction(A_TF_TAP); addAction(A_TF_DBL)
        addAction(A_TF_FWD); addAction(A_TF_BACK); addAction(A_SETTINGS)
    }
}
```

**`glass/.../hud/GlassHudActivity.kt`**：

```kotlin
package com.constellation.glass.glass.hud

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.ui.window.layout.LayoutParams.FLAG_KEEP_SCREEN_ON

class GlassHudActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Fullscreen immersive
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContent { GlassHudCompose(/* stateflow injected from service via IBinder */) }
    }
}
```

通过 ServiceConnection / LocalBroadcast 把 `_state` StateFlow 从 Service 传给 Activity。

### 4.5 Phone Debug 端实现

**`phoneDebug/.../PhoneDebugPlatformAdapter.kt`** — wrap existing `PhoneDebugHudSurface`：

```kotlin
internal fun createPlatformAdapter(ctx: Context): HudPlatformAdapter =
    PhoneDebugPlatformAdapter(ctx)

class PhoneDebugPlatformAdapter(private val ctx: Context) : HudPlatformAdapter {
    override fun createHudSurface() = PhoneDebugHudSurface(ctx)
    override fun createAudioSource() = PhoneAudioSource(ctx, scope)
    override fun installInputListener(handler: InputHandler) {
        DebugKeyReceiver.install(ctx, handler)  // notification actions
    }
    override fun displaySizeDp() = intArrayOf(480, 640)  // pretend to be glass
}
```

**`phoneDebug/.../input/DebugKeyReceiver.kt`**：在持久通知里放几个按钮（Click / Long / Double / TF-fwd / TF-back / Settings），点击触发 InputHandler。

---

## 5. build.gradle.kts 改造

```kotlin
android {
    // ...
    flavorDimensions += "platform"
    productFlavors {
        create("glass") {
            dimension = "platform"
            applicationIdSuffix = ""  // com.constellation.glass
            buildConfigField("boolean", "IS_GLASS", "true")
            buildConfigField("String", "PLATFORM", "\"glass\"")
            minSdk = 28
            targetSdk = 32  // Android Go base
        }
        create("phoneDebug") {
            dimension = "platform"
            applicationIdSuffix = ".phonedebug"  // com.constellation.glass.phonedebug
            buildConfigField("boolean", "IS_GLASS", "false")
            buildConfigField("String", "PLATFORM", "\"phoneDebug\"")
            minSdk = 28
            targetSdk = 34  // newer phones
        }
    }
    // ...
}

dependencies {
    // 删除：implementation("com.rokid.cxr:client-l:1.0.1")
    // 保留其他...
}
```

每个 flavor 自动从 `src/glass/` 或 `src/phoneDebug/` 编译。

---

## 6. 迁移执行步骤（按依赖顺序）

### 步骤 0 — 备份与分支
```bash
cd ~/Code/Projects/Constellation-Glass
git checkout -b pivot/baremetal-v2.1
git tag v2.0-final main  # 备份切点
```

### 步骤 1 — gradle flavor 改造
1. 改 `app/build.gradle.kts`：加 productFlavors，删 CXR-L dep
2. 创建空目录 `src/glass/{kotlin,res}/` 和 `src/phoneDebug/{kotlin,res}/`
3. 创建 `src/glass/AndroidManifest.xml` 和 `src/phoneDebug/AndroidManifest.xml`（空 manifest 占位）
4. `./gradlew assembleGlassDebug` 和 `assemblePhoneDebugDebug` 都要 build 通过（虽然没新代码）

### 步骤 2 — 抽接口到 core/
1. 创建 `core/HudPlatformAdapter.kt` 接口
2. 创建 `core/audio/AudioSource.kt` 接口
3. 创建 `core/input/InputHandler.kt` 接口
4. 把 `state/*`、`wss/*`、`auth/*`、`hud/HudSurface.kt`、`hud/StyledRunsRenderer.kt`、`hud/ScrollWindow.kt` 移到 `core/`
5. `ConstellationService` 用 `HudPlatformAdapter.create(applicationContext)` 拿 adapter
6. Build 失败可预期（没 adapter 实现），先存编译错误清单

### 步骤 3 — 实现 PhoneDebug flavor（先做这个，因为更熟）
1. 移 `hud/PhoneDebugHudSurface.kt` → `phoneDebug/hud/`
2. 移 `audio/AudioPipeline.kt` 的 AudioRecord 部分 → `phoneDebug/audio/PhoneAudioSource.kt`
3. 写 `phoneDebug/PhoneDebugPlatformAdapter.kt`
4. 写 `phoneDebug/input/DebugKeyReceiver.kt`（带 notification action）
5. 写 `phoneDebug/AndroidManifest.xml`（SYSTEM_ALERT_WINDOW + RECORD_AUDIO + FOREGROUND_SERVICE_MICROPHONE）
6. `./gradlew assemblePhoneDebugDebug` 通过
7. 装到 OnePlus 9 上，验证旧行为还在（test_invoke → card → mic_open → ...）

### 步骤 4 — 实现 Glass flavor
1. 写 `glass/audio/GlassAudioSource.kt`（0x6000FC deinterleave）
2. 写 `glass/input/SystemKeyReceiver.kt`
3. 写 `glass/hud/GlassHudActivity.kt` + `GlassHudSurface.kt`（Compose 渲染）
4. 写 `glass/GlassPlatformAdapter.kt`
5. 写 `glass/AndroidManifest.xml`（FGS microphone, 不要 SYSTEM_ALERT_WINDOW）
6. `./gradlew assembleGlassDebug` 通过
7. （暂不真机；等 Halo Ring 等其他准备完）

### 步骤 5 — 清理
1. 删 `R08-dev/refs/sdks/rokid/CXR-L SDK/cxrlsample101` 依赖（如有）
2. 删 `app/src/main/kotlin/com/constellation/glass/hud/HudRenderer.kt`
3. 删 `TokenStore.kt`
4. 删 `MainActivity.kt` 里 Rokid auth 路径
5. 删 `AndroidManifest.xml` 里 `com.rokid.ai.skill.local.*` meta-data
6. `./gradlew assembleGlassDebug assemblePhoneDebugDebug` 两 flavor 都通过

### 步骤 6 — 验证
1. PhoneDebug：装机，跑完整 E2E（之前验证过的 Level 1/2 流程）
2. Glass：跑单元测试（state machine、deinterleave、frame 解析）
3. Git tag `v2.1-pivot-complete`

---

## 7. 验证清单（每步必通过）

- [ ] 步骤 1 后：两个 flavor 都能空 build
- [ ] 步骤 2 后：core 模块编译通过；ConstellationService 链接报错可接受
- [ ] 步骤 3 后：phoneDebug flavor 完整 build + 装 OnePlus 9 + 跑 test_invoke E2E 验证通过
- [ ] 步骤 4 后：glass flavor 完整 build（不需要装机）
- [ ] 步骤 5 后：两 flavor 都 build；grep `com.rokid.cxr` 应返回 0
- [ ] 步骤 6 后：phoneDebug E2E 通过；glass 单测通过

---

## 8. 风险

| 风险 | 缓解 |
|---|---|
| productFlavor 拆分破坏现有 build | 步骤 1 强制空 flavor 先 build 过 |
| Compose 在 Android Go 上内存压力 | 步骤 4 用最简版本，避免动画 / 复杂 layout |
| 系统按键广播在某些 R08 固件版本不存在 | 真机才能验，先记入风险，到 3b.5 真机 deploy 时验 |
| 0x6000FC channel mask 在某些音频策略下被拒 | 同上；fallback 用单声道（不利用 iFlytek 但能跑） |
| HudActivity 跟系统其他 Activity 抢前台 | 单击按键时把 HudActivity 切回前台；double_click 让它回到 IDLE 让出前台 |

---

## 9. 估时

| 步骤 | 估时 |
|---|---|
| 0. 备份分支 | 5 min |
| 1. gradle flavor | 30 min |
| 2. core 接口 + 移动 | 1 h |
| 3. phoneDebug flavor 实现 + 验证 | 2 h |
| 4. glass flavor 实现 | 2 h |
| 5. 清理 | 30 min |
| 6. 验证 | 1 h |
| **总计** | **~7 h** |

---

## 10. 不在本次范围

- **Phase 3b.3 重做 Halo Ring profile push** — 等迁移完了再说
- **写 GlassHudCompose 的具体 UI** — 先用占位灰底，UI 风格后续设计
- **HudActivity ↔ Service 的 IPC 实现细节** — 用 LocalBroadcastManager 或 LiveData via bound service，二选一
- **App settings UI** — §2 的 shortcuts / connect 页面，未来 phase
- **Phase 3b.5 真机部署** — 等迁移完
