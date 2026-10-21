@tool

## GFConfigTypeDefinition: 配置值的结构化类型声明。
##
## 同一资源用于导入规范化、校验和生成描述；每次调用建立有限编译会话，
## 不缓存调用之间可能改变的资源。结构字段使用 GFConfigTableColumn 的约束。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFConfigTypeDefinition
extends Resource


# --- 枚举 ---

## 配置值的可编译形状。
## [br]
## @api public
## [br]
## @since unreleased
enum Kind {
	## 沿用字段标量转换。
	SCALAR,
	## 具有明确字段及可选基类的字典。
	STRUCT,
	## 具有统一元素类型的数组。
	ARRAY,
	## 具有受限键类型及统一值类型的字典。
	MAP,
	## 具有明确符号及整数值的枚举。
	ENUM,
	## 由判别字段选择具名结构分支的字典。
	POLYMORPHIC,
}


# --- 导出变量 ---

## 类型形状；只有对应形状的字段可以设置非默认值。
## [br]
## @api public
## [br]
## @since unreleased
@export var kind: Kind = Kind.SCALAR

## 供生成器及多态分支使用的稳定名称；多态分支必须非空且唯一。
## [br]
## @api public
## [br]
## @since unreleased
@export var type_name: StringName = &""

## 容器元素或直接类型调用是否允许 null；字段位置由 column.allow_null 决定。
## [br]
## @api public
## [br]
## @since unreleased
@export var allow_null: bool = false

## SCALAR 的标量类型；不接受 ANY、ARRAY 或 DICTIONARY。
## [br]
## @api public
## [br]
## @since unreleased
@export var scalar_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.STRING

## STRUCT 自己声明的字段；继承字段在前，禁止覆盖任何基类字段。
## [br]
## @api public
## [br]
## @since unreleased
@export var fields: Array[GFConfigTableColumn] = []

## STRUCT 的可选基类；只接受 STRUCT，整个定义图不允许循环。
## [br]
## @api public
## [br]
## @since unreleased
@export var base_type: GFConfigTypeDefinition = null

## ARRAY 的元素类型。
## [br]
## @api public
## [br]
## @since unreleased
@export var element_type: GFConfigTypeDefinition = null

## MAP 的键类型；只允许 STRING、STRING_NAME 和 INT，转换后重复键失败。
## [br]
## @api public
## [br]
## @since unreleased
@export var map_key_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.STRING

## MAP 的值类型。
## [br]
## @api public
## [br]
## @since unreleased
@export var map_value_type: GFConfigTypeDefinition = null

## ENUM 的具名整数值；符号及整数值均必须唯一。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema symbols: Dictionary，非空 String 或 StringName 符号映射到唯一 int 值。
@export var symbols: Dictionary = {}

## POLYMORPHIC 的必需判别字段；不得与任何分支的结构字段重名。
## [br]
## @api public
## [br]
## @since unreleased
@export var discriminator: StringName = &"type"

## POLYMORPHIC 的可选分支；每项必须是具名 GFConfigTypeDefinition STRUCT。
##
## 使用 Resource 数组避免默认值数组持有当前脚本自身，正式编译逐项检查类型。
## [br]
## @api public
## [br]
## @since unreleased
@export var variants: Array[Resource] = []


# --- 公共方法 ---

## 校验类型图、字段约束和默认值，不修改声明资源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 调用期预算与诊断上下文。
## [br]
## @return 校验报告，错误保留字段路径。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits，以及 source、field、field_path 和 field_segments。非空 field_segments 为权威根路径；否则 field 为根字段。仅给 field_path 时保留显示前缀，不从文本推导完整 field_segments。
## [br]
## @schema return: Dictionary，包含 ok、issues、error_count、warning_count。
func validate_definition(options: Dictionary = {}) -> Dictionary:
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new(options)
	var _node: Dictionary = compiler.compile_type(self)
	compiler.validate_defaults()
	return compiler.get_report()


## 在同一有限会话内编译类型并返回纯数据描述。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 调用期预算与诊断上下文。
## [br]
## @return 编译报告；失败时 definition 为空字典且 issues 保留原因。
## [br]
## @schema options: Dictionary，与 validate_definition 使用相同预算与来源上下文；根路径优先 field_segments，其次 field，仅有 field_path 时保留显示前缀。
## [br]
## @schema return: Dictionary，校验报告附加 definition；成功描述包含 kind、type_name、allow_null 及当前形状的字段，不含 Resource 引用。
func compile_definition(options: Dictionary = {}) -> Dictionary:
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new(options)
	var node: Dictionary = compiler.compile_type(self)
	compiler.validate_defaults()
	var report: Dictionary = compiler.get_report()
	var definition: Dictionary = compiler.describe_type(node) if report["ok"] else {}
	report = compiler.get_report()
	report["definition"] = definition if report["ok"] else {}
	return report


## 规范化并校验一个值，始终返回隔离副本。
##
## 任一类型、规则、预算或未知字段失败时 value 为 null，不返回部分成功数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 不会被修改的输入值。
## [br]
## @param options: 预算、来源与标量转换选项。
## [br]
## @return 校验报告及规范化值。
## [br]
## @schema value: Variant，符合所声明结构的标量、Array 或 Dictionary；不接受循环集合或对象。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits、coerce_values（默认 true）及与 validate_definition 相同的来源上下文；定义与值失败保留同一根路径。
## [br]
## @schema return: Dictionary，包含 ok、value、issues、error_count、warning_count 和 message；失败时 value 为 null。
func try_normalize(value: Variant, options: Dictionary = {}) -> Dictionary:
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new(options)
	var node: Dictionary = compiler.compile_type(self)
	compiler.validate_defaults()
	if not compiler.get_report()["ok"]:
		var failure: Dictionary = compiler.get_report()
		failure["value"] = null
		failure["message"] = "配置类型定义无效。"
		return failure
	return compiler.normalize_type(
		node,
		value,
		options
	)


## 有界描述声明结构，不执行默认值及业务值规则。
##
## ok 只说明结构可描述，不代替 validate_definition 或 compile_definition 的默认值准入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 调用期预算与来源上下文。
## [br]
## @return 包含 definition 的结构报告；无效结构不会伪装成空的合法定义。
## [br]
## @schema options: Dictionary，与 compile_definition 的选项相同。
## [br]
## @schema return: Dictionary，与 compile_definition 具有相同报告形状；仅校验声明结构，失败 definition 为空且 ok 为 false。
func describe(options: Dictionary = {}) -> Dictionary:
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.from_options(options)
	var node: Dictionary = compiler.compile_type(self)
	var report: Dictionary = compiler.get_report()
	var definition: Dictionary = compiler.describe_type(node) if report["ok"] else {}
	report = compiler.get_report()
	report["definition"] = definition if report["ok"] else {}
	return report


## 有界复制原始类型图，保留待校验声明且不执行值规则。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 调用期预算。
## [br]
## @return 校验报告与复制后的 definition；失败时为 null。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
## [br]
## @schema return: Dictionary，包含 ok、issues、error_count、warning_count、definition；definition 为独立 GFConfigTypeDefinition 或 null。
func try_duplicate_definition(options: Dictionary = {}) -> Dictionary:
	var copier: GFConfigTypeCopier = GFConfigTypeCopier.from_options(options)
	var definition: GFConfigTypeDefinition = copier.copy_definition(self)
	var report: Dictionary = copier.get_report()
	report["definition"] = definition if report["ok"] else null
	return report


## 复制原始声明；循环或超预算时返回 null，详细原因由 try_duplicate_definition 提供。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 调用期预算。
## [br]
## @return 独立类型资源；失败时为 null。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
func duplicate_definition(options: Dictionary = {}) -> GFConfigTypeDefinition:
	var report: Dictionary = try_duplicate_definition(options)
	var copied: Variant = report["definition"]
	if copied is GFConfigTypeDefinition:
		return copied
	return null
