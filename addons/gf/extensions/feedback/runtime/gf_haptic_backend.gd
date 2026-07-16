## GFHapticBackend: 震动输出后端协议。
##
## 项目可实现该协议，把 GFHapticUtility 的采样输出路由到平台 SDK、远程设备、
## 测试替身或自定义输入系统。该协议只承载输出能力，不定义播放策略。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
class_name GFHapticBackend
extends RefCounted


# --- 公共方法 ---

## 开始或刷新一次震动输出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param target_type: GFHapticUtility.TargetType 值。
## [br]
## @param target_id: 玩家索引或设备 ID。
## [br]
## @param weak_magnitude: 弱马达强度。
## [br]
## @param strong_magnitude: 强马达强度。
## [br]
## @param duration_seconds: 输出持续时间。
## [br]
## @param metadata: 输出元数据。
## [br]
## @schema metadata: Dictionary copied from GFHapticUtility output target metadata.
## [br]
## @return: 后端接受输出时返回 true。
func start_output(
	target_type: int,
	target_id: int,
	weak_magnitude: float,
	strong_magnitude: float,
	duration_seconds: float,
	metadata: Dictionary = {}
) -> bool:
	return _start_output(target_type, target_id, weak_magnitude, strong_magnitude, duration_seconds, metadata)


## 停止指定目标的震动输出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param target_type: GFHapticUtility.TargetType 值。
## [br]
## @param target_id: 玩家索引或设备 ID。
## [br]
## @param metadata: 输出元数据。
## [br]
## @schema metadata: Dictionary copied from GFHapticUtility output target metadata.
## [br]
## @return: 后端确认停止时返回 true。
func stop_output(target_type: int, target_id: int, metadata: Dictionary = {}) -> bool:
	return _stop_output(target_type, target_id, metadata)


# --- 可重写钩子 / 虚方法 ---

## 子类实现开始或刷新震动输出。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _target_type: GFHapticUtility.TargetType 值。
## [br]
## @param _target_id: 玩家索引或设备 ID。
## [br]
## @param _weak_magnitude: 弱马达强度。
## [br]
## @param _strong_magnitude: 强马达强度。
## [br]
## @param _duration_seconds: 输出持续时间。
## [br]
## @param _metadata: 输出元数据。
## [br]
## @schema _metadata: Dictionary copied from GFHapticUtility output target metadata.
## [br]
## @return: 后端接受输出时返回 true。
func _start_output(
	_target_type: int,
	_target_id: int,
	_weak_magnitude: float,
	_strong_magnitude: float,
	_duration_seconds: float,
	_metadata: Dictionary = {}
) -> bool:
	return false


## 子类实现停止震动输出。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _target_type: GFHapticUtility.TargetType 值。
## [br]
## @param _target_id: 玩家索引或设备 ID。
## [br]
## @param _metadata: 输出元数据。
## [br]
## @schema _metadata: Dictionary copied from GFHapticUtility output target metadata.
## [br]
## @return: 后端确认停止时返回 true。
func _stop_output(_target_type: int, _target_id: int, _metadata: Dictionary = {}) -> bool:
	return false
