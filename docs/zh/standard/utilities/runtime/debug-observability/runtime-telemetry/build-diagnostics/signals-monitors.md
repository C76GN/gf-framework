# 信号图、工具快照与监控预设

诊断快照的 `tools` 字段会聚合已注册模块公开的 `get_debug_snapshot()`。标准库内置读取 `GFBuildInfoUtility`、`GFAssetUtility`、`GFTimerUtility`、`GFRemoteCacheUtility`、`GFDownloadUtility`、`GFObjectPoolUtility` 和 `GFOperationDiagnosticsUtility`。

GF 内置扩展或项目模块如果也想进入诊断快照，应主动调用 `register_tool_snapshot_provider()`、`register_snapshot_section_provider()`、`register_monitor()` 或 `register_command()` 贡献数据。

例如 ActionQueue 扩展贡献 `tools.action_queue` 监控和 `tools.action_queue` 快照，Network 扩展贡献 `network` 快照分区。`GFDiagnosticsUtility` 不硬编码任何 GF 内置扩展 ID、路径或类型，因此扩展禁用或删除时不会影响标准库加载。

## 信号图

编辑器侧的 `GFSceneSignalAudit.build_signal_graph()` / `index_signal_graph()` 可把运行中节点树的信号、连接、节点索引整理为结构化数据；需要隐藏根节点外的目标时可传入 `include_external_targets = false`，需要只返回参与当前信号图的节点时可传入 `participating_nodes_only = true`。

`GFSignalGraphDock` 则把当前编辑场景渲染为 `GF Workspace > 信号诊断` 页面，默认查看保存连接、过滤编辑器外部目标，并让节点统计聚焦实际参与连接的节点，方便查看 source、signal、target 和 method。

`collect_signal_graph_snapshot()` 与内置命令 `diagnostics.signals` 会对当前场景根或传入根节点生成只读信号图；`collect_snapshot({ "include_signal_graph": true })` 可把它合并进完整诊断快照。它不会连接、断开或触发信号，只读取节点、信号和连接摘要。

## 监控预设

诊断监控项适合给 Overlay、编辑器面板或远程调试工具提供稳定采样入口。内置预设包括 `minimal`、`performance`、`architecture`、`tools` 与 `overlay`。

编辑器中的 `GFDiagnosticsDock` 渲染 `GF Workspace > Diagnostics` 页面，可直接采集这些预设、通用性能数据、工具快照和可选场景树摘要，便于开发期只读排查。

项目也可以注册自己的轻量 provider，并按预设导出 JSON、文本或 CSV：

```gdscript
var enemy_count_provider := func() -> int:
	return enemies.size()

diagnostics.register_monitor(&"runtime.enemy_count", enemy_count_provider, {
	"label": "Enemies",
	"group": "Runtime",
})
diagnostics.register_monitor_preset(&"runtime", PackedStringArray(["runtime.enemy_count"]))
diagnostics.register_tool_snapshot_provider(&"runtime", func() -> Dictionary:
	return { "enemy_count": enemies.size() }
)

var monitor_snapshot := diagnostics.collect_monitor_preset(&"runtime")
var text := diagnostics.export_monitor_snapshot(monitor_snapshot, &"text")
```

快照默认可包含构建信息、最近日志、外部贡献分区、URL 派生的缓存状态、工具路径和项目自定义 monitor 输出。这些快照只表达版本、队列、缓存、pending 数量和运行状态，不解释项目业务含义。
