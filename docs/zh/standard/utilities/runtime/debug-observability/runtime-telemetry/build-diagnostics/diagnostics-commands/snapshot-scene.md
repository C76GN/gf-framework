# 快照与场景树诊断

`GFDiagnosticsUtility` 可以采集运行时快照，并通过内置命令读取性能、工具状态和场景树摘要。

```gdscript
var utility_value: Variant = Gf.get_utility(GFDiagnosticsUtility)
if not (utility_value is GFDiagnosticsUtility):
	return
var diagnostics: GFDiagnosticsUtility = utility_value
var snapshot: Dictionary = diagnostics.collect_snapshot({
	"recent_log_count": 10,
})
var performance: Dictionary = diagnostics.execute_command(&"diagnostics.performance")
var tools: Dictionary = diagnostics.execute_command(&"diagnostics.tools")
```

`collect_snapshot()` 是进程内 native snapshot，框架内置采样可以保留 Vector、Color、Resource 摘要所需的 Godot Variant。外部工具、分区和 monitor 必须在采集前通过发布式 API 写入有界的 report-safe 缓存；普通采集只读缓存，不执行项目回调，owner 释放后的缓存会被剪枝。只有调用方显式传入非空 `diagnostic_provider_ids` 时，才会执行对应的[惰性诊断 Provider](lazy-providers.md)。把完整快照发送到 Debugger、写入 JSON 或并入支持报告前，仍应使用 `GFReportValueCodec` 应用最终导出与隐私策略，而不是直接依赖 `JSON.stringify()` 的隐式转换。

## 场景树快照

需要在运行时查看当前场景结构时，可显式采集只读场景树快照。它只记录节点名、类型、路径、可选脚本路径和子节点摘要，不读取任意属性、不调用业务方法，也不修改节点。

```gdscript
var scene: Dictionary = diagnostics.execute_command(&"diagnostics.scene", {
	"max_depth": 3,
	"max_nodes": 128,
	"include_groups": true,
})

var snapshot_with_scene: Dictionary = diagnostics.collect_snapshot({
	"include_scene_tree": true,
	"scene_tree_options": {
		"max_depth": 2,
	},
})
```

场景树快照适合编辑器诊断、支持报告和测试断言。它不是运行时对象查询 API，不应作为业务逻辑分支条件。
