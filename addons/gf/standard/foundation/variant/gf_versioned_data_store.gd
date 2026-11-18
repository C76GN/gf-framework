## GFVersionedDataStore: 受控写入、原子提交的分页纯数据记录序列。
##
## 只有交给此容器的记录参与版本管理。嵌套容器按值隔离，共享引用不保留业务身份。
## 支持替换、追加与清空；不提供任意位置插删或通用对象图。固定版本不遍历记录。
## 单线程串行使用；close 后仍须保留存储并推进 collect_garbage，直到回收债务归零。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFVersionedDataStore
extends RefCounted


# --- 常量 ---

## 默认有限预算；单条记录也是每次写入及回收的最大工作单元。
## [br]
## @api private
const _DEFAULTS: Dictionary[String, int] = {
	"max_records": 1_000_000,
	"max_owned_bytes": 134_217_728,
	"max_nodes": 2_000_000,
	"max_versions": 16,
	"max_readers": 64,
	"max_record_items": 4096,
	"max_record_payload_bytes": 65_536,
	"max_record_depth": 32,
	"max_record_elapsed_msec": 100,
}


# --- 私有变量 ---

## 负责当前版本与所有读取租约的共享存储。
## [br]
## @api private
var _arena: GFDataVersionArena = null

## 构造时复制并校验的有限预算。
## [br]
## @api private
var _limits: Dictionary[String, int] = {}

## 单条原始输入的同步捕获限制。
## [br]
## @api private
var _record_limits: Dictionary = {}

## 当前根引用；空序列为零。
## [br]
## @api private
var _root: int = 0

## 当前根的页层数，叶页为零。
## [br]
## @api private
var _level: int = 0

## 当前版本记录数量。
## [br]
## @api private
var _count: int = 0

## 只在完整事务成功后推进。
## [br]
## @api private
var _revision: int = 0

## 直接 new 与 close 后均不接受写入和获取。
## [br]
## @api private
var _open: bool = false


# --- Godot 生命周期方法 ---

## 最后引用释放仍归还当前根；显式关闭与分步回收才提供帧成本控制。
## [br]
## @api private
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _open:
		_arena.release_version(
			_root,
			_revision,
			false
		)
		_open = false


# --- 公共方法 ---

## 创建空序列；原始输入通过显式 commit 导入，构造没有隐藏全量复制。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param limits: 正整数限制，未知选项被拒绝。
## [br]
## @schema limits: Dictionary with optional max_records (1000000, at most 2147483647), max_owned_bytes (134217728), max_nodes (2000000), max_versions (16), max_readers (64), max_record_items (4096), max_record_payload_bytes (65536), max_record_depth (32, at most 255), max_record_elapsed_msec (100). Byte accounting includes unique retained nodes, staged input allowance and pending reclamation; it is not process RSS.
## [br]
## @return: 开放存储；非法配置返回 null。
static func create(limits: Dictionary = {}) -> GFVersionedDataStore:
	var effective: Dictionary[String, int] = _DEFAULTS.duplicate()
	for key: Variant in limits:
		if not effective.has(key) or not limits[key] is int:
			return null
		var number: int = limits[key]
		if number <= 0 or number > 2_147_483_647:
			return null
		effective[key] = number
	if effective["max_record_depth"] > 255:
		return null
	var store: GFVersionedDataStore = GFVersionedDataStore.new()
	store._limits = effective
	store._record_limits = {
		"max_items": effective["max_record_items"],
		"max_payload_bytes": effective["max_record_payload_bytes"],
		"max_string_length": effective["max_record_payload_bytes"],
		"max_depth": effective["max_record_depth"],
		"max_elapsed_msec": effective["max_record_elapsed_msec"],
	}
	store._arena = GFDataVersionArena.new()
	store._arena.configure(effective)
	var acquired: bool = store._arena.acquire_version(
		0,
		0,
		false
	)
	store._open = acquired
	return store


## 原子替换已有记录并追加新记录；输入仅需在本次同步调用期间稳定。
##
## 每条记录独立隔离；提交失败不改变当前版本或外部输入。大批导入是显式同步成本，
## 项目可在加载期完成，或以可接受的批次提交；不会自动把活数据当作跨帧稳定源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param replacements: 已有非负记录位置到新纯数据值的映射。
## [br]
## @schema replacements: Dictionary[int, Variant], positions must be less than current count; values follow GFDataSnapshot pure-data rules and per-record limits.
## [br]
## @param appended: 按顺序追加的记录值。
## [br]
## @schema appended: Array of pure-data records, each independently isolated.
## [br]
## @param expected_revision: 非负时必须等于当前版本；-1 表示不做乐观版本检查。
## [br]
## @return: 成功版本或明确失败；失败不消耗版本号。
## [br]
## @schema return: Dictionary with ok: bool, revision: int, error_kind: String; optional record_error: Dictionary from GFDataSnapshot.capture without snapshot.
func commit(
	replacements: Dictionary,
	appended: Array = [],
	expected_revision: int = -1
) -> Dictionary:
	if not _open:
		return _result(false, "store_closed")
	if (
		expected_revision < -1
		or (
			expected_revision >= 0
			and expected_revision != _revision
		)
	):
		return _result(false, "revision_conflict")
	if _revision == 9_223_372_036_854_775_807:
		return _result(false, "revision_exhausted")
	if appended.size() > int(_limits["max_records"]) - _count:
		return _result(false, "record_limit")
	for key: Variant in replacements:
		if not key is int:
			return _result(false, "invalid_position")
		var position: int = key
		if position < 0 or position >= _count:
			return _result(false, "invalid_position")
	if replacements.is_empty() and appended.is_empty():
		return _result(false, "empty_transaction")
	if not _arena.can_replace_version(_revision):
		return _result(false, "version_limit")
	var staging: int = int(_limits["max_record_payload_bytes"]) + int(_limits["max_record_items"]) * 32 + 128
	if not _arena.reserve_bytes(staging):
		return _result(false, "memory_limit")
	var candidate: PackedInt64Array = PackedInt64Array([_root, _level])
	var writable: Dictionary[int, bool] = {}
	_arena.retain_node(_root)
	var failure: Dictionary = {}
	for key: Variant in replacements:
		var position: int = key
		failure = _write_record(
			candidate,
			position,
			replacements[key],
			writable
		)
		if not failure.is_empty():
			break
	if failure.is_empty():
		for offset: int in range(appended.size()):
			failure = _write_record(
				candidate,
				_count + offset,
				appended[offset],
				writable
			)
			if not failure.is_empty():
				break
	_arena.return_bytes(staging)
	if not failure.is_empty():
		_arena.release_node(candidate[0])
		return failure
	_arena.release_version(
		_root,
		_revision,
		false
	)
	_root = candidate[0]
	_level = candidate[1]
	_count += appended.size()
	_revision += 1
	var _acquired: bool = _arena.acquire_version(
		_root,
		_revision,
		false
	)
	_arena.release_node(_root)
	return _result(true, "")


## 原子清空当前序列；已固定的历史版本保持原内容。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 新版本或失败原因；回收由 collect_garbage 推进。
## [br]
## @schema return: Dictionary with ok: bool, revision: int and error_kind: String.
func clear() -> Dictionary:
	if not _open:
		return _result(false, "store_closed")
	if not _arena.can_replace_version(_revision):
		return _result(false, "version_limit")
	if _revision == 9_223_372_036_854_775_807:
		return _result(false, "revision_exhausted")
	_arena.release_version(
		_root,
		_revision,
		false
	)
	_root = 0
	_level = 0
	_count = 0
	_revision += 1
	var _acquired: bool = _arena.acquire_version(
		0,
		_revision,
		false
	)
	return _result(true, "")


## 固定当前完整版本，只处理根与元信息，不复制或扫描记录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 独占读取租约；关闭或读者预算耗尽为 null。
func acquire_snapshot() -> GFDataVersion:
	if not _open:
		return null
	if not _arena.acquire_version(
		_root,
		_revision,
		true
	):
		return null
	var version: GFDataVersion = GFDataVersion.new()
	version.configure(
		_arena,
		PackedInt64Array(
			[
				_root,
				_level,
				_count,
				_revision,
			]
		)
	)
	return version


## 停止写入与新租约，退还当前根；现有租约继续有效。
## [br]
## @api public
## [br]
## @since unreleased
func close() -> void:
	if not _open:
		return
	_open = false
	_arena.release_version(
		_root,
		_revision,
		false
	)
	_root = 0


## 有界推进失去全部引用的页和记录回收，关闭后仍可调用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param max_nodes: 本次最多回收的节点数，必须为正。
## [br]
## @return: 实际回收数量；不会扫描仍被保留的版本。
func collect_garbage(max_nodes: int = 64) -> int:
	if _arena == null or max_nodes <= 0:
		return 0
	return _arena.collect(max_nodes)


## 返回当前版本与全部仍占用预算的存储计量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 纯标量诊断副本，pending_nodes 为零表示当前没有回收债务。
## [br]
## @schema return: Dictionary with open: bool, revision, count, charged_bytes, peak_bytes, nodes, pending_nodes, versions and readers: int. Caller-owned detached read copies are outside store accounting.
func get_statistics() -> Dictionary:
	var stats: Dictionary = {} if _arena == null else _arena.get_statistics()
	stats["open"] = _open
	stats["revision"] = _revision
	stats["count"] = _count
	return stats


# --- 私有/辅助方法 ---

## 每个候选根都拥有独立临时引用，任何失败都由 commit 退还。
## [br]
## @api private
func _write_record(
	candidate: PackedInt64Array,
	index: int,
	value: Variant,
	writable: Dictionary[int, bool]
) -> Dictionary:
	var captured: Dictionary = GFDataSnapshot.capture(value, _record_limits)
	if not captured["ok"]:
		var failure: Dictionary = _result(false, "invalid_record")
		var _erased: bool = captured.erase("snapshot")
		failure["record_error"] = captured
		return failure
	var snapshot: GFDataSnapshot = captured["snapshot"]
	var record: int = _arena.add_record(snapshot)
	if record == 0:
		return _result(false, "memory_limit")
	while index >= (1 << ((candidate[1] + 1) * 5)):
		var grown: int = _arena.grow_root(candidate[0])
		if grown == 0:
			_arena.release_node(record)
			return _result(false, "memory_limit")
		_arena.release_node(candidate[0])
		candidate[0] = grown
		candidate[1] += 1
		writable[grown] = true
	var next_root: int = _arena.replace_record(
		candidate[0],
		candidate[1],
		index,
		record,
		writable
	)
	_arena.release_node(record)
	if next_root == 0:
		return _result(false, "memory_limit")
	_arena.release_node(candidate[0])
	candidate[0] = next_root
	var _collected: int = _arena.collect(64)
	return {}


## 失败报告只包含本存储的当前版本，不泄漏候选数据。
## [br]
## @api private
func _result(ok: bool, error_kind: String) -> Dictionary:
	return {
		"ok": ok,
		"revision": _revision,
		"error_kind": error_kind,
	}
