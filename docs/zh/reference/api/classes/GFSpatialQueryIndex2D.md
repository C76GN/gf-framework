# GFSpatialQueryIndex2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial/gf_spatial_query_index_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

2D 空间查询策略 facade。 在统一 API 后面封装线性扫描与四叉树索引，让项目可按数据规模切换策略。 它只维护调用方提供的 Rect2 和 metadata，不解释实体身份或玩法过滤规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STRATEGY_AUTO`](#member-gfspatialqueryindex2d-constants-strategy_auto) | `const STRATEGY_AUTO: StringName = &"auto"` |
| 常量 | [`STRATEGY_LINEAR`](#member-gfspatialqueryindex2d-constants-strategy_linear) | `const STRATEGY_LINEAR: StringName = &"linear"` |
| 常量 | [`STRATEGY_QUADTREE`](#member-gfspatialqueryindex2d-constants-strategy_quadtree) | `const STRATEGY_QUADTREE: StringName = &"quadtree"` |
| 属性 | [`strategy`](#member-gfspatialqueryindex2d-properties-strategy) | `var strategy: StringName = STRATEGY_AUTO:` |
| 属性 | [`bounds`](#member-gfspatialqueryindex2d-properties-bounds) | `var bounds: Rect2 = Rect2():` |
| 属性 | [`auto_quadtree_threshold`](#member-gfspatialqueryindex2d-properties-auto_quadtree_threshold) | `var auto_quadtree_threshold: int = 64:` |
| 属性 | [`quadtree_max_depth`](#member-gfspatialqueryindex2d-properties-quadtree_max_depth) | `var quadtree_max_depth: int = GFQuadTreeUtility.DEFAULT_MAX_DEPTH:` |
| 属性 | [`quadtree_max_entities`](#member-gfspatialqueryindex2d-properties-quadtree_max_entities) | `var quadtree_max_entities: int = GFQuadTreeUtility.DEFAULT_MAX_ENTITIES:` |
| 方法 | [`configure`](#member-gfspatialqueryindex2d-methods-configure) | `func configure( world_bounds: Rect2, p_strategy: StringName = STRATEGY_AUTO, options: Dictionary = {} ) -> GFSpatialQueryIndex2D:` |
| 方法 | [`upsert`](#member-gfspatialqueryindex2d-methods-upsert) | `func upsert(entity_id: int, rect: Rect2, p_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`upsert_point`](#member-gfspatialqueryindex2d-methods-upsert_point) | `func upsert_point( entity_id: int, position: Vector2, radius: float = 0.0, p_metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`remove`](#member-gfspatialqueryindex2d-methods-remove) | `func remove(entity_id: int) -> bool:` |
| 方法 | [`clear`](#member-gfspatialqueryindex2d-methods-clear) | `func clear() -> void:` |
| 方法 | [`has_entity`](#member-gfspatialqueryindex2d-methods-has_entity) | `func has_entity(entity_id: int) -> bool:` |
| 方法 | [`get_entity_count`](#member-gfspatialqueryindex2d-methods-get_entity_count) | `func get_entity_count() -> int:` |
| 方法 | [`get_entity_record`](#member-gfspatialqueryindex2d-methods-get_entity_record) | `func get_entity_record(entity_id: int) -> Dictionary:` |
| 方法 | [`query_rect`](#member-gfspatialqueryindex2d-methods-query_rect) | `func query_rect(area: Rect2) -> Array[int]:` |
| 方法 | [`query_rect_into`](#member-gfspatialqueryindex2d-methods-query_rect_into) | `func query_rect_into(area: Rect2, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:` |
| 方法 | [`query_radius`](#member-gfspatialqueryindex2d-methods-query_radius) | `func query_radius(center: Vector2, radius: float) -> Array[int]:` |
| 方法 | [`query_radius_into`](#member-gfspatialqueryindex2d-methods-query_radius_into) | `func query_radius_into(center: Vector2, radius: float, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:` |
| 方法 | [`query_point`](#member-gfspatialqueryindex2d-methods-query_point) | `func query_point(point: Vector2) -> Array[int]:` |
| 方法 | [`query_point_into`](#member-gfspatialqueryindex2d-methods-query_point_into) | `func query_point_into(point: Vector2, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:` |
| 方法 | [`query_records_rect`](#member-gfspatialqueryindex2d-methods-query_records_rect) | `func query_records_rect(area: Rect2) -> Array[Dictionary]:` |
| 方法 | [`query_records_rect_into`](#member-gfspatialqueryindex2d-methods-query_records_rect_into) | `func query_records_rect_into(area: Rect2, out_records: Array[Dictionary], clear_output: bool = true) -> Array[Dictionary]:` |
| 方法 | [`query_records_radius`](#member-gfspatialqueryindex2d-methods-query_records_radius) | `func query_records_radius(center: Vector2, radius: float) -> Array[Dictionary]:` |
| 方法 | [`query_records_radius_into`](#member-gfspatialqueryindex2d-methods-query_records_radius_into) | `func query_records_radius_into( center: Vector2, radius: float, out_records: Array[Dictionary], clear_output: bool = true ) -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfspatialqueryindex2d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfspatialqueryindex2d-constants-strategy_auto"></a>

### `STRATEGY_AUTO`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STRATEGY_AUTO: StringName = &"auto"
```

根据实体数量和 bounds 自动选择策略。

<a id="member-gfspatialqueryindex2d-constants-strategy_linear"></a>

### `STRATEGY_LINEAR`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STRATEGY_LINEAR: StringName = &"linear"
```

使用线性扫描。

<a id="member-gfspatialqueryindex2d-constants-strategy_quadtree"></a>

### `STRATEGY_QUADTREE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STRATEGY_QUADTREE: StringName = &"quadtree"
```

使用 GFQuadTreeUtility。

## 属性

<a id="member-gfspatialqueryindex2d-properties-strategy"></a>

### `strategy`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var strategy: StringName = STRATEGY_AUTO:
```

当前策略。

<a id="member-gfspatialqueryindex2d-properties-bounds"></a>

### `bounds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var bounds: Rect2 = Rect2():
```

索引世界边界。

<a id="member-gfspatialqueryindex2d-properties-auto_quadtree_threshold"></a>

### `auto_quadtree_threshold`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var auto_quadtree_threshold: int = 64:
```

auto 策略切换到四叉树的实体数量阈值。

<a id="member-gfspatialqueryindex2d-properties-quadtree_max_depth"></a>

### `quadtree_max_depth`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var quadtree_max_depth: int = GFQuadTreeUtility.DEFAULT_MAX_DEPTH:
```

四叉树最大深度。

<a id="member-gfspatialqueryindex2d-properties-quadtree_max_entities"></a>

### `quadtree_max_entities`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var quadtree_max_entities: int = GFQuadTreeUtility.DEFAULT_MAX_ENTITIES:
```

四叉树单节点实体上限。

## 方法

<a id="member-gfspatialqueryindex2d-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( world_bounds: Rect2, p_strategy: StringName = STRATEGY_AUTO, options: Dictionary = {} ) -> GFSpatialQueryIndex2D:
```

配置索引。

参数：

| 名称 | 说明 |
|---|---|
| `world_bounds` | 索引世界边界。 |
| `p_strategy` | 查询策略。 |
| `options` | 配置选项，支持 auto_quadtree_threshold、quadtree_max_depth 和 quadtree_max_entities。 |

返回：当前索引。

结构：

- `options`: Dictionary，可包含 auto_quadtree_threshold、quadtree_max_depth 和 quadtree_max_entities。

<a id="member-gfspatialqueryindex2d-methods-upsert"></a>

### `upsert`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func upsert(entity_id: int, rect: Rect2, p_metadata: Dictionary = {}) -> bool:
```

插入或更新实体 Rect2。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |
| `rect` | 实体包围矩形。 |
| `p_metadata` | 调用方元数据。 |

返回：成功时返回 true。

结构：

- `p_metadata`: Dictionary copied into entity record metadata.

<a id="member-gfspatialqueryindex2d-methods-upsert_point"></a>

### `upsert_point`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func upsert_point( entity_id: int, position: Vector2, radius: float = 0.0, p_metadata: Dictionary = {} ) -> bool:
```

插入或更新以点和半径表示的实体。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |
| `position` | 实体位置。 |
| `radius` | 包围半径。 |
| `p_metadata` | 调用方元数据。 |

返回：成功时返回 true。

结构：

- `p_metadata`: Dictionary copied into entity record metadata.

<a id="member-gfspatialqueryindex2d-methods-remove"></a>

### `remove`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove(entity_id: int) -> bool:
```

移除实体。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |

返回：找到并移除时返回 true。

<a id="member-gfspatialqueryindex2d-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空索引。

<a id="member-gfspatialqueryindex2d-methods-has_entity"></a>

### `has_entity`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_entity(entity_id: int) -> bool:
```

检查实体是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |

返回：存在时返回 true。

<a id="member-gfspatialqueryindex2d-methods-get_entity_count"></a>

### `get_entity_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_entity_count() -> int:
```

获取实体数量。

返回：实体数量。

<a id="member-gfspatialqueryindex2d-methods-get_entity_record"></a>

### `get_entity_record`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_entity_record(entity_id: int) -> Dictionary:
```

获取实体记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |

返回：实体记录；不存在时为空字典。

结构：

- `return`: Dictionary，包含 entity_id、bounds 和 metadata。

<a id="member-gfspatialqueryindex2d-methods-query_rect"></a>

### `query_rect`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_rect(area: Rect2) -> Array[int]:
```

查询与 Rect2 相交的实体 ID。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询矩形。 |

返回：匹配实体 ID 数组。

<a id="member-gfspatialqueryindex2d-methods-query_rect_into"></a>

### `query_rect_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_rect_into(area: Rect2, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:
```

查询与 Rect2 相交的实体 ID，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询矩形。 |
| `out_entity_ids` | 接收匹配实体 ID 的数组。 |
| `clear_output` | 为 true 时先清空 out_entity_ids。 |

返回：同一个 out_entity_ids 数组。

<a id="member-gfspatialqueryindex2d-methods-query_radius"></a>

### `query_radius`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_radius(center: Vector2, radius: float) -> Array[int]:
```

查询与圆相交的实体 ID。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 圆心。 |
| `radius` | 半径。 |

返回：匹配实体 ID 数组。

<a id="member-gfspatialqueryindex2d-methods-query_radius_into"></a>

### `query_radius_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_radius_into(center: Vector2, radius: float, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:
```

查询与圆相交的实体 ID，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 圆心。 |
| `radius` | 半径。 |
| `out_entity_ids` | 接收匹配实体 ID 的数组。 |
| `clear_output` | 为 true 时先清空 out_entity_ids。 |

返回：同一个 out_entity_ids 数组。

<a id="member-gfspatialqueryindex2d-methods-query_point"></a>

### `query_point`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_point(point: Vector2) -> Array[int]:
```

查询包含点的实体 ID。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 查询点。 |

返回：匹配实体 ID 数组。

<a id="member-gfspatialqueryindex2d-methods-query_point_into"></a>

### `query_point_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_point_into(point: Vector2, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:
```

查询包含点的实体 ID，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 查询点。 |
| `out_entity_ids` | 接收匹配实体 ID 的数组。 |
| `clear_output` | 为 true 时先清空 out_entity_ids。 |

返回：同一个 out_entity_ids 数组。

<a id="member-gfspatialqueryindex2d-methods-query_records_rect"></a>

### `query_records_rect`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_rect(area: Rect2) -> Array[Dictionary]:
```

查询与 Rect2 相交的实体记录。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询矩形。 |

返回：匹配实体记录数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。

<a id="member-gfspatialqueryindex2d-methods-query_records_rect_into"></a>

### `query_records_rect_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_rect_into(area: Rect2, out_records: Array[Dictionary], clear_output: bool = true) -> Array[Dictionary]:
```

查询与 Rect2 相交的实体记录，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询矩形。 |
| `out_records` | 接收匹配实体记录的数组。 |
| `clear_output` | 为 true 时先清空 out_records。 |

返回：同一个 out_records 数组。

结构：

- `return`: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity_id、bounds 和 metadata。
- `out_records`: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。

<a id="member-gfspatialqueryindex2d-methods-query_records_radius"></a>

### `query_records_radius`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_radius(center: Vector2, radius: float) -> Array[Dictionary]:
```

查询与圆相交的实体记录。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 圆心。 |
| `radius` | 半径。 |

返回：匹配实体记录数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。

<a id="member-gfspatialqueryindex2d-methods-query_records_radius_into"></a>

### `query_records_radius_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_radius_into( center: Vector2, radius: float, out_records: Array[Dictionary], clear_output: bool = true ) -> Array[Dictionary]:
```

查询与圆相交的实体记录，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 圆心。 |
| `radius` | 半径。 |
| `out_records` | 接收匹配实体记录的数组。 |
| `clear_output` | 为 true 时先清空 out_records。 |

返回：同一个 out_records 数组。

结构：

- `return`: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity_id、bounds 和 metadata。
- `out_records`: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。

<a id="member-gfspatialqueryindex2d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 strategy、active_strategy、bounds、entity_count 和 index_dirty。
