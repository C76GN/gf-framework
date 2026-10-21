@tool

## GFConfigTypeCopier: 在有限预算内复制作者类型图，保留待校验的原始声明。
##
## 复制不执行值规则，不把无效枚举、字段或默认值过滤成合法声明。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFConfigTypeCopier
extends RefCounted


# --- 私有变量 ---

## 复制与调用方共享的工作及深度预算。
## [br]
## @api private
var _budget: GFConfigWorkBudget

## 完成的副本保留合法共享关系。
## [br]
## @api private
var _copies: Dictionary = {}

## 当前路径上的资源身份用于拒绝循环。
## [br]
## @api private
var _active: Dictionary = {}

## 只记录复制过程的预算或循环错误。
## [br]
## @api private
var _issues: Array[Dictionary] = []


# --- Godot 生命周期方法 ---

## 绑定外部预算，不读取资源或执行规则。
## [br]
## @api private
func _init(options: Dictionary = {}) -> void:
	_budget = GFConfigWorkBudget.from_options(options)


# --- 框架内部方法 ---

## 取得同一次 schema 复制的会话。
## [br]
## @api framework_internal
## [br]
## @param options: 复制预算与内部会话选项。
## [br]
## @return 当前复制会话。
## [br]
## @schema options: Dictionary，可包含 work_budget、work_limits 或 __gf_config_type_copier。
static func from_options(options: Dictionary = {}) -> GFConfigTypeCopier:
	var supplied: Variant = options.get("__gf_config_type_copier")
	if supplied is GFConfigTypeCopier:
		return supplied
	return GFConfigTypeCopier.new(options)


## 复制前准入基类元数据和内置规则已知载荷，不反射自定义资源属性。
##
## 自定义 duplicate_rule 和 describe 仍为受信任代码；这里只界定内置字段的复制工作。
## [br]
## @api framework_internal
## [br]
## @param rule: 即将复制或描述的规则，null 不产生额外工作。
## [br]
## @param budget: 当前操作共享的预算。
## [br]
## @return 已知载荷无循环且在预算内时为 true。
static func admit_rule_copy(rule: GFConfigValidationRule, budget: GFConfigWorkBudget) -> bool:
	if rule == null:
		return budget.is_ok()
	if not budget.admit_value(
		[rule.rule_id, rule.metadata],
		"validation.rule_clone"
	):
		return false
	var payload: Variant = null
	if rule is GFConfigSetValidationRule:
		var set_rule: GFConfigSetValidationRule = rule
		payload = set_rule.allowed_values
	elif rule is GFConfigNotDefaultValidationRule:
		var default_rule: GFConfigNotDefaultValidationRule = rule
		payload = default_rule.default_value
	elif rule is GFConfigLocalizationKeyValidationRule:
		var localization_rule: GFConfigLocalizationKeyValidationRule = rule
		payload = [localization_rule.known_keys, localization_rule.text_map]
	elif rule is GFConfigResourcePathValidationRule:
		var path_rule: GFConfigResourcePathValidationRule = rule
		payload = path_rule.allowed_extensions
	elif rule is GFConfigRegexValidationRule:
		var regex_rule: GFConfigRegexValidationRule = rule
		payload = regex_rule.pattern
	return budget.admit_value(payload, "validation.rule_payload_clone")


## 有界复制整个类型图，保留非循环的无效声明供正式校验指出。
## [br]
## @api framework_internal
## [br]
## @param definition: 作者类型资源。
## [br]
## @param depth: 当前图深度。
## [br]
## @return 独立副本；循环或超预算时为 null。
func copy_definition(definition: GFConfigTypeDefinition, depth: int = 0) -> GFConfigTypeDefinition:
	if definition == null:
		return null
	if not _enter(definition, depth):
		return null
	var identity: int = definition.get_instance_id()
	if _copies.has(identity):
		var _cached_identity_erased: bool = _active.erase(identity)
		return _copies[identity]
	var result: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	result.kind = definition.kind
	result.type_name = definition.type_name
	result.allow_null = definition.allow_null
	result.scalar_type = definition.scalar_type
	result.map_key_type = definition.map_key_type
	result.discriminator = definition.discriminator
	if not _budget.admit_value(definition.symbols, "type symbols"):
		_fail_budget()
		return null
	result.symbols = definition.symbols.duplicate(true)
	result.base_type = copy_definition(
		definition.base_type,
		depth + 1
	)
	result.element_type = copy_definition(
		definition.element_type,
		depth + 1
	)
	result.map_value_type = copy_definition(
		definition.map_value_type,
		depth + 1
	)
	for field: GFConfigTableColumn in definition.fields:
		if not _budget.is_ok() or not _issues.is_empty():
			break
		if not _budget.consume_work(1, "type field copy"):
			_fail_budget()
			break
		result.fields.append(
			copy_column(
				field,
				depth + 1
			)
		)
	for branch: Resource in definition.variants:
		if not _budget.is_ok() or not _issues.is_empty():
			break
		if not _budget.consume_work(1, "type branch copy"):
			_fail_budget()
			break
		if branch != null and not (branch is GFConfigTypeDefinition):
			_issues.append(
				{
					"severity": "error",
					"kind": "invalid_polymorphic_branch",
					"message": "多态分支必须是 GFConfigTypeDefinition 资源。",
				}
			)
			break
		var branch_definition: GFConfigTypeDefinition = branch
		result.variants.append(
			copy_definition(
				branch_definition,
				depth + 1
			)
		)
	var _erased: bool = _active.erase(identity)
	if not _issues.is_empty():
		return null
	_copies[identity] = result
	return result


## 复制字段而不执行其默认值或业务校验规则。
## [br]
## @api framework_internal
## [br]
## @param column: 作者字段，null 会原样保留。
## [br]
## @param depth: 当前图深度。
## [br]
## @return 独立字段；循环或预算失败时为 null。
func copy_column(column: GFConfigTableColumn, depth: int = 0) -> GFConfigTableColumn:
	if column == null:
		return null
	if not _enter(column, depth):
		return null
	var identity: int = column.get_instance_id()
	if _copies.has(identity):
		var _cached_identity_erased: bool = _active.erase(identity)
		return _copies[identity]
	if not _budget.admit_value(column.default_value, "column default") or not _budget.admit_value(column.metadata, "column metadata"):
		_fail_budget()
		return null
	var result: GFConfigTableColumn = GFConfigTableColumn.new()
	result.field_name = column.field_name
	result.value_type = column.value_type
	result.required = column.required
	result.allow_null = column.allow_null
	result.default_value = GFVariantData.duplicate_variant(column.default_value)
	result.metadata = column.metadata.duplicate(true)
	result.type_definition = copy_definition(
		column.type_definition,
		depth + 1
	)
	result.validation_rules = _copy_rules(column.validation_rules)
	result.element_validation_rules = _copy_rules(column.element_validation_rules)
	var _erased: bool = _active.erase(identity)
	if not _issues.is_empty():
		return null
	_copies[identity] = result
	return result


## 返回复制错误，不把无效声明误报为已经通过语义校验。
## [br]
## @api framework_internal
## [br]
## @return 复制成功标记和结构问题。
## [br]
## @schema return: Dictionary，包含 ok、issues、error_count、warning_count。
func get_report() -> Dictionary:
	if not _budget.is_ok():
		_fail_budget()
	return {
		"ok": _issues.is_empty(),
		"issues": _issues.duplicate(true),
		"error_count": _issues.size(),
		"warning_count": 0,
	}


# --- 私有/辅助方法 ---

## 每条边先消费预算，并只拒绝当前路径上的循环。
## [br]
## @api private
func _enter(resource: Resource, depth: int) -> bool:
	if not _issues.is_empty():
		return false
	if not _budget.check_depth(depth, "type copy") or not _budget.consume_work(1, "type copy"):
		_fail_budget()
		return false
	var identity: int = resource.get_instance_id()
	if _active.has(identity):
		_issues.append(
			{
				"severity": "error",
				"kind": "cyclic_type_definition",
				"message": "无法复制循环配置类型声明。",
			}
		)
		return false
	_active[identity] = true
	return true


## 沿用规则的复制契约；不调用任何 validate 方法，空规则保留给正式准入。
## [br]
## @api private
func _copy_rules(rules: Array[GFConfigValidationRule]) -> Array[GFConfigValidationRule]:
	var result: Array[GFConfigValidationRule] = []
	for rule: GFConfigValidationRule in rules:
		if not _budget.consume_work(1, "rule copy"):
			_fail_budget()
			break
		if not admit_rule_copy(rule, _budget):
			_fail_budget()
			break
		result.append(rule.duplicate_rule() if rule != null else null)
	return result


## 预算失败只保留一次终态原因。
## [br]
## @api private
func _fail_budget() -> void:
	if not _issues.is_empty():
		return
	var report: Dictionary = _budget.get_report()
	_issues.append(
		{
			"severity": "error",
			"kind": report["error_kind"],
			"message": report["error"],
		}
	)
