## GFCombatHitContext: 一次通用命中交互的上下文。
##
## 只保存 source、target、hit_id、payload、位置和元数据。
## 它不解释伤害、阵营、生命值、命中结果或任何业务语义。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFCombatHitContext
extends RefCounted


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 公共变量 ---

## 命中发起者。
## [br]
## @api public
var source: Object = null

## 命中目标。
## [br]
## @api public
var target: Object = null

## 命中 ID。
## [br]
## @api public
var hit_id: StringName = &""

## 命中携带的数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema payload: Variant，项目自定义命中载荷；框架只复制并透传。
var payload: Variant:
	get:
		return GFVariantData.duplicate_variant(_payload)
	set(value):
		_payload = GFVariantData.duplicate_variant(value)

## 通用强度值。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
var magnitude: float:
	get:
		return _magnitude
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_float(value):
			_magnitude = value

## 命中标签。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
var tags: Array[StringName]:
	get:
		return _tags.duplicate()
	set(value):
		_tags = value.duplicate()

## 2D 命中位置。
## [br]
## @api public
## [br]
## @since 3.17.0
var position_2d: Vector2:
	get:
		return _position_2d
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_vector2(value):
			_position_2d = value

## 2D 命中法线。
## [br]
## @api public
## [br]
## @since 3.17.0
var normal_2d: Vector2:
	get:
		return _normal_2d
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_vector2(value):
			_normal_2d = value

## 3D 命中位置。
## [br]
## @api public
## [br]
## @since 3.17.0
var position_3d: Vector3:
	get:
		return _position_3d
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_vector3(value):
			_position_3d = value

## 3D 命中法线。
## [br]
## @api public
## [br]
## @since 3.17.0
var normal_3d: Vector3:
	get:
		return _normal_3d
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_vector3(value):
			_normal_3d = value

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: Dictionary，项目自定义命中元数据；框架只复制并透传。
var metadata: Dictionary:
	get:
		return _metadata.duplicate(true)
	set(value):
		_metadata = value.duplicate(true)


# --- 私有变量 ---

var _payload: Variant = null
var _magnitude: float = 0.0
var _tags: Array[StringName] = []
var _position_2d: Vector2 = Vector2.ZERO
var _normal_2d: Vector2 = Vector2.ZERO
var _position_3d: Vector3 = Vector3.ZERO
var _normal_3d: Vector3 = Vector3.ZERO
var _metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_source: Object = null,
	p_target: Object = null,
	p_payload: Variant = null,
	p_hit_id: StringName = &""
) -> void:
	source = p_source
	target = p_target
	payload = p_payload
	hit_id = p_hit_id


# --- 公共方法 ---

## 设置 source 并返回自身。
## [br]
## @api public
## [br]
## @param value: source 对象。
## [br]
## @return 当前上下文。
func with_source(value: Object) -> GFCombatHitContext:
	source = value
	return self


## 设置 target 并返回自身。
## [br]
## @api public
## [br]
## @param value: target 对象。
## [br]
## @return 当前上下文。
func with_target(value: Object) -> GFCombatHitContext:
	target = value
	return self


## 设置 hit_id 并返回自身。
## [br]
## @api public
## [br]
## @param value: 命中 ID。
## [br]
## @return 当前上下文。
func with_hit_id(value: StringName) -> GFCombatHitContext:
	hit_id = value
	return self


## 设置 payload 并返回自身。
## [br]
## @api public
## [br]
## @param value: payload 数据。
## [br]
## @return 当前上下文。
## [br]
## @schema value: Variant，项目自定义命中载荷；框架只复制并透传。
func with_payload(value: Variant) -> GFCombatHitContext:
	payload = value
	return self


## 设置通用强度值并返回自身。
## [br]
## @api public
## [br]
## @param value: 通用强度值。
## [br]
## @return 当前上下文。
func with_magnitude(value: float) -> GFCombatHitContext:
	magnitude = value
	return self


## 设置标签并返回自身。
## [br]
## @api public
## [br]
## @param value: 标签数组。
## [br]
## @return 当前上下文。
func with_tags(value: Array[StringName]) -> GFCombatHitContext:
	tags = value.duplicate()
	return self


## 设置元数据并返回自身。
## [br]
## @api public
## [br]
## @param value: 元数据。
## [br]
## @return 当前上下文。
## [br]
## @schema value: Dictionary，项目自定义命中元数据；框架只复制并透传。
func with_metadata(value: Dictionary) -> GFCombatHitContext:
	metadata = value.duplicate(true)
	return self


## 转换为字典快照。
## [br]
## @api public
## [br]
## @return 字典快照。
## [br]
## @schema return: Dictionary，包含 source、target、hit_id、payload、magnitude、tags、position_2d、normal_2d、position_3d、normal_3d 和 metadata。
func to_dict() -> Dictionary:
	return {
		"source": source,
		"target": target,
		"hit_id": hit_id,
		"payload": GFVariantData.duplicate_variant(payload),
		"magnitude": magnitude,
		"tags": tags.duplicate(),
		"position_2d": position_2d,
		"normal_2d": normal_2d,
		"position_3d": position_3d,
		"normal_3d": normal_3d,
		"metadata": metadata.duplicate(true),
	}


## 转换为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 报告字典快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on to_dict().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(to_dict(), options)
