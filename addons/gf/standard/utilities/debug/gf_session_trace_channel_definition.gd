## GFSessionTraceChannelDefinition: Session Trace 配方中的通道定义。
##
## 该资源只描述稳定通道 ID、可见性和容量，不持有运行时回调或业务状态。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFSessionTraceChannelDefinition
extends Resource


# --- 常量 ---

const _MAX_CHANNEL_EVENTS: int = 1_000_000
const _MIN_CHANNEL_EVENT_BYTES: int = 512
const _MAX_CHANNEL_EVENT_BYTES: int = 16_777_216


# --- 导出变量 ---

## 稳定通道 ID。
## [br]
## @api public
## [br]
## @since unreleased
@export var channel_id: StringName = &""

## 通道应用后是否启用。
## [br]
## @api public
## [br]
## @since unreleased
@export var enabled: bool = true

## 默认快照是否包含该通道事件。
## [br]
## @api public
## [br]
## @since unreleased
@export var include_in_snapshot: bool = true

## 通道最多保留的事件数；0 表示只使用全局限制。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 1_000_000, 1) var max_events: int = 0

## 通道单事件字节预算；0 表示只使用全局限制。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 16_777_216, 1) var max_event_bytes: int = 0

## 使用 privacy 安全下限持久保存的目录元数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema metadata: Dictionary with project-defined catalog metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置通道定义并返回自身。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_channel_id: 稳定通道 ID。
## [br]
## @param options: 通道配置。
## [br]
## @schema options: Dictionary with enabled, include_in_snapshot, max_events, max_event_bytes, and metadata.
## [br]
## @return 当前定义。
func configure(
	p_channel_id: StringName,
	options: Dictionary = {}
) -> GFSessionTraceChannelDefinition:
	channel_id = p_channel_id
	enabled = GFVariantData.get_option_bool(options, "enabled", enabled)
	include_in_snapshot = GFVariantData.get_option_bool(
		options,
		"include_in_snapshot",
		include_in_snapshot
	)
	max_events = GFVariantData.get_option_int(options, "max_events", max_events)
	max_event_bytes = GFVariantData.get_option_int(
		options,
		"max_event_bytes",
		max_event_bytes
	)
	metadata = _duplicate_dictionary(
		GFVariantData.as_dictionary(GFVariantData.get_option_value(options, "metadata", {}))
	)
	return self


## 校验通道定义。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, counts, summary, and next_actions.
func validate_definition() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	var channel_text: String = String(channel_id)
	if channel_id == &"" or channel_text != channel_text.strip_edges() or channel_text.length() > 128:
		var _id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_channel_id",
			"Trace channel id must be non-empty, trimmed, and at most 128 characters.",
			{ "path": "channel_id" }
		)
	if max_events < 0 or max_events > _MAX_CHANNEL_EVENTS:
		var _event_limit_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_channel_event_limit",
			"Trace channel max_events must be between 0 and 1000000.",
			{ "path": "max_events", "value": max_events }
		)
	if (
		max_event_bytes < 0
		or max_event_bytes > _MAX_CHANNEL_EVENT_BYTES
		or (max_event_bytes > 0 and max_event_bytes < _MIN_CHANNEL_EVENT_BYTES)
	):
		var _event_bytes_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_channel_event_byte_budget",
			"Trace channel max_event_bytes must be 0 or between 512 and 16777216.",
			{ "path": "max_event_bytes", "value": max_event_bytes }
		)
	return GFValidationReportDictionary.finalize_report(report, "Session trace channel", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_channel_id": "Assign a stable channel id with at most 128 characters.",
			"invalid_channel_event_limit": "Use a channel max_events value between 0 and 1000000.",
			"invalid_channel_event_byte_budget": "Use 0 or a channel max_event_bytes value between 512 and 16777216.",
		},
		"fallback_action": "Review the first trace channel issue.",
		"no_action": "Session trace channel is valid.",
	})


# --- 框架内部方法 ---

## 转换为 `GFSessionTraceUtility.register_channel()` 选项。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 通道选项副本。
## [br]
## @schema return: Dictionary with enabled, include_in_snapshot, max_events, max_event_bytes, and metadata.
func to_channel_options_for_framework() -> Dictionary:
	return {
		"enabled": enabled,
		"include_in_snapshot": include_in_snapshot,
		"max_events": max_events,
		"max_event_bytes": max_event_bytes,
		"metadata": GFReportValueCodec.to_report_dictionary(
			metadata,
			GFReportValueCodec.make_redaction_options(
				GFReportValueCodec.REDACTION_PROFILE_PRIVACY
			)
		),
	}


## 转换为配方指纹记录。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return JSON-safe 通道定义。
## [br]
## @schema return: Dictionary with channel_id and channel options.
func to_report_dictionary_for_framework() -> Dictionary:
	return {
		"channel_id": String(channel_id),
		"options": GFReportValueCodec.to_report_dictionary(
			to_channel_options_for_framework(),
			GFReportValueCodec.make_redaction_options(
				GFReportValueCodec.REDACTION_PROFILE_PRIVACY
			)
		),
	}


# --- 私有/辅助方法 ---

static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))
