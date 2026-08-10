# 指针活动与手势摘要

如果项目需要把鼠标或触摸事件整理成“按下、移动、拖拽、空闲”的通用状态，而不是立刻绑定到按钮、棋盘或摄像机业务，可以注册或直接持有 `GFPointerActivityUtility`。

它不会读取全局 `Input`，也不会消费事件；项目在 `_input(event)` 中显式转发即可。

```gdscript
var pointer := Gf.get_utility(GFPointerActivityUtility) as GFPointerActivityUtility
pointer.drag_threshold_pixels = 8.0
pointer.idle_threshold_seconds = 0.5

func _input(event: InputEvent) -> void:
	pointer.handle_input_event(event)

func _process(delta: float) -> void:
	pointer.tick(delta)
```

`GFPointerActivityUtility` 发出 `pointer_pressed`、`pointer_moved`、`pointer_drag_started`、`pointer_dragged`、`pointer_drag_ended`、`pointer_released` 和空闲相关信号，只描述输入活动本身。

是否把拖拽解释成地图平移、物品拖放、框选、UI 滚动或编辑器画刷，应继续留在项目层或具体工具层。

## 手势摘要

需要把单指移动、双指缩放、双指旋转、触控板 pan / magnify 或鼠标滚轮统一为数据时，可以使用 `GFPointerGestureUtility`。它输出 `Dictionary` 摘要，不直接修改 Camera、Control、Node2D 或业务对象。

```gdscript
var gesture := Gf.get_utility(GFPointerGestureUtility) as GFPointerGestureUtility

func _input(event: InputEvent) -> void:
	gesture.handle_input_event(event)

func _ready() -> void:
	gesture.gesture_updated.connect(func(snapshot: Dictionary, _event: InputEvent) -> void:
		var pan_delta := snapshot["pan_delta"] as Vector2
		var scale := float(snapshot["scale"])
	)
```

摘要包含 `active`、`source`、`pointer_count`、`pointer_ids`、`center`、`previous_center`、`pan_delta`、`scale`、`rotation_delta`、`distance`、`previous_distance` 和 `primary_pointer_id`。项目可把这些值映射到地图拖动、相机缩放、画布操作或自定义控件，但这些策略不属于输入层。

鼠标与触摸属于不同身份域：运行时摘要当前以 `-2` 表示鼠标拖拽指针，触点保留 `InputEventScreenTouch.index`，`-1` 只表示没有 primary pointer。这样 touch index 0 与鼠标可以同时活动并独立释放。项目不应把 `pointer_ids` 当作纯 touch index；若只接受触摸，应同时根据事件来源或自己的输入模式过滤。

`GFPointerGestureUtility.calculate_gesture()` 也可以直接对两组指针位置字典做纯数据计算，适合编辑器工具、录制回放或测试中复用同一套手势数学。
