# 通用文件下载队列

这一页说明 `GFDownloadUtility` 如何下载远程文件、写入临时文件、提交目标文件，并处理续传、校验、暂停、取消和重试。

## 单文件队列

`GFDownloadUtility` 面向补丁包、远程资源包、配置包或编辑器工具下载这类“写入本地文件”的通用流程。它和 `GFRemoteCacheUtility` 的边界不同：前者负责文件落盘、临时文件提交、可选续传、SHA-256 校验、暂停和取消；后者只负责轻量文本/JSON 请求和 TTL 缓存。

```gdscript
var downloads := Gf.get_utility(GFDownloadUtility) as GFDownloadUtility

downloads.enqueue_download(
	"https://example.com/catalog.zip",
	"user://catalog.zip",
	func(result: Dictionary) -> void:
		if bool(result["success"]):
			print("downloaded: ", result["target_path"])
	,
	{
		"resume": true,
		"expected_sha256": "",
		"max_retries": 2,
		"retry_delay_seconds": 0.5,
	}
)
```

`enqueue_download()` 返回任务 ID；`cancel(id, delete_temp)` 可取消等待中或进行中的任务，`pause()` / `resume()` 会暂停启动新任务并把当前任务保留到队首。每个任务由 `GFDownloadTask` 描述，结果字典会包含 `status`、`status_name`、`received_bytes`、`total_bytes`、`response_code`、`error`、`retry_count` 和项目传入的 `metadata`。下载成功后先写入临时文件，再提交到目标路径；覆盖已有目标时会先把旧文件移动到同目录恢复 sidecar，候选提交失败则恢复旧目标，进程在替换窗口中断时下一次同路径提交也会先恢复 sidecar。成功提交后才清理备份。如果启用 `resume` 且临时文件存在，会追加 `Range` 请求头并在服务器返回 `206` 时合并分段文件；分段读取或写入失败会回滚到合并前的临时文件长度，不提交部分内容。`get_debug_snapshot()` 可被 `GFDiagnosticsUtility` 聚合到运行时工具快照中。

临时文件和续传分段文件由 utility 根据规范化后的 `target_path` 独占派生，调用方不能覆盖 `temp_path` 或 `segment_path`。因此取消清理只会删除当前任务拥有的 sidecar，不会接受同 scheme 下任意路径并误删无关文件。

## 清单批量下载

下载列表来自远程 manifest、补丁目录或项目侧资源索引时，可先用 `parse_manifest_entries()` 把数组、JSON 字符串，或包含 `files` / `entries` / `downloads` 的字典解析为标准条目，再用 `enqueue_manifest()` 或 `enqueue_manifest_entries()` 批量加入同一个顺序下载队列。清单条目支持 `url`、`source`、`href`、`target_path`、`path`、`file`、`sha256` / `expected_sha256`、`size` / `expected_size`、`headers` 和 `metadata`；相对 URL 可通过 `base_url` 补全。`target_root` 必须是没有 `..` 的 `res://` 或 `user://` 根，条目目标必须是该根下的安全相对路径；清单中的绝对 `target_path` 即使自身是 `res://` / `user://` 也会被拒绝，不能绕过批次授权根。批量入队仍然复用 `enqueue_download()` 的临时文件、续传、校验、覆盖和重试语义，不引入额外线程池或资源包业务规则。

```gdscript
var ids := downloads.enqueue_manifest(
	{
		"base_url": "https://example.com/patches",
		"files": [
			{
				"path": "catalog.json",
				"size": 512,
			},
			{
				"url": "https://cdn.example.com/audio/bgm.ogg",
				"target_path": "audio/bgm.ogg",
				"sha256": "",
			},
		],
	},
	"user://patch-cache",
	Callable(),
	{
		"max_retries": 2,
		"metadata": {
			"batch": "patch-cache",
		},
	}
)

var progress := downloads.get_tasks_progress(ids)
print(progress["completed_count"], "/", progress["task_count"])
```

`get_task_snapshot(id)` 会按“当前任务、等待队列、最终结果”的顺序返回任务快照；`get_tasks_progress(ids)` 可聚合多个任务的完成数、失败数、取消数、字节数和 `progress_ratio`。如果清单提供 `size` / `expected_size`，已完成任务即使没有实时进度采样，也能用该值补足聚合进度。该字段只是进度提示，不是文件完整性声明，也不会单独阻止截断或超长响应；需要完整性保证时必须提供 `sha256` / `expected_sha256`，或在项目协议层验证签名清单。批量 API 只接受 `target_root` 下的安全相对目标；包含 `../`、绝对路径或任意 URI scheme 的条目目标会被跳过。

## 失败与缓存边界

如果下载面向不稳定网络，可以在任务选项中设置 `max_retries` 和 `retry_delay_seconds`。下载器只会重试传输失败、无响应码、`408`、`425`、`429` 或 `5xx` 这类通常可恢复的失败；`4xx` 权限、缺失资源、校验失败、提交失败等不会被盲目重试。重试期间不会发出最终完成/失败信号，只有任务最终成功、失败或取消时才写入结果。

当目标文件已存在且任务设置 `overwrite = false` 时，下载器不会直接把已有文件视为成功。如果任务提供了 `expected_sha256`，会先校验目标文件；校验通过才返回 `from_existing_file` 结果，校验失败则进入失败状态并保留原文件。未提供 checksum 时，已有目标文件仍按“不可覆盖的已完成文件”处理。
