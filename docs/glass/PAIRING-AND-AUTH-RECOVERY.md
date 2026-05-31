# Glass 配对 / 鉴权 / 恢复

**一句话**：眼镜经公网 Edge（`edge.example.com`）连 Cortex；Edge 用一次性 cookie 鉴权，**会话存在内存里 → 每次重启/重部署 Edge 都会把所有客户端登出**。本文说明怎么生成配对 QR、登出后怎么恢复、以及鉴权失效时的 HUD 容错 UX。

---

## 1. 配对怎么工作

```
Web 控制台 (edge.example.com, 输 CONSOLE_PASSWORD 登录)
  │  About / Pair 页 → GET /api/auth/pair_qr
  │  Edge 把当前会话打成 { endpoint, cookie_name, cookie_value } 渲染成二维码
  ▼
眼镜 App → 扫码 → MainActivity.parseQrPayload → 写入：
  · EndpointStore  = endpoint   (wss://edge.example.com/ws/glass)
  · CookieStore    = cookie_name / cookie_value   (SharedPreferences, 30 天)
  ▼
ConstellationService.start → WSS 带 Cookie 头连 Edge → server_bound=True
```

QR 的 JSON 形状（眼镜端 `MainActivity.parseQrPayload` 认这个）：
```json
{
  "endpoint": "wss://edge.example.com/ws/glass",
  "cookie_name": "console_session",
  "cookie_value": "<Edge mint 的 session token>"
}
```

cookie 存明文 SharedPreferences（`constellation_secure.xml`，键 `edge_cookie_name`/`edge_cookie_value`）；`adb install -r` 重装**保留** cookie（不用反复扫码）。

---

## 2. 怎么生成配对 QR（你问的）

**正常路径（推荐）**：
1. 浏览器开 `https://edge.example.com`，用 `CONSOLE_PASSWORD` 登录。
2. 进 **About / Pair** 页（`web/src/routes/About.tsx`）——页面自动调 `GET /api/auth/pair_qr`，把**当前登录会话**打成 bundle 渲染成二维码。
3. 眼镜 App 的扫码页对准这个 QR，扫一下即配对。

> `pair_qr` 端点（`edge/console_edge/auth.py` `@app.get("/api/auth/pair_qr")`）要求**已登录**（用当前会话 mint pairing bundle），所以先在 Web 登录。

**密码路径（备选）**：眼镜登录门也能直接输 `CONSOLE_PASSWORD`（`CortexAuth.login` → `POST /api/auth/login` → 拿 cookie），不依赖 Web/QR。

---

## 3. 为什么会突然登出 + 怎么恢复

**根因**：Edge 的会话存**纯内存**（`auth.py`：`sessions: dict[token → expiry]`，注释明写 "Memory store loses sessions on edge restart — user re-logs in. Fine for v1."）。所以：

- **每次 `deploy/deploy-edge.sh` / 重启 `console-edge` → 所有客户端会话失效**（眼镜 + 网页都要重登）。
- 眼镜遇到 401/403 → `WssClient.onFailure` **halt reconnect**（不再死循环重连）+ 清本地 cookie。

**恢复 = 重新配对**：照 §2 重新扫码（或输密码）即可；server 端无需操作。

> ⚠️ 运维提醒：**动 Edge 前先知道这会把眼镜登出**。本轮（2026-05-31）为上线二进制图片管线重部署了 Edge，眼镜因此登出，需重配对。

---

## 4. 鉴权失效的 HUD 容错 UX（Zack 2026-05-31 规格）

铁律：**所有状态走 HUD，不靠 Android 通知**（FGS 那条常驻通知是系统强制的，保持静态最小，绝不用它传达状态）。

鉴权失效（401/403，halt 后）→ 进入 **HUD 鉴权失效态**：
- HUD 显示「登录失效 · 长按扫码重新配对」。
- **长按(LONG)** → 拉起摄像头扫码配对（打开 App 扫码页直达）。
- **双击(DOUBLE)** → dismiss（清掉提示）。
- **App 内**也提供「配对 / 重新扫码」按钮（主动重配，不必等失效）。

连带修复：**Offline 提示也要可 dismiss**（双击关掉；现状是连接驱动、无法手动关）。

> 实现落点：`AppState` 新增鉴权失效态；`StateMachine` 手势路由（LONG=扫码 / DOUBLE=dismiss）；`GlassHudSurface` 渲染；`WssClient` 暴露 authExpired；`ConstellationService` 由它驱动 HUD（非通知）；`MainActivity` 加「扫码直达」intent + App 内配对按钮。
