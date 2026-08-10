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

`save_report()` 先写同目录临时文件并 flush，再原子替换目标文件；写入中断不会先破坏已有报告。替换成功后还会清理旧 backup；若这一步失败，目标文件已经提交，但方法返回对应非 `OK` 错误，且不会增加 clean-success 计数。当前 `Error` 返回类型不能同时表达“已提交”和“存在清理债务”，调用方遇到该错误时应先检查目标文件，不要直接把它当成未写入并盲目重试。

路径附件默认拒绝，只有 `allow_path_attachments = true` 且路径位于 `allowed_attachment_roots` 时才会探测和读取文件，避免权限拒绝前泄露文件是否存在。读取路径和附件的可选输出路径都会拒绝 `DirAccess` 能识别的链接组件；本机绝对输出路径不会写回可上传报告，只保留 `<redacted_path>` 与无目录文件名。这里的检查仍不是跨平台、抗并发替换的文件句柄安全边界：敌对本地进程可能利用平台 reparse 类型或检查与打开之间的竞态。需要处理不可信本机对手时，应先把候选数据复制到项目独占的受信暂存区，或使用提供 no-follow/句柄身份校验的原生适配层。

自定义 section provider 是受信、同步 hook，必须准确接受一个 `Dictionary` 参数并直接返回结果。`submit_report()` transport 同样必须同步接受 `(report, options)`；当前实现不能抢占阻塞调用、捕获 GDScript 脚本错误或隔离错误参数个数。任意返回值（包括 `null`）仍是合法 legacy 成功值，只有返回带 `ok = false` 的字典才形成结构化失败。慢 I/O、HTTP 或异步 SDK 应由项目先放入自己的有界队列，再让 hook 只完成同步交接。

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

`request_url` 只是 outbox 中的逻辑端点，默认不表示真实 HTTP 地址。`transport_callback` 必须是签名为 `func(report: Dictionary, options: Dictionary) -> Variant` 的受信同步交接 hook；项目可在里面调用不会阻塞的内存队列或测试替身，网络、平台 SDK 与文件 I/O 应由队列消费者异步完成。建议为 Support Report 使用独立的 `GFRequestOutboxUtility` 与 `storage_path`：Outbox 只有一个 transport/filter 入口，不同报告、Analytics、购买或云存档请求通常有不同隐私、许可和重放政策。

`setup(..., outbox)` / `set_transport()` 的自动装配只会在 Outbox 尚未设置有效 `transport_callback` 时绑定 workflow 的内部路由，不会覆盖项目已有 transport。切换 Outbox、清空 transport、关闭自动装配或 `dispose()` 时，workflow 只解除仍由自己安装的绑定，不会清除项目后来替换的 transport。共享 Outbox 已有项目 transport 时，项目路由应先调用 `workflow.handles_request(envelope)`，只把匹配 Support Report 固定信封契约的请求交给 workflow；如果自动装配的内部路由收到非匹配请求，它会 fail closed，不调用 Support transport，请求按 Outbox 的重试/失败策略保留，而不会误把其他业务 body 当作报告发送。

`queue_report()` 只接受 `report_id` 为 String/StringName、长度 `1..4096` 且不含 C0 控制字符（U+0000..U+001F）或 DEL（U+007F）的报告；不合法的报告会在修改 Outbox 前失败。只有在 Outbox 完成持久化检查点、且 Outbox 自己的同步通知没有撤销该精确请求后，才返回 `status = "queued"`。随后发出的 `workflow_report_queued` 是耐久成功后的通知，参数都是隔离副本；监听器在通知中清理或重放 Outbox 属于下一项显式操作，不会反转已经完成的回执。失败结果的 `queue_result` 会保留 `reason`、`persisted` 和 `persistence_error`，不会把仅内存状态描述为离线交接成功。`max_attempts` 会钳制到 `1..64`。`replay_queued()` 会把 outbox 中保存的报告重新交给同一个 transport；若等待期间 workflow 被释放或替换 outbox，旧 continuation 返回 `workflow_lifecycle_changed`，不再递增计数或发完成信号。因此不要把账号 token、用户隐私许可或临时 UI 状态写死在 workflow 中，应该在 transport 或项目会话层动态处理。
