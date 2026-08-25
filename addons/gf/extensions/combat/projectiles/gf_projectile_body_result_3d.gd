## GFProjectileBodyResult3D: 3D body adapter 的捕获或应用结果。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFProjectileBodyResult3D
extends RefCounted


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 私有变量 ---

var _successful: bool = false
var _failure_reason: StringName = &"unconfigured"
var _transform: Transform3D = Transform3D.IDENTITY
var _actual_displacement: Vector3 = Vector3.ZERO


# --- 公共方法 ---

## 构造成功的 3D body 结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param transform_value: 应用后的 world transform。
## [br]
## @param actual_displacement: 本次操作产生的真实 world displacement。
## [br]
## @return: 成功结果。
static func successful(
	transform_value: Transform3D,
	actual_displacement: Vector3 = Vector3.ZERO
) -> GFProjectileBodyResult3D:
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_transform3d(transform_value)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(actual_displacement)
	):
		return failed(&"non_finite_body_result")
	var result: GFProjectileBodyResult3D = GFProjectileBodyResult3D.new()
	result._successful = true
	result._failure_reason = &""
	result._transform = transform_value
	result._actual_displacement = actual_displacement
	return result


## 构造失败的 3D body 结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 非空失败原因。
## [br]
## @param transform_value: 失败边界观测到的 transform。
## [br]
## @return: 失败结果。
static func failed(
	reason: StringName,
	transform_value: Transform3D = Transform3D.IDENTITY
) -> GFProjectileBodyResult3D:
	var result: GFProjectileBodyResult3D = GFProjectileBodyResult3D.new()
	result._failure_reason = reason if reason != &"" else &"body_operation_failed"
	if _GF_COMBAT_FINITE_MATH.is_finite_transform3d(transform_value):
		result._transform = transform_value
	return result


## 返回 body 操作是否成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时为 true。
func is_successful() -> bool:
	return _successful


## 返回失败原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功结果为空，失败结果为稳定原因。
func get_failure_reason() -> StringName:
	return _failure_reason


## 返回操作后的 world transform。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 3D transform 快照。
func get_transform() -> Transform3D:
	return _transform


## 返回 transform 的 world position。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 3D world position。
func get_position() -> Vector3:
	return _transform.origin


## 返回本次操作实际产生的 world displacement。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 真实位移向量；捕获或停止操作为零。
func get_actual_displacement() -> Vector3:
	return _actual_displacement
