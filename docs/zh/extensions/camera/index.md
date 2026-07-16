# Camera 通用相机编排

Camera 扩展提供通用 Rig、Director 和 Blend 资源。它只负责把“候选视角、优先级、过渡方式”抽象出来，不读取输入、不绑定角色控制器、不解释剧情状态，也不规定相机抖动、碰撞避让、锁定目标或关卡脚本。

`GFCameraRig2D` 和 `GFCameraRig3D` 是期望相机姿态的提供者。它们可以直接使用自身全局姿态，也可以通过 `target_path` 跟随任意 `Node2D` / `Node3D`。`GFCameraDirector2D` 和 `GFCameraDirector3D` 从显式 `rig_paths` 或 Rig 自动加入的分组中收集候选，按优先级选择当前可用 Rig，再把插值后的姿态应用到指定 Camera。

默认 Rig 分组分别是 `gf_camera_rig_2d` 与 `gf_camera_rig_3d`。自动分组收集会按 `camera_scope_path` / 父节点和 `camera_channel` 隔离，避免同一场景树中多个相机导演互相抢用 Rig。项目也可以关闭分组收集，只使用显式路径；显式 `rig_paths` 不参与 scope / channel 过滤，适合项目明确声明的跨区域镜头。

## 阅读入口

- [2D 相机编排](camera-2d.md)：显式 Rig 路径、优先级选择和手动更新。
- [过渡资源](blend.md)：`GFCameraBlend` 的持续时间、Tween transition/ease 和采样权重。
- [3D 相机编排](camera-3d.md)：目标跟随、旋转跟随、look-at 目标和 3D 姿态。

## 使用边界

Camera 扩展不接管项目的镜头状态机。常见做法是让项目 System、场景 Controller、状态机或关卡脚本只调整 Rig 的 `active`、`priority`、`target_path`、`camera_channel` 和配置资源；Director 继续只负责选择和应用当前最佳姿态。

## API Reference

完整类、属性和方法见 [Camera API Reference](../../reference/api/extensions-camera.md)。
