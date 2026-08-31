## GFTableRowPredicateRegistration: 命名行谓词的注册定义值。
##
## 把项目谓词与稳定 ID、启用状态和显式顺序组合成一次注册定义。
## GFTableDataView 会复制数组并以 order 升序、predicate_id 字典序稳定执行。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFTableRowPredicateRegistration
extends RefCounted


# --- 常量 ---

const _MAX_PREDICATE_ID_UTF8_BYTES: int = 128


# --- 私有变量 ---

var _predicate_id: StringName = &""
var _predicate: GFTableRowPredicate = null
var _order: int = 0
var _enabled: bool = true


# --- 公共方法 ---

## 创建注册定义值。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param predicate_id: 非空、无首尾空白且 UTF-8 编码不超过 128 字节的稳定 ID。
## [br]
## @param predicate: 项目提供的类型化行谓词。
## [br]
## @param order: 执行顺序；数值越小越早执行。
## [br]
## @param enabled: 是否参与投影。
## [br]
## @return 新的注册值；调用方仍应检查 validate_registration()。
static func create(
	predicate_id: StringName,
	predicate: GFTableRowPredicate,
	order: int = 0,
	enabled: bool = true
) -> GFTableRowPredicateRegistration:
	var registration: GFTableRowPredicateRegistration = GFTableRowPredicateRegistration.new()
	registration._predicate_id = predicate_id
	registration._predicate = predicate
	registration._order = order
	registration._enabled = enabled
	return registration


## 从候选注册的基类存储创建纯框架快照，不调用候选可覆写方法。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param registration: 待隔离的注册值。
## [br]
## @return 纯 GFTableRowPredicateRegistration；输入为空时返回 null。
static func snapshot_for_framework(
	registration: GFTableRowPredicateRegistration
) -> GFTableRowPredicateRegistration:
	if registration == null or not is_instance_valid(registration):
		return null
	return create(
		registration._predicate_id,
		registration._predicate,
		registration._order,
		registration._enabled
	)


## 获取稳定谓词 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 稳定谓词 ID。
func get_predicate_id() -> StringName:
	return _predicate_id


## 获取类型化谓词。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 注册的谓词。
func get_predicate() -> GFTableRowPredicate:
	return _predicate


## 获取显式执行顺序。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return order；数值越小越早执行。
func get_order() -> int:
	return _order


## 查询注册是否启用。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 启用时返回 true。
func is_enabled() -> bool:
	return _enabled


## 校验注册定义。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, counts, summary, and next_actions.
func validate_registration() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	var predicate_id_text: String = String(_predicate_id)
	if (
		predicate_id_text.is_empty()
		or predicate_id_text != predicate_id_text.strip_edges()
		or predicate_id_text.length() > _MAX_PREDICATE_ID_UTF8_BYTES
		or predicate_id_text.to_utf8_buffer().size() > _MAX_PREDICATE_ID_UTF8_BYTES
	):
		var _id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_predicate_id",
			"Table row predicate id must be non-empty, trimmed, and at most 128 UTF-8 bytes.",
			{ "path": "predicate_id" }
		)
	if _predicate == null or not is_instance_valid(_predicate):
		var _predicate_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_predicate",
			"Table row predicate registration requires a predicate instance.",
			{ "path": "predicate" }
		)
	return GFValidationReportDictionary.finalize_report(report, "Table row predicate registration", {
		"include_issue_count": true,
		"fallback_action": "Review the first table row predicate registration issue.",
		"no_action": "Table row predicate registration is valid.",
	})
