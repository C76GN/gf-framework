# 信号诊断与运行时信号探针

编辑器侧的 `GFSceneSignalAudit.build_signal_graph()` / `index_signal_graph()` 可把当前节点树的信号、连接和节点索引整理为结构化数据；需要隐藏根节点外的目标时可传入 `include_external_targets = false`，需要让 `nodes` 只保留参与当前信号图的来源和目标节点时可传入 `participating_nodes_only = true`。

信号图默认限制节点深度和节点数量，可通过 `max_node_depth` / `max_nodes` 调整，截断时报告会标记 `truncated`。

`GFSignalGraphDock` 会把当前编辑场景渲染为 `GF Workspace > 信号诊断` 页面，默认查看场景文件中保存的信号连接、过滤编辑器外部目标，并让节点统计聚焦在实际参与连接的节点上，方便查看 source、signal、target 和 method。

勾选“未连接信号”可以列出节点声明过但还没有连接目标的信号；勾选“追踪发射”后，面板会按连接页当前可见信号建立监听，优先追踪保存连接里的信号，避免 `draw` 这类高频内建信号刷屏。

## 运行时探针

如果要确认“信号有没有真的发射”，可以显式创建 `GFSignalRuntimeProbe` 监听一个节点或节点树。它会记录最近事件、发射时间、来源节点、信号名、参数和当前连接摘要。

单个信号最多追踪 16 个参数，超过上限的极少数自定义信号应在项目层自行封装 payload。参数快照还同时受 `max_container_items`、`max_snapshot_nodes` 和 `max_snapshot_bytes` 限制，宽而浅的大容器也会输出截断 marker，而不是只依赖递归深度。它只在项目主动 watch 后工作，不会默认全局接管所有信号：

```gdscript
var probe := GFSignalRuntimeProbe.new()
probe.max_events = 200
probe.signal_emitted.connect(func(event: Dictionary) -> void:
	print(event["source_node_path"], event["signal_name"], event["arguments"])
)

probe.watch_tree(get_tree().current_scene, {
	"recursive": true,
	"include_signals": PackedStringArray(["pressed", "timeout"]),
	"max_node_depth": 64,
	"max_nodes": 4096,
})
```

`GFSignalGraphDock` 的“发射记录”页也是基于这个探针，只有打开“追踪发射”后才会连接当前场景信号。它记录的是开启追踪之后发生的事件，不会回放旧信号；编辑器工作区也不会自动抓取独立运行的游戏进程。

运行时事件只追加到发射记录，不会在每次信号触发时重新构建完整连接树；场景连接结构只在结构刷新点重建，避免高频信号把编辑器 UI 放大成全树重绘。

节点树监听默认带深度和数量上限，避免误选整个大型场景树时把所有信号都连上。不要在生产构建默认开启全场景探针；面对远程调试、玩家可见工具或包含敏感参数的信号时，应由项目层限制范围、脱敏和权限。
