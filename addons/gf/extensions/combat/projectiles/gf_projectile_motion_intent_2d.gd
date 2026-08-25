## GFProjectileMotionIntent2D: 2D 移动策略的不可变输出。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFProjectileMotionIntent2D
extends RefCounted


## 定义 motion 计算的封闭输出种类。
## [br]
## @api public
## [br]
## @since unreleased
enum Kind {
	## 未配置 intent。
	NONE = 0,
	## 请求按 world-space 速度移动。
	MOVE = 1,
	## 策略拒绝产生可应用 intent。
	REJECTED = 2,
	## 策略正常请求结束当前 session。
	FINISH = 3,
}


var _kind: Kind = Kind.NONE
var _velocity: Vector2 = Vector2.ZERO
var _delta_seconds: float = 0.0
var _failure_reason: StringName = &""


## 构造 world-space MOVE intent。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param velocity: world-space 速度。
## [br]
## @param delta_seconds: 本 intent 对应的非负帧时长。
## [br]
## @return: 合法 MOVE intent；非法数值返回 REJECTED。
static func move(velocity: Vector2, delta_seconds: float) -> GFProjectileMotionIntent2D:
	var result: GFProjectileMotionIntent2D = GFProjectileMotionIntent2D.new()
	if not velocity.is_finite() or not is_finite(delta_seconds) or delta_seconds < 0.0:
		return rejected(&"invalid_motion_intent")
	result._kind = Kind.MOVE
	result._velocity = velocity
	result._delta_seconds = delta_seconds
	return result


## 构造被策略拒绝的 intent。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 稳定失败原因。
## [br]
## @return: REJECTED intent。
static func rejected(reason: StringName) -> GFProjectileMotionIntent2D:
	var result: GFProjectileMotionIntent2D = GFProjectileMotionIntent2D.new()
	result._kind = Kind.REJECTED
	result._failure_reason = reason if reason != &"" else &"motion_rejected"
	return result


## 构造正常结束当前 session 的 FINISH intent。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 不交给 body adapter 的 FINISH intent。
static func finish() -> GFProjectileMotionIntent2D:
	var result: GFProjectileMotionIntent2D = GFProjectileMotionIntent2D.new()
	result._kind = Kind.FINISH
	return result


## 返回 intent 种类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 封闭 `Kind` 值。
func get_kind() -> Kind:
	return _kind


## 返回 MOVE 的 world-space 速度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 2D world-space velocity。
func get_velocity() -> Vector2:
	return _velocity


## 返回 MOVE 对应的帧时长。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 非负秒数。
func get_delta_seconds() -> float:
	return _delta_seconds


## 返回 REJECTED 原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: REJECTED 时为非空稳定原因。
func get_failure_reason() -> StringName:
	return _failure_reason


## 返回 intent 是否为 runtime 可处理的非拒绝输出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: NONE、MOVE 或 FINISH 时为 true。
func is_valid() -> bool:
	return _kind != Kind.REJECTED
