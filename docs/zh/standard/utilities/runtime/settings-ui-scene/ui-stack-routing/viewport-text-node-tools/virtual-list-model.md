# 虚拟列表布局模型

`GFVirtualListModel` 是一个纯布局模型，用来维护大量可变尺寸条目的估算尺寸、实测尺寸、累计偏移和可见范围。它适合聊天流、日志面板、资源浏览器、编辑器 Dock 或其他长列表控件在项目侧自行实现“只物化可见行”的渲染策略。

## 定位

模型只回答四个问题：列表有多少条目、每个条目的尺寸是多少、当前滚动窗口应该显示哪些索引、尺寸变化后是否需要修正滚动偏移。它不创建 `Control`，不保存条目数据，不绑定 `ScrollContainer`，也不规定节点复用、选择、拖拽、搜索或视觉样式。

这使它可以被运行时 UI 和编辑器工具共同复用：项目或工具负责监听滚动、构建可见行、释放不可见行，并在行控件完成测量后把实际高度写回模型。

## 典型流程

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

## 注意事项

- `get_visible_range()` 返回 `Vector2i(start, end)`，其中 `end` 是不包含的结束索引。
- `overscan_items` 只扩大计算范围，不代表必须同时创建所有条目；项目仍可按帧分批物化。
- `trailing_padding` 只影响 `get_content_extent()` 的默认返回值，不改变条目自身偏移。
- 条目尺寸会被限制到 `MIN_ITEM_EXTENT` 以上，避免零尺寸条目破坏滚动范围。
- 模型不感知横向或纵向；参数名使用 `extent`，项目可把它解释为高度或宽度。
