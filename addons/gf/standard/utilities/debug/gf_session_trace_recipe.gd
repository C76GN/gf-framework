## GFSessionTraceRecipe: 可复用、可校验的 Session Trace 采集配方。
##
## 配方声明全局内存预算、允许的事件通道、显式检查点和快照读取默认值。
## 通道与检查点定义各自最多包含 256 项，数值预算会在运行时重新校验。
## 它不持有 Provider Callable、journal sink、上传地址、玩家许可或业务状态。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFSessionTraceRecipe
extends Resource


# --- 常量 ---

const _MAX_EVENTS: int = 1_000_000
const _MIN_EVENT_BUFFER_BYTES: int = 512
const _MAX_EVENT_BUFFER_BYTES: int = 1_073_741_824
const _MIN_EVENT_BYTES: int = 512
const _MAX_EVENT_BYTES: int = 16_777_216
const _MAX_SNAPSHOT_LIMIT: int = 1_000_000
const _MAX_CHANNEL_DEFINITIONS: int = 256
const _MAX_CHECKPOINT_DEFINITIONS: int = 256


# --- 导出变量 ---

## 稳定配方 ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var recipe_id: StringName = &""

## 全局内存事件数量上限。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 1_000_000, 1) var max_events: int = 512

## 全局内存事件缓冲字节预算。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 1_073_741_824, 1) var max_event_buffer_bytes: int = 1024 * 1024

## 全局单事件字节预算。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(512, 16_777_216, 1) var max_event_bytes: int = 16 * 1024

## 事件和单次 metadata 使用的脱敏 profile。
## [br]
## @api public
## [br]
## @since unreleased
@export_enum("privacy", "public", "support", "debug") var redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY

## 配方声明的事件通道。
## [br]
## @api public
## [br]
## @since unreleased
@export var channels: Array[GFSessionTraceChannelDefinition] = []

## 配方声明的显式采集检查点。
## [br]
## @api public
## [br]
## @since unreleased
@export var checkpoints: Array[GFSessionTraceCheckpoint] = []

## 配方快照默认保留的最新事件数；0 表示不限制。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 1_000_000, 1) var snapshot_limit: int = 0

## 配方快照默认是否包含会话上下文。
## [br]
## @api public
## [br]
## @since unreleased
@export var include_context: bool = true

## 配方快照默认是否包含通道目录。
## [br]
## @api public
## [br]
## @since unreleased
@export var include_channel_catalog: bool = false

## 配方快照默认是否包含 Provider 目录。
## [br]
## @api public
## [br]
## @since unreleased
@export var include_provider_catalog: bool = false

## 配方目录元数据；不自动写入会话上下文或事件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema metadata: Dictionary with project-defined recipe catalog metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置配方并返回自身。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_recipe_id: 稳定配方 ID。
## [br]
## @param p_channels: 通道定义。
## [br]
## @param p_checkpoints: 检查点定义。
## [br]
## @param options: 容量、脱敏与快照默认选项。
## [br]
## @schema options: Dictionary with max_events, max_event_buffer_bytes, max_event_bytes, redaction_profile, snapshot_limit, include_context, include_channel_catalog, include_provider_catalog, and metadata.
## [br]
## @return 当前配方。
func configure(
	p_recipe_id: StringName,
	p_channels: Array[GFSessionTraceChannelDefinition],
	p_checkpoints: Array[GFSessionTraceCheckpoint] = [],
	options: Dictionary = {}
) -> GFSessionTraceRecipe:
	recipe_id = p_recipe_id
	channels = p_channels.duplicate()
	checkpoints = p_checkpoints.duplicate()
	max_events = GFVariantData.get_option_int(options, "max_events", max_events)
	max_event_buffer_bytes = GFVariantData.get_option_int(
		options,
		"max_event_buffer_bytes",
		max_event_buffer_bytes
	)
	max_event_bytes = GFVariantData.get_option_int(
		options,
		"max_event_bytes",
		max_event_bytes
	)
	redaction_profile = GFVariantData.get_option_string(
		options,
		"redaction_profile",
		redaction_profile
	)
	snapshot_limit = GFVariantData.get_option_int(options, "snapshot_limit", snapshot_limit)
	include_context = GFVariantData.get_option_bool(options, "include_context", include_context)
	include_channel_catalog = GFVariantData.get_option_bool(
		options,
		"include_channel_catalog",
		include_channel_catalog
	)
	include_provider_catalog = GFVariantData.get_option_bool(
		options,
		"include_provider_catalog",
		include_provider_catalog
	)
	metadata = _duplicate_dictionary(
		GFVariantData.as_dictionary(GFVariantData.get_option_value(options, "metadata", {}))
	)
	return self


## 校验配方结构和引用唯一性。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, counts, summary, and next_actions.
func validate_recipe() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	var recipe_text: String = String(recipe_id)
	if recipe_id == &"" or recipe_text != recipe_text.strip_edges() or recipe_text.length() > 128:
		_append_issue(report, &"invalid_recipe_id", "Trace recipe id must be non-empty, trimmed, and at most 128 characters.", { "path": "recipe_id" })
	if channels.is_empty():
		_append_issue(report, &"empty_recipe_channels", "Trace recipe must declare at least one channel.", { "path": "channels" })
	if channels.size() > _MAX_CHANNEL_DEFINITIONS:
		_append_issue(report, &"recipe_channel_limit_exceeded", "Trace recipe may declare at most 256 channels.", { "path": "channels", "count": channels.size() })
	if checkpoints.size() > _MAX_CHECKPOINT_DEFINITIONS:
		_append_issue(report, &"recipe_checkpoint_limit_exceeded", "Trace recipe may declare at most 256 checkpoints.", { "path": "checkpoints", "count": checkpoints.size() })
	if max_events < 0 or max_events > _MAX_EVENTS:
		_append_issue(report, &"invalid_event_limit", "Trace recipe max_events must be between 0 and 1000000.", { "path": "max_events", "value": max_events })
	if (
		max_event_buffer_bytes < 0
		or max_event_buffer_bytes > _MAX_EVENT_BUFFER_BYTES
		or (
			max_event_buffer_bytes > 0
			and max_event_buffer_bytes < _MIN_EVENT_BUFFER_BYTES
		)
	):
		_append_issue(report, &"invalid_event_buffer_budget", "Trace recipe max_event_buffer_bytes must be 0 or between 512 and 1073741824.", { "path": "max_event_buffer_bytes", "value": max_event_buffer_bytes })
	if max_event_bytes < _MIN_EVENT_BYTES or max_event_bytes > _MAX_EVENT_BYTES:
		_append_issue(report, &"invalid_event_byte_budget", "Trace recipe max_event_bytes must be between 512 and 16777216.", { "path": "max_event_bytes", "value": max_event_bytes })
	if snapshot_limit < 0 or snapshot_limit > _MAX_SNAPSHOT_LIMIT:
		_append_issue(report, &"invalid_snapshot_limit", "Trace recipe snapshot_limit must be between 0 and 1000000.", { "path": "snapshot_limit", "value": snapshot_limit })
	if not _is_valid_redaction_profile(redaction_profile):
		_append_issue(report, &"invalid_redaction_profile", "Trace recipe redaction_profile is not supported.", { "path": "redaction_profile" })

	var channel_ids: Dictionary = {}
	for index: int in range(mini(channels.size(), _MAX_CHANNEL_DEFINITIONS)):
		var channel: GFSessionTraceChannelDefinition = channels[index]
		if channel == null or not GFVariantData.get_option_bool(channel.validate_definition(), "ok", false):
			_append_issue(report, &"invalid_channel_definition", "Trace recipe contains an invalid channel definition.", { "path": "channels", "index": index })
			continue
		if channel_ids.has(channel.channel_id):
			_append_issue(report, &"duplicate_recipe_channel", "Trace recipe channel ids must be unique.", { "path": "channels", "channel_id": String(channel.channel_id) })
		else:
			channel_ids[channel.channel_id] = true

	var checkpoint_ids: Dictionary = {}
	for index: int in range(mini(checkpoints.size(), _MAX_CHECKPOINT_DEFINITIONS)):
		var checkpoint: GFSessionTraceCheckpoint = checkpoints[index]
		if checkpoint == null or not GFVariantData.get_option_bool(checkpoint.validate_checkpoint(), "ok", false):
			_append_issue(report, &"invalid_checkpoint_definition", "Trace recipe contains an invalid checkpoint definition.", { "path": "checkpoints", "index": index })
			continue
		if checkpoint_ids.has(checkpoint.checkpoint_id):
			_append_issue(report, &"duplicate_recipe_checkpoint", "Trace recipe checkpoint ids must be unique.", { "path": "checkpoints", "checkpoint_id": String(checkpoint.checkpoint_id) })
		else:
			checkpoint_ids[checkpoint.checkpoint_id] = true

	return GFValidationReportDictionary.finalize_report(report, "Session trace recipe", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_recipe_id": "Assign a stable recipe id with at most 128 characters.",
			"empty_recipe_channels": "Declare at least one bounded trace channel.",
			"recipe_channel_limit_exceeded": "Keep recipe channels at or below 256 entries.",
			"recipe_checkpoint_limit_exceeded": "Keep recipe checkpoints at or below 256 entries.",
			"invalid_event_limit": "Use max_events between 0 and 1000000.",
			"invalid_event_buffer_budget": "Use 0 or max_event_buffer_bytes between 512 and 1073741824.",
			"invalid_event_byte_budget": "Use max_event_bytes between 512 and 16777216.",
			"invalid_snapshot_limit": "Use snapshot_limit between 0 and 1000000.",
			"invalid_redaction_profile": "Use privacy, public, support, or debug.",
			"invalid_channel_definition": "Fix or remove the invalid channel definition.",
			"duplicate_recipe_channel": "Keep channel ids unique inside the recipe.",
			"invalid_checkpoint_definition": "Fix or remove the invalid checkpoint definition.",
			"duplicate_recipe_checkpoint": "Keep checkpoint ids unique inside the recipe.",
		},
		"fallback_action": "Review the first session trace recipe issue.",
		"no_action": "Session trace recipe is valid.",
	})


## 获取指定检查点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param checkpoint_id: 检查点 ID。
## [br]
## @return 检查点；不存在时返回 null。
func get_checkpoint(checkpoint_id: StringName) -> GFSessionTraceCheckpoint:
	for index: int in range(mini(checkpoints.size(), _MAX_CHECKPOINT_DEFINITIONS)):
		var checkpoint: GFSessionTraceCheckpoint = checkpoints[index]
		if checkpoint != null and checkpoint.checkpoint_id == checkpoint_id:
			return checkpoint
	return null


## 获取不含运行时回调的 JSON-safe 配方描述。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 配方描述。
## [br]
## @schema return: Dictionary with recipe identity, budgets, bounded channels and checkpoints, source counts, definitions_truncated, snapshot_options, and metadata.
func to_report_dictionary() -> Dictionary:
	var channel_records: Array[Dictionary] = []
	for index: int in range(mini(channels.size(), _MAX_CHANNEL_DEFINITIONS)):
		var channel: GFSessionTraceChannelDefinition = channels[index]
		if channel != null:
			channel_records.append(channel.to_report_dictionary_for_framework())
	var checkpoint_records: Array[Dictionary] = []
	for index: int in range(mini(checkpoints.size(), _MAX_CHECKPOINT_DEFINITIONS)):
		var checkpoint: GFSessionTraceCheckpoint = checkpoints[index]
		if checkpoint != null:
			checkpoint_records.append(checkpoint.to_report_dictionary_for_framework())
	return GFReportValueCodec.to_report_dictionary(
		{
			"recipe_id": String(recipe_id),
			"max_events": max_events,
			"max_event_buffer_bytes": max_event_buffer_bytes,
			"max_event_bytes": max_event_bytes,
			"redaction_profile": redaction_profile,
			"channels": channel_records,
			"checkpoints": checkpoint_records,
			"channel_definition_count": channels.size(),
			"checkpoint_definition_count": checkpoints.size(),
			"definitions_truncated": (
				channels.size() > _MAX_CHANNEL_DEFINITIONS
				or checkpoints.size() > _MAX_CHECKPOINT_DEFINITIONS
			),
			"snapshot_options": get_snapshot_options_for_framework(),
			"metadata": metadata,
		},
		GFReportValueCodec.make_redaction_options(
			GFReportValueCodec.REDACTION_PROFILE_PRIVACY
		)
	)


# --- 框架内部方法 ---

## 获取配方快照默认选项。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 可传给 `GFSessionTraceUtility.build_snapshot()` 的选项。
## [br]
## @schema return: Dictionary with limit, include_context, include_channel_catalog, and include_provider_catalog.
func get_snapshot_options_for_framework() -> Dictionary:
	return {
		"limit": snapshot_limit,
		"include_context": include_context,
		"include_channel_catalog": include_channel_catalog,
		"include_provider_catalog": include_provider_catalog,
	}


## 计算用于检测应用后变更的稳定配方指纹。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return SHA-256 十六进制文本。
func get_fingerprint_for_framework() -> String:
	var fingerprint_record: Dictionary = to_report_dictionary()
	var checkpoint_records: Array[Dictionary] = []
	for index: int in range(mini(checkpoints.size(), _MAX_CHECKPOINT_DEFINITIONS)):
		var checkpoint: GFSessionTraceCheckpoint = checkpoints[index]
		if checkpoint == null:
			continue
		checkpoint_records.append(
			GFReportValueCodec.to_report_dictionary(
				{
					"checkpoint_id": String(checkpoint.checkpoint_id),
					"provider_ids": checkpoint.provider_ids,
					"optional_provider_ids": checkpoint.optional_provider_ids,
					"metadata": checkpoint.metadata,
				},
				GFReportValueCodec.make_redaction_options(redaction_profile)
			)
		)
	fingerprint_record["checkpoints"] = checkpoint_records
	return JSON.stringify(fingerprint_record, "", true).sha256_text()


# --- 私有/辅助方法 ---

func _append_issue(
	report: Dictionary,
	code: StringName,
	message: String,
	issue_metadata: Dictionary
) -> void:
	var _issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		code,
		message,
		issue_metadata
	)


func _is_valid_redaction_profile(profile: String) -> bool:
	return (
		profile == GFReportValueCodec.REDACTION_PROFILE_PRIVACY
		or profile == GFReportValueCodec.REDACTION_PROFILE_PUBLIC
		or profile == GFReportValueCodec.REDACTION_PROFILE_SUPPORT
		or profile == GFReportValueCodec.REDACTION_PROFILE_DEBUG
	)


static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))
