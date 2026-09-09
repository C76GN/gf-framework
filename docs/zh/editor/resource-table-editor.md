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

需要一次性应用多格修改时，可使用 `commit_cell_values()` 或 `commit_visible_cell_values()`。前者接收原始资源行索引，后者接收当前可见行索引；可见行索引会在写入前统一解析，避免第一项修改刷新过滤结果后影响后续项。两者都会先验证全部行和属性，再通过 `GFEditorPropertyBatchCommand` 原子提交：任一输入无效时零写入，运行期 setter 拒绝或最终状态不一致时恢复本次尝试前的全部显式属性。空变更数组是成功恒等操作，返回 `status = committed`、`error = OK` 和全零计数，不构造属性事务命令。

```gdscript
var report := editor.commit_visible_cell_values([
	{ "visible_row_index": 0, "property": &"label", "new_value": "Iron Sword" },
	{ "visible_row_index": 1, "property": &"amount", "new_value": 3 },
])
```

返回报告包含 `ok`、`status`、`error`、`requested_count`、`applied_count`、`unchanged_count`、`failed_count`、`issue_count`、`rolled_back`、`recovery_required`、`committed` 和 `errors`。`failed_count` 按唯一变更索引计数，`issue_count` 保留写入、补偿与终态验证产生的全部问题数。仅当 `recovery_required = true` 时，报告才包含 `transaction_command`；调用方可在修复目标 setter 的可写条件后调用 `recover()`（未 executed 的失败也可调用 `revert()`），再刷新表格。正常成功和完整回滚不会暴露可绕过表格信号、自动保存与刷新链路的命令句柄。

规范化请求值与稳定当前值相同时，该条目仍提交成功并计入 `unchanged_count`，但不会调用 setter 或发出 `cell_value_committed`。只有至少一项属性实际变化时，表格才统一刷新并处理自动保存；因此只有同值条目的单格或整批提交也不会保存或刷新。自动保存只会在 `auto_save_committed_resources = true` 且已变化资源存在 `resource_path` 时触发，同一批中同一个 `Resource` 只保存一次，保存失败通过 `resource_save_failed` 交给调用方处理。需要把通知或持久化作为独立动作的项目工具应使用自己的显式流程，不应把等值提交当作触发器。`ResourceSaver` 是属性事务完成后的副作用，不属于内存属性回滚边界，也不提供多文件磁盘事务保证。

## 多选属性编辑

表格支持多行选择，并在下方选择一个属性共同编辑。编辑器插件先提供已有的命令上下文：

```gdscript
var table := GFResourceTableEditor.new()
table.set_editor_context(GFEditorToolContext.from_plugin(self))
table.load_resources(resources)
```

缺少有效 `undo_manager` 时可以查看和暂存输入，应用按钮保持禁用；原有 `commit_cell_value()` 等直接提交 API 的行为不变。通过编辑器工作区创建的面板可接收工作区传递的同一上下文，独立使用者显式调用 `set_editor_context()`。

属性显示为一致或混合值，每个标量或向量分量旁都有“修改”勾选框。改变输入会自动勾选；也可以手动勾选，将显示的首个目标值明确应用到全部选择。未勾选的分量不会进入命令。例如两个资源分别为 `(1, 10)` 和 `(2, 20)`，只修改 `x = 8` 后得到 `(8, 10)` 和 `(8, 20)`。暂存期间其他代码修改未编辑的 `y` 时，应用也会保留其当前值。

“应用”调用 `apply_selected_property()`，把全部已勾选分量交给一条 `GFEditorPropertyBatchCommand`，由上下文管理器形成一次 Undo/Redo。只有事务成功并实际改变资源时，才发出 `Resource.changed`、`cell_value_committed` 并刷新表格；自动保存继续遵循上述可选、非磁盘事务规则。撤销和重做同样通知与保存，历史命令保活资源，弱引用面板；关闭面板后仍能重放资源修改。

表格仍存活但已绑定另一组资源时，旧历史动作不会刷新当前表格或覆盖草稿；旧资源的自动保存失败仍通过 `resource_save_failed` 上报，信号携带发生失败的原资源、路径和错误码。

“取消”、清空或更换选择、切换属性、刷新表格、替换上下文以及离树都会丢弃未应用的草稿，不修改资源。缺失属性、失效目标、只读声明以及不同类型或编辑提示的组合会禁止整批提交，不会只修改其中一部分。当前支持 `bool`、`int`、`float`、`String`、`StringName`、`NodePath` 和 `Vector2/3/4` 及其整数类型；其他类型仅展示，不递归展开 Resource、数组或字典。

`get_multi_edit_report()` 返回最近一次应用、撤销、重做或恢复的实际结果。原生管理器可能已建立或移动历史动作，而命令回调随后失败，因此以报告的 `ok`、`error` 和实际事务报告判断结果。失败不会发出成功的单元格通知，面板会刷新当前资源的实际值并显示诊断。

如果补偿没有完整完成，报告保留 `transaction_command`，面板显示“恢复编辑”并暂停新的多选应用。取消草稿、替换上下文或重新绑定资源都不会丢失这个句柄；没有有效上下文时恢复按钮禁用。修正资源 setter 的拒绝条件后，点击“恢复编辑”或调用 `recover_pending_edit()`，可重试恢复最近失败尝试前的属性状态。恢复失败仍保留句柄，成功后刷新受影响的当前资源并重新允许应用。

恢复不等于完成原操作。例如撤销前两个值均为 `9`，撤销及补偿失败后残留 `9`、`2`，恢复会回到 `9`、`9`，命令仍然处于已执行状态。若需再尝试真正撤销，可保留报告中的命令句柄并调用它的 `revert()`；控件不会擅自移动原生历史游标。恢复成功只清除待恢复状态，不对 Godot 已经接受的历史操作作成功承诺。跨不同编辑器 history 的目标仍由现有命令入口拒绝，此控件不会另建全局历史。

自定义面板也可复用 `GFEditorMultiPropertyField`：`configure(targets, property)` 建立弱引用选择，`get_snapshot()` 读取混合/缺失与草稿状态，`prepare_changes()` 重新验证并生成命令输入，`cancel_edit()` 丢弃草稿。这个控件只组织输入和已编辑分量，不执行事务，也不持有编辑器管理器。

## 值字段控件

`GFEditorValueField` 是表格和自定义 Inspector 可复用的单值输入控件。默认会按 Godot property info 创建 bool、int、float、enum、Vector2/3/4、Color、String、StringName、NodePath、Array 和 Dictionary 输入；Array / Dictionary 仍使用 JSON 文本输入，并在解析失败时保留旧值。

数值字段没有 `PROPERTY_HINT_RANGE` 时允许负值和大于默认控件上限的值；声明范围时继续使用属性提示中的上下限和步长。带 `PROPERTY_HINT_MULTILINE_TEXT` 的 String 使用多行文本框，保留空白行与首尾换行，支持同样的值同步、只读和防抖信号。这些行为也适用于多选属性编辑中的标量与向量分量输入。

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
