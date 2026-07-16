## GFCapabilityQuery: 可资源化的能力接收者查询条件。
##
## 用于把 required / rejected 能力类型、分组和子类匹配策略保存为 Resource，
## 便于编辑器工具、配置资源或项目脚本复用同一套查询声明。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFCapabilityQuery
extends Resource


# --- 导出变量 ---

## 查询必须拥有的能力类型列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema required_capability_types: Array[Script]，元素为必须拥有的能力脚本类型。
@export var required_capability_types: Array[Script] = []

## 查询必须排除的能力类型列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema rejected_capability_types: Array[Script]，元素为必须排除的能力脚本类型。
@export var rejected_capability_types: Array[Script] = []

## 是否在 required / rejected 匹配中包含子类能力。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var include_subclasses: bool = true

## 可选能力分组；非空时只在该分组内查询。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var group_name: StringName = &""

## 项目或工具自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary，保存项目或工具附加信息。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 使用指定 Utility 执行当前查询。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param capability_utility: 能力 Utility。
## [br]
## @return: 当前仍有效且满足条件的 receiver 列表。
## [br]
## @schema return: Array[Object]，元素为当前仍有效的能力接收对象。
func get_receivers(capability_utility: GFCapabilityUtility) -> Array[Object]:
	if capability_utility == null:
		var empty_result: Array[Object] = []
		return empty_result
	return capability_utility.get_receivers_matching_query(self)


## 判断指定 receiver 是否满足当前查询。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param capability_utility: 能力 Utility。
## [br]
## @param receiver: 要检查的能力接收对象。
## [br]
## @return: 满足查询返回 true。
func matches_receiver(capability_utility: GFCapabilityUtility, receiver: Object) -> bool:
	if capability_utility == null:
		return false
	return capability_utility.receiver_matches_query(receiver, self)


## 创建同内容查询拷贝。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return: 新查询资源。
func duplicate_query() -> GFCapabilityQuery:
	var query: GFCapabilityQuery = GFCapabilityQuery.new()
	query.required_capability_types = _duplicate_script_array(required_capability_types)
	query.rejected_capability_types = _duplicate_script_array(rejected_capability_types)
	query.include_subclasses = include_subclasses
	query.group_name = group_name
	query.metadata = metadata.duplicate(true)
	return query


## 导出查询声明摘要。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return: 查询声明字典。
## [br]
## @schema return: Dictionary，包含 required_capability_types、rejected_capability_types、include_subclasses、group_name 和 metadata。
func describe_query() -> Dictionary:
	return {
		"required_capability_types": _duplicate_script_array(required_capability_types),
		"rejected_capability_types": _duplicate_script_array(rejected_capability_types),
		"include_subclasses": include_subclasses,
		"group_name": group_name,
		"metadata": metadata.duplicate(true),
	}


## 导出查询声明的 JSON-safe 报告快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 查询报告字典。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on describe_query().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(describe_query(), options)


# --- 私有/辅助方法 ---

func _duplicate_script_array(source: Array[Script]) -> Array[Script]:
	var result: Array[Script] = []
	for script_type: Script in source:
		result.append(script_type)
	return result
