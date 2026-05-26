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

## 11. 完成定义（P-app.A 至少）

✅ 眼镜 / 一加上打开 app icon → MainActivity 拉起 + 直接进 MainScreen（已登录）或 LoginScreen（未登录）
✅ Status block 实时反映 `/api/health`（绿/橙点 + endpoint snippet + invoke count）
✅ Connect 屏可看 / 改 endpoint，DataStore 持久化，编辑后 WSS 自动重连
✅ TEST CONNECTION (Phase B 接好 `/api/ping` 后) 真能 ping 通并显示结果
✅ DOUBLE_CLICK 在 root 退到 launcher；MainActivity 进入前台时不与 HUD 抢面板
✅ 一加上同套 UI 用 touch + back 键操作可用
✅ glass + phoneDebug 两个 flavor 都 build clean
