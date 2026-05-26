# Constellation-Glass — In-App UI Design (§2 of ui-mockup)

**Status**: design — needs Zack's approval before implementation.
**Companion**: [GLASS-CLIENT-DESIGN.md](GLASS-CLIENT-DESIGN.md) v2.1 · [GLASS-SDK-REFERENCE.md](GLASS-SDK-REFERENCE.md) · [Doc/ui-mockup.html §2](../../Doc/ui-mockup.html) · [halo-ring-plugin-protocol.md](../cross-device/halo-ring-plugin-protocol.md)

---

## 1. 范围 + 它**不**是什么

P1.6 完成了 HUD（眼镜端面板上显示的 6 个 state）。**这份文档**说的是另一个表面 —— 当用户打开 app 图标时进入的**配置 / 状态 / 调试**界面。

| 表面 | 谁看 | 何时显示 | P1.6 状态 |
|---|---|---|---|
| **HUD** (Compose AppStateHud) | 眼镜佩戴者 | Service 推 state 时 | ✅ 完成 |
| **In-App UI** (本文) | 用户在手机上打开 app | 用户主动开 app 时 | ⏸ 未开工 |

**它不是什么**：
- ❌ 不是 HUD 的另一个版本（HUD 在眼镜上，配置在手机上 / 启动时）
- ❌ 不是手势 / profile 编辑器（那住在 Halo Ring 里，per ui-mockup §2 lede + C-38 Halo Ring 为 optional）
- ❌ 不是 HUD 主题 / TTL / 字号调节台（defaults handle 一切）

**它是什么**：手机 (phoneDebug) / 眼镜 (glass) 上**打开 app 后**看到的页面。极简：连接状态 + 几个快捷指令 + Cortex 端点信息。

---

## 2. 关键决策（提议中，待批）

| # | 决策 | 理由 |
|---|---|---|
| D1 | **Compose 渲染**（沿用 HUD 栈） | 单一 UI 栈；HudTheme 颜色/字号可复用；no Material3 |
| D2 | **主要在 phoneDebug flavor 跑** | 眼镜 480×640 太挤，没法塞 4 个 settings 屏；眼镜上 in-app 只保留极简 Login + "Open app on phone to configure" 提示 |
| D3 | **MainActivity 从 "one-shot launcher" 升级为持久 nav host** | 当前 MainActivity onCreate→login→`finish()` 后就死了，不可能回到 settings。需要变成 NavHost (Compose navigation 或手搭 sealed-class) 持久存在 |
| D4 | **本地状态 = DataStore (Preferences)；shortcuts = Cortex/Twin** | 连接状态 (cookie) + 连接 endpoint + app prefs 用 DataStore。shortcuts 走 Cortex 端 Twin (`~/constellation/twin/skills/shortcuts.md`)，因为它需要被 Cortex 自身和 Halo Ring 看到 |
| D5 | **Phase 1 = Main + Connect**，Shortcuts 推到 Phase 3 | shortcuts 涉及 Cortex 协议 + Twin storage + Halo Ring 注册，工作量大；Connect 屏单独最有用（debug 链路用）|

---

## 3. 信息架构

```
MainActivity (NavHost)
│
├─ MainScreen  (route = "main")             ← 默认 home
│  │
│  ├─ Status block (top)
│  │  - "Connected to Cortex" (绿点) / "Offline" (橙点)
│  │  - Endpoint snippet (wss://edge.example.com/ws/glass)
│  │  - Stats: invokes total · last activity
│  │
│  └─ Drill-in rows
│     - Shortcuts        ── (P3)
│     - Connect to Cortex ── ConnectScreen
│     - About            ── AboutScreen
│
├─ ConnectScreen (route = "connect")        ← P1 必有
│  - Endpoint URL (read-only, monospace)
│  - Connection status (live, polls /api/health)
│  - Cookie status (persisted ✓)
│  - Last invoke (timestamp)
│  - [TEST CONNECTION] button  ── POSTs /api/test/invoke {"text":"ping"} + waits for hud_state
│  - [LOG OUT] button (clears cookie, kills service, back to login)
│
├─ AboutScreen (route = "about")            ← P2
│  - App name / version / build flavor
│  - "Open source" + repo link
│  - "Made with " line
│
├─ ShortcutsListScreen (route = "shortcuts")  ── P3
└─ ShortcutEditorScreen (route = "shortcut/{id}") ── P3

LoginScreen (modal, first run only — current MainActivity inline UI lifted into Composable)
```

**Login 流程**：app 第一次启动 → 检查 cookie → 无则显示 LoginScreen → 输入密码 → POST `/api/auth/login` → 存 cookie → 跳转 MainScreen + 启动 Service。

**已登录流程**：app 启动 → 直接 MainScreen + Service 已运行（如果 ConstellationService 还活着不重启）。

---

## 4. 持久化

| 数据 | 存储 | 现状 |
|---|---|---|
| Cookie (`console_session=...`) | `SharedPreferences` via `CookieStore` | ✅ 已存在 |
| Cortex endpoint URL | `BuildConfig.WSS_URL` (compile time) → 移到 DataStore (runtime) | ⏸ 当前 hardcode 在 build.gradle.kts |
| Connection stats缓存 | 不持久；每次进 Connect screen 时 `GET /api/health` | — |
| Shortcuts | Cortex 端 `~/constellation/twin/skills/shortcuts.md` (markdown frontmatter list) | ⏸ P3, schema 待设计 |
| 用户偏好（暂无）| — | 设计上没有 user-tunable HUD 偏好 (defaults handle) |

**Endpoint URL 从 BuildConfig 改到 DataStore**: 这是个有意义的设计变化 —— 让 user 可以在 Connect 屏改 endpoint 而不重新编译 APK。简单 DataStore.Preferences with key `cortex_endpoint`, default = 当前 BuildConfig.WSS_URL.

---

## 5. Cortex 端 API 现状 + 需要补的

### 已有（够用）

| Endpoint | 用途 |
|---|---|
| `GET /api/health` | 拿 server_bound / tool_conn / stats.dispatches_total 等 — 喂 Main 屏 status block |
| `POST /api/auth/login` | 已有 cookie auth |
| `POST /api/test/invoke {"text":"ping"}` | "Test connection" 按钮的实现 — 已经 work |
| `GET /api/sessions?status=active` | 列出最近会话 / 时间戳 — 可以从这里抽 "last invoke" |

### Phase 3 需要新加（shortcuts）

| Endpoint | 行为 |
|---|---|
| `GET /api/shortcuts` | 列出 twin 里所有 shortcuts (parse `skills/shortcuts.md` frontmatter) |
| `POST /api/shortcuts` | 新建 shortcut (name + prompt + capture flags) → 写 twin |
| `PUT /api/shortcuts/{id}` | 更新 |
| `DELETE /api/shortcuts/{id}` | 删除 |

**Twin shortcuts schema**（提议）:
```markdown
---
id: quick-capture-person
name: Quick capture person
mode: photo               # photo / mic / both / none
created: 2026-05-26
---

Identify this person. If matches `people/core/`, surface archive.
If unknown, propose adding to `people/encounters.md`.
```

Shortcuts 走 Twin 不走 SharedPreferences 的理由：(a) Cortex 本身也要读它（用户语音触发 shortcut 时 router 需要 prompt template）; (b) Halo Ring app 通过 [halo-ring-plugin-protocol](../cross-device/halo-ring-plugin-protocol.md) ContentProvider 查 shortcuts 列表 → 需要服务端可访问。

---

## 6. 屏幕级 Compose 设计（Phase 1 起手）

每屏用 sealed-class route + 一个 `@Composable fun Screen()`。共享 Theme + 顶部 status bar。

### 6.1 共享 chrome (`AppChrome.kt`)

```kotlin
@Composable
fun AppChrome(title: String, onBack: (() -> Unit)? = null, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().background(Color.Black).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) {
                BasicText("←", style = TextStyle(fontSize = 20.sp, color = HudTheme.fg),
                          modifier = Modifier.clickable(onClick = onBack).padding(end = 12.dp))
            }
            ConnectionDot()  // 绿/橙小点
            BasicText(" Constellation", style = TextStyle(fontSize = 14.sp, color = HudTheme.fg))
            Spacer(Modifier.weight(1f))
            BasicText(title, style = TextStyle(fontSize = 11.sp, color = HudTheme.fgDim))
        }
        Spacer(Modifier.height(20.dp))
        content()
    }
}
```

### 6.2 MainScreen.kt

```
┌──────────────────────────────┐
│ ● Constellation         v0.2 │  ← chrome
├──────────────────────────────┤
│ ╔══════════════════════════╗ │
│ ║ ● Connected to Cortex    ║ │  ← status block
│ ║ wss://edge.example…  ║ │  (border-only frame)
│ ║ 12 invokes · 3 min ago   ║ │
│ ╚══════════════════════════╝ │
│                              │
│  Shortcuts        3 saved  › │  ← row drill-ins
│  Connect to Cortex         › │
│  About                     › │
│                              │
│  Halo Ring is optional ‣     │  ← bottom hint
└──────────────────────────────┘
```

Status block tap = goes to Connect (deep dive); rows go to respective screens.

### 6.3 ConnectScreen.kt

```
┌──────────────────────────────┐
│ ←  ●  Constellation    CONN  │
├──────────────────────────────┤
│ Connect to Cortex            │
│ Edge endpoint — WSS to Mac.  │
│                              │
│ EDGE ENDPOINT                │
│ ╔══════════════════════════╗ │
│ ║ wss://edge.example.com║ │
│ ║ /ws/glass                ║ │
│ ╚══════════════════════════╝ │
│                              │
│ Connection status  ● connected│
│ Cookie             persisted ✓│
│ Last invoke        3 min ago │
│                              │
│ [   TEST CONNECTION   ]      │
│                              │
│ Edge → Tailscale → Mac.      │
└──────────────────────────────┘
```

`TEST CONNECTION` 按钮：调 `/api/test/invoke {"text":"ping","modality":"text"}` → 等 5s 看 `WssClient` 是否收到任何 hud_state frame → toast "OK" 或 "Timeout"。

### 6.4 AboutScreen.kt

短截，~6 行：name / version / "free & open source" / repo link / "by Zack 紫意" / build flavor + git sha (BuildConfig)。

### 6.5 Phase 3 ShortcutsListScreen / ShortcutEditorScreen

延后，等 D5 决议+ Cortex 协议+ Twin schema 实施后再设计具体 Compose。Mockup 提供视觉参考。

---

## 7. Glass flavor 上怎么处理

眼镜的 480×640 portrait panel 上根本塞不下 settings screens（截屏证明）—— **glass flavor 上 in-app UI 只保留**:

```
┌──────────────────────────────┐
│ ● Constellation (running)    │
│                              │
│ HUD is active.               │
│                              │
│ Open the phone app to        │
│ configure shortcuts, change  │
│ the Cortex endpoint, etc.    │
│                              │
│              · v0.2.0 ·      │
└──────────────────────────────┘
```

唯一的入口 = LoginScreen 第一次配置 + 这个状态屏。所有 setting / shortcut 编辑都在 phoneDebug 上做（或者未来 web Console）。

**为什么不在 glass flavor 上也实现 settings？** 480×640 portrait + 单镜 + 无触屏 + 无键盘 = 任何编辑操作都极难。不如让眼镜专注于 HUD，配置走配对手机。

---

## 8. 分阶段实施提议

| Phase | 内容 | 工作量 | 价值 |
|---|---|---|---|
| **P-app.A** | 把 MainActivity 重写为 Compose NavHost；LoginScreen + MainScreen + ConnectScreen + 共享 chrome + DataStore 接入 endpoint URL | 4-5h | **高** — Connect 屏对调试连接极有用；Main 给"我的 Cortex 还活着吗"一个肉眼答案 |
| **P-app.B** | AboutScreen | 30 min | 低 |
| **P-app.C** | Glass flavor 上的"running"屏 | 1 h | 中（眼镜端打开 app 不再是空登录） |
| **P-app.D** | Shortcuts list + editor + Cortex `/api/shortcuts` endpoints + Twin schema + Halo Ring ContentProvider 注册 | 1-2 days | **高** — 这是用户在 ui-mockup §2 主要画的功能 |

**推荐顺序**: A → B → C → D。**D 是大块**（涉及 Cortex 协议 + Twin schema + Halo Ring 集成），单独成 ticket。

---

## 9. Open questions

- **OQ-app-1**: Endpoint URL 是否真的需要 user-editable? 你目前部署是 `wss://edge.example.com/ws/glass` 写死的。如果不打算多端切换，BuildConfig 也够。**默认假设可编辑**（D4）。
- **OQ-app-2**: Connect 屏 "TEST CONNECTION" 按钮要走整套 `/api/test/invoke` (会触发 router + tool dispatch)，还是搞个**新的轻 ping endpoint** `/api/ping` 只返回 200 + tool_conn 状态？后者更便宜。倾向后者。
- **OQ-app-3**: Logout 时是否真的杀 Service？还是只清 cookie？倾向：清 cookie + 让 Service 自己 close WSS 然后进 Offline 状态等下次 cookie 来。
- **OQ-app-4**: Halo Ring 在 v2.1 是 optional —— 主屏底部的 "Halo Ring is optional" hint 是合适的还是误导？(如果用户没装 Halo Ring，shortcuts 仍然有用 —— 可以通过 voice "do my [quick capture person]" 触发；只是没有 gesture 触发渠道)
- **OQ-app-5**: P3 Shortcuts 改不改影响 P3.1 (Halo Ring profile push)？需要先看 P1.7 Halo Ring profile 协议契约才能决定 Shortcuts 是否要发布 push 信号。

---

## 10. 完成定义（P-app.A 至少）

✅ 打开 app（phoneDebug 在一加上） → 已登录的情况下直接进 MainScreen
✅ MainScreen 顶部状态块实时反映 cortex `/api/health` (绿/橙点 + endpoint + invoke 计数)
✅ Connect screen 可以看到当前 endpoint URL，可以改并保存到 DataStore
✅ Connect screen 的 "TEST CONNECTION" 按钮真的能 ping 通并显示结果
✅ Back nav 正常工作 (硬件返回键 + chrome 上的 ← 都行)
✅ glass flavor build clean (即使内部其实是 "running" 极简屏)

