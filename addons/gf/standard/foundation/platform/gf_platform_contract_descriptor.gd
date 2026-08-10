## GFPlatformContractDescriptor: 平台桥接契约描述。
##
## 将一个 provider-neutral contract 的版本和方法集合固定为可校验数据。描述符不包含
## Steam、微信、主机厂商或项目业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 10.0.0
class_name GFPlatformContractDescriptor
extends Resource


# --- 导出变量 ---

## 契约稳定标识；直接创作的值不得包含首尾空白。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var contract_id: StringName = &""

## 契约版本。Adapter 应使用双方明确支持的版本，不做隐式降级。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var contract_version: String = "1.0.0"

## 方法描述符列表。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema methods: Array[GFPlatformContractMethodDescriptor] platform contract methods.
@export var methods: Array[GFPlatformContractMethodDescriptor] = []

## Adapter 作者定义的非业务元数据。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema metadata: Dictionary adapter-authoring metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置平台契约。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param p_contract_id: 契约稳定标识。
## [br]
## @param p_contract_version: 契约版本。
## [br]
## @param p_methods: 方法描述符列表。
## [br]
## @param p_metadata: Adapter 作者元数据。
## [br]
## @schema p_methods: Array[GFPlatformContractMethodDescriptor] platform contract methods.
## [br]
## @schema p_metadata: Dictionary adapter-authoring metadata.
## [br]
## @return 当前描述符。
func configure(
	p_contract_id: StringName,
	p_contract_version: String,
	p_methods: Array[GFPlatformContractMethodDescriptor],
	p_metadata: Dictionary = {}
) -> GFPlatformContractDescriptor:
	contract_id = StringName(String(p_contract_id).strip_edges())
	contract_version = p_contract_version.strip_edges()
	methods = []
	for method: GFPlatformContractMethodDescriptor in p_methods:
		if method != null:
			methods.append(method.duplicate_descriptor())
	metadata = p_metadata.duplicate(true)
	return self


## 获取方法描述符副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param method_id: 方法稳定标识。
## [br]
## @return 找到时返回描述符副本，否则返回 null。
func get_method(method_id: StringName) -> GFPlatformContractMethodDescriptor:
	var normalized_method_id: StringName = StringName(String(method_id).strip_edges())
	for method: GFPlatformContractMethodDescriptor in methods:
		if method != null and method.method_id == normalized_method_id:
			return method.duplicate_descriptor()
	return null


## 校验契约定义和重复方法。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 标准校验报告。
func validate_definition() -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(
		"Platform contract %s" % String(contract_id)
	)
	var normalized_contract_id: StringName = StringName(String(contract_id).strip_edges())
	if normalized_contract_id == &"":
		var _contract_issue: RefCounted = report.add_error(
			&"missing_contract_id",
			"Platform contract ID is required."
		)
	elif contract_id != normalized_contract_id:
		var _contract_format_issue: RefCounted = report.add_error(
			&"non_canonical_contract_id",
			"Platform contract ID must not have surrounding whitespace."
		)
	if contract_version.is_empty():
		var _version_issue: RefCounted = report.add_error(
			&"missing_contract_version",
			"Platform contract version is required."
		)
	if methods.is_empty():
		var _methods_issue: RefCounted = report.add_error(
			&"missing_contract_methods",
			"Platform contract must declare at least one method."
		)
	var seen_method_ids: Dictionary = {}
	for method: GFPlatformContractMethodDescriptor in methods:
		if method == null:
			var _null_method_issue: RefCounted = report.add_error(
				&"null_contract_method",
				"Platform contract contains a null method descriptor."
			)
			continue
		var method_report: GFValidationReport = method.validate_definition()
		var _merged_method: RefCounted = report.merge(method_report)
		if method.method_id != &"" and seen_method_ids.has(String(method.method_id)):
			var _duplicate_issue: RefCounted = report.add_error(
				&"duplicate_contract_method",
				"Platform contract method IDs must be unique.",
				method.method_id
			)
		seen_method_ids[String(method.method_id)] = true
	return report


## 创建契约描述符深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新描述符。
func duplicate_descriptor() -> GFPlatformContractDescriptor:
	return GFPlatformContractDescriptor.new().configure(
		contract_id,
		contract_version,
		methods,
		metadata
	)


## 转换为不包含请求和结果载荷的摘要字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 契约摘要。
## [br]
## @schema return: Dictionary platform contract descriptor summary.
func to_dict() -> Dictionary:
	var method_entries: Array[Dictionary] = []
	for method: GFPlatformContractMethodDescriptor in methods:
		if method != null:
			method_entries.append(method.to_dict())
	method_entries.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return GFVariantData.get_option_string(left, "method_id") < GFVariantData.get_option_string(right, "method_id")
	)
	return {
		"contract_id": contract_id,
		"contract_version": contract_version,
		"methods": method_entries,
		"metadata": metadata.duplicate(true),
	}
