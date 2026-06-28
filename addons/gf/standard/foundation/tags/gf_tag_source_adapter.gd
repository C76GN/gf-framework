## GFTagSourceAdapter: 通用标签源适配器。
##
## 支持 GFTagSet、Array、PackedStringArray、Dictionary 以及具备 has_tag/get_tag_count/get_tags
## 方法的对象。它不维护全局标签表，也不规定标签语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTagSourceAdapter
extends RefCounted


# --- 常量 ---

const _MAX_OBJECT_PROTOCOL_CACHE_ENTRIES: int = 512


# --- 私有变量 ---

static var _has_tag_arity_cache: Dictionary = {}


# --- 公共方法 ---

## 检查标签源是否拥有指定标签。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @param tag: 标签名。
## [br]
## @param minimum_count: 要求的最小层数。
## [br]
## @param include_child_tags: 为 true 时，`state` 可匹配 `state.burning`。
## [br]
## @return 满足要求返回 true。
static func source_has_tag(
	source: Variant,
	tag: StringName,
	minimum_count: int = 1,
	include_child_tags: bool = false
) -> bool:
	if tag == &"":
		return false

	var count: int = get_tag_count(source, tag, include_child_tags)
	if count >= max(1, minimum_count):
		return true
	if include_child_tags:
		return false
	if source is Object:
		var object_source: Object = source
		return _call_has_tag(object_source, tag, minimum_count)
	return false


## 获取标签源中的标签层数。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @param tag: 标签名。
## [br]
## @param include_child_tags: 为 true 时合并子标签层数。
## [br]
## @return 标签层数。
static func get_tag_count(source: Variant, tag: StringName, include_child_tags: bool = false) -> int:
	if source == null or tag == &"":
		return 0
	if source is GFTagSet:
		var tag_set: GFTagSet = source
		return tag_set.get_tag_count(tag, include_child_tags)
	if source is Dictionary:
		var data: Dictionary = source
		return _get_dictionary_tag_count(data, tag, include_child_tags)
	if source is PackedStringArray or source is Array:
		return _get_array_tag_count(source, tag, include_child_tags)
	if source is Object:
		var object_source: Object = source
		return _get_object_tag_count(object_source, tag, include_child_tags)
	return 0


## 获取标签源中的标签名。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @return 排序后的标签名。
static func get_tags(source: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if source == null:
		return result
	if source is GFTagSet:
		var tag_set: GFTagSet = source
		return tag_set.get_tags()
	if source is Dictionary:
		var source_data: Dictionary = source
		var data: Dictionary = _resolve_dictionary_tag_data(source_data)
		for tag_variant: Variant in data.keys():
			if GFVariantData.get_option_int(data, tag_variant, 0) > 0:
				var _tag_appended: bool = result.append(GFVariantData.to_text(tag_variant))
	elif source is PackedStringArray:
		var packed_source: PackedStringArray = source
		result = packed_source
	elif source is Array:
		var array_source: Array = source
		for tag_variant: Variant in array_source:
			var _array_tag_appended: bool = result.append(GFVariantData.to_text(tag_variant))
	elif source is Object:
		var object_source: Object = source
		result = _get_object_tags(object_source)

	result.sort()
	return result


## 获取标签源中的标签层数字典。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @return 标签名到层数的字典。
## [br]
## @schema return: Dictionary[StringName, int]，只包含层数大于 0 的标签。
static func get_tag_counts(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	for tag_text: String in get_tags(source):
		var tag: StringName = StringName(tag_text)
		var count: int = get_tag_count(source, tag)
		if count > 0:
			result[tag] = count
	return result


## 将任意标签源规范化为 GFTagSet。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @return 新的标签集合。
static func to_tag_set(source: Variant) -> GFTagSet:
	var tag_set: GFTagSet = GFTagSet.new()
	var _tags_set: GFTagSet = tag_set.set_tags(get_tag_counts(source))
	return tag_set


## 合并多个标签源并返回新的 GFTagSet。
## [br]
## @api public
## [br]
## @param sources: 标签源数组。
## [br]
## @schema sources: Array[Variant]，每个元素都可被 GFTagSourceAdapter 读取。
## [br]
## @return 合并后的标签集合。
static func merge_sources(sources: Array) -> GFTagSet:
	var tag_set: GFTagSet = GFTagSet.new()
	for source: Variant in sources:
		var counts: Dictionary = get_tag_counts(source)
		for tag_variant: Variant in counts.keys():
			var _tag_added: GFTagSet = tag_set.add_tag(
				GFVariantData.to_string_name(tag_variant),
				GFVariantData.to_int(counts[tag_variant])
			)
	return tag_set


## 检查标签源是否包含所有标签。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @param tags: 需要全部满足的标签。
## [br]
## @param include_child_tags: 是否启用层级匹配。
## [br]
## @return 全部满足返回 true。
static func matches_all(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:
	for tag: StringName in tags:
		if not source_has_tag(source, tag, 1, include_child_tags):
			return false
	return true


## 检查标签源是否包含任意标签。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @param tags: 需要满足任意一个的标签；空数组返回 true。
## [br]
## @param include_child_tags: 是否启用层级匹配。
## [br]
## @return 满足任意标签返回 true。
static func matches_any(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:
	if tags.is_empty():
		return true
	for tag: StringName in tags:
		if source_has_tag(source, tag, 1, include_child_tags):
			return true
	return false


## 检查标签源是否不包含任何禁止标签。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant tag source accepted by the adapter.
## [br]
## @param tags: 禁止出现的标签。
## [br]
## @param include_child_tags: 是否启用层级匹配。
## [br]
## @return 未命中禁止标签返回 true。
static func matches_none(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:
	for tag: StringName in tags:
		if source_has_tag(source, tag, 1, include_child_tags):
			return false
	return true


# --- 私有/辅助方法 ---

static func _get_dictionary_tag_count(data: Dictionary, tag: StringName, include_child_tags: bool) -> int:
	var tag_data: Dictionary = _resolve_dictionary_tag_data(data)
	if not include_child_tags:
		return _get_exact_dictionary_tag_count(tag_data, tag)

	var count: int = 0
	var prefix: String = "%s." % String(tag)
	for candidate_variant: Variant in tag_data.keys():
		var candidate_text: String = GFVariantData.to_text(candidate_variant)
		if candidate_text == String(tag) or candidate_text.begins_with(prefix):
			count += GFVariantData.get_option_int(tag_data, candidate_variant, 0)
	return count


static func _resolve_dictionary_tag_data(data: Dictionary) -> Dictionary:
	if data.has("tag_counts") and data["tag_counts"] is Dictionary:
		var tag_counts: Dictionary = data["tag_counts"]
		return tag_counts
	if data.has(&"tag_counts") and data[&"tag_counts"] is Dictionary:
		var named_tag_counts: Dictionary = data[&"tag_counts"]
		return named_tag_counts
	if data.has("tags") and not (data["tags"] is Dictionary):
		return _array_to_counts(data["tags"])
	if data.has(&"tags") and not (data[&"tags"] is Dictionary):
		return _array_to_counts(data[&"tags"])
	if data.has("tags") and data["tags"] is Dictionary:
		var tags: Dictionary = data["tags"]
		return tags
	if data.has(&"tags") and data[&"tags"] is Dictionary:
		var named_tags: Dictionary = data[&"tags"]
		return named_tags
	return data


static func _get_array_tag_count(source: Variant, tag: StringName, include_child_tags: bool) -> int:
	var count: int = 0
	var prefix: String = "%s." % String(tag)
	var values: PackedStringArray = PackedStringArray()
	if source is PackedStringArray:
		var packed_source: PackedStringArray = source
		values = packed_source
	elif source is Array:
		var array_source: Array = source
		for tag_variant: Variant in array_source:
			var _tag_appended: bool = values.append(GFVariantData.to_text(tag_variant))

	for candidate_text: String in values:
		if candidate_text == String(tag) or (include_child_tags and candidate_text.begins_with(prefix)):
			count += 1
	return count


static func _array_to_counts(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is PackedStringArray:
		var packed_source: PackedStringArray = source
		for tag_text: String in packed_source:
			var tag: StringName = StringName(tag_text)
			result[tag] = GFVariantData.get_option_int(result, tag, 0) + 1
	elif source is Array:
		var array_source: Array = source
		for tag_variant: Variant in array_source:
			var tag: StringName = GFVariantData.to_string_name(tag_variant)
			result[tag] = GFVariantData.get_option_int(result, tag, 0) + 1
	return result


static func _get_object_tag_count(source: Object, tag: StringName, include_child_tags: bool) -> int:
	var exact_count: int = 0
	var has_get_tag_count: bool = source.has_method("get_tag_count")
	if has_get_tag_count:
		exact_count = GFVariantData.to_int(source.call("get_tag_count", tag))
	if not include_child_tags:
		return exact_count

	var count: int = exact_count
	var prefix: String = "%s." % String(tag)
	for candidate_text: String in _get_object_tags(source):
		if candidate_text == String(tag):
			continue
		if candidate_text.begins_with(prefix):
			count += GFVariantData.to_int(source.call("get_tag_count", StringName(candidate_text))) if has_get_tag_count else 1
	return count


static func _get_object_tags(source: Object) -> PackedStringArray:
	if not source.has_method("get_tags"):
		return PackedStringArray()

	var raw_tags: Variant = source.call("get_tags")
	if raw_tags is PackedStringArray:
		return raw_tags
	var result: PackedStringArray = PackedStringArray()
	if raw_tags is Array:
		var array_tags: Array = raw_tags
		for tag_variant: Variant in array_tags:
			var _tag_appended: bool = result.append(GFVariantData.to_text(tag_variant))
	return result


static func _call_has_tag(source: Object, tag: StringName, minimum_count: int) -> bool:
	if not source.has_method("has_tag"):
		return false

	var argument_count: int = _get_has_tag_argument_count(source)
	if argument_count >= 2:
		return GFVariantData.to_bool(source.call("has_tag", tag, minimum_count))
	if argument_count >= 1:
		return GFVariantData.to_bool(source.call("has_tag", tag))
	return false


static func _get_has_tag_argument_count(source: Object) -> int:
	var cache_key: String = _get_object_protocol_cache_key(source)
	if not cache_key.is_empty() and _has_tag_arity_cache.has(cache_key):
		return GFVariantData.get_option_int(_has_tag_arity_cache, cache_key, -1)

	var argument_count: int = -1
	for method: Dictionary in source.get_method_list():
		if GFVariantData.get_option_string(method, "name") != "has_tag":
			continue
		var args: Array = GFVariantData.as_array(GFVariantData.get_option_value(method, "args", []))
		argument_count = args.size()
		break

	if not cache_key.is_empty():
		if _has_tag_arity_cache.size() >= _MAX_OBJECT_PROTOCOL_CACHE_ENTRIES:
			_has_tag_arity_cache.clear()
		_has_tag_arity_cache[cache_key] = argument_count
	return argument_count


static func _get_object_protocol_cache_key(source: Object) -> String:
	if source == null:
		return ""
	var script_value: Variant = source.get_script()
	if script_value is Script:
		var source_script: Script = script_value
		if not source_script.resource_path.is_empty():
			return "%s:%s" % [source.get_class(), source_script.resource_path]
		return "%s:%d" % [source.get_class(), source_script.get_instance_id()]
	return source.get_class()


static func _get_exact_dictionary_tag_count(tag_data: Dictionary, tag: StringName) -> int:
	if tag_data.has(tag):
		return GFVariantData.to_int(tag_data[tag])

	var tag_text: String = String(tag)
	if tag_data.has(tag_text):
		return GFVariantData.to_int(tag_data[tag_text])
	return 0
