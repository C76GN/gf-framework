## GFProjectileBodyAdapter3D: 3D 发射体宿主运动适配协议。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFProjectileBodyAdapter3D
extends Resource


# --- 公共方法 ---

## 校验完整实例 root 是否由本 adapter 支持。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root: 待驱动的完整 projectile root。
## [br]
## @return: `OK` 表示支持，否则返回确定错误码。
func validate_root(root: Node) -> Error:
	var result: Variant = _validate_root(root)
	if not result is int:
		return ERR_INVALID_DATA
	var error_code: int = result
	return error_code as Error


## 捕获运动计算所需的当前 body 快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root: 已通过 `validate_root()` 的 root。
## [br]
## @return: 当前 transform 与零实际位移的 typed 结果。
func capture_body(root: Node) -> GFProjectileBodyResult3D:
	var result: Variant = _capture_body(root)
	if typeof(result) == TYPE_OBJECT and is_instance_valid(result) and result is GFProjectileBodyResult3D:
		var typed_result: GFProjectileBodyResult3D = result
		return typed_result
	return GFProjectileBodyResult3D.failed(&"invalid_adapter_result")


## 将一次 typed intent 应用于 root。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root: 已通过 `validate_root()` 的 root。
## [br]
## @param intent: 本帧 motion intent。
## [br]
## @return: 应用后的 transform 与实际 world displacement。
func apply_intent(
	root: Node,
	intent: GFProjectileMotionIntent3D
) -> GFProjectileBodyResult3D:
	var result: Variant = _apply_intent(root, intent)
	if typeof(result) == TYPE_OBJECT and is_instance_valid(result) and result is GFProjectileBodyResult3D:
		var typed_result: GFProjectileBodyResult3D = result
		return typed_result
	return GFProjectileBodyResult3D.failed(&"invalid_adapter_result")


## 停止 root 的运动 authority，不产生额外位移。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root: 已通过 `validate_root()` 的 root。
## [br]
## @return: 停止后的 body 快照。
func stop(root: Node) -> GFProjectileBodyResult3D:
	var result: Variant = _stop(root)
	if typeof(result) == TYPE_OBJECT and is_instance_valid(result) and result is GFProjectileBodyResult3D:
		var typed_result: GFProjectileBodyResult3D = result
		return typed_result
	return GFProjectileBodyResult3D.failed(&"invalid_adapter_result")


# --- 可重写钩子 / 虚方法 ---

## 实现具体 root 准入规则。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _root: 待校验 root。
## [br]
## @return: `OK` 或确定错误码。
## [br]
## @schema return: Variant，必须为 `Error` 整数值；其他值由公开入口收窄为 `ERR_INVALID_DATA`。
func _validate_root(_root: Node) -> Variant:
	return ERR_UNAVAILABLE


## 捕获具体 body 快照。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _root: 已通过校验的 root。
## [br]
## @return: typed body 结果。
## [br]
## @schema return: Variant，必须为 live `GFProjectileBodyResult3D`。
func _capture_body(_root: Node) -> Variant:
	return GFProjectileBodyResult3D.failed(&"unsupported_body")


## 应用具体 body intent。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _root: 已通过校验的 root。
## [br]
## @param _intent: 本帧 intent。
## [br]
## @return: typed body 结果。
## [br]
## @schema return: Variant，必须为 live `GFProjectileBodyResult3D`。
func _apply_intent(
	_root: Node,
	_intent: GFProjectileMotionIntent3D
) -> Variant:
	return GFProjectileBodyResult3D.failed(&"unsupported_body")


## 停止具体 body。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _root: 已通过校验的 root。
## [br]
## @return: typed body 结果。
## [br]
## @schema return: Variant，必须为 live `GFProjectileBodyResult3D`。
func _stop(_root: Node) -> Variant:
	return GFProjectileBodyResult3D.failed(&"unsupported_body")
