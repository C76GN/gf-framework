# 3D 相机编排

3D 用法保持同一套语义。`GFCameraRig3D` 可以用 `target_path` 跟随目标位置和旋转，也可以开启 `look_at_enabled` 并设置 `look_at_target_path`，让期望 Transform 朝向另一个节点。

```gdscript
var rig := GFCameraRig3D.new()
rig.priority = 20
rig.target_path = rig.get_path_to(anchor)
rig.offset = Vector3(0.0, 3.0, 7.0)
rig.offset_follows_rotation = true
rig.look_at_enabled = true
rig.look_at_target_path = rig.get_path_to(subject)
```

3D Rig 只计算期望 Camera Transform。碰撞避让、遮挡处理、锁定目标、镜头摇臂或关卡脚本仍由项目层组合。

基础 `GFCameraRig3D` 的 `offset` 默认沿世界坐标轴。启用 `offset_follows_rotation` 时，只有目标存在且 `use_target_rotation = true` 才使用目标全局旋转，否则使用 Rig 全局旋转；所用旋转已剥离缩放和反射。位置偏移先计算，随后才执行 `look_at` 和 `rotation_degrees_offset`，因此后两者不改变偏移方向。

Camera 姿态只保留可由 Quaternion 表示的右手旋转：Rig 会从目标或自身 `Basis` 中剥离缩放，并按 Godot 的 rotation extraction 约定把镜像/奇数负轴缩放收敛为 determinant 近似 `+1` 的正交 Basis。这样负缩放层级也不会把反射矩阵送入 Director 的四元数 blend；需要保留镜像或 signed scale 的效果应由项目在渲染层单独处理，而不是写入 Camera 姿态。

`get_camera_transform()` 保留原生 `Transform3D`，便于运行时直接应用。需要 JSON-safe 数据时无需为 Camera 维护第二套 schema，可直接调用 `GFVariantJsonCodec.variant_to_json_compatible(rig.get_camera_transform())`；恢复时使用 `json_compatible_to_variant()`。

## 环绕 Rig

需要常见第三人称或检查物体视角时，可以使用 `GFCameraOrbitRig3D`。它继承 `GFCameraRig3D`，把 `target_path` 作为焦点来源，把 `offset` 作为焦点偏移，然后用 `yaw_degrees`、`pitch_degrees` 和 `distance` 计算相机姿态。Orbit Rig 会继续遵循基础 Rig 的 `look_at_enabled`、`look_at_target_path` 和 `rotation_degrees_offset` 语义。

```gdscript
var rig := GFCameraOrbitRig3D.new()
rig.target_path = rig.get_path_to(player)
rig.offset = Vector3(0.0, 1.5, 0.0)
rig.set_orbit(30.0, -20.0, 8.0)
```

`GFCameraOrbitInput3D` 是可选输入桥接节点。它可以读取显式注入的 `GFInputMappingUtility`，或从 `node_context_path` / 父级 `GFNodeContext` 获取输入映射，再按项目配置的 `orbit_action_id` 与 `zoom_action_id` 推进 Rig；它也可以处理鼠标右键拖拽和滚轮缩放。找不到有效 Rig 时不会捕获鼠标输入。它不会创建输入上下文或硬编码动作绑定，项目仍然负责决定按键、手柄轴、触摸手势和相机碰撞策略。

鼠标拖拽捕获绑定按下时的 Rig、设备、按键和捕获代次；禁用输入/鼠标环绕、运行时修改 `mouse_button`、窗口失焦或节点离树都会幂等取消捕获。输入值和缩放值分别有限仍不代表乘积有限，桥接会在调用 Rig 前再次拒绝溢出的 orbit/zoom 增量，并返回 `false`，因此这类无效输入不会被标记为已应用。

```gdscript
var input := GFCameraOrbitInput3D.new()
input.set_input_mapping_utility(Gf.get_utility(GFInputMappingUtility))
input.use_input_mapping = true
input.orbit_action_id = &"camera_orbit"
input.zoom_action_id = &"camera_zoom"
rig.add_child(input)
```

启用输入映射后，可通过 `get_debug_snapshot()` 检查 `input_mapping_missing`、`missing_actions` 和 `ready`。这只报告当前输入桥接是否具备运行条件，不会创建 InputMap action，也不会替项目决定动作命名。

## 禁用与本次输入收尾

`enabled = false` 会取消鼠标捕获，并终止当前 `process_input()` 中尚未应用的映射输入。映射修饰器、项目覆盖的映射读取方法或 Rig 的 `orbit_changed` 同步回调都可能触发禁用；即使同一回调又设置 `enabled = true`，旧调用也不会恢复。重新启用后的下一次调用仍可正常处理。

已提交的 Rig 参数不会回滚。例如 orbit 已应用、其变化回调禁用输入时，本次不再读取或应用后续 zoom，`process_input()` 仍返回 `true`。如果修饰器在任何参数提交前禁用，返回 `false`。直接调用 `apply_orbit_vector()` / `apply_zoom_value()` 仍由调用方显式控制，不受这个映射调用准入限制。

如果项目需要“本次完整处理后再停止”，使用 `MANUAL`，让回调只登记停止请求，统一驱动者等 `process_input()` 返回后再禁用。下面的项目脚本挂在包含 `OrbitRig/OrbitInput` 的普通 Node 上；先准备已启用的 `camera_orbit` 二维动作和 `camera_zoom` 一维动作，并在架构就绪后进入该场景。示例在本次参数首次变化时请求收尾，实际项目可替换这个业务条件。

```gdscript
# 项目统一驱动相机映射；回调不递归处理输入，也不在调用中途禁用。
extends Node


## 场景拥有的输入桥接，MANUAL 模式下仅由本脚本调用。
@onready var _orbit_input: GFCameraOrbitInput3D = $OrbitRig/OrbitInput

## 场景拥有的 Rig；这里只监听其参数变化，不接管释放。
@onready var _rig: GFCameraOrbitRig3D = $OrbitRig

## 单次同步调用期间保持 true，阻止驱动者重入自己的处理入口。
var _processing_input: bool = false

## 本次调用结束后消费的停止意图，回调只写这个标记。
var _stop_after_input: bool = false

## 接线成功后才驱动输入；离树或完成停止后不再调度。
var _active: bool = false


## 在首帧前关闭桥接器的自动调度，并接入已经就绪的项目映射。
func _ready() -> void:
	_orbit_input.update_mode = GFCameraOrbitInput3D.UpdateMode.MANUAL
	var mapping: GFInputMappingUtility = Gf.get_utility(GFInputMappingUtility) as GFInputMappingUtility
	if mapping == null:
		push_error("相机输入映射不可用。")
		return
	_orbit_input.set_input_mapping_utility(mapping)
	_orbit_input.use_input_mapping = true
	var connected: int = _rig.orbit_changed.connect(_on_orbit_changed)
	if connected != OK:
		push_error("相机变化监听连接失败。")
		return
	_active = true


## 完整调用原有映射算法，返回后才提交停止请求，不复制 orbit/zoom 计算。
func _process(delta: float) -> void:
	if not _active or _processing_input:
		return
	_processing_input = true
	var _applied: bool = _orbit_input.process_input(delta)
	_processing_input = false
	if not _active:
		return
	if _stop_after_input:
		_stop_after_input = false
		_orbit_input.enabled = false
		_active = false


## 示例业务条件：由本次输入引起的参数变化只登记收尾，不再次调用输入入口。
func _on_orbit_changed(_yaw: float, _pitch: float, _distance: float) -> void:
	if _processing_input:
		_stop_after_input = true


## 离树时撤销本脚本的调度和监听，避免退出后继续控制借用节点。
func _exit_tree() -> void:
	_active = false
	if is_instance_valid(_rig) and _rig.orbit_changed.is_connected(_on_orbit_changed):
		_rig.orbit_changed.disconnect(_on_orbit_changed)
	if is_instance_valid(_orbit_input):
		_orbit_input.enabled = false
```

场景中不要再用其他脚本或自动模式重复调用同一个输入桥接。`_processing_input` 只保护此驱动者，不能拦截外部代码直接调用桥接器；所有相机映射处理应经过同一入口。回调若直接禁用，仍采用立即取消剩余映射的合同；这个配方通过延后执行禁用来表达另一种停止时机，没有新增框架模式。
