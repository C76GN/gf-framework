@tool

# GF 项目生成物与本地状态的规范路径策略。
extends RefCounted


# --- 常量 ---

## 路径策略 JSON schema 版本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const POLICY_SCHEMA_VERSION: int = 1

## 路径策略 JSON 镜像的资源路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const POLICY_FILE_PATH: String = "res://addons/gf/kernel/core/project_artifact_policy.json"

## 项目可导出生成物的规范根目录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const GENERATED_ROOT: String = "res://generated"

## GF 统一访问入口的规范生成路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const ACCESS_OUTPUT_PATH: String = "res://generated/gf_access.gd"

## GF 项目访问入口的规范生成路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const PROJECT_ACCESS_OUTPUT_PATH: String = "res://generated/gf_project_access.gd"

## GF 配置访问入口的规范生成路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const CONFIG_ACCESS_OUTPUT_PATH: String = "res://generated/gf_config_access.gd"

## 网络代码生成物的规范根目录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const NETWORK_OUTPUT_ROOT: String = "res://generated/network"

## 不进入游戏导出的项目本地状态根目录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const PROJECT_STATE_ROOT: String = ".gf"

## GF 项目契约的规范路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const PROJECT_CONTRACT_PATH: String = ".gf/project_contract.json"

## AI Developer Kit 本地输出根目录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const AI_OUTPUT_ROOT: String = ".gf/ai"

## AI 项目快照的规范路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const AI_SNAPSHOT_PATH: String = ".gf/ai/project_snapshot.json"

## AI 反馈草稿的规范根目录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @since 9.0.0
const AI_FEEDBACK_ROOT: String = ".gf/ai/feedback"


# --- 框架内部方法 ---

## 返回可供独立工具镜像的路径策略。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 路径策略副本。
## [br]
## @schema return: Dictionary，包含 schema_version 和稳定 paths 映射。
static func to_dict() -> Dictionary:
	return {
		"schema_version": POLICY_SCHEMA_VERSION,
		"paths": {
			"generated_root": GENERATED_ROOT,
			"access_output_path": ACCESS_OUTPUT_PATH,
			"project_access_output_path": PROJECT_ACCESS_OUTPUT_PATH,
			"config_access_output_path": CONFIG_ACCESS_OUTPUT_PATH,
			"network_output_root": NETWORK_OUTPUT_ROOT,
			"project_state_root": PROJECT_STATE_ROOT,
			"project_contract_path": PROJECT_CONTRACT_PATH,
			"ai_output_root": AI_OUTPUT_ROOT,
			"ai_snapshot_path": AI_SNAPSHOT_PATH,
			"ai_feedback_root": AI_FEEDBACK_ROOT,
		},
	}


## 校验供独立工具读取的 JSON 镜像是否与内核策略完全一致。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param policy_path: 要校验的策略 JSON 路径。
## [br]
## @return 问题列表；为空表示一致。
static func validate_policy_file(policy_path: String = POLICY_FILE_PATH) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	if not FileAccess.file_exists(policy_path):
		var _missing_appended: bool = issues.append("项目产物路径策略镜像不存在：%s" % policy_path)
		return issues
	var file: FileAccess = FileAccess.open(policy_path, FileAccess.READ)
	if file == null:
		var _unreadable_appended: bool = issues.append("无法读取项目产物路径策略镜像：%s" % policy_path)
		return issues
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		var _parse_appended: bool = issues.append("项目产物路径策略镜像不是合法 JSON Dictionary：%s" % policy_path)
		return issues
	var actual: Dictionary = parser.data
	if actual.size() != 2 or not actual.has("schema_version") or not actual.has("paths"):
		var _root_appended: bool = issues.append("项目产物路径策略镜像根字段不完整或包含未知字段：%s" % policy_path)
		return issues
	var schema_version: Variant = actual.get("schema_version")
	if not schema_version is int and not schema_version is float:
		var _type_appended: bool = issues.append("项目产物路径策略镜像 schema_version 不是数字：%s" % policy_path)
		return issues
	if not _is_supported_schema_version(schema_version):
		var _version_appended: bool = issues.append("项目产物路径策略镜像 schema_version 不受支持：%s" % policy_path)
	if not actual.get("paths") is Dictionary:
		var _paths_type_appended: bool = issues.append("项目产物路径策略镜像 paths 不是 Dictionary：%s" % policy_path)
		return issues
	var actual_paths: Dictionary = actual.get("paths")
	var expected_paths: Dictionary = to_dict()["paths"]
	if actual_paths.size() != expected_paths.size():
		var _size_appended: bool = issues.append("项目产物路径策略镜像 paths 字段数量不一致：%s" % policy_path)
	for key_value: Variant in expected_paths.keys():
		var key: String = str(key_value)
		if not actual_paths.has(key) or actual_paths.get(key) != expected_paths.get(key):
			var _mismatch_appended: bool = issues.append("项目产物路径策略镜像字段不一致：%s (%s)" % [key, policy_path])
	for key_value: Variant in actual_paths.keys():
		var key: String = str(key_value)
		if not expected_paths.has(key):
			var _unknown_appended: bool = issues.append("项目产物路径策略镜像包含未知字段：%s (%s)" % [key, policy_path])
	return issues


# --- 私有/辅助方法 ---

static func _is_supported_schema_version(value: Variant) -> bool:
	if value is int:
		var integer_value: int = value
		return integer_value == POLICY_SCHEMA_VERSION
	if value is float:
		var float_value: float = value
		return is_equal_approx(float_value, float(POLICY_SCHEMA_VERSION))
	return false
