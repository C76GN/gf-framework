## GFTagCatalog: 可选标签目录与重定向资源。
##
## 用于声明项目可识别的标签、说明文本、迁移重定向和元数据。它只提供
## 定义校验和标签源规范化，不强制所有 GFTagSet 或 GFTagQuery 必须依赖全局目录。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFTagCatalog
extends Resource


# --- 导出变量 ---

## 目录标识。为空时调用方可自行决定报告主题。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var catalog_id: StringName = &""

## 标签定义列表。
##
## 每项是 Dictionary，至少包含 tag，可选 redirect_to、description 和 metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema tag_definitions: Array[Dictionary]，每项包含 tag: StringName/String、redirect_to: StringName/String、description: String、metadata: Dictionary。
@export var tag_definitions: Array[Dictionary] = []

## 校验标签源时是否允许目录外标签。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var allow_undefined_tags: bool = true

## 目录元数据。GF 不解释其中业务字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined catalog metadata.
@export var metadata: Dictionary = {}


# --- 私有变量 ---

var _definition_lookup_cache: Dictionary = {}
var _redirect_lookup_cache: Dictionary = {}
var _catalog_signature: String = ""


# --- 公共方法 ---

## 配置标签目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_catalog_id: 目录标识。
## [br]
## @param p_definitions: 标签定义列表。
## [br]
## @param options: 可选配置，支持 allow_undefined_tags 和 metadata。
## [br]
## @return 当前目录。
## [br]
## @schema p_definitions: Array[Dictionary] 标签定义列表。
## [br]
## @schema options: Dictionary catalog options.
func configure(
	p_catalog_id: StringName,
	p_definitions: Array[Dictionary] = [],
	options: Dictionary = {}
) -> GFTagCatalog:
	catalog_id = p_catalog_id
	tag_definitions = []
	for definition: Dictionary in p_definitions:
		tag_definitions.append(definition.duplicate(true))
	allow_undefined_tags = GFVariantData.get_option_bool(options, "allow_undefined_tags", allow_undefined_tags)
	metadata = GFVariantData.get_option_dictionary(options, "metadata", metadata)
	_invalidate_cache()
	return self


## 添加标签定义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param tag: 标签名。
## [br]
## @param options: 定义选项，支持 redirect_to、description 和 metadata。
## [br]
## @return 添加成功返回 true。
## [br]
## @schema options: Dictionary tag definition options.
func add_tag(tag: StringName, options: Dictionary = {}) -> bool:
	if tag == &"" or has_tag(tag):
		return false

	var definition: Dictionary = {
		"tag": tag,
		"redirect_to": GFVariantData.get_option_string_name(options, "redirect_to"),
		"description": GFVariantData.get_option_string(options, "description"),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	tag_definitions.append(definition)
	_invalidate_cache()
	return true


## 添加标签重定向定义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_tag: 旧标签名。
## [br]
## @param target_tag: 目标标签名。
## [br]
## @param options: 定义选项，支持 description 和 metadata。
## [br]
## @return 添加成功返回 true。
## [br]
## @schema options: Dictionary redirect definition options.
func add_redirect(source_tag: StringName, target_tag: StringName, options: Dictionary = {}) -> bool:
	if source_tag == &"" or target_tag == &"" or has_tag(source_tag):
		return false

	var definition: Dictionary = {
		"tag": source_tag,
		"redirect_to": target_tag,
		"description": GFVariantData.get_option_string(options, "description"),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	tag_definitions.append(definition)
	_invalidate_cache()
	return true


## 检查目录中是否声明了标签。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param tag: 标签名。
## [br]
## @param include_redirects: 是否把重定向源也视作已声明。
## [br]
## @return 已声明返回 true。
func has_tag(tag: StringName, include_redirects: bool = true) -> bool:
	_ensure_cache()
	if _definition_lookup_cache.has(tag):
		return true
	if include_redirects:
		return _redirect_lookup_cache.has(tag)
	return false


## 获取标签定义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param tag: 标签名。
## [br]
## @param include_redirects: 是否允许返回重定向源定义。
## [br]
## @return 定义副本；未声明时返回空 Dictionary。
## [br]
## @schema return: Dictionary tag definition.
func get_tag_definition(tag: StringName, include_redirects: bool = true) -> Dictionary:
	_ensure_cache()
	var definition: Dictionary = GFVariantData.get_option_dictionary(_definition_lookup_cache, tag)
	if definition.is_empty() and include_redirects:
		definition = GFVariantData.get_option_dictionary(_redirect_lookup_cache, tag)
	return definition.duplicate(true)


## 获取所有正式标签名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 排序后的标签名，不包含重定向源。
func get_tags() -> PackedStringArray:
	_ensure_cache()
	var result: PackedStringArray = PackedStringArray()
	for tag_variant: Variant in _definition_lookup_cache.keys():
		var _appended: bool = result.append(GFVariantData.to_text(tag_variant))
	result.sort()
	return result


## 获取所有重定向源标签。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 排序后的重定向源标签。
func get_redirect_tags() -> PackedStringArray:
	_ensure_cache()
	var result: PackedStringArray = PackedStringArray()
	for tag_variant: Variant in _redirect_lookup_cache.keys():
		var _appended: bool = result.append(GFVariantData.to_text(tag_variant))
	result.sort()
	return result


## 解析标签重定向。
##
## 连续重定向会被追踪到最终目标；遇到循环或空标签时返回原始标签。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param tag: 原始标签。
## [br]
## @param max_depth: 最大重定向层数。
## [br]
## @return 解析后的标签。
func resolve_tag(tag: StringName, max_depth: int = 16) -> StringName:
	if tag == &"":
		return &""

	_ensure_cache()
	var current_tag: StringName = tag
	var seen: Dictionary = {}
	var remaining: int = maxi(max_depth, 1)
	while remaining > 0 and _redirect_lookup_cache.has(current_tag):
		if seen.has(current_tag):
			return tag
		seen[current_tag] = true
		var definition: Dictionary = GFVariantData.get_option_dictionary(_redirect_lookup_cache, current_tag)
		var next_tag: StringName = GFVariantData.get_option_string_name(definition, "redirect_to")
		if next_tag == &"" or next_tag == current_tag:
			return tag
		current_tag = next_tag
		remaining -= 1
	if _redirect_lookup_cache.has(current_tag):
		return tag
	return current_tag


## 规范化标签源。
##
## 会读取任意 GFTagSourceAdapter 支持的来源，解析重定向并合并重复标签层数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source: 标签源。
## [br]
## @param options: 规范化选项，支持 drop_undefined 和 max_redirect_depth。
## [br]
## @return 新的标签集合。
## [br]
## @schema source: Variant accepted by GFTagSourceAdapter.
## [br]
## @schema options: Dictionary normalization options.
func normalize_tag_source(source: Variant, options: Dictionary = {}) -> GFTagSet:
	var result: GFTagSet = GFTagSet.new()
	var drop_undefined: bool = GFVariantData.get_option_bool(options, "drop_undefined", false)
	var max_redirect_depth: int = GFVariantData.get_option_int(options, "max_redirect_depth", 16)
	var counts: Dictionary = GFTagSourceAdapter.get_tag_counts(source)
	for tag_variant: Variant in counts.keys():
		var source_tag: StringName = GFVariantData.to_string_name(tag_variant)
		var resolved_tag: StringName = resolve_tag(source_tag, max_redirect_depth)
		if drop_undefined and not has_tag(resolved_tag, false):
			continue
		var count: int = GFVariantData.to_int(counts[tag_variant])
		var _tag_added: GFTagSet = result.add_tag(resolved_tag, count)
	return result


## 校验标签源是否满足目录声明。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source: 标签源。
## [br]
## @param options: 校验选项，支持 subject、allow_undefined_tags 和 max_redirect_depth。
## [br]
## @return 校验报告。
## [br]
## @schema source: Variant accepted by GFTagSourceAdapter.
## [br]
## @schema options: Dictionary validation options.
func validate_tag_source(source: Variant, options: Dictionary = {}) -> GFValidationReport:
	var subject: String = GFVariantData.get_option_string(options, "subject", String(catalog_id))
	var report: GFValidationReport = GFValidationReport.new(subject, {
		"catalog_id": catalog_id,
	})
	var allowed_unknown: bool = GFVariantData.get_option_bool(options, "allow_undefined_tags", allow_undefined_tags)
	var max_redirect_depth: int = GFVariantData.get_option_int(options, "max_redirect_depth", 16)
	var counts: Dictionary = GFTagSourceAdapter.get_tag_counts(source)
	for tag_variant: Variant in counts.keys():
		var source_tag: StringName = GFVariantData.to_string_name(tag_variant)
		var resolved_tag: StringName = resolve_tag(source_tag, max_redirect_depth)
		if resolved_tag != source_tag:
			var _redirect_issue: RefCounted = report.add_info(
				&"redirected_tag",
				"tag is redirected by catalog.",
				source_tag,
				"",
				{
					"source_tag": source_tag,
					"resolved_tag": resolved_tag,
				}
			)
		if not allowed_unknown and not has_tag(resolved_tag, false):
			var _undefined_issue: RefCounted = report.add_error(
				&"undefined_tag",
				"tag is not declared in catalog.",
				source_tag,
				"",
				{
					"source_tag": source_tag,
					"resolved_tag": resolved_tag,
				}
			)
	return report


## 校验目录定义自身。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 校验选项，支持 subject。
## [br]
## @return 校验报告。
## [br]
## @schema options: Dictionary validation options.
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
	var subject: String = GFVariantData.get_option_string(options, "subject", String(catalog_id))
	var report: GFValidationReport = GFValidationReport.new(subject, {
		"catalog_id": catalog_id,
	})
	var seen_tags: Dictionary = {}
	var target_tags: Dictionary = {}
	for definition: Dictionary in tag_definitions:
		var tag: StringName = _definition_tag(definition)
		if tag == &"":
			var _empty_issue: RefCounted = report.add_error(&"empty_tag", "tag definition must declare a tag.")
			continue
		if seen_tags.has(tag):
			var _duplicate_issue: RefCounted = report.add_error(&"duplicate_tag", "tag definition is duplicated.", tag)
		seen_tags[tag] = true
		var redirect_to: StringName = _definition_redirect(definition)
		if redirect_to != &"":
			target_tags[redirect_to] = true

	_ensure_cache()
	for source_tag_variant: Variant in _redirect_lookup_cache.keys():
		var source_tag: StringName = GFVariantData.to_string_name(source_tag_variant)
		var resolved_tag: StringName = resolve_tag(source_tag)
		if resolved_tag == source_tag:
			var _cycle_issue: RefCounted = report.add_error(&"redirect_cycle", "tag redirect chain is cyclic or invalid.", source_tag)

	for target_tag_variant: Variant in target_tags.keys():
		var target_tag: StringName = GFVariantData.to_string_name(target_tag_variant)
		if not seen_tags.has(target_tag):
			var _missing_issue: RefCounted = report.add_warning(&"missing_redirect_target", "redirect target is not declared in catalog.", target_tag)
	return report


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新标签目录。
func duplicate_catalog() -> GFTagCatalog:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	catalog.catalog_id = catalog_id
	catalog.allow_undefined_tags = allow_undefined_tags
	catalog.metadata = metadata.duplicate(true)
	for definition: Dictionary in tag_definitions:
		catalog.tag_definitions.append(definition.duplicate(true))
	return catalog


## 导出为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 标签目录字典。
## [br]
## @schema return: Dictionary serialized tag catalog.
func to_dictionary() -> Dictionary:
	var definitions: Array[Dictionary] = []
	for definition: Dictionary in tag_definitions:
		definitions.append(definition.duplicate(true))
	return {
		"catalog_id": catalog_id,
		"tag_definitions": definitions,
		"allow_undefined_tags": allow_undefined_tags,
		"metadata": metadata.duplicate(true),
	}


## 从字典创建标签目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 标签目录字典。
## [br]
## @return 新标签目录。
## [br]
## @schema data: Dictionary serialized tag catalog.
static func from_dictionary(data: Dictionary) -> GFTagCatalog:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var definitions: Array[Dictionary] = []
	var raw_definitions: Array = GFVariantData.get_option_array(data, "tag_definitions")
	for definition_value: Variant in raw_definitions:
		definitions.append(GFVariantData.as_dictionary(definition_value))
	var _configured: GFTagCatalog = catalog.configure(
		GFVariantData.get_option_string_name(data, "catalog_id"),
		definitions,
		{
			"allow_undefined_tags": GFVariantData.get_option_bool(data, "allow_undefined_tags", true),
			"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
		}
	)
	return catalog


# --- 私有/辅助方法 ---

func _ensure_cache() -> void:
	var signature: String = _make_catalog_signature()
	if signature == _catalog_signature:
		return

	_definition_lookup_cache = {}
	_redirect_lookup_cache = {}
	for definition: Dictionary in tag_definitions:
		var tag: StringName = _definition_tag(definition)
		if tag == &"":
			continue
		var normalized: Dictionary = _normalize_definition(definition)
		var redirect_to: StringName = GFVariantData.get_option_string_name(normalized, "redirect_to")
		if redirect_to == &"":
			_definition_lookup_cache[tag] = normalized
		else:
			_redirect_lookup_cache[tag] = normalized
	_catalog_signature = signature


func _invalidate_cache() -> void:
	_catalog_signature = ""
	_definition_lookup_cache.clear()
	_redirect_lookup_cache.clear()


func _make_catalog_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for definition: Dictionary in tag_definitions:
		var tag: String = String(_definition_tag(definition))
		var redirect_to: String = String(_definition_redirect(definition))
		var description: String = GFVariantData.get_option_string(definition, "description")
		var metadata_text: String = str(GFVariantData.get_option_dictionary(definition, "metadata"))
		var _part_appended: bool = parts.append("%d:%s>%d:%s#%d:%s@%d:%s" % [
			tag.length(),
			tag,
			redirect_to.length(),
			redirect_to,
			description.length(),
			description,
			metadata_text.length(),
			metadata_text,
		])
	parts.sort()
	return "|".join(parts)


func _normalize_definition(definition: Dictionary) -> Dictionary:
	return {
		"tag": _definition_tag(definition),
		"redirect_to": _definition_redirect(definition),
		"description": GFVariantData.get_option_string(definition, "description"),
		"metadata": GFVariantData.get_option_dictionary(definition, "metadata"),
	}


func _definition_tag(definition: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(definition, "tag")


func _definition_redirect(definition: Dictionary) -> StringName:
	if definition.has("redirect_to"):
		return GFVariantData.get_option_string_name(definition, "redirect_to")
	return GFVariantData.get_option_string_name(definition, "redirect")
