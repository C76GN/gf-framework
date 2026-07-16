## GFRefCountedPool: 通用 RefCounted 对象池。
##
## 用工厂 Callable 创建短生命周期 RefCounted 对象，并在归还时通过 hook 或
## reset_callback 显式清理状态。它不管理 Node、场景树、资源加载或业务生命周期。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.20.0
class_name GFRefCountedPool
extends RefCounted


# --- 常量 ---

## 对象可选实现：从池中取出后调用。
## [br]
## @api public
const HOOK_ON_ACQUIRE: StringName = &"on_gf_pool_acquire"

## 对象可选实现：归还池时调用。
## [br]
## @api public
const HOOK_ON_RELEASE: StringName = &"on_gf_pool_release"

## 对象可选实现：归还池时用于清理可复用状态。
## [br]
## @api public
const HOOK_RESET: StringName = &"reset_for_pool"


# --- 公共变量 ---

## 对象工厂。必须返回 RefCounted。
## [br]
## @api public
var factory: Callable = Callable()

## 归还对象时执行的可选重置回调。回调收到被归还的对象。
## [br]
## @api public
var reset_callback: Callable = Callable()

## 最多保留的可用对象数量。为 0 时不限制。
## [br]
## @api public
var max_available: int:
	get:
		return _max_available
	set(value):
		_max_available = maxi(value, 0)
		_trim_available()

## 池累计创建对象数量。
## [br]
## @api public
var created_count: int:
	get:
		return _created_count

## 当前可用对象数量。
## [br]
## @api public
var available_count: int:
	get:
		return _available.size()

## 当前借出对象数量。
## [br]
## @api public
var active_count: int:
	get:
		return _active_ids.size()


# --- 私有变量 ---

var _available: Array[RefCounted] = []
var _active_ids: Dictionary = {}
var _created_count: int = 0
var _max_available: int = 0


# --- Godot 生命周期方法 ---

func _init(p_factory: Callable = Callable(), p_reset_callback: Callable = Callable()) -> void:
	factory = p_factory
	reset_callback = p_reset_callback


# --- 公共方法 ---

## 配置对象池并返回自身。
## [br]
## @api public
## [br]
## @param p_factory: 对象工厂，必须返回 RefCounted。
## [br]
## @param p_reset_callback: 归还对象时执行的可选重置回调。
## [br]
## @param p_max_available: 最多保留的可用对象数量；0 表示不限制。
## [br]
## @return 当前对象池。
func configure(
	p_factory: Callable,
	p_reset_callback: Callable = Callable(),
	p_max_available: int = 0
) -> GFRefCountedPool:
	factory = p_factory
	reset_callback = p_reset_callback
	max_available = p_max_available
	return self


## 从池中借出对象。
## [br]
## @api public
## [br]
## @return 借出的 RefCounted；工厂无效或返回非 RefCounted 时返回 null。
func acquire() -> RefCounted:
	var item: RefCounted = null
	while not _available.is_empty() and item == null:
		item = _available.pop_back()
		if _is_active_item(item):
			push_error("[GFRefCountedPool] acquire 失败：可用池中存在已借出对象，已丢弃该重复引用。")
			item = null

	if item == null:
		item = _create_item()
		if item == null:
			return null
		if _is_active_item(item) or _available_has_item(item):
			push_error("[GFRefCountedPool] acquire 失败：factory 返回了已被当前池追踪的对象，已拒绝重复借出。")
			return null
		_created_count += 1

	_active_ids[item.get_instance_id()] = true
	_call_optional_hook(item, HOOK_ON_ACQUIRE)
	return item


## 归还对象。
## [br]
## @api public
## [br]
## @param item: 通过当前对象池借出的 RefCounted。
## [br]
## @return 成功归还或因容量上限丢弃时返回 true。
func release(item: RefCounted) -> bool:
	if item == null:
		return false

	var item_id: int = item.get_instance_id()
	if not _active_ids.has(item_id):
		push_warning("[GFRefCountedPool] release 收到未由当前池借出的对象，已忽略。")
		return false

	var _erase_result_152: Variant = _active_ids.erase(item_id)
	_prepare_item_for_reuse(item)
	if max_available > 0 and _available.size() >= max_available:
		return true

	_available.push_back(item)
	return true


## 预热对象池。
## [br]
## @api public
## [br]
## @param count: 要创建并保留的可用对象数量。
## [br]
## @return 实际新增到可用池的数量。
func prewarm(count: int) -> int:
	var created: int = 0
	for _index: int in range(maxi(count, 0)):
		if max_available > 0 and _available.size() >= max_available:
			break
		var item: RefCounted = _create_item()
		if item == null:
			break
		if _is_active_item(item) or _available_has_item(item):
			push_error("[GFRefCountedPool] prewarm 失败：factory 返回了已被当前池追踪的对象，已停止预热。")
			break
		_created_count += 1
		_prepare_item_for_reuse(item)
		_available.push_back(item)
		created += 1
	return created


## 清空当前可用对象，不影响已经借出的对象。
## [br]
## @api public
func clear_available() -> void:
	_available.clear()


## 忘记借出记录并清空可用池。
##
## 这不会强制回收外部仍持有的 RefCounted，只让当前池停止追踪它们。
## [br]
## @api public
func reset_pool() -> void:
	_available.clear()
	_active_ids.clear()


## 检查对象是否由当前池借出且尚未归还。
## [br]
## @api public
## [br]
## @param item: 要检查的对象。
## [br]
## @return 对象处于借出状态时返回 true。
func is_active(item: RefCounted) -> bool:
	return item != null and _active_ids.has(item.get_instance_id())


## 获取对象池调试快照。
## [br]
## @api public
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 created_count、available_count、active_count 与 max_available。
func get_debug_snapshot() -> Dictionary:
	return {
		"created_count": created_count,
		"available_count": available_count,
		"active_count": active_count,
		"max_available": max_available,
	}


# --- 私有/辅助方法 ---

func _create_item() -> RefCounted:
	if not factory.is_valid():
		push_error("[GFRefCountedPool] factory 无效，无法创建对象。")
		return null

	var value: Variant = factory.call()
	if value is RefCounted:
		var item: RefCounted = value
		return item

	push_error("[GFRefCountedPool] factory 必须返回 RefCounted。")
	return null


func _is_active_item(item: RefCounted) -> bool:
	return item != null and _active_ids.has(item.get_instance_id())


func _available_has_item(item: RefCounted) -> bool:
	if item == null:
		return false
	var item_id: int = item.get_instance_id()
	for available_item: RefCounted in _available:
		if available_item != null and available_item.get_instance_id() == item_id:
			return true
	return false


func _prepare_item_for_reuse(item: RefCounted) -> void:
	_call_optional_hook(item, HOOK_ON_RELEASE)
	if reset_callback.is_valid():
		reset_callback.call(item)
	_call_optional_hook(item, HOOK_RESET)


func _call_optional_hook(item: RefCounted, hook_name: StringName) -> void:
	if item.has_method(hook_name):
		item.call(hook_name)


func _trim_available() -> void:
	if max_available <= 0:
		return
	while _available.size() > max_available:
		_available.pop_back()
