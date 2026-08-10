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

## 同步回调与终态

`GFDragDropUtility` 的 signal 与 `contains` / `can_accept` / `drop` Callable 都在当前调用栈同步执行，因此框架把它们视为可重入边界：

- `start_drag()` 先注册会话再发出 `drag_started`；监听器若在回调中取消该会话，outer 调用返回 `-1`。
- `drop()` 解析期间，同一会话再次调用 `drop()` 会返回 `session_resolving`。项目回调若取消同一会话，取消终态优先，outer 调用返回 `session_cancelled`，不会再发出 `drag_dropped`。
- `get_drop_candidates()` / `get_best_drop_zone()` 的项目回调若取消或替换当前 session，本次查询立即失败关闭为空；控制器不会在该取消终态之后继续转发旧会话的 `drag_moved`。
- `contains` / `can_accept` 回调返回时若候选已不再注册，业务 `drop` Callable 不会执行，本次返回 `drop_zone_changed`，会话保留以便重试。
- `drop` 回调返回 `ok=false` 是可重试拒绝，会话继续活动；没有可用落点的 `no_drop_zone` 是终态拒绝，会话已经移除。
- `clear_sessions()` 与 `clear_zones()` 只处理调用开始时的快照；同步回调中新建的会话或落点会保留，不会无通知消失。

会话和落点的 JSON 调试快照直接进入带循环检测、深度、节点数和集合项预算的 `GFVariantJsonCodec`。循环值会输出 typed marker，遍历超限会输出 `TraversalLimit`，不会回退为 raw Object/Resource。metadata 的摄入容量策略仍应由项目在信任边界限制；不要把无界外部数据直接当作拖拽 metadata。

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

`GFDragDropController` 会在 source 离开场景树或失效时取消活动拖拽，错误 pointer 不会更新或释放当前会话，`-1` 不能作为活动捕获 ID。传入 `drag_parent` 时，source 会临时 reparent 到拖拽层；默认取消和无落点结束会恢复原父级，成功 drop 后是否恢复由 `restore_source_parent_on_success` 显式控制，避免框架替项目决定最终摆放位置。

控制器把底层 session、pointer capture、临时 reparent 和 source 生命周期监听作为同一个事务处理。`drag_parent` 不能是 source 自身或其子孙；底层拒绝启动时不会留下 capture 或错误父级。`drag_started` 只在这些状态全部提交后发布；若 started 回调同步结束会话，outer `start_drag()` 返回 `-1`。drop、cancel、无落点和 source 退出树等终态会先恢复可恢复的 source、断开监听并释放 pointer，再发布控制器终态信号，因此终态监听器可以立即开始下一会话。

仍有效但暂时 parentless 的 source 会用原父级重新挂载；原父级已释放、正在释放、拓扑非法或跨 SceneTree 时不会做非法 reparent，但会话和监听仍会安全闭合。需要业务层感知“视觉恢复失败”时，应在终态后检查 source 拓扑；框架当前没有单独的 restore-result signal。

`get_utility()` 当前返回可写的 live Utility。直接对控制器管理的 session 调用底层 `update_drag()`、`drop()` 或 `cancel_drag()` 会绕过控制器 façade 的 pointer 检查；底层终态仍会触发控制器清理。需要把 pointer capture 当作强制 authority 时，只调用控制器入口，不向低信任代码暴露这个 getter。
