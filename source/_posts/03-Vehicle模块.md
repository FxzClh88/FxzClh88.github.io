---
title: 03-Vehicle模块
date: 2026-08-14 12:00:00
categories: [QGC,Vehicle模块]
tags: [标签1, 标签2, 标签3]
description: 了解代码结构
cover: /img/banner.jpg
# sticky: 1   
# 想置顶就取消这行注释（数字越大越靠前）
---# 02 · 03-Vehicle模块
# 03 · Vehicle 模块（载具模型）

> 基于 `2.0.5\source\qgroundcontrol\src\Vehicle\`

## 一、Vehicle 在架构中的位置

Vehicle 是**全 QGC 最核心的类**——它把"一架载具（飞机/车/船/潜水器）"抽象成一个对象，聚合了几乎所有子管理器。

```
MAVLinkProtocol::messageReceived
        ↓
MultiVehicleManager（发现载具、管理多机）
        ↓
Vehicle（单架载具的完整模型 = 上帝类）
   ├── 飞行状态（位置/姿态/模式/解锁）
   ├── 子管理器（参数/任务/云台/相机/避障...）
   └── FactGroup 容器（一堆实时数据 Facts）
```

## 二、MultiVehicleManager —— 多载具总管家

`src/Vehicle/MultiVehicleManager.h`，单例，QML 可访问。

| 职责 | 关键成员/属性 |
|---|---|
| 管理所有载具 | `vehicles`（QmlObjectListModel）、`getVehicleById()` |
| 当前活跃载具 | `activeVehicle`、`setActiveVehicle()` |
| 多选载具（多机协同） | `selectedVehicles`、`selectVehicle()` / `deselectVehicle()` |
| 离线编辑载具 | `offlineEditingVehicle`（断开连接时做规划用） |
| 发送 GCS 心跳 | `_gcsHeartbeatTimer`（1 秒/次） |
| 信号 | `vehicleAdded` / `vehicleRemoved` / `activeVehicleChanged` |

**载具是怎么被发现的**（关键流程）：

```
MAVLinkProtocol 收到飞控心跳
   → vehicleHeartbeatInfo(link, vehicleId, componentId, firmwareType, vehicleType)
   → MultiVehicleManager::_vehicleHeartbeatInfo() 槽
   → 若是新 vehicleId → new Vehicle(link, vehicleId, ...)
   → vehicleAdded 信号 → UI 更新
```

> **对 FlyerLink 的意义**：FlyerLink 的"多架设备管理"定制，就是在这个多载具框架上做的——它利用 MultiVehicleManager 的 `vehicles`/`selectedVehicles`/`activeVehicle` 能力。

## 三、Vehicle —— 上帝类

`src/Vehicle/Vehicle.h`（约 1300 行，全 QGC 最大头文件之一）。

关键继承：`class Vehicle : public VehicleFactGroup, public VehicleTypes`

> **注意它继承 `VehicleFactGroup`** —— 意味着 Vehicle 自己**就是**一个 FactGroup（事实组），飞行姿态/位置/速度/电池等实时数据都是它的 Fact。QML 里直接 `vehicle.vehicle.roll.value` 这样读。

### 3.1 核心状态属性（QML 直接读）

| 属性 | 含义 |
|---|---|
| `id` | 载具 ID（MAVLink sysid） |
| `coordinate` / `homePosition` / `armedPosition` | 当前位置 / 家的位置 / 解锁位置 |
| `armed` | 是否已解锁（解锁=可起飞） |
| `flightMode` / `flightModes` | 当前/可选飞行模式 |
| `fixedWing/multiRotor/vtol/rover/sub/airship` | 载具类型布尔值 |
| `messagesReceived/Sent/Lost` | 消息收发统计 |
| `flying/landing/guidedMode` | 飞行状态 / 降落中 / 引导模式 |
| `vehicleTypeString` / `firmwareTypeString` | 类型/固件的显示字符串 |

### 3.2 聚合的子管理器（Vehicle 的"下属们"）

| 子管理器 | 属性 | 职责 |
|---|---|---|
| ParameterManager | `parameterManager` | 飞控参数读写 |
| VehicleLinkManager | `vehicleLinkManager` | 载具的多链路管理 |
| MissionManager | （成员） | 任务/航点收发 |
| GimbalController | `gimbalController` | 云台 |
| QGCCameraManager | （成员） | 相机 |
| RemoteIDManager | `remoteIDManager` | Remote ID 广播 |
| VehicleObjectAvoidance | `objectAvoidance` | 避障 |
| Autotune | `autotune` | 自动调参 |
| TrajectoryPoints | `trajectoryPoints` | 轨迹点 |
| InitialConnectStateMachine | （成员） | 初始连接状态机 |
| MavCommandQueue | （成员） | MAVLink 命令队列 |

### 3.3 FactGroup 容器（实时数据的 Facts）

Vehicle 把实时遥测数据组织成一个个 **FactGroup**，每个都是 `FactGroup*` 属性：

```
vehicle（本体：姿态/速度/电池） gps / gps2 / gpsAggregate
wind / vibration / temperature / clock / setpoint
estimatorStatus / terrain / distanceSensors / localPosition
hygrometer / generator / efi / radioStatus
actuators / batteries / escs
```

这些 FactGroup 的细节在下一篇《04-FactSystem》展开。

### 3.4 Q_INVOKABLE 控制方法（QML 可调）

| 方法 | 用途 |
|---|---|
| `virtualTabletJoystickValue(roll, pitch, yaw, thrust)` | **虚拟摇杆输入**（平板/键盘遥控） |
| `guidedModeTakeoff(alt)` / `guidedModeLand()` / `guidedModeRTL()` | 一键起飞/降落/返航 |
| `guidedModeGotoLocation(coord)` / `guidedModeChangeAltitude()` | 引导飞行 |

> ⚠️ **重点标注**：`virtualTabletJoystickValue()` 就是 FlyerLink"虚拟遥控/键盘控制"定制功能的底层 API。定制 UI 层（虚拟摇杆控件）最终就是调用这个方法来遥控载具。

## 四、一句话总结

- **MultiVehicleManager** = 车库管理员（管有多少辆车、哪辆是当前车）
- **Vehicle** = 单辆车（含所有仪表盘 + 所有控制按钮 + 所有子系统）

读懂了 Vehicle，QGC 的一半逻辑就通了。

---

**下一步**：04-FactSystem.md —— 参数/数据的统一抽象层（Fact/FactGroup）。
