## GFConfigPipelineCommitStage: Config Pipeline 的文件提交事务阶段。
##
## 将 Config Pipeline 的 ResourceSaver 等专用写入器接到框架级
## GFArtifactWriteTransaction。该阶段不复制事务实现、不解释产物内容，
## 也不决定输出路径策略。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineCommitStage
extends RefCounted


# --- 常量 ---

## Commit 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.commit.filesystem"

## Commit 阶段的实现版本；改变事务或回滚语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 4

## artifact write transaction 报告的格式标识。
## [br]
## @api private
## [br]
const _TRANSACTION_FORMAT: String = "gf.artifact_write.transaction"

## artifact write transaction 当前报告版本。
## [br]
## @api private
## [br]
const _TRANSACTION_VERSION: int = 1

## 执行多文件产物事务写入的内部脚本。
## [br]
## @api private
## [br]
const _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT = preload("res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd")

## 沿用配置产物路径域与框架源保护。
## [br]
## @api private
const _OUTPUT_PATH_POLICY_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd")


# --- 公共方法 ---

## 只读捕获登记簿与完整作者映射，并应用 Profile 的显式对账范围和恢复声明；ID 来自作者记录，不在预览时分配。
## [br]
## @api framework_internal
## [br]
## @param profile: 作者声明。
## [br]
## @param author_ir: 尚未消费目标裁剪的已验收 IR。
## [br]
## @return 登记候选及对原文件的摘要约束。
## [br]
## @schema return: Dictionary，success:bool、path:String、digest:String（missing表示不存在）、changes:Array[Dictionary]（Registry.preview变化）、candidate:GFConfigStableIDRegistry/null、error:String。未启用时path为空且candidate为null。
func prepare_stable_ids(profile: GFConfigPipelineProfile, author_ir: GFConfigPipelineIR) -> Dictionary:
	var failure: Dictionary = {
		"success": false,
		"path": "",
		"digest": "",
		"changes": [],
		"candidate": null,
		"error": "稳定 ID 声明或来源无效。",
	}
	if profile == null or author_ir == null:
		return failure
	if profile.stable_id_registry_path.is_empty():
		if (
			not profile.stable_id_bindings.is_empty()
			or not profile.stable_id_scope_tables.is_empty()
			or not profile.stable_id_restorations.is_empty()
		):
			return failure
		return {
			"success": true,
			"path": "",
			"digest": "",
			"changes": [],
			"candidate": null,
			"error": "",
		}
	var path_result: Dictionary = _OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(
		profile.stable_id_registry_path,
		{},
		"稳定 ID 登记簿"
	)
	var path: String = GFVariantData.get_option_string(path_result, "path")
	if (
		not GFVariantData.get_option_bool(path_result, "success")
		or path.get_extension().to_lower() != "json"
		or profile.stable_id_bindings.size() > 4096
	):
		return failure
	for source: GFConfigPipelineTableSource in profile.sources:
		if source != null and ProjectSettings.globalize_path(source.source_path).simplify_path() == ProjectSettings.globalize_path(path).simplify_path():
			return failure
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty()
	var digest: String = "missing"
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return failure
		var length: int = file.get_length()
		if length > 8388608:
			file.close()
			return failure
		var bytes: PackedByteArray = file.get_buffer(length)
		file.close()
		if bytes.size() != length:
			return failure
		registry = GFConfigStableIDRegistry.from_json(bytes.get_string_from_utf8())
		digest = _digest_bytes(bytes)
		if registry == null or digest.is_empty():
			failure["error"] = "稳定 ID 登记簿结构无效。"
			return failure
	var assignments: Dictionary = {}
	var row_count: int = 0
	for table_name: Variant in profile.stable_id_bindings:
		if not table_name is String or not profile.stable_id_bindings[table_name] is Dictionary:
			return failure
		var binding: Dictionary = profile.stable_id_bindings[table_name]
		if (
			binding.size() != 2
			or not binding.get("symbol_field") is String
			or not binding.get("id_field") is String
		):
			return failure
		var table_id: String = table_name
		var table: GFConfigPipelineTableIR = author_ir.get_table(StringName(table_id))
		if table == null:
			return failure
		var schema: GFConfigTableSchema = table.get_schema()
		var symbol_field: String = binding["symbol_field"]
		var id_field: String = binding["id_field"]
		if (
			schema == null
			or symbol_field.is_empty()
			or id_field.is_empty()
			or schema.get_column(StringName(symbol_field)) == null
			or schema.get_column(StringName(id_field)) == null
		):
			return failure
		var entries: Dictionary = {}
		for row: Dictionary in table.get_records():
			row_count += 1
			if (
				row_count > 65536
				or not row.get(symbol_field) is String
				or not row.get(id_field) is int
				or entries.has(row[symbol_field])
			):
				return failure
			entries[row[symbol_field]] = row[id_field]
		assignments[table_name] = entries
	var reconciliation_options: Dictionary = { "scope_tables": profile.stable_id_scope_tables, "restorations": profile.stable_id_restorations, }
	var preview: Dictionary = registry.preview(assignments, reconciliation_options)
	if not GFVariantData.get_option_bool(preview, "success"):
		failure["error"] = GFVariantData.get_option_string(preview, "error")
		return failure
	var candidate: GFConfigStableIDRegistry = registry.with_assignments(assignments, reconciliation_options)
	if candidate == null:
		return failure
	return {
		"success": true,
		"path": path,
		"digest": digest,
		"changes": preview["changes"],
		"candidate": candidate,
		"error": "",
	}


## 在外层产物事务已经捕获登记路径后写入候选；失败由调用方回滚整个事务。
## [br]
## @api framework_internal
## [br]
## @param plan: 本次 prepare_stable_ids 返回的计划，不能修改。
## [br]
## @schema plan: prepare_stable_ids 的成功结果；path非空且candidate有效。
## [br]
## @return 已写入且逐字节核对成功时为true；不负责结束外层事务。
func write_stable_ids(plan: Dictionary) -> bool:
	var path: String = GFVariantData.get_option_string(plan, "path")
	var raw: Variant = plan.get("candidate")
	if (
		path.is_empty()
		or not raw is GFConfigStableIDRegistry
		or not stable_ids_are_fresh(plan)
	):
		return false
	var registry: GFConfigStableIDRegistry = raw
	var bytes: PackedByteArray = (
		JSON.stringify(
			registry.to_record(),
			"\t",
			true
		) + "\n"
	).to_utf8_buffer()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_buffer(bytes)
	file.flush()
	var success: bool = stored and file.get_error() == OK
	file.close()
	return success and FileAccess.get_sha256(path) == _digest_bytes(bytes)


## 比较登记簿捕获后的原始字节，缺失状态同样参与校验。
## [br]
## @api framework_internal
## [br]
## @param plan: prepare_stable_ids 的结果。
## [br]
## @schema plan: Dictionary，path:String、digest:String。
## [br]
## @return 未启用或原文件仍一致时为true。
func stable_ids_are_fresh(plan: Dictionary) -> bool:
	var path: String = GFVariantData.get_option_string(plan, "path")
	if path.is_empty():
		return true
	var expected: String = GFVariantData.get_option_string(plan, "digest")
	return not FileAccess.file_exists(path) if expected == "missing" else not expected.is_empty() and FileAccess.get_sha256(path) == expected


## 捕获待写入路径的事务前状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param paths: 本次事务可能创建或覆盖的完整路径集合。
## [br]
## @param options: 框架级事务预算与允许根选项。
## [br]
## @return: 只能原样交给 complete() 或 rollback() 的 GFArtifactWriteTransaction 事务。
## [br]
## @schema options: Dictionary，必须包含非空 allowed_roots；可包含 max_file_count、max_backup_bytes 和 metadata。
## [br]
## @schema return: closed Dictionary，符合 gf.artifact_write.transaction@1，仅包含 ok、format、format_version、state、transaction_id、transaction_token、entry_count、backup_bytes、issues、recovery_required、recovery_action、recovery_transaction 和 metadata；事务身份及 recovery_transaction 均为不可改写的 opaque handle，不暴露目标或 sidecar 路径。失败且 recovery_required=true 时，按 recovery_action 终结 recovery_transaction。
func begin(paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(paths, options)


## 逆序恢复事务前状态；已存在文件恢复快照，事务中新建文件被删除。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param transaction: begin() 返回且仍处于 open 状态的原始事务字典。
## [br]
## @schema transaction: Dictionary，符合 gf.artifact_write.transaction@1。
## [br]
## @return: 回滚结果。
## [br]
## @schema return: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction。
func rollback(transaction: Dictionary) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)


## 完成事务并删除全部回滚快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param transaction: begin() 返回且仍处于 open 状态的原始事务字典。
## [br]
## @schema transaction: Dictionary，符合 gf.artifact_write.transaction@1。
## [br]
## @return: 提交完成结果。
## [br]
## @schema return: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction。
func complete(transaction: Dictionary) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、implementation_dependencies、input_contract 和 output_contract。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"implementation_dependencies": [
			"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd",
			"res://addons/gf/tools/config_pipeline/gf_config_stable_id_registry.gd",
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd",
		],
		"input_contract": "PackedStringArray",
		"output_contract": "%s@%d"
		% [_TRANSACTION_FORMAT, _TRANSACTION_VERSION],
	}


# --- 私有/辅助方法 ---

## 摘要绑定实际读取或写入的字节，避免另一次读取形成不同收据。
## [br]
## @api private
static func _digest_bytes(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(bytes) != OK:
		return ""
	return hashing.finish().hex_encode()
