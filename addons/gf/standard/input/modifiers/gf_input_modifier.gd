## GFInputModifier: 输入值修饰器基类。
##
## 修饰器只处理输入值转换，不决定动作是否触发。可挂在 GFInputBinding 或
## GFInputMapping 上，用于死区、缩放、归一化、范围映射等通用处理。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFInputModifier
extends Resource


# --- 公共方法 ---

## 修饰输入贡献值。
## [br]
## @api public
## [br]
## @param value: 当前二维贡献值；布尔与一维轴使用 x 分量。
## [br]
## @param _event: 产生该贡献的原生输入事件，可能为 null。
## [br]
## @param _action: 当前输入动作。
## [br]
## @return 修饰后的贡献值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	return value


## 修饰三维输入贡献值。
## 默认复用二维修饰逻辑处理 X/Y，并保留 Z 分量。
## [br]
## @api public
## [br]
## @param value: 当前三维贡献值。
## [br]
## @param event: 产生该贡献的原生输入事件，可能为 null。
## [br]
## @param action: 当前输入动作。
## [br]
## @return 修饰后的三维贡献值。
func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:
	var xy: Vector2 = modify(Vector2(value.x, value.y), event, action)
	return Vector3(xy.x, xy.y, value.z)


## 创建运行时副本。
## [br]
## @api public
## [br]
## @return 修饰器副本。
func duplicate_modifier() -> GFInputModifier:
	var modifier: Resource = duplicate(true)
	if modifier is GFInputModifier:
		var input_modifier: GFInputModifier = modifier
		return input_modifier
	return null


## 当前修饰器是否维护运行时状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 有运行时状态时返回 true。
func supports_runtime_state() -> bool:
	return false


## 获取运行时状态快照。
## 无状态修饰器返回空字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前运行时状态。
## [br]
## @schema return: Dictionary，具体字段由修饰器实现定义。
func get_modifier_runtime_state() -> Dictionary:
	return {}


## 从运行时状态快照恢复修饰器。
## 无状态修饰器忽略该调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param state: get_modifier_runtime_state() 生成的状态。
## [br]
## @schema state: Dictionary，具体字段由修饰器实现定义。
## [br]
## @return 当前修饰器。
func restore_modifier_runtime_state(state: Dictionary) -> GFInputModifier:
	var _unused_state: Dictionary = state
	return self


## 重置运行时状态。
## 无状态修饰器忽略该调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前修饰器。
func reset_modifier_runtime_state() -> GFInputModifier:
	return self


## 设置修饰器下一步使用的运行时 delta 秒数。
## 不依赖 delta 的修饰器忽略该调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta_seconds: 运行时 delta 秒数；小于 0 时实现应按 0 处理。
## [br]
## @return 当前修饰器。
func set_runtime_delta_seconds(delta_seconds: float) -> GFInputModifier:
	var _unused_delta_seconds: float = delta_seconds
	return self


## 清除手动运行时 delta，恢复修饰器默认时间源。
## 不依赖 delta 的修饰器忽略该调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前修饰器。
func clear_runtime_delta_seconds() -> GFInputModifier:
	return self
