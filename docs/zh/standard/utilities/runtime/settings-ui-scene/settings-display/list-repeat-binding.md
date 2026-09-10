# 列表与模板绑定

`GFItemListBinder` 和 `GFRepeaterBinder` 用于把数组数据同步到 UI，不把具体业务字段写进框架。

- `GFItemListBinder` 写入 `ItemList`、`OptionButton` 或 `PopupMenu`，支持文本、id/metadata、图标、禁用、tooltip 和初始选中状态。
- `GFRepeaterBinder` 用一个模板节点重复生成子节点，适合简单设置项、资源行、调试行或项目自己的列表 UI。

## 条目控件

```gdscript
var items := [
	{ "id": &"low", "text": "Low" },
	{ "id": &"high", "text": "High", "selected": true },
]

GFItemListBinder.write_items(%QualityOption, items)
var selected := GFItemListBinder.get_selected_metadata(%QualityOption)
```

长期跟随状态树时，可以绑定 `GFReactiveStateStore` 路径：

```gdscript
var binder := GFItemListBinder.new()
binder.bind_items(store, "settings.quality_options", %QualityOption)
```

`options` 可配置字段名，例如 `text_key`、`id_key`、`metadata_key`、`icon_key`、`disabled_key`、`selectable_key`、`tooltip_key` 和 `selected_key`。这些只是映射规则，项目仍然决定条目含义和点击后的行为。

## 模板重复

```gdscript
var binder := GFRepeaterBinder.new()
binder.bind_repeater(store, "inventory.rows", %Rows, %RowTemplate, {
	"text_key": "label",
	"configure_callable": func(row: Node, item: Variant, index: int) -> void:
		row.set_meta("row_index", index)
})
```

`GFRepeaterBinder` 默认隐藏模板节点，清理同一 `group_key` 下由它创建的旧副本，再复制当前数据对应的新节点。副本会带 `gf_repeater_clone`、`gf_repeater_group_key`、`gf_repeater_index` 和 `gf_repeater_item` meta，方便项目侧识别来源。

## 按稳定 ID 更新模板列表

列表中包含输入框、展开面板或其他需要保留节点身份的控件时，提供 `identity_callable(item, index)`。相同 ID 和模板的条目复用已有节点，插入只创建新节点，删除只释放对应副本，重排只移动节点；继续由 `VBoxContainer`、`HBoxContainer` 或 `GridContainer` 负责布局。

```gdscript
var binder := GFRepeaterBinder.new()
var bound: bool = binder.bind_repeater(store, "rows", %Rows, %RowTemplate, {
	"identity_callable": func(item: Variant, _index: int) -> Variant:
		return GFVariantData.get_option_value(GFVariantData.as_dictionary(item), "key"),
	"configure_callable": func(row: Node, item: Variant, index: int) -> void:
		var label: Label = row.get_node("NameLabel") as Label
		label.text = GFVariantData.get_option_string(GFVariantData.as_dictionary(item), "name")
		row.set_meta("row_index", index)
})
```

示例中的 `key` 和 `name` 都是项目选择的字段名，框架没有预设 ID 字段。ID 应表达条目身份，不能使用会随排序变化的数组下标。稳定键的支持范围和相等性由 `GFVariantKeyCodec` 定义。

相同 ID、模板实例和 `duplicate_flags` 才能复用节点。可比较的数据、索引和 `text_key` 都没有变化时，不重复调用配置回调。发生更新或重排时，回调负责同步需要变化的内容；不要每次都重置输入框、展开状态或正在播放的项目动画。上例只写 `NameLabel`，不会主动覆盖同一行中另一个输入框的未提交内容。节点复用不替代项目自己的草稿保存和业务提交。

有限的纯值数组和字典使用独立快照比较，可以发现同一数组或字典的原地修改。包含 Object、Callable、Signal、RID、循环，或超过比较预算的数据保留项目引用，每次同步都会配置对应行；框架不复制对象图。比较预算为深度 16、每项 4096 个值。回调闭包的外部状态不参与比较；需要强制重新配置未变化行时，可先 `clear_clones()` 再同步。

需要直接同步并检查失败原因时，使用 `GFRepeaterBinder.sync_container(container, template, items, options)` 的结构化结果。非法或重复 ID 会在修改 UI 前拒绝。模板或复制选项发生变化时不能继续复用旧副本；绑定只管理自己的克隆组，不会删除模板或其他组的装饰节点。

初次绑定失败通过 `bind_repeater()` 的 `false` 返回值报告。已建立绑定后，自动刷新被拒绝会发出 `synchronization_failed(container, group_key, error)`，项目可以提示输入问题或记录错误；直接调用 `sync_container()` 则检查返回报告的 `ok` 和 `error`。

每次同步最多接受 4096 项，单个稳定键编码后最多 4096 个 UTF-8 字节；按 ID 同步要求 `clear_existing=true`。选项只接受 API 中列出的字段和类型，未知键或无效类型会被拒绝。迁移旧调用时应移除附带的业务字段，把它们保留在项目自己的配置中。用 `Node.duplicate()` 复制已经同步的容器时，副本建立独立组状态，首次同步会重建复制出来的行，之后才开始按 ID 复用。

配置回调是同步的。回调中的解绑、容器离树或副本删除可能使本次更新失效；调用方应检查同步结果，不要把它当作能回滚任意项目副作用的事务。外部事件、Timer 和异步工作仍应由项目节点的生命周期负责清理。

回调更新绑定的状态路径时，本次同步退栈后会在后续帧处理最新值，每个绑定只保留一次待刷新请求。解绑会使旧请求失效，不会覆盖之后的新绑定。项目仍应避免配置回调与状态写入之间形成持续反馈循环。

## 使用边界

这两个 Binder 只处理数组到 UI 的同步和 owner 生命周期清理，不替代 `GFTableDataView` 的排序/过滤模型，也不替代项目自己的列表交互、分页或业务提交逻辑。普通模板列表适合需要原生 Container 布局和持续节点身份的界面；大量可变尺寸长列表使用 `GFVirtualListModel` 与 `GFVirtualListBinder` 的可见区回收机制。
