# 通用 Resource 表格控件

`GFResourceTableEditor` 是 `kernel/editor` 下的通用控件，用于把一组 `Resource` 按导出属性显示成表格。它不绑定具体配置类型，适合项目或扩展自己的编辑器面板复用。

```gdscript
var editor := GFResourceTableEditor.new()
editor.load_resources(resources, GFResourceTableEditor.build_export_columns(resources[0]))
editor.set_search_text("weapon")
editor.sort_by_property(&"priority")
editor.duplicate_resource(0)
editor.move_resource(0, 2)
```

控件提供路径扫描、脚本过滤、列推导、单元格提交、搜索过滤、排序、插入、复制、移动、移除和可见行索引查询。

`scan_resource_paths()` 默认限制递归深度和收集数量，项目工具可通过 `max_scan_depth` / `max_resource_paths` 调整。`commit_cell_value()` 始终接收原始资源行索引；启用过滤后可用 `get_visible_row_indices()` 做映射，或直接调用 `commit_visible_cell_value()`。

需要一次性应用多格修改时，可使用 `commit_cell_values()` 或 `commit_visible_cell_values()`。前者接收原始资源行索引，后者接收当前可见行索引；可见行索引会在写入前统一解析，避免第一项修改刷新过滤结果后影响后续项。

```gdscript
var report := editor.commit_visible_cell_values([
	{ "visible_row_index": 0, "property": &"label", "new_value": "Iron Sword" },
	{ "visible_row_index": 1, "property": &"amount", "new_value": 3 },
])
```

批量提交不是事务；部分失败不会回滚已成功的资源修改。返回报告包含 `ok`、`requested_count`、`applied_count`、`unchanged_count`、`failed_count`、`committed` 和 `errors`。启用自动保存时，同一批中同一个 `Resource` 只会保存一次。

自动保存只会在 `auto_save_committed_resources = true` 且资源已有 `resource_path` 时触发；保存失败通过 `resource_save_failed` 交给调用方处理。

## 值字段控件

`GFEditorValueField` 是表格和自定义 Inspector 可复用的单值输入控件。默认会按 Godot property info 创建 bool、int、float、enum、Vector2/3/4、Color、StringName、NodePath、Array 和 Dictionary 输入；Array / Dictionary 仍使用 JSON 文本输入，并在解析失败时保留旧值。

```gdscript
var field := GFEditorValueField.new()
field.set_label("Offset", true)
field.set_debounce_seconds(0.2)
field.configure({
	"name": &"offset",
	"type": TYPE_VECTOR2,
}, Vector2.ZERO)
field.debounced_value_changed.connect(func(value: Variant) -> void:
	commit_preview_value(value)
)
```

项目工具需要特殊控件时，可按 Variant 类型注册工厂。工厂返回的 Control 如果实现 `get_value()`、`set_value(value)`、`set_editable(editable)` 或发出 `value_changed(value)`，`GFEditorValueField` 会按这些约定读写和转发。控件工厂只用于编辑器 UI，不应在里面写入资源或场景；提交仍应由表格、命令或调用方控制。
