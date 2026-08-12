# Viewport 表面输入桥

`GFViewportSurfaceInputBridge` 把上游 provider 已解析出的表面命中、稳定指针身份和 `0.0..1.0` 坐标，同步转换成目标 `Viewport` 可接收的鼠标或触摸事件。它适合 3D 面板、监视器、离屏 UI 或其他把输入投射到 `SubViewport` 的通用场景。

这条边界是 provider-neutral 的：框架不求解射线、UV、Mesh、XR 控制器或显示表面，也不选择目标。项目或适配器负责命中解析，并给每次目标身份分配正整数 `target_generation`；桥只校验、捕获和投递。

## 捕获回执与代际

指针 key 由 `source_id + device_id + pointer_id` 组成。`capture_pointer()` 成功时返回 `GFViewportSurfaceInputCapture`，调用方必须保留该回执，并在 move、release 或 cancel 时原样交回同一个桥。回执同时携带桥分配的 capture generation 和 provider 提供的 target generation。

```gdscript
var bridge := GFViewportSurfaceInputBridge.new()
bridge.configure_limits(16, 32, 500, 8.0, 256)

var capture := bridge.capture_pointer(
	&"world_panel",
	device_id,
	pointer_id,
	GFViewportSurfaceInputBridge.PointerType.TOUCH,
	panel_viewport,
	panel_generation,
	normalized_uv,
	timestamp_msec
)
if capture != null:
	# 命中仍在原目标上时更新最后合法位置。
	bridge.move_pointer(
		capture,
		panel_viewport,
		panel_generation,
		new_normalized_uv,
		new_timestamp_msec
	)

# 即使指针已经离开表面，也在原目标的最后合法位置终止。
bridge.release_pointer(capture, release_timestamp_msec)
```

同一个 key 完成后可以被再次捕获，但会获得新的 capture generation。旧 press 的迟到 release/cancel 因回执对象与代际都不匹配而 fail-closed，不会终止新捕获。桥还用独立于双击历史的最近指针时间表保留每个 key 的时间高水位；仍在该表中的 key 即使已经结束上一代捕获，也会拒绝更早的迟到 press。目标被释放、target generation 改变、时间回退或坐标非法时同样不会猜测目标或坐标。

时间表默认保留最近 256 个 key，可通过 `configure_limits()` 的第五个参数配置为 `1..4096`，并用 `get_pointer_timestamp_count()` 观测当前占用。该预算是有界合同：key 被更多新近指针淘汰后，桥不再声称能仅凭时间识别它的旧 press，因此 provider 仍必须为每个稳定 key 提供非回退时间戳。把双击历史设为 `0` 或发生双击历史裁剪，不会关闭或删除仍在时间表预算内的保护。

## 坐标、事件类型与生命周期

- 输入坐标必须有限且两轴都位于闭区间 `0.0..1.0`；每一轴按 `uv * (size - 1)` 连续单调地映射到首尾有效像素，因此 `0.0` 对应首像素、`1.0` 对应末像素，不会落到 Viewport 的右侧或底部排他边界。`NaN`、Infinity 和越界值会被拒绝。
- `PointerType.MOUSE` 产生 `InputEventMouseButton` / `InputEventMouseMotion`；`PointerType.TOUCH` 产生 `InputEventScreenTouch` / `InputEventScreenDrag`。桥不会在两类之间隐式转换。
- `forward_mouse_hover()` 只接受未捕获的 mouse key；同一 key 已按下时必须继续走 capture 的 move/release/cancel API，桥会拒绝伪造 `button_mask=0` 的 hover motion。
- 每次投递时都读取目标当前尺寸。Viewport resize 后，move、release 和 cancel 会用当前尺寸换算最后合法标准化坐标。
- 离面 release/cancel 不需要再次提供目标，因此仍投递到按下时捕获的弱引用目标；若目标已释放或离开 SceneTree，则清理捕获并返回失败。
- 重复 press、重复按钮 press/release 不会重复产生状态事件，但成功接受的重复样本仍会推进最后合法位置或时间。鼠标 release 只接受左、右、中与两个扩展按钮，滚轮按钮返回 `false`。活动指针数、跨代际时间表、双击历史、双击时间窗口和像素距离都有显式上限；预算只能在首个样本前配置。
- provider 停用时调用 `cancel_source()`，目标代际失效时调用 `cancel_target()`，所有者销毁时调用 `dispose()`。`cancel_source()` 还会按 source/device 清除调用前已经释放的双击记录与时间高水位，使重新启用的 provider 从新的生命周期开始；若在同步 Viewport 回调中终止 source，仍在调用栈上的旧 hover/release 会失效，而回调后新建的 capture 代际不属于旧入口快照。批量取消仍在各自最后合法位置产生 cancel 事件。

## 所有权边界

桥只拥有“表面样本到 Viewport 输入事件”的同步适配和捕获生命周期。它不替代 `GFPointerActivityUtility` 的输入模式/活动追踪，不解释手势，不判定拖放，也不包含 UI、交互或 XR 业务规则。需要这些能力时，在项目层把各自单一职责的服务组合起来。
