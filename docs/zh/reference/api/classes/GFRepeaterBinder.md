# GFRepeaterBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_repeater_binder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

响应式模板重复渲染绑定器。 将数组数据渲染为容器中的模板副本，也可以订阅 `GFReactiveStateStore` 的路径并在数组变化时重建。它只负责模板复制、生命周期清理和通用文本写入， 具体行控件结构和业务交互由项目节点或 configure_callable 决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`META_CLONE`](#member-gfrepeaterbinder-constants-meta_clone) | `const META_CLONE: StringName = &"gf_repeater_clone"` |
| 常量 | [`META_GROUP_KEY`](#member-gfrepeaterbinder-constants-meta_group_key) | `const META_GROUP_KEY: StringName = &"gf_repeater_group_key"` |
| 常量 | [`META_INDEX`](#member-gfrepeaterbinder-constants-meta_index) | `const META_INDEX: StringName = &"gf_repeater_index"` |
| 常量 | [`META_ITEM`](#member-gfrepeaterbinder-constants-meta_item) | `const META_ITEM: StringName = &"gf_repeater_item"` |
| 方法 | [`bind_repeater`](#member-gfrepeaterbinder-methods-bind_repeater) | `func bind_repeater( store: RefCounted, path: Variant, container: Node, template: Node, options: Dictionary = {} ) -> bool:` |
| 方法 | [`rebuild_target`](#member-gfrepeaterbinder-methods-rebuild_target) | `func rebuild_target(container: Node, template: Node, items: Array, options: Dictionary = {}) -> Array[Node]:` |
| 方法 | [`unbind_container`](#member-gfrepeaterbinder-methods-unbind_container) | `func unbind_container(container: Node, options: Dictionary = {}) -> bool:` |
| 方法 | [`unbind_path`](#member-gfrepeaterbinder-methods-unbind_path) | `func unbind_path(store: RefCounted, path: Variant) -> int:` |
| 方法 | [`clear`](#member-gfrepeaterbinder-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_binding_count`](#member-gfrepeaterbinder-methods-get_binding_count) | `func get_binding_count() -> int:` |
| 方法 | [`dispose`](#member-gfrepeaterbinder-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`rebuild_container`](#member-gfrepeaterbinder-methods-rebuild_container) | `static func rebuild_container( container: Node, template: Node, items: Array, options: Dictionary = {} ) -> Array[Node]:` |
| 方法 | [`clear_clones`](#member-gfrepeaterbinder-methods-clear_clones) | `static func clear_clones(container: Node, options: Dictionary = {}) -> int:` |

## 常量

<a id="member-gfrepeaterbinder-constants-meta_clone"></a>

### `META_CLONE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const META_CLONE: StringName = &"gf_repeater_clone"
```

重复节点标记 meta key。

<a id="member-gfrepeaterbinder-constants-meta_group_key"></a>

### `META_GROUP_KEY`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const META_GROUP_KEY: StringName = &"gf_repeater_group_key"
```

重复节点分组 meta key。

<a id="member-gfrepeaterbinder-constants-meta_index"></a>

### `META_INDEX`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const META_INDEX: StringName = &"gf_repeater_index"
```

重复节点索引 meta key。

<a id="member-gfrepeaterbinder-constants-meta_item"></a>

### `META_ITEM`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const META_ITEM: StringName = &"gf_repeater_item"
```

重复节点原始条目 meta key。

## 方法

<a id="member-gfrepeaterbinder-methods-bind_repeater"></a>

### `bind_repeater`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func bind_repeater( store: RefCounted, path: Variant, container: Node, template: Node, options: Dictionary = {} ) -> bool:
```

绑定 store 路径到模板重复渲染。

参数：

| 名称 | 说明 |
|---|---|
| `store` | \`GFReactiveStateStore\` 实例。 |
| `path` | 状态路径，路径值应为 Array。 |
| `container` | 承载重复节点的容器。 |
| `template` | 要复制的模板节点。 |
| `options` | 可选项。支持 group_key、text_key、clear_existing、hide_template、duplicate_flags、configure_callable、sync_initial 和 default_items。 |

返回：成功绑定时返回 true。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。
- `options`: Dictionary，模板复制和字段映射选项。

<a id="member-gfrepeaterbinder-methods-rebuild_target"></a>

### `rebuild_target`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func rebuild_target(container: Node, template: Node, items: Array, options: Dictionary = {}) -> Array[Node]:
```

直接重建容器中的模板副本。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 承载重复节点的容器。 |
| `template` | 要复制的模板节点。 |
| `items` | 条目数组。 |
| `options` | 可选项，字段同 bind_repeater()。 |

返回：新建的节点数组。

结构：

- `items`: Array，重复渲染的数据条目。
- `options`: Dictionary，模板复制和字段映射选项。

<a id="member-gfrepeaterbinder-methods-unbind_container"></a>

### `unbind_container`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unbind_container(container: Node, options: Dictionary = {}) -> bool:
```

解绑指定容器。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 目标容器。 |
| `options` | 可选项，支持 group_key。 |

返回：找到并解绑时返回 true。

结构：

- `options`: Dictionary，包含可选 group_key。

<a id="member-gfrepeaterbinder-methods-unbind_path"></a>

### `unbind_path`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unbind_path(store: RefCounted, path: Variant) -> int:
```

解绑指定 store 路径上的所有重复渲染。

参数：

| 名称 | 说明 |
|---|---|
| `store` | \`GFReactiveStateStore\` 实例。 |
| `path` | 状态路径。 |

返回：解绑数量。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。

<a id="member-gfrepeaterbinder-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清理所有绑定。

<a id="member-gfrepeaterbinder-methods-get_binding_count"></a>

### `get_binding_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_binding_count() -> int:
```

获取当前有效绑定数量。

返回：有效绑定数量。

<a id="member-gfrepeaterbinder-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

释放所有绑定。

<a id="member-gfrepeaterbinder-methods-rebuild_container"></a>

### `rebuild_container`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func rebuild_container( container: Node, template: Node, items: Array, options: Dictionary = {} ) -> Array[Node]:
```

重建容器中的模板副本。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 承载重复节点的容器。 |
| `template` | 要复制的模板节点。 |
| `items` | 条目数组。 |
| `options` | 可选项。支持 group_key、text_key、clear_existing、hide_template、duplicate_flags 和 configure_callable。 |

返回：新建的节点数组。

结构：

- `items`: Array，重复渲染的数据条目。
- `options`: Dictionary，模板复制和字段映射选项。

<a id="member-gfrepeaterbinder-methods-clear_clones"></a>

### `clear_clones`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func clear_clones(container: Node, options: Dictionary = {}) -> int:
```

清理容器中由 GFRepeaterBinder 创建的副本。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 目标容器。 |
| `options` | 可选项，支持 group_key。 |

返回：清理的节点数量。

结构：

- `options`: Dictionary，包含可选 group_key。
