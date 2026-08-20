# 02 · ROV 三维模型系统

> 基于 `D:\UsefulData\QGC` 的 `View3DModel.qml`（+125）、`Setting3DModel.qml`（+233）、4 个设置项

## 一、模块概览

ROV（水下机器人）三维模型系统是 FlyerLink 的招牌定制，核心能力：**在飞行界面显示一个 3D 模型，实时反映载具的姿态（roll/pitch/yaw）**，并可自定义模型文件、颜色、初始旋转。

```
View3DModel.qml（3D 渲染 + 姿态绑定）
   ↑ 被两处使用
   ├── FlyView 里实时显示（跟随载具姿态）
   └── Setting3DModel.qml 里的预览（跟随滑杆）
```

## 二、View3DModel.qml —— 3D 渲染核心

基于 **QtQuick3D**（新版 QGC 引入的 3D 能力）。

### 2.1 核心：欧拉角 → 四元数

```qml
function eulerToQuaternion(roll, pitch, yaw) { ... }
```

QML 的 3D `Model.rotation` 用的是四元数（quaternion），而载具姿态是欧拉角（roll/pitch/yaw），所以必须转换。这是整个模块的技术关键。

### 2.2 实时姿态可视化（关键绑定）

```qml
Model {
    id: droneModel
    property var sensorRoll:  activeVehicle.roll.value
    property var sensorPitch: activeVehicle.pitch.value
    property var sensorYaw:   activeVehicle.heading.rawValue

    rotation: activeVehicle ? eulerToQuaternion(
        180 - sensorYaw, -sensorRoll, -sensorPitch
    ) : Qt.quaternion(1,0,0,0)   // 无载具时 = 单位四元数（不旋转）
}
```

**数据流**：`Vehicle 的 Fact（roll/pitch/heading）→ eulerToQuaternion → Model.rotation → 3D 模型实时转动`。

> 注意 `180 - sensorYaw` 和负号：因为 3D 模型的初始朝向和载具坐标系的朝向不同，需要坐标系对齐。这是调试 3D 显示时的常见坑。

### 2.3 渲染环境

- `SceneEnvironment`：透明背景（`Transparent`）+ 高抗锯齿（MSAA）
- 3 个 `PointLight` + 1 个 `DirectionalLight`：打光让模型立体
- `PrincipledMaterial`：金属质感（metalness 0.75）

### 2.4 可配置属性

| 属性 | 含义 |
|---|---|
| `modelSource` | 3D 模型文件（.mesh）路径 |
| `baseColor` | 模型颜色 |
| `rotationOffset` | 初始旋转偏移（用户校准） |
| `modelVisible` | 是否显示 |

## 三、Setting3DModel.qml —— 设置窗口

独立的 `Window`（Qt.Dialog），从侧边栏**长按 Modul3D 图标**打开。

### 3.1 功能

| 功能 | 实现 |
|---|---|
| 模型路径 | `FileDialog` 选 .mesh 文件 → 写 `model3DPath` |
| 旋转校准 | Pitch/Roll/Yaw 三个 Slider（-180~180） |
| 实时预览 | 右侧 View3DModel 预览，跟随滑杆 |
| 颜色 | `ColorDialog` → 写 `model3DColor` |
| 保存 | 把 x/y/z 写回 `personalizedModel`（JSON 字符串） |

### 3.2 可拖拽标题栏

标题栏有 `MouseArea` 手动实现窗口拖拽（Qt6 无边框窗口拖拽的常见做法）。

## 四、4 个设置项

| 设置项 | 用途 |
|---|---|
| `view3DStatus` | 是否在 FlyView 显示 3D 模型 |
| `model3DPath` | .mesh 文件路径 |
| `personalizedModel` | JSON 存旋转偏移 `{x,y,z}` |
| `model3DColor` | 材质颜色 |

## 五、数据流总结

```
用户操作（侧边栏长按 → 设置窗口）
  → 写设置项（model3DPath / model3DColor / personalizedModel）
  → View3DModel 读设置 + activeVehicle 姿态
  → eulerToQuaternion 转换
  → Model.rotation 实时更新
  → 3D ROV 模型跟随真实载具姿态转动
```

## 六、技术要点（迁移/维护注意）

1. **依赖 QtQuick3D** —— 旧版 QGC（Qt5）没有这个模块，这是新版独有的能力，FlyerLink 的 3D 模型是**纯新增**（不是迁移旧代码）。
2. **.mesh 格式** —— QtQuick3D 的模型格式，需要工具把常见 3D 格式（obj/fbx）转成 .mesh。
3. **坐标系对齐** —— `180 - yaw` 和负号是校准关键，换模型后可能要重新调。

---

**下一篇**：03-多设备管理.md —— 自定义载具图标 + 多机列表。
