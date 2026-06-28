# GFSpatialQueryIndex3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial/gf_spatial_query_index_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

3D 空间查询策略 facade。 在统一 API 后面封装线性扫描与空间哈希索引，让项目可按数据规模切换策略。 它只维护调用方提供的 AABB 和 metadata，不解释实体身份或玩法过滤规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STRATEGY_AUTO`](#member-gfspatialqueryindex3d-constants-strategy_auto) | `const STRATEGY_AUTO: StringName = &"auto"` |
| 常量 | [`STRATEGY_LINEAR`](#member-gfspatialqueryindex3d-constants-strategy_linear) | `const STRATEGY_LINEAR: StringName = &"linear"` |
| 常量 | [`STRATEGY_SPATIAL_HASH`](#member-gfspatialqueryindex3d-constants-strategy_spatial_hash) | `const STRATEGY_SPATIAL_HASH: StringName = &"spatial_hash"` |
| 属性 | [`strategy`](#member-gfspatialqueryindex3d-properties-strategy) | `var strategy: StringName = STRATEGY_AUTO:` |
| 属性 | [`cell_size`](#member-gfspatialqueryindex3d-properties-cell_size) | `var cell_size: float = 4.0:` |
| 属性 | [`auto_spatial_hash_threshold`](#member-gfspatialqueryindex3d-properties-auto_spatial_hash_threshold) | `var auto_spatial_hash_threshold: int = 64:` |
| 方法 | [`configure`](#member-gfspatialqueryindex3d-methods-configure) | `func configure(p_strategy: StringName = STRATEGY_AUTO, options: Dictionary = {}) -> GFSpatialQueryIndex3D:` |
| 方法 | [`upsert`](#member-gfspatialqueryindex3d-methods-upsert) | `func upsert(entity: Variant, entity_bounds: AABB, p_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`remove`](#member-gfspatialqueryindex3d-methods-remove) | `func remove(entity: Variant) -> bool:` |
| 方法 | [`clear`](#member-gfspatialqueryindex3d-methods-clear) | `func clear() -> void:` |
| 方法 | [`has_entity`](#member-gfspatialqueryindex3d-methods-has_entity) | `func has_entity(entity: Variant) -> bool:` |
| 方法 | [`get_entity_count`](#member-gfspatialqueryindex3d-methods-get_entity_count) | `func get_entity_count() -> int:` |
| 方法 | [`prune_invalid_entities`](#member-gfspatialqueryindex3d-methods-prune_invalid_entities) | `func prune_invalid_entities() -> void:` |
| 方法 | [`get_entity_record`](#member-gfspatialqueryindex3d-methods-get_entity_record) | `func get_entity_record(entity: Variant) -> Dictionary:` |
| 方法 | [`query_aabb`](#member-gfspatialqueryindex3d-methods-query_aabb) | `func query_aabb(area: AABB) -> Array[Variant]:` |
| 方法 | [`query_aabb_into`](#member-gfspatialqueryindex3d-methods-query_aabb_into) | `func query_aabb_into(area: AABB, out_entities: Array, clear_output: bool = true) -> Array:` |
| 方法 | [`query_radius`](#member-gfspatialqueryindex3d-methods-query_radius) | `func query_radius(center: Vector3, radius: float) -> Array[Variant]:` |
| 方法 | [`query_radius_into`](#member-gfspatialqueryindex3d-methods-query_radius_into) | `func query_radius_into(center: Vector3, radius: float, out_entities: Array, clear_output: bool = true) -> Array:` |
| 方法 | [`query_records_aabb`](#member-gfspatialqueryindex3d-methods-query_records_aabb) | `func query_records_aabb(area: AABB) -> Array[Dictionary]:` |
| 方法 | [`query_records_aabb_into`](#member-gfspatialqueryindex3d-methods-query_records_aabb_into) | `func query_records_aabb_into( area: AABB, out_records: Array[Dictionary], clear_output: bool = true ) -> Array[Dictionary]:` |
| 方法 | [`query_records_radius`](#member-gfspatialqueryindex3d-methods-query_records_radius) | `func query_records_radius(center: Vector3, radius: float) -> Array[Dictionary]:` |
| 方法 | [`query_records_radius_into`](#member-gfspatialqueryindex3d-methods-query_records_radius_into) | `func query_records_radius_into( center: Vector3, radius: float, out_records: Array[Dictionary], clear_output: bool = true ) -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfspatialqueryindex3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfspatialqueryindex3d-constants-strategy_auto"></a>

### `STRATEGY_AUTO`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STRATEGY_AUTO: StringName = &"auto"
```

根据实体数量自动选择策略。

<a id="member-gfspatialqueryindex3d-constants-strategy_linear"></a>

### `STRATEGY_LINEAR`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STRATEGY_LINEAR: StringName = &"linear"
```

使用线性扫描。

<a id="member-gfspatialqueryindex3d-constants-strategy_spatial_hash"></a>

### `STRATEGY_SPATIAL_HASH`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STRATEGY_SPATIAL_HASH: StringName = &"spatial_hash"
```

使用 GFSpatialHash3D。

## 属性

<a id="member-gfspatialqueryindex3d-properties-strategy"></a>

### `strategy`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var strategy: StringName = STRATEGY_AUTO:
```

当前策略。

<a id="member-gfspatialqueryindex3d-properties-cell_size"></a>

### `cell_size`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var cell_size: float = 4.0:
```

空间哈希格子尺寸。

<a id="member-gfspatialqueryindex3d-properties-auto_spatial_hash_threshold"></a>

### `auto_spatial_hash_threshold`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var auto_spatial_hash_threshold: int = 64:
```

auto 策略切换到空间哈希的实体数量阈值。

## 方法

<a id="member-gfspatialqueryindex3d-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure(p_strategy: StringName = STRATEGY_AUTO, options: Dictionary = {}) -> GFSpatialQueryIndex3D:
```

配置索引。

参数：

| 名称 | 说明 |
|---|---|
| `p_strategy` | 查询策略。 |
| `options` | 配置选项，支持 cell_size 和 auto_spatial_hash_threshold。 |

返回：当前索引。

结构：

- `options`: Dictionary，可包含 cell_size: float 和 auto_spatial_hash_threshold: int。

<a id="member-gfspatialqueryindex3d-methods-upsert"></a>

### `upsert`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func upsert(entity: Variant, entity_bounds: AABB, p_metadata: Dictionary = {}) -> bool:
```

插入或更新实体 AABB。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |
| `entity_bounds` | 实体包围盒。 |
| `p_metadata` | 调用方元数据。 |

返回：成功时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.
- `p_metadata`: Dictionary copied into entity record metadata.

<a id="member-gfspatialqueryindex3d-methods-remove"></a>

### `remove`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove(entity: Variant) -> bool:
```

移除实体。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |

返回：找到并移除时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.

<a id="member-gfspatialqueryindex3d-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空索引。

<a id="member-gfspatialqueryindex3d-methods-has_entity"></a>

### `has_entity`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_entity(entity: Variant) -> bool:
```

检查实体是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |

返回：存在时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.

<a id="member-gfspatialqueryindex3d-methods-get_entity_count"></a>

### `get_entity_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_entity_count() -> int:
```

获取实体数量。

返回：实体数量。

<a id="member-gfspatialqueryindex3d-methods-prune_invalid_entities"></a>

### `prune_invalid_entities`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func prune_invalid_entities() -> void:
```

清理已释放 Object 实体。

<a id="member-gfspatialqueryindex3d-methods-get_entity_record"></a>

### `get_entity_record`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_entity_record(entity: Variant) -> Dictionary:
```

获取实体记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |

返回：实体记录；不存在时为空字典。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.
- `return`: Dictionary，包含 entity、bounds 和 metadata。

<a id="member-gfspatialqueryindex3d-methods-query_aabb"></a>

### `query_aabb`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_aabb(area: AABB) -> Array[Variant]:
```

查询与 AABB 相交的实体。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询 AABB。 |

返回：匹配实体数组。

结构：

- `return`: Array[Variant]，实体值来自调用方传入的 entity。

<a id="member-gfspatialqueryindex3d-methods-query_aabb_into"></a>

### `query_aabb_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_aabb_into(area: AABB, out_entities: Array, clear_output: bool = true) -> Array:
```

查询与 AABB 相交的实体，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询 AABB。 |
| `out_entities` | 接收匹配实体的数组。 |
| `clear_output` | 为 true 时先清空 out_entities。 |

返回：同一个 out_entities 数组。

结构：

- `return`: Array[Variant]，同一个 out_entities 数组；实体值来自调用方传入的 entity。
- `out_entities`: Array[Variant]，实体值来自调用方传入的 entity。

<a id="member-gfspatialqueryindex3d-methods-query_radius"></a>

### `query_radius`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_radius(center: Vector3, radius: float) -> Array[Variant]:
```

查询与球体相交的实体。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 球心。 |
| `radius` | 半径。 |

返回：匹配实体数组。

结构：

- `return`: Array[Variant]，实体值来自调用方传入的 entity。

<a id="member-gfspatialqueryindex3d-methods-query_radius_into"></a>

### `query_radius_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_radius_into(center: Vector3, radius: float, out_entities: Array, clear_output: bool = true) -> Array:
```

查询与球体相交的实体，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 球心。 |
| `radius` | 半径。 |
| `out_entities` | 接收匹配实体的数组。 |
| `clear_output` | 为 true 时先清空 out_entities。 |

返回：同一个 out_entities 数组。

结构：

- `return`: Array[Variant]，同一个 out_entities 数组；实体值来自调用方传入的 entity。
- `out_entities`: Array[Variant]，实体值来自调用方传入的 entity。

<a id="member-gfspatialqueryindex3d-methods-query_records_aabb"></a>

### `query_records_aabb`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_aabb(area: AABB) -> Array[Dictionary]:
```

查询与 AABB 相交的实体记录。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询 AABB。 |

返回：匹配实体记录数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。

<a id="member-gfspatialqueryindex3d-methods-query_records_aabb_into"></a>

### `query_records_aabb_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_aabb_into( area: AABB, out_records: Array[Dictionary], clear_output: bool = true ) -> Array[Dictionary]:
```

查询与 AABB 相交的实体记录，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询 AABB。 |
| `out_records` | 接收匹配实体记录的数组。 |
| `clear_output` | 为 true 时先清空 out_records。 |

返回：同一个 out_records 数组。

结构：

- `return`: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity、bounds 和 metadata。
- `out_records`: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。

<a id="member-gfspatialqueryindex3d-methods-query_records_radius"></a>

### `query_records_radius`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_radius(center: Vector3, radius: float) -> Array[Dictionary]:
```

查询与球体相交的实体记录。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 球心。 |
| `radius` | 半径。 |

返回：匹配实体记录数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。

<a id="member-gfspatialqueryindex3d-methods-query_records_radius_into"></a>

### `query_records_radius_into`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func query_records_radius_into( center: Vector3, radius: float, out_records: Array[Dictionary], clear_output: bool = true ) -> Array[Dictionary]:
```

查询与球体相交的实体记录，并写入调用方提供的数组。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 球心。 |
| `radius` | 半径。 |
| `out_records` | 接收匹配实体记录的数组。 |
| `clear_output` | 为 true 时先清空 out_records。 |

返回：同一个 out_records 数组。

结构：

- `return`: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity、bounds 和 metadata。
- `out_records`: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。

<a id="member-gfspatialqueryindex3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 strategy、active_strategy、cell_size、entity_count 和 index_dirty。
