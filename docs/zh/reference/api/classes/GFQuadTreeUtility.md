# GFQuadTreeUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial/gf_quad_tree_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

纯逻辑 2D 四叉树空间划分工具。 继承自 GFUtility，提供不依赖引擎物理节点的 2D 空间划分和范围查询能力。 适用于模拟经营、RTS 等需要对海量实体进行高效范围检索的场景。 用法： 1. 调用 setup(bounds, max_depth, max_entities) 初始化树的参数。 2. 调用 insert(entity_id, rect) 将实体插入四叉树。 3. 调用 query_rect(rect)、query_radius(center, radius) 或 query_point(point) 查询。 4. 调用 update(entity_id, rect) 更新实体位置（内部先移除再插入）。 5. 调用 remove(entity_id) 移除实体。 注意：entity_id 为 int，由调用方自行管理 ID 映射。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_DEPTH`](#member-gfquadtreeutility-constants-default_max_depth) | `const DEFAULT_MAX_DEPTH: int = 8` |
| 常量 | [`DEFAULT_MAX_ENTITIES`](#member-gfquadtreeutility-constants-default_max_entities) | `const DEFAULT_MAX_ENTITIES: int = 8` |
| 属性 | [`bounds`](#member-gfquadtreeutility-properties-bounds) | `var bounds: Rect2 = Rect2()` |
| 属性 | [`max_depth`](#member-gfquadtreeutility-properties-max_depth) | `var max_depth: int = DEFAULT_MAX_DEPTH` |
| 属性 | [`max_entities_per_node`](#member-gfquadtreeutility-properties-max_entities_per_node) | `var max_entities_per_node: int = DEFAULT_MAX_ENTITIES` |
| 方法 | [`init`](#member-gfquadtreeutility-methods-init) | `func init() -> void:` |
| 方法 | [`setup`](#member-gfquadtreeutility-methods-setup) | `func setup(world_bounds: Rect2, depth: int = DEFAULT_MAX_DEPTH, entities_per_node: int = DEFAULT_MAX_ENTITIES) -> void:` |
| 方法 | [`insert`](#member-gfquadtreeutility-methods-insert) | `func insert(entity_id: int, rect: Rect2) -> void:` |
| 方法 | [`insert_with_hit_test`](#member-gfquadtreeutility-methods-insert_with_hit_test) | `func insert_with_hit_test(entity_id: int, rect: Rect2, hit_test: Callable) -> void:` |
| 方法 | [`remove`](#member-gfquadtreeutility-methods-remove) | `func remove(entity_id: int) -> void:` |
| 方法 | [`update`](#member-gfquadtreeutility-methods-update) | `func update(entity_id: int, new_rect: Rect2) -> void:` |
| 方法 | [`set_entity_hit_test`](#member-gfquadtreeutility-methods-set_entity_hit_test) | `func set_entity_hit_test(entity_id: int, hit_test: Callable) -> bool:` |
| 方法 | [`clear_entity_hit_test`](#member-gfquadtreeutility-methods-clear_entity_hit_test) | `func clear_entity_hit_test(entity_id: int) -> bool:` |
| 方法 | [`get_entity_rect`](#member-gfquadtreeutility-methods-get_entity_rect) | `func get_entity_rect(entity_id: int) -> Rect2:` |
| 方法 | [`query_rect`](#member-gfquadtreeutility-methods-query_rect) | `func query_rect(area: Rect2) -> Array[int]:` |
| 方法 | [`query_radius`](#member-gfquadtreeutility-methods-query_radius) | `func query_radius(center: Vector2, radius: float) -> Array[int]:` |
| 方法 | [`query_point`](#member-gfquadtreeutility-methods-query_point) | `func query_point(point: Vector2, use_exact_hit_tests: bool = true) -> Array[int]:` |
| 方法 | [`query_first_point`](#member-gfquadtreeutility-methods-query_first_point) | `func query_first_point(point: Vector2, use_exact_hit_tests: bool = true) -> int:` |
| 方法 | [`compact`](#member-gfquadtreeutility-methods-compact) | `func compact() -> void:` |
| 方法 | [`clear`](#member-gfquadtreeutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_entity_count`](#member-gfquadtreeutility-methods-get_entity_count) | `func get_entity_count() -> int:` |
| 方法 | [`has_entity`](#member-gfquadtreeutility-methods-has_entity) | `func has_entity(entity_id: int) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfquadtreeutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfquadtreeutility-constants-default_max_depth"></a>

### `DEFAULT_MAX_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_DEPTH: int = 8
```

默认最大树深度。

<a id="member-gfquadtreeutility-constants-default_max_entities"></a>

### `DEFAULT_MAX_ENTITIES`

- API：`public`

```gdscript
const DEFAULT_MAX_ENTITIES: int = 8
```

默认每节点最大实体数（超过后分裂）。

## 属性

<a id="member-gfquadtreeutility-properties-bounds"></a>

### `bounds`

- API：`public`

```gdscript
var bounds: Rect2 = Rect2()
```

四叉树覆盖的世界边界。

<a id="member-gfquadtreeutility-properties-max_depth"></a>

### `max_depth`

- API：`public`

```gdscript
var max_depth: int = DEFAULT_MAX_DEPTH
```

最大递归深度。

<a id="member-gfquadtreeutility-properties-max_entities_per_node"></a>

### `max_entities_per_node`

- API：`public`

```gdscript
var max_entities_per_node: int = DEFAULT_MAX_ENTITIES
```

每个节点在分裂前允许的最大实体数。

## 方法

<a id="member-gfquadtreeutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化：创建空根节点。

<a id="member-gfquadtreeutility-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup(world_bounds: Rect2, depth: int = DEFAULT_MAX_DEPTH, entities_per_node: int = DEFAULT_MAX_ENTITIES) -> void:
```

配置四叉树参数并重建。应在 init() 之前或之后调用。

参数：

| 名称 | 说明 |
|---|---|
| `world_bounds` | 世界边界矩形。 |
| `depth` | 最大递归深度。 |
| `entities_per_node` | 每节点最大实体数。 |

<a id="member-gfquadtreeutility-methods-insert"></a>

### `insert`

- API：`public`

```gdscript
func insert(entity_id: int, rect: Rect2) -> void:
```

将实体插入四叉树。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体唯一标识。 |
| `rect` | 实体的轴对齐包围矩形。 |

<a id="member-gfquadtreeutility-methods-insert_with_hit_test"></a>

### `insert_with_hit_test`

- API：`public`

```gdscript
func insert_with_hit_test(entity_id: int, rect: Rect2, hit_test: Callable) -> void:
```

将带精确点命中测试的实体插入四叉树。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体唯一标识。 |
| `rect` | 实体的轴对齐包围矩形。 |
| `hit_test` | 可选精确命中测试，签名为 `(entity_id, point, rect) -> bool`。 |

<a id="member-gfquadtreeutility-methods-remove"></a>

### `remove`

- API：`public`

```gdscript
func remove(entity_id: int) -> void:
```

从四叉树中移除实体。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 要移除的实体标识。 |

<a id="member-gfquadtreeutility-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(entity_id: int, new_rect: Rect2) -> void:
```

更新实体的位置（先移除再插入）。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |
| `new_rect` | 新的包围矩形。 |

<a id="member-gfquadtreeutility-methods-set_entity_hit_test"></a>

### `set_entity_hit_test`

- API：`public`

```gdscript
func set_entity_hit_test(entity_id: int, hit_test: Callable) -> bool:
```

设置实体的精确点命中测试。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |
| `hit_test` | 命中测试 Callable，签名为 `(entity_id, point, rect) -> bool`。 |

返回：设置成功返回 true。

<a id="member-gfquadtreeutility-methods-clear_entity_hit_test"></a>

### `clear_entity_hit_test`

- API：`public`

```gdscript
func clear_entity_hit_test(entity_id: int) -> bool:
```

清除实体的精确点命中测试。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |

返回：清除成功返回 true。

<a id="member-gfquadtreeutility-methods-get_entity_rect"></a>

### `get_entity_rect`

- API：`public`

```gdscript
func get_entity_rect(entity_id: int) -> Rect2:
```

获取实体矩形。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |

返回：实体矩形；不存在时返回空 Rect2。

<a id="member-gfquadtreeutility-methods-query_rect"></a>

### `query_rect`

- API：`public`

```gdscript
func query_rect(area: Rect2) -> Array[int]:
```

矩形范围查询：返回与查询区域有交集的所有实体 ID。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询矩形。 |

返回：匹配的实体 ID 数组。

<a id="member-gfquadtreeutility-methods-query_radius"></a>

### `query_radius`

- API：`public`

```gdscript
func query_radius(center: Vector2, radius: float) -> Array[int]:
```

圆形范围查询：返回包围矩形与圆有交集的所有实体 ID。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 圆心坐标。 |
| `radius` | 查询半径。 |

返回：匹配的实体 ID 数组。

<a id="member-gfquadtreeutility-methods-query_point"></a>

### `query_point`

- API：`public`

```gdscript
func query_point(point: Vector2, use_exact_hit_tests: bool = true) -> Array[int]:
```

点查询：返回包含该点的实体 ID，可选执行精确命中测试。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 查询点。 |
| `use_exact_hit_tests` | 是否执行通过 set_entity_hit_test() 注册的精确命中测试。 |

返回：匹配的实体 ID 数组。

<a id="member-gfquadtreeutility-methods-query_first_point"></a>

### `query_first_point`

- API：`public`

```gdscript
func query_first_point(point: Vector2, use_exact_hit_tests: bool = true) -> int:
```

点查询：返回第一个包含该点的实体 ID，不存在时返回 -1。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 查询点。 |
| `use_exact_hit_tests` | 是否执行精确命中测试。 |

返回：第一个实体 ID；不存在时返回 -1。

<a id="member-gfquadtreeutility-methods-compact"></a>

### `compact`

- API：`public`

```gdscript
func compact() -> void:
```

重建四叉树节点结构，保留实体、矩形和命中测试。

<a id="member-gfquadtreeutility-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空四叉树中的所有实体并重建根节点。

<a id="member-gfquadtreeutility-methods-get_entity_count"></a>

### `get_entity_count`

- API：`public`

```gdscript
func get_entity_count() -> int:
```

获取当前存储的实体总数。

返回：实体数量。

<a id="member-gfquadtreeutility-methods-has_entity"></a>

### `has_entity`

- API：`public`

```gdscript
func has_entity(entity_id: int) -> bool:
```

检查实体是否存在于四叉树中。

参数：

| 名称 | 说明 |
|---|---|
| `entity_id` | 实体标识。 |

返回：是否存在。

<a id="member-gfquadtreeutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：四叉树状态。

结构：

- `return`: Dictionary with `bounds: Rect2`, `entity_count: int`, `hit_test_count: int`, `max_depth: int`, `max_entities_per_node: int`, and `node_count: int`.
