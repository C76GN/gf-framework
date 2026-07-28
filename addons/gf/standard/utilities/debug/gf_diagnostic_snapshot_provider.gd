## GFDiagnosticSnapshotProvider: 按请求求值的诊断快照 Provider 协议。
##
## Provider 不会被轮询或随普通快照隐式执行。项目必须显式请求稳定 Provider ID，
## 输出才会由 `GFDiagnosticsUtility` 在重入保护、结构预算和脱敏边界内采集。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 10.0.0
class_name GFDiagnosticSnapshotProvider
extends RefCounted


# --- 常量 ---

## 默认 Provider 返回后验收时长预算，单位微秒。
##
## 同步 GDScript 无法被安全抢占；该预算用于拒绝和诊断已经返回的慢采集结果，
## 不能替代 Provider 自身的有界实现。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_DURATION_USEC: int = 50_000


# --- 公共变量 ---

## Provider 稳定 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
var provider_id: StringName = &"":
	set(value):
		if _definition_locked and value != provider_id:
			push_error("[GFDiagnosticSnapshotProvider] 已注册的 provider_id 不可修改。")
			return
		provider_id = value

## Provider 返回后的最大验收时长，单位微秒；0 表示不做时长拒绝。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_duration_usec: int = DEFAULT_MAX_DURATION_USEC:
	set(value):
		if _definition_locked and value != max_duration_usec:
			push_error("[GFDiagnosticSnapshotProvider] 已注册的 max_duration_usec 不可修改。")
			return
		max_duration_usec = value

## Provider 目录元数据。注册后不可修改，读取时返回副本，输出前由聚合器执行预算和脱敏。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema metadata: Dictionary with provider-defined catalog metadata.
var metadata: Dictionary:
	set(value):
		if _definition_locked and value != _metadata:
			push_error("[GFDiagnosticSnapshotProvider] 已注册的 metadata 不可修改。")
			return
		_metadata = _duplicate_dictionary(value)
	get:
		return _duplicate_dictionary(_metadata)


# --- 私有变量 ---

var _definition_locked: bool = false
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 配置 Provider 定义并返回自身。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param p_provider_id: 稳定 Provider ID。
## [br]
## @param options: 可选目录元数据。
## [br]
## @schema options: Dictionary with optional max_duration_usec: int and metadata: Dictionary.
## [br]
## @return 当前 Provider。
func configure(
	p_provider_id: StringName,
	options: Dictionary = {}
) -> GFDiagnosticSnapshotProvider:
	provider_id = p_provider_id
	max_duration_usec = GFVariantData.get_option_int(
		options,
		"max_duration_usec",
		max_duration_usec
	)
	metadata = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(options, "metadata", {})
	)
	return self


## 校验 Provider 定义。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, counts, summary, and next_actions.
func validate_provider() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	var provider_text: String = String(provider_id)
	if provider_id == &"" or provider_text != provider_text.strip_edges() or provider_text.length() > 128:
		var _id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_provider_id",
			"Diagnostic provider id must be non-empty, trimmed, and at most 128 characters.",
			{ "path": "provider_id" }
		)
	if max_duration_usec < 0:
		var _duration_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_provider_duration_budget",
			"Diagnostic provider max_duration_usec must be non-negative.",
			{ "path": "max_duration_usec", "value": max_duration_usec }
		)
	return GFValidationReportDictionary.finalize_report(report, "Diagnostic snapshot provider", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_provider_id": "Assign a stable, non-empty provider id with at most 128 characters.",
			"invalid_provider_duration_budget": "Use a non-negative max_duration_usec; use 0 only when post-return duration rejection is intentionally disabled.",
		},
		"fallback_action": "Review the first diagnostic provider issue.",
		"no_action": "Diagnostic snapshot provider is valid.",
	})


## 采集一次诊断结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param request: 调用方提供的临时只读上下文。
## [br]
## @schema request: Dictionary with caller-defined ephemeral fields.
## [br]
## @return 类型化 Provider 结果；实现返回 null 时由聚合器按无效结果处理。
func collect_snapshot(request: Dictionary = {}) -> GFDiagnosticProviderResult:
	return _collect_snapshot(_duplicate_dictionary(request))


# --- 可重写钩子 / 虚方法 ---

## 实现一次同步、只读且有界的诊断采集。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _request: 调用方提供的临时上下文副本。
## [br]
## @schema _request: Dictionary with caller-defined ephemeral fields.
## [br]
## @return 类型化采集结果。
func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
	return GFDiagnosticProviderResult.failed(
		&"provider_not_implemented",
		"Diagnostic provider did not implement _collect_snapshot()."
	)


# --- 框架内部方法 ---

## 锁定 Provider 身份定义。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return Provider 合法且已锁定时返回 true。
func lock_definition_for_framework() -> bool:
	if not GFVariantData.get_option_bool(validate_provider(), "ok", false):
		return false
	_definition_locked = true
	return true


# --- 私有/辅助方法 ---

static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))
