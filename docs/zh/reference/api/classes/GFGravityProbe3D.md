# GFGravityProbe3D

[API Reference](../index.md) / [Physics](../extensions-physics.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/physics/nodes/gf_gravity_probe_3d.gd`
- 模块：`Physics`
- 继承：`Node3D`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用 3D 重力采样器。 从场景树分组中采样 GFGravityField3D 或任何暴露 get_acceleration_at() 方法的对象，并按组合策略计算当前位置处的加速度、上下方向。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CombinationMode`](#member-gfgravityprobe3d-enums-combinationmode) | `enum CombinationMode` |
| 属性 | [`field_group`](#member-gfgravityprobe3d-properties-field_group) | `var field_group: StringName = &"gf_gravity_field_3d"` |
| 属性 | [`combination_mode`](#member-gfgravityprobe3d-properties-combination_mode) | `var combination_mode: CombinationMode = CombinationMode.SUM` |
| 属性 | [`use_fallback_when_empty`](#member-gfgravityprobe3d-properties-use_fallback_when_empty) | `var use_fallback_when_empty: bool = true` |
| 属性 | [`fallback_acceleration`](#member-gfgravityprobe3d-properties-fallback_acceleration) | `var fallback_acceleration: Vector3 = Vector3.DOWN * 9.8` |
| 属性 | [`cache_samples_per_frame`](#member-gfgravityprobe3d-properties-cache_samples_per_frame) | `var cache_samples_per_frame: bool = true` |
| 属性 | [`last_acceleration`](#member-gfgravityprobe3d-properties-last_acceleration) | `var last_acceleration: Vector3 = Vector3.ZERO` |
| 方法 | [`sample`](#member-gfgravityprobe3d-methods-sample) | `func sample() -> Vector3:` |
| 方法 | [`sample_fields`](#member-gfgravityprobe3d-methods-sample_fields) | `func sample_fields(fields: Array) -> Vector3:` |
| 方法 | [`sample_field_provider`](#member-gfgravityprobe3d-methods-sample_field_provider) | `func sample_field_provider(candidate_provider: Object, options: Dictionary = {}) -> Vector3:` |
| 方法 | [`get_down_direction`](#member-gfgravityprobe3d-methods-get_down_direction) | `func get_down_direction() -> Vector3:` |
| 方法 | [`get_up_direction`](#member-gfgravityprobe3d-methods-get_up_direction) | `func get_up_direction() -> Vector3:` |
| 方法 | [`invalidate_cache`](#member-gfgravityprobe3d-methods-invalidate_cache) | `func invalidate_cache() -> void:` |

## 枚举

<a id="member-gfgravityprobe3d-enums-combinationmode"></a>

### `CombinationMode`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum CombinationMode {
	## 汇总所有有效力场的加速度。
	SUM,
	## 只使用当前点加速度长度最大的力场。
	STRONGEST,
	## 只汇总当前点非零加速度中最高优先级的力场。
	HIGHEST_PRIORITY,
}
```

多个力场重叠时的采样组合策略。

## 属性

<a id="member-gfgravityprobe3d-properties-field_group"></a>

### `field_group`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var field_group: StringName = &"gf_gravity_field_3d"
```

要采样的力场分组。

<a id="member-gfgravityprobe3d-properties-combination_mode"></a>

### `combination_mode`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var combination_mode: CombinationMode = CombinationMode.SUM
```

多个力场重叠时的组合策略。

<a id="member-gfgravityprobe3d-properties-use_fallback_when_empty"></a>

### `use_fallback_when_empty`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var use_fallback_when_empty: bool = true
```

找不到力场时是否返回 fallback_acceleration。

<a id="member-gfgravityprobe3d-properties-fallback_acceleration"></a>

### `fallback_acceleration`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var fallback_acceleration: Vector3 = Vector3.DOWN * 9.8
```

找不到力场时使用的默认加速度。

<a id="member-gfgravityprobe3d-properties-cache_samples_per_frame"></a>

### `cache_samples_per_frame`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var cache_samples_per_frame: bool = true
```

同一帧、同一位置重复 sample() 时是否复用上次结果。

<a id="member-gfgravityprobe3d-properties-last_acceleration"></a>

### `last_acceleration`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var last_acceleration: Vector3 = Vector3.ZERO
```

最近一次 sample() 得到的加速度。

## 方法

<a id="member-gfgravityprobe3d-methods-sample"></a>

### `sample`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func sample() -> Vector3:
```

采样场景树分组中的所有力场。

返回：按 combination_mode 组合后的加速度。

<a id="member-gfgravityprobe3d-methods-sample_fields"></a>

### `sample_fields`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func sample_fields(fields: Array) -> Vector3:
```

采样指定力场列表。

参数：

| 名称 | 说明 |
|---|---|
| `fields` | 力场对象列表。 |

返回：按 combination_mode 组合后的加速度。

结构：

- `fields`: Array，包含 GFGravityField3D 或任何暴露 get_acceleration_at(Vector3) 的 Object。

<a id="member-gfgravityprobe3d-methods-sample_field_provider"></a>

### `sample_field_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func sample_field_provider(candidate_provider: Object, options: Dictionary = {}) -> Vector3:
```

从候选 provider 采样力场。

参数：

| 名称 | 说明 |
|---|---|
| `candidate_provider` | 暴露 get_candidate_objects(options) 的候选 provider。 |
| `options` | 候选查询选项；未设置 method_name 时默认筛选 get_acceleration_at。 |

返回：按 combination_mode 组合后的加速度。

结构：

- `options`: Dictionary passed to candidate_provider.get_candidate_objects(); method_name defaults to get_acceleration_at.

<a id="member-gfgravityprobe3d-methods-get_down_direction"></a>

### `get_down_direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_down_direction() -> Vector3:
```

获取当前位置的向下方向。

返回：向下方向。

<a id="member-gfgravityprobe3d-methods-get_up_direction"></a>

### `get_up_direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_up_direction() -> Vector3:
```

获取当前位置的向上方向。

返回：向上方向。

<a id="member-gfgravityprobe3d-methods-invalidate_cache"></a>

### `invalidate_cache`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func invalidate_cache() -> void:
```

清空当前帧采样缓存。
