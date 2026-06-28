## GFFormulaParameter: 通用公式运行时参数容器。
##
## 用于把施放者、目标、上下文对象和临时数值传给资源化公式。
## 它不规定任何业务字段，项目可通过 `set_value()` 写入自己的参数。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFFormulaParameter
extends RefCounted


# --- 公共变量 ---

## 公式发起者，例如攻击者、购买者、升级主体等。
## [br]
## @api public
var source: Object = null

## 公式目标，例如受击者、被购买对象、被升级对象等。
## [br]
## @api public
var target: Object = null

## 可选上下文对象，通常是系统、规则宿主或临时流程上下文。
## [br]
## @api public
var context: Object = null

## 额外参数表。Key 推荐使用 StringName。
## [br]
## @api public
## [br]
## @schema values: Dictionary keyed by StringName or String with caller-defined formula values.
var values: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_source: Object = null,
	p_target: Object = null,
	p_values: Dictionary = {},
	p_context: Object = null
) -> void:
	source = p_source
	target = p_target
	context = p_context
	values = GFVariantData.duplicate_variant(p_values)


# --- 公共方法 ---

## 写入一个参数值。
## [br]
## @api public
## [br]
## @param key: 参数键。
## [br]
## @param value: 参数值。
## [br]
## @schema value: Variant caller-defined formula value.
## [br]
## @return 当前参数容器，便于链式构造。
func set_value(key: StringName, value: Variant) -> GFFormulaParameter:
	values[key] = GFVariantData.duplicate_variant(value)
	return self


## 读取一个参数值。
## [br]
## @api public
## [br]
## @param key: 参数键。
## [br]
## @param default_value: 参数不存在时返回的默认值。
## [br]
## @schema default_value: Variant fallback value returned when key is absent.
## [br]
## @return 参数值或默认值。
## [br]
## @schema return: Variant formula value or fallback.
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.duplicate_variant(GFVariantData.get_option_value(values, key, default_value))


## 检查是否存在指定参数。
## [br]
## @api public
## [br]
## @param key: 参数键。
## [br]
## @return 存在时返回 true。
func has_value(key: StringName) -> bool:
	return values.has(key)


## 创建当前参数容器的深拷贝。
## [br]
## @api public
## [br]
## @return 新的参数容器实例。
func duplicate_parameter() -> GFFormulaParameter:
	return GFFormulaParameter.new(source, target, values, context)
