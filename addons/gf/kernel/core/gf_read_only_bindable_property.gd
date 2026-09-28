## GFReadOnlyBindableProperty: 只读响应式属性视图。
##
## 复用 `GFBindableProperty` 的读取、信号和生命周期绑定能力，
## 但阻止外部直接调用 `set_value()` 修改底层值。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFReadOnlyBindableProperty
extends GFBindableProperty


# --- 常量 ---

## 只读视图被调用写入接口时发出的错误文本。
## [br]
## @api private
const _READ_ONLY_ERROR: String = "[GFReadOnlyBindableProperty][read_only_bindable_property.read_only] This property is a read-only view; modify its value through the owning object."

## 深拷贝 Array 与 Dictionary 读取结果的 Variant 辅助脚本。
## [br]
## @api private
const _READ_ONLY_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param default_value: 属性的初始值。
## [br]
## @schema default_value: {"type": "Variant", "description": "属性的初始值。"}
func _init(default_value: Variant = null) -> void:
	super._init(default_value)


# --- 公共方法 ---

## 读取只读视图的当前值。
## Array 与 Dictionary 会返回深拷贝，避免调用方通过集合引用绕过只读约束。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 当前值；集合类型返回副本。
## [br]
## @schema return: Variant current read-only value; Array and Dictionary values are returned as deep copies.
func get_value() -> Variant:
	return _READ_ONLY_VARIANT_ACCESS_SCRIPT.duplicate_collection(super.get_value(), true)


## 只读视图不允许外部直接写入值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _new_value: 调用方尝试写入的新值。
## [br]
## @schema _new_value: {"type": "Variant", "description": "调用方尝试写入的新值。"}
func set_value(_new_value: Variant) -> void:
	push_error(_READ_ONLY_ERROR)


## 只读视图不允许外部原地修改值。
## [br]
## @api public
## [br]
## @param _mutator: 调用方尝试执行的修改回调。
## [br]
## @return 始终返回 false。
func mutate(_mutator: Callable) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读视图不允许外部向数组追加元素。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _item: 调用方尝试追加的元素。
## [br]
## @return 始终返回 false。
## [br]
## @schema _item: {"type": "Variant", "description": "调用方尝试追加的元素。"}
func append_to_array(_item: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读视图不允许外部向数组追加元素列表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _items: 调用方尝试追加的元素列表。
## [br]
## @return 始终返回 false。
## [br]
## @schema _items: {"type": "Array", "description": "调用方尝试追加的元素列表。"}
func append_array(_items: Array) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读视图不允许外部从数组删除元素。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _item: 调用方尝试删除的元素。
## [br]
## @return 始终返回 false。
## [br]
## @schema _item: {"type": "Variant", "description": "调用方尝试删除的元素。"}
func erase_from_array(_item: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读视图不允许外部设置字典键值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _key: 调用方尝试设置的键。
## [br]
## @param _new_value: 调用方尝试设置的新值。
## [br]
## @return 始终返回 false。
## [br]
## @schema _key: {"type": "Variant", "description": "调用方尝试设置的键。"}
## [br]
## @schema _new_value: {"type": "Variant", "description": "调用方尝试设置的新值。"}
func set_dictionary_value(_key: Variant, _new_value: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读视图不允许外部删除字典键。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _key: 调用方尝试删除的键。
## [br]
## @return 始终返回 false。
## [br]
## @schema _key: {"type": "Variant", "description": "调用方尝试删除的键。"}
func erase_dictionary_key(_key: Variant) -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


## 只读视图不允许外部清空集合。
## [br]
## @api public
## [br]
## @return 始终返回 false。
func clear_collection() -> bool:
	push_error(_READ_ONLY_ERROR)
	return false


# --- 框架内部方法 ---

## 供持有该只读视图的框架对象更新底层值，沿用基类的变化通知；此入口不执行调用者身份校验。
## [br]
## @api framework_internal
## [br]
## @param new_value: 所有者计算出的新值。
## [br]
## @schema new_value: {"type":"Variant","description":"类型由创建该属性的框架对象约定，按基类 set_value 语义写入。"}
func _set_value_from_owner(new_value: Variant) -> void:
	super.set_value(new_value)
