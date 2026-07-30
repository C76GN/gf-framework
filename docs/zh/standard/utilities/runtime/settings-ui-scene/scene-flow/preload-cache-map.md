# 预加载缓存与图谱

如果项目需要在关卡入口、地图预览或传送门附近提前准备场景资源，可以使用预加载缓存。缓存有 LRU 上限控制，`max_preloaded_scene_resources = 0` 时会清空并禁用缓存。

```gdscript
scene_util.max_preloaded_scene_resources = 4
scene_util.preload_scene("res://levels/level_3.tscn")
scene_util.preload_scene("res://levels/hub.tscn", true)

scene_util.scene_preload_completed.connect(func(path: String, _scene: PackedScene) -> void:
	if path == "res://levels/level_3.tscn":
		scene_util.load_scene_async(path)
)

scene_util.begin_background_scene_load("res://levels/level_4.tscn", { "spawn_point": "gate_b" })
scene_util.activate_background_scene("res://levels/level_4.tscn", "res://ui/loading_screen.tscn")

var snapshot := scene_util.get_scene_cache_debug_snapshot()
print(snapshot["preload_cache"]["paths"])
```

`get_scene_resource_state()` 可区分未加载、预加载中、已缓存和当前加载。`get_scene_resource_info()` 会额外返回固定缓存、预加载进度和文件大小信息。预加载请求可用 `cancel_scene_preload()` 或 `cancel_all_scene_preloads()` 标记取消；它只取消当前消费者 Lease、完成信号和缓存写入，不保证中止 Godot 已发起的资源线程。最后一个消费者取消后，底层请求会进入 Broker drain，迟到结果不会重新写入场景缓存。`get_scene_cache_debug_snapshot()` 的 `resource_broker` 可用于观察 active、pending、draining 与独占 admission。已缓存的场景可用 `remove_preloaded_scene()` 或 `clear_preloaded_scenes()` 手动释放；固定缓存可通过 `move_preloaded_scene_to_fixed()` / `move_preloaded_scene_to_temporary()` 在长期保留和 LRU 管理之间切换。

场景路径会在缓存、后台加载参数、历史和图谱查询中规范化：去掉首尾空白，统一反斜杠为 `/`，并折叠 `res://` 下的 `.` / `..` 片段。图谱查找、相邻遍历、固定/临时列表去重和重复校验会使用 `GFResourceIdentity.cache_key`，因此 `uid://` 与 canonical `res://` 指向同一资源时不会生成重复计划；对外报告仍保留 canonical 路径，便于项目层阅读和调试。

## 预加载图谱

如果相邻场景关系比较稳定，可以把预加载规则做成 `GFScenePreloadMap` 资源。每个 `GFScenePreloadEntry` 描述一个场景路径、相邻场景路径和是否固定缓存；`GFSceneUtility` 只按图谱计算预加载计划，不解释“关卡”“传送门”或“菜单流”的业务含义。

```gdscript
var preload_map := GFScenePreloadMap.new()
var hub_entry := GFScenePreloadEntry.new()
hub_entry.scene_path = "res://levels/hub.tscn"
hub_entry.adjacent_scene_paths = PackedStringArray([
	"res://levels/forest.tscn",
	"res://levels/cave.tscn",
])
preload_map.entries = [hub_entry]
preload_map.fixed_scene_paths = PackedStringArray(["res://ui/loading_screen.tscn"])

scene_util.configure_scene_preload_map(preload_map, 1, true)
scene_util.preload_scene_map_for("res://levels/hub.tscn")
```

`get_scene_preload_map_plan(path, radius, include_fixed)` 只返回计划，适合调试 UI 或测试断言。计划中包含 `source_cache_key`、`fixed_cache_keys`、`temporary_cache_keys`、`cache_keys` 和 `resource_identities`，可用于确认 `uid://` / `res://` 是否收敛到同一资源身份。`preload_scene_map_for()` 会把固定路径以 fixed cache 发起预加载，把相邻路径放入临时 LRU 缓存。`scene_preload_map_radius = -1` 表示使用图谱自身的 `default_radius`。

`auto_preload_map_neighbors_on_switch = true` 时，Scene Utility 会在切换前先监听目标 `scene_changed`，确认目标资源身份后等待首个稳定 process/render 边界，再以 `exclusive + require_idle` 请求共享 `GFResourceBroker`。因此仍在 Broker 中活动或 draining 的 Asset warmup 会先收敛，相邻场景不会在同一切换帧与它重叠发起。headless 环境使用 process frame 加零时长 SceneTree timer 作为无渲染 settle。新切换、图谱/半径变更、关闭自动预载与 Utility dispose 都会取消旧 generation；同路径手动预载拥有独立持久兴趣，不会被旧自动 generation 误杀。

邻居批次会在每次 Broker 请求和 `scene_preload_started` 等同步可重入通知后重验
generation。若通知处理器重配或关闭图谱，旧批次会立刻停止，不会继续登记剩余
邻居。Scene 的真实资源请求在 headless 也必须经过 Broker；缺少 Broker 时
`load_scene_async()` 返回 `ERR_UNCONFIGURED`，不会隐式同步加载。

图谱的 `validate_map({ "check_exists": true })` 可检查空路径、重复条目、自引用和缺失资源。图谱适合表达可复用资源关系；如果预加载依赖玩家进度、动态服务器配置或复杂权重，应由项目层先计算候选路径，再交给 `preload_scenes()` 或 `preload_scene_map_for()`。
