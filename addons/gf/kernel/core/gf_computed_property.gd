## GFComputedProperty: 由多个 GFBindableProperty 派生的只读响应式属性。
##
## 通过 compute 回调计算自身值，并在任一来源属性变化时自动刷新。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFComputedProperty
extends GFBindableProperty


# --- 常量 ---

const _READ_ONLY_ERROR: String = "[GFComputedProperty] 当前属性由 compute 回调派生，请修改来源属性。"
const _COMPUTED_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _effect: GFReactiveEffect = null


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @param sources: 要监听的 GFBindableProperty 列表。
## [br]
## @param compute: 用于计算当前值的回调。
## [br]
## @param default_value: 初始默认值。
## [br]
## @param owner: 可选 Node 生命周期宿主。
## [br]
## @schema default_value {
##   "type": "Variant",
##   "description": "初始默认值。"
## }
func _init(
	sources: Array[GFBindableProperty] = [],
	compute: Callable = Callable(),
	default_value: Variant = null,
	owner: Node = null
) -> void:
	super._init(default_value)
	if not sources.is_empty() or compute.is_valid():
		bind_sources(sources, compute, owner)


# --- 公共方法 ---

## 读取派生属性的当前值。
## Array 与 Dictionary 会返回深拷贝，避免调用方通过集合引用绕过只读约束。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 当前值；集合类型返回副本。
## [br]
## @schema return: Variant current computed value; Array and Dictionary values are returned as deep copies.
func get_value() -> Variant:
	return _COMPUTED_VARIANT_ACCESS_SCRIPT.duplicate_collection(super.get_value(), true)


## 绑定来源属性与计算回调。重复调用会替换旧绑定。
## [br]
## @api public
## [br]
## @param sources: 要监听的 GFBindableProperty 列表。
## [br]
## @param compute: 用于计算当前值的回调。
## [br]
## @param owner: 可选 Node 生命周期宿主。
## [br]
## @param run_immediately: 是否立即计算一次。
func bind_sources(
	sources: Array[GFBindableProperty],
	compute: Callable,
	owner: Node = null,
	run_immediately: bool = true
) -> void:
	stop()
	if not compute.is_valid():
		return

	_effect = GFReactiveEffect.new(
		sources,
		func() -> Variant:
			var next_value: Variant = compute.call()
			_set_value_from_compute(next_value)
			return next_value,
		owner,
		run_immediately
	)


## 停止自动刷新。
## [br]
## @api public
func stop() -> void:
	if _effect != null:
		_effect.stop()
		_effect = null


## 释放派生属性持有的监听。
## [br]
## @api public
func dispose() -> void:
	stop()


## 只读派生属性不允许外部直接写入值。
## [br]
## @api public
## [br]
## @param _new_value: 调用方尝试写入的新值。
## [br]
## @schema _new_value {
##   "type": "Variant",
##   "description": "调用方尝试写入的新值。"
## }
func set_value(_new_value: Variant) -> void:
	push_error(_READ_ONLY_ERROR)


## 只读派生属性不允许外部原地修改值。
## [br]
## @api public
## [br]
## @param _mutator: 调用方尝试执行的修改回调。
## [br]
## @return 始终返回 false。
func mutate(_mutator: Callable) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读派生属性不允许外部向数组追加元素。
## [br]
## @api public
## [br]
## @param _item: 调用方尝试追加的元素。
## [br]
## @return 始终返回 false。
## [br]
## @schema _item {
##   "type": "Variant",
##   "description": "调用方尝试追加的元素。"
## }
func append_to_array(_item: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读派生属性不允许外部向数组追加元素列表。
## [br]
## @api public
## [br]
## @param _items: 调用方尝试追加的元素列表。
## [br]
## @return 始终返回 false。
## [br]
## @schema _items {
##   "type": "Array",
##   "description": "调用方尝试追加的元素列表。"
## }
func append_array(_items: Array) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读派生属性不允许外部从数组删除元素。
## [br]
## @api public
## [br]
## @param _item: 调用方尝试删除的元素。
## [br]
## @return 始终返回 false。
## [br]
## @schema _item {
##   "type": "Variant",
##   "description": "调用方尝试删除的元素。"
## }
func erase_from_array(_item: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读派生属性不允许外部设置字典键值。
## [br]
## @api public
## [br]
## @param _key: 调用方尝试设置的键。
## [br]
## @param _new_value: 调用方尝试设置的新值。
## [br]
## @return 始终返回 false。
## [br]
## @schema _key {
##   "type": "Variant",
##   "description": "调用方尝试设置的键。"
## }
## [br]
## @schema _new_value {
##   "type": "Variant",
##   "description": "调用方尝试设置的新值。"
## }
func set_dictionary_value(_key: Variant, _new_value: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读派生属性不允许外部删除字典键。
## [br]
## @api public
## [br]
## @param _key: 调用方尝试删除的键。
## [br]
## @return 始终返回 false。
## [br]
## @schema _key {
##   "type": "Variant",
##   "description": "调用方尝试删除的键。"
## }
func erase_dictionary_key(_key: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读派生属性不允许外部清空集合。
## [br]
## @api public
## [br]
## @return 始终返回 false。
func clear_collection() -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 获取内部 effect 是否激活。
## [br]
## @api public
## [br]
## @return 激活时返回 true。
func is_computing() -> bool:
	return _effect != null and _effect.is_active()


# --- 私有/辅助方法 ---

func _set_value_from_compute(new_value: Variant) -> void:
	super.set_value(new_value)
