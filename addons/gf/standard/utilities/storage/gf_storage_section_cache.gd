## GFStorageSectionCache: 通用分区数据脏标记缓存。
##
## 用 scope_id + section_id 管理 Dictionary 分区，记录哪些分区被修改，并可生成只包含脏分区的
## 存储载荷。它不定义存档字段、业务模块或 UI，只负责分区缓存和脏状态机制。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFStorageSectionCache
extends RefCounted


# --- 私有变量 ---

var _scopes: Dictionary = {}


# --- 公共方法 ---

## 写入一个分区。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param section_id: 分区标识。
## [br]
## @param data: 分区数据。
## [br]
## @param mark_dirty: 为 true 时把分区标记为脏。
## [br]
## @return 写入成功返回 true。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
## [br]
## @schema data: Dictionary，调用方定义的分区载荷。
func write_section(scope_id: Variant, section_id: StringName, data: Dictionary, mark_dirty: bool = true) -> bool:
	if section_id == &"":
		return false

	var record: Dictionary = _get_or_create_scope_record(scope_id)
	var sections: Dictionary = _get_record_sections(record)
	sections[section_id] = data.duplicate(true)
	if mark_dirty:
		_get_record_dirty_sections(record)[section_id] = true
	return true


## 合并一个分区的补丁数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param section_id: 分区标识。
## [br]
## @param patch: 要合并到分区内的数据。
## [br]
## @param deep: 是否深合并嵌套 Dictionary。
## [br]
## @param mark_dirty: 为 true 时把分区标记为脏。
## [br]
## @return 合并后的分区副本。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
## [br]
## @schema patch: Dictionary，调用方定义的分区补丁。
## [br]
## @schema return: Dictionary，合并后的分区数据副本。
func merge_section(
	scope_id: Variant,
	section_id: StringName,
	patch: Dictionary,
	deep: bool = true,
	mark_dirty: bool = true
) -> Dictionary:
	var current: Dictionary = read_section(scope_id, section_id)
	current.merge(patch.duplicate(true), true)
	if deep:
		current = _deep_merge_dictionaries(read_section(scope_id, section_id), patch)
	var _write_ok: bool = write_section(scope_id, section_id, current, mark_dirty)
	return current.duplicate(true)


## 读取一个分区。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param section_id: 分区标识。
## [br]
## @param duplicate_value: 为 true 时返回深拷贝。
## [br]
## @return 分区数据；不存在时返回空字典。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
## [br]
## @schema return: Dictionary，调用方定义的分区载荷。
func read_section(scope_id: Variant, section_id: StringName, duplicate_value: bool = true) -> Dictionary:
	var record: Dictionary = _get_scope_record(scope_id)
	if record.is_empty():
		return {}
	var sections: Dictionary = _get_record_sections(record)
	if not sections.has(section_id):
		return {}
	var data: Dictionary = GFVariantData.get_option_dictionary(sections, section_id)
	return data.duplicate(true) if duplicate_value else data


## 检查分区是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param section_id: 分区标识。
## [br]
## @return 存在返回 true。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
func has_section(scope_id: Variant, section_id: StringName) -> bool:
	var record: Dictionary = _get_scope_record(scope_id)
	return not record.is_empty() and _get_record_sections(record).has(section_id)


## 获取作用域内的分区字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param only_dirty: 为 true 时只返回脏分区。
## [br]
## @return 分区字典副本。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，分区 ID 到分区载荷的映射。
func get_sections(scope_id: Variant, only_dirty: bool = false) -> Dictionary:
	var record: Dictionary = _get_scope_record(scope_id)
	if record.is_empty():
		return {}

	var sections: Dictionary = _get_record_sections(record)
	if not only_dirty:
		return sections.duplicate(true)

	var dirty_sections: Dictionary = _get_record_dirty_sections(record)
	var result: Dictionary = {}
	for section_id: Variant in dirty_sections.keys():
		if sections.has(section_id):
			result[section_id] = GFVariantData.get_option_dictionary(sections, section_id)
	return result.duplicate(true)


## 获取作用域内的分区 ID 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @return 分区 ID 列表。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
func get_section_ids(scope_id: Variant) -> PackedStringArray:
	var record: Dictionary = _get_scope_record(scope_id)
	if record.is_empty():
		return PackedStringArray()
	return _dictionary_keys_to_sorted_strings(_get_record_sections(record))


## 获取作用域内的脏分区 ID 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @return 脏分区 ID 列表。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
func get_dirty_sections(scope_id: Variant) -> PackedStringArray:
	var record: Dictionary = _get_scope_record(scope_id)
	if record.is_empty():
		return PackedStringArray()
	return _dictionary_keys_to_sorted_strings(_get_record_dirty_sections(record))


## 检查作用域或分区是否存在脏数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param section_id: 分区标识；为空时检查整个作用域。
## [br]
## @return 存在脏数据返回 true。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
func is_dirty(scope_id: Variant, section_id: StringName = &"") -> bool:
	var record: Dictionary = _get_scope_record(scope_id)
	if record.is_empty():
		return false
	var dirty_sections: Dictionary = _get_record_dirty_sections(record)
	return not dirty_sections.is_empty() if section_id == &"" else dirty_sections.has(section_id)


## 标记分区为干净。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param section_ids: 要清理的分区；为空时清理整个作用域。
## [br]
## @return 被清理的脏分区数量。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
func mark_clean(scope_id: Variant, section_ids: PackedStringArray = PackedStringArray()) -> int:
	var record: Dictionary = _get_scope_record(scope_id)
	if record.is_empty():
		return 0

	var dirty_sections: Dictionary = _get_record_dirty_sections(record)
	if section_ids.is_empty():
		var count: int = dirty_sections.size()
		dirty_sections.clear()
		return count

	var cleaned_count: int = 0
	for section_id: String in section_ids:
		if dirty_sections.erase(StringName(section_id)):
			cleaned_count += 1
	return cleaned_count


## 从 payload 填充作用域。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param payload: 带 sections 字段的载荷，或直接作为分区字典使用的载荷。
## [br]
## @param mark_dirty: 为 true 时把导入分区标记为脏。
## [br]
## @return 导入的分区数量。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
## [br]
## @schema payload: Dictionary，包含 sections 字段或直接为 Dictionary[StringName, Dictionary]。
func apply_payload(scope_id: Variant, payload: Dictionary, mark_dirty: bool = false) -> int:
	var sections_value: Variant = GFVariantData.get_option_value(payload, "sections", payload)
	var sections: Dictionary = GFVariantData.to_dictionary(sections_value)
	var count: int = 0
	for section_key: Variant in sections.keys():
		var section_id: StringName = GFVariantData.to_string_name(section_key)
		if write_section(scope_id, section_id, GFVariantData.get_option_dictionary(sections, section_key), mark_dirty):
			count += 1
	return count


## 构建适合交给存储层保存的分区载荷。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @param include_clean: 为 true 时包含所有分区；为 false 时只包含脏分区。
## [br]
## @param mark_clean_after_build: 为 true 时构建后清理对应脏标记。
## [br]
## @return 分区载荷。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
## [br]
## @schema return: Dictionary，包含 scope_id、sections、dirty_sections 和 include_clean。
func build_payload(
	scope_id: Variant,
	include_clean: bool = false,
	mark_clean_after_build: bool = false
) -> Dictionary:
	var sections: Dictionary = get_sections(scope_id, not include_clean)
	var dirty_sections: PackedStringArray = get_dirty_sections(scope_id)
	var payload: Dictionary = {
		"scope_id": scope_id,
		"sections": sections,
		"dirty_sections": dirty_sections,
		"include_clean": include_clean,
	}
	if mark_clean_after_build:
		if include_clean:
			var _all_cleaned: int = mark_clean(scope_id)
		else:
			var _dirty_cleaned: int = mark_clean(scope_id, dirty_sections)
	return payload


## 移除一个作用域。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 调用方定义的作用域标识。
## [br]
## @return 存在并移除时返回 true。
## [br]
## @schema scope_id: Variant，建议使用 String、StringName 或 int 等稳定值。
func evict_scope(scope_id: Variant) -> bool:
	return _scopes.erase(_make_scope_key(scope_id))


## 清空全部缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear() -> void:
	_scopes.clear()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 scope_count、section_count 和 dirty_section_count。
func get_debug_snapshot() -> Dictionary:
	var section_count: int = 0
	var dirty_section_count: int = 0
	for record_value: Variant in _scopes.values():
		var record: Dictionary = GFVariantData.to_dictionary(record_value)
		section_count += _get_record_sections(record).size()
		dirty_section_count += _get_record_dirty_sections(record).size()
	return {
		"scope_count": _scopes.size(),
		"section_count": section_count,
		"dirty_section_count": dirty_section_count,
	}


# --- 私有/辅助方法 ---

func _get_or_create_scope_record(scope_id: Variant) -> Dictionary:
	var key: String = _make_scope_key(scope_id)
	if not _scopes.has(key):
		_scopes[key] = {
			"scope_id": GFVariantData.duplicate_variant(scope_id),
			"sections": {},
			"dirty_sections": {},
		}
	return GFVariantData.as_dictionary(_scopes[key])


func _get_scope_record(scope_id: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(_scopes.get(_make_scope_key(scope_id), {}))


func _get_record_sections(record: Dictionary) -> Dictionary:
	if not record.has("sections") or not (record["sections"] is Dictionary):
		record["sections"] = {}
	return GFVariantData.as_dictionary(record["sections"])


func _get_record_dirty_sections(record: Dictionary) -> Dictionary:
	if not record.has("dirty_sections") or not (record["dirty_sections"] is Dictionary):
		record["dirty_sections"] = {}
	return GFVariantData.as_dictionary(record["dirty_sections"])


func _make_scope_key(scope_id: Variant) -> String:
	return var_to_str(scope_id)


func _dictionary_keys_to_sorted_strings(dictionary: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in dictionary.keys():
		var _append_result: bool = result.append(GFVariantData.to_text(key))
	result.sort()
	return result


func _deep_merge_dictionaries(base: Dictionary, patch: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in patch.keys():
		var patch_value: Variant = patch[key]
		if result.has(key) and result[key] is Dictionary and patch_value is Dictionary:
			result[key] = _deep_merge_dictionaries(
				GFVariantData.to_dictionary(result[key]),
				GFVariantData.to_dictionary(patch_value)
			)
		else:
			result[key] = GFVariantData.duplicate_variant(patch_value)
	return result
