# Feedback API

模块：`extensions/feedback`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 2 | 61 | 35 |
| [协议与扩展点](#category-protocol) | 1 | 4 | 4 |
| [资源定义](#category-resource_definition) | 3 | 50 | 16 |
| [运行时句柄](#category-runtime_handle) | 2 | 26 | 10 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFHapticUtility`](classes/GFHapticUtility.md#gfhapticutility) | `GFUtility` | `addons/gf/extensions/feedback/runtime/gf_haptic_utility.gd` |
| [`GFShakeUtility`](classes/GFShakeUtility.md#gfshakeutility) | `GFUtility` | `addons/gf/extensions/feedback/runtime/gf_shake_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFHapticBackend`](classes/GFHapticBackend.md#gfhapticbackend) | `RefCounted` | `addons/gf/extensions/feedback/runtime/gf_haptic_backend.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFHapticPreset`](classes/GFHapticPreset.md#gfhapticpreset) | `Resource` | `addons/gf/extensions/feedback/resources/gf_haptic_preset.gd` |
| [`GFShakePreset`](classes/GFShakePreset.md#gfshakepreset) | `Resource` | `addons/gf/extensions/feedback/resources/gf_shake_preset.gd` |
| [`GFShakeTrack`](classes/GFShakeTrack.md#gfshaketrack) | `Resource` | `addons/gf/extensions/feedback/resources/gf_shake_track.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFShakeReceiver2D`](classes/GFShakeReceiver2D.md#gfshakereceiver2d) | `Node` | `addons/gf/extensions/feedback/nodes/gf_shake_receiver_2d.gd` |
| [`GFShakeReceiver3D`](classes/GFShakeReceiver3D.md#gfshakereceiver3d) | `Node` | `addons/gf/extensions/feedback/nodes/gf_shake_receiver_3d.gd` |
