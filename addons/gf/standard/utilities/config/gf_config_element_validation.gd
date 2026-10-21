@tool

## GFConfigElementValidation: 顶层与嵌套旧 Array 字段共用的准入和计数。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFConfigElementValidation
extends RefCounted


# --- 常量 ---

## 内部选项中的共享会话键。
## [br]
## @api framework_internal
const SESSION_KEY: StringName = &"__gf_config_element_validation_session"

## 一次验证最多接纳的数组元素数。
## [br]
## @api framework_internal
const MAX_ELEMENTS: int = 65536

## 一次验证最多执行的元素与规则组合数。
## [br]
## @api framework_internal
const MAX_RULE_CHECKS: int = 262144

## 单字段最多声明的逐元素规则数。
## [br]
## @api framework_internal
const MAX_RULES_PER_COLUMN: int = 64


# --- 私有变量 ---

## 仅在字段整批获准后扣减的剩余元素数。
## [br]
## @api private
var _remaining_elements: int

## 与元素数共同准入的剩余规则调用次数。
## [br]
## @api private
var _remaining_checks: int


# --- Godot 生命周期方法 ---

## 绑定调用方已验证的有限容量，不读取配置数据。
## [br]
## @api framework_internal
## [br]
## @param element_limit: 一次验证的元素数量上限。
## [br]
## @param check_limit: 一次验证的元素与规则组合数量上限。
func _init(element_limit: int = MAX_ELEMENTS, check_limit: int = MAX_RULE_CHECKS) -> void:
	_remaining_elements = element_limit
	_remaining_checks = check_limit


# --- 框架内部方法 ---

## 复用显式会话；缺失时按指定限额建立一次验证的计数器。
## [br]
## @api framework_internal
## [br]
## @param options: 当前验证选项。
## [br]
## @param element_limit: 新会话的元素数上限。
## [br]
## @param check_limit: 新会话的规则调用数上限。
## [br]
## @return 当前验证会话，不重置已有计数。
## [br]
## @schema options: Dictionary，SESSION_KEY 可指向当前 GFConfigElementValidation。
static func from_options(
	options: Dictionary,
	element_limit: int = MAX_ELEMENTS,
	check_limit: int = MAX_RULE_CHECKS
) -> GFConfigElementValidation:
	var supplied: Variant = options.get(SESSION_KEY)
	if supplied is GFConfigElementValidation:
		return supplied
	return GFConfigElementValidation.new(element_limit, check_limit)


## 按既有顺序检查适用类型、数量和空规则，返回首个错误。
## [br]
## @api framework_internal
## [br]
## @param value_type: 字段的旧 ValueType。
## [br]
## @param rules: 保持作者顺序的逐元素规则。
## [br]
## @return 无错误时为空字典，否则包含稳定 kind 和 message。
## [br]
## @schema return: Dictionary，空字典或包含 kind、message 的单条定义问题。
static func get_definition_issue(value_type: int, rules: Array[GFConfigValidationRule]) -> Dictionary:
	if rules.is_empty():
		return {}
	if value_type != GFConfigTableColumn.ValueType.ARRAY:
		return { "kind": "element_rules_require_array", "message": "元素规则仅允许声明在 Array 字段上。" }
	if rules.size() > MAX_RULES_PER_COLUMN:
		return { "kind": "element_validation_rule_limit_exceeded", "message": "单列元素规则不能超过 64 条。" }
	for rule: GFConfigValidationRule in rules:
		if rule == null:
			return { "kind": "null_element_validation_rule", "message": "元素校验规则为空。" }
	return {}


## 保留既有单层值白名单，拒绝集合、对象、可执行引用和 packed 数组。
## [br]
## @api framework_internal
## [br]
## @param value: 待传入逐元素规则的值。
## [br]
## @return 可以运行元素规则时为 true。
## [br]
## @schema value: Variant，允许 null 及不属于集合或运行时句柄的原生标量。
static func is_value_supported(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return (
		value_type != TYPE_OBJECT
		and value_type != TYPE_CALLABLE
		and value_type != TYPE_SIGNAL
		and value_type != TYPE_RID
		and value_type != TYPE_DICTIONARY
		and value_type != TYPE_ARRAY
		and value_type < TYPE_PACKED_BYTE_ARRAY
	)


## 整批预留元素数和规则调用数；拒绝时两项额度都不改变。
## [br]
## @api framework_internal
## [br]
## @param element_count: 当前字段的元素数。
## [br]
## @param rule_count: 已通过定义准入的启用规则数。
## [br]
## @return 本字段可以完整验证时为 true。
func reserve(element_count: int, rule_count: int) -> bool:
	if element_count > _remaining_elements:
		return false
	var check_count: int = element_count * rule_count
	if check_count > _remaining_checks:
		return false
	_remaining_elements -= element_count
	_remaining_checks -= check_count
	return true
