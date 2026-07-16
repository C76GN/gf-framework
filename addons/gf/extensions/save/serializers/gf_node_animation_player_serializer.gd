## GFNodeAnimationPlayerSerializer: AnimationPlayer 通用播放状态序列化器。
##
## 保存当前动画、播放位置与速度缩放等通用播放状态，不保存动画资源内容。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeAnimationPlayerSerializer
extends GFNodeSerializer


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.animation_player"
	display_name = "Animation Player"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 AnimationPlayer。
func supports_node(node: Node) -> bool:
	return node is AnimationPlayer


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return AnimationPlayer 播放状态载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 current_animation、assigned_animation、current_animation_position、speed_scale、playing 与 active。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var player: AnimationPlayer = _get_animation_player(node)
	if player == null:
		return {}

	return {
		"current_animation": player.current_animation,
		"assigned_animation": player.assigned_animation,
		"current_animation_position": player.current_animation_position,
		"speed_scale": player.speed_scale,
		"playing": player.is_playing(),
		"active": player.active,
	}


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: AnimationPlayer 播放状态载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 current_animation、assigned_animation、current_animation_position、speed_scale、playing 与 active。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var player: AnimationPlayer = _get_animation_player(node)
	if player == null:
		return make_result(false, "Node is not AnimationPlayer.")

	var errors: Array[String] = _validate_property_specs_payload(payload, [
		{ "key": "current_animation", "kind": &"string_name" },
		{ "key": "assigned_animation", "kind": &"string_name" },
		{ "key": "current_animation_position", "kind": &"float" },
		{ "key": "speed_scale", "kind": &"float" },
		{ "key": "playing", "kind": &"bool" },
		{ "key": "active", "kind": &"bool" },
	])
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))

	if payload.has("speed_scale"):
		player.speed_scale = GFVariantData.to_float(payload["speed_scale"])
	if payload.has("active"):
		player.active = GFVariantData.to_bool(payload["active"])
	if payload.has("assigned_animation"):
		var assigned_animation: StringName = GFVariantData.to_string_name(payload["assigned_animation"])
		if assigned_animation == &"" or player.has_animation(assigned_animation):
			player.assigned_animation = assigned_animation

	var animation_name: StringName = GFVariantData.get_option_string_name(payload, "current_animation")
	var position: float = GFVariantData.get_option_float(payload, "current_animation_position")
	var should_play: bool = GFVariantData.get_option_bool(payload, "playing")
	if animation_name != &"" and player.has_animation(animation_name):
		player.play(animation_name)
		player.seek(maxf(position, 0.0), true)
		if not should_play:
			player.stop(false)
	elif not should_play:
		player.stop(false)

	return make_result(true)


# --- 私有/辅助方法 ---

func _get_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node
		return player
	return null
