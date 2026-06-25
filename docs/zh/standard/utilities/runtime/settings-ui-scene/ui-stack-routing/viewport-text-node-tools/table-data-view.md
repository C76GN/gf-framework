# 表格数据视图模型

`GFTableDataView`、`GFTableColumnDefinition` 和 `GFTableSelectionModel` 提供一个不绑定具体控件的表格数据层。它适合资源浏览器、配置表编辑器、运行时列表面板、调试表格或项目自己的数据管理 UI，把排序、过滤、可见行索引、单元格提交和选择状态从 Control 渲染中分离出来。

## 定位

表格数据视图只维护数据和视图状态：源行数组、列定义、过滤文本、排序列、可见行索引和稳定行 ID。它不创建 `Tree`、`ItemList`、`ScrollContainer` 或自绘 Control，不规定表头交互、主题样式、键盘快捷键、拖拽、分页或业务字段含义。

列定义负责描述一列如何读取值、写回值、格式化文本、参与过滤和比较排序。默认实现支持 `Dictionary` 与 `Object` / `Resource` 字段，也可以通过 `Callable` 接入项目自己的 getter、setter、formatter 或 comparator。

## 典型流程

```gdscript
var id_column := GFTableColumnDefinition.new().configure(&"id", "ID")
var name_column := GFTableColumnDefinition.new().configure(&"name", "Name")
var score_column := GFTableColumnDefinition.new().configure(&"score", "Score")
score_column.sort_mode = GFTableColumnDefinition.SortMode.NUMBER
score_column.editable = true

var table := GFTableDataView.new()
table.row_id_column = &"id"
table.set_columns([id_column, name_column, score_column])
table.set_rows(records)

table.sort_by_column(&"score", false)
table.set_filter_query("sword")

for visible_index in range(table.get_visible_row_count()):
	var row := table.describe_visible_row(visible_index)
	# 项目在这里把 row["values"] 渲染到自己的 Control。
```

提交单元格时，数据视图会通过列定义写回源行，并在排序或过滤可能受影响时重建可见行索引。

```gdscript
table.commit_visible_cell_value(visible_index, &"score", 120)
```

需要一次性应用多格修改时，可以使用批量提交入口。`commit_cell_values()` 接收源行索引，`commit_visible_cell_values()` 接收当前可见行索引；可见行索引会在写入前统一解析为源行索引，避免第一项修改触发重排后影响后续项。

```gdscript
var report := table.commit_visible_cell_values([
	{ "visible_row_index": 0, "column_id": &"score", "new_value": 120 },
	{ "visible_row_index": 1, "column_id": &"score", "new_value": 80 },
])

if report["ok"]:
	print(report["applied_count"])
```

批量提交不是事务；部分失败不会回滚已成功的项。返回报告包含 `ok`、`requested_count`、`applied_count`、`unchanged_count`、`failed_count`、`committed` 和 `errors`，项目 UI 可以据此展示批量编辑结果。

## 选择状态

`GFTableSelectionModel` 使用稳定 row id 维护选择集合，而不是使用当前可见行号。因此排序、过滤和可见行重建不会自动丢失选择。项目可以直接使用 `table.selection_model`，也可以把同一个选择模型共享给多个表格视图。

```gdscript
table.selection_model.set_selected("weapon_001", true)
table.sort_by_column(&"name")
table.set_filter_query("rare")

if table.selection_model.is_selected("weapon_001"):
	# 即使该行当前被过滤隐藏，选择状态仍然保留。
```

当源数据删除行后，可以调用 `prune_selection()` 移除已经不存在的 row id；如果只想保留当前可见行的选择，传入 `true`。

## 与虚拟列表的关系

`GFTableDataView` 负责回答“当前有哪些可见行、每行有哪些列值”。`GFVirtualListModel` 负责回答“大量可变尺寸行在滚动窗口中应该物化哪些索引”。大表 UI 可以组合两者：先用 `GFTableDataView` 得到过滤/排序后的可见行顺序，再用 `GFVirtualListModel` 控制 Control 的创建和测量。

## 注意事项

- `row_id_column` 应指向稳定字段；为空或缺失时会回退到源行索引，这适合临时表格，但不适合长期保存选择状态。
- 列定义的 `editable` 为 false 时，`commit_cell_value()` 不会写回该列。
- 自定义 `value_getter`、`value_setter`、`value_formatter` 和 `value_comparator` 应保持无业务副作用；真正的保存、撤销、权限和校验流程仍应在项目或编辑器工具层处理。
- 表格模型不解析 CSV 表头、不推断业务类型、不内置 checkbox、progress bar 或日期规则。这些都应由列定义和渲染层明确表达。
