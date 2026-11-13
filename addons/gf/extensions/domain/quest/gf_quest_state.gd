## GFQuestState: 可验证、可持久化且不持有回调的任务状态快照。
##
## 冻结接取时的定义、接取信息和生命周期。查询型指标的缓存不能在恢复时充当新样本；
## GFQuestUtility 恢复后将其标记为不可用，直到项目显式刷新。已完成状态保持完成。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFQuestState
extends RefCounted


# --- 私有变量 ---

## 完整验证后的隔离记录。
## [br]
## @api private
var _record: Dictionary = {}

## 该状态绑定的冻结定义。
## [br]
## @api private
var _definition: GFQuestDefinition


# --- 公共方法 ---

## 验证状态记录，不触发项目查询、任务事件或奖励。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record: 完整状态记录。
## [br]
## @schema record: 封闭九字段 Dictionary：definition:GFQuestDefinition记录、status:String（available/active/completed/cancelled/failed）、current_count:int、metric_available:bool、accepted:bool、acceptance_data:Dictionary、parent_id:String、failure_reason:String、format_version:int=1。acceptance_data为原生纯数据，深度16、2048节点、64KiB；记录总预算深度20、8192节点、256KiB。available必须未接取；active/completed必须已接取；非external的completed必须保存达标样本。父级存在性和环由Utility在整批恢复时验证。
## [br]
## @return 冻结状态；不合法时为 null。
static func from_record(record: Dictionary) -> GFQuestState:
	var fields: Array[String] = [
		"definition",
		"status",
		"current_count",
		"metric_available",
		"accepted",
		"acceptance_data",
		"parent_id",
		"failure_reason",
		"format_version",
	]
	if record.size() != fields.size():
		return null
	for key: Variant in record:
		if not key is String or key not in fields:
			return null
	if not record.get("definition") is Dictionary or not record.get("acceptance_data") is Dictionary:
		return null
	if (
		not record.get("status") is String
		or not record.get("parent_id") is String
		or not record.get("failure_reason") is String
	):
		return null
	if not record.get("current_count") is int or not record.get("format_version") is int:
		return null
	if (
		not record.get("accepted") is bool
		or not record.get("metric_available") is bool
		or record["format_version"] != 1
	):
		return null
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		record,
		{
			"allow_floats": true,
			"max_depth": 20,
			"max_items": 8192,
			"max_output_bytes": 262144,
			"max_string_length": 65536,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return null
	var definition_record: Dictionary = record["definition"]
	var definition: GFQuestDefinition = GFQuestDefinition.from_record(definition_record)
	if definition == null:
		return null
	var status: String = record["status"]
	var current: int = record["current_count"]
	var accepted: bool = record["accepted"]
	var available: bool = record["metric_available"]
	var acceptance: Dictionary = record["acceptance_data"]
	var acceptance_budget: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		acceptance,
		{
			"allow_floats": true,
			"max_depth": 16,
			"max_items": 2048,
			"max_output_bytes": 65536,
			"max_string_length": 65536,
		}
	)
	if not GFVariantData.get_option_bool(acceptance_budget, "ok"):
		return null
	var parent: String = record["parent_id"]
	var reason: String = record["failure_reason"]
	if status not in [
		"available",
		"active",
		"completed",
		"cancelled",
		"failed",
	]:
		return null
	if (
		(
			status == "available"
			and accepted
		)
		or (
			status in ["active", "completed"]
			and not accepted
		)
	):
		return null
	if (
		not accepted
		and (
			current != 0
			or available
			or not acceptance.is_empty()
		)
	):
		return null
	if current < 0 and not definition.allows_negative():
		return null
	if (
		status == "completed"
		and definition.get_completion() != GFQuestDefinition.EXTERNAL
		and (
			not available
			or current < definition.get_target()
		)
	):
		return null
	if (
		parent == String(definition.get_quest_id())
		or parent.length() > 256
		or parent != parent.strip_edges()
	):
		return null
	for index: int in range(parent.length()):
		if parent.unicode_at(index) < 32:
			return null
	if (
		reason.length() > 4096
		or (
			status != "failed"
			and not reason.is_empty()
		)
	):
		return null
	var state: GFQuestState = GFQuestState.new()
	state._record = record.duplicate(true)
	state._definition = definition
	return state


## 返回状态记录的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 验证后的状态；未通过工厂创建的实例返回空字典。
## [br]
## @schema return: 与 from_record.record 相同的封闭九字段 Dictionary。
func to_record() -> Dictionary:
	return _record.duplicate(true)


## 获取该状态绑定的冻结定义。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 冻结定义；未验证的实例为 null。
func get_definition() -> GFQuestDefinition:
	return _definition


## 获取生命周期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return available、active、completed、cancelled 或 failed。
func get_status() -> StringName:
	return GFVariantData.get_option_string_name(_record, "status")


## 获取已记录的指标值；查询型指标可能只是缓存。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 整数指标值。
func get_current_count() -> int:
	return GFVariantData.get_option_int(_record, "current_count")


## 区分可用于当前判断的样本与尚未刷新的缓存。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 导出状态时指标可用则为 true。
func is_metric_available() -> bool:
	return GFVariantData.get_option_bool(_record, "metric_available")
