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

## 环绕 Rig

需要常见第三人称或检查物体视角时，可以使用 `GFCameraOrbitRig3D`。它继承 `GFCameraRig3D`，把 `target_path` 作为焦点来源，把 `offset` 作为焦点偏移，然后用 `yaw_degrees`、`pitch_degrees` 和 `distance` 计算相机姿态。Orbit Rig 会继续遵循基础 Rig 的 `look_at_enabled`、`look_at_target_path` 和 `rotation_degrees_offset` 语义。

```gdscript
var rig := GFCameraOrbitRig3D.new()
rig.target_path = rig.get_path_to(player)
rig.offset = Vector3(0.0, 1.5, 0.0)
rig.set_orbit(30.0, -20.0, 8.0)
```

`GFCameraOrbitInput3D` 是可选输入桥接节点。它可以读取显式注入的 `GFInputMappingUtility`，或从 `node_context_path` / 父级 `GFNodeContext` 获取输入映射，再按项目配置的 `orbit_action_id` 与 `zoom_action_id` 推进 Rig；它也可以处理鼠标右键拖拽和滚轮缩放。找不到有效 Rig 时不会捕获鼠标输入。它不会创建输入上下文或硬编码动作绑定，项目仍然负责决定按键、手柄轴、触摸手势和相机碰撞策略。

```gdscript
var input := GFCameraOrbitInput3D.new()
input.set_input_mapping_utility(Gf.get_utility(GFInputMappingUtility))
input.use_input_mapping = true
input.orbit_action_id = &"camera_orbit"
input.zoom_action_id = &"camera_zoom"
rig.add_child(input)
```

启用输入映射后，可通过 `get_debug_snapshot()` 检查 `input_mapping_missing`、`missing_actions` 和 `ready`。这只报告当前输入桥接是否具备运行条件，不会创建 InputMap action，也不会替项目决定动作命名。
