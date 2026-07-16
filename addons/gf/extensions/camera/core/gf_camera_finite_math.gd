# Camera 扩展内部有限数值与姿态收敛工具。
extends RefCounted


# --- 常量 ---

const _BASIS_EPSILON: float = 0.000001


# --- 层内方法 ---

## 判断浮点数是否有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查值。
## [br]
## @return 值有限时返回 true。
static func is_finite_float(value: float) -> bool:
	return is_finite(value)


## 收敛浮点数。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查值。
## [br]
## @param fallback: 非法值回退。
## [br]
## @return 有限浮点数。
static func sanitize_float(value: float, fallback: float = 0.0) -> float:
	var safe_fallback: float = fallback if is_finite(fallback) else 0.0
	return value if is_finite(value) else safe_fallback


## 判断 Vector2 是否完全有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查向量。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


## 收敛 Vector2。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查向量。
## [br]
## @param fallback: 非法值回退。
## [br]
## @return 所有分量有限的向量。
static func sanitize_vector2(value: Vector2, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var safe_fallback: Vector2 = fallback if is_finite_vector2(fallback) else Vector2.ZERO
	return value if is_finite_vector2(value) else safe_fallback


## 判断 Vector3 是否完全有限。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查向量。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


## 收敛 Vector3。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查向量。
## [br]
## @param fallback: 非法值回退。
## [br]
## @return 所有分量有限的向量。
static func sanitize_vector3(value: Vector3, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var safe_fallback: Vector3 = fallback if is_finite_vector3(fallback) else Vector3.ZERO
	return value if is_finite_vector3(value) else safe_fallback


## 判断 Basis 是否有限且可构成稳定旋转。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查 Basis。
## [br]
## @return Basis 有限且非退化时返回 true。
static func is_valid_basis(value: Basis) -> bool:
	if (
		not is_finite_vector3(value.x)
		or not is_finite_vector3(value.y)
		or not is_finite_vector3(value.z)
	):
		return false
	if (
		value.x.length_squared() <= _BASIS_EPSILON
		or value.y.length_squared() <= _BASIS_EPSILON
		or value.z.length_squared() <= _BASIS_EPSILON
	):
		return false
	var determinant: float = value.determinant()
	return is_finite(determinant) and absf(determinant) > _BASIS_EPSILON


## 把 Basis 收敛为正交有限旋转。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查 Basis。
## [br]
## @param fallback: 非法值回退。
## [br]
## @return 有限正交 Basis。
static func sanitize_basis(value: Basis, fallback: Basis = Basis.IDENTITY) -> Basis:
	var safe_fallback: Basis = fallback.orthonormalized() if is_valid_basis(fallback) else Basis.IDENTITY
	if not is_valid_basis(value):
		return safe_fallback
	var normalized: Basis = value.orthonormalized()
	return normalized if is_valid_basis(normalized) else safe_fallback


## 判断 Transform3D 是否可安全应用到 Camera3D。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查 Transform3D。
## [br]
## @return origin 与 basis 均有效时返回 true。
static func is_valid_transform3d(value: Transform3D) -> bool:
	return is_finite_vector3(value.origin) and is_valid_basis(value.basis)


## 把 Transform3D 收敛为有限姿态。
## [br]
## @api layer_internal
## [br]
## @layer extensions/camera
## [br]
## @param value: 待检查 Transform3D。
## [br]
## @param fallback: 非法分量回退。
## [br]
## @return 可安全应用的 Transform3D。
static func sanitize_transform3d(
	value: Transform3D,
	fallback: Transform3D = Transform3D.IDENTITY
) -> Transform3D:
	var safe_fallback_origin: Vector3 = sanitize_vector3(fallback.origin, Vector3.ZERO)
	var safe_fallback_basis: Basis = sanitize_basis(fallback.basis, Basis.IDENTITY)
	return Transform3D(
		sanitize_basis(value.basis, safe_fallback_basis),
		sanitize_vector3(value.origin, safe_fallback_origin)
	)
