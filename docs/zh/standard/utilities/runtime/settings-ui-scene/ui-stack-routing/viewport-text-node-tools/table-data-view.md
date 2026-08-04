# 表格数据视图模型

`GFTableDataView`、`GFTableColumnDefinition` 和 `GFTableSelectionModel` 提供一个不绑定具体控件的表格数据层。它适合资源浏览器、配置表编辑器、运行时列表面板、调试表格或项目自己的数据管理 UI，把排序、过滤、可见行索引、单元格提交和选择状态从 Control 渲染中分离出来。

## 定位

表格数据视图只维护数据和视图状态：源行数组、列定义、过滤文本、排序列、可见行索引和稳定行 ID。它不创建 `Tree`、`ItemList`、`ScrollContainer` 或自绘 Control，不规定表头交互、主题样式、键盘快捷键、拖拽、分页或业务字段含义。

列定义负责描述一列如何读取值、写回值、格式化文本、参与过滤和比较排序。默认读取支持 `Dictionary` 与 `Object` / `Resource` 字段，也可以通过 `Callable` 接入项目自己的 getter、formatter 或 comparator。数据视图的事务式单元格提交只接受默认写入路径，不执行无法证明无副作用的自定义 setter。

## 典型流程

```gdscript
var id_column := GFTableColumnDefinition.new().configure(&"id", "ID")
var name_column := GFTableColumnDefinition.new().configure(&"name", "Name")
var score_column := GFTableColumnDefinition.new().configure(&"score", "Score")
score_column.sort_mode = GFTableColumnDefinition.SortMode.NUMBER
score_column.editable = true

var table := GFTableDataView.new()
var identity_result := table.set_row_id_column(&"id")
var columns_result := table.set_columns([id_column, name_column, score_column])
var rows_result := table.set_rows(records)

table.sort_by_column(&"score", false)
var filter_result := table.set_filter_query("sword")

for visible_index in range(table.get_visible_row_count()):
	var row := table.describe_visible_row(visible_index)
	# 项目在这里把 row["values"] 渲染到自己的 Control。
```

提交单元格时，数据视图会先隔离被触及的候选行，在候选 source 上完成全部默认写入、过滤、结构化谓词和排序；只有完整投影成功后，才一次性交换权威 source、projection、revision 与稳定 ID 选择。任何输入、隔离、写入、投影失败或经 `GFTableDataView` API 发起的回调重入都会保留提交前状态。

稳定行 ID 字段、文本过滤大小写策略与选择模型没有可直接赋值的公共字段。分别使用 `set_row_id_column()`、`set_filter_case_sensitive()` 与 `set_selection_model()` 进入同一候选投影事务，并通过对应 getter 查询已提交配置。候选失败时，旧配置、选择模型、投影与 revision 保持不变；getter、formatter、comparator、谓词或提交期信号回调若尝试重入这些 setter，内外事务都会失败关闭，不会让一次投影混用新旧语义。成功切换稳定 ID 字段或提交 ID 单元格时，选择集合与原范围锚点会按同一源行一起迁移，并在 `selection_changed` 发出前形成一致状态。

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

单格与批量入口使用同一事务边界；批量中任何一项失败都会丢弃整份候选，不会提交有效子集。返回报告包含 `ok`、`requested_count`、`applied_count`、`unchanged_count`、`failed_count`、`committed` 和 `errors`，项目 UI 可以据此展示提交结果。自定义 `value_setter` 会在调用前以 `non_transactional_value_setter` 失败关闭；需要业务命令、远端写入或撤销语义时，应在表格外先完成项目事务，再以新的 source 刷新数据视图。

## 结构化行谓词

复杂过滤应使用类型化行谓词，而不是把业务条件拼进搜索字符串。该协议由五个最小类型组成：

- `GFTableRowView` 是进入谓词前冻结的隔离行快照，只提供稳定 row id、源索引和已配置列值的副本；隐藏列也会包含在快照中，但源 row 本身不会暴露。每个谓词都会从框架内部 canonical view 得到一份独占副本，前一个谓词即使违约修改自己收到的快照，也不能影响后一个谓词。
- `GFTableRowPredicate` 定义同步求值协议。项目只覆写受保护的 `_evaluate()`，返回 `GFTableRowPredicateResult.included()`、`excluded()` 或 `failed()`；DataView 通过框架静态入口直接调用 `_evaluate()`，不会分派到候选子类覆写的公开 `evaluate()`。
- `GFTableRowPredicateResult` 明确区分包含、排除与有界错误，不用 `null`、布尔值或异常文本混合表达状态。框架从继承的基类存储静态归一化结果，不调用候选结果子类可覆写的 getter；未初始化或非法结果会固定失败关闭。
- `GFTableRowPredicateRegistration` 把谓词与稳定 ID、显式 `order` 和启用状态组合为注册定义。`GFTableDataView` 提交时直接从继承的基类存储创建纯框架 metadata 快照，不调用候选子类可覆写的 getter；调用方后续改写原注册对象，或改写 getter 返回的快照，都不会改变权威 registry。predicate 协议实例本身按引用保留，因此项目仍可显式调整该实例自己的参数；参数变化不会被框架隐式观察，修改后必须显式调用 `refresh_view()`，并只在返回的类型化结果成功时采用新投影。
- `GFTableViewRebuildResult` 描述候选投影是否成功、是否提交、对应 revision、扫描/求值计数和失败位置。

```gdscript
class HighScorePredicate extends GFTableRowPredicate:
	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		var score := int(row_view.get_value(&"score", 0))
		return (
			GFTableRowPredicateResult.included()
			if score >= 100
			else GFTableRowPredicateResult.excluded()
		)

var rebuild_result := table.set_row_predicates([
	GFTableRowPredicateRegistration.create(
		&"minimum_score",
		HighScorePredicate.new(),
		10
	),
])
if not rebuild_result.is_successful():
	push_warning(rebuild_result.get_error_message())
```

一次重建固定按“文本过滤 → 启用的结构化谓词 → 排序”执行。谓词按 `order` 升序排列；相同 `order` 使用 `predicate_id` 字典序打破平局，因此注册数组的输入顺序不会改变结果。排除会短路当前行剩余谓词，显式失败会中止整次候选投影。

`set_row_predicates()`、注册、注销、启用和重排都先执行 64 项 raw count admission，再复制并校验完整候选 registry，最后在局部候选索引上执行。超限输入不会遍历条目、调用候选方法或创建逐项快照。成功只交换一次投影、推进一次 revision，并发出一次 `view_changed(view_revision, visible_count)`；候选失败、非法配置或经 `GFTableDataView` 公共 mutation API 发起的递归重入不会修改 registry、source、projection、revision 或 selection，只返回 `GFTableViewRebuildResult` 并发出 `view_rebuild_failed(result)`。`get_row_predicate()` 与 `get_row_predicates()` 返回独立 metadata 快照；`get_last_view_rebuild_result()` 和失败信号也提供隔离结果，观察者不能污染模型保存的诊断。

谓词保持同步、纯读取且工作量有界，是调用方必须满足的协议前置条件。框架只保证经 `GFTableDataView` 公共 mutation API 发起的递归修改会失败关闭；如果谓词自行捕获外部 source、选择模型或其他可变对象并直接修改，项目已经违反协议，框架既无法检测全部副作用，也不能撤回此前由外部对象发出的信号。启用谓词时，row id 必须是 `GFVariantKeyCodec` 接受的稳定 key；`Object`、`Resource`、集合与其他引用身份不能作为 row id，失败结果也不会携带源对象别名。列值快照会在固定深度、节点数、集合项数与 UTF-8 字节预算内递归复制；PackedVector 按 double-precision 构建的最坏元素宽度计费。无脚本且通过复制后等价/无别名验证的内建 `Resource` 可以进入快照，脚本 `Resource`、其他 `Object`、`Callable`、`Signal`、`RID`、循环或超预算图一律失败关闭。

## 视图快照

需要把当前表格交给自定义控件、调试面板、虚拟列表或导出层时，可以使用 `describe_view()`。默认快照只包含当前可见行和可见列，并保留排序、过滤、选择状态与列描述；这让调用方拿到的是“当前视图”，而不是混杂源数据和隐藏字段的结构。

```gdscript
var snapshot := table.describe_view()
for row in snapshot["rows"]:
	var values: Dictionary = row["values"]
	print(row["visible_row_index"], row["row_id"], values)
```

如果需要完整源行，可以传入 `visible_only = false`；被过滤隐藏的行会保留在 `rows` 中，并以 `visible_row_index = -1` 标记。需要包含隐藏列或原始行数据时，显式启用 `include_hidden_columns` 或 `include_row_data`。

```gdscript
var full_snapshot := table.describe_view({
	"visible_only": false,
	"include_hidden_columns": true,
	"include_row_data": true,
})
```

`describe_row()` 可用于单独描述某个源行。快照中的值默认会复制 `Dictionary` / `Array`，避免调试、导出或渲染层意外修改源行；如果调用方明确需要引用原值，可以传入 `copy_values = false`。

## 选择状态

`GFTableSelectionModel` 使用稳定 row id 维护选择集合，而不是使用当前可见行号。因此排序、过滤和可见行重建不会自动丢失选择。项目通过 `get_selection_model()` 访问当前模型；需要让多个表格共享模型时，以 `set_selection_model()` 事务式安装同一个实例。

```gdscript
var selection := table.get_selection_model()
selection.set_selected("weapon_001", true)
table.sort_by_column(&"name")
table.set_filter_query("rare")

if selection.is_selected("weapon_001"):
	# 即使该行当前被过滤隐藏，选择状态仍然保留。
```

当源数据删除行后，可以调用 `prune_selection()` 移除已经不存在的 row id；如果只想保留当前可见行的选择，传入 `true`。

## 与虚拟列表的关系

`GFTableDataView` 负责回答“当前有哪些可见行、每行有哪些列值”。`GFVirtualListModel` 负责回答“大量可变尺寸行在滚动窗口中应该物化哪些索引”。`GFVirtualListFocusModel` 可用当前可见行索引维护虚拟焦点，避免焦点绑定到被回收复用的行控件。大表 UI 可以组合三者：先用 `GFTableDataView` 得到过滤/排序后的可见行顺序，再用 `GFVirtualListModel` 控制 Control 的创建和测量，用 `GFVirtualListFocusModel` 驱动键盘或手柄焦点表现。

组合层只应在 `view_changed` 成功信号中先更新虚拟布局的条目数量，再让 binder 失效并同步当前窗口。投影失败不会发出 `view_changed`，因此不得清空、重排或局部覆盖已经物化的控件；保留上一 revision 的布局与选择，等待调用方处理类型化失败结果后再决定是否重试。

## 注意事项

- `set_row_id_column()` 应传入稳定字段；为空或缺失时会回退到源行索引，这适合临时表格，但不适合长期保存选择状态。
- 列定义的 `editable` 为 false 时，`commit_cell_value()` 不会写回该列。
- 自定义 `value_getter`、`value_formatter` 和 `value_comparator` 必须保持同步、无业务副作用且工作量有界；经 `GFTableDataView` API 发起的递归 source / selection mutation 会中止外层候选，直接修改回调捕获的外部可变对象则属于项目违约。事务式单元格入口不执行自定义 `value_setter`。真正的保存、撤销、权限和校验流程仍应在项目或编辑器工具层处理。
- 表格模型不解析 CSV 表头、不推断业务类型、不内置 checkbox、progress bar 或日期规则。这些都应由列定义和渲染层明确表达。
