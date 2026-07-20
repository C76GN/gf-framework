## GFSaveMigrationRegistry: 确定性存档迁移注册表。
##
## Registry 强制每个 schema/owner/from_version 只有一条相邻版本边，
## 在隔离副本上先执行文档迁移，再按 section_id 排序执行分区迁移。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 9.0.0
class_name GFSaveMigrationRegistry
extends RefCounted


# --- 私有变量 ---

var _steps: Dictionary = {}
var _step_ids: Dictionary = {}


# --- 公共方法 ---

## 注册唯一迁移步骤。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param step: 有效的相邻版本迁移步骤。
## [br]
## @return 步骤有效且 edge 与 step_id 均未占用时返回 true。
func register_step(step: GFSaveMigrationStep) -> bool:
	if step == null:
		return false
	var validation: Dictionary = step.validate_step()
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return false
	var duplicated_resource: Resource = step.duplicate(true)
	if not duplicated_resource is GFSaveMigrationStep:
		return false
	var stored_step: GFSaveMigrationStep = duplicated_resource
	var edge_key: String = _make_edge_key(
		stored_step.schema_id,
		stored_step.section_id,
		stored_step.from_version
	)
	if _steps.has(edge_key) or _step_ids.has(stored_step.step_id):
		return false
	_steps[edge_key] = stored_step
	_step_ids[stored_step.step_id] = edge_key
	return true


## 注销指定迁移边。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param schema_id: 项目 schema ID。
## [br]
## @param section_id: 分区 ID；为空表示文档级迁移。
## [br]
## @param from_version: 来源版本。
## [br]
## @return 原本存在时返回 true。
func unregister_step(
	schema_id: StringName,
	section_id: StringName,
	from_version: int
) -> bool:
	var edge_key: String = _make_edge_key(schema_id, section_id, from_version)
	var step: GFSaveMigrationStep = _get_step_by_key(edge_key)
	if step == null:
		return false
	var _id_erased: bool = _step_ids.erase(step.step_id)
	return _steps.erase(edge_key)


## 清空全部迁移步骤。
## [br]
## @api public
## [br]
## @since 9.0.0
func clear() -> void:
	_steps.clear()
	_step_ids.clear()


## 检查指定版本边是否存在。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param schema_id: 项目 schema ID。
## [br]
## @param section_id: 分区 ID；为空表示文档级迁移。
## [br]
## @param from_version: 来源版本。
## [br]
## @return 已注册时返回 true。
func has_step(
	schema_id: StringName,
	section_id: StringName,
	from_version: int
) -> bool:
	return _steps.has(_make_edge_key(schema_id, section_id, from_version))


## 获取排序后的步骤描述。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 步骤描述数组。
## [br]
## @schema return: Array[Dictionary] following GFSaveMigrationStep.describe_step().
func describe_steps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var edge_keys: PackedStringArray = _sorted_dictionary_keys(_steps)
	for edge_key: String in edge_keys:
		var step: GFSaveMigrationStep = _get_step_by_key(edge_key)
		if step != null:
			result.append(step.describe_step())
	return result


## 构建不执行迁移代码的路径计划。
##
## 计划只验证当前已存在的文档和分区版本边；文档步骤可能新增或移除的
## 分区仍会在真实迁移后的最终 schema 校验中判定。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param document: 来源文档。
## [br]
## @param target_schema: 目标 schema。
## [br]
## @return 静态迁移计划。
## [br]
## @schema return: Dictionary with ok, migration_required, requires_document_step_evaluation, source_document_version, target_document_version, source_section_versions, target_section_versions, steps, error, and missing_edge.
func build_plan(
	document: GFSaveDocument,
	target_schema: GFSaveDocumentSchema
) -> Dictionary:
	var plan: Dictionary = _make_plan_base(document, target_schema)
	var preflight_error: String = _get_preflight_error(document, target_schema)
	if not preflight_error.is_empty():
		plan["error"] = preflight_error
		return plan
	var steps: Array[Dictionary] = []
	var document_version: int = document.get_schema_version()
	var requires_document_step_evaluation: bool = document_version < target_schema.schema_version
	while document_version < target_schema.schema_version:
		var document_step: GFSaveMigrationStep = _get_step(
			target_schema.schema_id,
			&"",
			document_version
		)
		if document_step == null:
			plan["error"] = "Missing document migration edge: %d -> %d" % [document_version, document_version + 1]
			plan["missing_edge"] = _make_edge_descriptor(
				target_schema.schema_id,
				&"",
				document_version,
				document_version + 1
			)
			return plan
		steps.append(document_step.describe_step())
		document_version += 1
	if requires_document_step_evaluation:
		plan["ok"] = true
		plan["steps"] = steps
		plan["migration_required"] = not steps.is_empty()
		plan["requires_document_step_evaluation"] = true
		return plan
	for section_id_text: String in target_schema.get_section_ids():
		var section_id: StringName = StringName(section_id_text)
		var section: GFSaveSection = document.get_section(section_id)
		if section == null:
			continue
		var section_version: int = section.get_schema_version()
		var target_version: int = target_schema.get_section_version(section_id)
		if section_version > target_version:
			plan["error"] = "Section is newer than the target schema: %s %d > %d" % [section_id_text, section_version, target_version]
			return plan
		while section_version < target_version:
			var section_step: GFSaveMigrationStep = _get_step(
				target_schema.schema_id,
				section_id,
				section_version
			)
			if section_step == null:
				plan["error"] = "Missing section migration edge: %s %d -> %d" % [section_id_text, section_version, section_version + 1]
				plan["missing_edge"] = _make_edge_descriptor(
					target_schema.schema_id,
					section_id,
					section_version,
					section_version + 1
				)
				return plan
			steps.append(section_step.describe_step())
			section_version += 1
	plan["ok"] = true
	plan["steps"] = steps
	plan["migration_required"] = not steps.is_empty()
	plan["requires_document_step_evaluation"] = false
	return plan


## 把文档事务式迁移到目标 schema。
##
## 迁移期间只操作副本；所有步骤和最终 schema 校验成功后才在结果中暴露文档。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param document: 来源文档。
## [br]
## @param target_schema: 目标 schema。
## [br]
## @param context: 项目定义的迁移上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral migration data.
## [br]
## @return 迁移终态结果。
func migrate(
	document: GFSaveDocument,
	target_schema: GFSaveDocumentSchema,
	context: Dictionary = {}
) -> GFSaveMigrationResult:
	var plan: Dictionary = build_plan(document, target_schema)
	if not GFVariantData.get_option_bool(plan, "ok", false):
		return _make_failure(
			document,
			target_schema,
			ERR_DOES_NOT_EXIST,
			GFVariantData.get_option_string(plan, "error", "Save migration preflight failed."),
			&"",
			[]
		)
	var current: GFSaveDocument = document.duplicate_document()
	var trace: Array[Dictionary] = []
	while current.get_schema_version() < target_schema.schema_version:
		var document_step: GFSaveMigrationStep = _get_step(
			target_schema.schema_id,
			&"",
			current.get_schema_version()
		)
		var document_result: GFSaveDocument = document_step._migrate_document(
			current.duplicate_document(),
			_make_step_context(context, document_step)
		)
		if document_result == null:
			return _make_failure(
				document,
				target_schema,
				FAILED,
				"Document migration step returned null.",
				document_step.step_id,
				trace
			)
		if document_result.get_schema_id() != target_schema.schema_id:
			return _make_failure(
				document,
				target_schema,
				ERR_INVALID_DATA,
				"Document migration step changed schema_id.",
				document_step.step_id,
				trace
			)
		var section_version_error: String = _get_document_step_section_version_error(
			current,
			document_result
		)
		if not section_version_error.is_empty():
			return _make_failure(
				document,
				target_schema,
				ERR_INVALID_DATA,
				section_version_error,
				document_step.step_id,
				trace
			)
		var canonical_document: GFSaveDocument = GFSaveDocument.new().configure(
			target_schema.schema_id,
			document_step.to_version,
			document_result.get_sections(),
			document_result.get_metadata()
		)
		var document_validation: Dictionary = canonical_document.validate_document()
		if not GFVariantData.get_option_bool(document_validation, "ok", false):
			return _make_failure(
				document,
				target_schema,
				ERR_INVALID_DATA,
				_get_first_validation_message(document_validation, "Document migration produced invalid data."),
				document_step.step_id,
				trace
			)
		current = canonical_document
		trace.append(document_step.describe_step())
	for section_id_text: String in target_schema.get_section_ids():
		var section_id: StringName = StringName(section_id_text)
		var current_section: GFSaveSection = current.get_section(section_id)
		if current_section == null:
			continue
		var target_version: int = target_schema.get_section_version(section_id)
		if current_section.get_schema_version() > target_version:
			return _make_failure(
				document,
				target_schema,
				ERR_FILE_UNRECOGNIZED,
				"Section is newer than the target schema: %s" % section_id_text,
				&"",
				trace
			)
		while current_section.get_schema_version() < target_version:
			var section_step: GFSaveMigrationStep = _get_step(
				target_schema.schema_id,
				section_id,
				current_section.get_schema_version()
			)
			if section_step == null:
				return _make_failure(
					document,
					target_schema,
					ERR_DOES_NOT_EXIST,
					"Section migration edge disappeared after preflight: %s" % section_id_text,
					&"",
					trace
				)
			var section_result: GFSaveSection = section_step._migrate_section(
				current_section.duplicate_section(),
				_make_step_context(context, section_step)
			)
			if section_result == null:
				return _make_failure(
					document,
					target_schema,
					FAILED,
					"Section migration step returned null.",
					section_step.step_id,
					trace
				)
			if section_result.get_section_id() != section_id:
				return _make_failure(
					document,
					target_schema,
					ERR_INVALID_DATA,
					"Section migration step changed section_id.",
					section_step.step_id,
					trace
				)
			var canonical_section: GFSaveSection = GFSaveSection.new().configure(
				section_id,
				section_step.to_version,
				section_result.get_payload(),
				section_result.get_metadata()
			)
			var section_validation: Dictionary = canonical_section.validate_section()
			if not GFVariantData.get_option_bool(section_validation, "ok", false):
				return _make_failure(
					document,
					target_schema,
					ERR_INVALID_DATA,
					_get_first_validation_message(section_validation, "Section migration produced invalid data."),
					section_step.step_id,
					trace
				)
			if not current.set_section(canonical_section):
				return _make_failure(
					document,
					target_schema,
					ERR_INVALID_DATA,
					"Section migration result could not be committed.",
					section_step.step_id,
					trace
				)
			current_section = canonical_section
			trace.append(section_step.describe_step())
	var final_validation: Dictionary = target_schema.validate_document(current, true)
	if not GFVariantData.get_option_bool(final_validation, "ok", false):
		return _make_failure(
			document,
			target_schema,
			ERR_INVALID_DATA,
			_get_first_validation_message(final_validation, "Migrated document does not match the target schema."),
			&"",
			trace
		)
	return _make_success(document, current, target_schema, trace)


# --- 私有/辅助方法 ---

func _get_preflight_error(
	document: GFSaveDocument,
	target_schema: GFSaveDocumentSchema
) -> String:
	if document == null:
		return "Save document is required."
	if target_schema == null:
		return "Target save document schema is required."
	var schema_validation: Dictionary = target_schema.validate_schema()
	if not GFVariantData.get_option_bool(schema_validation, "ok", false):
		return _get_first_validation_message(schema_validation, "Target schema is invalid.")
	var document_validation: Dictionary = document.validate_document()
	if not GFVariantData.get_option_bool(document_validation, "ok", false):
		return _get_first_validation_message(document_validation, "Save document is invalid.")
	if document.get_schema_id() != target_schema.schema_id:
		return "Save document schema_id does not match the target schema."
	if document.get_schema_version() > target_schema.schema_version:
		return "Save document is newer than the target schema."
	return ""


func _make_plan_base(
	document: GFSaveDocument,
	target_schema: GFSaveDocumentSchema
) -> Dictionary:
	return {
		"ok": false,
		"migration_required": false,
		"source_document_version": document.get_schema_version() if document != null else 0,
		"target_document_version": target_schema.schema_version if target_schema != null else 0,
		"source_section_versions": _get_section_versions(document),
		"target_section_versions": target_schema.section_versions.duplicate(true) if target_schema != null else {},
		"steps": [],
		"error": "",
		"missing_edge": {},
		"requires_document_step_evaluation": false,
	}


func _make_success(
	source_document: GFSaveDocument,
	target_document: GFSaveDocument,
	target_schema: GFSaveDocumentSchema,
	trace: Array[Dictionary]
) -> GFSaveMigrationResult:
	var result: GFSaveMigrationResult = GFSaveMigrationResult.new()
	result._gf_configure(
		true,
		target_document,
		OK,
		"",
		&"",
		source_document.get_schema_version(),
		target_schema.schema_version,
		_get_section_versions(source_document),
		_get_section_versions(target_document),
		trace
	)
	return result


func _make_failure(
	source_document: GFSaveDocument,
	target_schema: GFSaveDocumentSchema,
	error_code: Error,
	error: String,
	failed_step_id: StringName,
	trace: Array[Dictionary]
) -> GFSaveMigrationResult:
	var result: GFSaveMigrationResult = GFSaveMigrationResult.new()
	result._gf_configure(
		false,
		null,
		error_code,
		error,
		failed_step_id,
		source_document.get_schema_version() if source_document != null else 0,
		target_schema.schema_version if target_schema != null else 0,
		_get_section_versions(source_document),
		target_schema.section_versions if target_schema != null else {},
		trace
	)
	return result


func _get_step(
	schema_id: StringName,
	section_id: StringName,
	from_version: int
) -> GFSaveMigrationStep:
	return _get_step_by_key(_make_edge_key(schema_id, section_id, from_version))


func _get_step_by_key(edge_key: String) -> GFSaveMigrationStep:
	var value: Variant = GFVariantData.get_option_value(_steps, edge_key)
	if value is GFSaveMigrationStep:
		var step: GFSaveMigrationStep = value
		return step
	return null


func _make_step_context(context: Dictionary, step: GFSaveMigrationStep) -> Dictionary:
	var result: Dictionary = context.duplicate(true)
	result["migration_step_id"] = step.step_id
	result["migration_schema_id"] = step.schema_id
	result["migration_section_id"] = step.section_id
	result["migration_from_version"] = step.from_version
	result["migration_to_version"] = step.to_version
	return result


func _get_section_versions(document: GFSaveDocument) -> Dictionary:
	var result: Dictionary = {}
	if document == null:
		return result
	for section_id_text: String in document.get_section_ids():
		var section: GFSaveSection = document.get_section(StringName(section_id_text))
		if section != null:
			result[StringName(section_id_text)] = section.get_schema_version()
	return result


func _get_document_step_section_version_error(
	before: GFSaveDocument,
	after: GFSaveDocument
) -> String:
	for section_id_text: String in before.get_section_ids():
		var section_id: StringName = StringName(section_id_text)
		var before_section: GFSaveSection = before.get_section(section_id)
		var after_section: GFSaveSection = after.get_section(section_id)
		if before_section == null or after_section == null:
			continue
		if before_section.get_schema_version() != after_section.get_schema_version():
			return "Document migration must not change an existing section schema version: %s" % section_id_text
	return ""


func _get_first_validation_message(report: Dictionary, fallback: String) -> String:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	if issues.is_empty():
		return fallback
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	return GFVariantData.get_option_string(first_issue, "message", fallback)


static func _make_edge_key(
	schema_id: StringName,
	section_id: StringName,
	from_version: int
) -> String:
	var owner_key: String = "$document" if section_id == &"" else String(section_id)
	return "%s|%s|%d" % [String(schema_id), owner_key, from_version]


static func _make_edge_descriptor(
	schema_id: StringName,
	section_id: StringName,
	from_version: int,
	to_version: int
) -> Dictionary:
	return {
		"schema_id": schema_id,
		"section_id": section_id,
		"scope": &"document" if section_id == &"" else &"section",
		"from_version": from_version,
		"to_version": to_version,
	}


static func _sorted_dictionary_keys(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var text: String = GFVariantData.to_text(key)
		if not text.is_empty() and not result.has(text):
			var _appended: bool = result.append(text)
	result.sort()
	return result
