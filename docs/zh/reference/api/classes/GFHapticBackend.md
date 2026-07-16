# GFHapticBackend

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/runtime/gf_haptic_backend.gd`
- 模块：`Feedback`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

震动输出后端协议。 项目可实现该协议，把 GFHapticUtility 的采样输出路由到平台 SDK、远程设备、 测试替身或自定义输入系统。该协议只承载输出能力，不定义播放策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`start_output`](#member-gfhapticbackend-methods-start_output) | `func start_output( target_type: int, target_id: int, weak_magnitude: float, strong_magnitude: float, duration_seconds: float, metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`stop_output`](#member-gfhapticbackend-methods-stop_output) | `func stop_output(target_type: int, target_id: int, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`_start_output`](#member-gfhapticbackend-methods-_start_output) | `func _start_output( _target_type: int, _target_id: int, _weak_magnitude: float, _strong_magnitude: float, _duration_seconds: float, _metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`_stop_output`](#member-gfhapticbackend-methods-_stop_output) | `func _stop_output(_target_type: int, _target_id: int, _metadata: Dictionary = {}) -> bool:` |

## 方法

<a id="member-gfhapticbackend-methods-start_output"></a>

### `start_output`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func start_output( target_type: int, target_id: int, weak_magnitude: float, strong_magnitude: float, duration_seconds: float, metadata: Dictionary = {} ) -> bool:
```

开始或刷新一次震动输出。

参数：

| 名称 | 说明 |
|---|---|
| `target_type` | GFHapticUtility.TargetType 值。 |
| `target_id` | 玩家索引或设备 ID。 |
| `weak_magnitude` | 弱马达强度。 |
| `strong_magnitude` | 强马达强度。 |
| `duration_seconds` | 输出持续时间。 |
| `metadata` | 输出元数据。 |

返回：后端接受输出时返回 true。

结构：

- `metadata`: Dictionary copied from GFHapticUtility output target metadata.

<a id="member-gfhapticbackend-methods-stop_output"></a>

### `stop_output`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func stop_output(target_type: int, target_id: int, metadata: Dictionary = {}) -> bool:
```

停止指定目标的震动输出。

参数：

| 名称 | 说明 |
|---|---|
| `target_type` | GFHapticUtility.TargetType 值。 |
| `target_id` | 玩家索引或设备 ID。 |
| `metadata` | 输出元数据。 |

返回：后端确认停止时返回 true。

结构：

- `metadata`: Dictionary copied from GFHapticUtility output target metadata.

<a id="member-gfhapticbackend-methods-_start_output"></a>

### `_start_output`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _start_output( _target_type: int, _target_id: int, _weak_magnitude: float, _strong_magnitude: float, _duration_seconds: float, _metadata: Dictionary = {} ) -> bool:
```

子类实现开始或刷新震动输出。

参数：

| 名称 | 说明 |
|---|---|
| `_target_type` | GFHapticUtility.TargetType 值。 |
| `_target_id` | 玩家索引或设备 ID。 |
| `_weak_magnitude` | 弱马达强度。 |
| `_strong_magnitude` | 强马达强度。 |
| `_duration_seconds` | 输出持续时间。 |
| `_metadata` | 输出元数据。 |

返回：后端接受输出时返回 true。

结构：

- `_metadata`: Dictionary copied from GFHapticUtility output target metadata.

<a id="member-gfhapticbackend-methods-_stop_output"></a>

### `_stop_output`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _stop_output(_target_type: int, _target_id: int, _metadata: Dictionary = {}) -> bool:
```

子类实现停止震动输出。

参数：

| 名称 | 说明 |
|---|---|
| `_target_type` | GFHapticUtility.TargetType 值。 |
| `_target_id` | 玩家索引或设备 ID。 |
| `_metadata` | 输出元数据。 |

返回：后端确认停止时返回 true。

结构：

- `_metadata`: Dictionary copied from GFHapticUtility output target metadata.
