# 视口与坐标转换

如果项目需要本地多人分屏、每玩家相机或简单的编辑器预览布局，可以使用 `GFViewportUtility`。它只创建和维护 `SubViewportContainer` / `SubViewport` 结构，并提供按索引挂载相机与后处理材质的 API，不接管玩家、镜头规则或场景生命周期。

```gdscript
var viewport_util := GFViewportUtility.new()
var viewports := viewport_util.setup_split_screen(%Root, 2, {
	"viewport_size": Vector2i(640, 360),
})
viewport_util.set_viewport_camera(0, $Camera2D)
```

默认情况下，`viewport_size` 会保持 SubViewport 的渲染尺寸，`viewport_resolution_scale` 会按比例缩放该尺寸；需要让 SubViewport 跟随容器大小时，可在 options 中传入 `"stretch": true`。`clear_split_screen()` 会立即把旧 `GridContainer` 和已挂载相机从当前树上移除，再按参数决定是否释放相机，便于同一帧重建布局或切换分屏配置。

`viewport_resolution_scale` 只接受有限值，`NaN` / `Inf` 不会覆盖最后一个有效缩放。Control 到窗口矩形换算以及安全区换算也会在 `roundi()` 或 Control theme 写入前验证全部浮点输入；任一矩形、偏移、Viewport 尺寸或边距不是有限值时返回 `ok = false`，`apply_safe_area_margins()` 返回 `false` 且不会部分覆盖现有边距。

同一个工具还提供少量不绑定输入来源的坐标辅助。`screen_to_world_ray_3d(camera, screen_position, length)` 可从 Camera3D 和 Viewport 坐标生成射线，`raycast_from_screen_3d()` 在此基础上执行物理射线检测，`world_to_screen_3d()` 做 3D 投影；无效 Camera3D 会返回 `Vector2.ZERO`，需要失败原因时使用 `world_to_screen_3d_report()`。2D 侧可用 `world_to_screen_2d(canvas_item, world_position)` 与 `screen_to_world_2d(canvas_item, screen_position)` 在 CanvasItem 世界坐标和屏幕坐标之间转换。

这些方法不读取鼠标、不选择玩家、不决定命中对象含义，只提供稳定几何转换。

需要把 Godot UI 区域同步给原生平台视图、外部 overlay 或编辑器预览时，可用 `get_control_window_rect(control, viewport)` 读取 Control 全局矩形并换算为物理窗口像素。纯计算场景使用 `calculate_control_window_rect(control_rect, viewport_size, window_size, options)`，返回值包含 `ok`、`rect`、`scale_x`、`scale_y`、`content_rect` 和原始尺寸。窗口存在 letterbox、HiDPI 内容区或嵌入式 viewport 偏移时，传入 `"content_rect": Rect2i(...)`；只需要整体偏移时可传 `"viewport_offset"`。调用方仍负责外部视图的创建、权限和生命周期。

## 移动安全区

移动端 UI 需要避开刘海、圆角、系统手势区域或项目自己的固定遮挡时，可以用 `GFViewportUtility` 把 `DisplayServer.get_display_safe_area()` 返回的物理像素安全区转换为当前 Viewport 的逻辑边距。

```gdscript
var viewport_util := GFViewportUtility.new()
var margins := viewport_util.get_display_safe_area_margins(get_viewport(), {
	"bottom": 48.0,
})
viewport_util.apply_safe_area_margins(%SafeAreaRoot, margins)
```

`calculate_safe_area_margins()` 是纯计算入口，适合测试、编辑器工具或项目自己从平台插件获得安全区数据后复用。`extra_margins` 使用 Viewport 逻辑坐标，可以叠加项目自有底栏、悬浮输入区域或其他遮挡，但这些遮挡来源仍由项目决定。
