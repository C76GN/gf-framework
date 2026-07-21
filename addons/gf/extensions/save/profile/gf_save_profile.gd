## GFSaveProfile: 多 section 存档的项目级声明。
##
## Profile 从 provider 列表派生唯一文档 schema，避免项目同时维护重复的 section
## 版本清单。运行时数据仍由 provider 持有，Profile 不解释业务字段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFSaveProfile
extends Resource


# --- 常量 ---

## 拒绝当前 Profile 未声明的 section。
## [br]
## @api public
## [br]
## @since unreleased
const UNKNOWN_SECTION_REJECT: StringName = &"reject"

## 读取时接受未知 section，并在后续保存中原样保留。
## [br]
## @api public
## [br]
## @since unreleased
const UNKNOWN_SECTION_PRESERVE: StringName = &"preserve"

## 读取时接受未知 section，并在后续保存中显式丢弃。
## [br]
## @api public
## [br]
## @since unreleased
const UNKNOWN_SECTION_DROP: StringName = &"drop"


# --- 导出变量 ---

## 稳定运行时 Profile ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var profile_id: StringName = &""

## 稳定文档 schema ID；为空时使用 `profile_id`。
##
## 将它与运行时 ID 分离后，同一文档定义可用于多个槽位或存储目标。
## [br]
## @api public
## [br]
## @since unreleased
@export var schema_id: StringName = &""

## `GFStorageUtility` 管理的相对文件名。
## [br]
## @api public
## [br]
## @since unreleased
@export var file_name: String = ""

## 当前文档 schema 版本。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(1, 2_147_483_647, 1) var schema_version: int = 1

## 拥有各 section 的 provider，顺序决定采集与应用顺序。
## [br]
## @api public
## [br]
## @since unreleased
@export var providers: Array[GFSaveSectionProvider] = []

## 缺失、损坏和临时 IO 失败的显式政策。
## [br]
## @api public
## [br]
## @since unreleased
@export var recovery_policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()

## Profile 是否接受保存和 flush 请求。
## [br]
## @api public
## [br]
## @since unreleased
@export var save_enabled: bool = true

## Profile 是否接受读取请求。
## [br]
## @api public
## [br]
## @since unreleased
@export var load_enabled: bool = true

## 未声明 section 的处理政策。
##
## 默认拒绝，避免一次读取后再保存时静默删除未知数据。
## [br]
## @api public
## [br]
## @since unreleased
@export var unknown_section_policy: StringName = UNKNOWN_SECTION_REJECT


# --- 公共方法 ---

## 校验 profile、恢复政策和全部 provider。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_profile() -> Dictionary:
	var report: Dictionary = {"issues": []}
	if profile_id == &"" or String(profile_id) != String(profile_id).strip_edges():
		_append_issue(report, &"invalid_profile_id", "Profile id must be non-empty and trimmed.", "profile_id")
	if schema_id != &"" and String(schema_id) != String(schema_id).strip_edges():
		_append_issue(report, &"invalid_schema_id", "Schema id must be empty or trimmed.", "schema_id")
	if file_name.is_empty() or file_name != file_name.strip_edges():
		_append_issue(report, &"invalid_file_name", "Profile file name must be non-empty and trimmed.", "file_name")
	if schema_version <= 0:
		_append_issue(report, &"invalid_schema_version", "Profile schema version must be positive.", "schema_version")
	if providers.is_empty():
		_append_issue(report, &"missing_providers", "Profile requires at least one section provider.", "providers")
	if not save_enabled and not load_enabled:
		_append_issue(report, &"profile_disabled", "Profile must support save, load, or both.", "save_enabled")
	if unknown_section_policy not in [
		UNKNOWN_SECTION_REJECT,
		UNKNOWN_SECTION_PRESERVE,
		UNKNOWN_SECTION_DROP,
	]:
		_append_issue(
			report,
			&"invalid_unknown_section_policy",
			"Unknown section policy is not supported.",
			"unknown_section_policy"
		)
	var seen_ids: Dictionary = {}
	for index: int in range(providers.size()):
		var provider: GFSaveSectionProvider = providers[index]
		if provider == null:
			_append_issue(report, &"missing_provider", "Profile provider is null.", "providers.%d" % index)
			continue
		_append_nested_issues(report, provider.validate_provider(), "providers.%d" % index)
		if save_enabled and provider.required_on_load and not provider.save_enabled:
			_append_issue(
				report,
				&"required_provider_not_saveable",
				"A writable Profile must save every section required by its own schema.",
				"providers.%d.save_enabled" % index,
				{"section_id": provider.section_id}
			)
		if provider.section_id != &"" and seen_ids.has(provider.section_id):
			_append_issue(
				report,
				&"duplicate_section_provider",
				"Profile section ids must be unique.",
				"providers.%d.section_id" % index,
				{"section_id": provider.section_id}
			)
		seen_ids[provider.section_id] = true
	if recovery_policy == null:
		_append_issue(report, &"missing_recovery_policy", "Profile recovery policy is required.", "recovery_policy")
	else:
		_append_nested_issues(report, recovery_policy.validate_policy(), "recovery_policy")
	return GFValidationReportDictionary.finalize_report(report, "Save profile", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_profile_id": "Assign one stable non-empty trimmed runtime profile id.",
			"invalid_schema_id": "Use an empty schema id or one stable trimmed schema id.",
			"invalid_file_name": "Assign one owned storage-relative file name.",
			"invalid_schema_version": "Use a positive current document version.",
			"missing_providers": "Register at least one section owner.",
			"missing_provider": "Remove null entries or provide a valid provider.",
			"duplicate_section_provider": "Keep exactly one owner for each section id.",
			"missing_recovery_policy": "Assign an explicit recovery policy.",
			"profile_disabled": "Enable save, load, or both for the Profile.",
			"invalid_unknown_section_policy": "Use reject, preserve, or drop.",
			"required_provider_not_saveable": "Enable save or make the load section optional.",
		},
		"fallback_action": "Review the first save profile issue.",
		"no_action": "Save profile is valid.",
	})


## 从当前 provider 清单派生文档 schema。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前文档 schema；profile 无效时仍返回可诊断对象。
func build_schema() -> GFSaveDocumentSchema:
	var section_versions: Dictionary = {}
	var required_sections: PackedStringArray = PackedStringArray()
	for provider: GFSaveSectionProvider in providers:
		if provider == null or provider.section_id == &"":
			continue
		section_versions[provider.section_id] = provider.schema_version
		if provider.load_enabled and provider.required_on_load:
			var _appended: bool = required_sections.append(String(provider.section_id))
	return GFSaveDocumentSchema.new().configure(
		get_effective_schema_id(),
		schema_version,
		section_versions,
		{
			"required_sections": required_sections,
			"allow_unknown_sections": unknown_section_policy != UNKNOWN_SECTION_REJECT,
		}
	)


## 获取写入文档使用的 schema ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `schema_id` 非空时返回它，否则返回 `profile_id`。
func get_effective_schema_id() -> StringName:
	return schema_id if schema_id != &"" else profile_id


## 获取指定 section 的唯一 provider。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param section_id: 目标 section ID。
## [br]
## @return 匹配 provider；不存在时返回 null。
func get_provider(section_id: StringName) -> GFSaveSectionProvider:
	for provider: GFSaveSectionProvider in providers:
		if provider != null and provider.section_id == section_id:
			return provider
	return null


## 获取 provider 引用的隔离数组。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 按声明顺序排列的 provider。
func get_providers() -> Array[GFSaveSectionProvider]:
	return providers.duplicate()


# --- 私有/辅助方法 ---

func _append_issue(
	report: Dictionary,
	kind: StringName,
	message: String,
	path: String,
	metadata: Dictionary = {}
) -> void:
	var payload: Dictionary = metadata.duplicate(true)
	payload["path"] = path
	var _issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message,
		payload
	)


func _append_nested_issues(report: Dictionary, nested_report: Dictionary, prefix: String) -> void:
	for issue_value: Variant in GFVariantData.get_option_array(nested_report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var nested_path: String = GFVariantData.get_option_string(issue, "path")
		var metadata: Dictionary = issue.duplicate(true)
		metadata["path"] = prefix if nested_path.is_empty() else "%s.%s" % [prefix, nested_path]
		var _issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			GFVariantData.get_option_string(issue, "severity", "error"),
			GFVariantData.get_option_string_name(issue, "kind", &"invalid_nested_value"),
			GFVariantData.get_option_string(issue, "message", "Nested validation failed."),
			metadata
		)
