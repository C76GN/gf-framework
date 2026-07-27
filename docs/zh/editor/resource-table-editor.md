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

需要一次性应用多格修改时，可使用 `commit_cell_values()` 或 `commit_visible_cell_values()`。前者接收原始资源行索引，后者接收当前可见行索引；可见行索引会在写入前统一解析，避免第一项修改刷新过滤结果后影响后续项。两者都会先验证全部行和属性，再通过 `GFEditorPropertyBatchCommand` 原子提交：任一输入无效时零写入，运行期 setter 拒绝或最终状态不一致时恢复本次尝试前的全部显式属性。

```gdscript
var report := editor.commit_visible_cell_values([
	{ "visible_row_index": 0, "property": &"label", "new_value": "Iron Sword" },
	{ "visible_row_index": 1, "property": &"amount", "new_value": 3 },
])
```

返回报告包含 `ok`、`status`、`error`、`requested_count`、`applied_count`、`unchanged_count`、`failed_count`、`issue_count`、`rolled_back`、`recovery_required`、`committed` 和 `errors`。`failed_count` 按唯一变更索引计数，`issue_count` 保留写入、补偿与终态验证产生的全部问题数。仅当 `recovery_required = true` 时，报告才包含 `transaction_command`；调用方可在修复目标 setter 的可写条件后调用 `recover()`（未 executed 的失败也可调用 `revert()`），再刷新表格。正常成功和完整回滚不会暴露可绕过表格信号、自动保存与刷新链路的命令句柄。

`cell_value_committed`、刷新和自动保存只在整批属性事务成功后发生；同一批中同一个 `Resource` 只保存一次。自动保存只会在 `auto_save_committed_resources = true` 且资源已有 `resource_path` 时触发，保存失败通过 `resource_save_failed` 交给调用方处理。`ResourceSaver` 是属性事务完成后的副作用，不属于内存属性回滚边界，也不提供多文件磁盘事务保证。

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
