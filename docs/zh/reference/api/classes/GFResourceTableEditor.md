# GFResourceTableEditor

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_resource_table_editor.gd`
- 模块：`Kernel`
- 继承：`VBoxContainer`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

通用 Resource 表格编辑控件。 提供资源扫描、属性列提取、表格刷新与单元格提交，不绑定具体资源类型或业务数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`resource_selected`](#member-gfresourcetableeditor-signals-resource_selected) | `signal resource_selected(resource: Resource)` |
| 信号 | [`cell_value_committed`](#member-gfresourcetableeditor-signals-cell_value_committed) | `signal cell_value_committed(resource: Resource, property: StringName, old_value: Variant, new_value: Variant)` |
| 信号 | [`resource_save_failed`](#member-gfresourcetableeditor-signals-resource_save_failed) | `signal resource_save_failed(resource: Resource, path: String, error: Error)` |
| 信号 | [`resources_reordered`](#member-gfresourcetableeditor-signals-resources_reordered) | `signal resources_reordered(resources: Array)` |
| 信号 | [`resource_inserted`](#member-gfresourcetableeditor-signals-resource_inserted) | `signal resource_inserted(resource: Resource, index: int)` |
| 信号 | [`resource_removed`](#member-gfresourcetableeditor-signals-resource_removed) | `signal resource_removed(resource: Resource, index: int)` |
| 信号 | [`resource_filter_changed`](#member-gfresourcetableeditor-signals-resource_filter_changed) | `signal resource_filter_changed(query: String, visible_count: int)` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfresourcetableeditor-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_RESOURCE_PATHS`](#member-gfresourcetableeditor-constants-default_max_resource_paths) | `const DEFAULT_MAX_RESOURCE_PATHS: int = 10000` |
| 属性 | [`auto_save_committed_resources`](#member-gfresourcetableeditor-properties-auto_save_committed_resources) | `var auto_save_committed_resources: bool = false` |
| 属性 | [`search_text`](#member-gfresourcetableeditor-properties-search_text) | `var search_text: String = ""` |
| 属性 | [`sort_property`](#member-gfresourcetableeditor-properties-sort_property) | `var sort_property: StringName = &""` |
| 属性 | [`sort_ascending`](#member-gfresourcetableeditor-properties-sort_ascending) | `var sort_ascending: bool = true` |
| 方法 | [`build_export_columns`](#member-gfresourcetableeditor-methods-build_export_columns) | `static func build_export_columns(resource: Resource, include_read_only: bool = false) -> Array[Dictionary]:` |
| 方法 | [`scan_resource_paths`](#member-gfresourcetableeditor-methods-scan_resource_paths) | `static func scan_resource_paths( root_path: String = "res://", extensions: PackedStringArray = PackedStringArray(["tres", "res"]), options: Dictionary = {} ) -> PackedStringArray:` |
| 方法 | [`load_resources_from_paths`](#member-gfresourcetableeditor-methods-load_resources_from_paths) | `static func load_resources_from_paths(paths: PackedStringArray, script_filter: Script = null) -> Array[Resource]:` |
| 方法 | [`load_resources`](#member-gfresourcetableeditor-methods-load_resources) | `func load_resources(resources: Array[Resource], columns: Array[Dictionary] = []) -> void:` |
| 方法 | [`get_resources`](#member-gfresourcetableeditor-methods-get_resources) | `func get_resources() -> Array[Resource]:` |
| 方法 | [`get_columns`](#member-gfresourcetableeditor-methods-get_columns) | `func get_columns() -> Array[Dictionary]:` |
| 方法 | [`set_search_text`](#member-gfresourcetableeditor-methods-set_search_text) | `func set_search_text(query: String) -> void:` |
| 方法 | [`get_visible_row_indices`](#member-gfresourcetableeditor-methods-get_visible_row_indices) | `func get_visible_row_indices() -> PackedInt32Array:` |
| 方法 | [`get_visible_resource_count`](#member-gfresourcetableeditor-methods-get_visible_resource_count) | `func get_visible_resource_count() -> int:` |
| 方法 | [`find_resource_index`](#member-gfresourcetableeditor-methods-find_resource_index) | `func find_resource_index(resource: Resource) -> int:` |
| 方法 | [`sort_by_property`](#member-gfresourcetableeditor-methods-sort_by_property) | `func sort_by_property(property: StringName = &"", ascending: bool = true) -> void:` |
| 方法 | [`move_resource`](#member-gfresourcetableeditor-methods-move_resource) | `func move_resource(from_index: int, to_index: int) -> bool:` |
| 方法 | [`insert_resource`](#member-gfresourcetableeditor-methods-insert_resource) | `func insert_resource(resource: Resource, index: int = -1) -> bool:` |
| 方法 | [`remove_resource`](#member-gfresourcetableeditor-methods-remove_resource) | `func remove_resource(row_index: int) -> Resource:` |
| 方法 | [`duplicate_resource`](#member-gfresourcetableeditor-methods-duplicate_resource) | `func duplicate_resource(row_index: int, deep: bool = false, insert_after: bool = true) -> Resource:` |
| 方法 | [`commit_cell_value`](#member-gfresourcetableeditor-methods-commit_cell_value) | `func commit_cell_value(row_index: int, property: StringName, new_value: Variant) -> bool:` |
| 方法 | [`commit_visible_cell_value`](#member-gfresourcetableeditor-methods-commit_visible_cell_value) | `func commit_visible_cell_value(visible_row_index: int, property: StringName, new_value: Variant) -> bool:` |
| 方法 | [`refresh`](#member-gfresourcetableeditor-methods-refresh) | `func refresh() -> void:` |

## 信号

<a id="member-gfresourcetableeditor-signals-resource_selected"></a>

### `resource_selected`

- API：`public`

```gdscript
signal resource_selected(resource: Resource)
```

表格选中资源时发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 被选中的资源。 |

<a id="member-gfresourcetableeditor-signals-cell_value_committed"></a>

### `cell_value_committed`

- API：`public`

```gdscript
signal cell_value_committed(resource: Resource, property: StringName, old_value: Variant, new_value: Variant)
```

单元格值提交后发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 被修改的资源。 |
| `property` | 被修改的属性名。 |
| `old_value` | 提交前的旧值。 |
| `new_value` | 提交后的新值。 |

结构：

- `old_value`: Variant value before commit.
- `new_value`: Variant value after commit.

<a id="member-gfresourcetableeditor-signals-resource_save_failed"></a>

### `resource_save_failed`

- API：`public`

```gdscript
signal resource_save_failed(resource: Resource, path: String, error: Error)
```

自动保存资源失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 保存失败的资源。 |
| `path` | 资源路径。 |
| `error` | Godot 错误码。 |

<a id="member-gfresourcetableeditor-signals-resources_reordered"></a>

### `resources_reordered`

- API：`public`

```gdscript
signal resources_reordered(resources: Array)
```

资源列表顺序变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `resources` | 当前资源列表副本。 |

结构：

- `resources`: Array[Resource]

<a id="member-gfresourcetableeditor-signals-resource_inserted"></a>

### `resource_inserted`

- API：`public`

```gdscript
signal resource_inserted(resource: Resource, index: int)
```

插入资源后发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 被插入的资源。 |
| `index` | 插入索引。 |

<a id="member-gfresourcetableeditor-signals-resource_removed"></a>

### `resource_removed`

- API：`public`

```gdscript
signal resource_removed(resource: Resource, index: int)
```

移除资源后发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 被移除的资源。 |
| `index` | 移除前索引。 |

<a id="member-gfresourcetableeditor-signals-resource_filter_changed"></a>

### `resource_filter_changed`

- API：`public`

```gdscript
signal resource_filter_changed(query: String, visible_count: int)
```

搜索过滤条件变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 当前搜索文本。 |
| `visible_count` | 当前可见资源数量。 |

## 常量

<a id="member-gfresourcetableeditor-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认最大扫描深度。

<a id="member-gfresourcetableeditor-constants-default_max_resource_paths"></a>

### `DEFAULT_MAX_RESOURCE_PATHS`

- API：`public`

```gdscript
const DEFAULT_MAX_RESOURCE_PATHS: int = 10000
```

默认最大扫描资源路径数量。

## 属性

<a id="member-gfresourcetableeditor-properties-auto_save_committed_resources"></a>

### `auto_save_committed_resources`

- API：`public`

```gdscript
var auto_save_committed_resources: bool = false
```

提交单元格后是否自动保存已绑定路径的 Resource。

<a id="member-gfresourcetableeditor-properties-search_text"></a>

### `search_text`

- API：`public`

```gdscript
var search_text: String = ""
```

当前搜索过滤文本。为空时显示全部资源。

<a id="member-gfresourcetableeditor-properties-sort_property"></a>

### `sort_property`

- API：`public`

```gdscript
var sort_property: StringName = &""
```

当前排序属性；为空时不记录排序属性。

<a id="member-gfresourcetableeditor-properties-sort_ascending"></a>

### `sort_ascending`

- API：`public`

```gdscript
var sort_ascending: bool = true
```

当前排序方向。

## 方法

<a id="member-gfresourcetableeditor-methods-build_export_columns"></a>

### `build_export_columns`

- API：`public`

```gdscript
static func build_export_columns(resource: Resource, include_read_only: bool = false) -> Array[Dictionary]:
```

基于资源属性列表构建可编辑列声明。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 示例资源。 |
| `include_read_only` | 是否包含只读属性。 |

返回：列声明列表。

结构：

- `return`: Array of Dictionary column records with name, type, hint, hint_string, usage, and read_only.

<a id="member-gfresourcetableeditor-methods-scan_resource_paths"></a>

### `scan_resource_paths`

- API：`public`

```gdscript
static func scan_resource_paths( root_path: String = "res://", extensions: PackedStringArray = PackedStringArray(["tres", "res"]), options: Dictionary = {} ) -> PackedStringArray:
```

递归扫描资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描根路径。 |
| `extensions` | 文件扩展名白名单，不包含点号。 |
| `options` | 可选参数，支持 `max_scan_depth` 与 `max_resource_paths`。 |

返回：资源路径列表。

结构：

- `options`: Dictionary with optional max_scan_depth and max_resource_paths.

<a id="member-gfresourcetableeditor-methods-load_resources_from_paths"></a>

### `load_resources_from_paths`

- API：`public`

```gdscript
static func load_resources_from_paths(paths: PackedStringArray, script_filter: Script = null) -> Array[Resource]:
```

从路径列表加载资源。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 资源路径列表。 |
| `script_filter` | 可选脚本过滤；只返回附加该脚本或其子类脚本的资源。 |

返回：资源列表。

<a id="member-gfresourcetableeditor-methods-load_resources"></a>

### `load_resources`

- API：`public`

```gdscript
func load_resources(resources: Array[Resource], columns: Array[Dictionary] = []) -> void:
```

加载资源与列声明。

参数：

| 名称 | 说明 |
|---|---|
| `resources` | Resource 列表。 |
| `columns` | 可选列声明；为空时从第一条资源推导。 |

结构：

- `columns`: Array of Dictionary column records.

<a id="member-gfresourcetableeditor-methods-get_resources"></a>

### `get_resources`

- API：`public`

```gdscript
func get_resources() -> Array[Resource]:
```

获取当前资源列表拷贝。

返回：资源列表。

<a id="member-gfresourcetableeditor-methods-get_columns"></a>

### `get_columns`

- API：`public`

```gdscript
func get_columns() -> Array[Dictionary]:
```

获取当前列声明拷贝。

返回：列声明列表。

结构：

- `return`: Array of Dictionary column records.

<a id="member-gfresourcetableeditor-methods-set_search_text"></a>

### `set_search_text`

- API：`public`

```gdscript
func set_search_text(query: String) -> void:
```

设置搜索过滤文本。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 搜索文本，会匹配资源标签、路径和当前列值。 |

<a id="member-gfresourcetableeditor-methods-get_visible_row_indices"></a>

### `get_visible_row_indices`

- API：`public`

```gdscript
func get_visible_row_indices() -> PackedInt32Array:
```

获取当前可见资源行的原始索引。

返回：可见行索引列表。

<a id="member-gfresourcetableeditor-methods-get_visible_resource_count"></a>

### `get_visible_resource_count`

- API：`public`

```gdscript
func get_visible_resource_count() -> int:
```

获取当前可见资源数量。

返回：可见资源数量。

<a id="member-gfresourcetableeditor-methods-find_resource_index"></a>

### `find_resource_index`

- API：`public`

```gdscript
func find_resource_index(resource: Resource) -> int:
```

查找资源在当前列表中的索引。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 目标资源。 |

返回：资源索引；不存在时返回 -1。

<a id="member-gfresourcetableeditor-methods-sort_by_property"></a>

### `sort_by_property`

- API：`public`

```gdscript
func sort_by_property(property: StringName = &"", ascending: bool = true) -> void:
```

按属性或资源标签排序。

参数：

| 名称 | 说明 |
|---|---|
| `property` | 属性名；为空时按资源标签排序。 |
| `ascending` | 是否升序。 |

<a id="member-gfresourcetableeditor-methods-move_resource"></a>

### `move_resource`

- API：`public`

```gdscript
func move_resource(from_index: int, to_index: int) -> bool:
```

移动资源位置。

参数：

| 名称 | 说明 |
|---|---|
| `from_index` | 原始索引。 |
| `to_index` | 目标索引。 |

返回：移动成功返回 true。

<a id="member-gfresourcetableeditor-methods-insert_resource"></a>

### `insert_resource`

- API：`public`

```gdscript
func insert_resource(resource: Resource, index: int = -1) -> bool:
```

插入资源。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 要插入的资源。 |
| `index` | 插入索引；越界或负数时追加到末尾。 |

返回：插入成功返回 true。

<a id="member-gfresourcetableeditor-methods-remove_resource"></a>

### `remove_resource`

- API：`public`

```gdscript
func remove_resource(row_index: int) -> Resource:
```

移除资源。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 资源行索引。 |

返回：被移除的资源；无效索引返回 null。

<a id="member-gfresourcetableeditor-methods-duplicate_resource"></a>

### `duplicate_resource`

- API：`public`

```gdscript
func duplicate_resource(row_index: int, deep: bool = false, insert_after: bool = true) -> Resource:
```

复制资源并插入到列表。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 资源行索引。 |
| `deep` | 是否深拷贝子资源。 |
| `insert_after` | 为 true 时插入到当前资源之后，否则插入到当前位置。 |

返回：复制出的资源；无效索引返回 null。

<a id="member-gfresourcetableeditor-methods-commit_cell_value"></a>

### `commit_cell_value`

- API：`public`

```gdscript
func commit_cell_value(row_index: int, property: StringName, new_value: Variant) -> bool:
```

提交单元格值。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 资源行索引。 |
| `property` | 属性名。 |
| `new_value` | 新值。 |

返回：提交成功返回 true。

结构：

- `new_value`: Variant value assigned to the resource property.

<a id="member-gfresourcetableeditor-methods-commit_visible_cell_value"></a>

### `commit_visible_cell_value`

- API：`public`

```gdscript
func commit_visible_cell_value(visible_row_index: int, property: StringName, new_value: Variant) -> bool:
```

提交当前可见行的单元格值。

参数：

| 名称 | 说明 |
|---|---|
| `visible_row_index` | 过滤后的可见行索引。 |
| `property` | 属性名。 |
| `new_value` | 新值。 |

返回：提交成功返回 true。

结构：

- `new_value`: Variant value assigned to the resource property.

<a id="member-gfresourcetableeditor-methods-refresh"></a>

### `refresh`

- API：`public`

```gdscript
func refresh() -> void:
```

刷新表格显示。
