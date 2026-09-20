## GFTagComponent: 标签组件。
## 
## 基于 StringName 管理实体的标签及层数（如 &"State.Stun", &"Element.Fire"）。
## 标签系统通常用于技能释放前提检查、伤害加成判定等。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFTagComponent
extends RefCounted


# --- 信号 ---

## 当标签层数发生变化时发出。
## [br]
## @api public
## [br]
## @param tag_name: 标签名。
## [br]
## @param count: 变化后的最终层数。
signal tag_changed(tag_name: StringName, count: int)


# --- 私有变量 ---

var _tags: Dictionary = {}


# --- 公共方法 ---

## 添加标签。
## [br]
## @api public
## [br]
## @param p_tag: 标签名。
## [br]
## @param p_count: 增加的层数。
func add_tag(p_tag: StringName, p_count: int = 1) -> void:
	if p_count <= 0:
		return
		
	var current: int = GFVariantData.get_option_int(_tags, p_tag, 0)
	_tags[p_tag] = current + p_count
	tag_changed.emit(p_tag, _tags[p_tag])


## 移除标签或减少层数。
## [br]
## @api public
## [br]
## @param p_tag: 标签名。
## [br]
## @param p_count: 减少的层数，如果为 -1 则直接完全移除。
func remove_tag(p_tag: StringName, p_count: int = 1) -> void:
	if not _tags.has(p_tag):
		return

	if p_count == -1:
		var _erase_result_62: Variant = _tags.erase(p_tag)
		tag_changed.emit(p_tag, 0)
		return

	if p_count <= 0:
		push_warning("[GFTagComponent][tag_component.invalid_removal_count] remove_tag received an invalid stack count; use a positive number or -1.")
		return

	var current: int = _tags[p_tag]
	var updated: int = current - p_count
	
	if updated <= 0:
		var _erase_result_74: Variant = _tags.erase(p_tag)
		tag_changed.emit(p_tag, 0)
	else:
		_tags[p_tag] = updated
		tag_changed.emit(p_tag, updated)


## 检查是否拥有指定标签且层数达到要求。
## [br]
## @api public
## [br]
## @param p_tag: 标签名。
## [br]
## @param p_min_count: 要求的最小层数。
## [br]
## @return: 拥有指定标签且层数不低于要求时返回 true。
func has_tag(p_tag: StringName, p_min_count: int = 1) -> bool:
	return GFVariantData.get_option_int(_tags, p_tag, 0) >= p_min_count


## 获取标签的当前层数。
## [br]
## @api public
## [br]
## @param p_tag: 标签名。
## [br]
## @return: 当前标签层数；不存在时返回 0。
func get_tag_count(p_tag: StringName) -> int:
	return GFVariantData.get_option_int(_tags, p_tag, 0)


## 获取当前持有的标签名。
## [br]
## @api public
## [br]
## @return 排序后的标签名。
func get_tags() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for tag_variant: Variant in _tags.keys():
		if GFVariantData.get_option_int(_tags, tag_variant, 0) > 0:
			var _append_result_114: Variant = result.append(GFVariantData.to_text(tag_variant))
	result.sort()
	return result


## 获取标签层数快照。
## [br]
## @api public
## [br]
## @return 标签层数字典副本。
## [br]
## @schema return: Dictionary，键为标签名，值为当前层数。
func get_tag_snapshot() -> Dictionary:
	return _tags.duplicate(true)


## 清空所有标签。
## [br]
## @api public
func clear_all() -> void:
	var keys: Array = _tags.keys()
	_tags.clear()
	for tag_variant: Variant in keys:
		tag_changed.emit(GFVariantData.to_string_name(tag_variant), 0)
