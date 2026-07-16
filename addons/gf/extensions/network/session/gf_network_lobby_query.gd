## GFNetworkLobbyQuery: 平台中立的 lobby 查询条件。
##
## 查询对象只描述通用过滤条件，由具体 backend 决定如何映射到平台查询、
## 局域网发现或自建服务请求。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFNetworkLobbyQuery
extends Resource


# --- 导出变量 ---

## 查询稳定标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var query_id: StringName = &""

## 可选搜索文本。backend 可用它匹配显示名或平台自定义字段。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var search_text: String = ""

## 必须同时具备的 tag。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var required_tags: PackedStringArray = PackedStringArray()

## 必须匹配的 metadata 键值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema required_metadata: Dictionary metadata key/value filters.
@export var required_metadata: Dictionary = {}

## 最大结果数。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_results: int = 0

## 是否包含已满 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var include_full_lobbies: bool = false

## 是否包含不可加入 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var include_unjoinable_lobbies: bool = false

## 调用方自定义查询选项。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined query metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查 lobby 是否满足本地可判断的查询条件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby: Lobby 快照。
## [br]
## @return 满足条件返回 true。
func matches(lobby: GFNetworkLobbyDescriptor) -> bool:
	if lobby == null:
		return false
	if not include_full_lobbies and lobby.is_full():
		return false
	if not include_unjoinable_lobbies and not lobby.joinable:
		return false
	var normalized_search: String = search_text.strip_edges().to_lower()
	if not normalized_search.is_empty() and not lobby.get_display_name().to_lower().contains(normalized_search):
		return false
	for tag: String in required_tags:
		if not lobby.tags.has(tag):
			return false
	for key: Variant in required_metadata.keys():
		if not lobby.metadata.has(key) or lobby.metadata[key] != required_metadata[key]:
			return false
	return true


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 查询字典。
## [br]
## @schema return: Dictionary with query_id, search_text, required_tags, required_metadata, max_results, include_full_lobbies, include_unjoinable_lobbies, and metadata.
func to_dict() -> Dictionary:
	return {
		"query_id": query_id,
		"search_text": search_text,
		"required_tags": required_tags.duplicate(),
		"required_metadata": required_metadata.duplicate(true),
		"max_results": max_results,
		"include_full_lobbies": include_full_lobbies,
		"include_unjoinable_lobbies": include_unjoinable_lobbies,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用查询字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 查询字典。
## [br]
## @schema data: Dictionary with query_id, search_text, required_tags, required_metadata, max_results, include_full_lobbies, include_unjoinable_lobbies, and metadata.
func apply_dict(data: Dictionary) -> void:
	query_id = GFVariantData.get_option_string_name(data, "query_id")
	search_text = GFVariantData.get_option_string(data, "search_text")
	required_tags = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "required_tags"))
	required_metadata = GFVariantData.get_option_dictionary(data, "required_metadata")
	max_results = GFVariantData.get_option_int(data, "max_results", 0)
	include_full_lobbies = GFVariantData.get_option_bool(data, "include_full_lobbies", false)
	include_unjoinable_lobbies = GFVariantData.get_option_bool(data, "include_unjoinable_lobbies", false)
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建查询深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新查询。
func duplicate_query() -> GFNetworkLobbyQuery:
	var result: GFNetworkLobbyQuery = GFNetworkLobbyQuery.new()
	result.apply_dict(to_dict())
	return result


## 从字典创建查询。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 查询字典。
## [br]
## @schema data: Dictionary with query_id, search_text, required_tags, required_metadata, max_results, include_full_lobbies, include_unjoinable_lobbies, and metadata.
## [br]
## @return 新查询。
static func from_dict(data: Dictionary) -> GFNetworkLobbyQuery:
	var result: GFNetworkLobbyQuery = GFNetworkLobbyQuery.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	result.sort()
	return result
