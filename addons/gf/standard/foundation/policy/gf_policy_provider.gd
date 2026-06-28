## GFPolicyProvider: 通用策略提供者协议。
##
## 描述可对某类 artifact 字典执行校验、治理或打分的策略扩展点。
## Provider 只声明输入输出和执行协议，不规定具体业务类型。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 6.0.0
class_name GFPolicyProvider
extends Resource


# --- 导出变量 ---

## Provider 稳定标识。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var provider_id: StringName = &""

## 显示名称。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var display_name: String = ""

## 支持的 artifact kind；为空表示支持所有 kind。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var supported_artifact_kinds: PackedStringArray = PackedStringArray()

## 策略优先级，较小值先执行。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var priority: int = 0

## 输入 schema 描述。GF 不解释字段业务含义。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema input_schema: Dictionary caller-defined policy input schema.
@export var input_schema: Dictionary = {}

## 输出 schema 描述。GF 不解释字段业务含义。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema output_schema: Dictionary caller-defined policy output schema.
@export var output_schema: Dictionary = {}

## 策略是否声明为确定性。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var deterministic: bool = true

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary for caller-defined policy metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置 Provider。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_provider_id: Provider 稳定标识。
## [br]
## @param p_supported_artifact_kinds: 支持的 artifact kind；为空表示支持所有 kind。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into metadata.
## [br]
## @return 当前 Provider。
func configure(
	p_provider_id: StringName,
	p_supported_artifact_kinds: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> GFPolicyProvider:
	provider_id = p_provider_id
	supported_artifact_kinds = p_supported_artifact_kinds.duplicate()
	metadata = p_metadata.duplicate(true)
	return self


## 判断 Provider 是否支持该 artifact。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param artifact: artifact 字典。
## [br]
## @schema artifact: Dictionary with optional kind or artifact_kind.
## [br]
## @return 支持时返回 true。
func supports_artifact(artifact: Dictionary) -> bool:
	if supported_artifact_kinds.is_empty():
		return true
	var artifact_kind: String = _get_artifact_kind(artifact)
	return not artifact_kind.is_empty() and supported_artifact_kinds.has(artifact_kind)


## 执行策略。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param artifact: artifact 字典。
## [br]
## @param context: 调用方上下文。
## [br]
## @schema artifact: Dictionary policy input artifact.
## [br]
## @schema context: Dictionary caller-defined policy context.
## [br]
## @return 策略结果。
## [br]
## @schema return: Dictionary with ok, status, provider_id, artifact_kind, issues, data, and metadata.
func evaluate(artifact: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not supports_artifact(artifact):
		return make_result(true, &"skipped", artifact, [], { "reason": "unsupported_artifact_kind" })
	var result: Dictionary = _evaluate_policy(artifact.duplicate(true), context.duplicate(true))
	if result.is_empty():
		return make_result(true, &"passed", artifact)
	return _normalize_result(result, artifact)


## 创建策略结果。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param ok: 策略是否通过。
## [br]
## @param status: 策略状态。
## [br]
## @param artifact: artifact 字典。
## [br]
## @param issues: issue 字典数组。
## [br]
## @param data: 策略输出数据。
## [br]
## @schema artifact: Dictionary policy input artifact.
## [br]
## @schema issues: Array[Dictionary] policy issues.
## [br]
## @schema data: Dictionary policy output data.
## [br]
## @return 策略结果。
## [br]
## @schema return: Dictionary with ok, status, provider_id, artifact_kind, issues, data, and metadata.
func make_result(
	ok: bool,
	status: StringName,
	artifact: Dictionary,
	issues: Array = [],
	data: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"provider_id": provider_id,
		"artifact_kind": _get_artifact_kind(artifact),
		"issues": issues.duplicate(true),
		"data": data.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing provider_id, supported_artifact_kinds, priority, deterministic, and metadata.
func get_debug_snapshot() -> Dictionary:
	return {
		"provider_id": String(provider_id),
		"display_name": display_name,
		"supported_artifact_kinds": supported_artifact_kinds.duplicate(),
		"priority": priority,
		"deterministic": deterministic,
		"metadata": metadata.duplicate(true),
	}


# --- 可重写钩子 / 虚方法 ---

## 执行具体策略，供子类重写。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _artifact: artifact 字典副本。
## [br]
## @param _context: 调用方上下文字典副本。
## [br]
## @schema _artifact: Dictionary policy input artifact.
## [br]
## @schema _context: Dictionary caller-defined policy context.
## [br]
## @return 策略结果；返回空字典表示通过。
## [br]
## @schema return: Dictionary policy result; empty means passed.
func _evaluate_policy(_artifact: Dictionary, _context: Dictionary) -> Dictionary:
	return {}


# --- 私有/辅助方法 ---

func _normalize_result(result: Dictionary, artifact: Dictionary) -> Dictionary:
	var status: StringName = GFVariantData.get_option_string_name(result, "status", &"passed")
	var ok: bool = GFVariantData.get_option_bool(result, "ok", not _status_implies_failure(status))
	if _status_implies_failure(status):
		ok = false
	var normalized: Dictionary = make_result(
		ok,
		status,
		artifact,
		GFVariantData.get_option_array(result, "issues"),
		GFVariantData.get_option_dictionary(result, "data")
	)
	var result_metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")
	if not result_metadata.is_empty():
		normalized["metadata"] = GFVariantData.merge_dictionary(
			GFVariantData.get_option_dictionary(normalized, "metadata"),
			result_metadata,
			true,
			true
		)

	for key: Variant in result.keys():
		if _is_reserved_result_key(key):
			continue
		normalized[key] = GFVariantData.duplicate_variant(result[key], true, true)
	return normalized


static func _get_artifact_kind(artifact: Dictionary) -> String:
	return GFVariantData.get_option_string(
		artifact,
		"artifact_kind",
		GFVariantData.get_option_string(artifact, "kind")
	)


static func _status_implies_failure(status: StringName) -> bool:
	return [
		&"blocked",
		&"denied",
		&"error",
		&"failed",
		&"rejected",
	].has(status)


static func _is_reserved_result_key(key: Variant) -> bool:
	var text: String = GFVariantData.to_text(key)
	return [
		"artifact_kind",
		"data",
		"issues",
		"metadata",
		"ok",
		"provider_id",
		"status",
	].has(text)
