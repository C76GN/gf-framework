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
