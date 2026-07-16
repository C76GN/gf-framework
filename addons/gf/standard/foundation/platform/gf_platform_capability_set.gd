## GFPlatformCapabilitySet: 平台能力集合。
##
## 用纯数据描述某个运行平台或外部 adapter 暴露的能力及其限制。GF 不内置
## 具体平台表，调用方应使用稳定的业务无关能力 ID。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFPlatformCapabilitySet
extends Resource


# --- 导出变量 ---

## 平台标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var platform_id: StringName = &""

## Adapter 标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var adapter_id: StringName = &""

## 能力 ID 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var capabilities: PackedStringArray = PackedStringArray()

## 能力限制表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema limits: Dictionary[String, Dictionary]，key 为 capability_id。
@export var limits: Dictionary = {}

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置能力集合。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_platform_id: 平台标识。
## [br]
## @param p_capabilities: 能力 ID 列表。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @param p_adapter_id: Adapter 标识。
## [br]
## @schema p_metadata: Dictionary caller-defined metadata.
## [br]
## @return 当前能力集合。
func configure(
	p_platform_id: StringName,
	p_capabilities: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {},
	p_adapter_id: StringName = &""
) -> GFPlatformCapabilitySet:
	platform_id = p_platform_id
	adapter_id = p_adapter_id
	capabilities = _normalize_string_set(p_capabilities)
	limits.clear()
	metadata = p_metadata.duplicate(true)
	return self


## 清空能力集合。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear() -> void:
	platform_id = &""
	adapter_id = &""
	capabilities.clear()
	limits.clear()
	metadata.clear()


## 添加能力。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @param capability_limits: 能力限制字段。
## [br]
## @schema capability_limits: Dictionary capability limits.
## [br]
## @return 成功添加或已存在时返回 true。
func add_capability(capability_id: StringName, capability_limits: Dictionary = {}) -> bool:
	var normalized: String = _normalize_capability_id(capability_id)
	if normalized.is_empty():
		return false
	if not capabilities.has(normalized):
		var _appended: bool = capabilities.append(normalized)
		capabilities.sort()
	if not capability_limits.is_empty():
		limits[normalized] = capability_limits.duplicate(true)
	return true


## 移除能力。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @return 找到并移除时返回 true。
func remove_capability(capability_id: StringName) -> bool:
	var normalized: String = _normalize_capability_id(capability_id)
	if normalized.is_empty() or not capabilities.has(normalized):
		return false
	capabilities.remove_at(capabilities.find(normalized))
	var _erased: bool = limits.erase(normalized)
	return true


## 检查能力是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @return 存在返回 true。
func has_capability(capability_id: StringName) -> bool:
	return capabilities.has(_normalize_capability_id(capability_id))


## 检查是否包含全部能力。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param required_capabilities: 需要的能力 ID 列表。
## [br]
## @return 全部存在返回 true；空列表返回 true。
func has_all(required_capabilities: PackedStringArray) -> bool:
	for capability: String in required_capabilities:
		if not has_capability(StringName(capability)):
			return false
	return true


## 检查是否包含任一能力。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate_capabilities: 候选能力 ID 列表。
## [br]
## @return 任一存在返回 true；空列表返回 false。
func has_any(candidate_capabilities: PackedStringArray) -> bool:
	for capability: String in candidate_capabilities:
		if has_capability(StringName(capability)):
			return true
	return false


## 设置能力限制字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @param key: 限制字段名。
## [br]
## @param value: 限制字段值。
## [br]
## @schema value: Caller-defined limit value.
## [br]
## @return 写入成功返回 true。
func set_limit(capability_id: StringName, key: StringName, value: Variant) -> bool:
	var normalized: String = _normalize_capability_id(capability_id)
	var normalized_key: String = String(key).strip_edges()
	if normalized.is_empty() or normalized_key.is_empty():
		return false
	var capability_limits: Dictionary = get_capability_limits(capability_id)
	capability_limits[normalized_key] = GFVariantData.duplicate_variant(value)
	limits[normalized] = capability_limits
	var _capability_added: bool = add_capability(capability_id)
	return true


## 读取能力限制字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @param key: 限制字段名。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @schema default_value: Caller-defined default value.
## [br]
## @return 限制字段值。
## [br]
## @schema return: Caller-defined limit value.
func get_limit(capability_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	var capability_limits: Dictionary = get_capability_limits(capability_id)
	var normalized_key: String = String(key).strip_edges()
	if normalized_key.is_empty() or not capability_limits.has(normalized_key):
		return default_value
	return GFVariantData.duplicate_variant(capability_limits[normalized_key])


## 读取能力限制字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @return 能力限制字典副本。
## [br]
## @schema return: Dictionary capability limits.
func get_capability_limits(capability_id: StringName) -> Dictionary:
	var normalized: String = _normalize_capability_id(capability_id)
	if normalized.is_empty() or not limits.has(normalized):
		return {}
	return GFVariantData.to_dictionary(limits[normalized])


## 合并另一个能力集合。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param other: 另一个能力集合。
## [br]
## @param overwrite_existing: 是否覆盖已有限制和元数据字段。
## [br]
## @return 当前能力集合。
func merge_from(other: GFPlatformCapabilitySet, overwrite_existing: bool = true) -> GFPlatformCapabilitySet:
	if other == null:
		return self
	if platform_id == &"":
		platform_id = other.platform_id
	if adapter_id == &"":
		adapter_id = other.adapter_id
	for capability: String in other.capabilities:
		var _capability_added: bool = add_capability(StringName(capability))
	for capability_key: Variant in other.limits.keys():
		var normalized_key: String = str(capability_key).strip_edges()
		if normalized_key.is_empty():
			continue
		if overwrite_existing or not limits.has(normalized_key):
			limits[normalized_key] = GFVariantData.to_dictionary(other.limits[capability_key])
	for metadata_key: Variant in other.metadata.keys():
		if overwrite_existing or not metadata.has(metadata_key):
			metadata[metadata_key] = GFVariantData.duplicate_variant(other.metadata[metadata_key])
	return self


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 能力集合字典。
## [br]
## @schema return: Dictionary with platform_id, adapter_id, capabilities, limits, and metadata.
func to_dict() -> Dictionary:
	return {
		"platform_id": platform_id,
		"adapter_id": adapter_id,
		"capabilities": capabilities.duplicate(),
		"limits": limits.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用能力集合字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 能力集合字典。
## [br]
## @schema data: Dictionary with platform_id, adapter_id, capabilities, limits, and metadata.
func apply_dict(data: Dictionary) -> void:
	platform_id = GFVariantData.get_option_string_name(data, "platform_id")
	adapter_id = GFVariantData.get_option_string_name(data, "adapter_id")
	capabilities = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "capabilities"))
	limits = _normalize_limits(GFVariantData.get_option_dictionary(data, "limits"))
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建能力集合深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新能力集合。
func duplicate_set() -> GFPlatformCapabilitySet:
	return from_dict(to_dict())


## 从字典创建能力集合。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 能力集合字典。
## [br]
## @schema data: Dictionary with platform_id, adapter_id, capabilities, limits, and metadata.
## [br]
## @return 新能力集合。
static func from_dict(data: Dictionary) -> GFPlatformCapabilitySet:
	var result: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

static func _normalize_capability_id(capability_id: StringName) -> String:
	return String(capability_id).strip_edges()


static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	result.sort()
	return result


static func _normalize_limits(source_limits: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source_limits.keys():
		var normalized_key: String = str(key).strip_edges()
		if normalized_key.is_empty() or not (source_limits[key] is Dictionary):
			continue
		result[normalized_key] = GFVariantData.to_dictionary(source_limits[key])
	return result
