## GFLayerMaskUtility: 层名与 bitmask 互转工具。
##
## 提供通用层名数组到整数 bitmask 的稳定转换，也可读取 Godot 项目的
## 2D / 3D Physics Layer Names。它只处理名称、索引和整数掩码，
## 不写入节点属性，也不绑定具体碰撞、射线、阵营或玩法语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.21.0
class_name GFLayerMaskUtility
extends RefCounted


# --- 常量 ---

## Godot 物理层 bitmask 的默认层数量。
## [br]
## @api public
const DEFAULT_LAYER_COUNT: int = 32

## 无效层索引哨兵值。
## [br]
## @api public
const INVALID_LAYER_INDEX: int = -1


# --- 公共方法 ---

## 将层名列表转换为 bitmask。
## [br]
## @api public
## [br]
## @param names: 要启用的层名列表。
## [br]
## @schema names: Array of String or StringName layer names.
## [br]
## @param layer_names: 按层索引排列的层名表；索引 0 对应第 1 层。
## [br]
## @schema layer_names: Array of String or StringName layer names ordered by layer index.
## [br]
## @param case_sensitive: 是否区分大小写。
## [br]
## @return 对应 bitmask；未知名称会被忽略。
static func names_to_mask(names: Array, layer_names: Array, case_sensitive: bool = true) -> int:
	var mask: int = 0
	for name_variant: Variant in names:
		var layer_name: String = GFVariantData.to_text(name_variant)
		if layer_name.is_empty():
			continue
		var layer_index: int = find_layer_index(layer_name, layer_names, case_sensitive)
		if layer_index != INVALID_LAYER_INDEX:
			mask |= layer_index_to_mask(layer_index)
	return mask


## 将 bitmask 转换为层名列表。
## [br]
## @api public
## [br]
## @param mask: 要解析的 bitmask。
## [br]
## @param layer_names: 按层索引排列的层名表；索引 0 对应第 1 层。
## [br]
## @schema layer_names: Array of String or StringName layer names ordered by layer index.
## [br]
## @param include_unnamed: 是否为未命名但启用的层返回默认名称。
## [br]
## @return 按层索引排序的层名列表。
static func mask_to_names(mask: int, layer_names: Array, include_unnamed: bool = false) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var layer_count: int = DEFAULT_LAYER_COUNT if include_unnamed else mini(layer_names.size(), DEFAULT_LAYER_COUNT)
	for layer_index: int in range(layer_count):
		if mask & layer_index_to_mask(layer_index) == 0:
			continue
		var layer_name: String = _get_layer_name(layer_names, layer_index)
		if layer_name.is_empty() and include_unnamed:
			layer_name = _make_default_layer_name(layer_index)
		if not layer_name.is_empty():
			var _appended: bool = result.append(layer_name)
	return result


## 查找层名对应的零基索引。
## [br]
## @api public
## [br]
## @param layer_name: 要查找的层名。
## [br]
## @param layer_names: 按层索引排列的层名表；索引 0 对应第 1 层。
## [br]
## @schema layer_names: Array of String or StringName layer names ordered by layer index.
## [br]
## @param case_sensitive: 是否区分大小写。
## [br]
## @return 找到时返回零基索引；否则返回 INVALID_LAYER_INDEX。
static func find_layer_index(layer_name: String, layer_names: Array, case_sensitive: bool = true) -> int:
	if layer_name.is_empty():
		return INVALID_LAYER_INDEX

	var expected: String = layer_name if case_sensitive else layer_name.to_lower()
	var layer_count: int = mini(layer_names.size(), DEFAULT_LAYER_COUNT)
	for layer_index: int in range(layer_count):
		var candidate: String = _get_layer_name(layer_names, layer_index)
		if candidate.is_empty():
			continue
		if not case_sensitive:
			candidate = candidate.to_lower()
		if candidate == expected:
			return layer_index
	return INVALID_LAYER_INDEX


## 将零基层索引转换为单层 bitmask。
## [br]
## @api public
## [br]
## @param layer_index: 零基层索引。
## [br]
## @return 对应单层 bitmask；无效索引返回 0。
static func layer_index_to_mask(layer_index: int) -> int:
	if not is_layer_index_valid(layer_index):
		return 0
	return 1 << layer_index


## 判断零基层索引是否在有效范围内。
## [br]
## @api public
## [br]
## @param layer_index: 零基层索引。
## [br]
## @param layer_count: 可用层数量，上限为 DEFAULT_LAYER_COUNT。
## [br]
## @return 有效时返回 true。
static func is_layer_index_valid(layer_index: int, layer_count: int = DEFAULT_LAYER_COUNT) -> bool:
	var limit: int = clampi(layer_count, 0, DEFAULT_LAYER_COUNT)
	return layer_index >= 0 and layer_index < limit


## 获取输入层名中无法解析的名称。
## [br]
## @api public
## [br]
## @param names: 要检查的层名列表。
## [br]
## @schema names: Array of String or StringName layer names.
## [br]
## @param layer_names: 按层索引排列的层名表；索引 0 对应第 1 层。
## [br]
## @schema layer_names: Array of String or StringName layer names ordered by layer index.
## [br]
## @param case_sensitive: 是否区分大小写。
## [br]
## @return 未找到的层名列表，按首次出现顺序去重。
static func get_missing_names(names: Array, layer_names: Array, case_sensitive: bool = true) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for name_variant: Variant in names:
		var layer_name: String = GFVariantData.to_text(name_variant)
		if layer_name.is_empty():
			continue
		var seen_key: String = layer_name if case_sensitive else layer_name.to_lower()
		if seen.has(seen_key):
			continue
		seen[seen_key] = true
		if find_layer_index(layer_name, layer_names, case_sensitive) == INVALID_LAYER_INDEX:
			var _appended: bool = result.append(layer_name)
	return result


## 读取项目的 2D 或 3D 物理层名称。
## [br]
## @api public
## [br]
## @param dimension: 物理维度，只支持 2 或 3。
## [br]
## @param fallback_to_default_names: 未命名层是否返回 `Layer N`。
## [br]
## @return 长度为 DEFAULT_LAYER_COUNT 的层名列表；维度无效时返回空列表。
static func get_project_physics_layer_names(
	dimension: int = 2,
	fallback_to_default_names: bool = false
) -> PackedStringArray:
	if dimension != 2 and dimension != 3:
		return PackedStringArray()

	var result: PackedStringArray = PackedStringArray()
	var prefix: String = "layer_names/%dd_physics/layer_" % dimension
	for layer_number: int in range(1, DEFAULT_LAYER_COUNT + 1):
		var setting_path: String = "%s%d" % [prefix, layer_number]
		var layer_name: String = ""
		if ProjectSettings.has_setting(setting_path):
			layer_name = GFVariantData.to_text(ProjectSettings.get_setting(setting_path))
		if layer_name.is_empty() and fallback_to_default_names:
			layer_name = _make_default_layer_name(layer_number - 1)
		var _appended: bool = result.append(layer_name)
	return result


# --- 私有/辅助方法 ---

## 安全读取指定零基层索引的名称；越界返回空字符串，其它值转为文本。
## [br]
## @api private
## [br]
static func _get_layer_name(layer_names: Array, layer_index: int) -> String:
	if layer_index < 0 or layer_index >= layer_names.size():
		return ""
	return GFVariantData.to_text(layer_names[layer_index])


## 按零基索引生成面向用户的一基默认名称，例如 Layer 1。
## [br]
## @api private
## [br]
static func _make_default_layer_name(layer_index: int) -> String:
	return "Layer %d" % (layer_index + 1)
