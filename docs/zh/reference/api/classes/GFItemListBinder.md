# GFItemListBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_item_list_binder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

响应式条目控件绑定器。 将数组数据写入 `ItemList`、`OptionButton` 或 `PopupMenu`，也可以订阅 `GFReactiveStateStore` 的路径并在数组变化时刷新目标控件。它只负责条目展示、 metadata 和选择状态同步，不定义业务字段含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`bind_items`](#member-gfitemlistbinder-methods-bind_items) | `func bind_items( store: RefCounted, path: Variant, target: Object, options: Dictionary = {} ) -> bool:` |
| 方法 | [`write_target_items`](#member-gfitemlistbinder-methods-write_target_items) | `func write_target_items(target: Object, items: Array, options: Dictionary = {}) -> int:` |
| 方法 | [`unbind_target`](#member-gfitemlistbinder-methods-unbind_target) | `func unbind_target(target: Object) -> bool:` |
| 方法 | [`unbind_path`](#member-gfitemlistbinder-methods-unbind_path) | `func unbind_path(store: RefCounted, path: Variant) -> int:` |
| 方法 | [`clear`](#member-gfitemlistbinder-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_binding_count`](#member-gfitemlistbinder-methods-get_binding_count) | `func get_binding_count() -> int:` |
| 方法 | [`dispose`](#member-gfitemlistbinder-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`write_items`](#member-gfitemlistbinder-methods-write_items) | `static func write_items(target: Object, items: Array, options: Dictionary = {}) -> int:` |
| 方法 | [`get_item_metadata`](#member-gfitemlistbinder-methods-get_item_metadata) | `static func get_item_metadata(target: Object, index: int, fallback: Variant = null) -> Variant:` |
| 方法 | [`get_selected_metadata`](#member-gfitemlistbinder-methods-get_selected_metadata) | `static func get_selected_metadata(target: Object) -> Array:` |

## 方法

<a id="member-gfitemlistbinder-methods-bind_items"></a>

### `bind_items`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func bind_items( store: RefCounted, path: Variant, target: Object, options: Dictionary = {} ) -> bool:
```

绑定 store 路径到条目控件。

参数：

| 名称 | 说明 |
|---|---|
| `store` | \`GFReactiveStateStore\` 实例。 |
| `path` | 状态路径，路径值应为 Array。 |
| `target` | \`ItemList\`、\`OptionButton\` 或 \`PopupMenu\`。 |
| `options` | 可选映射项。支持 text_key、id_key、metadata_key、icon_key、disabled_key、selectable_key、tooltip_key、selected_key、clear、sync_initial 和 default_items。 |

返回：成功绑定时返回 true。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。
- `options`: Dictionary，键名映射与初始同步选项。

<a id="member-gfitemlistbinder-methods-write_target_items"></a>

### `write_target_items`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_target_items(target: Object, items: Array, options: Dictionary = {}) -> int:
```

直接写入目标控件条目。

参数：

| 名称 | 说明 |
|---|---|
| `target` | \`ItemList\`、\`OptionButton\` 或 \`PopupMenu\`。 |
| `items` | 条目数组。元素可为 Dictionary 或标量值。 |
| `options` | 可选映射项，字段同 bind_items()。 |

返回：实际写入条目数。

结构：

- `items`: Array，元素为 Dictionary 或标量值。
- `options`: Dictionary，键名映射与 clear 选项。

<a id="member-gfitemlistbinder-methods-unbind_target"></a>

### `unbind_target`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unbind_target(target: Object) -> bool:
```

解绑指定目标控件。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标控件。 |

返回：找到并解绑时返回 true。

<a id="member-gfitemlistbinder-methods-unbind_path"></a>

### `unbind_path`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unbind_path(store: RefCounted, path: Variant) -> int:
```

解绑指定 store 路径上的所有目标控件。

参数：

| 名称 | 说明 |
|---|---|
| `store` | \`GFReactiveStateStore\` 实例。 |
| `path` | 状态路径。 |

返回：解绑数量。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。

<a id="member-gfitemlistbinder-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清理所有绑定。

<a id="member-gfitemlistbinder-methods-get_binding_count"></a>

### `get_binding_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_binding_count() -> int:
```

获取当前有效绑定数量。

返回：有效绑定数量。

<a id="member-gfitemlistbinder-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

释放所有绑定。

<a id="member-gfitemlistbinder-methods-write_items"></a>

### `write_items`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func write_items(target: Object, items: Array, options: Dictionary = {}) -> int:
```

将数组数据写入条目控件。

参数：

| 名称 | 说明 |
|---|---|
| `target` | \`ItemList\`、\`OptionButton\` 或 \`PopupMenu\`。 |
| `items` | 条目数组。元素可为 Dictionary 或标量值。 |
| `options` | 可选映射项。支持 text_key、id_key、metadata_key、icon_key、disabled_key、selectable_key、tooltip_key、selected_key 和 clear。 |

返回：实际写入条目数。

结构：

- `items`: Array，元素为 Dictionary 或标量值。
- `options`: Dictionary，键名映射与 clear 选项。

<a id="member-gfitemlistbinder-methods-get_item_metadata"></a>

### `get_item_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func get_item_metadata(target: Object, index: int, fallback: Variant = null) -> Variant:
```

读取控件指定索引的 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `target` | \`ItemList\`、\`OptionButton\` 或 \`PopupMenu\`。 |
| `index` | 条目索引。 |
| `fallback` | 索引无效时返回的值。 |

返回：条目 metadata 或 fallback。

结构：

- `fallback`: Variant fallback value.
- `return`: Variant item metadata or fallback.

<a id="member-gfitemlistbinder-methods-get_selected_metadata"></a>

### `get_selected_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func get_selected_metadata(target: Object) -> Array:
```

读取当前选中条目的 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `target` | \`ItemList\` 或 \`OptionButton\`。 |

返回：选中 metadata 数组。

结构：

- `return`: Array，ItemList 返回所有选中条目 metadata，OptionButton 返回单个 metadata。
