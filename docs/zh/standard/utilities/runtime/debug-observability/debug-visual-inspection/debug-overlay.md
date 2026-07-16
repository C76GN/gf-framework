# 调试覆盖层

`GFDebugOverlayUtility` 会创建一个轻量 `CanvasLayer` 覆盖层，通过反射扫描当前架构内注册的 `GFModel`，并显示脚本变量的实时值。项目也可以主动发布少量运行时 watch，把不适合放进 Model 的临时观察值显示在同一个面板里。

它不是命令行控制台，也不执行指令；需要输入调试命令、查看日志输出时请使用 `GFConsoleUtility`。

覆盖层默认 `debug_only = true`，发布构建不会创建 GUI；如果项目确实需要在非 debug 构建中显示，必须显式关闭该选项，并自行确认数据脱敏和玩家可见性。

覆盖层会直接反射显示脚本变量值，并显示项目已发布的 watch 快照，不做业务字段白名单过滤。发布值会先经过报告边界编码和容量限制，Overlay 刷新阶段不会调用项目 `Callable`。

## 基础用法

```gdscript
var debug := Gf.get_utility(GFDebugOverlayUtility) as GFDebugOverlayUtility

# 默认按 `~` 呼出/隐藏，可按项目需要更换快捷键和刷新间隔。
debug.set_toggle_key(KEY_QUOTELEFT)
debug.set_refresh_interval(0.25)

# 可选：主动推送当前值，适合项目层已有刷新点的指标。
debug.push_watch_value(&"fps", Engine.get_frames_per_second(), {
	"label": "FPS",
	"group": "Runtime",
})

# 可选：在项目已有刷新点主动发布场景状态。
var scene := get_tree().current_scene
debug.push_watch_value(&"scene_path", "" if scene == null else scene.scene_file_path, {
	"label": "Scene",
	"group": "Runtime",
})
```

`push_watch_value()` 是项目观察值的唯一入口。调用方应在自己的帧循环、状态变更信号或低频采样点发布当前值；Overlay 只读取缓存，因此展开面板、刷新 GUI 或导出快照不会执行项目代码。单个值受 `max_value_collection_items` 和 `max_value_snapshot_nodes` 限制，发布失败不会写入部分结果。

注册了 `GFDiagnosticsUtility` 时，Overlay 默认也会显示 `overlay` 诊断监控预设，可用 `set_diagnostics_monitor_preset()` 切换预设，或把 `include_diagnostics_monitors` 设为 `false` 只显示手动 watch。

Watch 只是一层当前值显示通道，不保存历史，也不规定业务字段。需要开发期短期趋势时可使用 `record_metric_sample()` 或直接注册 `GFMetricSeries`；需要长期记录请接入 `GFLogUtility` / `GFDiagnosticsUtility` 或项目自己的分析系统。

正常运行中，Overlay 所属 GUI 在 `dispose()` 时会立即从场景树移除，避免调试层在架构销毁同一帧继续残留。Gf AutoLoad 正在执行 `_exit_tree()` 的同步释放作用域时不会重入修改父节点，而是禁用回调并登记延迟释放，由当前拆树流程收束节点。

## 面板

需要显示多行结构化内容时，使用 `push_panel_content()` 主动发布字符串、数组或字典，或使用 `push_panel_text()` 发布已经格式化的文本。结构化内容会在发布时编码成有界只读文本，最终文本受 `max_panel_content_chars` 限制；`include_recent_logs` 开启时还会附加最近日志面板。

面板同样不做脱敏，适合开发期聚合 `GFDiagnosticsUtility` 快照、项目局部状态或自定义工具输出。

## 短期指标趋势

`GFMetricSeries` 是 Overlay 的轻量短期采样容器，用于观察 FPS、帧耗时、对象数量、队列长度等开发期趋势。它只保留固定数量的数值采样，并提供最新值、最小值、最大值、平均值和 ASCII sparkline；它不是日志系统，也不会替项目上报遥测。

```gdscript
debug.record_metric_sample(&"fps", Engine.get_frames_per_second(), {
	"label": "FPS",
	"group": "Runtime",
	"max_samples": 120,
})
```

`include_metric_series_panel` 默认开启，会把已注册的可见指标序列附加到 Overlay 面板区。项目也可以创建并维护自己的 `GFMetricSeries`，再通过 `register_metric_series()` 交给 Overlay 展示。
