## GFTagSet: 通用标签集合资源。
##
## 只维护标签到层数的映射，不规定标签命名、业务含义或全局注册表。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTagSet
extends Resource


# --- 导出变量 ---

## 标签层数字典。键建议使用 StringName，值为正整数层数。
## [br]
## @api public
## [br]
## @schema tag_counts: Dictionary mapping tag names to positive integer counts.
@export var tag_counts: Dictionary = {}


# --- 私有变量 ---

var _hierarchical_count_cache: Dictionary = {}
var _tag_count_cache_signature: String = ""


# --- 公共方法 ---

## 清空并设置标签集合。
## [br]
## @api public
## [br]
## @param source_tags: Array、PackedStringArray 或 Dictionary 标签数据。
## [br]
## @schema source_tags: Variant tag source accepted as Array, PackedStringArray, or Dictionary.
## [br]
## @return 当前标签集合。
func set_tags(source_tags: Variant) -> GFTagSet:
	clear()
	if source_tags is Dictionary:
		var source_data: Dictionary = GFVariantData.as_dictionary(source_tags)
		for tag_variant: Variant in source_data.keys():
			var _add_tag_result_40: Variant = add_tag(GFVariantData.to_string_name(tag_variant), GFVariantData.to_int(source_data[tag_variant]))
	elif source_tags is PackedStringArray:
		for tag_text: String in source_tags:
			var _add_tag_result_43: Variant = add_tag(StringName(tag_text))
	elif source_tags is Array:
		for tag_variant: Variant in source_tags:
			var _add_tag_result_46: Variant = add_tag(GFVariantData.to_string_name(tag_variant))
	return self


## 添加标签层数。
## [br]
## @api public
## [br]
## @param tag: 标签名。
## [br]
## @param count: 增加层数。
## [br]
## @return 当前标签集合。
func add_tag(tag: StringName, count: int = 1) -> GFTagSet:
	if tag == &"" or count <= 0:
		return self

	tag_counts[tag] = GFVariantData.get_option_int(tag_counts, tag, 0) + count
	_invalidate_count_cache()
	return self


## 移除标签层数。
## [br]
## @api public
## [br]
## @param tag: 标签名。
## [br]
## @param count: 移除层数；-1 表示完全移除。
## [br]
## @return 当前标签集合。
func remove_tag(tag: StringName, count: int = 1) -> GFTagSet:
	if tag == &"" or not tag_counts.has(tag):
		return self
	if count == -1:
		var _erase_result_80: Variant = tag_counts.erase(tag)
		_invalidate_count_cache()
		return self
	if count <= 0:
		return self

	var updated_count: int = GFVariantData.get_option_int(tag_counts, tag, 0) - count
	if updated_count <= 0:
		var _erase_result_87: Variant = tag_counts.erase(tag)
	else:
		tag_counts[tag] = updated_count
	_invalidate_count_cache()
	return self


## 检查是否拥有指定标签且层数达到要求。
## [br]
## @api public
## [br]
## @param tag: 标签名。
## [br]
## @param minimum_count: 要求的最小层数。
## [br]
## @param include_child_tags: 为 true 时，`state` 可匹配 `state.burning`。
## [br]
## @return 满足要求返回 true。
func has_tag(tag: StringName, minimum_count: int = 1, include_child_tags: bool = false) -> bool:
	return get_tag_count(tag, include_child_tags) >= max(1, minimum_count)


## 获取标签层数。
## [br]
## @api public
## [br]
## @param tag: 标签名。
## [br]
## @param include_child_tags: 为 true 时合并子标签层数。
## [br]
## @return 标签层数。
func get_tag_count(tag: StringName, include_child_tags: bool = false) -> int:
	if tag == &"":
		return 0
	if not include_child_tags:
		return GFVariantData.get_option_int(tag_counts, tag, 0)

	_ensure_hierarchical_count_cache()
	return GFVariantData.get_option_int(_hierarchical_count_cache, tag, 0)


## 获取所有标签名。
## [br]
## @api public
## [br]
## @return 排序后的标签名。
func get_tags() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for tag_variant: Variant in tag_counts.keys():
		if GFVariantData.get_option_int(tag_counts, tag_variant, 0) > 0:
			var _appended: bool = result.append(GFVariantData.to_text(tag_variant))
	result.sort()
	return result


## 获取标签层数字典副本。
## [br]
## @api public
## [br]
## @return 标签层数字典。
## [br]
## @schema return: Dictionary mapping tag names to positive integer counts.
func get_tag_counts() -> Dictionary:
	return tag_counts.duplicate(true)


## 清空标签集合。
## [br]
## @api public
func clear() -> void:
	tag_counts.clear()
	_invalidate_count_cache()


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新标签集合。
func duplicate_set() -> GFTagSet:
	var next_set: GFTagSet = GFTagSet.new()
	next_set.tag_counts = tag_counts.duplicate(true)
	return next_set


## 导出为字典。
## [br]
## @api public
## [br]
## @return 标签集合字典。
## [br]
## @schema return: Dictionary serialized tag set.
func to_dictionary() -> Dictionary:
	return {
		"tag_counts": tag_counts.duplicate(true),
	}


## 从字典创建标签集合。
## [br]
## @api public
## [br]
## @param data: 标签集合字典。
## [br]
## @schema data: Dictionary serialized tag set or tag count map.
## [br]
## @return 新标签集合。
static func from_dictionary(data: Dictionary) -> GFTagSet:
	var next_set: GFTagSet = GFTagSet.new()
	var _set_tags_result_199: Variant = next_set.set_tags(GFVariantData.get_option_value(data, "tag_counts", data))
	return next_set


# --- 私有/辅助方法 ---

func _ensure_hierarchical_count_cache() -> void:
	var signature: String = _make_tag_counts_signature()
	if signature == _tag_count_cache_signature:
		return

	var next_cache: Dictionary = {}
	for tag_variant: Variant in tag_counts.keys():
		var count: int = GFVariantData.get_option_int(tag_counts, tag_variant, 0)
		if count <= 0:
			continue
		var tag_text: String = GFVariantData.to_text(tag_variant)
		if tag_text.is_empty():
			continue
		var prefix: String = ""
		for segment: String in tag_text.split("."):
			if segment.is_empty():
				continue
			prefix = segment if prefix.is_empty() else "%s.%s" % [prefix, segment]
			var prefix_key: StringName = StringName(prefix)
			next_cache[prefix_key] = GFVariantData.get_option_int(next_cache, prefix_key, 0) + count
	_hierarchical_count_cache = next_cache
	_tag_count_cache_signature = signature


func _make_tag_counts_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for tag_variant: Variant in tag_counts.keys():
		var tag_text: String = GFVariantData.to_text(tag_variant)
		var count: int = GFVariantData.get_option_int(tag_counts, tag_variant, 0)
		var _append_part: bool = parts.append("%d:%s=%d" % [tag_text.length(), tag_text, count])
	parts.sort()
	return "|".join(parts)


func _invalidate_count_cache() -> void:
	_hierarchical_count_cache.clear()
	_tag_count_cache_signature = ""
