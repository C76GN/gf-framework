## GFNetworkPeerIdentity: 网络 peer 与外部平台账号之间的中立身份描述。
##
## 该资源只保存传输 peer、平台账号和展示元信息之间的映射，不绑定 Steam、微信、
## Epic、自建账号或任何具体平台 SDK。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFNetworkPeerIdentity
extends Resource


# --- 导出变量 ---

## 传输层 peer 标识。-1 表示未知或尚未绑定传输连接。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var peer_id: int = -1

## 平台标识，例如 steam、wechat、lan 或 custom。GF 不解释具体平台语义。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var platform_id: StringName = &""

## 平台侧用户标识。动态外部 ID 使用 String 保存，避免把第三方账号体系写入 GF 类型系统。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var platform_user_id: String = ""

## 面向 UI 的显示名。框架不保证唯一性。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var display_name: String = ""

## 可选头像或资料图标 URI。由项目或 adapter 解释。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var avatar_uri: String = ""

## 身份具备的平台能力标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var capabilities: PackedStringArray = PackedStringArray()

## 调用方自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined identity metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置身份资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_peer_id: 传输层 peer 标识。
## [br]
## @param p_platform_id: 平台标识。
## [br]
## @param p_platform_user_id: 平台侧用户标识。
## [br]
## @param p_display_name: 显示名。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @param p_capabilities: 平台能力标识列表。
## [br]
## @schema p_metadata: Dictionary caller-defined identity metadata.
## [br]
## @return 当前身份资源。
func configure(
	p_peer_id: int = -1,
	p_platform_id: StringName = &"",
	p_platform_user_id: String = "",
	p_display_name: String = "",
	p_metadata: Dictionary = {},
	p_capabilities: PackedStringArray = PackedStringArray()
) -> GFNetworkPeerIdentity:
	peer_id = p_peer_id
	platform_id = p_platform_id
	platform_user_id = p_platform_user_id.strip_edges()
	display_name = p_display_name.strip_edges()
	metadata = p_metadata.duplicate(true)
	capabilities = _normalize_string_set(p_capabilities)
	return self


## 添加能力标识。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力标识。
## [br]
## @return 成功添加或已存在时返回 true。
func add_capability(capability_id: StringName) -> bool:
	var normalized: String = String(capability_id).strip_edges()
	if normalized.is_empty():
		return false
	if not capabilities.has(normalized):
		var _appended: bool = capabilities.append(normalized)
		capabilities.sort()
	return true


## 检查能力标识是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力标识。
## [br]
## @return 存在返回 true。
func has_capability(capability_id: StringName) -> bool:
	return capabilities.has(String(capability_id).strip_edges())


## 获取稳定身份 key。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 身份 key；优先使用 platform_id:platform_user_id，缺失时回退到 peer:<peer_id>。
func get_stable_key() -> String:
	if platform_id != &"" and not platform_user_id.is_empty():
		return "%s:%s" % [String(platform_id), platform_user_id]
	if peer_id >= 0:
		return "peer:%d" % peer_id
	return ""


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 身份字典。
## [br]
## @schema return: Dictionary with peer_id, platform_id, platform_user_id, display_name, avatar_uri, capabilities, and metadata.
func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"platform_id": platform_id,
		"platform_user_id": platform_user_id,
		"display_name": display_name,
		"avatar_uri": avatar_uri,
		"capabilities": capabilities.duplicate(),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用身份字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 身份字典。
## [br]
## @schema data: Dictionary with peer_id, platform_id, platform_user_id, display_name, avatar_uri, capabilities, and metadata.
func apply_dict(data: Dictionary) -> void:
	peer_id = GFVariantData.get_option_int(data, "peer_id", -1)
	platform_id = GFVariantData.get_option_string_name(data, "platform_id")
	platform_user_id = GFVariantData.get_option_string(data, "platform_user_id").strip_edges()
	display_name = GFVariantData.get_option_string(data, "display_name").strip_edges()
	avatar_uri = GFVariantData.get_option_string(data, "avatar_uri").strip_edges()
	capabilities = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "capabilities"))
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建身份深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新身份资源。
func duplicate_identity() -> GFNetworkPeerIdentity:
	var result: GFNetworkPeerIdentity = GFNetworkPeerIdentity.new()
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
## @schema return: Dictionary JSON-safe identity debug snapshot.
func get_debug_snapshot() -> Dictionary:
	return GFNetworkDebugTools.sanitize_debug_dictionary(to_dict())


## 从字典创建身份资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 身份字典。
## [br]
## @schema data: Dictionary with peer_id, platform_id, platform_user_id, display_name, avatar_uri, capabilities, and metadata.
## [br]
## @return 新身份资源。
static func from_dict(data: Dictionary) -> GFNetworkPeerIdentity:
	var result: GFNetworkPeerIdentity = GFNetworkPeerIdentity.new()
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
