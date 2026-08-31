# Project Layout 内部 schema-v1 profile compiler。
#
# 该脚本没有 class_name，只供 GFProjectLayoutAnalyzer 与
# GFProjectLayoutPlanner 预加载；它不进入 public class catalog。
extends RefCounted


# --- 常量 ---

const _BOUNDED_JSON_OBJECT_READER_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd"
)
const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)
const _CONTRACT_PATH: String = "res://addons/gf/tools/project_layout/contracts/project_profile_v1.contract.json"

const _CONTRACT_SCHEMA_VERSION: int = 1
const _CONTRACT_ID: String = "gf.project_layout.profile.v1"
# 该值只派生自 canonical contract 原始 bytes，不承载任何 profile 语义；
# 文件身份漂移时 compiler 与所有 compilation consumer 都必须失败关闭。
const _CANONICAL_CONTRACT_SHA256: String = "31384c45fa02238ac6fd1715ea361011ad795fbc3ee8337c581e1e9271c3bb9e"
const _BOOTSTRAP_REASON_CONTRACT_UNAVAILABLE: String = "PROJECT_LAYOUT_PROFILE_CONTRACT_UNAVAILABLE"
const _BOOTSTRAP_REASON_CONTRACT_INVALID: String = "PROJECT_LAYOUT_PROFILE_CONTRACT_INVALID"
const _RESOURCE_LIMIT_REASON_CODE: String = "PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED"
const _MAX_PROFILE_DEPTH: int = 64
const _MAX_PROFILE_STRUCTURE_VALUES: int = 65_536
const _MAX_PROFILE_COLLECTION_ITEMS: int = 8_192
const _MAX_PROFILE_STRING_LENGTH: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
const _MAX_PROFILE_STRING_BYTES: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES
const _MAX_PROFILE_WORK_UNITS: int = 262_144
const _MAX_PROFILE_DIAGNOSTICS: int = 256
const _REGEX_DIALECT: String = "portable_safe_v1"
const _REGEX_MAX_UTF8_BYTES: int = 1_024
const _REGEX_MAX_ALTERNATIVES: int = 32
const _REGEX_MAX_QUANTIFIERS_PER_BRANCH: int = 1
const _REGEX_ALLOWED_ESCAPED_LITERALS: String = "\\.^$*+?()[]{}|/-"
const _MAX_OPERATION_SCOPE_DEPTH: int = 8
const _MAX_OPERATION_SCOPE_STRUCTURE_VALUES: int = 4_096
const _MAX_OPERATION_SCOPE_COLLECTION_ITEMS: int = 128
const _MAX_OPERATION_SCOPE_REGISTRY_ENTRIES: int = 64
const _MAX_OPERATION_SCOPE_EXECUTED_FIELDS: int = 128
const _SEVERITY_DOMAIN: PackedStringArray = ["error", "warning", "info"]
const _NAMING_TARGET_DOMAIN: PackedStringArray = ["path", "name", "stem"]
const _CONTRACT_FIELDS: PackedStringArray = [
	"contract_schema_version",
	"contract_id",
	"profile_schema_versions",
	"domains",
	"semantics",
	"profile_fields",
	"zone_fields",
	"rule_common_fields",
	"rule_compatibility_fields",
	"rule_kinds",
	"reason_codes",
]
const _DOMAIN_FIELDS: PackedStringArray = ["severity", "naming_target"]
const _SEMANTICS_FIELDS: PackedStringArray = [
	"regex_match_mode",
	"regex_dialect",
	"regex_max_utf8_bytes",
	"regex_max_alternatives",
	"regex_max_quantifiers_per_branch",
	"regex_ascii_only",
	"regex_allow_groups",
	"regex_allowed_escaped_literals",
	"collection_duplicate_policy",
	"feature_contract_combination",
	"relative_path",
	"extension",
	"glob",
]
const _RELATIVE_PATH_SEMANTICS_FIELDS: PackedStringArray = [
	"allow_dot_segments",
	"allow_empty_segments",
	"allow_wildcards",
]
const _EXTENSION_SEMANTICS_FIELDS: PackedStringArray = [
	"trim_whitespace",
	"lowercase",
	"add_missing_leading_dot",
]
const _GLOB_SEMANTICS_FIELDS: PackedStringArray = [
	"match_entire_path",
	"single_star_crosses_separator",
	"double_star_crosses_separator",
	"double_star_slash_matches_zero_segments",
	"allow_dot_segments",
	"allow_empty_segments",
	"allow_trailing_separator",
	"allow_question_mark",
	"allow_character_classes",
	"allow_triple_star",
]
const _FIELD_TYPES: PackedStringArray = [
	"bool",
	"enum",
	"exact_integer",
	"extension_list",
	"glob_list",
	"non_empty_string",
	"object",
	"object_array",
	"positive_integer",
	"regex",
	"relative_path_list",
	"string",
]
const _FIELD_DESCRIPTOR_FIELDS: PackedStringArray = [
	"type",
	"required",
	"allow_empty",
	"default",
	"domain",
	"requires_capability",
	"empty_semantics",
]
const _RULE_DESCRIPTOR_FIELDS: PackedStringArray = ["default_severity", "fields"]
const _OPERATION_SCOPE_FIELDS: PackedStringArray = [
	"executor_id",
	"operation",
	"rule_registry",
	"unsupported_rule_policy",
	"zone_executed_fields",
]
const _REGISTRY_ENTRY_FIELDS: PackedStringArray = ["handler", "executed_fields"]
const _OPERATION_HANDLER_ARGUMENT_COUNTS: Dictionary = {
	"analyze": 4,
	"plan": 3,
}
const _REQUIRED_REASON_KEYS: PackedStringArray = [
	"contract_unavailable",
	"contract_invalid",
	"schema_version_unsupported",
	"required_field_missing",
	"field_unsupported",
	"field_type_invalid",
	"field_value_invalid",
	"duplicate_id",
	"relative_path_invalid",
	"regex_invalid",
	"regex_unsafe",
	"resource_limit",
	"field_not_executed",
	"rule_unsupported_by_executor",
	"registry_invalid",
	"collection_value_duplicate",
	"zone_extension_not_allowed",
	"zone_extension_denied",
]


# --- 私有变量 ---

var _profile_work_units: int = 0
var _profile_compile_terminal: bool = false


# --- 框架内部方法 ---

## 判断摘要是否精确绑定当前规范版本的 canonical contract bytes。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param contract_digest: 待验证的摘要。
## [br]
## @return: 是否与唯一派生的 canonical contract SHA-256 完全一致。
static func contract_digest_is_canonical_for_framework(contract_digest: String) -> bool:
	return contract_digest == _CANONICAL_CONTRACT_SHA256


## 按 canonical contract 编译 profile，并按真实 executor registry 派生能力。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param profile: 调用方提供的 schema-v1 profile。
## [br]
## @schema profile: Dictionary，字段契约由 project_profile_v1.contract.json 定义。
## [br]
## @param operation_scope: executor ID、operation、Callable rule registry、zone 已执行字段和 unsupported-rule policy。
## [br]
## @schema operation_scope: Dictionary，包含 executor_id、operation、rule_registry、unsupported_rule_policy 和 zone_executed_fields。
## [br]
## @return: 编译结果、规范化 profile、诊断和从 registry 派生的 capabilities。
## [br]
## @schema return: Dictionary，精确包含 success、profile、issues、error_count、warning_count、contract_id、contract_digest 和 capabilities；contract_digest 绑定本次实际解析的 canonical contract bytes；capabilities 在 contract/registry 失败时为 {}，否则是闭集，包含 executor_id: String、operation: String、rule_kinds: Array[String]、rule_fields: Dictionary[String, Array[String]] 和 zone_fields: Array[String]。
func compile_profile(profile: Dictionary, operation_scope: Dictionary) -> Dictionary:
	_profile_work_units = 0
	_profile_compile_terminal = false
	var result: Dictionary = _make_compile_result()
	if not _operation_scope_structure_is_admissible(operation_scope, result):
		return _finalize_result(result)
	if not _profile_structure_is_admissible(profile, result):
		return _finalize_result(result)
	var contract_result: Dictionary = _load_contract()
	if not _get_bool(contract_result, "success"):
		_add_issue(
			result,
			"error",
			_get_string(contract_result, "kind", "profile_contract_unavailable"),
			_get_string(contract_result, "reason_code", _BOOTSTRAP_REASON_CONTRACT_UNAVAILABLE),
			"",
			_get_string(contract_result, "message", "项目结构 profile contract 不可用。")
		)
		return _finalize_result(result)

	var contract_value: Variant = contract_result.get("contract", {})
	if not contract_value is Dictionary:
		_add_issue(
			result,
			"error",
			"profile_contract_invalid",
			_BOOTSTRAP_REASON_CONTRACT_INVALID,
			"",
			"项目结构 profile contract 根节点无效。"
		)
		return _finalize_result(result)
	var contract: Dictionary = contract_value
	result["contract_id"] = _get_string(contract, "contract_id")
	result["contract_digest"] = _get_string(contract_result, "contract_digest")

	var scope_result: Dictionary = _compile_operation_scope(operation_scope, contract, result)
	if _get_int(result, "error_count") > 0:
		return _finalize_result(result)
	result["capabilities"] = _get_dictionary(scope_result, "capabilities").duplicate(true)

	var compiled_profile: Dictionary = _compile_profile_data(profile, contract, scope_result, result)
	if _profile_compile_terminal:
		return _finalize_result(result)
	result["profile"] = compiled_profile
	# 成功 compilation 本身也必须落在与 Analyzer/Worker 一致的 data-only
	# 文本封套内；否则 profile 虽可编译，却无法经过公开消费链。
	if not _profile_structure_is_admissible(result, result):
		return _finalize_result(result)
	return _finalize_result(result)


# --- 私有/辅助方法 ---

func _make_compile_result() -> Dictionary:
	return {
		"success": false,
		"profile": {},
		"issues": [],
		"error_count": 0,
		"warning_count": 0,
		"contract_id": "",
		"contract_digest": "",
		"capabilities": {},
	}


func _operation_scope_structure_is_admissible(
	operation_scope: Dictionary,
	result: Dictionary
) -> bool:
	if operation_scope.size() > _OPERATION_SCOPE_FIELDS.size():
		_fail_profile_compile_limit(result, "operation_scope_fields")
		return false
	var registry_value: Variant = operation_scope.get("rule_registry")
	if registry_value is Dictionary:
		var registry: Dictionary = registry_value
		if registry.size() > _MAX_OPERATION_SCOPE_REGISTRY_ENTRIES:
			_fail_profile_compile_limit(result, "operation_scope_registry")
			return false
	var zone_fields_value: Variant = operation_scope.get("zone_executed_fields")
	if zone_fields_value is Array:
		var zone_fields: Array = zone_fields_value
		if zone_fields.size() > _MAX_OPERATION_SCOPE_EXECUTED_FIELDS:
			_fail_profile_compile_limit(result, "operation_scope_zone_fields")
			return false
	elif zone_fields_value is PackedStringArray:
		var packed_zone_fields: PackedStringArray = zone_fields_value
		if packed_zone_fields.size() > _MAX_OPERATION_SCOPE_EXECUTED_FIELDS:
			_fail_profile_compile_limit(result, "operation_scope_zone_fields")
			return false

	var stack: Array = [{
		"value": operation_scope,
		"depth": 0,
		"exit": false,
	}]
	var active_containers: Array = []
	var structure_value_count: int = 0
	var string_bytes: int = 0
	while not stack.is_empty():
		var frame_value: Variant = stack.pop_back()
		if not frame_value is Dictionary:
			_fail_profile_compile_limit(result, "operation_scope_structure")
			return false
		var frame: Dictionary = frame_value
		var value: Variant = frame.get("value")
		if _get_bool(frame, "exit"):
			if not active_containers.is_empty():
				var _removed_container: Variant = active_containers.pop_back()
			continue
		if not _consume_profile_work(result):
			return false
		structure_value_count += 1
		if structure_value_count > _MAX_OPERATION_SCOPE_STRUCTURE_VALUES:
			_fail_profile_compile_limit(result, "operation_scope_structure")
			return false
		var depth: int = _get_int(frame, "depth")
		if depth > _MAX_OPERATION_SCOPE_DEPTH:
			_fail_profile_compile_limit(result, "operation_scope_depth")
			return false
		if value is String:
			var text: String = value
			if text.length() > _MAX_PROFILE_STRING_LENGTH:
				_fail_profile_compile_limit(result, "operation_scope_string")
				return false
			var text_bytes: int = text.to_utf8_buffer().size()
			if string_bytes > _MAX_PROFILE_STRING_BYTES - text_bytes:
				_fail_profile_compile_limit(result, "operation_scope_string_bytes")
				return false
			string_bytes += text_bytes
			if not _consume_profile_work(result, ceili(float(text_bytes) / 256.0)):
				return false
			continue
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if (
				dictionary_value.size() > _MAX_OPERATION_SCOPE_COLLECTION_ITEMS
				or _active_profile_container_exists(active_containers, dictionary_value)
			):
				_fail_profile_compile_limit(result, "operation_scope_collection")
				return false
			active_containers.append(dictionary_value)
			stack.append({ "value": dictionary_value, "depth": depth, "exit": true })
			var keys: Array = dictionary_value.keys()
			for key_index: int in range(keys.size() - 1, -1, -1):
				var key: Variant = keys[key_index]
				if not key is String:
					_fail_profile_compile_limit(result, "dictionary_key")
					return false
				stack.append({ "value": dictionary_value[key], "depth": depth + 1, "exit": false })
				stack.append({ "value": key, "depth": depth + 1, "exit": false })
			continue
		if value is Array:
			var array_value: Array = value
			if (
				array_value.size() > _MAX_OPERATION_SCOPE_COLLECTION_ITEMS
				or _active_profile_container_exists(active_containers, array_value)
			):
				_fail_profile_compile_limit(result, "operation_scope_collection")
				return false
			active_containers.append(array_value)
			stack.append({ "value": array_value, "depth": depth, "exit": true })
			for item_index: int in range(array_value.size() - 1, -1, -1):
				stack.append({ "value": array_value[item_index], "depth": depth + 1, "exit": false })
			continue
		if value is PackedStringArray:
			var packed_values: PackedStringArray = value
			if packed_values.size() > _MAX_OPERATION_SCOPE_EXECUTED_FIELDS:
				_fail_profile_compile_limit(result, "operation_scope_executed_fields")
				return false
			for text: String in packed_values:
				structure_value_count += 1
				if (
					structure_value_count > _MAX_OPERATION_SCOPE_STRUCTURE_VALUES
					or text.length() > _MAX_PROFILE_STRING_LENGTH
				):
					_fail_profile_compile_limit(result, "operation_scope_string")
					return false
				var text_bytes: int = text.to_utf8_buffer().size()
				if string_bytes > _MAX_PROFILE_STRING_BYTES - text_bytes:
					_fail_profile_compile_limit(result, "operation_scope_string_bytes")
					return false
				string_bytes += text_bytes
				if not _consume_profile_work(
					result,
					1 + ceili(float(text_bytes) / 256.0)
				):
					return false
			continue
		if value is Callable or value == null or value is bool or value is int:
			continue
		if value is float:
			var float_value: float = value
			if not is_finite(float_value):
				_fail_profile_compile_limit(result, "operation_scope_number")
				return false
			continue
		_fail_profile_compile_limit(result, "operation_scope_value")
		return false
	return true


func _profile_structure_is_admissible(profile: Dictionary, result: Dictionary) -> bool:
	var stack: Array = [{
		"value": profile,
		"depth": 0,
		"exit": false,
	}]
	var active_containers: Array = []
	var structure_value_count: int = 0
	var string_bytes: int = 0
	while not stack.is_empty():
		var frame_value: Variant = stack.pop_back()
		if not frame_value is Dictionary:
			_fail_profile_compile_limit(result, "structure")
			return false
		var frame: Dictionary = frame_value
		var value: Variant = frame.get("value")
		if _get_bool(frame, "exit"):
			if not active_containers.is_empty():
				var _removed_container: Variant = active_containers.pop_back()
			continue
		if not _consume_profile_work(result):
			return false
		structure_value_count += 1
		if structure_value_count > _MAX_PROFILE_STRUCTURE_VALUES:
			_fail_profile_compile_limit(result, "structure")
			return false
		var depth: int = _get_int(frame, "depth")
		if depth > _MAX_PROFILE_DEPTH:
			_fail_profile_compile_limit(result, "depth")
			return false
		if value is String:
			var text: String = value
			if text.length() > _MAX_PROFILE_STRING_LENGTH:
				_fail_profile_compile_limit(result, "string_length")
				return false
			var text_bytes: int = text.to_utf8_buffer().size()
			if string_bytes > _MAX_PROFILE_STRING_BYTES - text_bytes:
				_fail_profile_compile_limit(result, "string_bytes")
				return false
			string_bytes += text_bytes
			var text_work_units: int = ceili(float(text_bytes) / 256.0)
			if not _consume_profile_work(result, text_work_units):
				return false
			continue
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if dictionary_value.size() > _MAX_PROFILE_COLLECTION_ITEMS:
				_fail_profile_compile_limit(result, "collection_items")
				return false
			if _active_profile_container_exists(active_containers, dictionary_value):
				_fail_profile_compile_limit(result, "cyclic_structure")
				return false
			active_containers.append(dictionary_value)
			stack.append({ "value": dictionary_value, "depth": depth, "exit": true })
			var keys: Array = dictionary_value.keys()
			for key_index: int in range(keys.size() - 1, -1, -1):
				var key: Variant = keys[key_index]
				if not key is String:
					_fail_profile_compile_limit(result, "dictionary_key")
					return false
				stack.append({ "value": dictionary_value[key], "depth": depth + 1, "exit": false })
				stack.append({ "value": key, "depth": depth + 1, "exit": false })
			continue
		if value is Array:
			var array_value: Array = value
			if array_value.size() > _MAX_PROFILE_COLLECTION_ITEMS:
				_fail_profile_compile_limit(result, "collection_items")
				return false
			if _active_profile_container_exists(active_containers, array_value):
				_fail_profile_compile_limit(result, "cyclic_structure")
				return false
			active_containers.append(array_value)
			stack.append({ "value": array_value, "depth": depth, "exit": true })
			for item_index: int in range(array_value.size() - 1, -1, -1):
				stack.append({ "value": array_value[item_index], "depth": depth + 1, "exit": false })
			continue
		if value == null or value is bool or value is int:
			continue
		if value is float:
			var float_value: float = value
			if not is_finite(float_value):
				_fail_profile_compile_limit(result, "non_finite_number")
				return false
			continue
		_fail_profile_compile_limit(result, "non_json_value")
		return false
	return true


func _active_profile_container_exists(active_containers: Array, value: Variant) -> bool:
	for active_value: Variant in active_containers:
		if is_same(active_value, value):
			return true
	return false


func _consume_profile_work(result: Dictionary, work_units: int = 1) -> bool:
	if _profile_compile_terminal:
		return false
	if work_units < 0 or _profile_work_units > _MAX_PROFILE_WORK_UNITS - work_units:
		_fail_profile_compile_limit(result, "work_units")
		return false
	_profile_work_units += work_units
	return true


func _fail_profile_compile_limit(result: Dictionary, _limit_name: String) -> void:
	if _profile_compile_terminal:
		return
	_profile_compile_terminal = true
	var issues: Array = _get_array(result, "issues")
	issues.clear()
	issues.append({
		"severity": "error",
		"kind": "profile_compile_resource_limit_exceeded",
		"reason_code": _RESOURCE_LIMIT_REASON_CODE,
		"path": "",
		"message": "项目结构 profile 超出不可关闭的编译资源边界。",
		"context": {},
	})
	result["profile"] = {}
	result["capabilities"] = {}
	result["contract_id"] = ""
	result["contract_digest"] = ""
	result["error_count"] = 1
	result["warning_count"] = 0


func _load_contract() -> Dictionary:
	var read_result: Dictionary = (
		_BOUNDED_JSON_OBJECT_READER_SCRIPT.read_object_with_content_sha256(
			_CONTRACT_PATH
		)
	)
	if not _get_bool(read_result, "ok"):
		return _contract_read_failure_result(read_result)
	var contract_digest: String = _get_string(read_result, "content_sha256")
	if not contract_digest_is_canonical_for_framework(contract_digest):
		return {
			"success": false,
			"kind": "profile_contract_invalid",
			"reason_code": _BOOTSTRAP_REASON_CONTRACT_INVALID,
			"message": "项目结构 profile contract 与规范版本身份不一致。",
		}
	var contract_value: Variant = read_result.get("data", {})
	if not contract_value is Dictionary:
		return {
			"success": false,
			"kind": "profile_contract_invalid",
			"reason_code": _BOOTSTRAP_REASON_CONTRACT_INVALID,
			"message": "项目结构 profile contract 不是有效 JSON Dictionary。",
		}
	var contract: Dictionary = contract_value
	if not _contract_is_valid(contract):
		return {
			"success": false,
			"kind": "profile_contract_invalid",
			"reason_code": _BOOTSTRAP_REASON_CONTRACT_INVALID,
			"message": "项目结构 profile contract 结构或描述符无效。",
		}
	return {
		"success": true,
		"contract": contract,
		"contract_digest": contract_digest,
	}


func _contract_read_failure_result(read_result: Dictionary) -> Dictionary:
	var error_kind: String = _get_string(read_result, "error_kind")
	if error_kind == "open_failed" or error_kind == "read_failed" or error_kind == "payload_too_large":
		return {
			"success": false,
			"kind": "profile_contract_unavailable",
			"reason_code": _BOOTSTRAP_REASON_CONTRACT_UNAVAILABLE,
			"message": "项目结构 profile contract 无法在读取边界内取得。",
		}
	return {
		"success": false,
		"kind": "profile_contract_invalid",
		"reason_code": _BOOTSTRAP_REASON_CONTRACT_INVALID,
		"message": "项目结构 profile contract 不是有效的有界 JSON Dictionary：%s" % _get_string(
			read_result,
			"error",
			"读取失败。"
		),
	}


func _contract_is_valid(contract: Dictionary) -> bool:
	if not _dictionary_has_exact_fields(contract, _CONTRACT_FIELDS):
		return false
	if not _is_exact_integer(contract.get("contract_schema_version")):
		return false
	if _exact_integer_value(contract.get("contract_schema_version")) != _CONTRACT_SCHEMA_VERSION:
		return false
	if _get_string(contract, "contract_id") != _CONTRACT_ID:
		return false
	var schema_versions_value: Variant = contract.get("profile_schema_versions")
	if not schema_versions_value is Array:
		return false
	var schema_versions: Array = schema_versions_value
	if schema_versions.size() != 1:
		return false
	for schema_version: Variant in schema_versions:
		if not _is_exact_integer(schema_version) or _exact_integer_value(schema_version) != 1:
			return false
	var domains_value: Variant = contract.get("domains")
	if not domains_value is Dictionary:
		return false
	var domains: Dictionary = domains_value
	if not _dictionary_has_exact_fields(domains, _DOMAIN_FIELDS):
		return false
	for domain_name: String in _DOMAIN_FIELDS:
		if not _string_collection_is_valid(domains.get(domain_name), false, true):
			return false
	if _to_string_list(domains.get("severity")) != _SEVERITY_DOMAIN:
		return false
	if _to_string_list(domains.get("naming_target")) != _NAMING_TARGET_DOMAIN:
		return false
	for field_map_name: String in ["profile_fields", "zone_fields", "rule_common_fields", "rule_compatibility_fields"]:
		var field_map_value: Variant = contract.get(field_map_name)
		if not field_map_value is Dictionary:
			return false
		var field_map: Dictionary = field_map_value
		if not _field_map_is_valid(field_map, contract):
			return false
	if not _contract_core_fields_are_valid(contract):
		return false
	var rule_kinds_value: Variant = contract.get("rule_kinds")
	if not rule_kinds_value is Dictionary:
		return false
	var rule_kinds: Dictionary = rule_kinds_value
	if rule_kinds.is_empty():
		return false
	for rule_kind_value: Variant in rule_kinds.keys():
		if not _is_non_empty_string_value(rule_kind_value):
			return false
		var rule_descriptor_value: Variant = rule_kinds[rule_kind_value]
		if not rule_descriptor_value is Dictionary:
			return false
		var rule_descriptor: Dictionary = rule_descriptor_value
		if not _dictionary_has_only_fields(rule_descriptor, _RULE_DESCRIPTOR_FIELDS):
			return false
		var default_severity: String = _get_string(rule_descriptor, "default_severity")
		if not _domain_has_value(contract, "severity", default_severity):
			return false
		var fields_value: Variant = rule_descriptor.get("fields")
		if not fields_value is Dictionary:
			return false
		var fields: Dictionary = fields_value
		if not _field_map_is_valid(fields, contract):
			return false
	var reason_codes_value: Variant = contract.get("reason_codes")
	if not reason_codes_value is Dictionary:
		return false
	var reason_codes: Dictionary = reason_codes_value
	if not _dictionary_has_exact_fields(reason_codes, _REQUIRED_REASON_KEYS):
		return false
	var seen_reason_codes: Dictionary = {}
	for reason_key: String in _REQUIRED_REASON_KEYS:
		var reason_code: String = _get_string(reason_codes, reason_key)
		if reason_code.strip_edges().is_empty() or seen_reason_codes.has(reason_code):
			return false
		seen_reason_codes[reason_code] = true
	if _get_string(reason_codes, "contract_unavailable") != _BOOTSTRAP_REASON_CONTRACT_UNAVAILABLE:
		return false
	if _get_string(reason_codes, "contract_invalid") != _BOOTSTRAP_REASON_CONTRACT_INVALID:
		return false
	if _get_string(reason_codes, "regex_unsafe") != "PROJECT_LAYOUT_PROFILE_REGEX_UNSAFE":
		return false
	if _get_string(reason_codes, "resource_limit") != _RESOURCE_LIMIT_REASON_CODE:
		return false
	return _semantics_are_valid(contract)


func _contract_core_fields_are_valid(contract: Dictionary) -> bool:
	var profile_fields: Dictionary = _get_dictionary(contract, "profile_fields")
	var zone_fields: Dictionary = _get_dictionary(contract, "zone_fields")
	var rule_common_fields: Dictionary = _get_dictionary(contract, "rule_common_fields")
	return (
		_descriptor_matches(profile_fields, "schema_version", "exact_integer", true)
		and _descriptor_matches(profile_fields, "id", "non_empty_string", true)
		and _descriptor_matches(profile_fields, "zones", "object_array", true)
		and _descriptor_matches(profile_fields, "rules", "object_array", true)
		and _descriptor_matches(zone_fields, "id", "non_empty_string", true)
		and _descriptor_matches(zone_fields, "roots", "relative_path_list", true)
		and _descriptor_matches(rule_common_fields, "id", "non_empty_string", true)
		and _descriptor_matches(rule_common_fields, "kind", "non_empty_string", true)
	)


func _descriptor_matches(
	field_map: Dictionary,
	field_name: String,
	expected_type: String,
	required: bool
) -> bool:
	var descriptor_value: Variant = field_map.get(field_name)
	if not descriptor_value is Dictionary:
		return false
	var descriptor: Dictionary = descriptor_value
	return _get_string(descriptor, "type") == expected_type and _get_bool(descriptor, "required") == required


func _field_map_is_valid(field_map: Dictionary, contract: Dictionary) -> bool:
	for field_name_value: Variant in field_map.keys():
		if not _is_non_empty_string_value(field_name_value):
			return false
		var descriptor_value: Variant = field_map[field_name_value]
		if not descriptor_value is Dictionary:
			return false
		var descriptor: Dictionary = descriptor_value
		if not _field_descriptor_is_valid(descriptor, contract):
			return false
	return true


func _field_descriptor_is_valid(descriptor: Dictionary, contract: Dictionary) -> bool:
	if not _dictionary_has_only_fields(descriptor, _FIELD_DESCRIPTOR_FIELDS):
		return false
	var field_type: String = _get_string(descriptor, "type")
	if not _FIELD_TYPES.has(field_type):
		return false
	for bool_field: String in ["required", "allow_empty", "requires_capability"]:
		if descriptor.has(bool_field) and not descriptor[bool_field] is bool:
			return false
	if descriptor.has("allow_empty") and not field_type.ends_with("_list"):
		return false
	if descriptor.has("domain"):
		var domain_name: String = _get_string(descriptor, "domain")
		if field_type != "enum" or not _contract_has_domain(contract, domain_name):
			return false
	if field_type == "enum" and not descriptor.has("domain"):
		return false
	if descriptor.has("empty_semantics") and not _is_non_empty_string_value(descriptor["empty_semantics"]):
		return false
	if descriptor.has("empty_semantics"):
		if not field_type.ends_with("_list") or _get_string(descriptor, "empty_semantics") != "deny_all":
			return false
	if descriptor.has("default") and not _raw_value_matches_descriptor(descriptor["default"], descriptor, contract):
		return false
	return true


func _semantics_are_valid(contract: Dictionary) -> bool:
	var semantics_value: Variant = contract.get("semantics")
	if not semantics_value is Dictionary:
		return false
	var semantics: Dictionary = semantics_value
	if not _dictionary_has_exact_fields(semantics, _SEMANTICS_FIELDS):
		return false
	if _get_string(semantics, "regex_match_mode") != "search":
		return false
	if _get_string(semantics, "regex_dialect") != _REGEX_DIALECT:
		return false
	if _get_int(semantics, "regex_max_utf8_bytes") != _REGEX_MAX_UTF8_BYTES:
		return false
	if _get_int(semantics, "regex_max_alternatives") != _REGEX_MAX_ALTERNATIVES:
		return false
	if (
		_get_int(semantics, "regex_max_quantifiers_per_branch")
		!= _REGEX_MAX_QUANTIFIERS_PER_BRANCH
	):
		return false
	if not semantics.get("regex_ascii_only") is bool or not _get_bool(semantics, "regex_ascii_only"):
		return false
	if not semantics.get("regex_allow_groups") is bool or _get_bool(semantics, "regex_allow_groups", true):
		return false
	if (
		_get_string(semantics, "regex_allowed_escaped_literals")
		!= _REGEX_ALLOWED_ESCAPED_LITERALS
	):
		return false
	if _get_string(semantics, "collection_duplicate_policy") != "preserve_first_warn":
		return false
	if _get_string(semantics, "feature_contract_combination") != "all_match_union_paths":
		return false
	var relative_path_value: Variant = semantics.get("relative_path")
	if not relative_path_value is Dictionary:
		return false
	var relative_path: Dictionary = relative_path_value
	if not _dictionary_has_exact_fields(relative_path, _RELATIVE_PATH_SEMANTICS_FIELDS):
		return false
	for field_name: String in _RELATIVE_PATH_SEMANTICS_FIELDS:
		if not relative_path[field_name] is bool or _get_bool(relative_path, field_name, true):
			return false
	var extension_value: Variant = semantics.get("extension")
	if not extension_value is Dictionary:
		return false
	var extension: Dictionary = extension_value
	if not _dictionary_has_exact_fields(extension, _EXTENSION_SEMANTICS_FIELDS):
		return false
	for field_name: String in _EXTENSION_SEMANTICS_FIELDS:
		if not extension[field_name] is bool or not _get_bool(extension, field_name):
			return false
	var glob_value: Variant = semantics.get("glob")
	if not glob_value is Dictionary:
		return false
	var glob: Dictionary = glob_value
	if not _dictionary_has_exact_fields(glob, _GLOB_SEMANTICS_FIELDS):
		return false
	for field_name: String in _GLOB_SEMANTICS_FIELDS:
		if not glob[field_name] is bool:
			return false
	return (
		_get_bool(glob, "match_entire_path")
		and not _get_bool(glob, "single_star_crosses_separator", true)
		and _get_bool(glob, "double_star_crosses_separator")
		and _get_bool(glob, "double_star_slash_matches_zero_segments")
		and not _get_bool(glob, "allow_dot_segments", true)
		and not _get_bool(glob, "allow_empty_segments", true)
		and not _get_bool(glob, "allow_trailing_separator", true)
		and not _get_bool(glob, "allow_question_mark", true)
		and not _get_bool(glob, "allow_character_classes", true)
		and not _get_bool(glob, "allow_triple_star", true)
	)


func _compile_operation_scope(operation_scope: Dictionary, contract: Dictionary, result: Dictionary) -> Dictionary:
	if not _consume_profile_work(result):
		return {}
	if not _dictionary_has_only_fields(operation_scope, _OPERATION_SCOPE_FIELDS):
		_add_registry_issue(contract, result, "operation_scope 包含未知字段。")
		return {}
	var executor_id: String = _get_string(operation_scope, "executor_id")
	var operation: String = _get_string(operation_scope, "operation")
	var unsupported_policy: String = _get_string(operation_scope, "unsupported_rule_policy")
	if (
		executor_id.is_empty()
		or not _OPERATION_HANDLER_ARGUMENT_COUNTS.has(operation)
		or not ["error", "schema_only"].has(unsupported_policy)
	):
		_add_registry_issue(contract, result, "operation_scope 缺少有效 executor、operation 或 unsupported policy。")
		return {}
	var expected_handler_argument_count: int = _get_int(_OPERATION_HANDLER_ARGUMENT_COUNTS, operation)
	var zone_fields_value: Variant = operation_scope.get("zone_executed_fields")
	if not _string_collection_is_valid(zone_fields_value, true, true):
		_add_registry_issue(contract, result, "operation_scope zone_executed_fields 必须是字符串数组。")
		return {}
	var zone_fields: PackedStringArray = _to_string_list(zone_fields_value)
	var zone_definitions: Dictionary = _get_dictionary(contract, "zone_fields")
	for field_name: String in zone_fields:
		if not _consume_profile_work(result):
			return {}
		if not zone_definitions.has(field_name):
			_add_registry_issue(contract, result, "operation_scope 声明了 contract 未定义的 zone 字段。")
			return {}

	var registry_value: Variant = operation_scope.get("rule_registry")
	if not registry_value is Dictionary:
		_add_registry_issue(contract, result, "operation_scope rule_registry 必须是 Dictionary。")
		return {}
	var registry: Dictionary = registry_value
	var rule_kinds: Dictionary = _get_dictionary(contract, "rule_kinds")
	var capability_rule_kinds: Array[String] = []
	var capability_rule_fields: Dictionary = {}
	for rule_kind_value: Variant in registry.keys():
		if not _consume_profile_work(result):
			return {}
		var rule_kind: String = _string_value(rule_kind_value)
		if rule_kind.is_empty() or not rule_kinds.has(rule_kind):
			_add_registry_issue(contract, result, "rule_registry 声明了 contract 未定义的 rule kind。")
			return {}
		var entry_value: Variant = registry[rule_kind_value]
		if not entry_value is Dictionary:
			_add_registry_issue(contract, result, "rule_registry entry 必须是 Dictionary。")
			return {}
		var entry: Dictionary = entry_value
		if not _dictionary_has_only_fields(entry, _REGISTRY_ENTRY_FIELDS):
			_add_registry_issue(contract, result, "rule_registry entry 包含未知字段。")
			return {}
		var handler_value: Variant = entry.get("handler")
		if not handler_value is Callable:
			_add_registry_issue(contract, result, "rule_registry handler 必须是 Callable。")
			return {}
		var handler: Callable = handler_value
		if not handler.is_valid():
			_add_registry_issue(contract, result, "rule_registry handler 无效。")
			return {}
		if handler.get_argument_count() != expected_handler_argument_count:
			_add_registry_issue(contract, result, "rule_registry handler 参数数量与 operation 执行协议不一致。")
			return {}
		var executed_fields_value: Variant = entry.get("executed_fields")
		if not _string_collection_is_valid(executed_fields_value, true, true):
			_add_registry_issue(contract, result, "rule_registry executed_fields 必须是字符串数组。")
			return {}
		var executed_fields: PackedStringArray = _to_string_list(executed_fields_value)
		var allowed_fields: Dictionary = _rule_field_definitions(contract, rule_kind)
		for field_name: String in executed_fields:
			if not _consume_profile_work(result):
				return {}
			if not allowed_fields.has(field_name):
				_add_registry_issue(contract, result, "rule_registry 声明了 contract 未定义的 rule 字段。")
				return {}
		capability_rule_kinds.append(rule_kind)
		var sorted_fields: Array[String] = []
		for field_name: String in executed_fields:
			sorted_fields.append(field_name)
		sorted_fields.sort()
		capability_rule_fields[rule_kind] = sorted_fields
	capability_rule_kinds.sort()
	var sorted_zone_fields: Array[String] = []
	for field_name: String in zone_fields:
		sorted_zone_fields.append(field_name)
	sorted_zone_fields.sort()
	return {
		"registry": registry,
		"unsupported_rule_policy": unsupported_policy,
		"zone_executed_fields": zone_fields,
		"capabilities": {
			"executor_id": executor_id,
			"operation": operation,
			"rule_kinds": capability_rule_kinds,
			"rule_fields": capability_rule_fields,
			"zone_fields": sorted_zone_fields,
		},
	}


func _compile_profile_data(profile: Dictionary, contract: Dictionary, scope: Dictionary, result: Dictionary) -> Dictionary:
	var profile_definitions: Dictionary = _get_dictionary(contract, "profile_fields")
	var compiled: Dictionary = _compile_fields(
		profile,
		profile_definitions,
		contract,
		result,
		"profile",
		_get_string(profile, "id"),
		PackedStringArray(),
		false,
		PackedStringArray(["zones", "rules"])
	)
	var schema_version_value: Variant = compiled.get("schema_version")
	if _is_exact_integer(schema_version_value):
		var schema_version: int = _exact_integer_value(schema_version_value)
		if not _contract_supports_profile_schema(contract, schema_version):
			_add_issue(
				result,
				"error",
				"unsupported_schema_version",
				_reason(contract, "schema_version_unsupported"),
				"schema_version",
				"项目结构 profile schema_version 不受支持。",
				{ "actual_value": schema_version }
			)

	var zones_value: Variant = profile.get("zones")
	var compiled_zones: Array = []
	if not profile.has("zones"):
		_add_field_issue(contract, result, "profile", "profile", "zones", null, "required_field_missing")
	elif not zones_value is Array:
		_add_field_issue(contract, result, "profile", "profile", "zones", profile.get("zones"), "field_type_invalid")
	else:
		var zones: Array = zones_value
		compiled_zones = _compile_zones(zones, contract, scope, result)
	compiled["zones"] = compiled_zones

	var rules_value: Variant = profile.get("rules")
	var compiled_rules: Array = []
	if not profile.has("rules"):
		_add_field_issue(contract, result, "profile", "profile", "rules", null, "required_field_missing")
	elif not rules_value is Array:
		_add_field_issue(contract, result, "profile", "profile", "rules", profile.get("rules"), "field_type_invalid")
	else:
		var rules: Array = rules_value
		compiled_rules = _compile_rules(rules, contract, scope, result)
	compiled["rules"] = compiled_rules
	return compiled


func _compile_zones(zones: Array, contract: Dictionary, scope: Dictionary, result: Dictionary) -> Array:
	var compiled_zones: Array = []
	var seen_ids: Dictionary = {}
	var definitions: Dictionary = _get_dictionary(contract, "zone_fields")
	var executed_fields: PackedStringArray = _get_packed_string_array(scope, "zone_executed_fields")
	for zone_value: Variant in zones:
		if not _consume_profile_work(result):
			return []
		if not zone_value is Dictionary:
			_add_issue(
				result,
				"error",
				"invalid_zone",
				_reason(contract, "field_type_invalid"),
				"zones",
				"项目结构 profile zones 条目必须是 Dictionary。",
				{ "actual": _describe_value(zone_value) }
			)
			continue
		var zone: Dictionary = zone_value
		var zone_id: String = _get_string(zone, "id")
		var compiled_zone: Dictionary = _compile_fields(
			zone,
			definitions,
			contract,
			result,
			"zone",
			zone_id,
			executed_fields,
			true
		)
		var compiled_id: String = _get_string(compiled_zone, "id")
		if not compiled_id.is_empty():
			if seen_ids.has(compiled_id):
				_add_duplicate_id_issue(contract, result, "zone", compiled_id)
			else:
				seen_ids[compiled_id] = true
		compiled_zones.append(compiled_zone)
	return compiled_zones


func _compile_rules(rules: Array, contract: Dictionary, scope: Dictionary, result: Dictionary) -> Array:
	var compiled_rules: Array = []
	var seen_ids: Dictionary = {}
	var registry: Dictionary = _get_dictionary(scope, "registry")
	var unsupported_policy: String = _get_string(scope, "unsupported_rule_policy")
	var rule_kinds: Dictionary = _get_dictionary(contract, "rule_kinds")
	for rule_value: Variant in rules:
		if not _consume_profile_work(result):
			return []
		if not rule_value is Dictionary:
			_add_issue(
				result,
				"error",
				"invalid_rule",
				_reason(contract, "field_type_invalid"),
				"rules",
				"项目结构 profile rules 条目必须是 Dictionary。",
				{ "actual": _describe_value(rule_value) }
			)
			continue
		var rule: Dictionary = rule_value
		var rule_id: String = _get_string(rule, "id")
		var rule_kind: String = _get_string(rule, "kind")
		var definitions: Dictionary = _rule_field_definitions(contract, rule_kind)
		var registry_entry: Dictionary = {}
		var has_handler: bool = registry.has(rule_kind)
		if has_handler:
			var entry_value: Variant = registry[rule_kind]
			if entry_value is Dictionary:
				registry_entry = entry_value
		var executed_fields: PackedStringArray = _get_packed_string_array(registry_entry, "executed_fields")
		var compiled_rule: Dictionary = _compile_fields(
			rule,
			definitions,
			contract,
			result,
			"rule",
			rule_id,
			executed_fields,
			has_handler
		)
		var compiled_id: String = _get_string(compiled_rule, "id")
		if not compiled_id.is_empty():
			if seen_ids.has(compiled_id):
				_add_duplicate_id_issue(contract, result, "rule", compiled_id)
			else:
				seen_ids[compiled_id] = true
		if not rule_kinds.has(rule_kind):
			_add_issue(
				result,
				"error",
				"unsupported_rule_kind",
				_reason(contract, "field_value_invalid"),
				rule_kind,
				"项目结构 profile 包含 contract 未定义的规则类型。",
				{ "rule_id": rule_id }
			)
		elif not has_handler and unsupported_policy == "error":
			_add_issue(
				result,
				"error",
				"unsupported_rule_kind",
				_reason(contract, "rule_unsupported_by_executor"),
				rule_kind,
				"当前项目结构 executor 不支持该规则类型。",
				{ "rule_id": rule_id }
			)
		if rule_kinds.has(rule_kind) and not compiled_rule.has("severity"):
			var rule_descriptor_value: Variant = rule_kinds[rule_kind]
			if rule_descriptor_value is Dictionary:
				var rule_descriptor: Dictionary = rule_descriptor_value
				compiled_rule["severity"] = _get_string(rule_descriptor, "default_severity")
		compiled_rules.append(compiled_rule)
	return compiled_rules


func _compile_fields(
	source: Dictionary,
	definitions: Dictionary,
	contract: Dictionary,
	result: Dictionary,
	scope_kind: String,
	scope_id: String,
	executed_fields: PackedStringArray,
	warn_unexecuted: bool,
	skipped_fields: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var compiled: Dictionary = {}
	var allowed_fields: PackedStringArray = _dictionary_string_keys(definitions)
	for field_value: Variant in source.keys():
		if not _consume_profile_work(result):
			return {}
		var field_name: String = _string_value(field_value)
		if not field_name.is_empty() and allowed_fields.has(field_name):
			continue
		_add_issue(
			result,
			"error",
			_unsupported_field_legacy_kind(scope_kind),
			_reason(contract, "field_unsupported"),
			scope_id,
			"项目结构 profile 包含不受支持的字段。",
			{ "field": field_name, "actual": _describe_value(field_value) }
		)
	var definition_names: Array[String] = []
	for field_value: Variant in definitions.keys():
		if not _consume_profile_work(result):
			return {}
		definition_names.append(_string_value(field_value))
	definition_names.sort()
	for field_name: String in definition_names:
		if not _consume_profile_work(result):
			return {}
		if skipped_fields.has(field_name):
			continue
		var descriptor_value: Variant = definitions[field_name]
		if not descriptor_value is Dictionary:
			continue
		var descriptor: Dictionary = descriptor_value
		if not source.has(field_name):
			if descriptor.has("default"):
				compiled[field_name] = _copy_contract_value(descriptor["default"])
			elif _get_bool(descriptor, "required"):
				_add_field_issue(contract, result, scope_kind, scope_id, field_name, null, "required_field_missing")
			continue
		var field_result: Dictionary = _compile_field_value(
			source[field_name],
			descriptor,
			contract,
			result,
			scope_kind,
			scope_id,
			field_name
		)
		if not _get_bool(field_result, "success"):
			continue
		if _get_bool(descriptor, "requires_capability") and warn_unexecuted and not executed_fields.has(field_name):
			_add_issue(
				result,
				"warning",
				"profile_field_not_executed",
				_reason(contract, "field_not_executed"),
				scope_id,
				"当前 Godot executor 接受但不执行该 schema-v1 字段。",
				{ "field": field_name, "scope": scope_kind }
			)
			continue
		compiled[field_name] = field_result.get("value")
	return compiled


func _compile_field_value(
	value: Variant,
	descriptor: Dictionary,
	contract: Dictionary,
	result: Dictionary,
	scope_kind: String,
	scope_id: String,
	field_name: String
) -> Dictionary:
	var field_type: String = _get_string(descriptor, "type")
	if field_type == "string" or field_type == "non_empty_string" or field_type == "regex":
		if not (value is String or value is StringName):
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
			return { "success": false }
		var string_value: String = _string_value(value)
		if field_type != "string" and string_value.strip_edges().is_empty():
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_value_invalid")
			return { "success": false }
		if field_type == "regex":
			var portable_error: String = _portable_regex_error(string_value, contract, result)
			if _profile_compile_terminal:
				return { "success": false }
			if not portable_error.is_empty() and portable_error != "syntax":
				_add_regex_unsafe_issue(contract, result, scope_id, field_name, portable_error)
				return { "success": false }
		if field_type == "regex" and _compile_regex(string_value) == null:
			_add_regex_issue(contract, result, scope_id, field_name)
			return { "success": false }
		return { "success": true, "value": string_value }
	if field_type == "bool":
		if not value is bool:
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
			return { "success": false }
		return { "success": true, "value": value }
	if field_type == "exact_integer" or field_type == "positive_integer":
		if not _is_exact_integer(value):
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
			return { "success": false }
		var integer_value: int = _exact_integer_value(value)
		if field_type == "positive_integer" and integer_value <= 0:
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_value_invalid")
			return { "success": false }
		return { "success": true, "value": integer_value }
	if field_type == "enum":
		if not (value is String or value is StringName):
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
			return { "success": false }
		var enum_value: String = _string_value(value)
		if not _domain_has_value(contract, _get_string(descriptor, "domain"), enum_value):
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_value_invalid")
			return { "success": false }
		return { "success": true, "value": enum_value }
	if field_type == "object":
		if not value is Dictionary:
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
			return { "success": false }
		var dictionary_value: Dictionary = value
		return { "success": true, "value": dictionary_value.duplicate(true) }
	if field_type == "object_array":
		if not value is Array:
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
			return { "success": false }
		var array_value: Array = value
		return { "success": true, "value": array_value.duplicate(true) }
	if field_type.ends_with("_list"):
		return _compile_string_list(value, descriptor, contract, result, scope_kind, scope_id, field_name, field_type)
	_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
	return { "success": false }


func _compile_string_list(
	value: Variant,
	descriptor: Dictionary,
	contract: Dictionary,
	result: Dictionary,
	scope_kind: String,
	scope_id: String,
	field_name: String,
	field_type: String
) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_type_invalid")
		return { "success": false }
	var values: Array = []
	if value is Array:
		values = value
	else:
		var packed_values: PackedStringArray = value
		for packed_value: String in packed_values:
			values.append(packed_value)
	if values.is_empty() and not _get_bool(descriptor, "allow_empty"):
		_add_field_issue(contract, result, scope_kind, scope_id, field_name, value, "field_value_invalid")
		return { "success": false }
	var normalized: Array[String] = []
	var normalized_set: Dictionary = {}
	var valid: bool = true
	for item: Variant in values:
		if not _consume_profile_work(result):
			return { "success": false }
		if not (item is String or item is StringName):
			valid = false
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, item, "field_type_invalid")
			continue
		var string_value: String = _string_value(item)
		if string_value.strip_edges().is_empty():
			valid = false
			_add_field_issue(contract, result, scope_kind, scope_id, field_name, item, "field_value_invalid")
			continue
		var canonical_value: String = _canonicalize_string_list_value(string_value, field_type)
		if field_type == "relative_path_list" and _profile_relative_path_is_invalid(canonical_value):
			valid = false
			_add_relative_path_issue(contract, result, scope_id, field_name, canonical_value)
			continue
		if field_type == "glob_list" and _profile_pattern_is_invalid(canonical_value):
			valid = false
			_add_relative_path_issue(contract, result, scope_id, field_name, canonical_value)
			continue
		if normalized_set.has(canonical_value):
			_add_issue(
				result,
				"warning",
				"duplicate_profile_value",
				_reason(contract, "collection_value_duplicate"),
				scope_id,
				"项目结构 profile 集合包含重复值；compiler 保留首次出现项。",
				{ "field": field_name, "value": canonical_value }
			)
			continue
		normalized_set[canonical_value] = true
		normalized.append(canonical_value)
	return { "success": valid, "value": normalized }


func _canonicalize_string_list_value(value: String, field_type: String) -> String:
	if field_type != "extension_list":
		return value
	var canonical_value: String = value.strip_edges().to_lower()
	if not canonical_value.begins_with("."):
		canonical_value = ".%s" % canonical_value
	return canonical_value


func _rule_field_definitions(contract: Dictionary, rule_kind: String) -> Dictionary:
	var result: Dictionary = {}
	for map_name: String in ["rule_common_fields", "rule_compatibility_fields"]:
		var field_map: Dictionary = _get_dictionary(contract, map_name)
		for field_value: Variant in field_map.keys():
			result[field_value] = field_map[field_value]
	var rule_kinds: Dictionary = _get_dictionary(contract, "rule_kinds")
	if rule_kinds.has(rule_kind):
		var rule_descriptor_value: Variant = rule_kinds[rule_kind]
		if rule_descriptor_value is Dictionary:
			var rule_descriptor: Dictionary = rule_descriptor_value
			var fields: Dictionary = _get_dictionary(rule_descriptor, "fields")
			for field_value: Variant in fields.keys():
				result[field_value] = fields[field_value]
	return result


func _raw_value_matches_descriptor(value: Variant, descriptor: Dictionary, contract: Dictionary) -> bool:
	var field_type: String = _get_string(descriptor, "type")
	if field_type == "string":
		return value is String or value is StringName
	if field_type == "non_empty_string" or field_type == "regex":
		if not (value is String or value is StringName):
			return false
		var string_value: String = _string_value(value)
		return (
			not string_value.strip_edges().is_empty()
			and (
				field_type != "regex"
				or (
					_portable_regex_error(string_value, contract).is_empty()
					and _compile_regex(string_value) != null
				)
			)
		)
	if field_type == "bool":
		return value is bool
	if field_type == "exact_integer":
		return _is_exact_integer(value)
	if field_type == "positive_integer":
		return _is_exact_integer(value) and _exact_integer_value(value) > 0
	if field_type == "enum":
		return _domain_has_value(contract, _get_string(descriptor, "domain"), _string_value(value))
	if field_type == "object":
		return value is Dictionary
	if field_type == "object_array":
		return value is Array
	if field_type.ends_with("_list"):
		var require_original_unique: bool = field_type != "extension_list"
		if not _string_collection_is_valid(value, _get_bool(descriptor, "allow_empty"), require_original_unique):
			return false
		var canonical_values: Dictionary = {}
		for item: String in _to_string_list(value):
			var canonical_item: String = _canonicalize_string_list_value(item, field_type)
			if canonical_values.has(canonical_item):
				return false
			canonical_values[canonical_item] = true
			if field_type == "relative_path_list" and _profile_relative_path_is_invalid(canonical_item):
				return false
			if field_type == "glob_list" and _profile_pattern_is_invalid(canonical_item):
				return false
		return true
	return false


func _contract_supports_profile_schema(contract: Dictionary, schema_version: int) -> bool:
	var versions_value: Variant = contract.get("profile_schema_versions")
	if not versions_value is Array:
		return false
	var versions: Array = versions_value
	for version_value: Variant in versions:
		if _is_exact_integer(version_value) and _exact_integer_value(version_value) == schema_version:
			return true
	return false


func _contract_has_domain(contract: Dictionary, domain_name: String) -> bool:
	var domains: Dictionary = _get_dictionary(contract, "domains")
	var domain_value: Variant = domains.get(domain_name)
	return domain_value is Array or domain_value is PackedStringArray


func _domain_has_value(contract: Dictionary, domain_name: String, value: String) -> bool:
	var domains: Dictionary = _get_dictionary(contract, "domains")
	var domain_value: Variant = domains.get(domain_name)
	if not (domain_value is Array or domain_value is PackedStringArray):
		return false
	return _to_string_list(domain_value).has(value)


func _dictionary_has_only_fields(data: Dictionary, allowed_fields: PackedStringArray) -> bool:
	for field_value: Variant in data.keys():
		var field_name: String = _string_value(field_value)
		if field_name.is_empty() or not allowed_fields.has(field_name):
			return false
	return true


func _dictionary_has_exact_fields(data: Dictionary, expected_fields: PackedStringArray) -> bool:
	if data.size() != expected_fields.size():
		return false
	return _dictionary_has_only_fields(data, expected_fields)


func _string_collection_is_valid(value: Variant, allow_empty: bool, require_unique: bool) -> bool:
	if not (value is Array or value is PackedStringArray):
		return false
	var values: PackedStringArray = _to_string_list(value)
	var value_count: int = 0
	if value is Array:
		var array_value: Array = value
		value_count = array_value.size()
	else:
		var packed_value: PackedStringArray = value
		value_count = packed_value.size()
	if values.size() != value_count or (values.is_empty() and not allow_empty):
		return false
	var seen: Dictionary = {}
	for item: String in values:
		if item.strip_edges().is_empty():
			return false
		if require_unique and seen.has(item):
			return false
		seen[item] = true
	return true


func _dictionary_string_keys(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key_value: Variant in data.keys():
		var key: String = _string_value(key_value)
		if not key.is_empty():
			var _append_key: bool = result.append(key)
	return result


func _to_string_list(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if item is String or item is StringName:
				var _append_item: bool = result.append(_string_value(item))
	return result


func _copy_contract_value(value: Variant) -> Variant:
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return value


func _reason(contract: Dictionary, reason_key: String) -> String:
	var reason_codes: Dictionary = _get_dictionary(contract, "reason_codes")
	return _get_string(reason_codes, reason_key, _BOOTSTRAP_REASON_CONTRACT_INVALID)


func _unsupported_field_legacy_kind(scope_kind: String) -> String:
	if scope_kind == "zone":
		return "unsupported_zone_field"
	if scope_kind == "rule":
		return "unsupported_rule_field"
	return "unsupported_profile_field"


func _legacy_field_kind(scope_kind: String, field_name: String, reason_key: String) -> String:
	if field_name == "schema_version" or field_name == "max_files":
		return "invalid_integer_field"
	if scope_kind == "profile" and field_name == "id":
		return "missing_profile_id" if reason_key == "required_field_missing" else "invalid_string_field"
	if scope_kind == "profile" and field_name in ["zones", "rules", "metadata"]:
		return "invalid_profile_field_type"
	if field_name == "severity":
		return "invalid_severity"
	if field_name == "target":
		return "invalid_naming_target"
	if field_name in ["required", "allow_root_files", "any"]:
		return "invalid_bool_field"
	var list_fields: PackedStringArray = [
		"roots", "allow_extensions", "deny_extensions", "exclude", "paths", "extensions",
		"include", "allowed_files", "required_subdirs", "allowed_subdirs",
	]
	if list_fields.has(field_name):
		return "invalid_string_list_field"
	return "invalid_string_field"


func _add_field_issue(
	contract: Dictionary,
	result: Dictionary,
	scope_kind: String,
	scope_id: String,
	field_name: String,
	actual_value: Variant,
	reason_key: String
) -> void:
	_add_issue(
		result,
		"error",
		_legacy_field_kind(scope_kind, field_name, reason_key),
		_reason(contract, reason_key),
		scope_id,
		"项目结构 profile 字段缺失、类型错误或值无效。",
		{ "field": field_name, "actual": _describe_value(actual_value) }
	)


func _add_relative_path_issue(
	contract: Dictionary,
	result: Dictionary,
	scope_id: String,
	field_name: String,
	path_value: String
) -> void:
	_add_issue(
		result,
		"error",
		"invalid_relative_path",
		_reason(contract, "relative_path_invalid"),
		path_value,
		"项目结构 profile 包含非法或非规范相对路径。",
		{ "field": field_name, "scope": scope_id }
	)


func _add_regex_issue(contract: Dictionary, result: Dictionary, scope_id: String, field_name: String) -> void:
	var legacy_kind: String = "invalid_feature_id_pattern" if field_name == "feature_id_pattern" else "invalid_naming_pattern"
	_add_issue(
		result,
		"error",
		legacy_kind,
		_reason(contract, "regex_invalid"),
		scope_id,
		"项目结构 profile 正则无法编译。",
		{ "field": field_name }
	)


func _add_regex_unsafe_issue(
	contract: Dictionary,
	result: Dictionary,
	scope_id: String,
	field_name: String,
	portable_reason: String
) -> void:
	var legacy_kind: String = (
		"invalid_feature_id_pattern"
		if field_name == "feature_id_pattern"
		else "invalid_naming_pattern"
	)
	_add_issue(
		result,
		"error",
		legacy_kind,
		_reason(contract, "regex_unsafe"),
		scope_id,
		"项目结构 profile 正则不属于 portable-safe-v1 安全子集。",
		{ "field": field_name, "portable_reason": portable_reason }
	)


func _add_duplicate_id_issue(contract: Dictionary, result: Dictionary, item_kind: String, item_id: String) -> void:
	_add_issue(
		result,
		"error",
		"duplicate_profile_id",
		_reason(contract, "duplicate_id"),
		item_id,
		"项目结构 profile 包含重复 ID。",
		{ "item_kind": item_kind }
	)


func _add_registry_issue(contract: Dictionary, result: Dictionary, message: String) -> void:
	_add_issue(
		result,
		"error",
		"profile_registry_invalid",
		_reason(contract, "registry_invalid"),
		"",
		message
	)


func _add_issue(
	result: Dictionary,
	severity: String,
	kind: String,
	reason_code: String,
	path: String,
	message: String,
	context: Dictionary = {}
) -> void:
	if _profile_compile_terminal:
		return
	var issues: Array = _get_array(result, "issues")
	if issues.size() >= _MAX_PROFILE_DIAGNOSTICS - 1:
		_fail_profile_compile_limit(result, "diagnostics")
		return
	issues.append({
		"severity": severity,
		"kind": kind,
		"reason_code": reason_code,
		"path": path,
		"message": message,
		"context": context.duplicate(true),
	})
	if severity == "error":
		result["error_count"] = _get_int(result, "error_count") + 1
	elif severity == "warning":
		result["warning_count"] = _get_int(result, "warning_count") + 1


func _finalize_result(result: Dictionary) -> Dictionary:
	result["success"] = not _profile_compile_terminal and _get_int(result, "error_count") == 0
	return result


func _describe_value(value: Variant) -> Dictionary:
	var value_type: int = typeof(value)
	var result: Dictionary = {
		"type": value_type,
		"type_name": type_string(value_type),
	}
	if value == null or value is bool or value is int or value is String:
		result["value"] = value
	elif value is StringName:
		result["value"] = _string_value(value)
	elif value is float:
		var float_value: float = value
		if is_finite(float_value):
			result["value"] = float_value
		elif is_nan(float_value):
			result["value"] = "NaN"
		else:
			result["value"] = "+Inf" if float_value > 0.0 else "-Inf"
	elif value is Array:
		var array_value: Array = value
		result["count"] = array_value.size()
	elif value is Dictionary:
		var dictionary_value: Dictionary = value
		result["count"] = dictionary_value.size()
	elif value is PackedStringArray:
		var packed_value: PackedStringArray = value
		result["count"] = packed_value.size()
	return result


func _portable_regex_error(
	pattern: String,
	contract: Dictionary,
	result: Dictionary = {}
) -> String:
	var semantics: Dictionary = _get_dictionary(contract, "semantics")
	var max_bytes: int = _get_int(
		semantics,
		"regex_max_utf8_bytes",
		_REGEX_MAX_UTF8_BYTES
	)
	var max_alternatives: int = _get_int(
		semantics,
		"regex_max_alternatives",
		_REGEX_MAX_ALTERNATIVES
	)
	var max_quantifiers: int = _get_int(
		semantics,
		"regex_max_quantifiers_per_branch",
		_REGEX_MAX_QUANTIFIERS_PER_BRANCH
	)
	var allowed_escapes: String = _get_string(
		semantics,
		"regex_allowed_escaped_literals",
		_REGEX_ALLOWED_ESCAPED_LITERALS
	)
	if pattern.to_utf8_buffer().size() > max_bytes:
		return "pattern_bytes"
	for character_index: int in pattern.length():
		var codepoint: int = pattern.unicode_at(character_index)
		if codepoint < 0x20 or codepoint > 0x7e:
			return "ascii_only"
	if pattern.is_empty():
		return "empty_branch"

	var branch_count: int = 1
	var branch_has_syntax: bool = false
	var branch_at_start: bool = true
	var branch_is_start_anchored: bool = false
	var can_quantify: bool = false
	var quantifier_count: int = 0
	var index: int = 0
	while index < pattern.length():
		if not result.is_empty() and not _consume_profile_work(result):
			return "resource_limit"
		var codepoint: int = pattern.unicode_at(index)
		if codepoint < 0x20 or codepoint > 0x7e:
			return "ascii_only"
		var character: String = pattern.substr(index, 1)
		if character == "\\":
			if (
				index + 1 >= pattern.length()
				or not allowed_escapes.contains(pattern.substr(index + 1, 1))
			):
				return "escape"
			branch_has_syntax = true
			branch_at_start = false
			can_quantify = true
			index += 2
			continue
		if character == "(" or character == ")":
			return "group"
		if character == "[":
			var class_result: Dictionary = _portable_regex_class_result(
				pattern,
				index,
				allowed_escapes,
				result
			)
			if _profile_compile_terminal:
				return "resource_limit"
			var class_error: String = _get_string(class_result, "error")
			if not class_error.is_empty():
				return class_error
			branch_has_syntax = true
			branch_at_start = false
			can_quantify = true
			index = _get_int(class_result, "end", index + 1)
			continue
		if character == "]":
			return "character_class"
		if character == "|":
			if not branch_has_syntax:
				return "empty_branch"
			branch_count += 1
			if branch_count > max_alternatives:
				return "alternatives"
			branch_has_syntax = false
			branch_at_start = true
			branch_is_start_anchored = false
			can_quantify = false
			quantifier_count = 0
			index += 1
			continue
		if character == "*" or character == "+" or character == "?":
			if not can_quantify:
				return "quantifier"
			if not branch_is_start_anchored:
				return "unanchored_quantifier"
			quantifier_count += 1
			if quantifier_count > max_quantifiers:
				return "quantifiers"
			can_quantify = false
			branch_at_start = false
			index += 1
			continue
		if character == "{" or character == "}":
			return "quantifier"
		if character == "^":
			if not branch_at_start:
				return "anchor"
			branch_is_start_anchored = true
			branch_has_syntax = true
			branch_at_start = false
			can_quantify = false
			index += 1
			continue
		if character == "$":
			if index + 1 < pattern.length() and pattern.substr(index + 1, 1) != "|":
				return "anchor"
			branch_has_syntax = true
			branch_at_start = false
			can_quantify = false
			index += 1
			continue
		branch_has_syntax = true
		branch_at_start = false
		can_quantify = true
		index += 1
	if not branch_has_syntax:
		return "empty_branch"
	return ""


func _portable_regex_class_result(
	pattern: String,
	start_index: int,
	allowed_escapes: String,
	result: Dictionary
) -> Dictionary:
	var tokens: Array[String] = []
	var index: int = start_index + 1
	if index < pattern.length() and pattern.substr(index, 1) == "^":
		index += 1
	while index < pattern.length():
		if not result.is_empty() and not _consume_profile_work(result):
			return { "end": index, "error": "resource_limit" }
		var character: String = pattern.substr(index, 1)
		if character == "]":
			if tokens.is_empty():
				return { "end": index + 1, "error": "character_class" }
			var joined_tokens: String = "".join(tokens)
			for set_operator: String in ["&&", "--", "~~", "||"]:
				if joined_tokens.contains(set_operator):
					return { "end": index + 1, "error": "character_class" }
			for token_index: int in tokens.size():
				if (
					tokens[token_index] != "-"
					or token_index == 0
					or token_index == tokens.size() - 1
				):
					continue
				var left_codepoint: int = tokens[token_index - 1].unicode_at(0)
				var right_codepoint: int = tokens[token_index + 1].unicode_at(0)
				if (
					_portable_regex_range_category(left_codepoint) == 0
					or (
						_portable_regex_range_category(left_codepoint)
						!= _portable_regex_range_category(right_codepoint)
					)
					or left_codepoint > right_codepoint
				):
					return { "end": index + 1, "error": "character_class" }
			return { "end": index + 1, "error": "" }
		if character == "[":
			return { "end": index + 1, "error": "character_class" }
		if character == "\\":
			if (
				index + 1 >= pattern.length()
				or not allowed_escapes.contains(pattern.substr(index + 1, 1))
			):
				return { "end": index + 1, "error": "escape" }
			var escaped_character: String = pattern.substr(index + 1, 1)
			tokens.append(escaped_character)
			index += 2
			continue
		tokens.append(character)
		index += 1
	return { "end": index, "error": "syntax" }


func _portable_regex_range_category(codepoint: int) -> int:
	if codepoint >= 0x30 and codepoint <= 0x39:
		return 1
	if codepoint >= 0x61 and codepoint <= 0x7a:
		return 2
	if codepoint >= 0x41 and codepoint <= 0x5a:
		return 3
	return 0


func _compile_regex(pattern: String) -> RegEx:
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile(pattern, false)
	if compile_result != OK:
		return null
	return expression


static func _profile_relative_path_is_invalid(path: String) -> bool:
	if path.is_empty() or path != path.strip_edges() or path.contains("\\") or path.ends_with("/"):
		return true
	if path.begins_with("/") or path.contains("://") or path.contains(":"):
		return true
	if path.is_absolute_path() or _is_filesystem_absolute_path(path):
		return true
	if path.contains("*") or path.contains("?") or path.contains("[") or path.contains("]"):
		return true
	return _path_has_invalid_segment(path)


static func _profile_pattern_is_invalid(pattern: String) -> bool:
	if pattern.is_empty() or pattern != pattern.strip_edges() or pattern.contains("\\") or pattern.ends_with("/"):
		return true
	if pattern.begins_with("/") or pattern.contains("://") or pattern.contains(":"):
		return true
	if pattern.contains("?") or pattern.contains("[") or pattern.contains("]") or pattern.contains("***"):
		return true
	return _path_has_invalid_segment(pattern)


static func _path_has_invalid_segment(path: String) -> bool:
	var parts: PackedStringArray = path.split("/", true)
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..":
			return true
	return false


func _path_has_parent_segment(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/")
	var body: String = normalized_path
	if normalized_path.contains("://"):
		body = normalized_path.get_slice("://", 1)
	var parts: PackedStringArray = body.split("/", false)
	for part: String in parts:
		if part == "..":
			return true
	return false


static func _is_filesystem_absolute_path(path: String) -> bool:
	if path.length() >= 3 and path.substr(1, 2) == ":/":
		return true
	return path.begins_with("//")


func _string_value(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


func _is_non_empty_string_value(value: Variant) -> bool:
	return not _string_value(value).strip_edges().is_empty()


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is String or value is StringName:
		return _string_value(value)
	return default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	if not source.has(key) or not source[key] is bool:
		return default_value
	var value: bool = source[key]
	return value


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	if not source.has(key):
		return default_value
	return _exact_integer_value(source[key], default_value)


func _is_exact_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


func _exact_integer_value(value: Variant, default_value: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		var float_value: float = value
		if _is_exact_integer(float_value):
			return int(float_value)
	return default_value


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {}
	var value: Variant = source[key]
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _get_array(source: Dictionary, key: String) -> Array:
	if not source.has(key):
		return []
	var value: Variant = source[key]
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


func _get_packed_string_array(source: Dictionary, key: String) -> PackedStringArray:
	if not source.has(key):
		return PackedStringArray()
	return _to_string_list(source[key])
