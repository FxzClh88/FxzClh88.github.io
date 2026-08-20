---
title: 02-MAVLink通信层
date: 2026-08-14 12:00:00
categories: [QGC,MAVLink通信层]
tags: [标签1, 标签2, 标签3]
description: MAVLink通信层
cover: /img/banner.jpg
# sticky: 1   # 想置顶就取消这行注释（数字越大越靠前）
---
# 02 · MAVLink 通信层

> 基于 `2.0.5\source\qgroundcontrol\src\Comms\` 和 `src\MAVLink\`

## 一、通信层在架构中的位置

这是**数据从飞控进入 QGC 的第一站**。理解它，后面 Vehicle/FactSystem 都顺了。

```
飞控 ⇄ [物理链路] → LinkManager → MAVLinkProtocol → Vehicle
```

## 二、两个目录的分工（新版的重要变化）

| 目录 | 内容 | 角色 |
|---|---|---|
| `src/Comms/` | LinkManager、LinkInterface、各链路、**MAVLinkProtocol** | 链路管理 + 协议处理 |
| `src/MAVLink/` | QGCMAVLink（QML单例）、MAVLinkFTP、ImageProtocolManager | MAVLink 工具/扩展 |

> ⚠️ **新版变化**：旧版的 `MAVLinkProtocol` 在 `src/comm/` 下（Qt5 时代），新版把它合并进了 `Comms/` 模块——因为协议处理和链路管理高度耦合。
>
> 而 `src/MAVLink/QGCMAVLink` 是个 **QML 单例工具类**（`QML_NAMED_ELEMENT(MAVLink)` + `QML_SINGLETON`），只提供一堆**静态转换函数**（firmware/vehicle 类型 ↔ 字符串、电机数量、传感器枚举等），给 QML 用，**不负责收发数据**。

## 三、LinkManager —— 链路总管家

`src/Comms/LinkManager.h`，单例（`LinkManager::instance()`），注册为 QML 元素（`QML_ELEMENT`，但 `QML_UNCREATABLE`，即 QML 只能引用不能 new）。

**核心职责：**

| 职责 | 关键方法/成员 |
|---|---|
| 管理所有链路 | `_rgLinks`、`_rgLinkConfigs`、`links()` |
| 增删连接配置 | `createConfiguration()` / `endCreateConfiguration()` / `removeConfiguration()` |
| 建立连接 | `createConnectedLink()` / `disconnectLink()` |
| 分配 MAVLink channel | `allocateMavlinkChannel()` / `freeMavlinkChannel()`（位掩码 `_mavlinkChannelsUsedBitMask`） |
| 自动连接 | `startAutoConnectedLinks()` / `_addUDPAutoConnectLink()` / `_addSerialAutoConnectLink()` |
| 日志回放 | `startLogReplay()` |
| 串口管理 | `serialPorts()` / `_updateSerialPorts()` / `_allowAutoConnectToBoard()` |
| MAVLink 转发 | `_addMAVLinkForwardingLink()` |

**关键点**：
- MAVLink channel 数量有限（`MAVLINK_COMM_NUM_BUFFERS`），每个活跃链路占一个 channel，用位掩码管理。
- Windows 上自动连接有 6 秒延迟（`_autoconnectConnectDelayMSecs = 6000`），是为了等 bootloader 刷完。

## 四、LinkInterface —— 链路抽象

`LinkInterface` 是抽象基类，所有具体链路实现它。具体类型：

| 链路 | 文件 | 用途 |
|---|---|---|
| SerialLink | `SerialLink.cc` | 串口（USB 数传/直连飞控） |
| UDPLink | `UDPLink.cc` | UDP（WiFi 数传、模拟器） |
| TCPLink | `TCPLink.cc` | TCP |
| Bluetooth | `Bluetooth/` | 蓝牙 |
| MockLink | `MockLink/` | 模拟链路（测试用） |
| **LogReplayLink** | `LogReplayLink.cc` | **日志回放**（把 .mavlink 文件当链路重放） |

## 五、MAVLinkProtocol —— 协议核心

`src/Comms/MAVLinkProtocol.h`，单例（`MAVLinkProtocol::instance()`）。

这是**真正解析 MAVLink 字节流的地方**：

```
LinkInterface 收到字节 → MAVLinkProtocol::receiveBytes(link, data)
                              ↓ 内部逐字节喂给 mavlink 库解析
                        解析出 mavlink_message_t
                              ↓
                        messageReceived 信号（广播给 Vehicle）
```

**核心职责：**

| 职责 | 关键成员/方法 |
|---|---|
| 接收解析 | `receiveBytes(link, data)` |
| 消息广播 | `messageReceived(link, message)` 信号 |
| 心跳发现载具 | `vehicleHeartbeatInfo(link, vehicleId, componentId, firmwareType, vehicleType)` 信号 |
| 遥测日志记录 | `_tempLogFile`、`_logData()`、`_saveTelemetryLog()`（存 .mavlink 文件） |
| 丢包统计 | `_totalReceiveCounter` / `_totalLossCounter` / `_runningLossPercent` + `mavlinkMessageStatus` 信号 |
| 序列号跟踪 | `_lastIndex[channel][sysid][compid]`（按链路隔离，防串扰） |
| 消息转发 | `_forward()` / `_forwardSupport()` |

**system/component id**：GCS 自己的 component id 固定是 `MAV_COMP_ID_MISSIONPLANNER`（兼容旧协议习惯）。

## 六、完整数据流（记这张图就够）

```
[飞控]
  │ MAVLink 字节流
  ▼
[物理链路] Serial / UDP / TCP / Bluetooth / Mock / LogReplay
  │ 实现 LinkInterface
  ▼
[LinkManager] 管理连接、分配 channel、自动连接
  │ 把收到的字节交给协议层
  ▼
[MAVLinkProtocol::receiveBytes()]
  │ 用 mavlink 库逐字节解析
  ▼
messageReceived(mavlink_message_t) 信号
  ▼
[Vehicle] 根据 msg id 分发处理（心跳/参数/姿态/任务...）
```

## 七、日志回放 —— 为什么重要

`LogReplayLink` 能把一个 `.mavlink` 遥测日志文件**当作一条"假链路"重放**。数据走完全相同的 MAVLinkProtocol → Vehicle 路径。

这对团队的意义：
- **AnalyzeView（日志分析视图）** 就是靠它把历史飞行日志"重放"出来做可视化分析。
- 调试 FlyerLink 视频/图传问题时，可以脱离真实硬件，用日志回放复现。

---

**下一步**：03-Vehicle模块.md —— 载具模型，全 QGC 最核心的类。
