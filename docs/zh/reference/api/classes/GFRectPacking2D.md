# GFRectPacking2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_rect_packing_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

通用 2D 矩形打包算法。 使用 MaxRects 风格的空闲矩形拆分，将一组矩形尺寸放入固定容器或自动求解正方形容器。 它只计算 Rect2i 放置结果，不创建 Texture、Material、Node 或图集资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_RECTS`](#member-gfrectpacking2d-constants-default_max_rects) | `const DEFAULT_MAX_RECTS: int = 4096` |
| 方法 | [`pack_fixed`](#member-gfrectpacking2d-methods-pack_fixed) | `static func pack_fixed( rect_sizes: Array[Vector2i], container_size: Vector2i, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`pack_square`](#member-gfrectpacking2d-methods-pack_square) | `static func pack_square(rect_sizes: Array[Vector2i], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`normalize_placements`](#member-gfrectpacking2d-methods-normalize_placements) | `static func normalize_placements( placements: Array[Rect2i], container_size: Vector2i ) -> Array[Rect2]:` |

## 常量

<a id="member-gfrectpacking2d-constants-default_max_rects"></a>

### `DEFAULT_MAX_RECTS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_RECTS: int = 4096
```

默认最大输入矩形数量，用于避免误把实时大批量数据交给纯 GDScript 打包算法。

## 方法

<a id="member-gfrectpacking2d-methods-pack_fixed"></a>

### `pack_fixed`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func pack_fixed( rect_sizes: Array[Vector2i], container_size: Vector2i, options: Dictionary = {} ) -> Dictionary:
```

将矩形打包进固定容器。

参数：

| 名称 | 说明 |
|---|---|
| `rect_sizes` | 每个矩形的原始尺寸。 |
| `container_size` | 容器尺寸。 |
| `options` | 可选参数，支持 padding、allow_rotate、sort 和 max_rects。 |

返回：打包结果字典。

结构：

- `rect_sizes`: Array[Vector2i]，每项是矩形尺寸；非正尺寸会标记为未放置。
- `options`: Dictionary，padding 为每个矩形四周保留的像素边距，allow_rotate 允许交换宽高，sort 控制是否按尺寸降序优化打包顺序，max_rects 控制最大输入矩形数量。
- `return`: Dictionary，包含 ok、error、container_size、placements、rotated、unplaced_indices、placed_count、used_area 和 occupancy。

<a id="member-gfrectpacking2d-methods-pack_square"></a>

### `pack_square`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func pack_square(rect_sizes: Array[Vector2i], options: Dictionary = {}) -> Dictionary:
```

将矩形打包进自动求解的正方形容器。

参数：

| 名称 | 说明 |
|---|---|
| `rect_sizes` | 每个矩形的原始尺寸。 |
| `options` | 可选参数，支持 padding、allow_rotate、sort、power_of_two、max_size 和 max_rects。 |

返回：打包结果字典。

结构：

- `rect_sizes`: Array[Vector2i]，每项是矩形尺寸；非正尺寸会标记为未放置。
- `options`: Dictionary，power_of_two 为 true 时只返回 2 的幂边长，max_size 大于 0 时限制最大边长，max_rects 控制最大输入矩形数量，其余字段同 pack_fixed()。
- `return`: Dictionary，包含 ok、error、container_size、placements、rotated、unplaced_indices、placed_count、used_area 和 occupancy。

<a id="member-gfrectpacking2d-methods-normalize_placements"></a>

### `normalize_placements`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func normalize_placements( placements: Array[Rect2i], container_size: Vector2i ) -> Array[Rect2]:
```

将像素 Rect2i 放置结果归一化为 0 到 1 的 Rect2。

参数：

| 名称 | 说明 |
|---|---|
| `placements` | 像素矩形列表。 |
| `container_size` | 容器尺寸。 |

返回：归一化矩形列表。

结构：

- `placements`: Array[Rect2i]，通常来自 pack_fixed() 或 pack_square() 的 placements 字段。
- `return`: Array[Rect2]，与输入顺序一致；无效容器或空矩形会返回空 Rect2。
