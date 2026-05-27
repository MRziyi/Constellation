# Constellation-Glass — 网络架构备选调研

**Created**: 2026-05-27
**Trigger**: 用户反馈 "WiFi 一直开太浪费电；眼镜重启后还要手动 `svc wifi enable`，能不能跟手机共享网络？"
**Status**: 调研 + 一轮实测；当前结论 = **维持 WiFi**，无可行的省电替代方案（在 iPhone + YodaOS 组合下）

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

## 2. 方案 A — BT-PAN tethering：**已实测，iPhone+YodaOS 不通**

### 2.1 测试设置（2026-05-27）

- 眼镜：Rokid Glasses `<glass-serial>`, YodaOS-Sprite (Android 12 Go base)
- 手机：iPhone 17 Pro (`68:EF:DC:7C:CA:37` BR/EDR, `63:5C:3A:17:F3:0C` LE)，预先与眼镜配对
- iPhone 设置：个人热点 → "允许其他人加入" = 开
- 眼镜设置：蓝牙 → iPhone 17 Pro → Device details → **Internet access** = 开

### 2.2 结果

✅ **BT-PAN 链路建起来了**：

```
05-27 15:14:25.439 BluetoothPan: setConnectionPolicy(68:EF:DC:7C:CA:37, 100)
05-27 15:14:25.628 PanService: handlePanDeviceStateChange State:1→2
                              LOCAL_PANU_ROLE:REMOTE_NAP_ROLE
05-27 15:14:25.655 ConnectivityService: Got NetworkProvider Messenger for Bluetooth Tethering

# eyewear:
18: bt-pan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ... state UNKNOWN
    inet6 2607:fb91:22c6:5f85:ae86:d1ff:fe59:3223/64 (SLAAC global)
    inet6 fe80::ae86:d1ff:fe59:3223/64 (link-local)

# iPhone advertised as IPv6 router:
fe80::68ef:dcff:fe88:2064 dev bt-pan ... router STALE
2607:fb91:22c6:5f85:d0cb:4d9b:3b95:f73 dev bt-pan ... router
```

❌ **但 ConnectivityService 没把 bt-pan 提升为可用 NetworkAgent**：

```
# only one NetworkAgent registered:
NetworkAgentInfo{network{100}  ni{WIFI CONNECTED}
  Specifier: SSID="Linksys_14590_5G" ...
```

❌ **没有 IPv4**（iOS BT 热点不发 DHCPv4）
❌ **IPv6 默认路由没装上**（Android 拒绝在 unregistered 接口上装 RA default route）
❌ `ping6 2001:4860:4860::8888` → "Network is unreachable"

### 2.3 根因分析

**两个互相加重的问题**：

1. **iOS Personal Hotspot over Bluetooth 只发 IPv6 RA，不跑 DHCPv4 server**
   - Apple 的 BT 热点是 PAN-NAP role，但没启用 IPv4 DHCP daemon
   - 唯一的网络配置渠道是 IPv6 RA + SLAAC

2. **YodaOS 的 BluetoothTethering NetworkAgent 没生效**
   - AOSP 标准实现下，PAN PANU 连接成功应该触发 BluetoothTethering 的 NetworkAgent 注册到 ConnectivityService
   - 但我们这里只看到 `Got NetworkProvider Messenger for Bluetooth Tethering`（provider 创建），后续没有 NetworkAgent register
   - 怀疑 Rokid 的 YodaOS-Sprite 在裁剪 system 服务时把 BluetoothTethering 完整链路砍了一半

**互相加重**：即使我们手动给 bt-pan 装路由（需要 root，眼镜没 `su`），应用层 OkHttp/curl 也走不通，因为 socket 选路由会先问 ConnectivityService，而它根本不知道 bt-pan 是个网络。

### 2.4 不通的退路

- **手动加路由**：需要 root；眼镜没暴露 root shell
- **绕过 ConnectivityService 直接 bind socket 到 bt-pan**：需要应用持 `INTERNET` + `CHANGE_NETWORK_STATE` 权限 + 改 OkHttp 配置 bind 到 specific interface；可能行得通，但很 hacky 且要单独 IPv6-only stack
- **换 Android 手机做 BT-PAN host**：Android 手机的 BT 热点跑标准 DHCPv4，可能能让 YodaOS 的 BluetoothTethering NetworkAgent 真正注册。**未实测**

### 2.5 结论

iPhone + YodaOS BT-PAN 这条组合 **死路一条**。若以后用 Android 手机做 hotspot，值得再试一次（DHCPv4 路径可能能激活 NetworkAgent）。

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

## 6. 决策 + 当前操作

**保持现状（方案 E）**：眼镜直接连 Linksys WiFi → 公网 → Edge → Cortex。WiFi 是当前最简单可行的方案。

**已知 pain point + workaround**：
- 眼镜重启后 WiFi 自动 OFF → `adb -s <glass-serial> shell svc wifi enable`（HANDOFF §7 已有这个 snippet）
- 长时间穿戴的能耗 → 还没量化，先观察

**接下来什么时候重启这个调研**：

| 触发条件 | 行动 |
|---|---|
| 量到 WiFi-only 模式下 > 6h 待机就掉电过半 | 试方案 A 改用 Android 手机做 hotspot 重测 |
| 想做实时视频上传眼镜→Cortex | 直接上方案 C (CXR-M + CXR-S) |
| 想做"完全脱离 Rokid 生态" mobile app | 方案 C 仍然推荐 |

---

## 7. 实测记录原始 log

`bt-pan up + IPv6 SLAAC OK + ConnectivityService not promoting` 的 logcat 摘录已在 §2.2 引述。完整 dumpsys / ip / ping 输出已保存到 git commit 链路记录里，不在这里粘贴防止过期。

如果将来要重做 BT-PAN 测试：
1. iPhone 个人热点开
2. 眼镜蓝牙→ iPhone → Internet access 切开（确认 bt-pan interface up）
3. `adb shell dumpsys connectivity | grep NetworkAgentInfo` —— **关键**：如果只有 WIFI，说明 NetworkAgent 还是没注册，跟今天结果一样
4. 如果有 BLUETOOTH transport 的 NetworkAgentInfo 出现，再继续测路由 / DHCP / 应用层
