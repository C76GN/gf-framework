# 支持报告

`GFSupportReportUtility` 用于把用户描述、项目元数据、构建信息、按精度控制的运行时信息、`GFDiagnosticsUtility` 快照和项目自定义分区聚合成一个普通字典。它可以导出 JSON、写入本地文件，也可以通过项目传入的 `Callable` 提交给任意自有流程；GF 不内置上传地址、工单系统或玩家反馈 UI。

默认报告遵循最小采集原则：`runtime` 只使用 `RuntimeDetail.MINIMAL` 保留平台信息，场景、诊断、自定义分区和截图都不会自动采集。项目应在展示预览并取得适当许可后，按问题类型显式增加所需数据，而不是先生成完整报告再尝试删除字段。

```gdscript
var reports := Gf.get_utility(GFSupportReportUtility) as GFSupportReportUtility
reports.register_section(&"save_slot", func(_options: Dictionary) -> Dictionary:
	return {
		"slot_id": current_slot_id,
		"checkpoint": current_checkpoint_id,
	}
)

var report := reports.build_report("设置界面打开后无法返回", {
	"metadata": {
		"screen": "settings",
	},
	"tags": ["ui", "runtime"],
	"runtime_detail": GFSupportReportUtility.RuntimeDetail.COARSE,
	"include_diagnostics": true,
	"include_scene": true,
	"include_sections": true,
	"scene_options": {
		"max_depth": 64,
		"max_nodes": 10000,
	},
})
reports.save_report(report, "user://support/report_latest.json")
var markdown_summary := reports.export_report_markdown(report, {
	"title": "Support Report",
})
```

运行时快照分为三档：

- `MINIMAL`：只包含 `detail` 和 `platform`，适合默认玩家反馈入口。
- `COARSE`：增加语言代码，以及处理器数量、静态内存和对象数量的范围；范围不能还原为精确计数，适合定位设备档位或运行规模差异。
- `FULL`：包含完整 locale、Engine 信息和精确计数，只应在内部 QA、开发构建或用户明确同意的诊断流程中启用。

`collect_runtime_snapshot(detail)` 可在真正构建报告前生成预览。完全不需要运行时信息时传入 `include_runtime = false`；需要项目自定义分区时传入 `include_sections = true`。已注册分区不会因为“存在”就自动进入报告，避免存档槽位、账号状态或项目诊断数据被意外带入。

场景快照只记录当前场景名称、路径和节点数量，节点数量统计默认限制深度与节点数；被截断时 `scene.node_count_truncated` 为 `true`。`export_report_json()` 适合自动化传输和持久化；`export_report_markdown()` 适合把同一份报告摘要贴进 Issue、PR、客服工单或测试记录。

`save_report()` 先写同目录临时文件并 flush，再原子替换目标文件；写入中断不会先破坏已有报告。路径附件默认拒绝，只有 `allow_path_attachments = true` 且路径位于 `allowed_attachment_roots` 时才会探测和读取文件，避免权限拒绝前泄露文件是否存在。附件保存同样受 `allowed_output_roots` 和字节上限约束。

## 工作流与离线重放

需要把“构建报告、尝试提交、失败后排队、稍后重放”作为同一条流程复用时，可以组合 `GFSupportReportWorkflow`。它内部仍使用 `GFSupportReportUtility` 构建报告，并把离线请求交给 `GFRequestOutboxUtility`；上传地址、鉴权、玩家确认、隐私脱敏和重试窗口仍由项目层决定。

```gdscript
var workflow := GFSupportReportWorkflow.new()
workflow.setup(reports, request_outbox)
workflow.set_session_metadata({
	"session_id": session_id,
})
workflow.set_transport(func(report: Dictionary, options: Dictionary) -> Dictionary:
	return submit_support_payload(report, options)
)

var result := workflow.submit_report("读档失败", {
	"metadata": {
		"screen": "load_game",
	},
	"transport_options": {
		"priority": "normal",
	},
})

if result["status"] == &"queued":
	print("报告已进入离线队列")
```

`request_url` 只是 outbox 中的逻辑端点，默认不表示真实 HTTP 地址。`transport_callback` 的建议签名是 `func(report: Dictionary, options: Dictionary) -> Variant`，项目可在里面调用 HTTP、平台 SDK、本地文件或测试替身。`replay_queued()` 会把 outbox 中保存的报告重新交给同一个 transport；因此不要把账号 token、用户隐私许可或临时 UI 状态写死在 workflow 中，应该在 transport 或项目会话层动态处理。
