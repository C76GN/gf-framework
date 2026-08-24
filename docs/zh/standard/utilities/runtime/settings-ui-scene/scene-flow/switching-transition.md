# 切换与 Transition 配置

`GFSceneUtility` 用于切换主场景、播放 Loading 过渡、后台预加载资源，并在切换时清理旧场景专用模块。

```gdscript
var scene_util := Gf.get_utility(GFSceneUtility) as GFSceneUtility

# 标记 BattleSystem 为瞬态，它会在切场景时自动从架构中被注销/销毁。
scene_util.mark_transient(BattleSystem)

# 开始带 Loading 过渡的异步切换。
var load_error: Error = scene_util.load_scene_async(
	"res://levels/level_2.tscn",
	"res://ui/loading_screen.tscn"
)
if load_error != OK:
	push_error("无法发起场景切换：%s" % error_string(load_error))
```

如果项目希望把切换参数做成资源，可使用 `GFSceneTransitionConfig`：

```gdscript
var transition := GFSceneTransitionConfig.new()
transition.target_scene_path = "res://levels/level_2.tscn"
transition.loading_scene_path = "res://ui/loading_screen.tscn"
transition.preload_before_change = true
transition.cache_loaded_scene = true
transition.params = { "spawn_point": "gate_a" }
transition.minimum_duration_seconds = 0.35

var transition_error: Error = scene_util.load_scene_with_transition(transition)
```

这两个入口会同步返回“是否成功发起”对应的 Godot `Error`；路径无效、资源类型错误或当前状态拒绝时不会伪装成 `OK`。已经发起后的加载进度与异步终态继续通过 `scene_load_progress`、`scene_load_failed`、`scene_load_completed` 和 `scene_switch_completed` 等信号观察。成功信号只在 `SceneTree.scene_changed` 已确认冻结目标成为 `current_scene` 后发布。

需要逐请求身份、独立取消或安全帧提交终态时，使用
`load_scene_request_async()` 并保存返回的 `GFSceneOperation`。类型化入口与旧信号保持
兼容，但全局信号不适合作为单次 consumer 的相关性协议；完整时序见
[类型化场景请求](async-requests.md)。

`minimum_duration_seconds` 只控制 loading scene 至少停留多久，避免缓存命中时过渡 UI 一闪而过；它不替代目标场景自己的初始化等待。

## 屏幕覆盖式转场

如果项目只需要通用的淡入、淡出或 shader 进度覆盖层，可组合 `GFScreenTransitionUtility` 与 `GFScreenTransitionEffect`。该 Utility 只管理一个 `CanvasLayer` 覆盖层，不直接调用 `GFSceneUtility`，因此同样适用于菜单切页、战斗结算、存档读档遮罩或项目自己的切场景管线。

```gdscript
var screen_transition := Gf.get_utility(GFScreenTransitionUtility) as GFScreenTransitionUtility
var scene_util := Gf.get_utility(GFSceneUtility) as GFSceneUtility

screen_transition.fade_out(0.25, Color.BLACK, func() -> void:
	scene_util.load_scene_async("res://levels/level_2.tscn")
)
```

`GFScreenTransitionEffect` 可以配置起止透明度、时长、颜色、缓动、CanvasLayer 层级和可选 `ShaderMaterial`。如果设置了 `shader_material`，Utility 会复制材质并向 `progress_parameter` 写入 0 到 1 的进度；具体 shader 仍由项目提供。

这类覆盖层只解决“视觉遮罩如何播放”的问题，不负责目标场景初始化、资源预热、玩家出生点、旧场景释放或业务状态迁移。需要完整切换流程时，仍应让项目把它与 `GFSceneUtility`、loading scene 或自己的流程控制组合起来。
