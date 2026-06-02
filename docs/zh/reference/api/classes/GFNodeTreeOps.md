# GFNodeTreeOps

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_node_tree_ops.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用节点树操作集合。 提供安全添加、重挂、替换、遍历、类型查找和 owner 传播等节点树基础操作。 该工具只处理 Godot Node 结构，不绑定具体玩法、UI 或场景业务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`add_child_with_owner`](#member-gfnodetreeops-methods-add_child_with_owner) | `static func add_child_with_owner( parent: Node, child: Node, owner: Node = null, force_readable_name: bool = false ) -> bool:` |
| 方法 | [`reparent_node`](#member-gfnodetreeops-methods-reparent_node) | `static func reparent_node( node: Node, new_parent: Node, keep_global_transform: bool = true, owner: Node = null ) -> bool:` |
| 方法 | [`replace_child`](#member-gfnodetreeops-methods-replace_child) | `static func replace_child( parent: Node, old_child: Node, new_child: Node, keep_global_transform: bool = true, free_old_child: bool = false, owner: Node = null ) -> bool:` |
| 方法 | [`find_first_parent_of_type`](#member-gfnodetreeops-methods-find_first_parent_of_type) | `static func find_first_parent_of_type( node: Node, parent_type: Variant, include_self: bool = false ) -> Node:` |
| 方法 | [`find_first_child_of_type`](#member-gfnodetreeops-methods-find_first_child_of_type) | `static func find_first_child_of_type( parent: Node, child_type: Variant, recursive: bool = false, include_internal: bool = false, include_parent: bool = false ) -> Node:` |
| 方法 | [`collect_node_tree`](#member-gfnodetreeops-methods-collect_node_tree) | `static func collect_node_tree( root: Node, type_filter: Variant = null, include_root: bool = true, include_internal: bool = false ) -> Array[Node]:` |
| 方法 | [`set_owner_recursive`](#member-gfnodetreeops-methods-set_owner_recursive) | `static func set_owner_recursive(node: Node, owner: Node) -> void:` |
| 方法 | [`free_children`](#member-gfnodetreeops-methods-free_children) | `static func free_children(parent: Node, include_internal: bool = false) -> int:` |

## 方法

<a id="member-gfnodetreeops-methods-add_child_with_owner"></a>

### `add_child_with_owner`

- API：`public`

```gdscript
static func add_child_with_owner( parent: Node, child: Node, owner: Node = null, force_readable_name: bool = false ) -> bool:
```

把子节点添加到父节点，并按场景编辑规则设置 owner。

参数：

| 名称 | 说明 |
|---|---|
| `parent` | 目标父节点。 |
| `child` | 要添加的子节点。 |
| `owner` | 可选 owner；为空时使用 parent.owner，若没有则使用 parent。 |
| `force_readable_name` | 是否要求 Godot 生成可读名称。 |

返回：添加成功返回 true。

<a id="member-gfnodetreeops-methods-reparent_node"></a>

### `reparent_node`

- API：`public`

```gdscript
static func reparent_node( node: Node, new_parent: Node, keep_global_transform: bool = true, owner: Node = null ) -> bool:
```

把节点移动到新父节点下。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 要移动的节点。 |
| `new_parent` | 新父节点。 |
| `keep_global_transform` | 为 true 时尽量保留 Node2D、Node3D 或 Control 的全局变换。 |
| `owner` | 可选 owner；为空时使用 new_parent.owner，若没有则使用 new_parent。 |

返回：移动成功返回 true。

<a id="member-gfnodetreeops-methods-replace_child"></a>

### `replace_child`

- API：`public`

```gdscript
static func replace_child( parent: Node, old_child: Node, new_child: Node, keep_global_transform: bool = true, free_old_child: bool = false, owner: Node = null ) -> bool:
```

用新子节点替换父节点下的旧子节点。

参数：

| 名称 | 说明 |
|---|---|
| `parent` | 目标父节点。 |
| `old_child` | 要被替换的旧子节点。 |
| `new_child` | 新子节点。 |
| `keep_global_transform` | 为 true 时重挂新节点时尽量保留全局变换。 |
| `free_old_child` | 为 true 时替换后 queue_free() 旧节点。 |
| `owner` | 可选 owner；为空时使用 parent.owner，若没有则使用 parent。 |

返回：替换成功返回 true。

<a id="member-gfnodetreeops-methods-find_first_parent_of_type"></a>

### `find_first_parent_of_type`

- API：`public`

```gdscript
static func find_first_parent_of_type( node: Node, parent_type: Variant, include_self: bool = false ) -> Node:
```

向上查找第一个匹配类型的父级节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 查询起点。 |
| `parent_type` | 目标类型，可为脚本类型、原生类或类名字符串。 |
| `include_self` | 是否包含查询起点。 |

返回：匹配节点；未找到时返回 null。

结构：

- `parent_type`: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, or script resource path.

<a id="member-gfnodetreeops-methods-find_first_child_of_type"></a>

### `find_first_child_of_type`

- API：`public`

```gdscript
static func find_first_child_of_type( parent: Node, child_type: Variant, recursive: bool = false, include_internal: bool = false, include_parent: bool = false ) -> Node:
```

向下查找第一个匹配类型的子节点。

参数：

| 名称 | 说明 |
|---|---|
| `parent` | 查询根节点。 |
| `child_type` | 目标类型，可为脚本类型、原生类或类名字符串。 |
| `recursive` | 是否递归查找。 |
| `include_internal` | 是否包含内部子节点。 |
| `include_parent` | 是否允许 parent 自身命中。 |

返回：匹配节点；未找到时返回 null。

结构：

- `child_type`: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, or script resource path.

<a id="member-gfnodetreeops-methods-collect_node_tree"></a>

### `collect_node_tree`

- API：`public`

```gdscript
static func collect_node_tree( root: Node, type_filter: Variant = null, include_root: bool = true, include_internal: bool = false ) -> Array[Node]:
```

收集节点树中的节点。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 节点树根节点。 |
| `type_filter` | 可选类型过滤器，可为脚本类型、原生类或类名字符串。 |
| `include_root` | 是否包含 root 自身。 |
| `include_internal` | 是否包含内部子节点。 |

返回：匹配节点列表。

结构：

- `type_filter`: Variant type filter accepted by is_instance_of(), native class name, GDScript class_name, script resource path, or null for all nodes.

<a id="member-gfnodetreeops-methods-set_owner_recursive"></a>

### `set_owner_recursive`

- API：`public`

```gdscript
static func set_owner_recursive(node: Node, owner: Node) -> void:
```

递归设置节点树 owner。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 节点树根节点。 |
| `owner` | 目标 owner；必须是节点树中被设置节点的祖先。 |

<a id="member-gfnodetreeops-methods-free_children"></a>

### `free_children`

- API：`public`

```gdscript
static func free_children(parent: Node, include_internal: bool = false) -> int:
```

从父节点移除并 queue_free() 父节点下的全部子节点。

参数：

| 名称 | 说明 |
|---|---|
| `parent` | 目标父节点。 |
| `include_internal` | 是否包含内部子节点。 |

返回：进入释放队列的子节点数量。
