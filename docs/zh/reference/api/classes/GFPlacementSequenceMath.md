# GFPlacementSequenceMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_placement_sequence_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

连续放置序列的纯数学预测工具。 根据已经确认的放置点或格子，预测下一次放置候选位置。它只处理纯数据， 不创建节点、不读取场景、不绑定编辑器选择、UndoRedo、碰撞或重叠规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`MODE_FALLBACK`](#member-gfplacementsequencemath-constants-mode_fallback) | `const MODE_FALLBACK: StringName = &"fallback"` |
| 常量 | [`MODE_REPEAT_LAST`](#member-gfplacementsequencemath-constants-mode_repeat_last) | `const MODE_REPEAT_LAST: StringName = &"repeat_last"` |
| 常量 | [`MODE_EXTRAPOLATED`](#member-gfplacementsequencemath-constants-mode_extrapolated) | `const MODE_EXTRAPOLATED: StringName = &"extrapolated"` |
| 方法 | [`predict_next_position_2d`](#member-gfplacementsequencemath-methods-predict_next_position_2d) | `static func predict_next_position_2d( positions: Array[Vector2], fallback_position: Vector2 = Vector2.ZERO, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`predict_next_position_3d`](#member-gfplacementsequencemath-methods-predict_next_position_3d) | `static func predict_next_position_3d( positions: Array[Vector3], fallback_position: Vector3 = Vector3.ZERO, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`predict_next_cell_2d`](#member-gfplacementsequencemath-methods-predict_next_cell_2d) | `static func predict_next_cell_2d( cells: Array[Vector2i], fallback_cell: Vector2i = Vector2i.ZERO ) -> Dictionary:` |
| 方法 | [`predict_next_cell_3d`](#member-gfplacementsequencemath-methods-predict_next_cell_3d) | `static func predict_next_cell_3d( cells: Array[Vector3i], fallback_cell: Vector3i = Vector3i.ZERO ) -> Dictionary:` |

## 常量

<a id="member-gfplacementsequencemath-constants-mode_fallback"></a>

### `MODE_FALLBACK`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MODE_FALLBACK: StringName = &"fallback"
```

没有可用历史时使用调用方提供的 fallback。

<a id="member-gfplacementsequencemath-constants-mode_repeat_last"></a>

### `MODE_REPEAT_LAST`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MODE_REPEAT_LAST: StringName = &"repeat_last"
```

只有一个可用历史点时复用最后一次放置位置。

<a id="member-gfplacementsequencemath-constants-mode_extrapolated"></a>

### `MODE_EXTRAPOLATED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MODE_EXTRAPOLATED: StringName = &"extrapolated"
```

至少有两个可用历史点时按 `last + (last - previous)` 推断下一次位置。

## 方法

<a id="member-gfplacementsequencemath-methods-predict_next_position_2d"></a>

### `predict_next_position_2d`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func predict_next_position_2d( positions: Array[Vector2], fallback_position: Vector2 = Vector2.ZERO, options: Dictionary = {} ) -> Dictionary:
```

预测下一次 2D 连续位置。

参数：

| 名称 | 说明 |
|---|---|
| `positions` | 已确认的放置位置，按时间顺序排列。 |
| `fallback_position` | 没有历史位置时使用的候选位置。 |
| `options` | 可选项，支持 max_step_length 限制外推步长；小于等于 0 时不限制。 |

返回：预测报告。

结构：

- `options`: Dictionary，可包含 max_step_length: float。
- `return`: Dictionary，包含 ok、mode、position、step、source_count、valid_count、ignored_invalid_count、clamped、max_step_length 和 error。

<a id="member-gfplacementsequencemath-methods-predict_next_position_3d"></a>

### `predict_next_position_3d`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func predict_next_position_3d( positions: Array[Vector3], fallback_position: Vector3 = Vector3.ZERO, options: Dictionary = {} ) -> Dictionary:
```

预测下一次 3D 连续位置。

参数：

| 名称 | 说明 |
|---|---|
| `positions` | 已确认的放置位置，按时间顺序排列。 |
| `fallback_position` | 没有历史位置时使用的候选位置。 |
| `options` | 可选项，支持 max_step_length 限制外推步长；小于等于 0 时不限制。 |

返回：预测报告。

结构：

- `options`: Dictionary，可包含 max_step_length: float。
- `return`: Dictionary，包含 ok、mode、position、step、source_count、valid_count、ignored_invalid_count、clamped、max_step_length 和 error。

<a id="member-gfplacementsequencemath-methods-predict_next_cell_2d"></a>

### `predict_next_cell_2d`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func predict_next_cell_2d( cells: Array[Vector2i], fallback_cell: Vector2i = Vector2i.ZERO ) -> Dictionary:
```

预测下一次 2D 离散格子。

参数：

| 名称 | 说明 |
|---|---|
| `cells` | 已确认的放置格子，按时间顺序排列。 |
| `fallback_cell` | 没有历史格子时使用的候选格子。 |

返回：预测报告。

结构：

- `return`: Dictionary，包含 ok、mode、cell、step、source_count、valid_count、ignored_invalid_count 和 error。

<a id="member-gfplacementsequencemath-methods-predict_next_cell_3d"></a>

### `predict_next_cell_3d`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func predict_next_cell_3d( cells: Array[Vector3i], fallback_cell: Vector3i = Vector3i.ZERO ) -> Dictionary:
```

预测下一次 3D 离散格子。

参数：

| 名称 | 说明 |
|---|---|
| `cells` | 已确认的放置格子，按时间顺序排列。 |
| `fallback_cell` | 没有历史格子时使用的候选格子。 |

返回：预测报告。

结构：

- `return`: Dictionary，包含 ok、mode、cell、step、source_count、valid_count、ignored_invalid_count 和 error。
