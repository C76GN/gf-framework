## GFSessionTraceCheckpoint: Session Trace 配方中的显式 Provider 采集点。
##
## 检查点只引用已经在运行时注册的 Provider ID，单个列表最多包含 256 项。
## 默认所有 Provider 都是必需项；`optional_provider_ids` 可把部分失败降级为
## 可观察但不阻断检查点的结果。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 10.0.0
class_name GFSessionTraceCheckpoint
extends Resource


# --- 常量 ---

const _MAX_CHECKPOINT_PROVIDERS: int = 256


# --- 导出变量 ---

## 稳定检查点 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var checkpoint_id: StringName = &""

## 按顺序显式采集的 Provider ID。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var provider_ids: PackedStringArray = PackedStringArray()

## 允许失败而不让检查点整体失败的 Provider ID，必须是 `provider_ids` 子集。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var optional_provider_ids: PackedStringArray = PackedStringArray()

## 合并进每次 Provider 事件的检查点元数据。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema metadata: Dictionary with project-defined checkpoint metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置检查点并返回自身。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param p_checkpoint_id: 稳定检查点 ID。
## [br]
## @param p_provider_ids: 按顺序采集的 Provider ID。
## [br]
## @param options: 检查点选项。
## [br]
## @schema options: Dictionary with optional_provider_ids and metadata.
## [br]
## @return 当前检查点。
func configure(
	p_checkpoint_id: StringName,
	p_provider_ids: PackedStringArray,
	options: Dictionary = {}
) -> GFSessionTraceCheckpoint:
	checkpoint_id = p_checkpoint_id
	provider_ids = p_provider_ids.duplicate()
	optional_provider_ids = GFVariantData.get_option_packed_string_array(
		options,
		"optional_provider_ids"
	)
	metadata = _duplicate_dictionary(
		GFVariantData.as_dictionary(GFVariantData.get_option_value(options, "metadata", {}))
	)
	return self


## 校验检查点定义。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, counts, summary, and next_actions.
func validate_checkpoint() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	var checkpoint_text: String = String(checkpoint_id)
	if checkpoint_id == &"" or checkpoint_text != checkpoint_text.strip_edges() or checkpoint_text.length() > 128:
		var _id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_checkpoint_id",
			"Trace checkpoint id must be non-empty, trimmed, and at most 128 characters.",
			{ "path": "checkpoint_id" }
		)
	if provider_ids.is_empty():
		var _empty_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"empty_checkpoint_providers",
			"Trace checkpoint must reference at least one provider.",
			{ "path": "provider_ids" }
		)
	if provider_ids.size() > _MAX_CHECKPOINT_PROVIDERS:
		var _provider_limit_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"checkpoint_provider_limit_exceeded",
			"Trace checkpoint may reference at most 256 providers.",
			{ "path": "provider_ids", "count": provider_ids.size() }
		)
	if optional_provider_ids.size() > _MAX_CHECKPOINT_PROVIDERS:
		var _optional_limit_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"checkpoint_optional_provider_limit_exceeded",
			"Trace checkpoint may reference at most 256 optional providers.",
			{ "path": "optional_provider_ids", "count": optional_provider_ids.size() }
		)
	var seen: Dictionary = {}
	for index: int in range(mini(provider_ids.size(), _MAX_CHECKPOINT_PROVIDERS)):
		var provider_text: String = provider_ids[index]
		var provider_id: StringName = StringName(provider_text)
		if provider_text.is_empty() or provider_text != provider_text.strip_edges() or provider_text.length() > 128:
			var _provider_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_checkpoint_provider_id",
				"Trace checkpoint provider ids must be non-empty, trimmed, and at most 128 characters.",
				{ "path": "provider_ids", "provider_id": provider_text }
			)
		elif seen.has(provider_id):
			var _duplicate_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"duplicate_checkpoint_provider",
				"Trace checkpoint provider ids must be unique.",
				{ "path": "provider_ids", "provider_id": provider_text }
			)
		else:
			seen[provider_id] = true
	var optional_seen: Dictionary = {}
	for index: int in range(mini(optional_provider_ids.size(), _MAX_CHECKPOINT_PROVIDERS)):
		var optional_text: String = optional_provider_ids[index]
		var optional_provider_id: StringName = StringName(optional_text)
		if optional_seen.has(optional_provider_id):
			var _duplicate_optional_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"duplicate_optional_provider",
				"Optional provider ids must be unique.",
				{ "path": "optional_provider_ids", "provider_id": optional_text }
			)
		else:
			optional_seen[optional_provider_id] = true
		if not seen.has(optional_provider_id):
			var _optional_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"unknown_optional_provider",
				"Optional provider ids must be a subset of provider_ids.",
				{ "path": "optional_provider_ids", "provider_id": optional_text }
			)
	return GFValidationReportDictionary.finalize_report(report, "Session trace checkpoint", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_checkpoint_id": "Assign a stable checkpoint id with at most 128 characters.",
			"empty_checkpoint_providers": "Add at least one explicitly registered snapshot provider id.",
			"invalid_checkpoint_provider_id": "Use stable provider ids with at most 128 characters.",
			"checkpoint_provider_limit_exceeded": "Keep provider_ids at or below 256 entries.",
			"checkpoint_optional_provider_limit_exceeded": "Keep optional_provider_ids at or below 256 entries.",
			"duplicate_checkpoint_provider": "Remove duplicate provider ids.",
			"duplicate_optional_provider": "Remove duplicate optional provider ids.",
			"unknown_optional_provider": "Keep optional_provider_ids inside provider_ids.",
		},
		"fallback_action": "Review the first trace checkpoint issue.",
		"no_action": "Session trace checkpoint is valid.",
	})


# --- 框架内部方法 ---

## 查询 Provider 是否为可选项。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param provider_id: Provider ID。
## [br]
## @return 可选时返回 true。
func is_provider_optional_for_framework(provider_id: StringName) -> bool:
	return optional_provider_ids.has(String(provider_id))


## 转换为配方指纹记录。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return JSON-safe 检查点定义。
## [br]
## @schema return: Dictionary with checkpoint_id, provider_ids, optional_provider_ids, and metadata.
func to_report_dictionary_for_framework() -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(
		{
			"checkpoint_id": String(checkpoint_id),
			"provider_ids": provider_ids,
			"optional_provider_ids": optional_provider_ids,
			"metadata": metadata,
		},
		GFReportValueCodec.make_redaction_options(
			GFReportValueCodec.REDACTION_PROFILE_PRIVACY
		)
	)


# --- 私有/辅助方法 ---

static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))
