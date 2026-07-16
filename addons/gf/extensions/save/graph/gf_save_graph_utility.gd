## GFSaveGraphUtility: 通用节点存档图编排工具。
##
## 负责遍历 GFSaveScope/GFSaveSource，采集、应用和落盘存档图。具体数据结构
## 由 Source、Serializer 或项目继承类决定，Utility 本身不绑定业务字段。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSaveGraphUtility
extends GFUtility


# --- 常量 ---

## 存档图载荷格式标识。
## [br]
## @api public
const FORMAT_ID: String = "gf_save_graph"

## 当前存档图载荷格式版本。
## [br]
## @api public
const FORMAT_VERSION: int = 1

const _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _GF_SAVE_PERSISTED_VALUE_VALIDATOR = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")
const _CREATED_ENTITIES_CONTEXT_KEY: String = "_gf_save_graph_created_entities"
const _SOURCE_SNAPSHOTS_CONTEXT_KEY: String = "_gf_save_graph_source_snapshots"
const _TRANSACTION_BOUNDARY_CONTEXT_KEY: String = "_gf_save_graph_transaction_boundary"
const _AFTER_LOAD_QUEUE_CONTEXT_KEY: String = "_gf_save_graph_after_load_queue"


# --- 公共变量 ---

## 节点序列化器注册表。
## [br]
## @api public
var serializer_registry: GFNodeSerializerRegistry = GFNodeSerializerRegistry.new()

## 存档图流程步骤。按数组顺序执行，适合压缩前校验、调试标记、版本适配等通用处理。
## [br]
## @api public
var pipeline_steps: Array[GFSavePipelineStep] = []


# --- 私有变量 ---

var _entity_factories: Dictionary = {}


# --- 公共方法 ---

## 注册实体工厂。
## [br]
## @api public
## [br]
## @param factory: 实体工厂。
func register_entity_factory(factory: GFSaveEntityFactory) -> void:
	if factory == null:
		return

	var type_key: StringName = factory.get_type_key()
	if type_key == &"":
		return
	_entity_factories[type_key] = factory


## 注销实体工厂。
## [br]
## @api public
## [br]
## @param type_key: 实体类型键。
func unregister_entity_factory(type_key: StringName) -> void:
	_erase_dictionary_key(_entity_factories, type_key)


## 清空实体工厂。
## [br]
## @api public
func clear_entity_factories() -> void:
	_entity_factories.clear()


## 添加存档流程步骤。
## [br]
## @api public
## [br]
## @param step: 流程步骤。
func add_pipeline_step(step: GFSavePipelineStep) -> void:
	if step == null or pipeline_steps.has(step):
		return
	pipeline_steps.append(step)


## 移除存档流程步骤。
## [br]
## @api public
## [br]
## @param step: 流程步骤。
func remove_pipeline_step(step: GFSavePipelineStep) -> void:
	_erase_pipeline_step(step)


## 清空存档流程步骤。
## [br]
## @api public
func clear_pipeline_steps() -> void:
	pipeline_steps.clear()


## 创建存档流程上下文。
## [br]
## @api public
## [br]
## @param operation: 操作类型。
## [br]
## @param scope: 可选根 Scope。
## [br]
## @param shared: 初始共享数据。
## [br]
## @schema shared: Dictionary，流程共享数据，可由步骤写入调试标记、迁移状态或项目自定义键。
## [br]
## @return 新上下文。
func create_pipeline_context(
	operation: StringName,
	scope: GFSaveScope = null,
	shared: Dictionary = {}
) -> GFSavePipelineContext:
	var root_scope_key: StringName = _get_scope_key_for_inspection(scope) if scope != null else &""
	return GFSavePipelineContext.new(operation, root_scope_key, shared)


## 检查 Scope 树的可保存结构。
## [br]
## @api public
## [br]
## @param scope: 根 Scope。
## [br]
## @param context: 调用上下文字典。
## [br]
## @schema context: Dictionary，可包含诊断调用方自定义键，不会被 Utility 写入私有状态。
## [br]
## @return 诊断报告。
## [br]
## @schema return: Dictionary，包含 ok、healthy、scope_key、计数字段、issue_counts_by_kind、summary、next_action、scopes、sources 与 issues。
func inspect_scope(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"healthy": true,
		"scope_key": String(_get_scope_key_for_inspection(scope)) if scope != null else "",
		"scope_count": 0,
		"source_count": 0,
		"enabled_scope_count": 0,
		"enabled_source_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"issue_counts_by_kind": {},
		"summary": "",
		"next_action": "",
		"scopes": [],
		"sources": [],
		"issues": [],
	}
	if scope == null:
		_append_diagnostic_issue(report, "error", "null_scope", "", "", "Scope is null.")
		report["ok"] = false
		return _finalize_diagnostic_report(report, "Save scope")

	_inspect_scope_recursive(scope, context, report, String(_get_scope_key_for_inspection(scope)))
	report["ok"] = _report_has_no_error_issues(report)
	return _finalize_diagnostic_report(report, "Save scope")


## 构建 Scope 健康报告。
## [br]
## @api public
## [br]
## @param scope: 根 Scope。
## [br]
## @param context: 调用上下文字典。
## [br]
## @schema context: Dictionary，可包含诊断调用方自定义键，不会被 Utility 写入私有状态。
## [br]
## @return 含 summary、next_action 与 issue 统计的诊断报告。
## [br]
## @schema return: Dictionary，结构与 inspect_scope 的返回诊断报告一致。
func build_scope_health_report(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:
	return inspect_scope(scope, context)


## 校验载荷是否能匹配当前 Scope 树。
## [br]
## @api public
## [br]
## @param scope: 根 Scope。
## [br]
## @param payload: 待校验载荷。
## [br]
## @param strict: 为 true 时把缺失 Source/Scope 视为错误；否则视为警告。
## [br]
## @schema payload: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
## [br]
## @return 诊断报告。
## [br]
## @schema return: Dictionary，包含 ok、healthy、scope_key、checked_source_count、checked_scope_count、missing、issues、summary 与 next_action。
func validate_payload_for_scope(scope: GFSaveScope, payload: Dictionary, strict: bool = false) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"healthy": true,
		"scope_key": String(_get_scope_key_for_inspection(scope)) if scope != null else "",
		"checked_source_count": 0,
		"checked_scope_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"issue_counts_by_kind": {},
		"summary": "",
		"next_action": "",
		"missing": [],
		"issues": [],
	}
	if scope == null:
		_append_diagnostic_issue(report, "error", "null_scope", "", "", "Scope is null.")
		report["ok"] = false
		return _finalize_diagnostic_report(report, "Save payload")
	if payload.is_empty():
		_append_diagnostic_issue(report, "error", "empty_payload", String(_get_scope_key_for_inspection(scope)), _get_node_debug_path(scope), "Payload is empty.")
		report["ok"] = false
		return _finalize_diagnostic_report(report, "Save payload")

	if GFVariantData.get_option_string(payload, "format") != FORMAT_ID:
		_append_diagnostic_issue(report, "error", "format_mismatch", String(_get_scope_key_for_inspection(scope)), _get_node_debug_path(scope), "Payload format does not match GF save graph.")
	if GFVariantData.get_option_int(payload, "format_version", -1) > FORMAT_VERSION:
		_append_diagnostic_issue(report, "error", "future_format_version", String(_get_scope_key_for_inspection(scope)), _get_node_debug_path(scope), "Payload format version is newer than this utility.")

	_validate_payload_scope_recursive(scope, payload, strict, report, String(_get_scope_key_for_inspection(scope)))
	report["ok"] = _report_has_no_error_issues(report)
	return _finalize_diagnostic_report(report, "Save payload")


## 构建载荷匹配健康报告。
## [br]
## @api public
## [br]
## @param scope: 根 Scope。
## [br]
## @param payload: 待校验载荷。
## [br]
## @param strict: 为 true 时把缺失 Source/Scope 视为错误；否则视为警告。
## [br]
## @schema payload: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
## [br]
## @return 含 summary、next_action 与 issue 统计的诊断报告。
## [br]
## @schema return: Dictionary，结构与 validate_payload_for_scope 的返回诊断报告一致。
func build_payload_health_report(scope: GFSaveScope, payload: Dictionary, strict: bool = false) -> Dictionary:
	return validate_payload_for_scope(scope, payload, strict)


## 采集 Scope 存档图。
## [br]
## @api public
## [br]
## @param scope: 根 Scope。
## [br]
## @param context: 调用上下文字典。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @return 存档载荷。
## [br]
## @schema return: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
func gather_scope(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:
	if scope == null or not scope._can_save_scope(context):
		return {}

	var owns_pipeline_context: bool = not _has_pipeline_context(context)
	context = _ensure_pipeline_context(context, &"gather", scope)
	var pipeline_context: GFSavePipelineContext = _get_pipeline_context(context)
	if owns_pipeline_context:
		_record_pipeline_event(pipeline_context, &"gather_started", scope)

	_run_before_gather_steps(scope, context)
	_record_pipeline_event(pipeline_context, &"gather_scope_started", scope)
	scope._before_save(context)
	var payload: Dictionary = {
		"format": FORMAT_ID,
		"format_version": FORMAT_VERSION,
		"scope": scope.describe_scope(),
		"sources": {},
		"scopes": {},
	}
	var source_payloads: Dictionary = GFVariantData.as_dictionary(payload["sources"])
	var child_payloads: Dictionary = GFVariantData.as_dictionary(payload["scopes"])

	for source: GFSaveSource in _get_sources_for_scope(scope):
		if not source._can_save_source(context):
			continue

		var reference_root_state: Dictionary = _push_reference_root_context(context, scope)
		source._before_save(context)
		var source_key: String = _make_scoped_source_key(scope, source)
		if source_payloads.has(source_key):
			var duplicate_source_error: String = "[GFSaveGraphUtility] gather_scope 失败：同一 Scope 内存在重复 Source key：%s" % source_key
			push_error(duplicate_source_error)
			pipeline_context.add_error(duplicate_source_error, {
				"scope_key": String(scope.get_scope_key()),
				"source_key": source_key,
			})
			_pop_reference_root_context(context, reference_root_state)
			return {}
		var descriptor: Dictionary = source.describe_source(scope)
		_merge_identity_descriptor(source, descriptor)
		_record_pipeline_event(pipeline_context, &"gather_source_started", scope, source, "", {
			"source_key": source_key,
		})
		source_payloads[source_key] = {
			"descriptor": descriptor,
			"data": source._gather_save_data(context, serializer_registry),
		}
		_pop_reference_root_context(context, reference_root_state)
		_record_pipeline_event(pipeline_context, &"gather_source_finished", scope, source, "", {
			"source_key": source_key,
		})

	for child_scope: GFSaveScope in _get_child_scopes(scope):
		if not child_scope._can_save_scope(context):
			continue
		var child_payload: Dictionary = gather_scope(child_scope, context)
		if child_payload.is_empty():
			var child_gather_error: String = "[GFSaveGraphUtility] gather_scope 失败：子 Scope 采集失败：%s" % String(child_scope.get_scope_key())
			push_error(child_gather_error)
			pipeline_context.add_error(child_gather_error, {
				"scope_key": String(scope.get_scope_key()),
				"child_scope_key": String(child_scope.get_scope_key()),
			})
			return {}
		var child_key: String = String(child_scope.get_scope_key())
		if child_payloads.has(child_key):
			var duplicate_child_error: String = "[GFSaveGraphUtility] gather_scope 失败：同一 Scope 内存在重复子 Scope key：%s" % child_key
			push_error(duplicate_child_error)
			pipeline_context.add_error(duplicate_child_error, {
				"scope_key": String(scope.get_scope_key()),
				"child_scope_key": child_key,
			})
			return {}
		child_payloads[child_key] = child_payload

	scope._after_save(payload, context)
	var final_payload: Dictionary = _run_after_gather_steps(scope, payload, context)
	_record_pipeline_event(pipeline_context, &"gather_scope_finished", scope, null, "", {
		"source_count": _get_dictionary_field(final_payload, "sources").size(),
		"scope_count": _get_dictionary_field(final_payload, "scopes").size(),
	})
	if owns_pipeline_context:
		pipeline_context.finish()
		if GFVariantData.get_option_bool(context, "include_pipeline_trace", false):
			final_payload["pipeline_trace"] = pipeline_context.to_dict(true)
	return final_payload


## 应用 Scope 存档图。
## [br]
## @api public
## [br]
## @param scope: 根 Scope。
## [br]
## @param payload: 存档载荷。
## [br]
## @param context: 调用上下文字典。
## [br]
## @param strict: 为 true 时缺失 Source/Scope 会记录错误。
## [br]
## @schema payload: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @return 结果字典。
## [br]
## @schema return: Dictionary，包含 ok、applied、errors、missing，可选 pipeline_trace。
func apply_scope(
	scope: GFSaveScope,
	payload: Dictionary,
	context: Dictionary = {},
	strict: bool = false
) -> Dictionary:
	if scope == null:
		return _make_apply_result(false, 0, ["Scope is null."], [])
	if payload.is_empty():
		return _make_apply_result(false, 0, ["Save payload is empty."], [])
	if not scope._can_load_scope(context):
		return _make_apply_result(true, 0, [], [])

	var owns_pipeline_context: bool = not _has_pipeline_context(context)
	context = _ensure_pipeline_context(context, &"apply", scope)
	var pipeline_context: GFSavePipelineContext = _get_pipeline_context(context)
	var owns_created_entities: bool = not context.has(_CREATED_ENTITIES_CONTEXT_KEY)
	if owns_created_entities:
		context[_CREATED_ENTITIES_CONTEXT_KEY] = []
	var owns_source_snapshots: bool = not context.has(_SOURCE_SNAPSHOTS_CONTEXT_KEY)
	if owns_source_snapshots:
		context[_SOURCE_SNAPSHOTS_CONTEXT_KEY] = []
	var owns_transaction_boundary: bool = not context.has(_TRANSACTION_BOUNDARY_CONTEXT_KEY)
	if owns_transaction_boundary:
		context[_TRANSACTION_BOUNDARY_CONTEXT_KEY] = true
		context[_AFTER_LOAD_QUEUE_CONTEXT_KEY] = []
	if owns_pipeline_context:
		_record_pipeline_event(pipeline_context, &"apply_started", scope)

	payload = _run_before_apply_steps(scope, payload, context)
	_record_pipeline_event(pipeline_context, &"apply_scope_started", scope)
	var applied: int = 0
	var errors: Array[String] = []
	var missing: Array[String] = []
	_append_apply_format_errors(payload, errors, pipeline_context)
	_append_apply_scope_descriptor_errors(scope, payload, errors, pipeline_context)
	if not errors.is_empty():
		return _finalize_apply_scope(
			scope,
			payload,
			_make_apply_result(false, applied, errors, missing),
			context,
			pipeline_context,
			owns_pipeline_context,
			owns_created_entities,
			owns_source_snapshots,
			owns_transaction_boundary
		)
	var source_payloads: Dictionary = _get_payload_dictionary_field(
		payload,
		"sources",
		errors,
		pipeline_context,
		"invalid_sources_payload"
	)
	var child_payloads: Dictionary = _get_payload_dictionary_field(
		payload,
		"scopes",
		errors,
		pipeline_context,
		"invalid_scopes_payload"
	)
	if not errors.is_empty():
		return _finalize_apply_scope(
			scope,
			payload,
			_make_apply_result(false, applied, errors, missing),
			context,
			pipeline_context,
			owns_pipeline_context,
			owns_created_entities,
			owns_source_snapshots,
			owns_transaction_boundary
		)

	_append_apply_preflight_errors(
		scope,
		source_payloads,
		child_payloads,
		strict,
		errors,
		missing,
		pipeline_context,
		String(_get_scope_key_for_inspection(scope))
	)
	if not errors.is_empty():
		return _finalize_apply_scope(
			scope,
			payload,
			_make_apply_result(false, applied, errors, missing),
			context,
			pipeline_context,
			owns_pipeline_context,
			owns_created_entities,
			owns_source_snapshots,
			owns_transaction_boundary
		)

	scope._before_load(payload, context)
	var source_index: Dictionary = _index_sources_by_key_for_inspection(scope)
	var source_keys: Array = source_payloads.keys()
	source_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _compare_source_payload_keys(left, right, source_payloads)
	)
	var loaded_sources: Array[Dictionary] = []

	for source_key_variant: Variant in source_keys:
		var source_key: String = str(source_key_variant)
		if not (source_payloads[source_key_variant] is Dictionary):
			var invalid_source_error: String = "Invalid source payload: %s" % source_key
			errors.append(invalid_source_error)
			pipeline_context.add_error(invalid_source_error, { "source_key": source_key })
			continue

		var source_payload: Dictionary = GFVariantData.as_dictionary(source_payloads[source_key_variant])
		var source: GFSaveSource = _get_save_source_value(GFVariantData.get_option_value(source_index, source_key))
		if source == null:
			source = _try_create_source_from_payload(scope, source_payload, context, source_key)
			if source != null:
				source_index[source_key] = source

		if source == null:
			missing.append(source_key)
			if strict:
				var missing_source_error: String = "Missing source: %s" % source_key
				errors.append(missing_source_error)
				pipeline_context.add_error(missing_source_error, { "source_key": source_key })
			else:
				_record_pipeline_event(pipeline_context, &"apply_source_missing", scope, null, "", {
					"source_key": source_key,
				}, &"warning")
			continue
		var reference_root_state: Dictionary = _push_reference_root_context(context, scope)
		if not source._can_load_source(context):
			_pop_reference_root_context(context, reference_root_state)
			continue

		_track_source_snapshot(context, source)
		_record_pipeline_event(pipeline_context, &"apply_source_started", scope, source, "", {
			"source_key": source_key,
		})
		var source_data: Variant = GFVariantData.get_option_value(source_payload, "data")
		var result: Dictionary = GFVariantData.as_dictionary(source._apply_save_data(source_data, context, serializer_registry))
		if GFVariantData.get_option_bool(result, "ok", false):
			applied += 1
			loaded_sources.append({
				"source": source,
				"data": GFVariantData.duplicate_variant(source_data),
			})
			_record_pipeline_event(pipeline_context, &"apply_source_finished", scope, source, "", {
				"source_key": source_key,
			})
		else:
			var source_errors: Array = GFVariantData.as_array(GFVariantData.get_option_value(result, "errors", []))
			if source_errors.is_empty():
				source_errors = [GFVariantData.get_option_string(result, "error", "Apply failed")]
			for source_error_variant: Variant in source_errors:
				var source_error: String = "%s: %s" % [source_key, str(source_error_variant)]
				errors.append(source_error)
				pipeline_context.add_error(source_error, { "source_key": source_key })
		_pop_reference_root_context(context, reference_root_state)

	var child_scope_index: Dictionary = _index_child_scopes_for_inspection(scope)
	var child_keys: Array = child_payloads.keys()
	child_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _compare_scope_payload_keys(left, right, child_payloads)
	)
	for child_key_variant: Variant in child_keys:
		var child_key: String = str(child_key_variant)
		var child_scope: GFSaveScope = _get_save_scope_value(GFVariantData.get_option_value(child_scope_index, child_key))
		if child_scope == null:
			missing.append(child_key)
			if strict:
				var missing_scope_error: String = "Missing scope: %s" % child_key
				errors.append(missing_scope_error)
				pipeline_context.add_error(missing_scope_error, { "scope_key": child_key })
			else:
				_record_pipeline_event(pipeline_context, &"apply_scope_missing", scope, null, "", {
					"scope_key": child_key,
				}, &"warning")
			continue

		if not (child_payloads[child_key_variant] is Dictionary):
			var invalid_child_error: String = "Invalid child scope payload: %s" % child_key
			errors.append(invalid_child_error)
			pipeline_context.add_error(invalid_child_error, { "scope_key": child_key })
			continue

		var child_payload: Dictionary = GFVariantData.as_dictionary(child_payloads[child_key_variant])
		var child_result: Dictionary = apply_scope(child_scope, child_payload, context, strict)
		applied += GFVariantData.get_option_int(child_result, "applied")
		for error: String in GFVariantData.to_string_array(GFVariantData.get_option_value(child_result, "errors", [])):
			errors.append(error)
		for missing_key: String in GFVariantData.to_string_array(GFVariantData.get_option_value(child_result, "missing", [])):
			missing.append("%s/%s" % [child_key, missing_key])

	if errors.is_empty() and owns_transaction_boundary:
		_append_transaction_participant_errors(pipeline_context, context, &"prepare", errors)
	if errors.is_empty() and owns_transaction_boundary:
		_append_transaction_participant_errors(pipeline_context, context, &"commit", errors)
	if errors.is_empty():
		_queue_after_load_callbacks(context, loaded_sources, scope, payload)
	return _finalize_apply_scope(
		scope,
		payload,
		_make_apply_result(errors.is_empty(), applied, errors, missing),
		context,
		pipeline_context,
		owns_pipeline_context,
		owns_created_entities,
		owns_source_snapshots,
		owns_transaction_boundary
	)


## 采集并保存 Scope。
## [br]
## @api public
## [br]
## @param file_name: 目标文件名。
## [br]
## @param scope: 根 Scope。
## [br]
## @param metadata: 附加元信息。
## [br]
## @param context: 调用上下文字典。
## [br]
## @schema metadata: Dictionary，写入载荷 metadata 字段的项目元信息。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 及项目自定义键。
## [br]
## @return Godot 错误码。
func save_scope(
	file_name: String,
	scope: GFSaveScope,
	metadata: Dictionary = {},
	context: Dictionary = {}
) -> Error:
	var storage: GFStorageUtility = _get_storage_utility()
	if storage == null:
		return ERR_UNCONFIGURED
	var metadata_validation: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(metadata)
	if not GFVariantData.get_option_bool(metadata_validation, "ok", false):
		_push_persisted_validation_error("payload.metadata", metadata_validation)
		return ERR_INVALID_DATA

	var payload: Dictionary = gather_scope(scope, context)
	if payload.is_empty():
		return ERR_INVALID_DATA
	if not metadata.is_empty():
		payload["metadata"] = metadata.duplicate(true)
	var payload_validation: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(payload)
	if not GFVariantData.get_option_bool(payload_validation, "ok", false):
		_push_persisted_validation_error("payload", payload_validation)
		return ERR_INVALID_DATA
	return storage.save_data(file_name, payload)


## 从文件读取并应用 Scope。
## [br]
## @api public
## [br]
## @param file_name: 目标文件名。
## [br]
## @param scope: 根 Scope。
## [br]
## @param context: 调用上下文字典。
## [br]
## @param strict: 为 true 时缺失 Source/Scope 会记录错误。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @return 结果字典。
## [br]
## @schema return: Dictionary，包含 ok、applied、errors、missing，可选 pipeline_trace。
func load_scope(
	file_name: String,
	scope: GFSaveScope,
	context: Dictionary = {},
	strict: bool = false
) -> Dictionary:
	var storage: GFStorageUtility = _get_storage_utility()
	if storage == null:
		return _make_apply_result(false, 0, ["GFStorageUtility is not registered."], [])

	var payload: Dictionary = storage.load_data(file_name)
	if payload.is_empty():
		return _make_apply_result(false, 0, ["Save payload is empty."], [])
	var validation_report: Dictionary = validate_payload_for_scope(scope, payload, strict)
	if not GFVariantData.get_option_bool(validation_report, "ok", false):
		return _make_apply_result(
			false,
			0,
			_get_validation_error_messages(validation_report),
			GFVariantData.to_string_array(GFVariantData.get_option_value(validation_report, "missing", []))
		)
	return apply_scope(scope, payload, context, strict)


# --- 私有/辅助方法 ---

func _get_non_empty_string_name(value: Variant, fallback: StringName = &"") -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return fallback if string_name_value == &"" else string_name_value
	if value is String:
		var text_value: String = value
		var trimmed_value: String = text_value.strip_edges()
		return fallback if trimmed_value.is_empty() else StringName(trimmed_value)
	return fallback


func _get_node_path_value(value: Variant) -> NodePath:
	if value is NodePath:
		return value
	if value is String or value is StringName:
		return NodePath(GFVariantData.to_text(value))
	return NodePath("")


func _get_node_value(value: Variant) -> Node:
	if not is_instance_valid(value):
		return null
	if value is Node:
		return value
	return null


func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		return value
	return null


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _get_save_source_value(value: Variant) -> GFSaveSource:
	if value is GFSaveSource:
		return value
	return null


func _get_save_scope_value(value: Variant) -> GFSaveScope:
	if value is GFSaveScope:
		return value
	return null


func _get_save_identity_value(value: Variant) -> GFSaveIdentity:
	if value is GFSaveIdentity:
		return value
	return null


func _get_entity_factory_value(value: Variant) -> GFSaveEntityFactory:
	if value is GFSaveEntityFactory:
		return value
	return null


func _get_pipeline_context_value(value: Variant) -> GFSavePipelineContext:
	if value is GFSavePipelineContext:
		return value
	return null


func _push_reference_root_context(context: Dictionary, scope: GFSaveScope) -> Dictionary:
	var had_key: bool = context.has(GFVariantReferenceCodec.OPTION_ROOT_NODE)
	var previous_value: Variant = GFVariantData.get_option_value(context, GFVariantReferenceCodec.OPTION_ROOT_NODE)
	context[GFVariantReferenceCodec.OPTION_ROOT_NODE] = scope
	return {
		"had_key": had_key,
		"value": previous_value,
	}


func _pop_reference_root_context(context: Dictionary, state: Dictionary) -> void:
	if GFVariantData.get_option_bool(state, "had_key", false):
		context[GFVariantReferenceCodec.OPTION_ROOT_NODE] = GFVariantData.get_option_value(state, "value")
	else:
		var _erased_reference_root: bool = context.erase(GFVariantReferenceCodec.OPTION_ROOT_NODE)


func _get_storage_utility_value(value: Variant) -> GFStorageUtility:
	if value is GFStorageUtility:
		return value
	return null


func _get_dictionary_field(source: Dictionary, key: Variant, fallback: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(source, key, fallback))


func _read_object_property(object: Object, property_name: StringName, fallback: Variant = null) -> Variant:
	return GFObjectPropertyTools.read_property(object, NodePath(String(property_name)), fallback)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _append_dictionary_array_field(target: Dictionary, field_name: String, value: Variant) -> void:
	var values: Array = GFVariantData.as_array(GFVariantData.get_option_value(target, field_name, []))
	values.append(value)
	target[field_name] = values


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _erase_pipeline_step(step: GFSavePipelineStep) -> void:
	pipeline_steps.erase(step)


func _record_pipeline_event(
	pipeline_context: GFSavePipelineContext,
	stage: StringName,
	scope: Object = null,
	source: Object = null,
	message: String = "",
	payload: Dictionary = {},
	severity: StringName = &"info"
) -> void:
	if pipeline_context == null:
		return
	var event: GFSavePipelineEvent = pipeline_context.record_event(stage, scope, source, message, payload, severity)
	if event != null:
		return


func _finalize_diagnostic_report(report: Dictionary, subject: String) -> Dictionary:
	return _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT.finalize_report(report, subject, {
		"next_actions": _get_diagnostic_next_actions(),
		"fallback_action": "Review the first reported save graph issue before using this data.",
	})


func _get_diagnostic_next_actions() -> Dictionary:
	return {
		"null_scope": "Select or pass a valid GFSaveScope before running save graph diagnostics.",
		"empty_payload": "Load or gather a non-empty GF save graph payload before applying it.",
		"format_mismatch": "Use a payload generated by GFSaveGraphUtility or migrate it before applying.",
		"future_format_version": "Upgrade GF or run a project-level payload migration before applying this payload.",
		"invalid_scope_descriptor": "Fix the payload scope descriptor before applying it.",
		"scope_key_mismatch": "Apply this payload to the matching GFSaveScope or migrate the payload scope key.",
		"scope_namespace_mismatch": "Apply this payload to the matching key namespace or migrate the payload descriptor.",
		"invalid_sources_payload": "Fix the payload structure before applying it to the current scope tree.",
		"invalid_scopes_payload": "Fix the payload structure before applying it to the current scope tree.",
		"invalid_child_payload": "Fix the payload structure before applying it to the current scope tree.",
		"invalid_source_payload": "Fix each source entry so it is a Dictionary with a Dictionary data payload.",
		"invalid_source_descriptor": "Fix each source descriptor so it is a Dictionary.",
		"invalid_source_data": "Fix each source data payload so it is a Dictionary.",
		"empty_source_key": "Assign a stable source_key to every GFSaveSource.",
		"duplicate_source_key": "Rename one of the GFSaveSource source_key values inside the same scope.",
		"duplicate_scope_key": "Rename one of the child GFSaveScope scope_key values under the same parent.",
		"missing_target": "Fix the GFSaveSource target_node_path or disable the source when the target is optional.",
		"no_matching_serializer": "Register a matching serializer or assign explicit serializers for this target node type.",
		"missing_source": "Restore the missing GFSaveSource, ignore it intentionally, or provide a project migration path.",
		"missing_scope": "Restore the missing GFSaveScope, ignore it intentionally, or provide a project migration path.",
	}


func _get_validation_error_messages(report: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if issue.is_empty() or GFVariantData.get_option_string(issue, "severity") != "error":
			continue
		var kind: String = GFVariantData.get_option_string(issue, "kind", "validation_error")
		var message: String = GFVariantData.get_option_string(issue, "message", "Invalid save payload.")
		result.append("%s: %s" % [kind, message])
	if result.is_empty():
		result.append(GFVariantData.get_option_string(report, "summary", "Invalid save payload."))
	return result


func _get_sources_for_scope(scope: GFSaveScope) -> Array[GFSaveSource]:
	var result: Array[GFSaveSource] = []
	_collect_sources(scope, result)
	result.sort_custom(func(left: GFSaveSource, right: GFSaveSource) -> bool:
		if left.phase != right.phase:
			return left.phase < right.phase
		return String(left.get_source_key()) < String(right.get_source_key())
	)
	return result


func _get_sources_for_scope_for_inspection(scope: Node) -> Array[GFSaveSource]:
	var result: Array[GFSaveSource] = []
	_collect_sources_for_inspection(scope, result)
	result.sort_custom(func(left: GFSaveSource, right: GFSaveSource) -> bool:
		var left_phase: int = _get_int_property(left, &"phase", GFSaveScope.Phase.NORMAL)
		var right_phase: int = _get_int_property(right, &"phase", GFSaveScope.Phase.NORMAL)
		if left_phase != right_phase:
			return left_phase < right_phase
		return String(_get_source_key_for_inspection(left)) < String(_get_source_key_for_inspection(right))
	)
	return result


func _inspect_scope_recursive(
	scope: GFSaveScope,
	context: Dictionary,
	report: Dictionary,
	scope_path: String
) -> void:
	report["scope_count"] = GFVariantData.get_option_int(report, "scope_count") + 1
	var can_save_scope: bool = _can_save_scope_for_inspection(scope, context)
	var can_load_scope: bool = _can_load_scope_for_inspection(scope, context)
	if can_save_scope:
		report["enabled_scope_count"] = GFVariantData.get_option_int(report, "enabled_scope_count") + 1

	var scope_key: String = String(_get_scope_key_for_inspection(scope))
	_append_dictionary_array_field(report, "scopes", {
		"key": scope_key,
		"path": _get_node_debug_path(scope),
		"can_save": can_save_scope,
		"can_load": can_load_scope,
		"phase": _get_int_property(scope, &"phase", GFSaveScope.Phase.NORMAL),
	})

	var source_key_counts: Dictionary = {}
	for source: GFSaveSource in _get_sources_for_scope_for_inspection(scope):
		report["source_count"] = GFVariantData.get_option_int(report, "source_count") + 1
		var can_save_source: bool = _can_save_source_for_inspection(source, context)
		var can_load_source: bool = _can_load_source_for_inspection(source, context)
		if can_save_source:
			report["enabled_source_count"] = GFVariantData.get_option_int(report, "enabled_source_count") + 1

		var source_key: String = _make_scoped_source_key_for_inspection(scope, source)
		source_key_counts[source_key] = GFVariantData.get_option_int(source_key_counts, source_key) + 1
		var target: Node = _get_source_target_node_for_inspection(source)
		var serializer_ids: PackedStringArray = _get_source_serializer_ids_for_inspection(source, target)
		_append_dictionary_array_field(report, "sources", {
			"key": source_key,
			"path": _get_node_debug_path(source),
			"target_path": _get_node_debug_path(target),
			"can_save": can_save_source,
			"can_load": can_load_source,
			"phase": _get_int_property(source, &"phase", GFSaveScope.Phase.NORMAL),
			"serializer_ids": serializer_ids,
		})

		if source_key.is_empty():
			_append_diagnostic_issue(report, "error", "empty_source_key", scope_path, _get_node_debug_path(source), "Save source key is empty.")
		if (
			can_save_source
			and not _get_node_path_property(source, &"target_node_path").is_empty()
			and target == null
		):
			_append_diagnostic_issue(report, "warning", "missing_target", source_key, _get_node_debug_path(source), "Save source target node is missing.")
		if (
			can_save_source
			and target != null
			and (
				_get_bool_property(source, &"use_registry_serializers", false)
				or not _get_resource_array_property(source, &"serializers").is_empty()
			)
			and serializer_ids.is_empty()
		):
			_append_diagnostic_issue(report, "warning", "no_matching_serializer", source_key, _get_node_debug_path(source), "No configured serializer supports the target node.")

	for source_key_variant: Variant in source_key_counts.keys():
		var count: int = GFVariantData.to_int(source_key_counts[source_key_variant])
		if count > 1:
			_append_diagnostic_issue(report, "error", "duplicate_source_key", str(source_key_variant), _get_node_debug_path(scope), "Duplicate save source key in the same scope.")

	var child_scope_key_counts: Dictionary = {}
	for child_scope: GFSaveScope in _get_child_scopes_for_inspection(scope):
		var child_key: String = String(_get_scope_key_for_inspection(child_scope))
		child_scope_key_counts[child_key] = GFVariantData.get_option_int(child_scope_key_counts, child_key) + 1
	for child_key_variant: Variant in child_scope_key_counts.keys():
		var count: int = GFVariantData.to_int(child_scope_key_counts[child_key_variant])
		if count > 1:
			_append_diagnostic_issue(report, "error", "duplicate_scope_key", str(child_key_variant), _get_node_debug_path(scope), "Duplicate child scope key in the same scope.")

	for child_scope: GFSaveScope in _get_child_scopes_for_inspection(scope):
		_inspect_scope_recursive(child_scope, context, report, "%s/%s" % [scope_path, String(_get_scope_key_for_inspection(child_scope))])


func _validate_payload_scope_recursive(
	scope: GFSaveScope,
	payload: Dictionary,
	strict: bool,
	report: Dictionary,
	scope_path: String
) -> void:
	report["checked_scope_count"] = GFVariantData.get_option_int(report, "checked_scope_count") + 1
	var severity: String = "error" if strict else "warning"
	_append_payload_scope_descriptor_diagnostics(scope, payload, report, scope_path)
	_append_duplicate_key_diagnostics(scope, report, scope_path)
	var source_index: Dictionary = _index_sources_by_key_for_inspection(scope)
	var source_payload_value: Variant = GFVariantData.get_option_value(payload, "sources", {})
	var source_payloads: Dictionary = GFVariantData.as_dictionary(source_payload_value)
	if not (source_payload_value is Dictionary):
		_append_diagnostic_issue(report, "error", "invalid_sources_payload", scope_path, _get_node_debug_path(scope), "Payload sources must be a Dictionary.")
		source_payloads = {}
	for source_key_variant: Variant in source_payloads.keys():
		report["checked_source_count"] = GFVariantData.get_option_int(report, "checked_source_count") + 1
		var source_key: String = str(source_key_variant)
		var source_payload_entry: Variant = source_payloads[source_key_variant]
		if not (source_payload_entry is Dictionary):
			_append_diagnostic_issue(report, "error", "invalid_source_payload", source_key, _get_node_debug_path(scope), "Payload source entry must be a Dictionary.")
			continue
		var source_payload: Dictionary = GFVariantData.as_dictionary(source_payload_entry)
		var source_descriptor: Variant = GFVariantData.get_option_value(source_payload, "descriptor", {})
		if not (source_descriptor is Dictionary):
			_append_diagnostic_issue(report, "error", "invalid_source_descriptor", source_key, _get_node_debug_path(scope), "Payload source descriptor must be a Dictionary.")
		var source_data: Variant = GFVariantData.get_option_value(source_payload, "data", null)
		if not (source_data is Dictionary):
			_append_diagnostic_issue(report, "error", "invalid_source_data", source_key, _get_node_debug_path(scope), "Payload source data must be a Dictionary.")
		if not source_index.has(source_key):
			_append_dictionary_array_field(report, "missing", "%s:%s" % [scope_path, source_key])
			_append_diagnostic_issue(report, severity, "missing_source", source_key, _get_node_debug_path(scope), "Payload source does not exist in the current scope.")

	var child_scope_index: Dictionary = _index_child_scopes_for_inspection(scope)
	var child_payloads_value: Variant = GFVariantData.get_option_value(payload, "scopes", {})
	var child_payloads: Dictionary = GFVariantData.as_dictionary(child_payloads_value)
	if not (child_payloads_value is Dictionary):
		_append_diagnostic_issue(report, "error", "invalid_scopes_payload", scope_path, _get_node_debug_path(scope), "Payload scopes must be a Dictionary.")
		child_payloads = {}
	for child_key_variant: Variant in child_payloads.keys():
		var child_key: String = str(child_key_variant)
		var child_scope: GFSaveScope = _get_save_scope_value(GFVariantData.get_option_value(child_scope_index, child_key))
		if child_scope == null:
			_append_dictionary_array_field(report, "missing", "%s/%s" % [scope_path, child_key])
			_append_diagnostic_issue(report, severity, "missing_scope", child_key, _get_node_debug_path(scope), "Payload child scope does not exist in the current scope.")
			continue

		var child_payload_value: Variant = child_payloads[child_key_variant]
		var child_payload: Dictionary = GFVariantData.as_dictionary(child_payload_value)
		if not (child_payload_value is Dictionary):
			_append_diagnostic_issue(report, "error", "invalid_child_payload", child_key, _get_node_debug_path(child_scope), "Child scope payload must be a Dictionary.")
			continue
		_validate_payload_scope_recursive(child_scope, child_payload, strict, report, "%s/%s" % [scope_path, child_key])


func _collect_sources(current: Node, result: Array[GFSaveSource]) -> void:
	for child: Node in current.get_children():
		if child is GFSaveScope:
			continue
		if child is GFSaveSource:
			var source: GFSaveSource = _get_save_source_value(child)
			if source != null:
				result.append(source)
		_collect_sources(child, result)


func _collect_sources_for_inspection(current: Node, result: Array[GFSaveSource]) -> void:
	if current == null:
		return

	for child: Node in current.get_children():
		if child is GFSaveScope:
			continue
		if child is GFSaveSource:
			var source: GFSaveSource = _get_save_source_value(child)
			if source != null:
				result.append(source)
		_collect_sources_for_inspection(child, result)


func _get_child_scopes(scope: GFSaveScope) -> Array[GFSaveScope]:
	var result: Array[GFSaveScope] = []
	for child: Node in scope.get_children():
		if child is GFSaveScope:
			var child_scope: GFSaveScope = _get_save_scope_value(child)
			if child_scope != null:
				result.append(child_scope)
	result.sort_custom(_compare_scopes_for_traversal)
	return result


func _get_child_scopes_for_inspection(scope: Node) -> Array[GFSaveScope]:
	var result: Array[GFSaveScope] = []
	if scope == null:
		return result

	for child: Node in scope.get_children():
		if child is GFSaveScope:
			var child_scope: GFSaveScope = _get_save_scope_value(child)
			if child_scope != null:
				result.append(child_scope)
	result.sort_custom(_compare_scopes_for_traversal)
	return result


func _index_sources_by_key_for_inspection(scope: Node) -> Dictionary:
	var result: Dictionary = {}
	for source: GFSaveSource in _get_sources_for_scope_for_inspection(scope):
		result[_make_scoped_source_key_for_inspection(scope, source)] = source
	return result


func _index_child_scopes_for_inspection(scope: Node) -> Dictionary:
	var result: Dictionary = {}
	for child_scope: GFSaveScope in _get_child_scopes_for_inspection(scope):
		result[String(_get_scope_key_for_inspection(child_scope))] = child_scope
	return result


func _append_duplicate_key_diagnostics(scope: Node, report: Dictionary, _scope_path: String) -> void:
	var source_key_counts: Dictionary = _count_source_keys_for_inspection(scope)
	for source_key_variant: Variant in source_key_counts.keys():
		var source_key: String = str(source_key_variant)
		if GFVariantData.get_option_int(source_key_counts, source_key) > 1:
			_append_diagnostic_issue(report, "error", "duplicate_source_key", source_key, _get_node_debug_path(scope), "Duplicate save source key in the same scope.")

	var child_scope_key_counts: Dictionary = _count_child_scope_keys_for_inspection(scope)
	for child_key_variant: Variant in child_scope_key_counts.keys():
		var child_key: String = str(child_key_variant)
		if GFVariantData.get_option_int(child_scope_key_counts, child_key) > 1:
			_append_diagnostic_issue(report, "error", "duplicate_scope_key", child_key, _get_node_debug_path(scope), "Duplicate child scope key in the same scope.")


func _append_payload_scope_descriptor_diagnostics(
	scope: GFSaveScope,
	payload: Dictionary,
	report: Dictionary,
	scope_path: String
) -> void:
	var descriptor_value: Variant = GFVariantData.get_option_value(payload, "scope", {})
	if not (descriptor_value is Dictionary):
		_append_diagnostic_issue(report, "error", "invalid_scope_descriptor", scope_path, _get_node_debug_path(scope), "Payload scope descriptor must be a Dictionary.")
		return
	var descriptor: Dictionary = GFVariantData.as_dictionary(descriptor_value)
	var payload_scope_key: StringName = GFVariantData.get_option_string_name(descriptor, "scope_key")
	if payload_scope_key != &"" and payload_scope_key != _get_scope_key_for_inspection(scope):
		_append_diagnostic_issue(report, "error", "scope_key_mismatch", scope_path, _get_node_debug_path(scope), "Payload scope key does not match the target scope.")
	var payload_namespace: StringName = GFVariantData.get_option_string_name(descriptor, "key_namespace")
	var target_namespace: String = String(_get_string_name_property(scope, &"key_namespace", &""))
	if payload_namespace != &"" and String(payload_namespace) != target_namespace:
		_append_diagnostic_issue(report, "error", "scope_namespace_mismatch", scope_path, _get_node_debug_path(scope), "Payload key namespace does not match the target scope.")


func _count_source_keys_for_inspection(scope: Node) -> Dictionary:
	var result: Dictionary = {}
	for source: GFSaveSource in _get_sources_for_scope_for_inspection(scope):
		var source_key: String = _make_scoped_source_key_for_inspection(scope, source)
		result[source_key] = GFVariantData.get_option_int(result, source_key) + 1
	return result


func _count_child_scope_keys_for_inspection(scope: Node) -> Dictionary:
	var result: Dictionary = {}
	for child_scope: GFSaveScope in _get_child_scopes_for_inspection(scope):
		var child_key: String = String(_get_scope_key_for_inspection(child_scope))
		result[child_key] = GFVariantData.get_option_int(result, child_key) + 1
	return result


func _append_apply_format_errors(
	payload: Dictionary,
	errors: Array[String],
	pipeline_context: GFSavePipelineContext
) -> void:
	if GFVariantData.get_option_string(payload, "format") != FORMAT_ID:
		var format_error: String = "Payload format does not match GF save graph."
		errors.append(format_error)
		pipeline_context.add_error(format_error, { "kind": "format_mismatch" })
	if GFVariantData.get_option_int(payload, "format_version", -1) > FORMAT_VERSION:
		var version_error: String = "Payload uses a future format version newer than this utility."
		errors.append(version_error)
		pipeline_context.add_error(version_error, { "kind": "future_format_version" })


func _append_apply_scope_descriptor_errors(
	scope: GFSaveScope,
	payload: Dictionary,
	errors: Array[String],
	pipeline_context: GFSavePipelineContext
) -> void:
	var descriptor_value: Variant = GFVariantData.get_option_value(payload, "scope", {})
	if not (descriptor_value is Dictionary):
		var descriptor_error: String = "Invalid save payload: scope must be a Dictionary."
		errors.append(descriptor_error)
		pipeline_context.add_error(descriptor_error, { "kind": "invalid_scope_descriptor" })
		return
	var descriptor: Dictionary = GFVariantData.as_dictionary(descriptor_value)
	var payload_scope_key: StringName = GFVariantData.get_option_string_name(descriptor, "scope_key")
	if payload_scope_key != &"" and payload_scope_key != scope.get_scope_key():
		var scope_key_error: String = "Save payload scope key does not match target scope: %s" % String(payload_scope_key)
		errors.append(scope_key_error)
		pipeline_context.add_error(scope_key_error, {
			"kind": "scope_key_mismatch",
			"payload_scope_key": String(payload_scope_key),
			"target_scope_key": String(scope.get_scope_key()),
		})
	var payload_namespace: StringName = GFVariantData.get_option_string_name(descriptor, "key_namespace")
	if payload_namespace != &"" and String(payload_namespace) != scope.get_key_prefix():
		var namespace_error: String = "Save payload key namespace does not match target scope: %s" % String(payload_namespace)
		errors.append(namespace_error)
		pipeline_context.add_error(namespace_error, {
			"kind": "scope_namespace_mismatch",
			"payload_key_namespace": String(payload_namespace),
			"target_key_namespace": scope.get_key_prefix(),
		})


func _append_apply_preflight_errors(
	scope: GFSaveScope,
	source_payloads: Dictionary,
	child_payloads: Dictionary,
	strict: bool,
	errors: Array[String],
	missing: Array[String],
	pipeline_context: GFSavePipelineContext,
	scope_path: String
) -> void:
	for source_key_variant: Variant in _sorted_dictionary_keys(source_payloads):
		var source_key: String = str(source_key_variant)
		if not (source_payloads[source_key_variant] is Dictionary):
			var invalid_source_error: String = "Invalid source payload: %s" % source_key
			errors.append(invalid_source_error)
			pipeline_context.add_error(invalid_source_error, { "source_key": source_key })
			continue
		var source_payload: Dictionary = GFVariantData.as_dictionary(source_payloads[source_key_variant])
		var descriptor_value: Variant = GFVariantData.get_option_value(source_payload, "descriptor", {})
		if not (descriptor_value is Dictionary):
			var invalid_descriptor_error: String = "Invalid source descriptor payload: %s" % source_key
			errors.append(invalid_descriptor_error)
			pipeline_context.add_error(invalid_descriptor_error, { "source_key": source_key })
		var data_value: Variant = GFVariantData.get_option_value(source_payload, "data", null)
		if not (data_value is Dictionary):
			var invalid_data_error: String = "Invalid source data payload: %s" % source_key
			errors.append(invalid_data_error)
			pipeline_context.add_error(invalid_data_error, { "source_key": source_key })

	for source_key_variant: Variant in _duplicate_keys_from_counts(_count_source_keys_for_inspection(scope)):
		var duplicate_source_key: String = str(source_key_variant)
		var duplicate_source_error: String = "Duplicate source key: %s" % duplicate_source_key
		errors.append(duplicate_source_error)
		pipeline_context.add_error(duplicate_source_error, {
			"scope_key": scope_path,
			"source_key": duplicate_source_key,
		})

	for child_key_variant: Variant in _duplicate_keys_from_counts(_count_child_scope_keys_for_inspection(scope)):
		var duplicate_child_key: String = str(child_key_variant)
		var duplicate_child_error: String = "Duplicate child scope key: %s" % duplicate_child_key
		errors.append(duplicate_child_error)
		pipeline_context.add_error(duplicate_child_error, {
			"scope_key": scope_path,
			"child_scope_key": duplicate_child_key,
		})

	var child_scope_index: Dictionary = _index_child_scopes_for_inspection(scope)
	for child_key_variant: Variant in _sorted_dictionary_keys(child_payloads):
		var child_key: String = str(child_key_variant)
		var child_payload_value: Variant = child_payloads[child_key_variant]
		if not (child_payload_value is Dictionary):
			var invalid_child_error: String = "Invalid child scope payload: %s" % child_key
			errors.append(invalid_child_error)
			pipeline_context.add_error(invalid_child_error, { "scope_key": child_key })
			continue

		var child_scope: GFSaveScope = _get_save_scope_value(GFVariantData.get_option_value(child_scope_index, child_key))
		if child_scope == null:
			missing.append(child_key)
			if strict:
				var missing_scope_error: String = "Missing scope: %s" % child_key
				errors.append(missing_scope_error)
				pipeline_context.add_error(missing_scope_error, { "scope_key": child_key })
			continue

		var child_payload: Dictionary = GFVariantData.as_dictionary(child_payload_value)
		var nested_source_payloads_value: Variant = GFVariantData.get_option_value(child_payload, "sources", {})
		var nested_child_payloads_value: Variant = GFVariantData.get_option_value(child_payload, "scopes", {})
		if not (nested_source_payloads_value is Dictionary):
			var invalid_nested_sources_error: String = "Invalid save payload: sources must be a Dictionary."
			errors.append(invalid_nested_sources_error)
			pipeline_context.add_error(invalid_nested_sources_error, {
				"scope_key": child_key,
			})
			continue
		if not (nested_child_payloads_value is Dictionary):
			var invalid_nested_scopes_error: String = "Invalid save payload: scopes must be a Dictionary."
			errors.append(invalid_nested_scopes_error)
			pipeline_context.add_error(invalid_nested_scopes_error, {
				"scope_key": child_key,
			})
			continue
		_append_apply_preflight_errors(
			child_scope,
			GFVariantData.as_dictionary(nested_source_payloads_value),
			GFVariantData.as_dictionary(nested_child_payloads_value),
			strict,
			errors,
			missing,
			pipeline_context,
			"%s/%s" % [scope_path, child_key]
		)


func _duplicate_keys_from_counts(counts: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key_variant: Variant in counts.keys():
		var key: String = str(key_variant)
		if GFVariantData.get_option_int(counts, key) > 1:
			var _append_key: bool = result.append(key)
	result.sort()
	return result


func _sorted_dictionary_keys(data: Dictionary) -> Array:
	var result: Array = data.keys()
	result.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str(left) < str(right)
	)
	return result


func _make_scoped_source_key(scope: GFSaveScope, source: GFSaveSource) -> String:
	var prefix: String = scope.get_key_prefix()
	var key: String = String(source.get_source_key())
	if prefix.is_empty():
		return key
	return "%s/%s" % [prefix, key]


func _make_scoped_source_key_for_inspection(scope: Node, source: Node) -> String:
	var prefix: String = String(_get_string_name_property(scope, &"key_namespace", &""))
	var key: String = String(_get_source_key_for_inspection(source))
	if prefix.is_empty():
		return key
	return "%s/%s" % [prefix, key]


func _get_scope_key_for_inspection(scope: Node) -> StringName:
	if scope == null:
		return &""
	return _get_string_name_property(scope, &"scope_key", StringName(scope.name))


func _get_source_key_for_inspection(source: Node) -> StringName:
	if source == null:
		return &""
	return _get_string_name_property(source, &"source_key", StringName(source.name))


func _can_save_scope_for_inspection(scope: Node, _context: Dictionary = {}) -> bool:
	return (
		_get_bool_property(scope, &"enabled", true)
		and _get_bool_property(scope, &"save_enabled", true)
	)


func _can_load_scope_for_inspection(scope: Node, _context: Dictionary = {}) -> bool:
	return (
		_get_bool_property(scope, &"enabled", true)
		and _get_bool_property(scope, &"load_enabled", true)
	)


func _can_save_source_for_inspection(source: Node, _context: Dictionary = {}) -> bool:
	return (
		_get_bool_property(source, &"enabled", true)
		and _get_bool_property(source, &"save_enabled", true)
	)


func _can_load_source_for_inspection(source: Node, _context: Dictionary = {}) -> bool:
	return (
		_get_bool_property(source, &"enabled", true)
		and _get_bool_property(source, &"load_enabled", true)
	)


func _get_source_target_node_for_inspection(source: Node) -> Node:
	if source == null:
		return null

	var target_node_path: NodePath = _get_node_path_property(source, &"target_node_path")
	if not target_node_path.is_empty():
		return source.get_node_or_null(target_node_path)
	return source.get_parent()


func _get_source_serializer_ids_for_inspection(source: Node, target: Node) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if source == null or target == null:
		return result

	var local_serializers: Array[Resource] = _get_resource_array_property(source, &"serializers")
	if not local_serializers.is_empty():
		for serializer: Resource in local_serializers:
			var serializer_id: StringName = _get_serializer_id_for_inspection(serializer)
			if serializer_id != &"":
				_append_packed_string(result, String(serializer_id))
		return result

	if _get_bool_property(source, &"use_registry_serializers", false) and serializer_registry != null:
		for serializer: GFNodeSerializer in serializer_registry.get_serializers_for_node(target):
			if serializer != null:
				_append_packed_string(result, String(serializer.get_serializer_id()))
	return result


func _get_serializer_id_for_inspection(serializer: Resource) -> StringName:
	if serializer == null:
		return &""

	var serializer_id: StringName = _get_string_name_property(serializer, &"serializer_id", &"")
	if serializer_id != &"":
		return serializer_id
	if not serializer.resource_path.is_empty():
		return StringName(serializer.resource_path)

	var script: Script = _get_script_value(serializer.get_script())
	if script != null:
		return StringName(script.resource_path)
	return &""


func _get_string_name_property(object: Object, property_name: StringName, fallback: StringName = &"") -> StringName:
	if object == null:
		return fallback

	var value: Variant = _read_object_property(object, property_name, fallback)
	return _get_non_empty_string_name(value, fallback)


func _get_bool_property(object: Object, property_name: StringName, fallback: bool = false) -> bool:
	if object == null:
		return fallback

	var value: Variant = _read_object_property(object, property_name, fallback)
	return GFVariantData.to_bool(value, fallback)


func _get_int_property(object: Object, property_name: StringName, fallback: int = 0) -> int:
	if object == null:
		return fallback

	var value: Variant = _read_object_property(object, property_name, fallback)
	return GFVariantData.to_int(value, fallback)


func _get_node_path_property(object: Object, property_name: StringName) -> NodePath:
	if object == null:
		return NodePath("")

	var value: Variant = _read_object_property(object, property_name, NodePath(""))
	return _get_node_path_value(value)


func _get_resource_array_property(object: Object, property_name: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	if object == null:
		return result

	var value: Variant = _read_object_property(object, property_name, [])
	if not value is Array:
		return result

	for entry: Variant in GFVariantData.as_array(value):
		var resource: Resource = _get_resource_value(entry)
		if resource != null:
			result.append(resource)
	return result


func _merge_identity_descriptor(source: GFSaveSource, descriptor: Dictionary) -> void:
	var identity: GFSaveIdentity = _find_identity(source)
	if identity == null:
		return

	var identity_descriptor: Dictionary = identity.describe_identity()
	for key: Variant in identity_descriptor.keys():
		descriptor[key] = identity_descriptor[key]


func _find_identity(source: GFSaveSource) -> GFSaveIdentity:
	for child: Node in source.get_children():
		if child is GFSaveIdentity:
			return _get_save_identity_value(child)

	var target: Node = source.get_target_node()
	if target == null:
		return null
	for child: Node in target.get_children():
		if child is GFSaveIdentity:
			return _get_save_identity_value(child)
	return null


func _try_create_source_from_payload(
	scope: GFSaveScope,
	source_payload: Dictionary,
	context: Dictionary,
	expected_source_key: String
) -> GFSaveSource:
	if scope.restore_policy != GFSaveScope.RestorePolicy.ALLOW_FACTORIES:
		return null

	var descriptor: Dictionary = _get_dictionary_field(source_payload, "descriptor")
	var type_key: StringName = _get_non_empty_string_name(GFVariantData.get_option_value(descriptor, "type_key"))
	var factory: GFSaveEntityFactory = _get_entity_factory_value(GFVariantData.get_option_value(_entity_factories, type_key))
	if factory == null:
		return null

	var entity: Node = factory._create_entity(descriptor, context)
	if entity == null:
		return null

	if entity is GFSaveSource:
		scope.add_child(entity)
		_track_created_entity(context, entity)
		factory._after_entity_created(entity, descriptor, context)
		if not is_instance_valid(entity):
			return null
		var direct_source: GFSaveSource = _get_save_source_value(entity)
		_align_factory_source_key(scope, direct_source, expected_source_key)
		if _make_scoped_source_key(scope, direct_source) != expected_source_key:
			_free_created_entity(entity)
			return null
		return direct_source
	var source: GFSaveSource = _find_first_source(entity)
	if source == null:
		_free_created_entity(entity)
		return null

	scope.add_child(entity)
	_track_created_entity(context, entity)
	factory._after_entity_created(entity, descriptor, context)
	if not is_instance_valid(entity) or not is_instance_valid(source):
		return null
	_align_factory_source_key(scope, source, expected_source_key)
	if _make_scoped_source_key(scope, source) != expected_source_key:
		_free_created_entity(entity)
		return null
	return source


func _align_factory_source_key(scope: GFSaveScope, source: GFSaveSource, expected_source_key: String) -> void:
	if scope == null or source == null or expected_source_key.is_empty():
		return
	var prefix: String = scope.get_key_prefix()
	var local_key: String = expected_source_key
	if not prefix.is_empty():
		var prefix_text: String = "%s/" % prefix
		if expected_source_key.begins_with(prefix_text):
			local_key = expected_source_key.substr(prefix_text.length())
	if local_key.is_empty():
		return
	source.source_key = StringName(local_key)


func _find_first_source(root: Node) -> GFSaveSource:
	for child: Node in root.get_children():
		if child is GFSaveSource:
			return _get_save_source_value(child)
		var nested: GFSaveSource = _find_first_source(child)
		if nested != null:
			return nested
	return null


func _source_payload_phase(source_payload_variant: Variant) -> int:
	if not (source_payload_variant is Dictionary):
		return 0

	var source_payload: Dictionary = GFVariantData.as_dictionary(source_payload_variant)
	var descriptor: Dictionary = _get_dictionary_field(source_payload, "descriptor")
	return GFVariantData.get_option_int(descriptor, "phase", GFSaveScope.Phase.NORMAL)


func _scope_payload_phase(scope_payload_variant: Variant) -> int:
	if not (scope_payload_variant is Dictionary):
		return GFSaveScope.Phase.NORMAL

	var scope_payload: Dictionary = GFVariantData.as_dictionary(scope_payload_variant)
	var descriptor: Dictionary = _get_dictionary_field(scope_payload, "scope")
	return GFVariantData.get_option_int(descriptor, "phase", GFSaveScope.Phase.NORMAL)


func _compare_source_payload_keys(left: Variant, right: Variant, source_payloads: Dictionary) -> bool:
	var left_phase: int = _source_payload_phase(GFVariantData.get_option_value(source_payloads, left))
	var right_phase: int = _source_payload_phase(GFVariantData.get_option_value(source_payloads, right))
	if left_phase != right_phase:
		return left_phase < right_phase
	return str(left) < str(right)


func _compare_scope_payload_keys(left: Variant, right: Variant, child_payloads: Dictionary) -> bool:
	var left_phase: int = _scope_payload_phase(GFVariantData.get_option_value(child_payloads, left))
	var right_phase: int = _scope_payload_phase(GFVariantData.get_option_value(child_payloads, right))
	if left_phase != right_phase:
		return left_phase < right_phase
	return str(left) < str(right)


func _compare_scopes_for_traversal(left: GFSaveScope, right: GFSaveScope) -> bool:
	var left_phase: int = _get_int_property(left, &"phase", GFSaveScope.Phase.NORMAL)
	var right_phase: int = _get_int_property(right, &"phase", GFSaveScope.Phase.NORMAL)
	if left_phase != right_phase:
		return left_phase < right_phase
	return String(_get_scope_key_for_inspection(left)) < String(_get_scope_key_for_inspection(right))


func _make_apply_result(ok: bool, applied: int, errors: Array[String], missing: Array[String]) -> Dictionary:
	return {
		"ok": ok,
		"applied": applied,
		"errors": errors,
		"missing": missing,
	}


func _get_payload_dictionary_field(
	payload: Dictionary,
	field_name: String,
	errors: Array[String],
	pipeline_context: GFSavePipelineContext,
	issue_kind: String
) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(payload, field_name, {})
	if value is Dictionary:
		return GFVariantData.as_dictionary(value)

	var error: String = "Invalid save payload: %s must be a Dictionary." % field_name
	errors.append(error)
	pipeline_context.add_error(error, { "kind": issue_kind })
	return {}


func _finish_apply_scope(
	scope: GFSaveScope,
	payload: Dictionary,
	result: Dictionary,
	context: Dictionary,
	pipeline_context: GFSavePipelineContext,
	owns_pipeline_context: bool
) -> Dictionary:
	var final_result: Dictionary = _run_after_apply_steps(scope, payload, result, context)
	_record_pipeline_event(pipeline_context, &"apply_scope_finished", scope, null, "", {
		"applied": GFVariantData.get_option_int(final_result, "applied"),
		"error_count": GFVariantData.get_option_array(final_result, "errors").size(),
		"missing_count": GFVariantData.get_option_array(final_result, "missing").size(),
	})
	if owns_pipeline_context:
		pipeline_context.finish()
		if GFVariantData.get_option_bool(context, "include_pipeline_trace", false):
			final_result["pipeline_trace"] = pipeline_context.to_dict(true)
	return final_result


func _finalize_apply_scope(
	scope: GFSaveScope,
	payload: Dictionary,
	result: Dictionary,
	context: Dictionary,
	pipeline_context: GFSavePipelineContext,
	owns_pipeline_context: bool,
	owns_created_entities: bool,
	owns_source_snapshots: bool,
	owns_transaction_boundary: bool = false
) -> Dictionary:
	var should_rollback: bool = (
		GFVariantData.get_option_bool(context, "transactional_apply", true)
		and not GFVariantData.get_option_bool(result, "ok", false)
	)
	if should_rollback and owns_transaction_boundary:
		_rollback_transaction_participants(pipeline_context, context)
	if should_rollback and owns_source_snapshots:
		_rollback_source_snapshots(context, pipeline_context)
	if should_rollback and owns_created_entities:
		_rollback_created_entities(context)
	if owns_transaction_boundary:
		if GFVariantData.get_option_bool(result, "ok", false):
			_dispatch_after_load_callbacks(context)
		else:
			_clear_after_load_callbacks(context)

	var final_result: Dictionary = _finish_apply_scope(
		scope,
		payload,
		result,
		context,
		pipeline_context,
		owns_pipeline_context
	)
	if owns_created_entities:
		_erase_dictionary_key(context, _CREATED_ENTITIES_CONTEXT_KEY)
	if owns_source_snapshots:
		_erase_dictionary_key(context, _SOURCE_SNAPSHOTS_CONTEXT_KEY)
	if owns_transaction_boundary:
		pipeline_context.clear_transaction_participants()
		_erase_dictionary_key(context, _AFTER_LOAD_QUEUE_CONTEXT_KEY)
		_erase_dictionary_key(context, _TRANSACTION_BOUNDARY_CONTEXT_KEY)
	return final_result


func _queue_after_load_callbacks(
	context: Dictionary,
	loaded_sources: Array[Dictionary],
	scope: GFSaveScope,
	payload: Dictionary
) -> void:
	var queue: Array = GFVariantData.get_option_array(context, _AFTER_LOAD_QUEUE_CONTEXT_KEY)
	for loaded_source_entry: Dictionary in loaded_sources:
		var loaded_source: GFSaveSource = _get_save_source_value(
			GFVariantData.get_option_value(loaded_source_entry, "source")
		)
		if loaded_source == null or not is_instance_valid(loaded_source):
			continue
		queue.append({
			"kind": &"source",
			"target": loaded_source,
			"data": GFVariantData.duplicate_variant(
				GFVariantData.get_option_value(loaded_source_entry, "data")
			),
		})
	if scope != null and is_instance_valid(scope):
		queue.append({
			"kind": &"scope",
			"target": scope,
			"data": GFVariantData.duplicate_variant(payload),
		})
	context[_AFTER_LOAD_QUEUE_CONTEXT_KEY] = queue


func _dispatch_after_load_callbacks(context: Dictionary) -> void:
	var callbacks: Array = GFVariantData.get_option_array(context, _AFTER_LOAD_QUEUE_CONTEXT_KEY)
	context[_AFTER_LOAD_QUEUE_CONTEXT_KEY] = []
	for callback_value: Variant in callbacks:
		if not callback_value is Dictionary:
			continue
		var callback: Dictionary = GFVariantData.as_dictionary(callback_value)
		var target: Object = GFVariantData.get_option_value(callback, "target") as Object
		if target == null or not is_instance_valid(target):
			continue
		var data: Variant = GFVariantData.get_option_value(callback, "data")
		match GFVariantData.get_option_string_name(callback, "kind"):
			&"source":
				if target is GFSaveSource:
					var source: GFSaveSource = target
					source._after_load(data, context)
			&"scope":
				if target is GFSaveScope and data is Dictionary:
					var callback_scope: GFSaveScope = target
					callback_scope._after_load(GFVariantData.as_dictionary(data), context)


func _clear_after_load_callbacks(context: Dictionary) -> void:
	context[_AFTER_LOAD_QUEUE_CONTEXT_KEY] = []


func _append_transaction_participant_errors(
	pipeline_context: GFSavePipelineContext,
	context: Dictionary,
	stage: StringName,
	errors: Array[String]
) -> void:
	if pipeline_context == null:
		return

	var participants: Array[GFSaveTransactionParticipant] = pipeline_context.get_transaction_participants()
	for participant: GFSaveTransactionParticipant in participants:
		if participant == null:
			continue
		var result: Dictionary = _run_transaction_participant_stage(participant, context, stage)
		if GFVariantData.get_option_bool(result, "ok", false):
			_record_pipeline_event(pipeline_context, _transaction_stage_to_event(stage), null, null, "", {
				"participant_id": String(participant.participant_id),
			})
			continue

		var participant_errors: Array[String] = GFVariantData.to_string_array(GFVariantData.get_option_value(result, "errors", []))
		if participant_errors.is_empty():
			participant_errors.append("Save transaction participant failed.")
		for participant_error: String in participant_errors:
			var message: String = "%s %s failed: %s" % [
				_get_transaction_participant_label(participant),
				String(stage),
				participant_error,
			]
			errors.append(message)
			pipeline_context.add_error(message, {
				"participant_id": String(participant.participant_id),
				"stage": String(stage),
			})


func _rollback_transaction_participants(
	pipeline_context: GFSavePipelineContext,
	context: Dictionary
) -> void:
	if pipeline_context == null:
		return

	var participants: Array[GFSaveTransactionParticipant] = pipeline_context.get_transaction_participants()
	for index: int in range(participants.size() - 1, -1, -1):
		var participant: GFSaveTransactionParticipant = participants[index]
		if participant == null:
			continue
		var result: Dictionary = participant.rollback(context)
		if GFVariantData.get_option_bool(result, "ok", false):
			_record_pipeline_event(pipeline_context, &"transaction_participant_rolled_back", null, null, "", {
				"participant_id": String(participant.participant_id),
			})
			continue

		var participant_errors: Array[String] = GFVariantData.to_string_array(GFVariantData.get_option_value(result, "errors", []))
		if participant_errors.is_empty():
			participant_errors.append("Save transaction participant rollback failed.")
		for participant_error: String in participant_errors:
			pipeline_context.add_error("%s rollback failed: %s" % [
				_get_transaction_participant_label(participant),
				participant_error,
			], {
				"participant_id": String(participant.participant_id),
				"stage": "rollback",
			})


func _run_transaction_participant_stage(
	participant: GFSaveTransactionParticipant,
	context: Dictionary,
	stage: StringName
) -> Dictionary:
	match stage:
		&"prepare":
			return participant.prepare(context)
		&"commit":
			return participant.commit(context)
		_:
			return participant.make_result(false, ["Unknown transaction participant stage: %s" % String(stage)])


func _transaction_stage_to_event(stage: StringName) -> StringName:
	match stage:
		&"prepare":
			return &"transaction_participant_prepared"
		&"commit":
			return &"transaction_participant_committed"
		_:
			return &"transaction_participant_stage_finished"


func _get_transaction_participant_label(participant: GFSaveTransactionParticipant) -> String:
	if participant == null:
		return "Save transaction participant"
	if participant.participant_id != &"":
		return "Save transaction participant %s" % String(participant.participant_id)
	return "Save transaction participant"


func _track_source_snapshot(context: Dictionary, source: GFSaveSource) -> void:
	if (
		not GFVariantData.get_option_bool(context, "transactional_apply", true)
		or not context.has(_SOURCE_SNAPSHOTS_CONTEXT_KEY)
		or source == null
		or not is_instance_valid(source)
		or _source_snapshot_exists(context, source)
		or _is_created_entity_or_descendant(context, source)
	):
		return

	var snapshots: Array = GFVariantData.as_array(GFVariantData.get_option_value(context, _SOURCE_SNAPSHOTS_CONTEXT_KEY, []))
	var snapshot_data: Variant = source._gather_save_data(context, serializer_registry)
	snapshots.append({
		"source": source,
		"data": GFVariantData.duplicate_variant(snapshot_data),
	})
	context[_SOURCE_SNAPSHOTS_CONTEXT_KEY] = snapshots


func _source_snapshot_exists(context: Dictionary, source: GFSaveSource) -> bool:
	for snapshot_variant: Variant in GFVariantData.as_array(GFVariantData.get_option_value(context, _SOURCE_SNAPSHOTS_CONTEXT_KEY, [])):
		var snapshot: Dictionary = GFVariantData.as_dictionary(snapshot_variant)
		var snapshot_source: GFSaveSource = _get_save_source_value(GFVariantData.get_option_value(snapshot, "source"))
		if snapshot_source == source:
			return true
	return false


func _rollback_source_snapshots(context: Dictionary, pipeline_context: GFSavePipelineContext) -> void:
	var snapshots: Array = GFVariantData.as_array(GFVariantData.get_option_value(context, _SOURCE_SNAPSHOTS_CONTEXT_KEY, []))
	for index: int in range(snapshots.size() - 1, -1, -1):
		var snapshot: Dictionary = GFVariantData.as_dictionary(snapshots[index])
		var source: GFSaveSource = _get_save_source_value(GFVariantData.get_option_value(snapshot, "source"))
		if source == null or not is_instance_valid(source):
			continue
		var snapshot_data: Variant = GFVariantData.get_option_value(snapshot, "data")
		var result: Dictionary = GFVariantData.as_dictionary(source._apply_save_data(snapshot_data, context, serializer_registry))
		if not GFVariantData.get_option_bool(result, "ok", false):
			var rollback_error: String = "Source rollback failed: %s" % String(source.get_source_key())
			pipeline_context.add_error(rollback_error, {
				"source_key": String(source.get_source_key()),
			})
	snapshots.clear()


func _track_created_entity(context: Dictionary, entity: Node) -> void:
	if not context.has(_CREATED_ENTITIES_CONTEXT_KEY):
		return
	var created_entities: Array = GFVariantData.as_array(context[_CREATED_ENTITIES_CONTEXT_KEY])
	if not created_entities.has(entity):
		created_entities.append(entity)
	context[_CREATED_ENTITIES_CONTEXT_KEY] = created_entities


func _rollback_created_entities(context: Dictionary) -> void:
	var created_entities: Array = GFVariantData.as_array(GFVariantData.get_option_value(context, _CREATED_ENTITIES_CONTEXT_KEY, []))

	for index: int in range(created_entities.size() - 1, -1, -1):
		var entity_variant: Variant = created_entities[index]
		var entity: Node = _get_node_value(entity_variant)
		if not is_instance_valid(entity):
			continue
		_free_created_entity(entity)
	created_entities.clear()


func _is_created_entity_or_descendant(context: Dictionary, node: Node) -> bool:
	if node == null:
		return false
	for entity_variant: Variant in GFVariantData.as_array(GFVariantData.get_option_value(context, _CREATED_ENTITIES_CONTEXT_KEY, [])):
		var entity: Node = _get_node_value(entity_variant)
		if not is_instance_valid(entity):
			continue
		if entity == node or entity.is_ancestor_of(node):
			return true
	return false


func _free_created_entity(entity: Node) -> void:
	if not is_instance_valid(entity):
		return

	var parent: Node = entity.get_parent()
	if parent != null:
		parent.remove_child(entity)
	entity.free()


func _ensure_pipeline_context(
	context: Dictionary,
	operation: StringName,
	scope: GFSaveScope
) -> Dictionary:
	if _has_pipeline_context(context):
		return context

	var result: Dictionary = context.duplicate()
	var shared: Dictionary = _get_dictionary_field(result, "pipeline_shared")
	result["pipeline_context"] = create_pipeline_context(operation, scope, shared)
	return result


func _has_pipeline_context(context: Dictionary) -> bool:
	return GFVariantData.get_option_value(context, "pipeline_context") is GFSavePipelineContext


func _get_pipeline_context(context: Dictionary) -> GFSavePipelineContext:
	return _get_pipeline_context_value(GFVariantData.get_option_value(context, "pipeline_context"))


func _run_before_gather_steps(scope: GFSaveScope, context: Dictionary) -> void:
	for step: GFSavePipelineStep in pipeline_steps:
		if step != null and step.enabled:
			_record_pipeline_step_event(context, &"before_gather_step", scope, step)
			step._before_gather_scope(scope, context)


func _run_after_gather_steps(
	scope: GFSaveScope,
	payload: Dictionary,
	context: Dictionary
) -> Dictionary:
	var result: Dictionary = payload
	for step: GFSavePipelineStep in pipeline_steps:
		if step == null or not step.enabled:
			continue
		_record_pipeline_step_event(context, &"after_gather_step", scope, step)
		var next_payload: Variant = step._after_gather_scope(scope, result, context)
		if next_payload is Dictionary:
			result = GFVariantData.as_dictionary(next_payload)
	return result


func _run_before_apply_steps(
	scope: GFSaveScope,
	payload: Dictionary,
	context: Dictionary
) -> Dictionary:
	var result: Dictionary = payload
	for step: GFSavePipelineStep in pipeline_steps:
		if step == null or not step.enabled:
			continue
		_record_pipeline_step_event(context, &"before_apply_step", scope, step)
		var next_payload: Variant = step._before_apply_scope(scope, result, context)
		if next_payload is Dictionary:
			result = GFVariantData.as_dictionary(next_payload)
	return result


func _run_after_apply_steps(
	scope: GFSaveScope,
	payload: Dictionary,
	result: Dictionary,
	context: Dictionary
) -> Dictionary:
	var final_result: Dictionary = result
	for step: GFSavePipelineStep in pipeline_steps:
		if step == null or not step.enabled:
			continue
		_record_pipeline_step_event(context, &"after_apply_step", scope, step)
		var next_result: Variant = step._after_apply_scope(scope, payload, final_result, context)
		if next_result is Dictionary:
			final_result = GFVariantData.as_dictionary(next_result)
	return final_result


func _record_pipeline_step_event(
	context: Dictionary,
	stage: StringName,
	scope: GFSaveScope,
	step: GFSavePipelineStep
) -> void:
	var pipeline_context: GFSavePipelineContext = _get_pipeline_context(context)
	if pipeline_context == null:
		return
	var step_script: Script = _get_script_value(step.get_script())
	_record_pipeline_event(pipeline_context, stage, scope, null, "", {
		"step_id": step.step_id,
		"step_script": step_script.resource_path if step_script != null else "",
	})


func _get_storage_utility() -> GFStorageUtility:
	return _get_storage_utility_value(get_utility(GFStorageUtility))


func _push_persisted_validation_error(label: String, report: Dictionary) -> void:
	push_error(
		"[GFSaveGraphUtility] save_scope 失败：%s 在 %s 不可持久化：%s。" % [
			label,
			GFVariantData.get_option_string(report, "path", "$"),
			GFVariantData.get_option_string(report, "error", "invalid_value"),
		]
	)


func _get_source_serializer_ids(source: GFSaveSource, target: Node) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if target == null:
		return result

	if not source.serializers.is_empty():
		for serializer: GFNodeSerializer in source.serializers:
			if serializer != null and serializer.supports_node(target):
				_append_packed_string(result, String(serializer.get_serializer_id()))
		return result

	if source.use_registry_serializers and serializer_registry != null:
		for serializer: GFNodeSerializer in serializer_registry.get_serializers_for_node(target):
			if serializer != null:
				_append_packed_string(result, String(serializer.get_serializer_id()))
	return result


func _append_diagnostic_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	key: String,
	path: String,
	message: String
) -> void:
	var issue: Dictionary = _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT.append_issue(report, severity, StringName(kind), message, {
		"key": key,
		"path": path,
	})
	if not issue.is_empty():
		return


func _report_has_no_error_issues(report: Dictionary) -> bool:
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if not issue.is_empty() and GFVariantData.get_option_string(issue, "severity") == "error":
			return false
	return true


func _get_node_debug_path(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return String(node.get_path())
	return node.name
