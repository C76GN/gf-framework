## GFNetworkLobbyDescriptor: 平台中立的 lobby 快照。
##
## 描述外部平台、局域网或自建服务中的房间状态。它只承载可复用的联机结构，
## 不把玩家准备、队伍、角色或具体玩法写入框架层。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFNetworkLobbyDescriptor
extends Resource


# --- 枚举 ---

## Lobby 可见性。
## [br]
## @api public
## [br]
## @since 8.0.0
enum Visibility {
	## 由 backend 或平台默认策略决定。
	DEFAULT,
	## 可公开查询。
	PUBLIC,
	## 仅好友、群组或平台关系可见。
	RELATIONSHIP,
	## 只能通过邀请或精确 ID 加入。
	PRIVATE,
	## 不可查询且不可加入。
	HIDDEN,
}


# --- 导出变量 ---

## Lobby 外部稳定 ID。动态平台 ID 使用 String 保存。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var lobby_id: String = ""

## 提供该 lobby 的 backend 标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var backend_id: StringName = &""

## 编辑器或 UI 可显示名称。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var display_name: String = ""

## owner 的传输 peer 标识。未知时为 -1。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var owner_peer_id: int = -1

## owner 的平台用户 ID。用于尚未建立传输连接但平台已返回 owner 的场景。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var owner_platform_user_id: String = ""

## 最大成员数。小于等于 0 表示 backend 未声明。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_members: int = 0

## 当前是否允许加入。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var joinable: bool = true

## Lobby 可见性。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var visibility: Visibility = Visibility.DEFAULT

## 成员列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema members: Array[GFNetworkLobbyMember] lobby member snapshots.
@export var members: Array[GFNetworkLobbyMember] = []

## Lobby 标签，用于轻量查询或展示。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var tags: PackedStringArray = PackedStringArray()

## 调用方自定义 lobby metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined lobby metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置 lobby 快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_lobby_id: Lobby 外部稳定 ID。
## [br]
## @param options: 可选字段，支持 backend_id、display_name、owner_peer_id、owner_platform_user_id、max_members、joinable、visibility、members、tags 和 metadata。
## [br]
## @schema options: Dictionary lobby fields.
## [br]
## @return 当前 lobby。
func configure(p_lobby_id: String, options: Dictionary = {}) -> GFNetworkLobbyDescriptor:
	lobby_id = p_lobby_id.strip_edges()
	backend_id = GFVariantData.get_option_string_name(options, "backend_id")
	display_name = GFVariantData.get_option_string(options, "display_name").strip_edges()
	owner_peer_id = GFVariantData.get_option_int(options, "owner_peer_id", -1)
	owner_platform_user_id = GFVariantData.get_option_string(options, "owner_platform_user_id").strip_edges()
	max_members = GFVariantData.get_option_int(options, "max_members", 0)
	joinable = GFVariantData.get_option_bool(options, "joinable", true)
	visibility = GFVariantData.get_option_int(options, "visibility", Visibility.DEFAULT) as Visibility
	members = _copy_members_from_array(GFVariantData.get_option_array(options, "members"))
	tags = _normalize_string_set(GFVariantData.get_option_packed_string_array(options, "tags"))
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 获取展示名称。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 展示名称。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not lobby_id.is_empty():
		return lobby_id
	return "Network Lobby"


## 获取成员数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 成员数量。
func get_member_count() -> int:
	var count: int = 0
	for member: GFNetworkLobbyMember in members:
		if member != null:
			count += 1
	return count


## 检查 lobby 是否已满。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 已满返回 true；未声明 max_members 时返回 false。
func is_full() -> bool:
	return max_members > 0 and get_member_count() >= max_members


## 获取成员。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param peer_id: 传输 peer 标识。
## [br]
## @return 成员；不存在时返回 null。
func get_member(peer_id: int) -> GFNetworkLobbyMember:
	for member: GFNetworkLobbyMember in members:
		if member != null and member.peer_id == peer_id:
			return member
	return null


## 设置或替换成员。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param member: 成员。
func set_member(member: GFNetworkLobbyMember) -> void:
	if member == null:
		return
	for index: int in range(members.size()):
		if members[index] != null and members[index].peer_id == member.peer_id:
			members[index] = member.duplicate_member()
			return
	members.append(member.duplicate_member())


## 移除成员。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param peer_id: 传输 peer 标识。
## [br]
## @return 找到并移除时返回 true。
func remove_member(peer_id: int) -> bool:
	for index: int in range(members.size()):
		if members[index] != null and members[index].peer_id == peer_id:
			members.remove_at(index)
			return true
	return false


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Lobby 字典。
## [br]
## @schema return: Dictionary with lobby_id, backend_id, display_name, owner_peer_id, owner_platform_user_id, max_members, joinable, visibility, members, tags, and metadata.
func to_dict() -> Dictionary:
	var member_entries: Array[Dictionary] = []
	for member: GFNetworkLobbyMember in members:
		if member != null:
			member_entries.append(member.to_dict())
	return {
		"lobby_id": lobby_id,
		"backend_id": backend_id,
		"display_name": display_name,
		"owner_peer_id": owner_peer_id,
		"owner_platform_user_id": owner_platform_user_id,
		"max_members": max_members,
		"joinable": joinable,
		"visibility": int(visibility),
		"members": member_entries,
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用 lobby 字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: Lobby 字典。
## [br]
## @schema data: Dictionary with lobby_id, backend_id, display_name, owner_peer_id, owner_platform_user_id, max_members, joinable, visibility, members, tags, and metadata.
func apply_dict(data: Dictionary) -> void:
	lobby_id = GFVariantData.get_option_string(data, "lobby_id").strip_edges()
	backend_id = GFVariantData.get_option_string_name(data, "backend_id")
	display_name = GFVariantData.get_option_string(data, "display_name").strip_edges()
	owner_peer_id = GFVariantData.get_option_int(data, "owner_peer_id", -1)
	owner_platform_user_id = GFVariantData.get_option_string(data, "owner_platform_user_id").strip_edges()
	max_members = GFVariantData.get_option_int(data, "max_members", 0)
	joinable = GFVariantData.get_option_bool(data, "joinable", true)
	visibility = GFVariantData.get_option_int(data, "visibility", Visibility.DEFAULT) as Visibility
	members = _copy_members_from_array(GFVariantData.get_option_array(data, "members"))
	tags = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "tags"))
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建 lobby 深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新 lobby。
func duplicate_lobby() -> GFNetworkLobbyDescriptor:
	var result: GFNetworkLobbyDescriptor = GFNetworkLobbyDescriptor.new()
	result.apply_dict(to_dict())
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary JSON-safe lobby debug snapshot.
func get_debug_snapshot() -> Dictionary:
	return GFNetworkDebugTools.sanitize_debug_dictionary(to_dict())


## 从字典创建 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: Lobby 字典。
## [br]
## @schema data: Dictionary with lobby_id, backend_id, display_name, owner_peer_id, owner_platform_user_id, max_members, joinable, visibility, members, tags, and metadata.
## [br]
## @return 新 lobby。
static func from_dict(data: Dictionary) -> GFNetworkLobbyDescriptor:
	var result: GFNetworkLobbyDescriptor = GFNetworkLobbyDescriptor.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

static func _copy_members_from_array(source_members: Array) -> Array[GFNetworkLobbyMember]:
	var result: Array[GFNetworkLobbyMember] = []
	for member_value: Variant in source_members:
		if member_value is GFNetworkLobbyMember:
			var member: GFNetworkLobbyMember = member_value
			result.append(member.duplicate_member())
		elif member_value is Dictionary:
			var member_data: Dictionary = member_value
			result.append(GFNetworkLobbyMember.from_dict(member_data))
	return result


static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	result.sort()
	return result
