# GFNodeGroupCache

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_node_group_cache.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

SceneTree group 查询缓存。 适合相机、交互、物理探针、运行时注册表或编辑器预览等需要频繁读取 同一 group 节点快照的场景。它只缓存 Godot group 查询结果，不规定节点业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cache_invalidated`](#member-gfnodegroupcache-signals-cache_invalidated) | `signal cache_invalidated(reason: StringName)` |
| 属性 | [`tree`](#member-gfnodegroupcache-properties-tree) | `var tree: SceneTree:` |
| 属性 | [`group_name`](#member-gfnodegroupcache-properties-group_name) | `var group_name: StringName:` |
| 属性 | [`type_filter`](#member-gfnodegroupcache-properties-type_filter) | `var type_filter: Variant:` |
| 方法 | [`from_tree`](#member-gfnodegroupcache-methods-from_tree) | `static func from_tree( p_tree: SceneTree, p_group_name: StringName, p_type_filter: Variant = null ) -> GFNodeGroupCache:` |
| 方法 | [`configure`](#member-gfnodegroupcache-methods-configure) | `func configure( p_tree: SceneTree, p_group_name: StringName, p_type_filter: Variant = null ) -> GFNodeGroupCache:` |
| 方法 | [`invalidate`](#member-gfnodegroupcache-methods-invalidate) | `func invalidate(reason: StringName = &"manual") -> void:` |
| 方法 | [`refresh`](#member-gfnodegroupcache-methods-refresh) | `func refresh() -> Array[Node]:` |
| 方法 | [`get_nodes`](#member-gfnodegroupcache-methods-get_nodes) | `func get_nodes() -> Array[Node]:` |
| 方法 | [`get_first`](#member-gfnodegroupcache-methods-get_first) | `func get_first() -> Node:` |
| 方法 | [`has_node`](#member-gfnodegroupcache-methods-has_node) | `func has_node(node: Node) -> bool:` |
| 方法 | [`size`](#member-gfnodegroupcache-methods-size) | `func size() -> int:` |
| 方法 | [`is_dirty`](#member-gfnodegroupcache-methods-is_dirty) | `func is_dirty() -> bool:` |
| 方法 | [`dispose`](#member-gfnodegroupcache-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnodegroupcache-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnodegroupcache-signals-cache_invalidated"></a>

### `cache_invalidated`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal cache_invalidated(reason: StringName)
```

缓存被标记为脏时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失效原因。 |

## 属性

<a id="member-gfnodegroupcache-properties-tree"></a>

### `tree`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var tree: SceneTree:
```

查询的 SceneTree。

<a id="member-gfnodegroupcache-properties-group_name"></a>

### `group_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var group_name: StringName:
```

查询的 group 名。

<a id="member-gfnodegroupcache-properties-type_filter"></a>

### `type_filter`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var type_filter: Variant:
```

可选类型过滤器，可为脚本类型、原生类或类名字符串。

结构：

- `type_filter`: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null.

## 方法

<a id="member-gfnodegroupcache-methods-from_tree"></a>

### `from_tree`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_tree( p_tree: SceneTree, p_group_name: StringName, p_type_filter: Variant = null ) -> GFNodeGroupCache:
```

创建并配置 group 缓存。

参数：

| 名称 | 说明 |
|---|---|
| `p_tree` | 查询的 SceneTree。 |
| `p_group_name` | 查询的 group 名。 |
| `p_type_filter` | 可选类型过滤器。 |

返回：新 group 缓存。

结构：

- `p_type_filter`: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null.

<a id="member-gfnodegroupcache-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_tree: SceneTree, p_group_name: StringName, p_type_filter: Variant = null ) -> GFNodeGroupCache:
```

重新配置缓存。

参数：

| 名称 | 说明 |
|---|---|
| `p_tree` | 查询的 SceneTree。 |
| `p_group_name` | 查询的 group 名。 |
| `p_type_filter` | 可选类型过滤器。 |

返回：当前缓存。

结构：

- `p_type_filter`: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null.

<a id="member-gfnodegroupcache-methods-invalidate"></a>

### `invalidate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func invalidate(reason: StringName = &"manual") -> void:
```

手动标记缓存失效。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失效原因。 |

<a id="member-gfnodegroupcache-methods-refresh"></a>

### `refresh`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func refresh() -> Array[Node]:
```

立即重建缓存并返回节点快照。

返回：当前 group 节点快照。

<a id="member-gfnodegroupcache-methods-get_nodes"></a>

### `get_nodes`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_nodes() -> Array[Node]:
```

获取 group 节点快照。

返回：当前 group 节点快照。

<a id="member-gfnodegroupcache-methods-get_first"></a>

### `get_first`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_first() -> Node:
```

获取第一项 group 节点。

返回：第一个匹配节点；没有匹配时返回 null。

<a id="member-gfnodegroupcache-methods-has_node"></a>

### `has_node`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_node(node: Node) -> bool:
```

检查节点是否在当前缓存快照中。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |

返回：在缓存快照中返回 true。

<a id="member-gfnodegroupcache-methods-size"></a>

### `size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func size() -> int:
```

获取当前匹配节点数量。

返回：匹配节点数量。

<a id="member-gfnodegroupcache-methods-is_dirty"></a>

### `is_dirty`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_dirty() -> bool:
```

检查缓存是否已失效。

返回：缓存需要重建时返回 true。

<a id="member-gfnodegroupcache-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

断开 SceneTree 信号并清空缓存。

<a id="member-gfnodegroupcache-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取缓存诊断快照。

返回：诊断快照。

结构：

- `return`: Dictionary，包含 group_name、dirty、node_count、has_tree、type_filter 和 diagnostics。
