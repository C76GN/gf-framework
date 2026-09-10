# 2D 相机编排

2D Director 从候选 Rig 中选择当前姿态，并把结果应用到 `Camera2D`。

```gdscript
var director := GFCameraDirector2D.new()
director.camera_path = director.get_path_to(camera_2d)
director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL

var overview := GFCameraRig2D.new()
overview.priority = 1
overview.global_position = Vector2(0.0, 0.0)
overview.zoom = Vector2(1.2, 1.2)

var focus := GFCameraRig2D.new()
focus.priority = 10
focus.target_path = focus.get_path_to(player)
focus.offset = Vector2(0.0, -64.0)

director.rig_paths = [
	director.get_path_to(overview),
	director.get_path_to(focus),
]
director.process_camera(delta)
```

项目可以用多个 Rig 表达总览、玩家跟随、剧情焦点或调试视角。Director 只负责选择和应用当前最佳姿态。

`process_camera(delta)` 只在本帧真实应用了 Rig 姿态时返回 `true`。如果当前没有可用 Rig，Director 会保留相机原状并返回 `false`；调用方不应把“相机仍保持原姿态”当作本帧已经应用新姿态。

Director 会把“选择 active rig”和“应用到 Camera”分开。缺少 Camera 时仍可以刷新并选中可用 Rig，但 `process_camera()` 返回 `false`；需要诊断时读取 `get_debug_snapshot()` 中的 `last_process.reason`，例如 `missing_camera` 或 `missing_rig`。

需要把 2D 姿态写入诊断、网络或存档报告时，使用 `GFCameraRig2D.get_camera_pose_data()`。它会去掉运行时 Rig 对象引用，改用 `rig_path` / `rig_instance_id` 等 JSON-safe 字段表达来源。

## 多目标共同入镜

启用 `gf.camera` 后，可以用 `GFCameraFramingRig2D` 为多个 `Node2D` 锚点计算中心和统一缩放。它适合双人共屏、观战和多个对象的展示，仍由现有 Director 选择优先级并执行混合。

```gdscript
func _ready() -> void:
	var director: GFCameraDirector2D = %Director
	var camera: Camera2D = %Camera2D
	var framing := GFCameraFramingRig2D.new()
	add_child(framing)
	framing.target_paths = [
		framing.get_path_to(%FirstTarget),
		framing.get_path_to(%SecondTarget),
	]
	framing.viewport_margin = Vector2(48.0, 48.0)
	framing.min_extent = Vector2(32.0, 32.0)
	framing.min_zoom = 0.25
	framing.max_zoom = 2.0
	framing.priority = 10
	director.camera_path = director.get_path_to(camera)
	director.rig_paths = [director.get_path_to(framing)]
	var _applied: bool = director.process_camera(0.0)
	var report: Dictionary = framing.get_framing_report(camera)
	if not GFVariantData.get_option_bool(report, "fits"):
		print("取景状态：", GFVariantData.get_option_string_name(report, "reason"))
```

目标路径相对 Rig，项目决定哪些目标加入集合。取景使用目标锚点，不自动推断 Sprite、碰撞形状或业务角色的范围；需要包住完整对象时，可以由项目提供边缘锚点。每次计算重新解析路径，离树、待释放、缺失和重复目标不会作为有效目标；有效集合为空时没有可应用姿态。

目标必须位于输出 Viewport 的同一世界画布。共享 `World2D` 的多个 Viewport 可以使用同一组世界锚点；属于不同世界或 `CanvasLayer` 的目标会明确失败，不能把它们的局部坐标混为一个包围框。

`viewport_margin` 表示视口每侧的像素留白，`min_extent` 表示退化包围框的最小世界范围，避免单个目标或重合目标导致无限放大。缩放限制由 `min_zoom` / `max_zoom` 指定。Director 将实际 `Camera2D` 传给 Rig，取景使用该相机的有效输出 Viewport，不假设 Rig 与相机位于相同大小的视口。Camera2D 忽略旋转时按未旋转画面计算；取景需要居中锚点模式。

相机自身的变换基底必须有限且不退化，父变换也必须允许写入期望的全局姿态；不满足时报告 `invalid_camera_transform`，不应用错误姿态。相机的画面缩放由 `zoom` 决定，项目不需要用节点 `scale` 实现取景。

群体取景不使用继承的单目标 `target_path`、`use_target_rotation` 和固定 `zoom`。它使用 Rig 的全局旋转加 `rotation_degrees_offset`，并应用 Rig 的 `offset`；Camera2D 忽略旋转时取景角度为零。相机原生 `offset` 会在期望位置中反向补偿，其属性本身保持不变。

报告中的 `ok` 表示是否成功得到有限、可应用的期望姿态；`fits` 表示在该姿态和留白下能否包住真实目标锚点；`zoom_limited` 表示缩放受到配置限制。最小缩放过大并挤出目标时，仍可成功计算姿态，但 `fits` 为 `false`，项目可以据此调整取景策略。缩放夹取不必然导致目标出画，例如单个锚点可能同时满足 `zoom_limited = true` 和 `fits = true`。非法参数或缺少有效相机时读取 `reason`，不要把失败结果当作默认位置或缩放。

`fits` 只描述期望姿态的几何结果。Director 混合途中、Camera2D 原生限位、拖拽或平滑都可能使当前画面暂时不同；需要严格共同入镜的界面应明确配置这些行为。

## 自定义 2D Rig 的上下文

`get_camera_pose(camera: Camera2D = null)` 和 `get_camera_pose_data(camera: Camera2D = null)` 现在接受目标相机。普通 `GFCameraRig2D` 仍支持无参读取；取景 Rig 必须有相机上下文，才能读取正确的输出尺寸。

已有自定义 2D Rig 如果重写这两个方法，应为覆盖方法增加相同的可选参数，并在调用父类时转交它，例如 `super.get_camera_pose(camera)`。Director 统一传入实际相机，不通过反射兼容旧的无参覆盖。3D Rig 的方法不受这项变更影响。
