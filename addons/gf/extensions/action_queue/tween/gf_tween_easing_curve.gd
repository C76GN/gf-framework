# Action Queue 内部缓动曲线捕获；只保留原生 Curve 数据，不保留来源资源或脚本。
extends RefCounted


# --- 常量 ---

const _MAX_POINTS: int = 256
const _MIN_BAKE_RESOLUTION: int = 2
# 原生 Curve.set_bake_resolution 的上限为 1000。
const _MAX_BAKE_RESOLUTION: int = 1000
const _MAX_SAMPLE_MAGNITUDE: float = 16.0


# --- 层内方法 ---

## 捕获独立纯值数据，并校验实际消费的原生烘焙曲线。
## 仅保证烘焙采样输出有限且绝对值不超过 16，不保证未采样原曲线的极值。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param source: 无脚本的原生 Curve；null 表示继续使用 Tween 预设。
## [br]
## @return: 错误说明与独立数据；错误时没有部分数据。
## [br]
## @schema return: Dictionary，error: String（空字符串表示成功）、data: Dictionary。data 为空表示无曲线；否则包含 positions: PackedVector2Array、tangents: PackedVector2Array（每点左、右切线）、modes: PackedInt32Array（每点左、右模式交错）、bake_resolution: int、value_range: Vector2（编辑器最小、最大值）。
static func capture(source: Curve) -> Dictionary:
	if source == null:
		return { "error": "", "data": {} }
	if source.get_script() != null:
		return _failure("Easing curves must be native Curve resources without a script.")
	var point_count: int = source.get_point_count()
	if point_count < 2 or point_count > _MAX_POINTS:
		return _failure("Easing curves require 2 to 256 points.")
	if source.min_domain != 0.0 or source.max_domain != 1.0:
		return _failure("Easing curve domains must be exactly 0 to 1.")
	var positions: PackedVector2Array = PackedVector2Array()
	var tangents: PackedVector2Array = PackedVector2Array()
	var modes: PackedInt32Array = PackedInt32Array()
	for index: int in range(point_count):
		var _position_added: bool = positions.append(source.get_point_position(index))
		var _tangent_added: bool = tangents.append(Vector2(
			source.get_point_left_tangent(index), source.get_point_right_tangent(index)
		))
		var _left_mode_added: bool = modes.append(source.get_point_left_mode(index))
		var _right_mode_added: bool = modes.append(source.get_point_right_mode(index))
	var data: Dictionary = {
		"positions": positions,
		"tangents": tangents,
		"modes": modes,
		"bake_resolution": source.bake_resolution,
		"value_range": Vector2(source.min_value, source.max_value),
	}
	var data_error: String = _get_data_error(data)
	if not data_error.is_empty():
		return _failure(data_error)
	var private_curve: Curve = _build_curve(data)
	var sample_error: String = _get_sample_error(private_curve)
	if not sample_error.is_empty():
		return _failure(sample_error)
	return { "error": "", "data": data }


## 从已捕获的数据重建独立的无脚本原生 Curve，不复制来源 metadata。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param data: capture 成功返回的非空 data；不得修改其中的已校验数据。
## [br]
## @schema data: Dictionary，结构同 capture 返回值的 data。
## [br]
## @return: 已烘焙的私有 Curve；空数据或无效数据返回 null。
static func create_curve(data: Dictionary) -> Curve:
	if data.is_empty() or not _get_data_error(data).is_empty():
		return null
	var private_curve: Curve = _build_curve(data)
	if not _get_sample_error(private_curve).is_empty():
		return null
	return private_curve


## 创建只强持私有原生 Curve 的插值闭包；不持有来源步骤、动作或节点。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param data: capture 成功返回的 data；空数据表示没有自定义曲线。
## [br]
## @schema data: Dictionary，结构同 capture 返回值的 data。
## [br]
## @return: 原生烘焙插值闭包；没有曲线或数据无效时返回空 Callable。
## [br]
## @schema return: Callable(progress: float) -> float；progress 为有限的 0..1 时间进度，返回已校验的烘焙插值进度。
static func create_interpolator(data: Dictionary) -> Callable:
	var private_curve: Curve = create_curve(data)
	if private_curve == null:
		return Callable()
	return func(progress: float) -> float:
		return private_curve.sample_baked(progress)


## 复制有效曲线的原生数据；不会复制脚本、metadata 或来源引用。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param source: 待复制的原生 Curve。
## [br]
## @return: 独立曲线；来源为空或无效时返回 null。
static func duplicate_curve(source: Curve) -> Curve:
	var result: Dictionary = capture(source)
	var data_value: Variant = result.get("data")
	if data_value is Dictionary:
		var data: Dictionary = data_value
		return create_curve(data)
	return null


## 返回曲线数据所需的烘焙采样数，供调用方累计整组预算。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param data: capture 成功返回的 data。
## [br]
## @schema data: Dictionary，结构同 capture 返回值的 data。
## [br]
## @return: 烘焙采样数；空数据或字段类型不符时返回 0。
static func get_sample_count(data: Dictionary) -> int:
	var count_value: Variant = data.get("bake_resolution")
	if count_value is int:
		var count: int = count_value
		return count
	return 0


## 返回曲线数据的点数，供调用方累计整组预算。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param data: capture 成功返回的 data。
## [br]
## @schema data: Dictionary，结构同 capture 返回值的 data。
## [br]
## @return: 曲线点数；空数据或字段类型不符时返回 0。
static func get_point_count(data: Dictionary) -> int:
	var positions_value: Variant = data.get("positions")
	if positions_value is PackedVector2Array:
		var positions: PackedVector2Array = positions_value
		return positions.size()
	return 0


# --- 私有/辅助方法 ---

static func _failure(message: String) -> Dictionary:
	return { "error": message, "data": {} }


static func _get_data_error(data: Dictionary) -> String:
	var positions_value: Variant = data.get("positions")
	var tangents_value: Variant = data.get("tangents")
	var modes_value: Variant = data.get("modes")
	var resolution_value: Variant = data.get("bake_resolution")
	var range_value: Variant = data.get("value_range")
	if not (
		positions_value is PackedVector2Array and tangents_value is PackedVector2Array
		and modes_value is PackedInt32Array and resolution_value is int and range_value is Vector2
	):
		return "Easing curve snapshot fields have invalid types."
	var positions: PackedVector2Array = positions_value
	var tangents: PackedVector2Array = tangents_value
	var modes: PackedInt32Array = modes_value
	var resolution: int = resolution_value
	var value_range: Vector2 = range_value
	var point_count: int = positions.size()
	if point_count < 2 or point_count > _MAX_POINTS:
		return "Easing curves require 2 to 256 points."
	if tangents.size() != point_count or modes.size() != point_count * 2:
		return "Easing curve point, tangent and mode counts must agree."
	if resolution < _MIN_BAKE_RESOLUTION or resolution > _MAX_BAKE_RESOLUTION:
		return "Easing curve bake_resolution must be between 2 and 1000."
	if not value_range.is_finite() or value_range.x > 0.0 or value_range.y < 1.0:
		return "Easing curve editing ranges must be finite and include 0 to 1."
	if positions[0] != Vector2.ZERO or positions[point_count - 1] != Vector2.ONE:
		return "Easing curves must start exactly at (0, 0) and end exactly at (1, 1)."
	for index: int in range(point_count):
		var position: Vector2 = positions[index]
		if not position.is_finite() or not tangents[index].is_finite():
			return "Easing curve points and tangents must be finite."
		if position.y < value_range.x or position.y > value_range.y:
			return "Easing curve points must lie within their editing value range."
		if index > 0 and position.x <= positions[index - 1].x:
			return "Easing curve point X coordinates must be strictly increasing."
		for mode_index: int in range(index * 2, index * 2 + 2):
			if modes[mode_index] != Curve.TANGENT_FREE and modes[mode_index] != Curve.TANGENT_LINEAR:
				return "Easing curve tangent modes must be valid native modes."
	return ""


static func _build_curve(data: Dictionary) -> Curve:
	var positions_value: Variant = data["positions"]
	var tangents_value: Variant = data["tangents"]
	var modes_value: Variant = data["modes"]
	var range_value: Variant = data["value_range"]
	if not (
		positions_value is PackedVector2Array and tangents_value is PackedVector2Array
		and modes_value is PackedInt32Array and range_value is Vector2
	):
		return null
	var positions: PackedVector2Array = positions_value
	var tangents: PackedVector2Array = tangents_value
	var modes: PackedInt32Array = modes_value
	var value_range: Vector2 = range_value
	var private_curve: Curve = Curve.new()
	private_curve.min_value = value_range.x
	private_curve.max_value = value_range.y
	private_curve.bake_resolution = get_sample_count(data)
	var point_data: Array = []
	for index: int in range(positions.size()):
		point_data.append(positions[index])
		point_data.append(tangents[index].x)
		point_data.append(tangents[index].y)
		point_data.append(modes[index * 2])
		point_data.append(modes[index * 2 + 1])
	# add_point 会重算 LINEAR 切线，使删除控制点后的合法原生曲线改变形状。
	# 只向新建无脚本 Curve 写入已校验的原生存储数据，保留切线数值和模式。
	private_curve.set(&"_data", point_data)
	private_curve.bake()
	return private_curve


static func _get_sample_error(private_curve: Curve) -> String:
	if private_curve == null:
		return "Easing curve snapshot could not be reconstructed."
	var resolution: int = private_curve.bake_resolution
	for index: int in range(resolution):
		var progress: float = float(index) / float(resolution - 1)
		var sample_value: float = private_curve.sample_baked(progress)
		if not is_finite(sample_value) or absf(sample_value) > _MAX_SAMPLE_MAGNITUDE:
			return "Easing curve baked samples must be finite and have magnitude at most 16."
	return ""
