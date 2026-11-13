## GFStorageConflictReport: 冻结的记录冲突与显式解决候选。
##
## 载荷只能通过显式 getter 读取；to_dict() 不包含身份、revision 或业务数据。
## revision 只能比较相等。报告不执行写入，也不证明解决候选已提交。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFStorageConflictReport
extends RefCounted


# --- 枚举 ---

## 候选的解决方式，不代表持久化结果。
## [br]
## @api public
## [br]
## @since unreleased
enum Resolution {
	## 尚未决定。
	UNRESOLVED,
	## 选择本地候选。
	USE_LOCAL,
	## 选择远端候选。
	USE_REMOTE,
	## 使用项目合并候选。
	MERGED,
	## 跳过冲突。
	SKIPPED,
}


# --- 私有变量 ---

## 工厂校验后的独立数据，不向调用方暴露容器。
## [br]
## @api private
var _record: Dictionary = {}


# --- 公共方法 ---

## 创建冻结报告；无效身份、选项或载荷返回 null。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record_namespace: 记录命名空间。
## [br]
## @param record_key: 记录键。
## [br]
## @param local_data: 本地完整候选。
## [br]
## @param remote_data: 已观察的远端完整候选。
## [br]
## @param options: revision 与存在性声明。
## [br]
## @schema local_data: Dictionary of finite native data; no objects or cycles.
## [br]
## @schema remote_data: Same native contract; empty when remote_exists=false.
## [br]
## @schema options: Closed Dictionary with expected_revision:String (default empty), actual_revision:String (default empty), remote_exists:bool (default true). Empty revisions are allowed for plain Backend transfers.
## [br]
## @return 隔离报告或 null；完整报告限深度64、300000节点、64MiB规范字节。
static func create(
	record_namespace: String,
	record_key: String,
	local_data: Dictionary,
	remote_data: Dictionary,
	options: Dictionary = {}
) -> GFStorageConflictReport:
	if record_namespace.is_empty() or record_key.is_empty():
		return null
	for key: Variant in options:
		if key not in [
			"expected_revision",
			"actual_revision",
			"remote_exists",
		]:
			return null
	var expected: Variant = options.get("expected_revision", "")
	var actual: Variant = options.get("actual_revision", "")
	var exists: Variant = options.get("remote_exists", true)
	if (
		not expected is String
		or not actual is String
		or not exists is bool
	):
		return null
	if (
		exists == false
		and (
			not remote_data.is_empty()
			or actual != ""
		)
	):
		return null
	return _from_record(
		{
			"namespace": record_namespace,
			"key": record_key,
			"local_data": local_data,
			"remote_data": remote_data,
			"expected_revision": expected,
			"actual_revision": actual,
			"remote_exists": exists,
			"resolution": Resolution.UNRESOLVED,
			"resolved_data": {},
		}
	)


## 返回指定解决候选的新报告；原报告不变。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param resolution: 明确的解决方式。
## [br]
## @param data: 解决候选；未解决或跳过时必须为空。
## [br]
## @schema data: Dictionary of admitted finite native data.
## [br]
## @return 隔离的新报告或 null。
func with_resolution(resolution: Resolution, data: Dictionary = {}) -> GFStorageConflictReport:
	if (
		_record.is_empty()
		or resolution < Resolution.UNRESOLVED
		or resolution > Resolution.SKIPPED
	):
		return null
	if resolution in [Resolution.UNRESOLVED, Resolution.SKIPPED] and not data.is_empty():
		return null
	var record: Dictionary = _record.duplicate(true)
	record["resolution"] = resolution
	record["resolved_data"] = data
	return _from_record(record)


## 复制完整报告；无效对象返回 null。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 独立报告副本。
func duplicate_report() -> GFStorageConflictReport:
	return _from_record(_record) if not _record.is_empty() else null


## 获取记录命名空间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定命名空间。
func get_namespace() -> String:
	return GFVariantData.get_option_string(_record, "namespace")


## 获取记录键。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定记录键。
func get_key() -> String:
	return GFVariantData.get_option_string(_record, "key")


## 获取本地已知 revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不透明 revision。
func get_expected_revision() -> String:
	return GFVariantData.get_option_string(_record, "expected_revision")


## 获取远端观察 revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不透明 revision。
func get_actual_revision() -> String:
	return GFVariantData.get_option_string(_record, "actual_revision")


## 获取本地候选副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整候选副本。
## [br]
## @schema return: Dictionary of admitted native data.
func get_local_data() -> Dictionary:
	return GFVariantData.get_option_dictionary(_record, "local_data").duplicate(true)


## 获取远端候选副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整候选副本。
## [br]
## @schema return: Dictionary of admitted native data.
func get_remote_data() -> Dictionary:
	return GFVariantData.get_option_dictionary(_record, "remote_data").duplicate(true)


## 获取解决候选副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未持久化的候选副本。
## [br]
## @schema return: Dictionary of admitted native data.
func get_resolved_data() -> Dictionary:
	return GFVariantData.get_option_dictionary(_record, "resolved_data").duplicate(true)


## 查询远端记录存在性。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已观察远端存在时为 true。
func remote_exists() -> bool:
	return GFVariantData.get_option_bool(_record, "remote_exists")


## 获取选择的解决方式。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Resolution 枚举值。
func get_resolution() -> Resolution:
	var value: int = GFVariantData.get_option_int(_record, "resolution")
	match value:
		Resolution.USE_LOCAL:
			return Resolution.USE_LOCAL
		Resolution.USE_REMOTE:
			return Resolution.USE_REMOTE
		Resolution.MERGED:
			return Resolution.MERGED
		Resolution.SKIPPED:
			return Resolution.SKIPPED
		_:
			return Resolution.UNRESOLVED


## 检查是否已选择解决方式，不代表写入成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已选择或跳过时为 true。
func is_resolved() -> bool:
	return get_resolution() != Resolution.UNRESOLVED


## 导出不含载荷与身份的诊断摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 诊断摘要。
## [br]
## @schema return: Dictionary with valid:bool,resolution:int,remote_exists:bool,revision_matches:bool.
func to_dict() -> Dictionary:
	return {
		"valid": not _record.is_empty(),
		"resolution": get_resolution(),
		"remote_exists": remote_exists(),
		"revision_matches": get_expected_revision() == get_actual_revision(),
	}


# --- 私有/辅助方法 ---

## 有界验证整个报告，再复制容器所有权。
## [br]
## @api private
static func _from_record(record: Dictionary) -> GFStorageConflictReport:
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		record,
		{
			"allow_floats": true,
			"max_depth": 64,
			"max_items": 300000,
			"max_output_bytes": 67108864,
			"max_string_length": 16777216,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return null
	var report: GFStorageConflictReport = GFStorageConflictReport.new()
	report._record = record.duplicate(true)
	return report
