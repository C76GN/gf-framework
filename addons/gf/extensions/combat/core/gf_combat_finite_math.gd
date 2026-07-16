# Combat 扩展内部有限数值契约。
extends RefCounted


# --- 层内方法 ---

## 判断浮点值是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @return 有限时返回 true。
static func is_finite_float(value: float) -> bool:
	return is_finite(value)


## 判断 Vector2 所有分量是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


## 判断 Vector3 所有分量是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


## 判断 Transform2D 所有分量是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_transform2d(value: Transform2D) -> bool:
	return (
		is_finite_vector2(value.x)
		and is_finite_vector2(value.y)
		and is_finite_vector2(value.origin)
	)


## 判断 Basis 所有分量是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_basis(value: Basis) -> bool:
	return (
		is_finite_vector3(value.x)
		and is_finite_vector3(value.y)
		and is_finite_vector3(value.z)
	)


## 判断 Transform3D 所有分量是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_transform3d(value: Transform3D) -> bool:
	return is_finite_basis(value.basis) and is_finite_vector3(value.origin)


## 返回有限非负值，否则使用有限非负回退。
## [br]
## @api layer_internal
## [br]
## @layer extensions/combat
## [br]
## @param value: 待检查值。
## [br]
## @param fallback: 非法值回退。
## [br]
## @return 有限非负值。
static func non_negative_or(value: float, fallback: float = 0.0) -> float:
	var safe_fallback: float = maxf(fallback, 0.0) if is_finite(fallback) else 0.0
	return maxf(value, 0.0) if is_finite(value) else safe_fallback
