## GFLayeredSprite2D：由单一时间轴驱动的通用分层精灵节点。
##
## 配置会先完整校验并复制帧拓扑，再原子替换当前状态。节点只负责层、变体和播放，
## 不拥有资源发现、下载、缓存或任何项目业务分类。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFLayeredSprite2D
extends Node2D


# --- 信号 ---

## 完整配置成功替换后发出。
## [br]
## @api public
## [br]
## @since unreleased
signal configuration_changed

## 动画开始或恢复播放时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param animation: 已开始或恢复的动画 ID。
signal animation_started(animation: StringName)

## 非循环动画到达边界时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param animation: 已到达非循环边界的动画 ID。
signal animation_finished(animation: StringName)

## 当前帧身份改变时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param animation: 当前动画 ID。
## [br]
## @param frame: 当前从 0 开始的帧索引。
signal frame_changed(animation: StringName, frame: int)

## 某层成功切换变体后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param layer_id: 已切换的稳定层 ID。
## [br]
## @param variant_id: 新的稳定变体 ID。
signal layer_variant_changed(layer_id: StringName, variant_id: StringName)


# --- 常量 ---

## 单个定义允许的最大层数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_LAYERS: int = 32

## 单层允许的最大变体数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_VARIANTS_PER_LAYER: int = 64

## 时间轴允许的最大动画数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_ANIMATIONS: int = 128

## 单动画允许的最大帧数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_FRAMES_PER_ANIMATION: int = 4096

## 一个配置允许引用的最大总帧数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_TOTAL_FRAME_REFERENCES: int = 65536

## 一个配置允许引用的最大唯一纹理数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_UNIQUE_TEXTURES: int = 8192

## 单次推进允许跨越的最大帧边界数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_FRAME_ADVANCES_PER_TICK: int = 4096

## 播放速度绝对值上限。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_SPEED_SCALE: float = 1024.0

const _MAX_ID_LENGTH: int = 128


# --- 私有变量 ---

var _timeline_frames: SpriteFrames = null
var _animation_names: Array[StringName] = []
var _layer_states: Array[Dictionary] = []
var _layers_by_id: Dictionary = {}
var _current_animation: StringName = &""
var _current_frame: int = 0
var _frame_progress: float = 0.0
var _speed_scale: float = 1.0
var _playing: bool = false
var _resume_cursor_available: bool = false
var _configuration_in_progress: bool = false
var _state_generation: int = 0
var _last_rejection_reason: StringName = &""


# --- Godot 生命周期方法 ---

func _ready() -> void:
	set_process(_playing)


func _process(delta: float) -> void:
	var _advanced: bool = advance(delta)


func _draw() -> void:
	if _timeline_frames == null or _current_animation == &"":
		return
	for layer_state: Dictionary in _layer_states:
		if not GFVariantData.get_option_bool(layer_state, "visible", true):
			continue
		var variants: Dictionary = GFVariantData.as_dictionary(layer_state.get("variants"))
		var variant_id: StringName = GFVariantData.get_option_string_name(layer_state, "variant_id")
		var frames_value: Variant = variants.get(variant_id)
		if not frames_value is SpriteFrames:
			continue
		var frames: SpriteFrames = frames_value
		if not frames.has_animation(_current_animation):
			continue
		if _current_frame < 0 or _current_frame >= frames.get_frame_count(_current_animation):
			continue
		var texture: Texture2D = frames.get_frame_texture(_current_animation, _current_frame)
		if texture == null:
			continue
		var offset: Vector2 = GFVariantData.to_vector2(layer_state.get("offset", Vector2.ZERO))
		var tint: Color = Color.WHITE
		var tint_value: Variant = layer_state.get("modulate", Color.WHITE)
		if tint_value is Color:
			tint = tint_value
		draw_texture(texture, offset - texture.get_size() * 0.5, tint)


# --- 公共方法 ---

## 原子配置时间轴与全部层。
## [br]
## @api public
## [br]
## @param definition: 待验证并复制的定义资源。
## [br]
## @return: 配置完整有效且已替换时返回 true；失败时保留原配置。
## [br]
## @since unreleased
func configure(definition: GFLayeredSpriteDefinition) -> bool:
	if _configuration_in_progress:
		return _reject(&"configuration_reentry")
	_configuration_in_progress = true
	var snapshot: Dictionary = _build_configuration_snapshot(definition)
	if snapshot.is_empty():
		_configuration_in_progress = false
		return false

	var timeline_value: Variant = snapshot.get("timeline_frames")
	if not timeline_value is SpriteFrames:
		_configuration_in_progress = false
		return _reject(&"timeline_snapshot_failed")
	stop(false)
	_timeline_frames = timeline_value
	_animation_names.clear()
	for animation_name: StringName in GFVariantData.as_array(snapshot.get("animation_names")):
		_animation_names.append(animation_name)
	_layer_states.assign(GFVariantData.as_array(snapshot.get("layers")))
	_layers_by_id.clear()
	for layer_state: Dictionary in _layer_states:
		_layers_by_id[GFVariantData.get_option_string_name(layer_state, "layer_id")] = layer_state
	_current_animation = GFVariantData.get_option_string_name(snapshot, "default_animation")
	_current_frame = 0
	_frame_progress = 0.0
	_speed_scale = 1.0
	_resume_cursor_available = false
	_last_rejection_reason = &""
	_bump_state_generation()
	var committed_generation: int = _state_generation
	_configuration_in_progress = false
	queue_redraw()
	configuration_changed.emit()
	if _state_generation == committed_generation:
		frame_changed.emit(_current_animation, _current_frame)
	return true


## 清除当前配置和播放状态。
## [br]
## @api public
## [br]
## @since unreleased
func clear_configuration() -> void:
	stop(false)
	_timeline_frames = null
	_animation_names.clear()
	_layer_states.clear()
	_layers_by_id.clear()
	_current_animation = &""
	_current_frame = 0
	_frame_progress = 0.0
	_resume_cursor_available = false
	_last_rejection_reason = &""
	_bump_state_generation()
	queue_redraw()
	configuration_changed.emit()


## 是否持有完整有效的配置快照。
## [br]
## @api public
## [br]
## @return: 已配置时返回 true。
## [br]
## @since unreleased
func is_configured() -> bool:
	return _timeline_frames != null and not _layer_states.is_empty()


## 返回稳定排序的动画名称快照。
## [br]
## @api public
## [br]
## @return: 与内部数组隔离的动画名称数组。
## [br]
## @since unreleased
func get_animation_names() -> Array[StringName]:
	return _animation_names.duplicate()


## 返回按绘制顺序排列的层 ID 快照。
## [br]
## @api public
## [br]
## @return: 与内部数组隔离的层 ID 数组。
## [br]
## @since unreleased
func get_layer_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for layer_state: Dictionary in _layer_states:
		result.append(GFVariantData.get_option_string_name(layer_state, "layer_id"))
	return result


## 播放指定动画。
##
## 暂停或显式定位后的同名动画会从保留游标继续；首次播放、停止或完成后的
## 同名动画会按速度方向重新初始化，反向播放从末端开始。[param from_end]
## 会显式强制从末端重新开始。
## [br]
## @api public
## [br]
## @param animation: 时间轴动画 ID。
## [br]
## @param speed_scale: 有限且非零的播放速度；负值表示反向播放。
## [br]
## @param from_end: 是否从动画末帧开始。
## [br]
## @return: 参数有效且已开始播放时返回 true。
## [br]
## @since unreleased
func play(
	animation: StringName,
	speed_scale: float = 1.0,
	from_end: bool = false
) -> bool:
	if _timeline_frames == null or not _timeline_frames.has_animation(animation):
		return _reject(&"unknown_animation")
	if not _is_finite_float(speed_scale) or is_zero_approx(speed_scale):
		return _reject(&"invalid_speed_scale")
	if absf(speed_scale) > MAX_SPEED_SCALE:
		return _reject(&"speed_scale_limit")
	var previous_animation: StringName = _current_animation
	var previous_frame: int = _current_frame
	var animation_changed_value: bool = previous_animation != animation
	_current_animation = animation
	_speed_scale = speed_scale
	if animation_changed_value or from_end or not _resume_cursor_available:
		_current_frame = (
			_timeline_frames.get_frame_count(animation) - 1
			if from_end or speed_scale < 0.0
			else 0
		)
		_frame_progress = 1.0 if from_end or speed_scale < 0.0 else 0.0
	_playing = true
	_resume_cursor_available = true
	_last_rejection_reason = &""
	_bump_state_generation()
	var playback_generation: int = _state_generation
	set_process(true)
	queue_redraw()
	animation_started.emit(animation)
	if (
		_state_generation == playback_generation
		and (previous_animation != _current_animation or previous_frame != _current_frame)
	):
		frame_changed.emit(_current_animation, _current_frame)
	return true


## 暂停并保留当前帧位置。
## [br]
## @api public
## [br]
## @since unreleased
func pause() -> void:
	_playing = false
	_last_rejection_reason = &""
	_bump_state_generation()
	set_process(false)


## 停止播放。
## [br]
## @api public
## [br]
## @param reset_to_start: 是否将当前动画重置到首帧。
## [br]
## @since unreleased
func stop(reset_to_start: bool = true) -> void:
	var frame_identity_changed: bool = (
		reset_to_start
		and _timeline_frames != null
		and _current_animation != &""
		and _current_frame != 0
	)
	_playing = false
	_resume_cursor_available = false
	_last_rejection_reason = &""
	set_process(false)
	if reset_to_start and _timeline_frames != null and _current_animation != &"":
		_current_frame = 0
		_frame_progress = 0.0
		queue_redraw()
	_bump_state_generation()
	if frame_identity_changed:
		frame_changed.emit(_current_animation, _current_frame)


## 将当前动画定位到指定帧和帧内进度。
## [br]
## @api public
## [br]
## @param frame: 从 0 开始的帧索引。
## [br]
## @param frame_progress: 当前帧内 0..1 的时间进度。
## [br]
## @return: 定位参数有效时返回 true。
## [br]
## @since unreleased
func seek(frame: int, frame_progress: float = 0.0) -> bool:
	if _timeline_frames == null or _current_animation == &"":
		return _reject(&"not_configured")
	if frame < 0 or frame >= _timeline_frames.get_frame_count(_current_animation):
		return _reject(&"frame_out_of_range")
	if not _is_finite_float(frame_progress) or frame_progress < 0.0 or frame_progress > 1.0:
		return _reject(&"invalid_frame_progress")
	var changed: bool = _current_frame != frame
	_current_frame = frame
	_frame_progress = frame_progress
	_resume_cursor_available = true
	_last_rejection_reason = &""
	_bump_state_generation()
	queue_redraw()
	if changed:
		frame_changed.emit(_current_animation, _current_frame)
	return true


## 以秒为单位推进共享时间轴。
##
## 节点在播放时会自动调用本方法；确定性模拟也可在节点未入树时显式调用。
## [br]
## @api public
## [br]
## @param delta_seconds: 非负、有限的推进时间。
## [br]
## @return: 完整消费本次推进量时返回 true；参数非法或跨帧预算耗尽时返回 false。
## [br]
## @since unreleased
func advance(delta_seconds: float) -> bool:
	if not _is_finite_float(delta_seconds) or delta_seconds < 0.0:
		return _reject(&"invalid_delta")
	if not _playing or delta_seconds == 0.0:
		_last_rejection_reason = &""
		return true
	if _timeline_frames == null or _current_animation == &"":
		return _reject(&"not_configured")
	var animation_speed: float = _timeline_frames.get_animation_speed(_current_animation)
	if not _is_finite_float(animation_speed) or animation_speed <= 0.0:
		return _reject(&"invalid_timeline_speed")
	var remaining_units: float = delta_seconds * absf(_speed_scale) * animation_speed
	if not _is_finite_float(remaining_units):
		return _reject(&"invalid_delta")
	var advances: int = 0
	var playback_generation: int = _state_generation
	while remaining_units > 0.0 and _playing:
		if advances >= MAX_FRAME_ADVANCES_PER_TICK:
			return _reject(&"frame_advance_limit")
		var frame_duration: float = _timeline_frames.get_frame_duration(
			_current_animation,
			_current_frame
		)
		if not _is_finite_float(frame_duration) or frame_duration <= 0.0:
			return _reject(&"invalid_frame_duration")
		var distance: float = (
			frame_duration * (1.0 - _frame_progress)
			if _speed_scale > 0.0
			else frame_duration * _frame_progress
		)
		if remaining_units < distance:
			var progress_delta: float = remaining_units / frame_duration
			_frame_progress += progress_delta if _speed_scale > 0.0 else -progress_delta
			remaining_units = 0.0
			break
		remaining_units = maxf(remaining_units - distance, 0.0)
		var crossed_boundary: bool = _advance_frame_boundary(_speed_scale > 0.0)
		advances += 1
		if _state_generation != playback_generation:
			return true
		if not crossed_boundary:
			break
	_last_rejection_reason = &""
	return true


## 当前是否正在播放。
## [br]
## @api public
## [br]
## @return: 正在自动推进时返回 true。
## [br]
## @since unreleased
func is_playing() -> bool:
	return _playing


## 返回当前动画 ID。
## [br]
## @api public
## [br]
## @return: 当前动画 ID；未配置时为空。
## [br]
## @since unreleased
func get_current_animation() -> StringName:
	return _current_animation


## 返回当前帧索引。
## [br]
## @api public
## [br]
## @return: 当前帧索引。
## [br]
## @since unreleased
func get_current_frame() -> int:
	return _current_frame


## 返回当前帧内的 0..1 时间进度。
## [br]
## @api public
## [br]
## @return: 当前帧内进度。
## [br]
## @since unreleased
func get_frame_progress() -> float:
	return _frame_progress


## 切换指定层的帧变体。
## [br]
## @api public
## [br]
## @param layer_id: 待切换的稳定层 ID。
## [br]
## @param variant_id: 该层中已配置的稳定变体 ID。
## [br]
## @return: 层和变体均存在时返回 true。
## [br]
## @since unreleased
func set_layer_variant(layer_id: StringName, variant_id: StringName) -> bool:
	var layer_state: Dictionary = GFVariantData.as_dictionary(_layers_by_id.get(layer_id, {}))
	if layer_state.is_empty():
		return _reject(&"unknown_layer")
	var variants: Dictionary = GFVariantData.as_dictionary(layer_state.get("variants"))
	if not variants.has(variant_id):
		return _reject(&"unknown_variant")
	if GFVariantData.get_option_string_name(layer_state, "variant_id") == variant_id:
		_last_rejection_reason = &""
		return true
	layer_state["variant_id"] = variant_id
	_last_rejection_reason = &""
	queue_redraw()
	layer_variant_changed.emit(layer_id, variant_id)
	return true


## 返回指定层的当前变体 ID。
## [br]
## @api public
## [br]
## @param layer_id: 待读取的稳定层 ID。
## [br]
## @return: 当前变体 ID；层不存在时为空。
## [br]
## @since unreleased
func get_layer_variant(layer_id: StringName) -> StringName:
	var layer_state: Dictionary = GFVariantData.as_dictionary(_layers_by_id.get(layer_id, {}))
	return GFVariantData.get_option_string_name(layer_state, "variant_id")


## 设置指定层可见性。
## [br]
## @api public
## [br]
## @param layer_id: 待修改的稳定层 ID。
## [br]
## @param layer_visible: 新可见状态。
## [br]
## @return: 层存在时返回 true。
## [br]
## @since unreleased
func set_layer_visible(layer_id: StringName, layer_visible: bool) -> bool:
	var layer_state: Dictionary = GFVariantData.as_dictionary(_layers_by_id.get(layer_id, {}))
	if layer_state.is_empty():
		return _reject(&"unknown_layer")
	layer_state["visible"] = layer_visible
	_last_rejection_reason = &""
	queue_redraw()
	return true


## 返回指定层可见性。
## [br]
## @api public
## [br]
## @param layer_id: 待读取的稳定层 ID。
## [br]
## @return: 层存在且可见时返回 true。
## [br]
## @since unreleased
func is_layer_visible(layer_id: StringName) -> bool:
	var layer_state: Dictionary = GFVariantData.as_dictionary(_layers_by_id.get(layer_id, {}))
	return not layer_state.is_empty() and GFVariantData.get_option_bool(layer_state, "visible")


## 设置指定层调制颜色。
## [br]
## @api public
## [br]
## @param layer_id: 待修改的稳定层 ID。
## [br]
## @param layer_modulate: 所有分量均须有限的新调制颜色。
## [br]
## @return: 层存在且颜色分量均有限时返回 true。
## [br]
## @since unreleased
func set_layer_modulate(layer_id: StringName, layer_modulate: Color) -> bool:
	var layer_state: Dictionary = GFVariantData.as_dictionary(_layers_by_id.get(layer_id, {}))
	if layer_state.is_empty():
		return _reject(&"unknown_layer")
	if not _is_finite_color(layer_modulate):
		return _reject(&"invalid_modulate")
	layer_state["modulate"] = layer_modulate
	_last_rejection_reason = &""
	queue_redraw()
	return true


## 设置指定层绘制偏移。
## [br]
## @api public
## [br]
## @param layer_id: 待修改的稳定层 ID。
## [br]
## @param layer_offset: 两分量均须有限的新绘制偏移。
## [br]
## @return: 层存在且偏移分量均有限时返回 true。
## [br]
## @since unreleased
func set_layer_offset(layer_id: StringName, layer_offset: Vector2) -> bool:
	var layer_state: Dictionary = GFVariantData.as_dictionary(_layers_by_id.get(layer_id, {}))
	if layer_state.is_empty():
		return _reject(&"unknown_layer")
	if not _is_finite_vector2(layer_offset):
		return _reject(&"invalid_offset")
	layer_state["offset"] = layer_offset
	_last_rejection_reason = &""
	queue_redraw()
	return true


## 返回最近一次拒绝原因。
## [br]
## @api public
## [br]
## @return: 稳定原因 ID；最近一次操作成功时为空。
## [br]
## @since unreleased
func get_last_rejection_reason() -> StringName:
	return _last_rejection_reason


# --- 私有/辅助方法 ---

func _build_configuration_snapshot(definition: GFLayeredSpriteDefinition) -> Dictionary:
	if definition == null or definition.timeline_frames == null:
		_set_rejection_reason(&"missing_timeline")
		return {}
	if definition.layers.is_empty() or definition.layers.size() > MAX_LAYERS:
		_set_rejection_reason(&"layer_limit")
		return {}
	var timeline_source: SpriteFrames = definition.timeline_frames
	var animation_names: Array[StringName] = []
	for animation_name: StringName in timeline_source.get_animation_names():
		animation_names.append(animation_name)
	animation_names.sort()
	if animation_names.is_empty() or animation_names.size() > MAX_ANIMATIONS:
		_set_rejection_reason(&"animation_limit")
		return {}
	var total_frame_references: int = 0
	if not _validate_frame_topology(timeline_source, animation_names):
		return {}
	for animation_name: StringName in animation_names:
		total_frame_references += timeline_source.get_frame_count(animation_name)
	if total_frame_references > MAX_TOTAL_FRAME_REFERENCES:
		_set_rejection_reason(&"total_frame_reference_limit")
		return {}

	var texture_ids: Dictionary = {}
	if not _track_unique_textures(timeline_source, animation_names, texture_ids):
		return {}
	var layer_ids: Dictionary = {}
	var layer_plans: Array[Dictionary] = []
	for source_index: int in range(definition.layers.size()):
		var layer: GFLayeredSpriteLayerDefinition = definition.layers[source_index]
		if layer == null or not _is_valid_id(layer.layer_id) or layer_ids.has(layer.layer_id):
			_set_rejection_reason(&"invalid_layer_id")
			return {}
		if layer.variants.is_empty() or layer.variants.size() > MAX_VARIANTS_PER_LAYER:
			_set_rejection_reason(&"variant_limit")
			return {}
		if not _is_finite_vector2(layer.offset) or not _is_finite_color(layer.modulate):
			_set_rejection_reason(&"invalid_layer_draw_state")
			return {}
		if layer.draw_order < -4096 or layer.draw_order > 4096:
			_set_rejection_reason(&"invalid_draw_order")
			return {}
		var variant_ids: Dictionary = {}
		var variant_plans: Array[Dictionary] = []
		for variant: GFLayeredSpriteVariant in layer.variants:
			if (
				variant == null
				or not _is_valid_id(variant.variant_id)
				or variant_ids.has(variant.variant_id)
				or variant.sprite_frames == null
			):
				_set_rejection_reason(&"invalid_variant")
				return {}
			if not _matches_frame_topology(
				variant.sprite_frames,
				timeline_source,
				animation_names
			):
				_set_rejection_reason(&"variant_topology_mismatch")
				return {}
			for animation_name: StringName in animation_names:
				var frame_count: int = variant.sprite_frames.get_frame_count(animation_name)
				total_frame_references += frame_count
				if total_frame_references > MAX_TOTAL_FRAME_REFERENCES:
					_set_rejection_reason(&"total_frame_reference_limit")
					return {}
			if not _track_unique_textures(variant.sprite_frames, animation_names, texture_ids):
				return {}
			variant_ids[variant.variant_id] = true
			variant_plans.append({
				"variant_id": variant.variant_id,
				"source_frames": variant.sprite_frames,
			})
		if not variant_ids.has(layer.default_variant_id):
			_set_rejection_reason(&"missing_default_variant")
			return {}
		layer_ids[layer.layer_id] = true
		layer_plans.append({
			"layer_id": layer.layer_id,
			"variant_id": layer.default_variant_id,
			"variant_plans": variant_plans,
			"offset": layer.offset,
			"modulate": layer.modulate,
			"visible": layer.visible,
			"draw_order": layer.draw_order,
			"source_index": source_index,
		})
	var default_animation: StringName = definition.default_animation
	if default_animation == &"":
		default_animation = animation_names[0]
	elif not timeline_source.has_animation(default_animation):
		_set_rejection_reason(&"unknown_default_animation")
		return {}

	var timeline_copy: SpriteFrames = _copy_frame_topology(
		timeline_source,
		timeline_source,
		animation_names
	)
	if timeline_copy == null:
		_set_rejection_reason(&"timeline_snapshot_failed")
		return {}
	var layer_states: Array[Dictionary] = []
	for layer_plan: Dictionary in layer_plans:
		var variant_frames: Dictionary = {}
		for variant_plan: Dictionary in GFVariantData.as_array(layer_plan.get("variant_plans")):
			var source_value: Variant = variant_plan.get("source_frames")
			if not source_value is SpriteFrames:
				_set_rejection_reason(&"variant_snapshot_failed")
				return {}
			var source_frames: SpriteFrames = source_value
			var frames_copy: SpriteFrames = _copy_frame_topology(
				source_frames,
				timeline_source,
				animation_names
			)
			if frames_copy == null:
				_set_rejection_reason(&"variant_snapshot_failed")
				return {}
			variant_frames[
				GFVariantData.get_option_string_name(variant_plan, "variant_id")
			] = frames_copy
		layer_states.append({
			"layer_id": GFVariantData.get_option_string_name(layer_plan, "layer_id"),
			"variant_id": GFVariantData.get_option_string_name(layer_plan, "variant_id"),
			"variants": variant_frames,
			"offset": GFVariantData.to_vector2(layer_plan.get("offset", Vector2.ZERO)),
			"modulate": layer_plan.get("modulate", Color.WHITE),
			"visible": GFVariantData.get_option_bool(layer_plan, "visible", true),
			"draw_order": GFVariantData.get_option_int(layer_plan, "draw_order"),
			"source_index": GFVariantData.get_option_int(layer_plan, "source_index"),
		})
	layer_states.sort_custom(_sort_layer_state)
	return {
		"timeline_frames": timeline_copy,
		"animation_names": animation_names,
		"default_animation": default_animation,
		"layers": layer_states,
	}


func _track_unique_textures(
	frames: SpriteFrames,
	animation_names: Array[StringName],
	texture_ids: Dictionary
) -> bool:
	for animation_name: StringName in animation_names:
		var frame_count: int = frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var texture: Texture2D = frames.get_frame_texture(animation_name, frame_index)
			if texture == null:
				continue
			texture_ids[texture.get_instance_id()] = true
			if texture_ids.size() > MAX_UNIQUE_TEXTURES:
				_set_rejection_reason(&"unique_texture_limit")
				return false
	return true


func _copy_frame_topology(
	texture_source: SpriteFrames,
	timeline_source: SpriteFrames,
	animation_names: Array[StringName]
) -> SpriteFrames:
	if not _matches_frame_topology(texture_source, timeline_source, animation_names):
		return null
	if not _validate_frame_topology(timeline_source, animation_names):
		return null
	var result: SpriteFrames = SpriteFrames.new()
	for existing_animation: StringName in result.get_animation_names():
		result.remove_animation(existing_animation)
	for animation_name: StringName in animation_names:
		result.add_animation(animation_name)
		result.set_animation_speed(
			animation_name,
			timeline_source.get_animation_speed(animation_name)
		)
		result.set_animation_loop(
			animation_name,
			timeline_source.get_animation_loop(animation_name)
		)
		var frame_count: int = timeline_source.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			result.add_frame(
				animation_name,
				texture_source.get_frame_texture(animation_name, frame_index),
				timeline_source.get_frame_duration(animation_name, frame_index)
			)
	return result


func _validate_frame_topology(frames: SpriteFrames, animation_names: Array[StringName]) -> bool:
	for animation_name: StringName in animation_names:
		if not _is_valid_id(animation_name):
			_set_rejection_reason(&"invalid_animation_id")
			return false
		var frame_count: int = frames.get_frame_count(animation_name)
		if frame_count <= 0 or frame_count > MAX_FRAMES_PER_ANIMATION:
			_set_rejection_reason(&"frame_limit")
			return false
		var animation_speed: float = frames.get_animation_speed(animation_name)
		if not _is_finite_float(animation_speed) or animation_speed <= 0.0:
			_set_rejection_reason(&"invalid_timeline_speed")
			return false
		for frame_index: int in range(frame_count):
			var duration: float = frames.get_frame_duration(animation_name, frame_index)
			if not _is_finite_float(duration) or duration <= 0.0:
				_set_rejection_reason(&"invalid_frame_duration")
				return false
	return true


func _matches_frame_topology(
	frames: SpriteFrames,
	timeline_frames: SpriteFrames,
	animation_names: Array[StringName]
) -> bool:
	var candidate_names: Array[StringName] = []
	for animation_name: StringName in frames.get_animation_names():
		candidate_names.append(animation_name)
	candidate_names.sort()
	if candidate_names != animation_names:
		return false
	for animation_name: StringName in animation_names:
		var frame_count: int = frames.get_frame_count(animation_name)
		if frame_count <= 0 or frame_count > MAX_FRAMES_PER_ANIMATION:
			return false
		if frame_count != timeline_frames.get_frame_count(animation_name):
			return false
	return true


func _advance_frame_boundary(forward: bool) -> bool:
	var frame_count: int = _timeline_frames.get_frame_count(_current_animation)
	var previous_frame: int = _current_frame
	var next_frame: int = _current_frame + (1 if forward else -1)
	if next_frame >= 0 and next_frame < frame_count:
		_current_frame = next_frame
		_frame_progress = 0.0 if forward else 1.0
		queue_redraw()
		frame_changed.emit(_current_animation, _current_frame)
		return true
	if _timeline_frames.get_animation_loop(_current_animation):
		_current_frame = 0 if forward else frame_count - 1
		_frame_progress = 0.0 if forward else 1.0
		queue_redraw()
		if _current_frame != previous_frame:
			frame_changed.emit(_current_animation, _current_frame)
		return true
	_current_frame = frame_count - 1 if forward else 0
	_frame_progress = 1.0 if forward else 0.0
	_playing = false
	_resume_cursor_available = false
	set_process(false)
	queue_redraw()
	animation_finished.emit(_current_animation)
	return false


func _sort_layer_state(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = GFVariantData.get_option_int(left, "draw_order")
	var right_order: int = GFVariantData.get_option_int(right, "draw_order")
	if left_order == right_order:
		return GFVariantData.get_option_int(left, "source_index") < GFVariantData.get_option_int(
			right,
			"source_index"
		)
	return left_order < right_order


func _is_valid_id(value: StringName) -> bool:
	var text: String = String(value)
	return not text.is_empty() and text.length() <= _MAX_ID_LENGTH and text == text.strip_edges()


func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


func _is_finite_color(value: Color) -> bool:
	return (
		_is_finite_float(value.r)
		and _is_finite_float(value.g)
		and _is_finite_float(value.b)
		and _is_finite_float(value.a)
	)


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _bump_state_generation() -> void:
	_state_generation += 1


func _reject(reason: StringName) -> bool:
	_set_rejection_reason(reason)
	return false


func _set_rejection_reason(reason: StringName) -> void:
	_last_rejection_reason = reason
