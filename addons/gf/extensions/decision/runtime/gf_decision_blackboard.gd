## GFDecisionBlackboard: 通用决策黑板。
##
## 保存一组由项目定义的运行时值，用于 Utility AI、导演系统或其他决策流程读取。
## 它只管理键值、变更信号和调试快照，不规定任何玩法字段。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 4.3.0
class_name GFDecisionBlackboard
extends RefCounted


# --- 信号 ---

## 当黑板值发生变化时发出。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param old_value: 旧值。
## [br]
## @schema old_value: 黑板中的任意项目值；之前不存在时为 null。
## [br]
## @param new_value: 新值。
## [br]
## @schema new_value: 黑板中的任意项目值。
signal value_changed(key: StringName, old_value: Variant, new_value: Variant)

## 当黑板值被移除时发出。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param old_value: 被移除的旧值。
## [br]
## @schema old_value: 黑板中的任意项目值。
signal value_removed(key: StringName, old_value: Variant)


# --- 公共变量 ---

## 黑板值表。键通常为 StringName，值由项目决定。
## [br]
## @api public
## [br]
## @schema values: Dictionary[StringName, Variant] project-defined decision values.
var values: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(initial_values: Dictionary = {}) -> void:
	merge(initial_values)


# --- 公共方法 ---

## 设置黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param value: 要写入或修改的值。
## [br]
## @schema value: 要写入黑板的任意项目值。
func set_value(key: StringName, value: Variant) -> void:
	if key == &"":
		return

	var old_value: Variant = get_value(key)
	if values.has(key) and old_value == value:
		return

	values[key] = value
	value_changed.emit(key, old_value, value)


## 获取黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @return: 黑板值或默认值。
## [br]
## @schema default_value: 黑板缺失时返回的任意默认值。
## [br]
## @schema return: 黑板中的项目值，或传入的 default_value。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(values, key, default_value)


## 检查黑板值是否存在。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @return: 存在返回 true。
func has_value(key: StringName) -> bool:
	return values.has(key) or values.has(String(key))


## 移除黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @return: 移除成功返回 true。
func erase_value(key: StringName) -> bool:
	if not has_value(key):
		return false

	var old_value: Variant = get_value(key)
	if values.has(key):
		var _erase_string_name_result: Variant = values.erase(key)
	else:
		var _erase_string_result: Variant = values.erase(String(key))
	value_removed.emit(key, old_value)
	return true


## 清空全部黑板值。
## [br]
## @api public
func clear() -> void:
	var keys: Array = values.keys()
	for key_variant: Variant in keys:
		var _erase_result: Variant = erase_value(GFVariantData.to_string_name(key_variant))


## 合并一批黑板值。
## [br]
## @api public
## [br]
## @param source_values: 要合并的值表。
## [br]
## @param overwrite: 已存在同名键时是否覆盖。
## [br]
## @schema source_values: Dictionary[StringName, Variant] project-defined decision values.
func merge(source_values: Dictionary, overwrite: bool = true) -> void:
	for key_variant: Variant in source_values.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key == &"":
			continue
		if not overwrite and has_value(key):
			continue
		set_value(key, source_values[key_variant])


## 转换为值表副本。
## [br]
## @api public
## [br]
## @return: 黑板值表副本。
## [br]
## @schema return: Dictionary[StringName, Variant] project-defined decision values.
func to_dictionary() -> Dictionary:
	return values.duplicate(true)


## 创建黑板副本。
## [br]
## @api public
## [br]
## @return: 新黑板实例。
func duplicate_blackboard() -> GFDecisionBlackboard:
	return GFDecisionBlackboard.new(to_dictionary())


## 获取调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 value_count、keys 和 values 字段的 Dictionary。
func get_debug_snapshot() -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	for key_variant: Variant in values.keys():
		var _append_result: Variant = keys.append(GFVariantData.to_text(key_variant))
	keys.sort()
	return {
		"value_count": values.size(),
		"keys": keys,
		"values": to_dictionary(),
	}
