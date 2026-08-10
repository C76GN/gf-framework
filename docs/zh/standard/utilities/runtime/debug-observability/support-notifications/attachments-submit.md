# 附件与提交

附件可通过 `attachments` 传入文本、字节或带 `text` / `bytes` / `path` 字段的字典。`collect_attachments()` 与 `add_attachment_to_report()` 会统一写出 `ok`、`filename`、`mime_type`、`size_bytes`、`encoding`、`data` 和 `metadata`。

```gdscript
var report := reports.build_report("设置界面打开后无法返回", {
	"attachments": {
		"local_log": {
			"text": recent_log_text,
			"filename": "recent_log.txt",
			"mime_type": "text/plain",
		},
	},
	"max_attachment_bytes": 512 * 1024,
})
```

`include_screenshot` 可把当前 Viewport 截图作为普通附件加入报告，`screenshot_path` 可额外把截图写到本地路径。截图捕获复用 [GFScreenshotUtility](../debug-visual-inspection/screenshots.md)，需要批量尺寸、语言或项目自定义路径策略时可以直接使用该工具。默认 `default_max_attachment_bytes` 会限制单个附件大小，避免支持报告在玩家入口无限膨胀；当前非正值仍表示关闭该显示级限制，而且尚无不可关闭的报告总字节上限，因此只能由受信内部工具使用，不能把调用方可控预算直接暴露给玩家或插件。Markdown 导出只输出附件摘要，不内联附件正文或二进制内容。

路径附件和可选输出路径都会先做词法根边界检查，并拒绝 `DirAccess` 能识别的链接组件；保存结果中的绝对目录会脱敏为 `<redacted_path>`，仅额外返回 `saved_filename`。这些 GDScript 检查不能承诺覆盖所有 Windows reparse 类型，也不能把检查与文件打开绑定成同一个原子操作；不可信本机对手模型需要项目独占暂存区或原生 no-follow/句柄身份适配。

## 提交流程

如果需要上传或进入项目自己的客服/反馈管线，使用 `submit_report(report, transport, options)`。`transport` 会收到报告字典副本和提交选项。它是受信同步 hook：必须准确接受两个参数并直接返回，不能依赖 GF 抢占阻塞、捕获脚本错误或等待异步结果。推荐让它只把请求交给项目自己的有界队列；写文件、HTTP 和平台 SDK 工作由队列消费者执行。

提交返回值会归一化为 `ok`、`value`、`error`、`metadata` 和 `submitted_at_unix`，便于 UI 或日志统一处理。legacy 契约把任意不带显式 `ok = false` 的返回值（包括 `null`）视为成功值。面对玩家可见入口时，应在项目层过滤敏感字段、限制附件大小，并决定是否允许 `include_screenshot`。
