## GFLspWorkspaceEditAdapter: 调用方提供的闭合 LSP WorkspaceEdit 安全适配器。
##
## 该工具只把已完成的 `documentChanges` 文本编辑转换为一次性预检计划，并在
## 工作区、文档版本和磁盘来源摘要仍一致时通过 GFArtifactWriteTransaction 提交。
## 它不建立 LSP 连接、不请求 rename/code action、不处理 create/rename/delete
## 文件操作、不读取未保存缓冲区、不驱动 UI，也不触发编辑器文件系统扫描。
## 允许目标严格限定为当前 `res://` 内已存在且未经过链接的 portable `.gd` 文件。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFLspWorkspaceEditAdapter
extends RefCounted


# --- 常量 ---

## LSP UTF-8 position encoding 标识。
## [br]
## @api public
## [br]
## @since unreleased
const POSITION_ENCODING_UTF8: String = "utf-8"

## LSP UTF-16 position encoding 标识。
## [br]
## @api public
## [br]
## @since unreleased
const POSITION_ENCODING_UTF16: String = "utf-16"

const _FORMAT: String = "gf.lsp_workspace_edit.plan"
const _FORMAT_VERSION: int = 1
const _DEFAULT_MAX_FILE_COUNT: int = 64
const _DEFAULT_MAX_EDITS_PER_FILE: int = 1024
const _DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024
const _DEFAULT_MAX_TOTAL_BYTES: int = 32 * 1024 * 1024
const _DEFAULT_MAX_WORKSPACE_EDIT_BYTES: int = 8 * 1024 * 1024
const _ABSOLUTE_MAX_FILE_COUNT: int = 256
const _ABSOLUTE_MAX_EDITS_PER_FILE: int = 4096
const _ABSOLUTE_MAX_FILE_BYTES: int = 64 * 1024 * 1024
const _ABSOLUTE_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024
const _ABSOLUTE_MAX_WORKSPACE_EDIT_BYTES: int = 32 * 1024 * 1024
const _MAX_URI_BYTES: int = 16 * 1024
const _MAX_LSP_INTEGER: int = 2_147_483_647
const _PLAN_SCRIPT = preload(
	"res://addons/gf/tools/lsp_workspace_edit/gf_lsp_workspace_edit_plan.gd"
)
const _ARTIFACT_TRANSACTION_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd"
)
const _SOURCE_TEXT_PATCH_TOOLS_SCRIPT = preload(
	"res://addons/gf/standard/foundation/text/gf_source_text_patch_tools.gd"
)


# --- 私有变量 ---

static var _test_before_artifact_commit: Callable = Callable()
static var _test_track_position_line_scans: bool = false
static var _test_position_line_scan_counts: Dictionary = {}


# --- 公共方法 ---

## 预检调用方已经取得的闭合 WorkspaceEdit。
##
## 只接受带版本的 `documentChanges` / `TextDocumentEdit`，每个目标必须在
## workspace_snapshot 中恰好出现一次且 saved=true。计划阶段会读取严格 UTF-8
## 磁盘字节、精确换算 UTF-8 或 UTF-16 坐标、拒绝重叠并执行底层写事务预检，
## 但不会写文件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param workspace_edit: 调用方提供且已闭合的 LSP WorkspaceEdit。
## [br]
## @param workspace_snapshot: 调用方提供的工作区与已保存文档状态。
## [br]
## @param options: position encoding 与资源预算。
## [br]
## @return: 有效或带拒绝证据的 WorkspaceEdit 计划。
## [br]
## @schema workspace_edit: closed Dictionary，仅包含 documentChanges；每项仅包含 textDocument={uri:String,version:int} 和 edits；每个 edit 仅包含 range={start={line:int,character:int},end={line:int,character:int}} 与 newText:String。
## [br]
## @schema workspace_snapshot: closed Dictionary，仅包含 workspace_uri:String、workspace_version:int 和 documents:Array；每个 document 仅包含 uri:String、version:int、saved:bool、source_sha256:String，且 documents 必须与 edit 目标集合完全一致。
## [br]
## @schema options: closed Dictionary，必须包含 position_encoding=utf-8|utf-16；可包含 max_file_count、max_edits_per_file、max_file_bytes、max_total_bytes、max_workspace_edit_bytes，均为正整数且不得超过工具绝对上限。
## [br]
## @schema return: GFLspWorkspaceEditPlan；使用 get_report() 读取不含源码正文的 JSON-safe 证据。
static func build_plan(
	workspace_edit: Dictionary,
	workspace_snapshot: Dictionary,
	options: Dictionary = {}
) -> GFLspWorkspaceEditPlan:
	var option_report: Dictionary = _normalize_options(options)
	var option_issues: Array[Dictionary] = _get_issue_array(option_report)
	if not option_issues.is_empty():
		return _make_invalid_plan(option_issues)

	var snapshot_report: Dictionary = _normalize_workspace_snapshot(
		workspace_snapshot,
		option_report
	)
	var snapshot_issues: Array[Dictionary] = _get_issue_array(snapshot_report)
	if not snapshot_issues.is_empty():
		return _make_invalid_plan(snapshot_issues, snapshot_report, option_report)

	var edit_report: Dictionary = _normalize_workspace_edit(
		workspace_edit,
		snapshot_report,
		option_report
	)
	var edit_issues: Array[Dictionary] = _get_issue_array(edit_report)
	if not edit_issues.is_empty():
		return _make_invalid_plan(edit_issues, snapshot_report, option_report)

	var documents: Array[Dictionary] = _get_dictionary_array(edit_report, "documents")
	var entries: Array[Dictionary] = []
	for document: Dictionary in documents:
		entries.append(_ARTIFACT_TRANSACTION_SCRIPT.make_text_entry(
			GFVariantData.get_option_string(document, "path"),
			GFVariantData.get_option_string(document, "result_text"),
			{
				"overwrite": true,
				"expected_sha256": GFVariantData.get_option_string(
					document,
					"result_sha256"
				),
				"expected_existing_sha256": GFVariantData.get_option_string(
					document,
					"source_sha256"
				),
				"artifact_id": "lsp-workspace-edit",
			}
		))
	var transaction_options: Dictionary = _make_transaction_options(option_report)
	var preflight: Dictionary = _ARTIFACT_TRANSACTION_SCRIPT.get_preflight_report(
		entries,
		transaction_options
	)
	if not GFVariantData.get_option_bool(preflight, "ok"):
		var preflight_issues: Array[Dictionary] = []
		for message: String in GFVariantData.get_option_packed_string_array(
			preflight,
			"issues"
		):
			_append_issue(
				preflight_issues,
				&"artifact_preflight_failed",
				message
			)
		return _make_invalid_plan(
			preflight_issues,
			snapshot_report,
			option_report
		)

	var payload: Dictionary = {
		"format": _FORMAT,
		"format_version": _FORMAT_VERSION,
		"workspace_uri": GFVariantData.get_option_string(
			snapshot_report,
			"workspace_uri"
		),
		"workspace_root_sha256": GFVariantData.get_option_string(
			snapshot_report,
			"workspace_root_sha256"
		),
		"workspace_version": GFVariantData.get_option_int(
			snapshot_report,
			"workspace_version"
		),
		"position_encoding": GFVariantData.get_option_string(
			option_report,
			"position_encoding"
		),
		"budgets": _extract_budgets(option_report),
		"documents": documents,
	}
	var plan_sha256: String = _hash_canonical(payload)
	if not _is_sha256(plan_sha256):
		var hash_issues: Array[Dictionary] = []
		_append_issue(
			hash_issues,
			&"plan_hash_failed",
			"WorkspaceEdit plan SHA-256 could not be computed."
		)
		return _make_invalid_plan(hash_issues, snapshot_report, option_report)

	var public_documents: Array[Dictionary] = []
	for document: Dictionary in documents:
		public_documents.append(_make_public_document_report(document))
	var report: Dictionary = _make_plan_report(
		true,
		"ready",
		plan_sha256,
		snapshot_report,
		option_report,
		public_documents,
		[],
		GFVariantData.get_option_int(edit_report, "edit_count"),
		GFVariantData.get_option_int(edit_report, "changed_count"),
		GFVariantData.get_option_int(edit_report, "source_bytes"),
		GFVariantData.get_option_int(edit_report, "result_bytes")
	)
	var plan: GFLspWorkspaceEditPlan = _PLAN_SCRIPT.new()
	var initialized: bool = plan.initialize_for_adapter(
		true,
		plan_sha256,
		report,
		payload
	)
	if not initialized:
		var initialization_issues: Array[Dictionary] = []
		_append_issue(
			initialization_issues,
			&"plan_initialization_failed",
			"WorkspaceEdit plan could not be initialized."
		)
		return _make_invalid_plan(
			initialization_issues,
			snapshot_report,
			option_report
		)
	return plan


## 在绑定状态仍一致时一次性提交计划。
##
## 提交前会重新验证计划 SHA、当前工作区身份与版本、全部文档 saved/version/hash，
## 并重新读取磁盘严格 UTF-8 字节。通过后计划先被消费，再以 scan_filesystem=false
## 调用 GFArtifactWriteTransaction；失败报告会原样保留需要调用方处理的恢复句柄。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param plan: build_plan() 返回且尚未消费的计划。
## [br]
## @param workspace_snapshot: 提交瞬间由调用方重新采集的已保存工作区状态。
## [br]
## @return: 不含源码正文的闭合提交报告。
## [br]
## @schema workspace_snapshot: 与 build_plan() 的 workspace_snapshot 相同，且工作区身份/版本、目标集合、文档版本与来源 SHA-256 必须仍匹配计划。
## [br]
## @schema return: closed Dictionary，仅包含 ok、status、plan_sha256、written_count、unchanged_count、recovery_required、recovery_action、recovery_transaction、issues、artifact_report；recovery_required=true 时调用方必须按 recovery_action 将 recovery_transaction 原样交给 GFArtifactWriteTransaction.rollback() 或 complete()。
static func commit_plan(
	plan: GFLspWorkspaceEditPlan,
	workspace_snapshot: Dictionary
) -> Dictionary:
	if plan == null:
		return _make_commit_failure(
			"invalid_plan",
			"WorkspaceEdit plan is null."
		)
	if plan.is_consumed():
		return _make_commit_failure(
			"plan_consumed",
			"WorkspaceEdit plan has already been consumed.",
			plan.get_plan_sha256()
		)
	if not plan.is_valid():
		return _make_commit_failure(
			"invalid_plan",
			"WorkspaceEdit plan is not valid.",
			plan.get_plan_sha256()
		)

	var payload: Dictionary = plan.read_payload_for_adapter()
	var payload_report: Dictionary = _validate_plan_payload(payload)
	var payload_issues: Array[Dictionary] = _get_issue_array(payload_report)
	if not payload_issues.is_empty():
		return _make_commit_report(
			false,
			"invalid_plan",
			plan.get_plan_sha256(),
			payload_issues
		)
	var recalculated_sha256: String = _hash_canonical(payload)
	if (
		not _is_sha256(recalculated_sha256)
		or recalculated_sha256 != plan.get_plan_sha256()
	):
		return _make_commit_failure(
			"plan_hash_mismatch",
			"WorkspaceEdit plan payload no longer matches its SHA-256.",
			plan.get_plan_sha256()
		)

	var budgets: Dictionary = GFVariantData.get_option_dictionary(
		payload,
		"budgets"
	)
	var snapshot_report: Dictionary = _normalize_workspace_snapshot(
		workspace_snapshot,
		budgets
	)
	var snapshot_issues: Array[Dictionary] = _get_issue_array(snapshot_report)
	if not snapshot_issues.is_empty():
		return _make_commit_report(
			false,
			"snapshot_rejected",
			plan.get_plan_sha256(),
			snapshot_issues
		)
	var freshness_issues: Array[Dictionary] = _validate_fresh_state(
		payload,
		snapshot_report
	)
	if not freshness_issues.is_empty():
		return _make_commit_report(
			false,
			"stale_plan",
			plan.get_plan_sha256(),
			freshness_issues
		)

	if not plan.claim_for_adapter(recalculated_sha256):
		return _make_commit_failure(
			"plan_claim_failed",
			"WorkspaceEdit plan could not be claimed for one-shot commit.",
			plan.get_plan_sha256()
		)
	if _test_before_artifact_commit.is_valid():
		var before_artifact_commit: Callable = _test_before_artifact_commit
		_test_before_artifact_commit = Callable()
		var _test_hook_result: Variant = before_artifact_commit.call()

	var entries: Array[Dictionary] = []
	for document: Dictionary in _get_dictionary_array(payload, "documents"):
		entries.append(_ARTIFACT_TRANSACTION_SCRIPT.make_text_entry(
			GFVariantData.get_option_string(document, "path"),
			GFVariantData.get_option_string(document, "result_text"),
			{
				"overwrite": true,
				"expected_sha256": GFVariantData.get_option_string(
					document,
					"result_sha256"
				),
				"expected_existing_sha256": GFVariantData.get_option_string(
					document,
					"source_sha256"
				),
				"artifact_id": "lsp-workspace-edit",
			}
		))
	var artifact_report: Dictionary = _ARTIFACT_TRANSACTION_SCRIPT.commit(
		entries,
		_make_transaction_options(budgets)
	)
	var artifact_ok: bool = GFVariantData.get_option_bool(
		artifact_report,
		"ok"
	)
	var issues: Array[Dictionary] = []
	for message: String in GFVariantData.get_option_packed_string_array(
		artifact_report,
		"issues"
	):
		_append_issue(issues, &"artifact_transaction_failed", message)
	return _make_commit_report(
		artifact_ok,
		"committed" if artifact_ok else "transaction_failed",
		plan.get_plan_sha256(),
		issues,
		artifact_report
	)


# --- 私有/辅助方法 ---

static func _normalize_options(options: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	_require_closed_dictionary(
		options,
		PackedStringArray([
			"position_encoding",
			"max_file_count",
			"max_edits_per_file",
			"max_file_bytes",
			"max_total_bytes",
			"max_workspace_edit_bytes",
		]),
		"options",
		issues
	)
	var position_encoding: String = ""
	if not _has_exact_string(options, "position_encoding"):
		_append_issue(
			issues,
			&"invalid_position_encoding",
			"options.position_encoding must be an exact String."
		)
	else:
		position_encoding = GFVariantData.get_option_string(
			options,
			"position_encoding"
		)
		if not [POSITION_ENCODING_UTF8, POSITION_ENCODING_UTF16].has(
			position_encoding
		):
			_append_issue(
				issues,
				&"invalid_position_encoding",
				"position_encoding must be utf-8 or utf-16."
			)
	var result: Dictionary = {
		"position_encoding": position_encoding,
		"max_file_count": _read_budget(
			options,
			"max_file_count",
			_DEFAULT_MAX_FILE_COUNT,
			_ABSOLUTE_MAX_FILE_COUNT,
			issues
		),
		"max_edits_per_file": _read_budget(
			options,
			"max_edits_per_file",
			_DEFAULT_MAX_EDITS_PER_FILE,
			_ABSOLUTE_MAX_EDITS_PER_FILE,
			issues
		),
		"max_file_bytes": _read_budget(
			options,
			"max_file_bytes",
			_DEFAULT_MAX_FILE_BYTES,
			_ABSOLUTE_MAX_FILE_BYTES,
			issues
		),
		"max_total_bytes": _read_budget(
			options,
			"max_total_bytes",
			_DEFAULT_MAX_TOTAL_BYTES,
			_ABSOLUTE_MAX_TOTAL_BYTES,
			issues
		),
		"max_workspace_edit_bytes": _read_budget(
			options,
			"max_workspace_edit_bytes",
			_DEFAULT_MAX_WORKSPACE_EDIT_BYTES,
			_ABSOLUTE_MAX_WORKSPACE_EDIT_BYTES,
			issues
		),
		"issues": issues,
	}
	result["ok"] = issues.is_empty()
	return result


static func _normalize_workspace_snapshot(
	snapshot: Dictionary,
	budgets: Dictionary
) -> Dictionary:
	var issues: Array[Dictionary] = []
	_require_closed_dictionary(
		snapshot,
		PackedStringArray([
			"workspace_uri",
			"workspace_version",
			"documents",
		]),
		"workspace_snapshot",
		issues
	)
	if not _has_exact_string(snapshot, "workspace_uri"):
		_append_issue(
			issues,
			&"invalid_workspace_uri",
			"workspace_snapshot.workspace_uri must be an exact String."
		)
	if not _has_nonnegative_int(snapshot, "workspace_version"):
		_append_issue(
			issues,
			&"invalid_workspace_version",
			"workspace_snapshot.workspace_version must be a nonnegative int."
		)
	if not snapshot.has("documents") or not snapshot["documents"] is Array:
		_append_issue(
			issues,
			&"invalid_workspace_documents",
			"workspace_snapshot.documents must be an Array."
		)
	if not issues.is_empty():
		return {
			"ok": false,
			"workspace_uri": "",
			"workspace_version": 0,
			"workspace_root": "",
			"workspace_root_sha256": "",
			"documents": [],
			"document_map": {},
			"issues": issues,
		}

	var workspace_uri: String = GFVariantData.get_option_string(
		snapshot,
		"workspace_uri"
	)
	var uri_report: Dictionary = _decode_file_uri(workspace_uri)
	if not GFVariantData.get_option_bool(uri_report, "ok"):
		_append_issue(
			issues,
			&"invalid_workspace_uri",
			GFVariantData.get_option_string(uri_report, "message")
		)
	var actual_root: String = _normalize_absolute_path(
		ProjectSettings.globalize_path("res://")
	)
	var workspace_root: String = GFVariantData.get_option_string(
		uri_report,
		"absolute_path"
	)
	if (
		GFVariantData.get_option_bool(uri_report, "ok")
		and workspace_root != actual_root
	):
		_append_issue(
			issues,
			&"workspace_identity_mismatch",
			"workspace_uri does not identify the current res:// root."
		)

	var raw_documents: Array = GFVariantData.get_option_array(
		snapshot,
		"documents"
	)
	var max_file_count: int = GFVariantData.get_option_int(
		budgets,
		"max_file_count",
		_DEFAULT_MAX_FILE_COUNT
	)
	if raw_documents.is_empty() or raw_documents.size() > max_file_count:
		_append_issue(
			issues,
			&"document_count_budget_exceeded",
			"workspace_snapshot.documents must contain between 1 and max_file_count entries."
		)
		return {
			"ok": false,
			"workspace_uri": workspace_uri,
			"workspace_version": GFVariantData.get_option_int(
				snapshot,
				"workspace_version"
			),
			"workspace_root": actual_root,
			"workspace_root_sha256": actual_root.sha256_text(),
			"documents": [],
			"document_map": {},
			"issues": issues,
		}
	var documents: Array[Dictionary] = []
	var document_map: Dictionary = {}
	for index: int in range(raw_documents.size()):
		var value: Variant = raw_documents[index]
		if not value is Dictionary:
			_append_issue(
				issues,
				&"invalid_document_state",
				"Each workspace document state must be a Dictionary.",
				{ "index": index }
			)
			continue
		var document: Dictionary = value
		var before_count: int = issues.size()
		_require_closed_dictionary(
			document,
			PackedStringArray(["uri", "version", "saved", "source_sha256"]),
			"workspace_snapshot.documents[%d]" % index,
			issues
		)
		if not _has_exact_string(document, "uri"):
			_append_issue(
				issues,
				&"invalid_document_uri",
				"Document uri must be an exact String.",
				{ "index": index }
			)
		if not _has_nonnegative_int(document, "version"):
			_append_issue(
				issues,
				&"invalid_document_version",
				"Document version must be a nonnegative int.",
				{ "index": index }
			)
		if not _has_exact_bool(document, "saved"):
			_append_issue(
				issues,
				&"invalid_saved_state",
				"Document saved must be an exact bool.",
				{ "index": index }
			)
		elif not GFVariantData.get_option_bool(document, "saved"):
			_append_issue(
				issues,
				&"unsaved_document",
				"WorkspaceEdit targets with unsaved buffers are not accepted.",
				{ "index": index }
			)
		if (
			not _has_exact_string(document, "source_sha256")
			or not _is_sha256(GFVariantData.get_option_string(
				document,
				"source_sha256"
			))
		):
			_append_issue(
				issues,
				&"invalid_source_sha256",
				"Document source_sha256 must be 64 lowercase hexadecimal characters.",
				{ "index": index }
			)
		if issues.size() != before_count:
			continue
		var target_report: Dictionary = _resolve_target_uri(
			GFVariantData.get_option_string(document, "uri"),
			actual_root
		)
		if not GFVariantData.get_option_bool(target_report, "ok"):
			_append_issue(
				issues,
				GFVariantData.get_option_string_name(
					target_report,
					"kind",
					&"invalid_document_uri"
				),
				GFVariantData.get_option_string(target_report, "message"),
				{ "index": index }
			)
			continue
		var path: String = GFVariantData.get_option_string(
			target_report,
			"path"
		)
		var identity: String = _portable_path_identity(path)
		if document_map.has(identity):
			_append_issue(
				issues,
				&"portable_path_collision",
				"Workspace document states collide under portable path identity.",
				{ "index": index, "path": path }
			)
			continue
		var normalized_document: Dictionary = {
			"uri": GFVariantData.get_option_string(document, "uri"),
			"version": GFVariantData.get_option_int(document, "version"),
			"saved": true,
			"source_sha256": GFVariantData.get_option_string(
				document,
				"source_sha256"
			),
			"path": path,
			"absolute_path": GFVariantData.get_option_string(
				target_report,
				"absolute_path"
			),
		}
		documents.append(normalized_document)
		document_map[identity] = normalized_document
	return {
		"ok": issues.is_empty(),
		"workspace_uri": workspace_uri,
		"workspace_version": GFVariantData.get_option_int(
			snapshot,
			"workspace_version"
		),
		"workspace_root": actual_root,
		"workspace_root_sha256": actual_root.sha256_text(),
		"documents": documents,
		"document_map": document_map,
		"issues": issues,
	}


static func _normalize_workspace_edit(
	workspace_edit: Dictionary,
	snapshot: Dictionary,
	budgets: Dictionary
) -> Dictionary:
	var issues: Array[Dictionary] = []
	_require_closed_dictionary(
		workspace_edit,
		PackedStringArray(["documentChanges"]),
		"workspace_edit",
		issues
	)
	if not workspace_edit.has("documentChanges"):
		_append_issue(
			issues,
			&"unsupported_workspace_edit_shape",
			"WorkspaceEdit must contain documentChanges."
		)
	elif not workspace_edit["documentChanges"] is Array:
		_append_issue(
			issues,
			&"unsupported_workspace_edit_shape",
			"WorkspaceEdit.documentChanges must be an Array."
		)
	if not issues.is_empty():
		return _make_edit_normalization_failure(issues)

	var changes: Array = GFVariantData.get_option_array(
		workspace_edit,
		"documentChanges"
	)
	var max_file_count: int = GFVariantData.get_option_int(
		budgets,
		"max_file_count"
	)
	if changes.is_empty() or changes.size() > max_file_count:
		_append_issue(
			issues,
			&"document_count_budget_exceeded",
			"documentChanges must contain between 1 and max_file_count entries."
		)
		return _make_edit_normalization_failure(issues)

	var snapshot_map: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"document_map"
	)
	var workspace_root: String = GFVariantData.get_option_string(
		snapshot,
		"workspace_root"
	)
	var seen_targets: Dictionary = {}
	var documents: Array[Dictionary] = []
	var edit_count: int = 0
	var changed_count: int = 0
	var source_bytes: int = 0
	var result_bytes: int = 0
	var replacement_bytes: int = 0
	for index: int in range(changes.size()):
		var value: Variant = changes[index]
		if not value is Dictionary:
			_append_issue(
				issues,
				&"unsupported_document_change",
				"Each documentChanges entry must be a TextDocumentEdit Dictionary.",
				{ "index": index }
			)
			continue
		var change: Dictionary = value
		if change.has("kind"):
			_append_issue(
				issues,
				&"file_resource_operation_not_supported",
				"WorkspaceEdit create, rename, and delete operations are not accepted.",
				{ "index": index }
			)
			continue
		var before_count: int = issues.size()
		_require_closed_dictionary(
			change,
			PackedStringArray(["textDocument", "edits"]),
			"workspace_edit.documentChanges[%d]" % index,
			issues
		)
		if not change.has("textDocument") or not change["textDocument"] is Dictionary:
			_append_issue(
				issues,
				&"invalid_text_document",
				"TextDocumentEdit.textDocument must be a Dictionary.",
				{ "index": index }
			)
		if not change.has("edits") or not change["edits"] is Array:
			_append_issue(
				issues,
				&"invalid_text_edits",
				"TextDocumentEdit.edits must be an Array.",
				{ "index": index }
			)
		if issues.size() != before_count:
			continue
		var text_document: Dictionary = GFVariantData.get_option_dictionary(
			change,
			"textDocument"
		)
		_require_closed_dictionary(
			text_document,
			PackedStringArray(["uri", "version"]),
			"textDocument",
			issues
		)
		if not _has_exact_string(text_document, "uri"):
			_append_issue(
				issues,
				&"invalid_document_uri",
				"textDocument.uri must be an exact String.",
				{ "index": index }
			)
		if not _has_nonnegative_int(text_document, "version"):
			_append_issue(
				issues,
				&"invalid_document_version",
				"textDocument.version must be a nonnegative int.",
				{ "index": index }
			)
		if issues.size() != before_count:
			continue

		var target_uri: String = GFVariantData.get_option_string(
			text_document,
			"uri"
		)
		var target_report: Dictionary = _resolve_target_uri(
			target_uri,
			workspace_root
		)
		if not GFVariantData.get_option_bool(target_report, "ok"):
			_append_issue(
				issues,
				GFVariantData.get_option_string_name(
					target_report,
					"kind",
					&"invalid_document_uri"
				),
				GFVariantData.get_option_string(target_report, "message"),
				{ "index": index }
			)
			continue
		var path: String = GFVariantData.get_option_string(target_report, "path")
		var identity: String = _portable_path_identity(path)
		if seen_targets.has(identity):
			_append_issue(
				issues,
				&"portable_path_collision",
				"TextDocumentEdit targets collide under portable path identity.",
				{ "index": index, "path": path }
			)
			continue
		seen_targets[identity] = true
		if not snapshot_map.has(identity):
			_append_issue(
				issues,
				&"missing_document_state",
				"Every edit target must have one workspace document state.",
				{ "index": index, "path": path }
			)
			continue
		var document_state: Dictionary = GFVariantData.as_dictionary(
			snapshot_map[identity]
		)
		if GFVariantData.get_option_string(document_state, "uri") != target_uri:
			_append_issue(
				issues,
				&"document_uri_mismatch",
				"TextDocumentEdit uri must exactly match its snapshot uri.",
				{ "index": index, "path": path }
			)
			continue
		var document_version: int = GFVariantData.get_option_int(
			text_document,
			"version"
		)
		if document_version != GFVariantData.get_option_int(
			document_state,
			"version"
		):
			_append_issue(
				issues,
				&"document_version_mismatch",
				"TextDocumentEdit version does not match the saved document state.",
				{ "index": index, "path": path }
			)
			continue

		var source_report: Dictionary = _read_strict_utf8_source(
			path,
			GFVariantData.get_option_int(budgets, "max_file_bytes")
		)
		if not GFVariantData.get_option_bool(source_report, "ok"):
			_append_issue(
				issues,
				GFVariantData.get_option_string_name(
					source_report,
					"kind",
					&"source_read_failed"
				),
				GFVariantData.get_option_string(source_report, "message"),
				{ "index": index, "path": path }
			)
			continue
		var source_sha256: String = GFVariantData.get_option_string(
			source_report,
			"sha256"
		)
		if source_sha256 != GFVariantData.get_option_string(
			document_state,
			"source_sha256"
		):
			_append_issue(
				issues,
				&"source_sha256_mismatch",
				"Saved document source_sha256 does not match strict disk bytes.",
				{ "index": index, "path": path }
			)
			continue
		var edit_values: Array = GFVariantData.get_option_array(change, "edits")
		var converted_report: Dictionary = _convert_text_edits(
			GFVariantData.get_option_string(source_report, "text"),
			edit_values,
			GFVariantData.get_option_string(budgets, "position_encoding"),
			GFVariantData.get_option_int(budgets, "max_edits_per_file")
		)
		var conversion_issues: Array[Dictionary] = _get_issue_array(
			converted_report
		)
		if not conversion_issues.is_empty():
			for issue: Dictionary in conversion_issues:
				var annotated_issue: Dictionary = issue.duplicate(true)
				annotated_issue["document_index"] = index
				annotated_issue["path"] = path
				issues.append(annotated_issue)
			continue
		replacement_bytes += GFVariantData.get_option_int(
			converted_report,
			"replacement_bytes"
		)
		if replacement_bytes > GFVariantData.get_option_int(
			budgets,
			"max_workspace_edit_bytes"
		):
			_append_issue(
				issues,
				&"workspace_edit_budget_exceeded",
				"WorkspaceEdit replacement text exceeds max_workspace_edit_bytes."
			)
			continue
		var source_text: String = GFVariantData.get_option_string(
			source_report,
			"text"
		)
		var converted_edits: Array[Dictionary] = _get_dictionary_array(
			converted_report,
			"edits"
		)
		var patch_report: Dictionary = _SOURCE_TEXT_PATCH_TOOLS_SCRIPT.apply_text_edits(
			source_text,
			converted_edits,
			{ "include_edits": false }
		)
		if not GFVariantData.get_option_bool(patch_report, "ok"):
			var patch_kind: StringName = GFVariantData.get_option_string_name(
				patch_report,
				"error",
				&"invalid_text_edits"
			)
			_append_issue(
				issues,
				patch_kind,
				"Text edits are invalid, out of bounds, or overlapping.",
				{ "index": index, "path": path }
			)
			continue
		var result_text: String = GFVariantData.get_option_string(
			patch_report,
			"text"
		)
		var document_source_bytes: int = GFVariantData.get_option_int(
			source_report,
			"size_bytes"
		)
		var document_result_bytes: int = result_text.to_utf8_buffer().size()
		if document_result_bytes > GFVariantData.get_option_int(
			budgets,
			"max_file_bytes"
		):
			_append_issue(
				issues,
				&"result_file_budget_exceeded",
				"Edited document exceeds max_file_bytes.",
				{ "index": index, "path": path }
			)
			continue
		source_bytes += document_source_bytes
		result_bytes += document_result_bytes
		if (
			source_bytes > GFVariantData.get_option_int(budgets, "max_total_bytes")
			or result_bytes > GFVariantData.get_option_int(
				budgets,
				"max_total_bytes"
			)
		):
			_append_issue(
				issues,
				&"total_byte_budget_exceeded",
				"WorkspaceEdit source or result bytes exceed max_total_bytes."
			)
			continue
		var changed: bool = source_text != result_text
		if changed:
			changed_count += 1
		edit_count += edit_values.size()
		documents.append({
			"path": path,
			"uri": target_uri,
			"version": document_version,
			"source_sha256": source_sha256,
			"result_sha256": result_text.sha256_text(),
			"source_bytes": document_source_bytes,
			"result_bytes": document_result_bytes,
			"edit_count": edit_values.size(),
			"changed": changed,
			"result_text": result_text,
		})

	if seen_targets.size() != snapshot_map.size():
		_append_issue(
			issues,
			&"workspace_document_set_mismatch",
			"workspace_snapshot.documents must exactly match WorkspaceEdit targets."
		)
	if issues.is_empty():
		var serialized_bytes: int = JSON.stringify(
			workspace_edit,
			"",
			true
		).to_utf8_buffer().size()
		if serialized_bytes > GFVariantData.get_option_int(
			budgets,
			"max_workspace_edit_bytes"
		):
			_append_issue(
				issues,
				&"workspace_edit_budget_exceeded",
				"Serialized WorkspaceEdit exceeds max_workspace_edit_bytes."
			)
	documents.sort_custom(Callable(GFLspWorkspaceEditAdapter, "_compare_documents"))
	return {
		"ok": issues.is_empty(),
		"documents": documents,
		"edit_count": edit_count,
		"changed_count": changed_count,
		"source_bytes": source_bytes,
		"result_bytes": result_bytes,
		"issues": issues,
	}


static func _convert_text_edits(
	source_text: String,
	edits: Array,
	position_encoding: String,
	max_edits_per_file: int
) -> Dictionary:
	var issues: Array[Dictionary] = []
	if edits.is_empty() or edits.size() > max_edits_per_file:
		_append_issue(
			issues,
			&"edit_count_budget_exceeded",
			"Each TextDocumentEdit must contain between 1 and max_edits_per_file edits."
		)
		return { "ok": false, "edits": [], "replacement_bytes": 0, "issues": issues }
	var lines: Array[Dictionary] = _build_line_map(source_text)
	var converted: Array[Dictionary] = []
	var replacement_bytes: int = 0
	for index: int in range(edits.size()):
		var value: Variant = edits[index]
		if not value is Dictionary:
			_append_issue(
				issues,
				&"invalid_text_edit",
				"Each edit must be a Dictionary.",
				{ "index": index }
			)
			continue
		var edit: Dictionary = value
		var before_count: int = issues.size()
		_require_closed_dictionary(
			edit,
			PackedStringArray(["range", "newText"]),
			"edit[%d]" % index,
			issues
		)
		if not edit.has("range") or not edit["range"] is Dictionary:
			_append_issue(
				issues,
				&"invalid_text_edit",
				"edit.range must be a Dictionary.",
				{ "index": index }
			)
		if not _has_exact_string(edit, "newText"):
			_append_issue(
				issues,
				&"invalid_text_edit",
				"edit.newText must be an exact String.",
				{ "index": index }
			)
		if issues.size() != before_count:
			continue
		var range_data: Dictionary = GFVariantData.get_option_dictionary(
			edit,
			"range"
		)
		_require_closed_dictionary(
			range_data,
			PackedStringArray(["start", "end"]),
			"edit.range",
			issues
		)
		if not range_data.has("start") or not range_data["start"] is Dictionary:
			_append_issue(
				issues,
				&"invalid_text_edit",
				"edit.range.start must be a Dictionary.",
				{ "index": index }
			)
		if not range_data.has("end") or not range_data["end"] is Dictionary:
			_append_issue(
				issues,
				&"invalid_text_edit",
				"edit.range.end must be a Dictionary.",
				{ "index": index }
			)
		if issues.size() != before_count:
			continue
		var start: Dictionary = GFVariantData.get_option_dictionary(
			range_data,
			"start"
		)
		var finish: Dictionary = GFVariantData.get_option_dictionary(
			range_data,
			"end"
		)
		_validate_position_shape(start, "start", index, issues)
		_validate_position_shape(finish, "end", index, issues)
		if issues.size() != before_count:
			continue
		var start_report: Dictionary = _lsp_position_to_godot_character(
			lines,
			GFVariantData.get_option_int(start, "line"),
			GFVariantData.get_option_int(start, "character"),
			position_encoding
		)
		var end_report: Dictionary = _lsp_position_to_godot_character(
			lines,
			GFVariantData.get_option_int(finish, "line"),
			GFVariantData.get_option_int(finish, "character"),
			position_encoding
		)
		if not GFVariantData.get_option_bool(start_report, "ok"):
			_append_issue(
				issues,
				GFVariantData.get_option_string_name(
					start_report,
					"kind",
					&"range_out_of_bounds"
				),
				GFVariantData.get_option_string(start_report, "message"),
				{ "index": index, "field": "start" }
			)
			continue
		if not GFVariantData.get_option_bool(end_report, "ok"):
			_append_issue(
				issues,
				GFVariantData.get_option_string_name(
					end_report,
					"kind",
					&"range_out_of_bounds"
				),
				GFVariantData.get_option_string(end_report, "message"),
				{ "index": index, "field": "end" }
			)
			continue
		var replacement: String = edit["newText"]
		if _string_contains_nul(replacement):
			_append_issue(
				issues,
				&"invalid_replacement_text",
				"edit.newText must not contain a NUL code point.",
				{ "index": index }
			)
			continue
		replacement_bytes += replacement.to_utf8_buffer().size()
		converted.append({
			"range": {
				"start": {
					"line": GFVariantData.get_option_int(start, "line"),
					"character": GFVariantData.get_option_int(
						start_report,
						"character"
					),
				},
				"end": {
					"line": GFVariantData.get_option_int(finish, "line"),
					"character": GFVariantData.get_option_int(
						end_report,
						"character"
					),
				},
			},
			"newText": replacement,
		})
	return {
		"ok": issues.is_empty(),
		"edits": converted,
		"replacement_bytes": replacement_bytes,
		"issues": issues,
	}


static func _validate_position_shape(
	position: Dictionary,
	field: String,
	edit_index: int,
	issues: Array[Dictionary]
) -> void:
	_require_closed_dictionary(
		position,
		PackedStringArray(["line", "character"]),
		"edit.range.%s" % field,
		issues
	)
	if not _has_nonnegative_int(position, "line"):
		_append_issue(
			issues,
			&"invalid_text_edit",
			"LSP position line must be a nonnegative int.",
			{ "index": edit_index, "field": field }
		)
	if not _has_nonnegative_int(position, "character"):
		_append_issue(
			issues,
			&"invalid_text_edit",
			"LSP position character must be a nonnegative int.",
			{ "index": edit_index, "field": field }
		)


static func _build_line_map(source_text: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var line_start: int = 0
	var index: int = 0
	while index < source_text.length():
		var character: String = source_text.substr(index, 1)
		if character == "\r":
			lines.append({
				"text": source_text.substr(line_start, index - line_start),
			})
			if (
				index + 1 < source_text.length()
				and source_text.substr(index + 1, 1) == "\n"
			):
				index += 2
			else:
				index += 1
			line_start = index
			continue
		if character == "\n":
			lines.append({
				"text": source_text.substr(line_start, index - line_start),
			})
			index += 1
			line_start = index
			continue
		index += 1
	lines.append({
		"text": source_text.substr(line_start),
	})
	return lines


static func _lsp_position_to_godot_character(
	lines: Array[Dictionary],
	line: int,
	character_units: int,
	position_encoding: String
) -> Dictionary:
	if line < 0 or line >= lines.size():
		return {
			"ok": false,
			"kind": &"range_out_of_bounds",
			"message": "LSP position line is outside source text.",
		}
	var boundaries: PackedInt32Array = _get_line_position_boundaries(
		lines,
		line,
		position_encoding
	)
	if boundaries.is_empty():
		return {
			"ok": false,
			"kind": &"position_map_failed",
			"message": "LSP position boundary table could not be allocated.",
		}
	var lower_index: int = 0
	var upper_index: int = boundaries.size() - 1
	while lower_index <= upper_index:
		var middle_index: int = (lower_index + upper_index) >> 1
		var boundary_units: int = boundaries[middle_index]
		if boundary_units == character_units:
			return { "ok": true, "character": middle_index }
		if boundary_units < character_units:
			lower_index = middle_index + 1
		else:
			upper_index = middle_index - 1
	if not boundaries.is_empty() and character_units < boundaries[-1]:
		return {
			"ok": false,
			"kind": &"position_splits_codepoint",
			"message": "LSP character offset splits a UTF code point boundary.",
		}
	return {
		"ok": false,
		"kind": &"range_out_of_bounds",
		"message": "LSP character offset is outside its source line.",
	}


static func _get_line_position_boundaries(
	lines: Array[Dictionary],
	line: int,
	position_encoding: String
) -> PackedInt32Array:
	var line_data: Dictionary = lines[line]
	if GFVariantData.get_option_string(
		line_data,
		"boundary_encoding"
	) == position_encoding:
		var cached_value: Variant = line_data.get("boundaries")
		if cached_value is PackedInt32Array:
			var cached_boundaries: PackedInt32Array = cached_value
			return cached_boundaries
	var line_text: String = GFVariantData.get_option_string(line_data, "text")
	var boundaries: PackedInt32Array = PackedInt32Array()
	var resize_error_code: int = boundaries.resize(line_text.length() + 1)
	if resize_error_code != OK:
		return boundaries
	boundaries[0] = 0
	var consumed_units: int = 0
	_record_test_position_line_scan(line)
	for index: int in range(line_text.length()):
		var codepoint: int = line_text.unicode_at(index)
		if position_encoding == POSITION_ENCODING_UTF8:
			consumed_units += _get_utf8_codepoint_size(codepoint)
		elif codepoint > 0xffff:
			consumed_units += 2
		else:
			consumed_units += 1
		boundaries[index + 1] = consumed_units
	line_data["boundary_encoding"] = position_encoding
	line_data["boundaries"] = boundaries
	lines[line] = line_data
	return boundaries


static func _get_utf8_codepoint_size(codepoint: int) -> int:
	if codepoint <= 0x7f:
		return 1
	if codepoint <= 0x7ff:
		return 2
	if codepoint <= 0xffff:
		return 3
	return 4


static func _read_strict_utf8_source(path: String, max_file_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _make_source_failure(
			&"source_not_found",
			"WorkspaceEdit target no longer exists."
		)
	var hash_before: String = FileAccess.get_sha256(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _make_source_failure(
			&"source_read_failed",
			"WorkspaceEdit target could not be opened for strict UTF-8 reading."
		)
	var size_bytes: int = file.get_length()
	if size_bytes < 0 or size_bytes > max_file_bytes:
		file.close()
		return _make_source_failure(
			&"source_file_budget_exceeded",
			"WorkspaceEdit target exceeds max_file_bytes."
		)
	var bytes: PackedByteArray = file.get_buffer(size_bytes)
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK or bytes.size() != size_bytes:
		return _make_source_failure(
			&"source_read_failed",
			"WorkspaceEdit target bytes could not be read completely."
		)
	if (
		bytes.size() >= 3
		and bytes[0] == 0xef
		and bytes[1] == 0xbb
		and bytes[2] == 0xbf
	):
		return _make_source_failure(
			&"utf8_bom_not_supported",
			"WorkspaceEdit target must be UTF-8 without BOM."
		)
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _make_source_failure(
			&"invalid_utf8_source",
			"WorkspaceEdit target is not strict UTF-8 text."
		)
	var calculated_hash: String = _sha256_bytes(bytes)
	var hash_after: String = FileAccess.get_sha256(path)
	if (
		not _is_sha256(calculated_hash)
		or hash_before != calculated_hash
		or hash_after != calculated_hash
	):
		return _make_source_failure(
			&"source_changed_during_read",
			"WorkspaceEdit target changed while it was being read."
		)
	return {
		"ok": true,
		"kind": &"",
		"message": "",
		"text": text,
		"size_bytes": size_bytes,
		"sha256": calculated_hash,
	}


static func _resolve_target_uri(uri: String, workspace_root: String) -> Dictionary:
	var uri_report: Dictionary = _decode_file_uri(uri)
	if not GFVariantData.get_option_bool(uri_report, "ok"):
		return {
			"ok": false,
			"kind": &"invalid_document_uri",
			"message": GFVariantData.get_option_string(uri_report, "message"),
		}
	var absolute_path: String = GFVariantData.get_option_string(
		uri_report,
		"absolute_path"
	)
	if (
		absolute_path == workspace_root
		or not absolute_path.begins_with(workspace_root + "/")
	):
		return {
			"ok": false,
			"kind": &"target_outside_workspace",
			"message": "WorkspaceEdit target is outside the current res:// root.",
		}
	var relative_path: String = absolute_path.substr(workspace_root.length() + 1)
	if relative_path.is_empty() or relative_path != relative_path.simplify_path():
		return {
			"ok": false,
			"kind": &"invalid_document_uri",
			"message": "WorkspaceEdit target URI is not a canonical project path.",
		}
	var resource_path: String = "res://" + relative_path
	if not resource_path.to_lower().ends_with(".gd"):
		return {
			"ok": false,
			"kind": &"unsupported_target_type",
			"message": "WorkspaceEdit target must be an existing .gd file.",
		}
	if (
		not FileAccess.file_exists(resource_path)
		or DirAccess.dir_exists_absolute(absolute_path)
	):
		return {
			"ok": false,
			"kind": &"source_not_found",
			"message": "WorkspaceEdit target must be an existing regular .gd file.",
		}
	if _path_has_link_component(absolute_path):
		return {
			"ok": false,
			"kind": &"linked_target_not_allowed",
			"message": "WorkspaceEdit target crosses a filesystem link or reparse point.",
		}
	return {
		"ok": true,
		"kind": &"",
		"message": "",
		"path": resource_path,
		"absolute_path": absolute_path,
	}


static func _decode_file_uri(uri: String) -> Dictionary:
	if uri.to_utf8_buffer().size() > _MAX_URI_BYTES:
		return _make_uri_failure("file URI exceeds the URI byte budget.")
	if not uri.begins_with("file://"):
		return _make_uri_failure("Only lowercase file:// URIs are accepted.")
	if uri.contains("\\") or uri.contains("?") or uri.contains("#"):
		return _make_uri_failure("file URI must not contain backslashes, query, or fragment.")
	var body: String = uri.substr(7)
	if body.is_empty() or not body.begins_with("/") or body.begins_with("//"):
		return _make_uri_failure("file URI must identify a local absolute path without authority.")
	if not _has_valid_percent_encoding(body):
		return _make_uri_failure("file URI contains an invalid percent escape.")
	var lower_body: String = body.to_lower()
	if lower_body.contains("%2f") or lower_body.contains("%5c"):
		return _make_uri_failure("file URI must not percent-encode path separators.")
	var decoded: String = body.uri_decode()
	if decoded.contains("\\") or _string_contains_nul(decoded):
		return _make_uri_failure("file URI decodes to an invalid local path.")
	if decoded.length() >= 4 and decoded.substr(0, 1) == "/" and decoded.substr(2, 2) == ":/":
		decoded = decoded.substr(1)
	var components: PackedStringArray = decoded.split("/", false)
	for component: String in components:
		if component == "." or component == "..":
			return _make_uri_failure("file URI must not contain dot path segments.")
	var normalized: String = _normalize_absolute_path(decoded)
	if normalized.is_empty() or not _is_absolute_filesystem_path(normalized):
		return _make_uri_failure("file URI must decode to an absolute filesystem path.")
	return {
		"ok": true,
		"message": "",
		"absolute_path": normalized,
	}


static func _validate_plan_payload(payload: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	_require_closed_dictionary(
		payload,
		PackedStringArray([
			"format",
			"format_version",
			"workspace_uri",
			"workspace_root_sha256",
			"workspace_version",
			"position_encoding",
			"budgets",
			"documents",
		]),
		"plan",
		issues
	)
	if not _has_exact_string(payload, "format") or GFVariantData.get_option_string(
		payload,
		"format"
	) != _FORMAT:
		_append_issue(issues, &"invalid_plan", "Plan format is invalid.")
	if not _has_exact_int(payload, "format_version") or GFVariantData.get_option_int(
		payload,
		"format_version"
	) != _FORMAT_VERSION:
		_append_issue(issues, &"invalid_plan", "Plan format_version is invalid.")
	if not _has_exact_string(payload, "workspace_uri"):
		_append_issue(issues, &"invalid_plan", "Plan workspace_uri is invalid.")
	if (
		not _has_exact_string(payload, "workspace_root_sha256")
		or not _is_sha256(GFVariantData.get_option_string(
			payload,
			"workspace_root_sha256"
		))
	):
		_append_issue(issues, &"invalid_plan", "Plan workspace identity is invalid.")
	if not _has_nonnegative_int(payload, "workspace_version"):
		_append_issue(issues, &"invalid_plan", "Plan workspace_version is invalid.")
	if (
		not _has_exact_string(payload, "position_encoding")
		or not [POSITION_ENCODING_UTF8, POSITION_ENCODING_UTF16].has(
			GFVariantData.get_option_string(payload, "position_encoding")
		)
	):
		_append_issue(issues, &"invalid_plan", "Plan position_encoding is invalid.")
	if not payload.has("budgets") or not payload["budgets"] is Dictionary:
		_append_issue(issues, &"invalid_plan", "Plan budgets are invalid.")
	if not payload.has("documents") or not payload["documents"] is Array:
		_append_issue(issues, &"invalid_plan", "Plan documents are invalid.")
	if not issues.is_empty():
		return { "ok": false, "issues": issues }

	var raw_budgets: Dictionary = GFVariantData.get_option_dictionary(
		payload,
		"budgets"
	)
	_require_closed_dictionary(
		raw_budgets,
		PackedStringArray([
			"position_encoding",
			"max_file_count",
			"max_edits_per_file",
			"max_file_bytes",
			"max_total_bytes",
			"max_workspace_edit_bytes",
		]),
		"plan.budgets",
		issues
	)
	var budget_report: Dictionary = _normalize_options(raw_budgets)
	for issue: Dictionary in _get_issue_array(budget_report):
		issues.append(issue)
	if GFVariantData.get_option_string(
		budget_report,
		"position_encoding"
	) != GFVariantData.get_option_string(payload, "position_encoding"):
		_append_issue(
			issues,
			&"invalid_plan",
			"Plan position_encoding and budgets disagree."
		)
	var raw_documents: Array = GFVariantData.get_option_array(payload, "documents")
	var documents: Array[Dictionary] = _get_dictionary_array(payload, "documents")
	if (
		documents.is_empty()
		or documents.size() != raw_documents.size()
		or documents.size() > GFVariantData.get_option_int(
			budget_report,
			"max_file_count",
			0
		)
	):
		_append_issue(issues, &"invalid_plan", "Plan document count is invalid.")
	var seen: Dictionary = {}
	var source_total: int = 0
	var result_total: int = 0
	for index: int in range(documents.size()):
		var document: Dictionary = documents[index]
		_require_closed_dictionary(
			document,
			PackedStringArray([
				"path",
				"uri",
				"version",
				"source_sha256",
				"result_sha256",
				"source_bytes",
				"result_bytes",
				"edit_count",
				"changed",
				"result_text",
			]),
			"plan.documents[%d]" % index,
			issues
		)
		if (
			not _has_exact_string(document, "path")
			or not GFVariantData.get_option_string(document, "path").begins_with(
				"res://"
			)
			or not GFVariantData.get_option_string(document, "path").to_lower().ends_with(
				".gd"
			)
		):
			_append_issue(issues, &"invalid_plan", "Plan target path is invalid.")
			continue
		var path: String = GFVariantData.get_option_string(document, "path")
		var identity: String = _portable_path_identity(path)
		if seen.has(identity):
			_append_issue(issues, &"invalid_plan", "Plan targets collide under portable identity.")
		else:
			seen[identity] = true
		if not _has_exact_string(document, "uri"):
			_append_issue(issues, &"invalid_plan", "Plan target uri is invalid.")
		if not _has_nonnegative_int(document, "version"):
			_append_issue(issues, &"invalid_plan", "Plan document version is invalid.")
		if (
			not _has_exact_string(document, "source_sha256")
			or not _is_sha256(GFVariantData.get_option_string(
				document,
				"source_sha256"
			))
			or not _has_exact_string(document, "result_sha256")
			or not _is_sha256(GFVariantData.get_option_string(
				document,
				"result_sha256"
			))
		):
			_append_issue(issues, &"invalid_plan", "Plan document hashes are invalid.")
		if (
			not _has_nonnegative_int(document, "source_bytes")
			or not _has_nonnegative_int(document, "result_bytes")
			or not _has_nonnegative_int(document, "edit_count")
			or not _has_exact_bool(document, "changed")
			or not _has_exact_string(document, "result_text")
		):
			_append_issue(issues, &"invalid_plan", "Plan document metadata is invalid.")
			continue
		var result_text: String = GFVariantData.get_option_string(
			document,
			"result_text"
		)
		var source_size: int = GFVariantData.get_option_int(document, "source_bytes")
		var result_size: int = GFVariantData.get_option_int(document, "result_bytes")
		if (
			result_text.to_utf8_buffer().size() != result_size
			or result_text.sha256_text() != GFVariantData.get_option_string(
				document,
				"result_sha256"
			)
			or source_size > GFVariantData.get_option_int(
				budget_report,
				"max_file_bytes",
				0
			)
			or result_size > GFVariantData.get_option_int(
				budget_report,
				"max_file_bytes",
				0
			)
			or GFVariantData.get_option_int(document, "edit_count") <= 0
			or GFVariantData.get_option_int(document, "edit_count") > GFVariantData.get_option_int(
				budget_report,
				"max_edits_per_file",
				0
			)
		):
			_append_issue(issues, &"invalid_plan", "Plan document content or budgets are invalid.")
		source_total += source_size
		result_total += result_size
	if (
		source_total > GFVariantData.get_option_int(budget_report, "max_total_bytes", 0)
		or result_total > GFVariantData.get_option_int(
			budget_report,
			"max_total_bytes",
			0
		)
	):
		_append_issue(issues, &"invalid_plan", "Plan total byte budget is invalid.")
	var current_root_sha256: String = _normalize_absolute_path(
		ProjectSettings.globalize_path("res://")
	).sha256_text()
	if current_root_sha256 != GFVariantData.get_option_string(
		payload,
		"workspace_root_sha256"
	):
		_append_issue(issues, &"workspace_identity_mismatch", "Plan belongs to another workspace.")
	return { "ok": issues.is_empty(), "issues": issues }


static func _validate_fresh_state(
	payload: Dictionary,
	snapshot: Dictionary
) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if GFVariantData.get_option_string(payload, "workspace_uri") != GFVariantData.get_option_string(
		snapshot,
		"workspace_uri"
	):
		_append_issue(
			issues,
			&"workspace_identity_mismatch",
			"Commit snapshot workspace_uri differs from the reviewed plan."
		)
	if GFVariantData.get_option_int(payload, "workspace_version") != GFVariantData.get_option_int(
		snapshot,
		"workspace_version"
	):
		_append_issue(
			issues,
			&"workspace_version_mismatch",
			"Commit snapshot workspace_version differs from the reviewed plan."
		)
	if GFVariantData.get_option_string(payload, "workspace_root_sha256") != GFVariantData.get_option_string(
		snapshot,
		"workspace_root_sha256"
	):
		_append_issue(
			issues,
			&"workspace_identity_mismatch",
			"Commit snapshot resolves to another workspace root."
		)
	var snapshot_map: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"document_map"
	)
	var documents: Array[Dictionary] = _get_dictionary_array(payload, "documents")
	if snapshot_map.size() != documents.size():
		_append_issue(
			issues,
			&"workspace_document_set_mismatch",
			"Commit snapshot target set differs from the reviewed plan."
		)
	var max_file_bytes: int = GFVariantData.get_option_int(
		GFVariantData.get_option_dictionary(payload, "budgets"),
		"max_file_bytes"
	)
	for document: Dictionary in documents:
		var path: String = GFVariantData.get_option_string(document, "path")
		var identity: String = _portable_path_identity(path)
		if not snapshot_map.has(identity):
			_append_issue(
				issues,
				&"missing_document_state",
				"Commit snapshot is missing a reviewed target.",
				{ "path": path }
			)
			continue
		var state: Dictionary = GFVariantData.as_dictionary(snapshot_map[identity])
		if (
			GFVariantData.get_option_string(state, "uri")
			!= GFVariantData.get_option_string(document, "uri")
			or GFVariantData.get_option_int(state, "version")
			!= GFVariantData.get_option_int(document, "version")
			or GFVariantData.get_option_string(state, "source_sha256")
			!= GFVariantData.get_option_string(document, "source_sha256")
		):
			_append_issue(
				issues,
				&"document_state_mismatch",
				"Commit document uri, version, or source SHA-256 differs from the plan.",
				{ "path": path }
			)
			continue
		var source_report: Dictionary = _read_strict_utf8_source(
			path,
			max_file_bytes
		)
		if not GFVariantData.get_option_bool(source_report, "ok"):
			_append_issue(
				issues,
				GFVariantData.get_option_string_name(
					source_report,
					"kind",
					&"source_read_failed"
				),
				GFVariantData.get_option_string(source_report, "message"),
				{ "path": path }
			)
			continue
		if (
			GFVariantData.get_option_string(source_report, "sha256")
			!= GFVariantData.get_option_string(document, "source_sha256")
			or GFVariantData.get_option_int(source_report, "size_bytes")
			!= GFVariantData.get_option_int(document, "source_bytes")
		):
			_append_issue(
				issues,
				&"source_sha256_mismatch",
				"Disk source changed after the WorkspaceEdit plan was reviewed.",
				{ "path": path }
			)
			continue
		var expected_changed: bool = (
			GFVariantData.get_option_string(document, "source_sha256")
			!= GFVariantData.get_option_string(document, "result_sha256")
		)
		if GFVariantData.get_option_bool(document, "changed") != expected_changed:
			_append_issue(
				issues,
				&"invalid_plan",
				"Plan changed metadata does not match source and result hashes.",
				{ "path": path }
			)
	return issues


static func _make_invalid_plan(
	issues: Array[Dictionary],
	snapshot: Dictionary = {},
	options: Dictionary = {}
) -> GFLspWorkspaceEditPlan:
	var report: Dictionary = _make_plan_report(
		false,
		"rejected",
		"",
		snapshot,
		options,
		[],
		issues,
		0,
		0,
		0,
		0
	)
	var plan: GFLspWorkspaceEditPlan = _PLAN_SCRIPT.new()
	var _initialized: bool = plan.initialize_for_adapter(false, "", report, {})
	return plan


static func _make_plan_report(
	ok: bool,
	status: String,
	plan_sha256: String,
	snapshot: Dictionary,
	options: Dictionary,
	documents: Array[Dictionary],
	issues: Array[Dictionary],
	edit_count: int,
	changed_count: int,
	source_bytes: int,
	result_bytes: int
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"plan_sha256": plan_sha256,
		"workspace_uri": GFVariantData.get_option_string(
			snapshot,
			"workspace_uri"
		),
		"workspace_version": GFVariantData.get_option_int(
			snapshot,
			"workspace_version"
		),
		"position_encoding": GFVariantData.get_option_string(
			options,
			"position_encoding"
		),
		"document_count": documents.size(),
		"edit_count": edit_count,
		"changed_count": changed_count,
		"source_bytes": source_bytes,
		"result_bytes": result_bytes,
		"issues": issues.duplicate(true),
		"documents": documents.duplicate(true),
		"consumed": false,
	}


static func _make_public_document_report(document: Dictionary) -> Dictionary:
	return {
		"path": GFVariantData.get_option_string(document, "path"),
		"uri": GFVariantData.get_option_string(document, "uri"),
		"version": GFVariantData.get_option_int(document, "version"),
		"source_sha256": GFVariantData.get_option_string(
			document,
			"source_sha256"
		),
		"result_sha256": GFVariantData.get_option_string(
			document,
			"result_sha256"
		),
		"source_bytes": GFVariantData.get_option_int(document, "source_bytes"),
		"result_bytes": GFVariantData.get_option_int(document, "result_bytes"),
		"edit_count": GFVariantData.get_option_int(document, "edit_count"),
		"changed": GFVariantData.get_option_bool(document, "changed"),
	}


static func _make_commit_failure(
	status: String,
	message: String,
	plan_sha256: String = ""
) -> Dictionary:
	var issues: Array[Dictionary] = []
	_append_issue(issues, StringName(status), message)
	return _make_commit_report(false, status, plan_sha256, issues)


static func _make_commit_report(
	ok: bool,
	status: String,
	plan_sha256: String,
	issues: Array[Dictionary],
	artifact_report: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"plan_sha256": plan_sha256,
		"written_count": GFVariantData.get_option_int(
			artifact_report,
			"written_count"
		),
		"unchanged_count": GFVariantData.get_option_int(
			artifact_report,
			"unchanged_count"
		),
		"recovery_required": GFVariantData.get_option_bool(
			artifact_report,
			"recovery_required"
		),
		"recovery_action": str(GFVariantData.get_option_string_name(
			artifact_report,
			"recovery_action"
		)),
		"recovery_transaction": GFVariantData.get_option_dictionary(
			artifact_report,
			"recovery_transaction"
		).duplicate(true),
		"issues": issues.duplicate(true),
		"artifact_report": artifact_report.duplicate(true),
	}


static func _make_edit_normalization_failure(
	issues: Array[Dictionary]
) -> Dictionary:
	return {
		"ok": false,
		"documents": [],
		"edit_count": 0,
		"changed_count": 0,
		"source_bytes": 0,
		"result_bytes": 0,
		"issues": issues,
	}


static func _make_source_failure(kind: StringName, message: String) -> Dictionary:
	return {
		"ok": false,
		"kind": kind,
		"message": message,
		"text": "",
		"size_bytes": 0,
		"sha256": "",
	}


static func _make_uri_failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"absolute_path": "",
	}


static func _make_transaction_options(budgets: Dictionary) -> Dictionary:
	return {
		"allowed_roots": PackedStringArray(["res://"]),
		"overwrite_existing": true,
		"max_file_count": GFVariantData.get_option_int(
			budgets,
			"max_file_count"
		),
		"max_file_bytes": GFVariantData.get_option_int(
			budgets,
			"max_file_bytes"
		),
		"max_total_bytes": GFVariantData.get_option_int(
			budgets,
			"max_total_bytes"
		),
		"max_backup_bytes": GFVariantData.get_option_int(
			budgets,
			"max_total_bytes"
		),
		"scan_filesystem": false,
	}


static func _extract_budgets(options: Dictionary) -> Dictionary:
	return {
		"position_encoding": GFVariantData.get_option_string(
			options,
			"position_encoding"
		),
		"max_file_count": GFVariantData.get_option_int(
			options,
			"max_file_count"
		),
		"max_edits_per_file": GFVariantData.get_option_int(
			options,
			"max_edits_per_file"
		),
		"max_file_bytes": GFVariantData.get_option_int(
			options,
			"max_file_bytes"
		),
		"max_total_bytes": GFVariantData.get_option_int(
			options,
			"max_total_bytes"
		),
		"max_workspace_edit_bytes": GFVariantData.get_option_int(
			options,
			"max_workspace_edit_bytes"
		),
	}


static func _read_budget(
	options: Dictionary,
	key: String,
	default_value: int,
	absolute_maximum: int,
	issues: Array[Dictionary]
) -> int:
	if not options.has(key):
		return default_value
	if not _has_exact_int(options, key):
		_append_issue(
			issues,
			&"invalid_budget",
			"%s must be an exact int." % key,
			{ "field": key }
		)
		return default_value
	var value: int = GFVariantData.get_option_int(options, key)
	if value <= 0 or value > absolute_maximum:
		_append_issue(
			issues,
			&"invalid_budget",
			"%s must be positive and no greater than its absolute limit." % key,
			{ "field": key, "absolute_maximum": absolute_maximum }
		)
		return default_value
	return value


static func _require_closed_dictionary(
	data: Dictionary,
	allowed_keys: PackedStringArray,
	context: String,
	issues: Array[Dictionary]
) -> void:
	for key_value: Variant in data.keys():
		if typeof(key_value) != TYPE_STRING:
			_append_issue(
				issues,
				&"unsupported_field",
				"%s contains a non-String key." % context
			)
			continue
		var key: String = str(key_value)
		if not allowed_keys.has(key):
			_append_issue(
				issues,
				&"unsupported_field",
				"%s contains unsupported field: %s." % [context, key],
				{ "field": key }
			)


static func _has_exact_string(data: Dictionary, key: String) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_STRING


static func _has_exact_bool(data: Dictionary, key: String) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_BOOL


static func _has_exact_int(data: Dictionary, key: String) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_INT


static func _has_nonnegative_int(data: Dictionary, key: String) -> bool:
	if not _has_exact_int(data, key):
		return false
	var value: int = GFVariantData.get_option_int(data, key, -1)
	return value >= 0 and value <= _MAX_LSP_INTEGER


static func _get_issue_array(report: Dictionary) -> Array[Dictionary]:
	return _get_dictionary_array(report, "issues")


static func _get_dictionary_array(
	report: Dictionary,
	key: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(report, key):
		if value is Dictionary:
			var data: Dictionary = value
			result.append(data.duplicate(true))
	return result


static func _append_issue(
	issues: Array[Dictionary],
	kind: StringName,
	message: String,
	fields: Dictionary = {}
) -> void:
	var issue: Dictionary = {
		"kind": kind,
		"message": message,
	}
	for key: Variant in fields.keys():
		issue[key] = GFVariantData.duplicate_variant(fields[key], true)
	issues.append(issue)


static func _hash_canonical(value: Variant) -> String:
	return JSON.stringify(value, "", true).sha256_text()


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in range(value.length()):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true


static func _has_valid_percent_encoding(value: String) -> bool:
	var index: int = 0
	while index < value.length():
		if value.substr(index, 1) != "%":
			index += 1
			continue
		if index + 2 >= value.length():
			return false
		var first: String = value.substr(index + 1, 1).to_lower()
		var second: String = value.substr(index + 2, 1).to_lower()
		if "0123456789abcdef".find(first) < 0 or "0123456789abcdef".find(second) < 0:
			return false
		index += 3
	return true


static func _string_contains_nul(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) == 0:
			return true
	return false


static func _normalize_absolute_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").simplify_path()
	while normalized.length() > 1 and normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	return normalized


static func _portable_path_identity(path: String) -> String:
	return _normalize_absolute_path(path).to_lower()


static func _is_absolute_filesystem_path(path: String) -> bool:
	if path.is_absolute_path():
		return true
	return path.length() >= 3 and path.substr(1, 2) == ":/"


static func _path_has_link_component(path: String) -> bool:
	var current: String = _normalize_absolute_path(path)
	while not current.is_empty():
		if _path_component_is_link(current):
			return true
		var parent: String = _normalize_absolute_path(current.get_base_dir())
		if parent.is_empty() or parent == current:
			break
		current = parent
	return false


static func _path_component_is_link(path: String) -> bool:
	var normalized: String = _normalize_absolute_path(path)
	var parent: String = normalized.get_base_dir()
	var component_name: String = normalized.get_file()
	if parent.is_empty() or component_name.is_empty():
		return false
	var directory: DirAccess = DirAccess.open(parent)
	if directory == null:
		return DirAccess.dir_exists_absolute(parent)
	return directory.is_link(component_name)


static func _compare_documents(left: Dictionary, right: Dictionary) -> bool:
	return _portable_path_identity(
		GFVariantData.get_option_string(left, "path")
	) < _portable_path_identity(GFVariantData.get_option_string(right, "path"))


static func _configure_test_before_artifact_commit(callback: Callable) -> void:
	_test_before_artifact_commit = callback


static func _configure_test_position_line_scan_tracking(enabled: bool) -> void:
	_test_track_position_line_scans = enabled
	_test_position_line_scan_counts.clear()


static func _get_test_position_line_scan_count(line: int) -> int:
	return GFVariantData.get_option_int(_test_position_line_scan_counts, line, 0)


static func _record_test_position_line_scan(line: int) -> void:
	if not _test_track_position_line_scans:
		return
	_test_position_line_scan_counts[line] = (
		GFVariantData.get_option_int(_test_position_line_scan_counts, line, 0)
		+ 1
	)


static func _reset_test_state() -> void:
	_test_before_artifact_commit = Callable()
	_test_track_position_line_scans = false
	_test_position_line_scan_counts.clear()
