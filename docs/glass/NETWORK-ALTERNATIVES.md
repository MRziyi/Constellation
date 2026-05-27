# Constellation-Glass — 网络架构备选调研

**Created**: 2026-05-27
**Updated**: 2026-05-27 (二轮实测后改写 — BT-PAN 实际**可用**，把 iPhone 切到 LTE 即可)
**Trigger**: 用户反馈 "WiFi 一直开太浪费电；眼镜重启后还要手动 `svc wifi enable`，能不能跟手机共享网络？"
**Status**: ✅ **BT-PAN 可用**（前提：iPhone 在 LTE，不是 5G）。完整端到端 WSS → Cortex Card 已验证。WiFi 可常关。

---

## 1. 候选方案（按改动量从低到高排）

| 方案 | 链路 | 改动量 | 眼镜 WiFi 可关 |
|---|---|---|---|
| **A. BT-PAN tethering** | 眼镜 ↔ BT ↔ 手机 ↔ 网 | 配置 + 一处 UI toggle | ✅（理论上） |
| **B. CXR-L bridge** | 手机 app ↔ Rokid AI APP ↔ 眼镜 | 重写为 phone app + 丢 Compose | ✅ |
| **C. CXR-M + CXR-S 直 BLE** | 手机 app (CXR-M) ↔ BLE ↔ 眼镜 app (CXR-S) | 加手机 companion + 眼镜端集成 CXR-S | ✅，且有 Wi-Fi P2P 大带宽通道 |
| **D. WiFi hotspot from phone** | 眼镜 → WiFi → 手机 → 网 | 0 | ❌（仍走 WiFi） |
| **E. 保持现状 (WiFi 直接到 Edge)** | 眼镜 → WiFi → 公网 → Edge | 0 | — |

---

## 2. 方案 A — BT-PAN tethering：✅ **可用**（iPhone 必须在 LTE）

### 2.1 测试设置（2026-05-27, 二轮）

- 眼镜：Rokid Glasses `<glass-serial>`, YodaOS-Sprite (Android 12 Go base)
- 手机：iPhone 17 Pro (`68:EF:DC:7C:CA:37` BR/EDR, `63:5C:3A:17:F3:0C` LE)，预先与眼镜配对
- iPhone 设置：个人热点 → "允许其他人加入" = 开
- iPhone 设置：**蜂窝网络 → 蜂窝数据选项 → 语音与数据 = LTE/4G**（**关键**：5G 模式下 BT hotspot 只发 IPv6）
- 眼镜设置：蓝牙 → iPhone 17 Pro → Device details → **Internet access** = 开

### 2.2 结果

#### 一轮（iPhone 在 **5G**）：失败

bt-pan 接口起来，IPv6 SLAAC 通了，**但 IPv4 没拿到 + ConnectivityService 没注册 NetworkAgent + 默认路由空**。logcat：

```
05-27 15:14:25.628 PanService: handlePanDeviceStateChange State:1→2 LOCAL_PANU_ROLE:REMOTE_NAP_ROLE
# only one NetworkAgent registered:
NetworkAgentInfo{network{100}  ni{WIFI CONNECTED}  ...}
```

#### 二轮（iPhone 切到 **LTE** + 眼镜端 toggle Internet access off+on 重协商）：✅ 通

bt-pan 接口拿到 IPv4 + 完整 NetworkAgent 注册 + 优先级高于 WiFi：

```
19: bt-pan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 172.20.10.10/28 brd 172.20.10.15 scope global bt-pan
    inet6 2607:fb91:22c6:5f85:5e49:29fe:b96e:1c2f/64 scope global

NetworkAgentInfo{network{101}  ni{Bluetooth Tethering CONNECTED}
  ...VALIDATED  Score(69)
  InterfaceName: bt-pan
  LinkAddresses: [172.20.10.10/28, IPv6×2]
  DnsAddresses: [/172.20.10.1, fe80::68ef:dcff:fe88:2064%bt-pan]
  Routes:
    0.0.0.0/0 -> 172.20.10.1 bt-pan   ← IPv4 default
    ::/0 -> fe80::68ef:dcff:fe88:2064 bt-pan
  Transports: BLUETOOTH
  Capabilities: INTERNET&NOT_RESTRICTED&TRUSTED&VALIDATED
  LinkUpBandwidth>=24000Kbps  LinkDnBandwidth>=24000Kbps

# BT-PAN score 69 > WiFi score 60 → default network = BT
$ ip route get 8.8.8.8
8.8.8.8 via 172.20.10.1 dev bt-pan ...
```

E2E（WiFi 关掉，只 BT 路径）：
- `ping edge.example.com` → 3/3，164-275ms
- `curl https://edge.example.com/api/health` → `{"status":"ok",...}` 200 OK
- POST `/api/test/invoke {"text":"battery?"}` → Cortex 处理 → WSS hud_state → card → CardHud 在眼镜上渲染 → 5.35s auto-close
- 总 round-trip wall time: **~10s**（与 WiFi 模式相同量级）

### 2.3 根因 + 修复方法

#### 一轮失败的根因

**iOS 17+ 的已知 bug**：iPhone 在 5G 网络下，Personal Hotspot 的 BT-PAN-NAP 不发 IPv4 DHCP/没配 IPv4 router 地址 —— 只发 IPv6 RA。

**iPhone 端佐证**：连上 BT-PAN 后，iPhone 的 Settings → 蓝牙 → 眼镜 → "Bluetooth PAN-NAP" 详情页显示 **IPv4 Address / Subnet Mask / Router 三个字段都是空白**（Configure IP: Automatic 但没值）。说明 iPhone 自己都没在这条链路配 IPv4。

**Android 端连锁反应**：因为没有 IPv4 lease，YodaOS 的 `BluetoothTethering` NetworkAgent 卡在 "Got NetworkProvider Messenger" 之后不往下注册 NetworkAgent —— 所以 ConnectivityService 不知道这是张可用网络，应用层走不通。

Apple Community + Google Issue Tracker 多份独立报告确认这是 iOS 17.2+ 行为变化，仍在 iOS 18/19 (2026) 未修复。

#### 修复方法（**实测有效**）

**iPhone 切到 LTE/4G**（设置 → 蜂窝网络 → 蜂窝数据选项 → 语音与数据 → LTE）。切换瞬间 BT-PAN 会 drop 一次（radio 重置），然后眼镜端 toggle Internet access off+on 重协商 —— 这次 iPhone 就发标准 DHCPv4 lease 了：

- 眼镜拿到 `172.20.10.10/28`，gateway `172.20.10.1`（iPhone）
- DNS `172.20.10.1`
- YodaOS `BluetoothTethering NetworkAgent` 完整注册（score 69，VALIDATED）
- 默认路由 `0.0.0.0/0 → 172.20.10.1 bt-pan`

切回 5G 后 BT-PAN 会再次只 IPv6，需要再切回 LTE。

#### Sources

- [iPhone hotspot force IPv4 for connected devices (Apple Community)](https://discussions.apple.com/thread/255384679)
- [Hotspot with iPhone IPv4 not assigning (Apple Community)](https://discussions.apple.com/thread/255466044)
- [Android 13 device not able to connect to iPhone IPv6 only (Google issue tracker)](https://issuetracker.google.com/issues/376090601)
- [pwnagotchi bt-tether DHCP PR](https://github.com/jayofelony/pwnagotchi/pull/442) — 类似问题的 Linux 客户端开源解法

---

## 3. 方案 B (CXR-L) — 设计上不推荐

Rokid 官方"phone-bridge"方案，但跟我们 v2.1 的 "bare-metal + Compose HUD" 设计冲突：

- 眼镜 UI 只能用 CXR-L 的 JSON CustomView schema（LinearLayout/TextView/ImageView，无 Compose）—— **v2.1 投入的全部 Compose HUD 工作作废**
- CXR-L 必须经过 **Rokid AI APP 中转**，跟我们 C-37/C-38 "不依赖 Sprite"原则冲突
- 重写为 phone app 是 multi-week 工程

**唯一可能的妥协**：CXR-L CUSTOMAPP 模式 = "把我们眼镜端 app 通过 CXR-L 部署 + 加一条 customCmd 通道作 WSS 替代"。这条还能保留 Compose HUD，但仍然依赖 Rokid AI APP 跑着。

详见：
- [reference/rokid-glass/cxrl-docs/00-introduction.md](../../reference/rokid-glass/cxrl-docs/00-introduction.md)
- [reference/rokid-glass/cxrl-docs/MANIFEST.md](../../reference/rokid-glass/cxrl-docs/MANIFEST.md) — 23 个 sub-page 按需取

---

## 4. 方案 C (CXR-M + CXR-S) — 远期最有潜力

Rokid 商业级 SDK，用户已私下拿到完整 20 页文档：`~/Code/Projects/R08-dev/refs/sdks/rokid/CXR-M SDK/`。

### 4.1 关键事实（从 `01简介.html` 提炼）

| 维度 | CXR-M 特性 |
|---|---|
| 手机端 SDK | CXR-M（Android only；iOS 不支持） |
| 眼镜端 SDK | **CXR-S** (peer-to-peer 配对) |
| 跟 Rokid AI APP 共存 | **互斥**（同一手机不能同装）—— 反而符合我们"不依赖 Sprite"原则 |
| 控制通道 | 直 BLE（不经过 Rokid AI APP）|
| 大数据通道 | **Wi-Fi P2P Group** ⭐ （视频/录像/大照片）|
| 眼镜 UI 能力 | RelativeLayout / LinearLayout / ImageView / TextView / Lottie |
| TTS + 通知 + Toast | ✅ |
| 自定义指令 | CXR-M ↔ CXR-S 双向 |
| 场景模板 | AI 助手 / 翻译 / 提词器 / 自定义显示 |

### 4.2 跟我们的设计的契合度

- ✅ "不依赖 Sprite / Rokid AI APP" —— CXR-M 跟 AI APP 互斥，反而强化我们 C-37/C-38
- ✅ 眼镜端保留我们 Compose HUD —— CXR-S 是眼镜端 app library，不替代我们 UI
- ✅ 大数据走 Wi-Fi P2P —— 既能省 LTE 流量又能避免公网 Edge
- ❌ 需要写 **手机 companion app**（CXR-M）—— 现在 Constellation 只有眼镜端
- ❌ 需要在眼镜端 **集成 CXR-S** —— 还要再加 SDK 依赖
- ❌ 手机端 only Android —— 用户主力 iPhone 用不了；除非额外搞一个 Android 设备

### 4.3 推荐时机

如果将来：
1. 眼镜 WiFi 能耗在长时间穿戴下成为真正问题（需先量化）
2. 或者要做高带宽眼镜→手机数据流（实时视频上传）
3. 或者放下 iPhone 主力，配一个 Android 中介设备

—— **再启动 CXR-M + CXR-S 集成**。当前没有这些触发条件，**不动**。

---

## 5. 方案 D (WiFi hotspot from phone) — 不省电

iPhone 的"个人热点 → 允许其他人加入"对 Wi-Fi 客户端是 well-supported 的（标准 DHCP + DHCPv6 都跑）。眼镜可以正常加入，**但仍然是 WiFi**，能耗跟原方案一样。仅在"用户在外、家里 WiFi 不可达"的场景能用，**不解决能耗问题**。

---

## 6. 决策

**采用方案 A（BT-PAN）作为可选省电模式**。WiFi 仍然可用作 fallback。

### 6.1 用户操作清单（每次想用 BT 共享网络时）

| # | 操作 | 在哪 |
|---|---|---|
| 1 | 蜂窝数据选项切 LTE/4G (不是 5G) | iPhone 设置 |
| 2 | 个人热点 → "允许其他人加入" = 开 | iPhone 设置 |
| 3 | 蓝牙 → Rokid Glasses → 详情 → Internet access = 开 | iPhone（如果有），或眼镜 |
| 4 | （可选）关眼镜 WiFi 省电 | Constellation app → Android system settings → Wi-Fi → 关 |

> 第 4 步通过我们 Constellation app Main 屏新加的 "Android system settings" 入口直接到 Android 原生 Settings 顶层 → Wi-Fi。

### 6.2 已知坑

- **iPhone 5G 模式下 BT-PAN 只发 IPv6**（iOS 17+ bug）→ 必须 LTE
- iPhone 切 5G ↔ LTE 时 BT-PAN 会 drop 一次，需要 toggle Internet access 重协商
- 眼镜重启后 WiFi 自动 OFF（YodaOS 行为）→ 走 BT-PAN 模式时反而是个好事（不会自动开 WiFi 浪费电）
- 眼镜进程 OOM 概率：Android Go 内存压力下，Settings + Constellation 同时打开有时 lowmemorykiller 杀 Constellation。重启 app 即可

### 6.3 远期再考虑

| 触发条件 | 行动 |
|---|---|
| BT-PAN 带宽不够（实时视频上传眼镜→Cortex 等）| 上方案 C (CXR-M + CXR-S) Wi-Fi P2P 大带宽通道 |
| 想做"完全脱离 Rokid 生态" mobile app | 方案 C 仍然推荐 |
| 想自动化 5G/LTE 切换避免手动 | 短期无解（iOS 没暴露这个 API），需要 iOS Shortcuts / Focus mode 配合 |

---

## 7. 实测记录原始 log

`bt-pan up + IPv6 SLAAC OK + ConnectivityService not promoting` 的 logcat 摘录已在 §2.2 引述。完整 dumpsys / ip / ping 输出已保存到 git commit 链路记录里，不在这里粘贴防止过期。

如果将来要重做 BT-PAN 测试：
1. iPhone 个人热点开
2. 眼镜蓝牙→ iPhone → Internet access 切开（确认 bt-pan interface up）
3. `adb shell dumpsys connectivity | grep NetworkAgentInfo` —— **关键**：如果只有 WIFI，说明 NetworkAgent 还是没注册，跟今天结果一样
4. 如果有 BLUETOOTH transport 的 NetworkAgentInfo 出现，再继续测路由 / DHCP / 应用层
