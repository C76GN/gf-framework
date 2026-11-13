## GFQuestDefinition: 独立于运行状态的冻结任务定义。
##
## 指标由项目查询或输入提供；完成策略与指标模式独立。接取条件和完成阻塞器是
## GFQuestUtility 中的运行时回调，不进入可持久化定义。自动完成不发放业务奖励。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFQuestDefinition
extends RefCounted


# --- 常量 ---

## 查询项目已经积累的历史事实。
## [br]
## @api public
## [br]
## @since unreleased
const HISTORY: StringName = &"history"

## 只累计接取后收到的明确整数增量。
## [br]
## @api public
## [br]
## @since unreleased
const SINCE_ACCEPTANCE: StringName = &"since_acceptance"

## 查询会升降的当前值；默认需要显式确认完成。
## [br]
## @api public
## [br]
## @since unreleased
const CURRENT: StringName = &"current"

## 首次达标且完成阻塞器通过时完成。
## [br]
## @api public
## [br]
## @since unreleased
const AUTOMATIC: StringName = &"automatic"

## 达标后由 complete_quest 显式确认。
## [br]
## @api public
## [br]
## @since unreleased
const MANUAL: StringName = &"manual"

## 项目显式判定完成，只检查完成阻塞器，不要求计数达标。
## [br]
## @api public
## [br]
## @since unreleased
const EXTERNAL: StringName = &"external"


# --- 私有变量 ---

## 已验证的封闭纯数据定义。
## [br]
## @api private
var _record: Dictionary = {}


# --- 公共方法 ---

## 创建定义；相同 ID 的已接取任务不受随后发布的新版本影响。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 非空任务身份，最多 256 字符且不得带首尾空白。
## [br]
## @param metric_id: 指标或增量事件身份；external 策略可为空。
## [br]
## @param options: 定义政策。
## [br]
## @schema options: 封闭 Dictionary，可选 version:int>=1（默认1）、mode:String（history/since_acceptance/current，默认since_acceptance）、target:int>=0（默认1）、completion:String（automatic/manual/external）、allow_negative:bool（默认false）、metadata:Dictionary。current 默认manual，其他默认automatic。metadata 为有界原生纯数据，深度16、2048节点、64KiB。
## [br]
## @return 冻结定义；非法输入返回 null。
static func create(
	quest_id: StringName,
	metric_id: StringName,
	options: Dictionary = {}
) -> GFQuestDefinition:
	var prepared: Dictionary = _prepare_create(
		quest_id,
		metric_id,
		options
	)
	var report: Dictionary = prepared["report"]
	if not GFVariantData.get_option_bool(report, "ok"):
		return null
	var definition: GFQuestDefinition = GFQuestDefinition.new()
	var record: Dictionary = prepared["record"]
	definition._record = record.duplicate(true)
	return definition


## 只读检查 create 的输入，返回首个拒绝原因；不创建任务定义或保留输入引用。
##
## create 每次独立重新校验，旧报告不能授权后来修改的输入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 与 create 相同的任务身份。
## [br]
## @param metric_id: 与 create 相同的指标身份。
## [br]
## @param options: 与 create 相同的定义政策。
## [br]
## @schema options: 与 create.options 相同的封闭 Dictionary。
## [br]
## @return 当前输入的独立校验报告；不输出错误日志。
## [br]
## @schema return: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。
static func validate_create(
	quest_id: StringName,
	metric_id: StringName,
	options: Dictionary = {}
) -> Dictionary:
	var prepared: Dictionary = _prepare_create(
		quest_id,
		metric_id,
		options
	)
	var report: Dictionary = prepared["report"]
	return report


## 从持久化记录恢复并完整验证定义。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record: 完整定义记录。
## [br]
## @schema record: 必须且只能包含 quest_id:String、metric_id:String 和 create.options 的六个字段；不进行宽容转换。
## [br]
## @return 验证后的定义；失败返回 null。
static func from_record(record: Dictionary) -> GFQuestDefinition:
	if (
		record.size() != 8
		or not record.get("quest_id") is String
		or not record.get("metric_id") is String
	):
		return null
	var options: Dictionary = record.duplicate()
	var _removed_id: bool = options.erase("quest_id")
	var _removed_metric: bool = options.erase("metric_id")
	for required: String in [
		"version",
		"mode",
		"target",
		"completion",
		"allow_negative",
		"metadata",
	]:
		if not options.has(required):
			return null
	return create(
		StringName(GFVariantData.get_option_string(record, "quest_id")),
		StringName(GFVariantData.get_option_string(record, "metric_id")),
		options
	)


## 返回可持久化定义的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 定义记录；未经工厂验证的实例为空。
## [br]
## @schema return: 与 from_record.record 相同的八字段 Dictionary。
func to_record() -> Dictionary:
	return _record.duplicate(true)


## 获取任务身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 任务 ID；未验证实例为空。
func get_quest_id() -> StringName:
	return GFVariantData.get_option_string_name(_record, "quest_id")


## 获取指标身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 指标 ID。
func get_metric_id() -> StringName:
	return GFVariantData.get_option_string_name(_record, "metric_id")


## 获取定义版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数版本；未验证实例为0。
func get_version() -> int:
	return GFVariantData.get_option_int(_record, "version")


## 获取指标模式。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return HISTORY、SINCE_ACCEPTANCE 或 CURRENT。
func get_mode() -> StringName:
	return GFVariantData.get_option_string_name(_record, "mode")


## 获取目标计数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负目标。
func get_target() -> int:
	return GFVariantData.get_option_int(_record, "target")


## 获取完成策略。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return AUTOMATIC、MANUAL 或 EXTERNAL。
func get_completion() -> StringName:
	return GFVariantData.get_option_string_name(_record, "completion")


## 查询是否显式允许负向输入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 允许负数指标或增量时为 true。
func allows_negative() -> bool:
	return GFVariantData.get_option_bool(_record, "allow_negative")


# --- 私有/辅助方法 ---

## create 与只读诊断共用完整验证，临时 record 仅在本次调用中存在。
## [br]
## @api private
static func _prepare_create(
	quest_id: StringName,
	metric_id: StringName,
	options: Dictionary
) -> Dictionary:
	var report: Dictionary = _validate_definition_id(
		String(quest_id),
		"/quest_id"
	)
	if not GFVariantData.get_option_bool(report, "ok"):
		return { "report": report }
	if metric_id != &"":
		report = _validate_definition_id(
			String(metric_id),
			"/metric_id"
		)
		if not GFVariantData.get_option_bool(report, "ok"):
			return { "report": report }
	for key: Variant in options:
		if not key is String:
			return { "report": _validation_report("invalid_key_type", "/options") }
		var field: String = key
		if field not in [
			"version",
			"mode",
			"target",
			"completion",
			"allow_negative",
			"metadata",
		]:
			var field_path: String = "/options/" + field.replace("~", "~0").replace("/", "~1")
			return { "report": _validation_report("unknown_field", field_path) }
	var version_value: Variant = options.get("version", 1)
	var target_value: Variant = options.get("target", 1)
	var mode_value: Variant = options.get("mode", "since_acceptance")
	var negative_value: Variant = options.get("allow_negative", false)
	var metadata_value: Variant = options.get("metadata", {})
	if not version_value is int:
		return { "report": _validation_report("invalid_type", "/options/version") }
	if not target_value is int:
		return { "report": _validation_report("invalid_type", "/options/target") }
	if not mode_value is String:
		return { "report": _validation_report("invalid_type", "/options/mode") }
	if not negative_value is bool:
		return { "report": _validation_report("invalid_type", "/options/allow_negative") }
	if not metadata_value is Dictionary:
		return { "report": _validation_report("invalid_type", "/options/metadata") }
	var version: int = version_value
	var target: int = target_value
	var mode: String = mode_value
	if version < 1:
		return { "report": _validation_report("invalid_value", "/options/version") }
	if target < 0:
		return { "report": _validation_report("invalid_value", "/options/target") }
	if mode not in [
		String(HISTORY),
		String(SINCE_ACCEPTANCE),
		String(CURRENT),
	]:
		return { "report": _validation_report("invalid_value", "/options/mode") }
	var completion_value: Variant = options.get(
		"completion",
		"manual" if mode == String(CURRENT) else "automatic"
	)
	if not completion_value is String:
		return { "report": _validation_report("invalid_type", "/options/completion") }
	if completion_value not in [
		"automatic",
		"manual",
		"external",
	]:
		return { "report": _validation_report("invalid_value", "/options/completion") }
	if metric_id == &"" and completion_value != "external":
		return { "report": _validation_report("required", "/metric_id") }
	var metadata: Dictionary = metadata_value
	report = _validate_metadata(metadata)
	if not GFVariantData.get_option_bool(report, "ok"):
		return { "report": report }
	return {
		"report": report,
		"record": {
			"quest_id": String(quest_id),
			"metric_id": String(metric_id),
			"version": version,
			"mode": mode,
			"target": target,
			"completion": completion_value,
			"allow_negative": negative_value,
			"metadata": metadata,
		},
	}


## 将身份长度与格式拒绝分开，保留原有身份语义。
## [br]
## @api private
static func _validate_definition_id(value: String, path: String) -> Dictionary:
	if value.length() > 256:
		return _validation_report(
			"length_limit",
			path,
			256,
			value.length()
		)
	if not _valid_id(value):
		return _validation_report("invalid_id", path)
	return _validation_report()


## 每次创建独立纯数据报告，不保存全局错误或可复用的准入资格。
## [br]
## @api private
static func _validation_report(
	error_kind: String = "",
	path: String = "",
	limit: int = -1,
	observed: int = -1
) -> Dictionary:
	var report: Dictionary = {
		"ok": error_kind.is_empty(),
		"error_kind": error_kind,
		"path": path,
	}
	if limit >= 0:
		report["limit"] = limit
		report["observed"] = observed
	return report


## 保留底层计量和预算，不从错误文本猜测种类或把前缀计数当作总量。
## [br]
## @api private
static func _data_validation_report(
	measured: Dictionary,
	limits: Dictionary,
	path: String
) -> Dictionary:
	if GFVariantData.get_option_bool(measured, "ok"):
		return _validation_report()
	var report: Dictionary = _validation_report("data_invalid", path)
	report["measurement"] = measured.duplicate(true)
	report["limits"] = limits.duplicate()
	var limit_kind: String = GFVariantData.get_option_string(measured, "limit_kind")
	if not limit_kind.is_empty():
		report["error_kind"] = "budget_exceeded"
		report["limit_kind"] = limit_kind
		report["limit"] = GFVariantData.get_option_int(measured, "limit")
		report["observed"] = GFVariantData.get_option_int(measured, "observed")
		report["observed_is_lower_bound"] = GFVariantData.get_option_bool(measured, "observed_is_lower_bound")
	elif GFVariantData.get_option_string(measured, "failure_kind") == "output_limit":
		var output_limit: int = GFVariantData.get_option_int(limits, "max_output_bytes")
		report["error_kind"] = "budget_exceeded"
		report["limit_kind"] = "max_output_bytes"
		report["limit"] = output_limit
		report["observed"] = output_limit + 1
		report["observed_is_lower_bound"] = true
	return report


## 检查持久化身份文本，不规范化到另一个身份。
## [br]
## @api private
static func _valid_id(value: String) -> bool:
	if (
		value.is_empty()
		or value.length() > 256
		or value != value.strip_edges()
	):
		return false
	for index: int in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true


## 只读测量定义元数据，保留拒绝时的预算和前缀计量。
## [br]
## @api private
static func _validate_metadata(value: Dictionary) -> Dictionary:
	var limits: Dictionary = {
		"allow_floats": true,
		"max_depth": 16,
		"max_items": 2048,
		"max_output_bytes": 65536,
		"max_string_length": 65536,
	}
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(value, limits)
	return _data_validation_report(
		measured,
		limits,
		"/options/metadata"
	)
