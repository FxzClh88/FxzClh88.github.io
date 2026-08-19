# 05 · 任务规划（PlanManager / MissionManager）

> 基于 `2.0.5\source\qgroundcontrol\src\MissionManager\`

## 一、任务模块概览

QGC 把"飞控上的任务数据"分成三种，统一管理：

| 类型 | MAV_MISSION_TYPE | 管理器 | 用途 |
|---|---|---|---|
| 飞行任务 | `MISSION` | MissionManager | 航点/命令序列 |
| 地理围栏 | `FENCE` | GeoFenceManager | 电子围栏（限制飞行范围） |
| 集结点 | `RALLY` | RallyPointManager | 安全集结点（返航备降点） |

## 二、三合一架构（新版核心重构）

```
            PlanManager（基类，任务收发状态机）
             ├── MissionManager（飞行任务）
             ├── GeoFenceManager（地理围栏）
             └── RallyPointManager（集结点）
```

`PlanManager` 是三者共同基类，用 `MAV_MISSION_TYPE _planType` 区分类型。三者的收发逻辑**完全相同**，只是类型不同。这是新版对旧版的一大重构（旧版三个管理器代码高度重复）。

## 三、任务收发状态机（PlanManager 核心）

所有收发都是**有限状态机 + Ack 超时重试**：

```
【读任务 loadFromVehicle】
MISSION_REQUEST_LIST → MISSION_COUNT（得知总数）
  → 逐个 MISSION_REQUEST(i) → MISSION_ITEM(i)
  → newMissionItemsAvailable 信号

【写任务 writeMissionItems】
MISSION_COUNT（告知总数）
  → 等飞控 MISSION_REQUEST(i) → 发 MISSION_ITEM(i)
  → 全部发完 → MISSION_ACK
  → sendComplete 信号

【清除 removeAll】
MISSION_CLEAR_ALL → MISSION_ACK → removeAllComplete
```

**可靠性设计：**
- Ack 超时 1500ms，最多重试 5 次（`_ackTimeoutMilliseconds` / `_maxRetryCount`）
- 错误码枚举齐全（AckTimeout / ProtocolError / ItemMismatch / VehicleAckError...）
- 写入时保留 `_itemIndicesToWrite` 队列，逐个确认

## 四、MissionItem —— 单个任务项

`MissionItem.h`：一个任务项 = 一条 MAVLink 命令。

| 字段 | 含义 |
|---|---|
| `seq` | 序号（0 开始，home 点是第 0 项） |
| `command` | 命令（WAYPOINT / TAKEOFF / LAND / RTL / SPEED / DELAY / DO_DIGICAM_CONTROL...） |
| `params 1-7` | 命令参数 |
| `coordinate` | 经纬度 + 高度 |
| `frame` | 坐标系（相对 home / 绝对） |
| `autoContinue` | 是否自动执行下一项 |

## 五、复杂任务（测绘/扫描）

`ComplexMissionItem` 会**自动生成一串 MissionItem**：

| 复杂任务 | 类 | 用途 |
|---|---|---|
| 测绘 | SurveyComplexItem | 正射/多光谱航测（自动生成 S 形航线） |
| 走廊扫描 | CorridorScanComplexItem | 沿走廊/管道飞行 |
| 结构扫描 | StructureScanComplexItem | 环绕建筑物 360° 拍摄 |
| 降落 | LandingComplexItem / FixedWingLanding / VTOLLanding | 各类降落模式 |

它们继承 `TransectStyleComplexItem`（航线样式基类），依赖 `CameraCalc`（相机参数计算重叠率/间距）。

## 六、UI 层控制器

任务模块还有一层"控制器"供 UI 使用：

| 类 | 职责 |
|---|---|
| `MissionController` | 单个任务的 UI 控制器 |
| `PlanMasterController` | 计划主控制器（统领 Mission/GeoFence/Rally 三个控制器） |
| `PlanManager` | 与飞控交互的底层管理器 |
| `MissionCommandTree / UIInfo` | 命令的树结构 + UI 显示信息（图标/标签/参数说明） |

`MavCmdInfo*.json`（FixedWing/MultiRotor/Rover/Sub/VTOL）定义了每种载具类型支持哪些命令、命令怎么显示。

## 七、数据流（任务下发全链路）

```
PlanView（QML 规划界面）
  → 用户拖拽航点 / 画测绘区域
  → MissionController（UI 控制器，生成 MissionItem 列表）
  → PlanManager::writeMissionItems（状态机）
  → MAVLink 消息（MISSION_COUNT / MISSION_ITEM）
  → 飞控
```

**读取反之**：飞控 → MISSION_ITEM → PlanManager → MissionController → PlanView 显示。

## 八、对 FlyerLink 的意义

- FlyerLink 的 **`CustomPlanMenuButton`**（自定义规划菜单按钮，见定制模块）就是挂在 PlanView 任务规划流程上的 UI 定制。
- 水下 ROV 如果走任务模式，复用 PlanManager 即可（QGC 已内置 Sub 类型的命令定义 `MavCmdInfoSub.json`）。

---

**下一步**：06-UI层三大视图.md —— QML 界面怎么组织（B 部分最后一篇）。
