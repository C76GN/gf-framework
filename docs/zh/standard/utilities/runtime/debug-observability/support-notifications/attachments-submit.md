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

`include_screenshot` 可把当前 Viewport 截图作为普通附件加入报告，`screenshot_path` 可额外把截图写到本地路径。截图捕获复用 [GFScreenshotUtility](../debug-visual-inspection/screenshots.md)，需要批量尺寸、语言或项目自定义路径策略时可以直接使用该工具。默认 `default_max_attachment_bytes` 会限制单个附件大小，避免支持报告在玩家入口无限膨胀。Markdown 导出只输出附件摘要，不内联附件正文或二进制内容。

## 提交流程

如果需要上传或进入项目自己的客服/反馈管线，使用 `submit_report(report, transport, options)`。`transport` 会收到报告字典副本和提交选项；它可以写文件、排队、发 HTTP 请求或交给平台 SDK，但这些实现都留在项目层。

提交返回值会归一化为 `ok`、`value`、`error`、`metadata` 和 `submitted_at_unix`，便于 UI 或日志统一处理。面对玩家可见入口时，应在项目层过滤敏感字段、限制附件大小，并决定是否允许 `include_screenshot`。
