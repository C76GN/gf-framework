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

## 使用边界

这两个 Binder 只处理数组到 UI 的同步和 owner 生命周期清理，不替代 `GFTableDataView` 的排序/过滤模型，也不替代项目自己的列表交互、分页、虚拟化或业务提交逻辑。大量可变尺寸长列表仍建议组合 `GFVirtualListModel`。
