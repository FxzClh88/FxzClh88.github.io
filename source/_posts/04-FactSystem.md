---
title: FactSystem
date: 2026-08-14 12:00:00
categories: [QGC,FactSystem]
tags: [标签1, 标签2, 标签3]
description: FactSystem
cover: /img/banner.jpg
# sticky: 1   # 想置顶就取消这行注释（数字越大越靠前）
---
# 04 · FactSystem（事实系统 / 参数抽象层）

> 基于 `2.0.5\source\qgroundcontrol\src\FactSystem\`

## 一、FactSystem 是什么

QGC 把"飞控参数"和"实时遥测数据"统一抽象成 **Fact**（事实）。所有参数的读写、显示、校验都走这一套机制。

```
飞控参数 / 遥测数据
        ↓
ParameterManager（下载/读写/缓存）
        ↓
Fact（单个值：名字 + 元数据 + 值 + 单位）
        ↓
FactGroup（一组 Facts 的容器，如 Vehicle 本体）
        ↓
QML UI（自动绑定显示 + 编辑控件）
```

## 二、Fact —— 单个事实（核心单元）

`src/FactSystem/Fact.h`，继承 QObject，QML 可用。

**核心概念：raw value vs cooked value（最关键的一条）**

| 值 | 含义 | 例子 |
|---|---|---|
| `rawValue` | 飞控的**原始值** | 温度 = 2345（厘摄氏度） |
| `cookedValue` | **换算后**的用户单位值 | 温度 = 23.45（摄氏度） |

中间有 translator 做单位换算。QML 显示用 `cookedValue`，发给飞控用 `rawValue`。这是 QGC 参数系统最核心的设计。

**Fact 的关键属性（QML 直接读）：**

| 属性 | 含义 |
|---|---|
| `name` | 参数名（如 `WPNAV_SPEED`） |
| `value` / `rawValue` | cooked 值 / raw 值 |
| `defaultValue` | 默认值 |
| `min` / `max` | 取值范围 |
| `units` | 单位（m、m/s、°C...） |
| `enumStrings` / `enumValues` | 枚举项（模式选择） |
| `decimalPlaces` | 小数位 |
| `label` / `shortDescription` / `longDescription` | 显示名 / 简介 / 详述 |
| `readOnly` / `writeOnly` | 读写权限 |
| `category` / `group` | 分类 / 分组 |

**关键信号：**

| 信号 | 含义 |
|---|---|
| `valueChanged` | 值变化（UI 自动刷新） |
| `containerRawValueChanged` | 用户改了值 → 发给飞控 |
| `vehicleUpdated` | 飞控确认写入（ACK 回来） |

## 三、FactMetaData —— 参数元数据

`FactMetaData.h` + `factmetadata.schema.json`。

元数据 = 参数的类型、单位、范围、枚举、描述、小数位。**从飞控固件的参数定义自动生成**（PX4/APM 的参数表），编译期注入 QGC。

> 意义：QGC 不硬编码每个参数，而是靠元数据动态描述。这样任何飞控固件的参数都能自动正确显示。

## 四、FactGroup —— 事实组容器

`FactGroup.h`：把一组相关 Facts 打包。`FactGroupWithId` 是带 ID 的变体。

**Vehicle 本身就是 FactGroup**（`VehicleFactGroup`），所以 QML 里：

```qml
vehicle.vehicle.roll.value      // 横滚角
vehicle.gps.lat.value           // GPS 纬度
vehicle.battery.percent.value   // 电量百分比
```

结构是 `载具 → FactGroup → Fact → value`。

## 五、ParameterManager —— 参数下载/读写/缓存

`src/FactSystem/ParameterManager.h`，是 Vehicle 的子管理器（`vehicle->parameterManager`）。

**核心数据：** `_mapCompId2FactMap` = `componentId → (参数名 → Fact*)` 两级映射。

**参数下载流程（连接时）：**

```
1. 发送 PARAM_REQUEST_LIST（请求全部参数列表）
2. 飞控逐个回 PARAM_VALUE → _handleParamValue() 建 Fact
3. PX4 飞控：先 _HASH_CHECK 哈希校验，命中缓存则秒加载
4. 参数缓存到本地文件（parameterCacheFile）
5. parametersReady 信号（参数就绪）
```

**写参数流程：**

```
QML 改 Fact.value
  → containerRawValueChanged 信号
  → _mavlinkParamSet() 发 PARAM_SET
  → 等 ACK（超时 1000ms，重试 2 次）
  → vehicleUpdated 信号（确认写入成功）
```

**其他能力：**
- 参数名 remap（`_remapParamNameToVersion`）：固件版本升级后参数改名，自动映射
- 批量刷新（`bulkRefresh`）：指数退避重试
- 参数导出（`writeParametersToStream`）

## 六、一句话总结

| 概念 | 一句话 |
|---|---|
| Fact | 一个带元数据的值（参数/遥测） |
| FactMetaData | 这个值的"说明书"（类型/范围/单位/描述） |
| FactGroup | 一组值的"文件夹" |
| ParameterManager | 参数的"快递员"（下载/写入/缓存） |

> **对 FlyerLink 的意义**：水下组件（声纳/深度）如果有自定义参数，就是通过这个 FactSystem 接入的——自定义 FactMetaData + FactGroup 即可，不用动 UI 框架。

---

**下一步**：05-任务规划MissionManager.md —— 航点任务怎么收发。
