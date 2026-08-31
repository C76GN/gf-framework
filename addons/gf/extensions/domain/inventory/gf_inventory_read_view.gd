## GFInventoryReadView: 槽位接收回调的临时只读库存投影。
##
## 库存模型与原子转移规划器会为每次槽位接收检查创建此视图。查询反映
## 当前逐步候选，因而后续槽位可观察此前写入；视图不暴露可变库存引用。
## 回调返回后视图立即失效，项目不得跨回调保存并依赖它。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFInventoryReadView
extends RefCounted


# --- 私有变量 ---

var _candidate_slots: Array = []
var _registry: GFInventoryItemRegistry = null
var _active: bool = false


# --- 公共方法 ---

## 检查视图是否仍处于当前同步接收回调内。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 仍可查询时返回 true；回调返回后为 false。
func is_active() -> bool:
	return _active


## 获取候选槽位数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 当前候选槽位数量；失效后返回 0。
func get_slot_count() -> int:
	return _candidate_slots.size() if _active else 0


## 检查候选槽位索引是否有效。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 视图有效且索引存在时返回 true。
func is_valid_slot(slot_index: int) -> bool:
	return _active and slot_index >= 0 and slot_index < _candidate_slots.size()


## 获取候选堆叠的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 候选堆叠副本；空槽、无效索引或失效视图返回 null。
func get_stack(slot_index: int) -> GFInventoryStack:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	return stack.duplicate_stack() if stack != null else null


## 获取候选堆叠字典快照。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 候选堆叠字典；空槽、无效索引或失效视图返回空字典。
## [br]
## @schema return: Dictionary，包含 item_id、amount 与 instance_data。
func get_stack_data(slot_index: int) -> Dictionary:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	return stack.to_dict() if stack != null else {}


## 检查候选槽位是否为空。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 空槽返回 true；无效索引或失效视图也返回 true。
func is_slot_empty(slot_index: int) -> bool:
	return _get_stack_ref(slot_index) == null


## 获取候选中指定物品总数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 可选实例数据过滤条件；空字典匹配全部同 ID 堆叠。
## [br]
## @return: 候选总数量；失效视图返回 0。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据。
func get_item_total(item_id: StringName, instance_data: Dictionary = {}) -> int:
	if not _active or item_id == &"":
		return 0
	var filter_by_instance: bool = not instance_data.is_empty()
	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	var total: int = 0
	for stack_value: Variant in _candidate_slots:
		var stack: GFInventoryStack = _get_stack_value(stack_value)
		if stack == null or stack.item_id != item_id:
			continue
		if filter_by_instance and not stack.can_merge(item_id, normalized_data, _registry):
			continue
		total += stack.amount
	return total


## 检查候选中是否拥有足够数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param item_id: 物品标识。
## [br]
## @param amount: 需要数量。
## [br]
## @param instance_data: 可选实例数据过滤条件。
## [br]
## @return: 数量足够返回 true。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据。
func has_item(
	item_id: StringName,
	amount: int = 1,
	instance_data: Dictionary = {}
) -> bool:
	return get_item_total(item_id, instance_data) >= amount


## 获取候选空槽位索引。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 空槽位索引；失效视图返回空数组。
func get_empty_slot_indices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if not _active:
		return result
	for slot_index: int in range(_candidate_slots.size()):
		if _get_stack_ref(slot_index) == null:
			_append_slot_index(result, slot_index)
	return result


## 获取候选已占用槽位索引。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 已占用槽位索引；失效视图返回空数组。
func get_occupied_slot_indices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if not _active:
		return result
	for slot_index: int in range(_candidate_slots.size()):
		if _get_stack_ref(slot_index) != null:
			_append_slot_index(result, slot_index)
	return result


## 获取候选中指定物品所在槽位。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 可选实例数据过滤条件；空字典匹配全部同 ID 堆叠。
## [br]
## @return: 匹配槽位索引；失效视图返回空数组。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据。
func get_slots_for_item(
	item_id: StringName,
	instance_data: Dictionary = {}
) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if not _active or item_id == &"":
		return result
	var filter_by_instance: bool = not instance_data.is_empty()
	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	for slot_index: int in range(_candidate_slots.size()):
		var stack: GFInventoryStack = _get_stack_ref(slot_index)
		if stack == null or stack.item_id != item_id:
			continue
		if filter_by_instance and not stack.can_merge(item_id, normalized_data, _registry):
			continue
		_append_slot_index(result, slot_index)
	return result


# --- 框架内部方法 ---

## 绑定当前同步规划候选。仅规划器可调用。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param candidate_slots: 已有界隔离的候选槽位数组。
## [br]
## @param registry: 当前库存注册表；只用于只读实例兼容性查询。
## [br]
## @return: 首次有效绑定返回 true。
## [br]
## @schema candidate_slots: Internal bounded candidate slots owned by the transfer planner.
func configure_for_framework(
	candidate_slots: Array,
	registry: GFInventoryItemRegistry
) -> bool:
	if _active or candidate_slots.is_empty():
		return false
	_candidate_slots = candidate_slots
	_registry = registry
	_active = true
	return true


## 使视图失效并释放所有候选与配置引用。仅规划器可调用。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
func invalidate_for_framework() -> void:
	_active = false
	_candidate_slots = []
	_registry = null


# --- 私有/辅助方法 ---

func _get_stack_ref(slot_index: int) -> GFInventoryStack:
	if not is_valid_slot(slot_index):
		return null
	return _get_stack_value(_candidate_slots[slot_index])


func _normalize_instance_data(item_id: StringName, instance_data: Dictionary) -> Dictionary:
	if _registry == null:
		return instance_data.duplicate(true)
	return _registry.normalize_instance_data(item_id, instance_data)


static func _get_stack_value(value: Variant) -> GFInventoryStack:
	if value is GFInventoryStack:
		var stack: GFInventoryStack = value
		return stack
	return null


static func _append_slot_index(target: PackedInt32Array, slot_index: int) -> void:
	var _appended: bool = target.append(slot_index)
