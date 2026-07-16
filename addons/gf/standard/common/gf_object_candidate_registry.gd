## GFObjectCandidateRegistry: 通用 Object 候选注册表。
##
## 使用弱引用记录候选对象，并提供按 group、method、priority 和注册顺序筛选排序的
## 候选快照。它不解释候选对象的业务语义，适合交互、命中、选择或编辑器工具复用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFObjectCandidateRegistry
extends RefCounted


# --- 公共变量 ---

## 最大候选记录数量；小于等于 0 时不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_candidates: int = 0:
	set(value):
		max_candidates = maxi(value, 0)

## 注册表自定义元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary copied into debug snapshots.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _records: Dictionary = {}
var _order: Array[int] = []
var _serial: int = 0


# --- 公共方法 ---

## 清空全部候选。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear() -> void:
	_records.clear()
	_order.clear()
	_serial = 0


## 注册或更新一个候选对象。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate: 候选对象。
## [br]
## @param options: 注册选项。
## [br]
## @schema options: Dictionary with optional priority:int, group:StringName, owner:Object|int|String|StringName, stable_key:Variant, and metadata:Dictionary.
## [br]
## @return 候选有效并成功写入时返回 true。
func register_candidate(candidate: Object, options: Dictionary = {}) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false

	var candidate_id: int = candidate.get_instance_id()
	var existing_order: int = _get_existing_order(candidate_id)
	var order: int = existing_order
	if order < 0:
		_serial += 1
		order = _serial
		_order.append(candidate_id)

	_records[candidate_id] = {
		"id": candidate_id,
		"ref": weakref(candidate),
		"priority": GFVariantData.get_option_int(options, "priority", 0),
		"group": GFVariantData.get_option_string_name(options, "group", &""),
		"owner_id": _get_owner_id(GFVariantData.get_option_value(options, "owner", 0)),
		"stable_key": GFVariantData.duplicate_variant(GFVariantData.get_option_value(options, "stable_key", candidate_id)),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata").duplicate(true),
		"order": order,
	}
	_prune_for_capacity()
	return true


## 移除一个候选对象。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate: 候选对象。
## [br]
## @return 找到并移除时返回 true。
func unregister_candidate(candidate: Object) -> bool:
	if candidate == null:
		return false
	return unregister_candidate_id(candidate.get_instance_id())


## 按实例 ID 移除候选。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate_id: 候选对象实例 ID。
## [br]
## @return 找到并移除时返回 true。
func unregister_candidate_id(candidate_id: int) -> bool:
	if not _records.has(candidate_id):
		return false
	var removed: bool = _records.erase(candidate_id)
	_remove_order_id(candidate_id)
	return removed


## 移除指定 owner 关联的候选。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: Object、实例 ID 或文本 owner key。
## [br]
## @schema owner: Object, int, String, or StringName owner identity.
## [br]
## @return 移除数量。
func unregister_owner(owner: Variant) -> int:
	var owner_id: int = _get_owner_id(owner)
	if owner_id == 0:
		return 0
	var removed_count: int = 0
	for candidate_id: int in _order.duplicate():
		var record: Dictionary = _get_record(candidate_id)
		if GFVariantData.get_option_int(record, "owner_id", 0) != owner_id:
			continue
		if unregister_candidate_id(candidate_id):
			removed_count += 1
	return removed_count


## 清理已释放对象的候选记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 清理数量。
func prune_invalid() -> int:
	var removed_count: int = 0
	for candidate_id: int in _order.duplicate():
		if _get_record_object(_get_record(candidate_id)) != null:
			continue
		if unregister_candidate_id(candidate_id):
			removed_count += 1
	return removed_count


## 获取候选记录快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 查询选项。
## [br]
## @schema options: Dictionary with optional group:StringName, method_name:StringName, include_metadata:bool, max_count:int, and prune_invalid:bool.
## [br]
## @return 候选记录数组，按 priority 降序、注册顺序升序排列。
## [br]
## @schema return: Array[Dictionary] with id, object, priority, group, owner_id, stable_key, metadata, and order.
func get_candidates(options: Dictionary = {}) -> Array[Dictionary]:
	if GFVariantData.get_option_bool(options, "prune_invalid", true):
		var _pruned_count: int = prune_invalid()

	var group_filter: StringName = GFVariantData.get_option_string_name(options, "group", &"")
	var method_name: StringName = GFVariantData.get_option_string_name(options, "method_name", &"")
	var include_metadata: bool = GFVariantData.get_option_bool(options, "include_metadata", true)
	var max_count: int = GFVariantData.get_option_int(options, "max_count", 0)
	var result: Array[Dictionary] = []
	for candidate_id: int in _order:
		var record: Dictionary = _get_record(candidate_id)
		if record.is_empty():
			continue
		var candidate: Object = _get_record_object(record)
		if candidate == null:
			continue
		if group_filter != &"" and GFVariantData.get_option_string_name(record, "group", &"") != group_filter:
			continue
		if method_name != &"" and not candidate.has_method(method_name):
			continue
		result.append(_make_candidate_snapshot(record, candidate, include_metadata))
	result.sort_custom(_sort_candidate_snapshots)
	if max_count > 0 and result.size() > max_count:
		result = result.slice(0, max_count)
	return result


## 获取候选对象列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 查询选项，语义同 get_candidates()。
## [br]
## @schema options: Dictionary with optional group:StringName, method_name:StringName, and max_count:int.
## [br]
## @return 候选对象数组。
## [br]
## @schema return: Array[Object] from valid candidate snapshots.
func get_candidate_objects(options: Dictionary = {}) -> Array[Object]:
	var result: Array[Object] = []
	for snapshot: Dictionary in get_candidates(options):
		var object_value: Variant = GFVariantData.get_option_value(snapshot, "object")
		if object_value is Object:
			var object_candidate: Object = object_value
			result.append(object_candidate)
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return JSON-safe 调试快照。
## [br]
## @schema return: Dictionary with count, valid_count, max_candidates, candidates, and metadata.
func get_debug_snapshot() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for snapshot: Dictionary in get_candidates({ "include_metadata": true }):
		var candidate_copy: Dictionary = snapshot.duplicate(true)
		candidate_copy["object"] = GFReportValueCodec.to_json_compatible(GFVariantData.get_option_value(snapshot, "object"), {
			"redaction_profile": GFReportValueCodec.REDACTION_PROFILE_SUPPORT,
		})
		candidates.append(candidate_copy)
	return {
		"count": _records.size(),
		"valid_count": candidates.size(),
		"max_candidates": max_candidates,
		"candidates": candidates,
		"metadata": GFReportValueCodec.to_report_dictionary(metadata, {
			"redaction_profile": GFReportValueCodec.REDACTION_PROFILE_SUPPORT,
		}),
	}


# --- 私有/辅助方法 ---

func _get_existing_order(candidate_id: int) -> int:
	var record: Dictionary = _get_record(candidate_id)
	return GFVariantData.get_option_int(record, "order", -1)


func _get_record(candidate_id: int) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_records, candidate_id, {}))


func _get_record_object(record: Dictionary) -> Object:
	var ref_value: Variant = GFVariantData.get_option_value(record, "ref")
	if not (ref_value is WeakRef):
		return null
	var object_ref: WeakRef = ref_value
	var object_value: Variant = object_ref.get_ref()
	if object_value is Object:
		var object_candidate: Object = object_value
		if is_instance_valid(object_candidate):
			return object_candidate
	return null


func _make_candidate_snapshot(record: Dictionary, candidate: Object, include_metadata: bool) -> Dictionary:
	var snapshot: Dictionary = {
		"id": GFVariantData.get_option_int(record, "id", 0),
		"object": candidate,
		"priority": GFVariantData.get_option_int(record, "priority", 0),
		"group": GFVariantData.get_option_string_name(record, "group", &""),
		"owner_id": GFVariantData.get_option_int(record, "owner_id", 0),
		"stable_key": GFVariantData.duplicate_variant(GFVariantData.get_option_value(record, "stable_key")),
		"order": GFVariantData.get_option_int(record, "order", 0),
	}
	if include_metadata:
		snapshot["metadata"] = GFVariantData.get_option_dictionary(record, "metadata").duplicate(true)
	return snapshot


func _prune_for_capacity() -> void:
	if max_candidates <= 0:
		return
	while _records.size() > max_candidates and not _order.is_empty():
		var candidate_id: int = _order[0]
		_order.remove_at(0)
		var _removed: bool = _records.erase(candidate_id)


func _remove_order_id(candidate_id: int) -> void:
	for index: int in range(_order.size() - 1, -1, -1):
		if _order[index] == candidate_id:
			_order.remove_at(index)


static func _sort_candidate_snapshots(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = GFVariantData.get_option_int(left, "priority", 0)
	var right_priority: int = GFVariantData.get_option_int(right, "priority", 0)
	if left_priority != right_priority:
		return left_priority > right_priority
	var left_order: int = GFVariantData.get_option_int(left, "order", 0)
	var right_order: int = GFVariantData.get_option_int(right, "order", 0)
	return left_order < right_order


static func _get_owner_id(owner: Variant) -> int:
	if owner is Object:
		var owner_object: Object = owner
		if is_instance_valid(owner_object):
			return owner_object.get_instance_id()
	if owner is int:
		var owner_int: int = owner
		return maxi(owner_int, 0)
	if owner is String or owner is StringName:
		var owner_text: String = GFVariantData.to_text(owner).strip_edges()
		if owner_text.is_empty():
			return 0
		return owner_text.hash()
	return 0
