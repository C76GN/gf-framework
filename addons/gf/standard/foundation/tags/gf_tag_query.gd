## GFTagQuery: 通用标签查询资源。
##
## 使用 all/any/none 三组标签描述条件，可直接匹配标签集合、标签组件或普通数据。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTagQuery
extends Resource


# --- 常量 ---

## 用于检查标签源成员关系的内部适配器脚本。
## [br]
## @api private
## [br]
const _GF_TAG_SOURCE_ADAPTER_SCRIPT = preload("res://addons/gf/standard/foundation/tags/gf_tag_source_adapter.gd")


# --- 导出变量 ---

## 必须全部存在的标签。
## [br]
## @api public
@export var all_tags: Array[StringName] = []

## 至少存在一个的标签；为空时跳过该条件。
## [br]
## @api public
@export var any_tags: Array[StringName] = []

## 不允许存在的标签。
## [br]
## @api public
@export var none_tags: Array[StringName] = []

## 是否启用层级匹配。例如查询 `state` 时可匹配 `state.burning`。
## [br]
## @api public
@export var include_child_tags: bool = false


# --- 公共方法 ---

## 检查查询是否为空。
## [br]
## @api public
## [br]
## @return 无任何条件时返回 true。
func is_empty() -> bool:
	return all_tags.is_empty() and any_tags.is_empty() and none_tags.is_empty()


## 匹配标签源。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant accepted by GFTagSourceAdapter.
## [br]
## @return 满足查询返回 true。
func matches(source: Variant) -> bool:
	var report: Dictionary = get_match_report(source)
	return GFVariantData.get_option_bool(report, "ok")


## 获取匹配报告。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant accepted by GFTagSourceAdapter.
## [br]
## @return 包含 ok、missing_all、missing_any、blocked_tags 的报告。
## [br]
## @schema return: Dictionary with ok, missing_all, missing_any, blocked_tags, include_child_tags.
func get_match_report(source: Variant) -> Dictionary:
	var missing_all: Array[StringName] = []
	for tag: StringName in all_tags:
		if not _GF_TAG_SOURCE_ADAPTER_SCRIPT.source_has_tag(source, tag, 1, include_child_tags):
			missing_all.append(tag)

	var missing_any: Array[StringName] = []
	if not any_tags.is_empty():
		for tag: StringName in any_tags:
			if not _GF_TAG_SOURCE_ADAPTER_SCRIPT.source_has_tag(source, tag, 1, include_child_tags):
				missing_any.append(tag)
		if missing_any.size() < any_tags.size():
			missing_any.clear()

	var blocked_tags: Array[StringName] = []
	for tag: StringName in none_tags:
		if _GF_TAG_SOURCE_ADAPTER_SCRIPT.source_has_tag(source, tag, 1, include_child_tags):
			blocked_tags.append(tag)

	return {
		"ok": missing_all.is_empty() and missing_any.is_empty() and blocked_tags.is_empty(),
		"missing_all": missing_all,
		"missing_any": missing_any,
		"blocked_tags": blocked_tags,
		"include_child_tags": include_child_tags,
	}


## 配置查询条件。
## [br]
## @api public
## [br]
## @param required_all: 必须全部存在的标签。
## [br]
## @param required_any: 至少存在一个的标签。
## [br]
## @param rejected_none: 不允许存在的标签。
## [br]
## @param hierarchical: 是否启用层级匹配。
## [br]
## @return 当前查询。
func configure(
	required_all: Array[StringName] = [],
	required_any: Array[StringName] = [],
	rejected_none: Array[StringName] = [],
	hierarchical: bool = false
) -> GFTagQuery:
	all_tags = required_all.duplicate()
	any_tags = required_any.duplicate()
	none_tags = rejected_none.duplicate()
	include_child_tags = hierarchical
	return self


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新查询。
func duplicate_query() -> GFTagQuery:
	var query: GFTagQuery = GFTagQuery.new()
	var _configure_result_139: Variant = query.configure(all_tags, any_tags, none_tags, include_child_tags)
	return query


## 导出为字典。
## [br]
## @api public
## [br]
## @return 查询字典。
## [br]
## @schema return: Dictionary serialized tag query.
func to_dictionary() -> Dictionary:
	return {
		"all_tags": all_tags.duplicate(),
		"any_tags": any_tags.duplicate(),
		"none_tags": none_tags.duplicate(),
		"include_child_tags": include_child_tags,
	}


## 从字典创建查询。
## [br]
## @api public
## [br]
## @param data: 查询字典。
## [br]
## @schema data: Dictionary serialized tag query.
## [br]
## @return 新查询。
static func from_dictionary(data: Dictionary) -> GFTagQuery:
	var query: GFTagQuery = GFTagQuery.new()
	query.all_tags = GFVariantData.get_option_string_name_array(data, "all_tags")
	query.any_tags = GFVariantData.get_option_string_name_array(data, "any_tags")
	query.none_tags = GFVariantData.get_option_string_name_array(data, "none_tags")
	query.include_child_tags = GFVariantData.get_option_bool(data, "include_child_tags")
	return query
