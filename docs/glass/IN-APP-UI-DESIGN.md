# Constellation-Glass — In-App UI Design (§2 of ui-mockup)

**Status**: design v2 — incorporates user direction "应用内设置跑在眼镜上，参考 Halo Ring 范式".
**Companion**: [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 · [GLASS-SDK-REFERENCE.md](GLASS-SDK-REFERENCE.md) · [Doc/ui-mockup.html §2](../../Doc/ui-mockup.html) · `~/Code/Projects/Halo-Ring/app-project/app/src/main/kotlin/com/halo/ring/ui/` (reference)

---

## 1. 范围 + 它**不**是什么

P1.6 完成了 HUD（眼镜端面板上的 6 个 state machine 状态）。**这份文档**说的是另一个表面 —— **用户打开 app 图标后进入的配置界面，跑在眼镜本机面板上**（不是甩到配对手机）。

| 表面 | 何时显示 | 谁绘制 | 状态 |
|---|---|---|---|
| **HUD** (`GlassHudActivity` + `AppStateHud` Compose) | Service 推 state 时 | Service-driven snapshot | ✅ P1.6 完成 |
| **In-App UI** (本文，`MainActivity` → settings NavHost) | 用户点 app 图标 / launcher 拉起时 | MainActivity-owned Compose | ⏸ 未开工 |

**它在眼镜上跑**：打开 app icon → MainActivity 全屏拉起 → 用**物理键**（CLICK / LONG / DOUBLE / TWO_FINGER_SWIPE_*）翻菜单 → 双击退出回 launcher。

**它不是什么**：
- ❌ 不甩到手机（眼镜端就能完整配置）
- ❌ 不在 HUD state machine 里（HUD 是瞬时状态机；settings 是独立 Activity / NavHost）
- ❌ 不是手势 / Halo Ring profile 编辑器（那住在 Halo Ring app 里）

**为什么改方向**：参考 Halo Ring 已有范式 —— Halo Ring 本身也是为小屏穿戴写的，但在 Rokid 眼镜上提供了完整的 11-section settings UI 用 `FocusableRow` + sealed-class `SubScreen` navigation。Constellation 沿用同套范式。

---

## 2. 关键决策（v2 修正）

| # | 决策 | 理由 |
|---|---|---|
| D1 | **Compose 渲染**（沿用 HUD 栈） | 单一 UI 栈；HudTheme 颜色/字号复用；no Material3 |
| **D2** ⚠️ 修正 | **glass flavor 是主战场**——in-app UI 完整跑在 Rokid Glasses 面板上 (480×640)。phoneDebug 同样 UI 镜像作为开发辅助。 | 用户直接定 "不可能 configure on phone"。Halo Ring 已证明小屏深 settings 可行。 |
| **D3** | **MainActivity → 持久 Compose NavHost** + `SubScreen` sealed-class 栈 | 现 MainActivity 是 one-shot launcher (login→finish)；需要变成可重入、可栈式 drill-in 的持久 Activity。Halo Ring 模式直接搬。|
| **D4 物理键导航** | 复用 Glass 的 SystemKeyReceiver；映射到 Compose 焦点 + 命令: `TWO_FINGER_SWIPE_FORWARD/BACK` = 焦点上/下 (`requestFocus` next/prev)；`CLICK` = 激活当前 `FocusableRow` (= onClick)；`LONG_PRESS` = 同 CLICK 备用；`DOUBLE_CLICK` = back (pop nav stack；空栈则退到 launcher) | C-38 已定的物理键映射就是这些。无键盘、无触屏 = 焦点 + 单按键确认是唯一可行模式。Halo Ring 的 `FocusableRow` 就是 explicitly 设计给这套。|
| **D5 存储** | Cookie / endpoint URL / app prefs = DataStore；shortcuts = Cortex Twin (`twin/skills/shortcuts.md`) | endpoint runtime 可改 (你已确认)；shortcuts 走 Twin 因为 Cortex router + Halo Ring ContentProvider 都要读 |
| **D6 Service handoff** | MainActivity onResume → Service "暂停"HUD 推送 (state stays Idle)；MainActivity onPause → Service 立即恢复 | 同一块 panel 同一时刻只能渲染一个东西。MainActivity 前台时占面板做 settings；用户双击退出后 Service 接管。|
| **D7 测试连接走 `/api/ping`** | 新加 Cortex 轻量 endpoint：`POST /api/ping` → 立即 `{ok, server_bound, tool_conn, ts}`。Connect 屏 "TEST CONNECTION" 调它。 | 你已确认。不触发 router / dispatch；几毫秒返回；和 `GET /api/health` 等价但 `POST` 把它当成 "user action" 记一次 metric。|
| **D8 Halo Ring hint 文案** | 主屏底部改写为 "Pair Halo Ring for ring-gesture shortcuts" | 你已确认；optional enhancement 定位 |

---

## 3. 信息架构

```
MainActivity (Compose NavHost; 持久；接管 panel)
│
├─ Login (sealed-class state: NotLoggedIn) ──┐  ← 第一次启动，无 cookie 时
│  - 密码输入 (TYPE_TEXT_VARIATION_PASSWORD)  │
│  - 单按 CLICK = submit                     │
│  - 成功 → 转 Main                          │
│                                            │
└─ Authenticated (state: LoggedIn) ──────────┘
   │
   └─ NavStack (LIFO of SubScreen)
      │
      ├─ Main          (route = Main)
      │  - Status block (live)
      │  - Drill-in rows (Shortcuts / Connect / About / Shortcuts-bind-hint)
      │
      ├─ Connect       (route = Connect)
      │  - Endpoint URL (read-only display + [EDIT])
      │  - Connection status / last invoke
      │  - [TEST CONNECTION] CTA
      │
      ├─ EditEndpoint  (route = EditEndpoint)
      │  - Text input for new URL
      │  - [SAVE] / [CANCEL]
      │
      ├─ About         (route = About)
      │  - app name / version / flavor / git sha
      │  - "Open source" + repo
      │  - "by Zack 紫意"
      │
      ├─ ShortcutsList (route = Shortcuts)         ← P3
      │  - Saved shortcuts (FocusableRow each)
      │  - [+ NEW SHORTCUT]
      │
      └─ ShortcutEditor(route = ShortcutEdit{id})  ← P3
         - Name field
         - Preset prompt (multi-line)
         - Capture toggles (photo / mic)
         - [SAVE] / [DELETE]
```

**Back semantics**: DOUBLE_CLICK pops one entry off NavStack. Empty stack + DOUBLE_CLICK = `moveTaskToBack(true)` → 返回 launcher。**Service 不退**——后台继续维持 WSS。

---

## 4. 物理键 → Compose 焦点桥接

复用 Halo Ring 的 `TempleFocusBridge` 模式（按键事件 → Compose `FocusManager` 调用）。

```kotlin
// MainActivity 内 registerReceiver
when (key) {
    SPRITE_BUTTON_CLICK         -> focusedRowOnClick()  // 激活当前焦点
    SPRITE_BUTTON_LONG_PRESS    -> focusedRowOnClick()  // 备用，同 CLICK
    SPRITE_BUTTON_DOUBLE_CLICK  -> popNavStackOrExit()
    TWO_FINGER_SWIPE_FORWARD    -> focusManager.moveFocus(FocusDirection.Down)
    TWO_FINGER_SWIPE_BACK       -> focusManager.moveFocus(FocusDirection.Up)
    TWO_FINGER_SINGLE_TAP       -> /* P3: 次选 / context action */
    TWO_FINGER_DOUBLE_TAP       -> popNavStackOrExit()  // 备用 back
}
```

Compose 端用 `FocusableRow`（直接抄 Halo Ring 的 `Components.kt`，去掉 Material3 import 改成 BasicText）：
- 每行 `Modifier.onFocusChanged + clickable + 视觉高亮`
- `clickable` 隐含 `focusable`；DPAD 系统按键 `DPAD_CENTER` 自动触发 onClick
- 焦点高亮 = 2dp 左侧绿条 + 7% 绿底色

**HudHud 同 Activity 的关系**：见 §6 Service handoff。

---

## 5. 屏幕级 Compose 设计

### 5.1 共享 chrome (`AppChrome.kt`)

```kotlin
@Composable
fun AppChrome(
    title: String,
    onBack: (() -> Unit)? = null,
    cortexConnected: Boolean,
    content: @Composable () -> Unit,
) {
    Column(Modifier.fillMaxSize().background(Color.Black).padding(16.dp)) {
        Row {
            ConnectionDot(connected = cortexConnected)
            Spacer(Modifier.width(8.dp))
            BasicText("Constellation",
                      style = TextStyle(fontSize = HudTheme.metaSize, color = HudTheme.fg))
            Spacer(Modifier.weight(1f))
            BasicText(title,
                      style = TextStyle(fontSize = HudTheme.footerSize, color = HudTheme.fgDim))
        }
        Spacer(Modifier.height(16.dp))
        content()
    }
}
```

### 5.2 MainScreen.kt（mockup §2.1）

```
┌──────────────────────────────┐
│ ● Constellation         MAIN │  ← chrome (live ●)
├──────────────────────────────┤
│ ╔══════════════════════════╗ │
│ ║ ● Connected to Cortex    ║ │  ← status block (focusable;
│ ║ wss://edge.example…  ║ │     CLICK → Connect screen)
│ ║ 12 invokes · 3 min ago   ║ │
│ ╚══════════════════════════╝ │
│                              │
│ ▌ Shortcuts          3 ›    │  ← FocusableRow x4
│   Connect to Cortex     ›    │
│   About                 ›    │
│                              │
│ Pair Halo Ring for           │  ← bottom hint (dim, not focusable)
│ ring-gesture shortcuts       │
└──────────────────────────────┘
```

Status block 自己也是 `FocusableRow`（CLICK = drill into Connect）—— 单一 entry point 不重复。

### 5.3 ConnectScreen.kt（mockup §2.4）

```
┌──────────────────────────────┐
│ ←● Constellation     CONNECT │
├──────────────────────────────┤
│ Connect to Cortex            │
│ Edge endpoint — WSS to Mac.  │
│                              │
│ ╔══════════════════════════╗ │
│ ║ wss://edge.example.com║ │  ← FocusableRow (CLICK = EditEndpoint)
│ ║ /ws/glass                ║ │
│ ╚══════════════════════════╝ │
│                              │
│ Status:        ● connected   │  ← live, polls /api/ping every 5s
│ Cookie:        persisted ✓   │
│ Last invoke:   3 min ago     │
│                              │
│ ┃ TEST CONNECTION    ┃       │  ← Cta button (focusable)
└──────────────────────────────┘
```

`TEST CONNECTION` 调 `POST /api/ping`，5s 超时；返回结果通过短暂的"toast"行（fixed位置，2s 自动消失）显示。

**No logout**: per user direction 2026-05-26 — 第一次登录后 cookie 永久有效；不提供清除入口。如果将来需要换账号，卸载重装。

### 5.4 EditEndpointScreen.kt

简单单行 BasicTextField + [SAVE] / [CANCEL]。SAVE = 写入 DataStore，然后 push 事件给 ConstellationService 重连 WSS。

### 5.5 AboutScreen.kt

```
┌──────────────────────────────┐
│ ←● Constellation       ABOUT │
├──────────────────────────────┤
│ Constellation                │
│ v0.2.0-pivot-baremetal       │
│ flavor: glass · sha: a921cbe │
│                              │
│ A constellation of senses,   │
│ one mind.                    │
│                              │
│ by Zack 紫意                  │
│                              │
│ Free & open source           │
│ github.com/MRziyi/…          │
└──────────────────────────────┘
```

无 focusable rows（信息屏）。CLICK 在此屏 = 空操作；DOUBLE = back.

### 5.6 LoginScreen.kt

单密码字段（沿用现 MainActivity 的密码输入逻辑），CLICK 在 input 内 = submit。

---

## 6. Service ↔ MainActivity handoff

同一块 480×640 panel 同一时刻只能渲染一个 Activity。问题：MainActivity 在前台时，Service 推 `hud_state` 让 `GlassHudActivity` 启动会**抢走 panel**。

**解决**：MainActivity 暴露一个静态 flag `MainActivity.isForeground: AtomicBoolean`。

- `MainActivity.onResume()`: `isForeground.set(true)`；可选广播 `INTENT_HUD_PAUSE` 让 Service 知道暂时不要 launch HUD Activity
- `MainActivity.onPause()`: `isForeground.set(false)`；Service 恢复正常
- `ConstellationService` 的 `GlassHudSurface.bringActivityToFront()` 加判断：
  ```kotlin
  private fun bringActivityToFront() {
      if (MainActivity.isForeground.get()) {
          Timber.i("GlassHudSurface · MainActivity foreground, skipping HUD launch")
          return  // 状态 snapshot 还是更新了；MainActivity 关闭后下次状态变化会重新 bring up
      }
      // ... 现有 startActivity
  }
  ```

这样 user 进 settings 不会被 HUD 弹出打断；退 settings 后下次 invoke 自然回 HUD。

---

## 7. Cortex 端 API 现状 + 需要补的

### 已有（够用）

| Endpoint | 用途 |
|---|---|
| `GET /api/health` | 主屏 status block 信息源（server_bound / tool_conn / stats.dispatches_total）|
| `POST /api/auth/login` | Login |
| `GET /api/sessions?status=active` | 拿 last invoke 时间戳 |

### Phase A 新增（小）

| Endpoint | 行为 |
|---|---|
| `POST /api/ping` | 立即返回 `{ok: true, server_bound, tool_conn, ts}`。**不**走 router / dispatcher。Connect 屏 TEST CONNECTION 调它。|

### Phase D 新增（shortcuts）

| Endpoint | 行为 |
|---|---|
| `GET /api/shortcuts` | 读 `~/constellation/twin/skills/shortcuts.md` 的 frontmatter list |
| `POST /api/shortcuts` | 新建 (name + prompt + capture flags) |
| `PUT /api/shortcuts/{id}` | 更新 |
| `DELETE /api/shortcuts/{id}` | 删除 |

**Twin shortcuts schema**:
```markdown
---
id: quick-capture-person
name: Quick capture person
photo: true
mic: false
created: 2026-05-26
---

Identify this person. If matches `people/core/`, surface archive.
If unknown, propose adding to `people/encounters.md`.
```

---

## 8. phoneDebug flavor

phoneDebug 的 in-app UI = **跟 glass flavor 完全相同的 Composable**，只是 host 是常规手机 Activity（无 panel 透明 theme，无 SystemKeyReceiver；用 touch 触发 onClick + 后退键 = DOUBLE 等价）。

**为什么不让 phoneDebug 享受触屏 native 体验？** 维护两套 UI 不划算。phoneDebug 的目的是开发回归——保证 settings UI 跟眼镜上看到的**一样**，反过来更好。Touch 等价于 CLICK + 后退键等价于 DOUBLE_CLICK。Swipe 用 LazyColumn 自然滚动取代 SWIPE_FORWARD/BACK 焦点切换。

---

## 9. 分阶段实施提议

| Phase | 内容 | 工时 | 价值 |
|---|---|---|---|
| **P-app.A 基础设施** | MainActivity → Compose NavHost；`SubScreen` sealed；`FocusableRow` 端口（去 Material3 → BasicText）；`AppChrome` 共享 frame；DataStore endpoint 持久化；LoginScreen + MainScreen + ConnectScreen + EditEndpointScreen + Service handoff (`isForeground` flag) | **6-8 h** | **必须做的** —— 没这层后面什么都进不去 |
| **P-app.B Cortex `/api/ping`** + TEST CONNECTION 接入 | Cortex 加 endpoint；Glass Connect 屏调它 | **1 h** | 高 —— Connect 屏才有用 |
| **P-app.C AboutScreen** | 静态信息屏 | **30 min** | 低 |
| **P-app.D Shortcuts** (大) | ShortcutsList + ShortcutEditor + Cortex `/api/shortcuts` (GET/POST/PUT/DELETE) + Twin `skills/shortcuts.md` schema + 解析器 + 写入器 + Halo Ring ContentProvider 注册（按现有 plugin protocol） | **1-2 day** | **高** —— mockup §2 主要功能 |

**推荐顺序**: A → B → C → D。A+B+C 是一个 sitting；D 单独成 ticket。

---

## 10. Open questions（剩 2 个）

- **OQ-app-1** ~~endpoint 编辑性~~ → 已定**可编辑**（D5）
- **OQ-app-2** ~~TEST 用哪个 endpoint~~ → 已定**新加 `/api/ping`**（D7）
- **OQ-app-3** ~~Logout~~ → **不做**。第一次登录持久；换账号靠卸载重装。
- **OQ-app-4** ~~Halo Ring hint 文案~~ → 已定 "Pair Halo Ring..."（D8）
- **OQ-app-5** Shortcuts 在 Halo Ring 视角下如何注册 → **协议清楚**：暴露 `HaloActionsProvider` ContentProvider 返回 cursor (`action_id=shortcut_<id>`, `label`, `group=shortcuts`)；接收端 `HaloTriggerReceiver` 监听 `com.halo.ring.action.TRIGGER` Intent。stubs 已在 `halo/` 目录，P-app.D 填实现即可。

---

## 11. 完成定义 + 验证记录

### ✅ P-app.A 完成 (commits `7cd9261` + `a64a5a5`)

- 眼镜 / 一加上打开 app icon → MainActivity 拉起 + 直接进 MainScreen
- Status block 实时反映 `/api/health`（绿/橙点 + endpoint snippet + invoke count）
- Connect 屏可看 / 改 endpoint，DataStore 持久化，编辑后 `ConstellationService.reconfigure()` 自动重连
- DOUBLE_CLICK (system back) 在 root 退到 launcher；MainActivity 前台时 GlassHudSurface + phoneDebug overlay 都让出面板
- 一加上同套 UI 用 touch + back 键操作可用
- glass + phoneDebug 两个 flavor 都 build clean

### ✅ P-app.B 完成 (Cortex `3fa38b7` + Glass part of `2fc8634`)

- Cortex 加 `POST /api/ping` 轻量 endpoint，不触发 router / dispatcher / LLM
- Glass `CortexPingClient` 调用 + 自动带 cookie（Edge gate all `/api/*`）
- TEST CONNECTION 按钮 → 4s 超时 → toast "pinging…" → "✓ ping ok · server_bound · tool_conn" → 4s 自动清除
- HealthClient 也补了 cookie（之前 Status block 因 401 一直显示 Offline）

### ✅ P-app.C 完成 (Glass part of `2fc8634`)

- AboutScreen：版本号 / flavor / 标语 / Halo Ring repo / 开源声明，全静态信息屏
- 自动从 BuildConfig 读 `VERSION_NAME` + `PLATFORM`

### ✅ P-app.D Shortcuts — landed 2026-05-26 (text-only fire; CameraX deferred)

Five sub-phases shipped:

| Phase | 内容 | 验证 |
|---|---|---|
| D.1 | Twin schema (`<!-- shortcut:start --> ...`) + 3 seed shortcuts (`whats-in-front` / `quick-capture-person` / `ocr-save-to-today`) — landed to live twin `~/constellation/twin/skills/shortcuts.md` | parser strips ```` ``` ```` code-fenced blocks → 3 entries parsed |
| D.2 | Cortex `shortcuts_store.py` + `/api/shortcuts` CRUD (GET/POST/PUT/DELETE). HTML-comment delimited blocks (per-block YAML frontmatter doesn't work for multi-block files). | full CRUD curl cycle verified |
| D.3 | Glass `ShortcutsClient` + `ShortcutsListScreen` (mockup §2.2) + `ShortcutEditorScreen` (mockup §2.3). MainActivity nav wiring + slugify helper for new ids. | live list shown on OnePlus 9; drill-in editor shows prompt + photo ON toggle correctly |
| D.4 | `HaloActionsProvider` returns `voice_invoke` + `kill_active` + one row per shortcut as `action_id="shortcut_<id>"`. Reads from new `ShortcutsLocalCache` (no network in `query()`). MainActivity writes cache after every list refresh. | `am broadcast` simulating Halo Ring → receiver fires |
| D.5.a | `ShortcutFireClient` + `HaloTriggerReceiver` wired. Text-only fire path: `shortcut_<id>` → cache lookup → POST `/api/test/invoke` with cookie. | full E2E from broadcast → HUD card (response: "no photo attached" — D.5.b TODO) |

### ✅ Phase Q — Camera (photo capture) + QR-code login — landed 2026-05-26 EOD

Eight sub-phases shipped after P-app.D.5.a, fulfilling the two carry-forward TODOs above (CameraX for photo shortcuts + on-eyewear login UX):

| Phase | 内容 | 验证 |
|---|---|---|
| Q.1 | `ConstellationService.startListening(ctx)` + `killActive(ctx)` static helpers via a volatile `instance` ref. `HaloTriggerReceiver` routes `voice_invoke` + `kill_active` to them. | `am broadcast voice_invoke` → Idle → Listening ✓ |
| Q.2 | CameraX 1.4.0 + ML Kit Barcode 17.3.0 + lifecycle-process + kotlinx-coroutines-guava deps. CAMERA runtime permission + **FOREGROUND_SERVICE_CAMERA** declared in main/glass/phoneDebug manifests. ConstellationService FGS type → `microphone\|camera` (Android 14+ blocks background camera access without it — confirmed via ERROR_CAMERA_DISABLED on first try). | Both flavors build clean |
| Q.3 | `camera/CameraCapture.kt` — headless one-shot photo. ProcessCameraProvider + one-shot LifecycleOwner (main-thread state transitions). Downscale to **1024px longest edge + JPEG q=80**: 1,799,426 B → 70,137 B (**25× reduction**, no visible quality loss for LLM vision). | 70 KB JPEG verified on OnePlus 9 |
| Q.4 | `ShortcutFireClient` photo path: `if (sc.photo) CameraCapture.capture(ctx)` → Base64 → `image` field on POST `/api/test/invoke`. **Service-mediated firing** (`ConstellationService.fireShortcut`) — the 10s BroadcastReceiver budget can't cover camera bring-up + capture + base64 + HTTP. Service uses its own CoroutineScope. | E2E: `am broadcast shortcut_whats-in-front` → capture → POST → HUD Thinking → Card. |
| Q.5 | `camera/QrScanner.kt` — Composable wrapping CameraX `PreviewView` via AndroidView + `ImageAnalysis` use case + ML Kit `BarcodeScanning` constrained to `FORMAT_QR_CODE`. First valid QR rawValue fires `onDetected` once. | Built; visual E2E pending Q.8 deploy |
| Q.6 | `LoginScreen` gains a `SCAN QR` button alongside AUTHORIZE (50/50 Cta row). `LoginGate` keeps a `scanning` state — when true, replaces LoginScreen with `QrScanLoginOverlay` (full-screen scanner + hint + CANCEL). QR payload parsed as `{endpoint, cookie_name, cookie_value}` JSON → writes both to EndpointStore + CookieStore → jumps to Main. | Built; visual E2E pending Q.8 |
| Q.7 | **Edge** `/api/auth/pair_qr` — auth-gated, derives endpoint from request Host header, returns `{endpoint, cookie_name, cookie_value}`. **Web Console** new `/about` route with `QRCodeSVG` 256×256 (white padding) + endpoint/cookie metadata + security warning. `qrcode.react` npm dep (via pnpm). Build green. | Pending deploy + scan E2E |
| Q.8 | Deploy edge + web + scan E2E on OnePlus 9 then Rokid Glasses | ⏸ **pending** |

### ✅ Q.4.5 — Cortex vision passthrough — landed 2026-05-26 EOD

Glass already shipped image bytes with the prompt via `image_b64` (Phase Q). Cortex now routes them correctly to a vision-capable tool. Architecture (refined): the dispatcher maintains a small allowlist `_VISION_AWARE_TOOLS = {"vision_describe"}`. The router (purely text-prompt-based decision) selects vision_describe when `(photo attached)` is present AND the prompt is vision-shaped. Only then does dispatcher inject `_image_b64` into the tool's args. All other routings — even photo-bearing — never see the image bytes (default-off guarantee against surprise vision API costs).

E2E verified on OnePlus 9: shortcut fire → CameraCapture 70KB JPEG → POST → classifier simple → router picks vision_describe → OpenAI gpt-5.2 multimodal → real prose description back to the HUD card.

Constellation-Server commits: `83bba42` (image gate) + `1250f74` (vision_describe adapter) + `948bad6` (router + classifier + token kwarg).

Glass-side requires zero changes — the Phase Q image plumbing already does the right thing.

---

## 12. 端到端真机验证日志（OnePlus 9, 854afb6b · Rokid Glasses <glass-serial>）

### P-app.A/B/C — Settings UI (OnePlus 9)

| 步骤 | 期望 | 结果 |
|---|---|---|
| Launch app (cookie 存在) | 跳过 Login，直接进 Main | ✅ |
| Main 顶部 Status block | "● Connected to Cortex" 绿点 | ✅ |
| Main → tap "Connect to Cortex" | 进 ConnectScreen | ✅ |
| Connect → tap endpoint URL | 进 EditEndpointScreen | ✅ |
| EditEndpoint → CANCEL | 回 Connect (栈 pop) | ✅ |
| Connect → tap TEST CONNECTION | toast "✓ ping ok · server_bound · tool_conn" | ✅ |
| Connect → system back | 回 Main | ✅ |
| Main → tap About | 进 AboutScreen，显示真版本号 | ✅ |
| About → system back | 回 Main | ✅ |
| Main → system back | `topResumedActivity=launcher`；Service 仍 alive | ✅ |
| Service 后台时，HUD overlay 自动重新 attach | foreground watcher 工作正常 | ✅ |

### P-app.D — Shortcuts (OnePlus 9)

| 步骤 | 期望 | 结果 |
|---|---|---|
| Main → tap Shortcuts | List 显示 3 个 seed shortcuts (`whats-in-front` / `quick-capture-person` / `ocr-save-to-today`) | ✅ |
| Tap 任一 shortcut | Editor 打开，prompt + photo ON 正确预填 | ✅ |
| Cortex `/api/shortcuts` GET/POST/PUT/DELETE | full CRUD cycle via curl | ✅ |
| `am broadcast TRIGGER --es action_id shortcut_whats-in-front` | Receiver 收到 → ShortcutFire (text-only D.5.a) → Cortex Card 响应 "no photo attached" (text path correct) | ✅ |
| `am broadcast shortcut_whats-in-front` **after Phase Q** | CameraCapture 70 KB JPEG → POST `/api/test/invoke` with `image` field → Cortex event_id returned | ✅ |

### P-app.Q — Camera + QR login

| 步骤 | 期望 | 结果 |
|---|---|---|
| `am broadcast voice_invoke` | StateMachine Idle → Listening | ✅ |
| `am broadcast kill_active` | StateMachine Listening → Idle | ✅ |
| Photo capture downscale | 1.7 MB → 70 KB at 1024px / q=80 | ✅ |
| FGS_CAMERA type declared | Service can keep camera in background | ✅ |
| QR scanner / SCAN QR button on LoginScreen | ✅ landed 2026-05-26 EOD — OnePlus: scanned QR in ~4s, app auto-jumped to Main, cookie+endpoint persisted, WSS reconnect + invoke+card all worked |
| Edge `/api/auth/pair_qr` | ✅ deployed 2026-05-26 EOD — returns 401 unauthed, JSON `{endpoint, cookie_name, cookie_value}` when session cookie present |
| Web Console `/about` QR render | ✅ deployed 2026-05-26 EOD — qrcode.react 256×256 rendered, scannable from OnePlus camera through Mac display |

### Rokid Glasses <glass-serial> — first device contact

| Step | Observation |
|---|---|
| `adb install` glass APK | Success (P1.5 baseline) |
| Launch MainActivity → LoginScreen render | **480 × 640 px, density 240 (hdpi)** — first real measurement of `Resources.getDisplayMetrics().densityDpi` on the panel. Logical content area = 320 × 426 dp. |
| Visual: Compose Login renders crisply | Title bold green + endpoint monospace + password field + AUTHORIZE button all legible at 480×640 |
| Cookie missing → expected Login | ✓ (no cookie carried from elsewhere) |

**Implications**:
- `HudTheme` dp values render at × 1.5 px (240 / 160 baseline). Our `panelWidthDp = 480.dp` constant is a misleading name — actual content area at density 240 is 320 dp. Doesn't break anything (we use `fillMaxSize()` for sizing) but should rename / comment for clarity.
- `cardBodyWrapChars = 42` was tuned on the OnePlus simulator. On Rokid Glasses 320 dp content width with sans-serif body, real char-width should be measured on first text-rendering pass.

### Rokid Glasses <glass-serial> — Q.8 QR-pair verification (2026-05-26 EOD)

| Step | Observation |
|---|---|
| Fresh install `app-glass-debug.apk` + grant CAMERA / RECORD_AUDIO / SYSTEM_ALERT_WINDOW | Success |
| Launch MainActivity (no cookie) | LoginScreen rendered crisp on 480×640 — "Constellation" title bold green, endpoint monospace `wss://edge.example.com/ws/glass`, body "Enter password or scan the QR code from your web console.", **SCAN QR** + **AUTHORIZE** buttons side-by-side |
| Tap SCAN QR (adb input tap 130 351) | Scanner overlay rendered: top-line "Open web Console → About → Pair this device. Point the camera at the QR." + camera preview area + CANCEL button at bottom |
| Eyewear camera points at QR shown on Mac (`open /tmp/q8_pair_qr.png`) | Scan detected; nav popped to Main automatically |
| Main screen rendered post-pair | "● Constellation MAIN" with amber dot in title (Offline state), status block "● Offline" + endpoint `wss://edge.example.com/ws/glass` (set by QR scan) + Shortcuts / Connect to Cortex / About rows + "Pair Halo Ring for ring-gesture shortcuts" hint |
| WSS connect attempt | `WssClient · reconnect in 1435ms (attempt 1)` — DNS lookup for `edge.example.com` fails (no internet on eyewear). Cookie + endpoint are persisted; just the network can't reach Edge. |
| Force-stop + relaunch | Straight to Main, no Login flash → **cookie + endpoint persisted correctly across app restart** |

**Q.8 result**: Pair flow ✅ fully verified on real eyewear. **Eyewear-network setup is the only blocker** between this state and full Cortex round-trip; the QR pair architecture itself works exactly as designed.

### Rokid Glasses — post-WiFi-online E2E (2026-05-27 EOD session)

After the eyewear was put on a network that resolves `edge.example.com`, we ran a second pass to verify the full HUD → Cortex → HUD round-trip works on the real panel.

**Verified ✅**:

| Step | Observation |
|---|---|
| Service start on first MainActivity launch | `ConstellationService · onCreate` → endpoint correctly read from EndpointStore (set by QR scan) → WSS connecting |
| WSS handshake completes (first wake) | `Offline → Idle` transition fires; Connect screen shows "● connected" + cookie persisted |
| `/api/test/invoke battery?` from Mac | event reaches Cortex; classifier + router + dispatch fire correctly |
| Card frame arrives at eyewear (during stable WSS window) | `StateMachine · Idle → Thinking`; `GlassHudActivity · onCreate` (HUD Activity launched from the Service via Intent) |
| **GlassHudActivity renders Compose HUD on real 480×640 panel** | Screenshot `eyewear_card_v3.png` captured **the Thinking state overlay live** ("🧠 planning dispatch (gpt-5.2 router)") on top of the launcher/MainActivity backdrop. **First time Compose HUD has been seen rendering on the actual JBD4020 panel during a live Cortex round-trip.** |
| Foreground-suppression handoff (D6) | `GlassHudSurface · MainActivity foreground, skipping HUD launch` when settings UI is up; `GlassHudActivity · onCreate` when MainActivity is backgrounded |

**Blocked ⚠️**:

The WSS connection on the eyewear's WiFi is **intermittent under power-saving**. After the first stable window (Offline → Idle → Thinking transition + Compose HUD live), subsequent `WssClient · connecting` attempts time out silently (no `open (HTTP 101)`, no `closed` event — TLS handshake never completes). The Service stays alive, MainActivity stays alive, but the WSS reconnect loop can't get past TLS handshake. Logs show `pmo_core_psoc_send_host_wakeup_ind_to_fw` + `wow is enabled` (Wake-on-Wireless power-save mode) right around when the connection drops.

Diagnostics done:
- Cortex side healthy: `tool_conn: True`, events received via `/api/test/invoke`, `glass_frame.emit kind=card` fires
- Public Edge reachable from anywhere else (Mac, OnePlus 9)
- Eyewear pings `<mac-host>` (Mac mini Tailscale IP) → **100% loss** (eyewear is NOT on Tailscale)
- Eyewear can resolve `edge.example.com` during the brief connected windows
- Tailscale package not installed on eyewear: `pm list packages | grep tailscale` returns nothing

**Fix applied (Constellation-Glass `850ad81`)** — Tailscale recommendation reverted (the eyewear can't join Zack's Tailscale LAN; public Edge is the only path):

1. **WssClient.kt** — `pingInterval(10s)` (was 15s; keeps WiFi radio warmer), `connectTimeout(20s)`, `writeTimeout(15s)`, `retryOnConnectionFailure(true)`, **`connectionPool.evictAll()` at start of every `connect()`** (the key fix — flushes "half-dead" sockets that survive WoW state transitions but fail TLS handshake on reuse). `onFailure` log promoted from warn → info with throwable class + message inline.
2. **All 5 HTTP clients** (`CortexHealthClient`, `CortexPingClient`, `ShortcutsClient`, `ShortcutFireClient`, `auth/CortexAuth`) — connectTimeout from 3–10s → 15s; ShortcutFireClient readTimeout bumped to 30s for full Cortex+vision turnaround.

**Verified post-fix** (2026-05-27, same eyewear):
- WSS first attempt times out at 20s, second attempt (after evictAll) opens cleanly → `Offline → Idle`
- Full `battery?` cycle: `Idle → Thinking → Card` with **GlassHudActivity rendering the Compose CardHud** on the real 480×640 panel showing "System status / Battery: 80% (True) / Focus: off / Wi-Fi: None / Frontmost app: Code / Time: 2026-05-27T01:23:59-05:00 (CDT) / double-click to dismiss · auto-close"
- Shortcuts page fetch on eyewear sometimes fails on first cold connect (15s not always enough under WoW); subsequent fetches within the same session succeed — workaround: navigate-retry. Manual single-retry on SocketTimeoutException would smooth this; tracked in TODO.

**Still not verified** (need a session with stable WSS to drive them):
- ~~Vision shortcut E2E from eyewear~~ → ✅ verified 2026-05-28 (next section)
- Voice invoke / Listening / mic capture flow on eyewear
- ~~Long Card body wrapping at real 320 dp / density 240~~ → ✅ verified 2026-05-28; natural Compose wrap renders cleanly

### Rokid Glasses — 2026-05-28 session (HUD overlay + CameraGate + control model + full vision E2E)

This session executed three structural changes + closed two long-running open items.

**1. HUD overlay pivot** (Constellation-Glass `c0f8836` + `830d884`; SoT R10 C-48..C-50)

Real-device wear feedback: "HUD 不要充满一个屏幕, 要让 HUD 真的是 HUD. 你要申请打开这个悬浮在其他应用上面的 overlay 权限, 然后真的悬浮在系统级的最上层" + "字体什么的都能变小一些".

Replaced `GlassHudActivity` (fullscreen transparent) with `GlassHudOverlay` (SYSTEM_ALERT_WINDOW). Both flavors converged on the SYSTEM_ALERT_WINDOW + ComposeView pattern. `OverlayHostOwner` lifted from phoneDebug/ to main/. Added `CardFrame` Composable (rounded 12dp + dim green border + dark fill — transparent on JBD4020 unlit pixels). Type scale -30%: title 22→14sp / body 16→11sp / meta 13→10sp / footer 12→9sp. `SCREEN_BRIGHT_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP` held while non-Idle (5-min ceiling).

Verified on real Rokid Glasses (`<glass-serial>`): card floats above Rokid Sprite launcher; wearer sees "To wake up the AI assistant, please say 'Hi Rokid'" + status bar (time + WiFi + battery) BENEATH the card. Smaller text renders crisply at density=240. WakeLock keeps panel on during card display.

**2. CameraGate / YodaOS camera gate** (Constellation-Glass `8a2b989` + `591e1d9`; SoT R10 C-51)

Root cause of `ERROR_CAMERA_DISABLED` on the eyewear: **AppOps `CAMERA: foreground` UID mode**. `dumpsys media.camera` showed:
```
Uid mode: CAMERA: foreground
REJECT device 0 client for package com.constellation.glass, reason:
  connectHelper:1853: Camera "0" disabled by policy
```

NOT vendor camera-ID / Sprite reservation / missing permission. YodaOS-Sprite strictly requires a RESUMED Activity in our process even with `foregroundServiceType=camera` + explicit `ServiceCompat.startForeground(..., FOREGROUND_SERVICE_TYPE_CAMERA)`. OnePlus 9 (vanilla AOSP) accepts FGS_CAMERA as "in-use"; YodaOS doesn't.

Workaround: `CameraGate.captureViaGate(ctx)` launches one-shot `CameraGateActivity` (transparent `Theme.Translucent.NoTitleBar`, `singleInstance` in own task, `noHistory`). Activity exists ~2s while CameraX captures, returns bytes via `CompletableDeferred`, `finish()`. Mirrors Rokid's own `com.rokid.os.sprite.assist.media.page.CameraActivity` pattern.

**3. Full vision shortcut E2E** verified 2026-05-28 on real Rokid Glasses:

| Step | Observation |
|---|---|
| App backgrounded (HOME pressed; Rokid launcher visible) | confirmed via `dumpsys window | grep mResumedActivity` |
| `adb shell am broadcast -a com.halo.ring.action.TRIGGER --es action_id shortcut_whats-in-front -p com.constellation.glass` | `HaloTriggerReceiver` → `ConstellationService.fireShortcut` → `ShortcutFireClient` |
| `ShortcutFireClient · id=whats-in-front photo=true` | photo route entered |
| `CameraGateActivity · onCreate` | transparent gate launched |
| `CameraCapture · downscaled 6065030B → 165425B (1024px max, q=80)` | eyewear's own camera captured 6 MB → 165 KB |
| `CameraGateActivity · capture done, bytes=165425; finishing` | gate exits |
| Cortex classifier → `intent.simple_via_router` + router picks `vision_describe` | C-47 allowlist gates image to vision_describe only |
| `vision_describe` → OpenAI gpt-5.2 multimodal → prose | ~3s |
| `glass_frame.emit kind=card` | Cortex → eyewear |
| `GlassHudSurface · Thinking → Card` + `GlassHudOverlay · attached` | overlay re-attaches over launcher |
| Real JBD4020 panel shows | **"Photo description: A rotated view of a desk setup shows a large monitor with a code editor open over a mountain-and-sea wallpaper. A smaller white window is open near the bottom, partially washed out by glare on the screen. To the left sits a Sony device with indicator lights and nearby cables, next to a patterned box. ... double-click to dismiss"** |

Real Claude vision output from a frame the eyewear took itself, rendered as a Compose CardHud over the Rokid launcher, during a hands-off shortcut trigger from a backgrounded app. **FULL VISION SHORTCUT E2E.** Screenshot: `/tmp/rokid_vision_card_v2.png`.

**4. HUD control model unification** (Constellation-Glass `e301ef1` + `248b21b`; SoT R11 C-52..C-53)

User feedback after wearing the eyewear:
1. "这个字的换行还是太窄了" — F1 fix: drop `cardBodyWrapChars` pre-pagination; `BasicText(softWrap=true)` in `verticalScroll(rememberScrollState)`; new `CardScrollBus` SharedFlow plumbs 2F SWIPE input → `animateScrollBy`.
2. "如果没有这三类操作的卡片的话, 它也应该在我这个前翻后推的时候向下, 后划后也是向上" — F2 fix: info-only cards (`options=[]`) route CLICK/LONG/DOUBLE/2F-DBL to new `dismissCardLocally()` (local-only transition; NO Cortex emit). 2F SWIPE works on all card types via `CardScrollBus`.
3. "再点击一下...或者这个固定五秒钟多久之后就隐藏掉" — F3 fix: info-only cards get a dynamic TTL `(3s + 50ms × bodyLen).coerceIn(3s, 30s)`. 55-char body closes in 5.75s; 430-char body in 24.5s. Real-device verified.
4. "用语音来控制的那个 SDK 是不是还能用" — declined again (C-53 reaffirms C-37/C-38). InstructSdk requires Sprite always-on listener; violates energy budget. Voice modify path = LONG_PRESS → cortex emits `mic_open` → Glass Listening → speak → CLICK end → audio_end → cortex re-plans. Server-side whisper does STT.

**5. Detach-on-Idle fix** (Constellation-Glass `248b21b`)

User caught: "close 之后显示不对...把半个身为移出屏幕了, 还有半个身为留在屏幕里". The pre-fix `transition(prev, AppState.Idle)` only called `overlay.wakeOff()` and left the SYSTEM_ALERT_WINDOW attached with an empty Compose tree. Result on JBD4020: last-frame pixels (mid-scrolled body) stayed latched while WakeLock release faded the screen.

Fix: on Card → Idle (or any non-Idle → Idle), `overlay.detach()` calls `wm.removeView()` for real. Re-attach on next non-Idle (~30ms cost, not user-visible). Verified: panel after close shows only Rokid launcher, zero residual card content.

### 2026-05-28 result summary

The eyewear now does the full intended UX end-to-end:
- HUD is a true floating overlay above the launcher (not a fullscreen takeover)
- Cards size + height adapt to content; auto-close on body-length-proportional TTL; clean detach
- Type scale and wrap are tuned for the real panel
- Camera works for photo shortcuts despite the YodaOS AppOps gate
- Vision pipeline E2E delivers real prose descriptions of what the wearer sees

**Still ⏸**: P1.5a (voice / Listening flow on eyewear), P1.5b (voice + camera in Listening — pick a/b/c), P1.5c (audio mask acceptance + 24h idle drain + DOUBLE_CLICK behavior + scroll px/swipe tuning).
