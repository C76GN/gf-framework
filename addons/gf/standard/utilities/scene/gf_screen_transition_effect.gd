## GFScreenTransitionEffect: 屏幕覆盖式转场效果配置。
##
## 只描述通用覆盖层颜色、透明度、时长、缓动和可选 ShaderMaterial 进度参数，
## 不绑定具体场景切换流程或项目视觉资源。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.23.0
class_name GFScreenTransitionEffect
extends Resource


# --- 枚举 ---

## 转场权重采样的缓动模式。
## [br]
## @api public
enum EasingMode {
	## 线性采样。
	LINEAR,
	## smoothstep 采样。
	SMOOTH_STEP,
	## 二次缓入。
	EASE_IN,
	## 二次缓出。
	EASE_OUT,
	## 二次缓入缓出。
	EASE_IN_OUT,
}


# --- 导出变量 ---

## 转场时长，单位秒。小于等于 0 时会在下一次推进时立即完成。
## [br]
## @api public
@export_range(0.0, 30.0, 0.01, "or_greater") var duration_seconds: float = 0.25

## 起始透明度。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var from_alpha: float = 0.0

## 结束透明度。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var to_alpha: float = 1.0

## 覆盖层颜色。
## [br]
## @api public
@export var color: Color = Color.BLACK

## CanvasLayer 层级。
## [br]
## @api public
@export var layer: int = 120

## 是否让覆盖层拦截鼠标和触摸输入。
## [br]
## @api public
@export var block_input: bool = true

## 权重采样缓动模式。
## [br]
## @api public
@export var easing_mode: EasingMode = EasingMode.SMOOTH_STEP

## 可选 ShaderMaterial。Utility 会复制该材质并写入 progress_parameter。
## [br]
## @api public
@export var shader_material: ShaderMaterial = null

## shader_material 中表示进度的参数名。为空时不写入 shader 参数。
## [br]
## @api public
@export var progress_parameter: StringName = &"progress"

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，项目自定义元数据；框架不会读取或改写其中字段。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 批量配置转场效果。
## [br]
## @api public
## [br]
## @param new_duration_seconds: 转场时长，单位秒。
## [br]
## @param new_from_alpha: 起始透明度。
## [br]
## @param new_to_alpha: 结束透明度。
## [br]
## @param new_color: 覆盖层颜色。
## [br]
## @return 当前资源，便于链式配置。
func configure(
	new_duration_seconds: float,
	new_from_alpha: float,
	new_to_alpha: float,
	new_color: Color = Color.BLACK
) -> GFScreenTransitionEffect:
	duration_seconds = maxf(new_duration_seconds, 0.0)
	from_alpha = clampf(new_from_alpha, 0.0, 1.0)
	to_alpha = clampf(new_to_alpha, 0.0, 1.0)
	color = new_color
	return self


## 根据已流逝时间采样 0 到 1 的转场权重。
## [br]
## @api public
## [br]
## @param elapsed_seconds: 已流逝秒数。
## [br]
## @return 缓动后的权重。
func sample_weight(elapsed_seconds: float) -> float:
	if duration_seconds <= 0.0:
		return 1.0

	var t: float = clampf(elapsed_seconds / duration_seconds, 0.0, 1.0)
	match easing_mode:
		EasingMode.SMOOTH_STEP:
			return t * t * (3.0 - 2.0 * t)
		EasingMode.EASE_IN:
			return t * t
		EasingMode.EASE_OUT:
			return 1.0 - ((1.0 - t) * (1.0 - t))
		EasingMode.EASE_IN_OUT:
			if t < 0.5:
				return 2.0 * t * t
			return 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5
		_:
			return t


## 根据转场权重采样覆盖层透明度。
## [br]
## @api public
## [br]
## @param weight: 0 到 1 的转场权重。
## [br]
## @return 插值后的透明度。
func sample_alpha(weight: float) -> float:
	return lerpf(from_alpha, to_alpha, clampf(weight, 0.0, 1.0))


## 复制转场效果配置。
## [br]
## @api public
## [br]
## @return 深拷贝后的转场效果。
func duplicate_effect() -> GFScreenTransitionEffect:
	var copy: GFScreenTransitionEffect = GFScreenTransitionEffect.new()
	copy.duration_seconds = duration_seconds
	copy.from_alpha = from_alpha
	copy.to_alpha = to_alpha
	copy.color = color
	copy.layer = layer
	copy.block_input = block_input
	copy.easing_mode = easing_mode
	copy.shader_material = _variant_to_shader_material(shader_material.duplicate(true)) if shader_material != null else null
	copy.progress_parameter = progress_parameter
	copy.metadata = metadata.duplicate(true)
	return copy


## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return 配置字典。
## [br]
## @schema return: Dictionary，包含 duration_seconds、from_alpha、to_alpha、color、layer、block_input、easing_mode、progress_parameter、has_shader_material 和 metadata。
func to_dict() -> Dictionary:
	return {
		"duration_seconds": duration_seconds,
		"from_alpha": from_alpha,
		"to_alpha": to_alpha,
		"color": color,
		"layer": layer,
		"block_input": block_input,
		"easing_mode": easing_mode,
		"progress_parameter": progress_parameter,
		"has_shader_material": shader_material != null,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 将 Variant 转为 ShaderMaterial；类型不匹配时返回 null。
## [br]
## @api private
## [br]
func _variant_to_shader_material(value: Variant) -> ShaderMaterial:
	if value is ShaderMaterial:
		var material: ShaderMaterial = value
		return material
	return null
