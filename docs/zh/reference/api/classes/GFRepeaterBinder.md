# GFRepeaterBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_repeater_binder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

响应式模板重复渲染绑定器。 将数组数据渲染为容器中的模板副本，也可以订阅 `GFReactiveStateStore` 的路径并在数组变化时同步。显式提供 identity_callable 后，同 ID、同模板实例和 duplicate_flags 的节点会复用，普通 Container 继续负责布局。未提供 ID 时重建副本。 具体行结构和交互由项目决定；项目回调主动改写的字段不属于局部状态保留承诺。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`synchronization_failed`](#member-gfrepeaterbinder-signals-synchronization_failed) | `signal synchronization_failed(container: Node, group_key: StringName, error: StringName)` |
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
| 方法 | [`sync_container`](#member-gfrepeaterbinder-methods-sync_container) | `static func sync_container( container: Node, template: Node, items: Array, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`clear_clones`](#member-gfrepeaterbinder-methods-clear_clones) | `static func clear_clones(container: Node, options: Dictionary = {}) -> int:` |

## 信号

<a id="member-gfrepeaterbinder-signals-synchronization_failed"></a>

### `synchronization_failed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal synchronization_failed(container: Node, group_key: StringName, error: StringName)
```

活跃绑定的自动 store 刷新失败时发出；失败边界同 sync_container()。 初次 bind_repeater() 的失败通过返回值报告。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 仍有效的目标容器。 |
| `group_key` | 失败的克隆组。 |
| `error` | sync_container() 的失败标识。 |

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
| `options` | sync_container() 的选项，另支持 sync_initial 和 default_items。 |

返回：成功绑定时返回 true。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。
- `options`: Dictionary，支持 group_key、text_key、clear_existing、hide_template、duplicate_flags、configure_callable、identity_callable、sync_initial: bool 和 default_items: Array；同步边界同 sync_container()。

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

返回：本次顺序的节点数组，包含复用节点；失败返回空数组。详细结果使用 sync_container()。

结构：

- `items`: Array，重复渲染的数据条目。
- `options`: Dictionary，字段及稳定 ID 同 sync_container()。

<a id="member-gfrepeaterbinder-methods-unbind_container"></a>

### `unbind_container`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unbind_container(container: Node, options: Dictionary = {}) -> bool:
```

解绑指定容器，并中断本实例绑定驱动的同步；已经显示的节点保留。

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

清理本实例所有绑定并中断它们驱动的同步；已显示节点仍由容器持有。

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

同步容器中的模板副本；它是 sync_container() 的节点数组便捷入口。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 承载重复节点的容器。 |
| `template` | 要复制的模板节点。 |
| `items` | 条目数组。 |
| `options` | 可选项，字段及稳定 ID 合同同 sync_container()。 |

返回：本次顺序的节点数组，包含复用节点；失败返回空数组。

结构：

- `items`: Array，重复渲染的数据条目。
- `options`: Dictionary，字段同 sync_container()。

<a id="member-gfrepeaterbinder-methods-sync_container"></a>

### `sync_container`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func sync_container( container: Node, template: Node, items: Array, options: Dictionary = {} ) -> Dictionary:
```

同步容器中的模板副本，并报告节点身份的变化。 每次最多 4096 项；稳定 key token 最多 4096 UTF-8 字节。ID 回调在结构修改前 全量执行并校验；String 与 StringName 按 codec 分别作为不同身份。未提供 ID 时 保留重建语义；提供 ID 时 clear_existing 必须为 true。只管理当前克隆组。 新增、移动或数据变化的条目才配置。有限纯值 Array/Dictionary 保存独立比较快照； 包含 Object/Callable/Signal/RID、循环或超出比较预算的条目保留项目引用并每次配置， 不深复制此类数据，也不推断对象内部变化。复制已同步容器会隔离组状态，首次同步重建复制行。 同组嵌套同步返回 busy；clear_clones、解绑和离树中断后续工作。项目回调副作用 不会回滚。不要在回调中释放/移走正在配置的节点；此类中断返回空 nodes。

参数：

| 名称 | 说明 |
|---|---|
| `container` | 承载当前克隆组的容器。 |
| `template` | 克隆模板；同一模板实例与 duplicate_flags 才能复用节点。 |
| `items` | 本次完整条目数组。 |
| `options` | 模板选项；identity_callable 可显式提供稳定 ID。 |

返回：同步报告。

结构：

- `items`: Array，项目提供的数据条目。
- `options`: Dictionary，包含 group_key: String/StringName、text_key: String/StringName、hide_template: bool、duplicate_flags: int (0..15)、configure_callable: Callable(Node, Variant, int) -> void、clear_existing: bool 和 identity_callable: Callable(Variant, int) -> stable Variant key；允许 bind_repeater 使用的 sync_initial/default_items，拒绝未知键。
- `return`: Dictionary，包含 ok: bool、error: StringName、nodes: Array[Node]、created_count: int、reused_count: int、removed_count: int；error 为空或 invalid_target、invalid_options、item_limit、invalid_identity、duplicate_identity、busy、interrupted、duplicate_failed。失败的 nodes 为空，计数只在成功时提供。

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
