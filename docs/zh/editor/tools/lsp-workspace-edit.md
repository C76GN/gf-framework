# LSP WorkspaceEdit 安全提交工具包

`gf.tool.lsp_workspace_edit` 把调用方已经取得的 LSP `WorkspaceEdit` 收敛为“先计划、后提交”的项目脚本写入协议。它解决的是编辑器工具在拿到完整文本修改后，如何复核坐标、目标、版本和磁盘来源并交给统一文件事务；它不负责连接语言服务器，也不负责决定应该重命名哪个符号。

公开入口 `GFLspWorkspaceEditAdapter` 负责构建和提交计划；一次性值对象 `GFLspWorkspaceEditPlan` 只暴露不含源码正文的审查报告与终态。

核心不变量是：只有经过审查的同一份计划，才能覆盖仍处于同一已保存状态的同一批脚本。工具因此把工作区 URI 与调用方版本、文档 URI 与版本、磁盘来源 SHA-256、结果 SHA-256、位置编码和资源预算一起绑定进 `plan_sha256`。

## 能力边界

适配器只接受以下边界：

- 顶层只有 `documentChanges`，每项都是带 `textDocument.version` 的 `TextDocumentEdit`。
- 每个 edit 只有 `range` 和 `newText`，位置使用明确的 `utf-8` 或 `utf-16` 编码。
- 目标是当前 `res://` 内已存在、未经过符号链接或 Windows reparse point 的 portable `.gd` 文件；`workspace_uri` 和目标的规范宿主绝对路径必须与当前项目路径逐字符一致，错误大小写不会被宿主文件系统的宽松查找视为同一授权路径。
- 调用方提供的 `workspace_snapshot.documents` 与目标集合完全一致，每个目标都有 `saved = true`、版本和来源 SHA-256。
- 文件数、每文件 edit 数、单文件字节、总字节和 WorkspaceEdit 字节均受显式预算约束。

下列内容会失败关闭：

- 无版本的 `changes` 形态，以及任何未知字段或错误字段类型；
- create、rename、delete 等文件资源操作；
- 项目外 URI、非 `file://` URI、URI authority、查询、fragment、dot segment、编码分隔符和非法 percent escape；
- 宿主绝对路径大小写不精确的工作区或目标，以及重复目标或在大小写不敏感 portable identity 下碰撞的目标；portable identity 只用于碰撞检测和稳定排序，不参与授权或 containment；
- 未保存目标、版本不一致、来源摘要不一致、非严格 UTF-8 或带 BOM 的来源；
- 越界坐标、落在 UTF-8 多字节序列或 UTF-16 surrogate pair 内部的坐标，以及重叠或同点顺序不明的 edits；
- 超预算输入、结果或事务备份。

该闭合契约有意不兼容更宽松的 WorkspaceEdit 解释。上游若需要文件创建、跨文件重命名规划或未保存缓冲区支持，应先在拥有完整编辑器/LSP 状态的项目工具中解决，再把可证明为已保存纯文本修改的子集交给本适配器；不要在适配器里猜测缺失语义。

## 两阶段用法

调用方应在取得 WorkspaceEdit 时采集一次状态用于计划，在真正提交前重新采集一次状态。`workspace_version` 是调用方维护的工作区世代号；它应在会让整批计划失效的项目重载、工作区切换或批量状态变化时递增。文档 `version` 则应来自生成 WorkspaceEdit 的同一文本文档状态。

```gdscript
var workspace_edit: Dictionary = lsp_result_workspace_edit
var reviewed_snapshot: Dictionary = {
	"workspace_uri": current_project_file_uri,
	"workspace_version": current_workspace_generation,
	"documents": [{
		"uri": target_file_uri,
		"version": target_document_version,
		"saved": true,
		"source_sha256": FileAccess.get_sha256("res://features/player/player.gd"),
	}],
}

var plan: GFLspWorkspaceEditPlan = GFLspWorkspaceEditAdapter.build_plan(
	workspace_edit,
	reviewed_snapshot,
	{
		"position_encoding": GFLspWorkspaceEditAdapter.POSITION_ENCODING_UTF16,
		"max_file_count": 32,
		"max_edits_per_file": 512,
		"max_file_bytes": 2 * 1024 * 1024,
		"max_total_bytes": 16 * 1024 * 1024,
		"max_workspace_edit_bytes": 4 * 1024 * 1024,
	}
)
if not plan.is_valid():
	push_error(JSON.stringify(plan.get_report(), "\t"))
	return

# 在展示并确认 plan.get_report() 后，重新采集而不是复用旧快照。
var commit_snapshot: Dictionary = collect_current_saved_workspace_snapshot()
var commit_report: Dictionary = GFLspWorkspaceEditAdapter.commit_plan(
	plan,
	commit_snapshot
)
if not commit_report.ok:
	if commit_report.recovery_required:
		persist_recovery_handle_for_operator(commit_report)
	push_error(JSON.stringify(commit_report, "\t"))
```

`get_report()` 只公开目标资源路径、URI、版本、edit 数、字节数和前后摘要，不公开待写入源码正文。`plan_sha256` 绑定的内部计划包含结果文本，但调用方拿到的是隔离值对象，不能把报告改写成另一份提交。

计划在进入底层文件事务前保持可重试：如果提交快照过时或磁盘来源漂移，提交失败且计划不被消费。所有复核通过后，计划先被一次性认领，再把计划中的来源 SHA-256 作为 `expected_existing_sha256`、结果 SHA-256 作为 `expected_sha256` 交给 `GFArtifactWriteTransaction`。底层事务会在预检和每个实际替换边界再次比较旧内容，freshness 复核后的协作式并发写入也不会被覆盖；无论底层事务成功还是失败，同一计划都不能再次提交。

## 位置编码

`position_encoding` 必须与产生 WorkspaceEdit 的 LSP 会话协商结果一致：

- `utf-8` 的 `character` 是当前行起点后的 UTF-8 字节数；
- `utf-16` 的 `character` 是当前行起点后的 UTF-16 code unit 数，非 BMP code point 占两个单位。

适配器按需为每个被引用行构建一次 UTF-8 或 UTF-16 累计 code-point 边界表，后续坐标通过二分精确命中 Godot `String` 字符索引；不会为同一行的每个 edit 重扫整行，也不会把 surrogate pair 或 UTF-8 序列中间的偏移静默吸附到相邻字符。来源扫描受 `max_file_bytes` 限制，坐标查询数受 `max_edits_per_file` 限制，文档数量超出 `max_file_count` 时在解析条目前立即失败。换算后继续复用 `GFSourceTextPatchTools` 的范围、重叠和单次组装语义。

## 事务、恢复与编辑器重载

提交复用 `GFArtifactWriteTransaction`，并固定 `allowed_roots = ["res://"]`、`overwrite_existing = true` 和 `scan_filesystem = false`。多目标会先完整预检和 staging，替换失败时由底层事务逆序补偿。

若提交报告返回 `recovery_required = true`，调用方必须保留 `recovery_transaction`，并按 `recovery_action` 原样交给 `GFArtifactWriteTransaction.rollback()` 或 `complete()`。恢复未终结前不要重跑同一重构、扫描文件系统或用另一批写入覆盖现场。

适配器不会自动调用 `EditorFileSystem.scan()`、重载脚本或处理编辑器中的未保存缓冲区。调用方只能在事务已完整终结后，根据自己的编辑器生命周期决定是否扫描、重新打开文件或提示用户；这类行为不能被隐藏在通用写适配器中。

## 诚实限制

该工具不是完整 rename 引擎，也不是 LSP client、编辑器 UI、语义验证器或安全沙箱。它不会证明 WorkspaceEdit 的业务意图正确，也不会解析结果脚本来保证语法或类型正确；调用方仍应在提交后运行相应诊断与测试。

GDScript 文件 API 无法固定父目录 handle。适配器会在计划和提交阶段拒绝可观察到的链接，以精确规范宿主路径复核工作区 containment，并把来源/结果摘要作为底层 compare-and-exchange 前置条件；底层事务也会在替换前复核可观察路径、旧内容与 sidecar 状态。但本机恶意进程仍可能在这些路径调用之间交换目录或文件，因此该机制适用于受信工作区和协作式并发，不承诺封死敌对目录 TOCTOU。多文件提交提供运行期补偿，不承诺断电、进程终止或文件系统故障下的 crash atomicity。
