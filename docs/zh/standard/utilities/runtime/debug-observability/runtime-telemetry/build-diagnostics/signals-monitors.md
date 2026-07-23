# 信号图、工具快照与监控预设

诊断快照的 `tools` 字段会聚合基础工具快照和外部模块已经发布的缓存快照。诊断 core 只内置构建信息、计时器、对象池和操作统计等框架采样；资产加载、下载、远端缓存、可选扩展或项目系统需要进入同一份诊断快照时，应在自身状态变化或受控刷新点主动发布。

标准库其他工具、GF 内置扩展或项目模块如果也想进入诊断快照，应调用 `publish_tool_snapshot()`、`publish_snapshot_section()`、`register_monitor()` / `publish_monitor_sample()` 或 `register_command()` 贡献数据。

例如 ActionQueue 扩展贡献 `tools.action_queue` 监控和 `tools.action_queue` 快照，Network 扩展贡献 `network` 快照分区。`GFDiagnosticsUtility` 不硬编码任何 GF 内置扩展 ID、路径或类型，因此扩展禁用或删除时不会影响标准库加载。

## 信号图

编辑器侧的 `GFSceneSignalAudit.build_signal_graph()` / `index_signal_graph()` 可把运行中节点树的信号、连接、节点索引整理为结构化数据；需要隐藏根节点外的目标时可传入 `include_external_targets = false`，需要只返回参与当前信号图的节点时可传入 `participating_nodes_only = true`。

`GFSignalGraphDock` 则把当前编辑场景渲染为 `GF Workspace > 信号诊断` 页面，默认查看保存连接、过滤编辑器外部目标，并让节点统计聚焦实际参与连接的节点，方便查看 source、signal、target 和 method。

`collect_signal_graph_snapshot()` 与内置命令 `diagnostics.signals` 会对当前场景根或传入根节点生成只读信号图；`collect_snapshot({ "include_signal_graph": true })` 可把它合并进完整诊断快照。它不会连接、断开或触发信号，只读取节点、信号和连接摘要。

## 监控预设

诊断监控项适合给 Overlay、编辑器面板或远程调试工具提供稳定采样入口。内置预设包括 `minimal`、`performance`、`architecture`、`tools` 与 `overlay`。

编辑器中的 `GFDiagnosticsDock` 渲染 `GF Workspace > Diagnostics` 页面，可直接采集这些预设、通用性能数据、工具快照和可选场景树摘要，便于开发期只读排查。

项目也可以注册自己的监控元数据，在已有刷新点发布采样，并按预设导出 JSON、文本或 CSV：

```gdscript
diagnostics.register_monitor(self, &"runtime.enemy_count", {
	"label": "Enemies",
	"group": "Runtime",
})
diagnostics.publish_monitor_sample(self, &"runtime.enemy_count", enemies.size())
diagnostics.register_monitor_preset(&"runtime", PackedStringArray(["runtime.enemy_count"]))
diagnostics.publish_tool_snapshot(self, &"runtime", {
	"enemy_count": enemies.size(),
})

var monitor_snapshot: Dictionary = diagnostics.collect_monitor_preset(&"runtime")
var text: String = diagnostics.export_monitor_snapshot(monitor_snapshot, &"text")
```

快照默认可包含构建信息、最近日志、外部贡献分区、工具状态和项目自定义 monitor 输出。这些快照只表达版本、队列、缓存、pending 数量和运行状态，不解释项目业务含义。

## 发布边界

外部分区和工具快照必须通过 `publish_snapshot_section()` / `publish_tool_snapshot()` 提交 `Dictionary`。监控值则先用 `register_monitor()` 声明 owner 和显示元数据，再用 `publish_monitor_sample()` 更新。发布时会检查 `max_contribution_collection_items`、`max_contribution_nodes`、`max_contribution_depth` 和 `max_contribution_bytes`，并立即转换为 report-safe 缓存；无效或超预算的新值会被拒绝，监控项继续保留上一份有效采样。

为兼容既有集成，项目仍可发布名为 `diagnostic_providers` 的自定义分区。普通 `collect_snapshot()` 会返回这份缓存；只有调用方显式提交非空 `diagnostic_provider_ids` 时，当次快照的同名顶层键才由内置惰性 Provider 批次结果占用。这个临时覆盖不会注销自定义分区，后续普通快照仍会返回原缓存。

同名贡献只允许当前 owner 更新或移除，owner 释放后会自动剪枝。`collect_snapshot()` 和 Overlay 刷新只读取缓存，不执行外部 `Callable`，因此观察行为不能重入业务逻辑或阻塞诊断 UI。框架内置采样仍可保留进程内 native Variant；把完整快照写入文件、Debugger 通道或支持报告时，继续通过 `GFReportValueCodec` 处理最终导出策略。
