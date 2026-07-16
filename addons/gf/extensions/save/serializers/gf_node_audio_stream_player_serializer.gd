## GFNodeAudioStreamPlayerSerializer: AudioStreamPlayer 通用播放状态序列化器。
##
## 支持 AudioStreamPlayer、AudioStreamPlayer2D 与 AudioStreamPlayer3D 的通用播放参数。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeAudioStreamPlayerSerializer
extends GFNodeSerializer


# --- 常量 ---

const _OPTIONAL_PROPERTIES: PackedStringArray = [
	"stream_paused",
	"volume_db",
	"pitch_scale",
	"bus",
	"max_distance",
	"attenuation",
]

const _APPLY_PROPERTY_SPECS: Array[Dictionary] = [
	{ "key": "playing", "kind": &"bool" },
	{ "key": "playback_position", "kind": &"float" },
	{ "key": "stream_paused", "kind": &"bool" },
	{ "key": "volume_db", "kind": &"float" },
	{ "key": "pitch_scale", "kind": &"float" },
	{ "key": "bus", "kind": &"string_name" },
	{ "key": "max_distance", "kind": &"float" },
	{ "key": "attenuation", "kind": &"float" },
]


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.audio_stream_player"
	display_name = "Audio Stream Player"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 AudioStreamPlayer、AudioStreamPlayer2D 或 AudioStreamPlayer3D。
func supports_node(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 音频播放状态载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 playing、playback_position、stream_paused、volume_db、pitch_scale、bus、max_distance 与 attenuation。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	if not supports_node(node):
		return {}

	var result: Dictionary = {
		"playing": GFVariantData.to_bool(node.call("is_playing")) if node.has_method("is_playing") else false,
		"playback_position": GFVariantData.to_float(node.call("get_playback_position")) if node.has_method("get_playback_position") else 0.0,
	}
	_copy_properties_to_payload(node, result, _OPTIONAL_PROPERTIES)
	return result


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: 音频播放状态载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 playing、playback_position、stream_paused、volume_db、pitch_scale、bus、max_distance 与 attenuation。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	if not supports_node(node):
		return make_result(false, "Node is not AudioStreamPlayer.")

	var errors: Array[String] = _validate_property_specs_payload(payload, _APPLY_PROPERTY_SPECS)
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))

	_apply_properties_from_payload(node, payload, PackedStringArray([
		"volume_db",
		"pitch_scale",
		"bus",
		"max_distance",
		"attenuation",
	]))

	var should_play: bool = GFVariantData.get_option_bool(payload, "playing")
	var should_pause: bool = GFVariantData.get_option_bool(payload, "stream_paused")
	if (should_play or should_pause) and node.has_method("play") and _can_start_playback(node):
		node.call("play", maxf(GFVariantData.get_option_float(payload, "playback_position"), 0.0))
	elif not should_play and not should_pause and node.has_method("stop"):
		node.call("stop")

	_apply_property_from_payload(node, payload, "stream_paused")
	return make_result(true)


# --- 私有/辅助方法 ---

func _can_start_playback(node: Object) -> bool:
	if not _has_property(node, "stream"):
		return true
	return GFObjectPropertyTools.read_property(node, NodePath("stream")) != null
