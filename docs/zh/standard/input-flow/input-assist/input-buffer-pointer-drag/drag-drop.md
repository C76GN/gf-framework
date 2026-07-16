# 拖放会话

如果项目已经把鼠标、触摸、手柄光标或编辑器指针整理成统一位置，并希望再把“拖拽会话”和“可释放落点”拆出来复用，可以使用 `GFDragDropUtility`。

它只管理 `GFDragSession`、`GFDropZone`、命中排序和 drop 结果包装，不读取 `InputEvent`，不移动节点，也不规定背包、棋盘、卡牌、技能栏或编辑器工具的业务含义。

## 最小流程

```gdscript
var drag_drop := GFDragDropUtility.new()
var toolbar_drop := func(session: GFDragSession, zone: GFDropZone, position: Variant) -> Dictionary:
	return {
		"ok": true,
		"payload": session.payload,
		"zone": zone.zone_id,
		"position": position,
	}

drag_drop.register_rect_zone(
	&"toolbar",
	Rect2(Vector2(0.0, 0.0), Vector2(320.0, 64.0)),
	PackedStringArray(["command"]),
	{
		"priority": 10,
		"drop": toolbar_drop,
	}
)

var session_id := drag_drop.start_drag(&"command", { "id": &"inspect" }, pointer_position)
drag_drop.update_drag(session_id, pointer_position)
var result := drag_drop.drop(session_id, release_position)
```

## 使用边界

`GFDropZone` 可以由矩形、`Control.get_global_rect()` 或自定义 `contains_callable` 描述命中范围；`accepted_types` 为空表示不限制拖拽类型，`priority` 越大越优先。

由 `Control` 创建的落点会在查询时剪枝失效引用，并跳过不可交互控件：不在场景树、不可见、`mouse_filter = MOUSE_FILTER_IGNORE` 或已禁用的 `BaseButton` 都不会被命中。`only_accepting=true` 查询会先检查类型和 `can_accept` 回调，再执行命中检测，适合拖拽预览或高频指针更新减少无效回调。

更复杂的权限、容量、冷却、网格占用或跨模块事务应写在项目自己的 `can_accept` / `drop` 回调、Command 或 System 中，再把最终结果以 `{ "ok": true }` 或 `{ "ok": false, "reason": ... }` 返回给工具。

## 可选控制器

如果项目需要把一次 UI 拖拽绑定到 source 节点生命周期、单指针捕获、取消和临时拖拽层，可以使用 `GFDragDropController`。控制器持有一个 `GFDragDropUtility`，一次只管理一个活动拖拽；需要多指或多窗口并行拖拽时，为每个交互域创建独立控制器即可。

```gdscript
var controller := GFDragDropController.new()
add_child(controller)

controller.register_control_zone(&"inventory_slot", slot_control, PackedStringArray(["item"]))

var session_id := controller.start_drag(
	&"item",
	item_payload,
	pointer_position,
	item_control,
	{
		"pointer_id": touch_index,
		"drag_parent": drag_layer,
	}
)

controller.update_pointer(pointer_position, touch_index)
var result := controller.drop(release_position, touch_index)
```

`GFDragDropController` 会在 source 离开场景树或失效时取消活动拖拽，错误 pointer 不会更新或释放当前会话。传入 `drag_parent` 时，source 会临时 reparent 到拖拽层；默认取消和无落点结束会恢复原父级，成功 drop 后是否恢复由 `restore_source_parent_on_success` 显式控制，避免框架替项目决定最终摆放位置。

控制器把底层 session、pointer capture、临时 reparent 和 source 生命周期监听作为同一个事务处理。`drag_parent` 不能是 source 自身或其子孙；底层拒绝启动时不会留下 capture 或错误父级。drop、cancel、无落点和 source 退出树等所有终态都会断开本次监听，重复拖拽同一节点不会累积旧回调。
