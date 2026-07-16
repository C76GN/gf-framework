# 虚拟列表布局与焦点模型

`GFVirtualListModel` 是一个纯布局模型，用来维护大量可变尺寸条目的估算尺寸、实测尺寸、累计偏移和可见范围。`GFVirtualListFocusModel` 用数据索引维护虚拟焦点，让回收式列表不用把键盘或手柄焦点绑定到临时物化的 `Control`。

## 定位

布局模型只回答四个问题：列表有多少条目、每个条目的尺寸是多少、当前滚动窗口应该显示哪些索引、尺寸变化后是否需要修正滚动偏移。焦点模型只回答当前哪个数据索引拥有虚拟焦点、前后移动应落到哪个可聚焦索引、数据数量变化后焦点应如何修正。它们都不创建 `Control`，不保存条目数据，不绑定 `ScrollContainer`，也不规定节点复用、选择、拖拽、搜索或视觉样式。

这使它可以被运行时 UI 和编辑器工具共同复用：项目或工具负责监听滚动、构建可见行、释放不可见行，并在行控件完成测量后把实际高度写回模型。

## 布局流程

```gdscript
var model := GFVirtualListModel.new()
model.estimated_item_extent = 56.0
model.overscan_items = 2
model.trailing_padding = 24.0
model.set_item_count(entries.size())

func refresh_visible_rows(scroll_y: float, viewport_height: float) -> void:
	var visible_range := model.get_visible_range(scroll_y, viewport_height)
	for index in range(visible_range.x, visible_range.y):
		var offset := model.get_item_offset(index)
		var extent := model.get_item_extent(index)
		# 项目在这里创建或复用自己的 Control，并放到 offset。
```

当某个行控件完成布局后，把实际高度写回模型。若被修改的条目位于当前视口之前，报告会给出 `scroll_adjustment`，调用方可以把滚动偏移加上这个值来减少内容跳动。

```gdscript
var report := model.set_item_extent(row_index, measured_height, true, scroll_y)
if report["changed"] and report["scroll_adjustment"] != 0.0:
	scroll_container.scroll_vertical += int(report["scroll_adjustment"])
```

## 虚拟焦点

回收式列表中，当前可见行 `Control` 会不断复用，因此焦点状态应保存在数据索引上，再由渲染层把焦点表现同步到当前物化的行控件。

```gdscript
var focus := GFVirtualListFocusModel.new()
focus.item_count = entries.size()
focus.focusable_callback = func(index: int) -> bool:
	return not entries[index].get("disabled", false)

focus.focus_first()
focus.focus_next()

var focused_index := focus.focused_index
if focused_index != GFVirtualListFocusModel.NO_FOCUS:
	# 项目在这里滚动到 focused_index，并刷新当前可见行的焦点表现。
```

`wrap_navigation` 控制首尾是否环绕。条目数量或 `focusable_callback` 变化后，当前焦点会优先保留；如果越界或不再可聚焦，会修正到附近可聚焦索引。默认不会在没有焦点时自动选择第一项；需要进入列表后自动聚焦时，启用 `auto_focus_on_count_change` 或显式调用 `focus_first()`。

`GFVirtualListFocusModel` 表达的是“导航焦点”，不等于业务选中。需要保留多选、范围选择或排序/过滤后的稳定选择时，应继续使用 `GFTableSelectionModel` 或项目自己的选择状态。

## 注意事项

- `get_visible_range()` 返回 `Vector2i(start, end)`，其中 `end` 是不包含的结束索引。
- `overscan_items` 只扩大计算范围，不代表必须同时创建所有条目；项目仍可按帧分批物化。
- `trailing_padding` 只影响 `get_content_extent()` 的默认返回值，不改变条目自身偏移。
- estimate、实测 extent、padding 和 offset 必须是有限数值；`NaN` / `Inf` 会被拒绝或回退，条目尺寸还会被限制到 `MIN_ITEM_EXTENT` 以上，维持二分查找所需的有限单调累计偏移。
- 模型不感知横向或纵向；参数名使用 `extent`，项目可把它解释为高度或宽度。
- `focusable_callback` 应保持轻量、可重复调用，不应在判断过程中修改列表数据或创建节点。
