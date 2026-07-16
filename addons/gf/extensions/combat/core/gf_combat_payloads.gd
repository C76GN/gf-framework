## GFCombatPayloads: 存放战斗相关的事件载体类。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 3.17.0
class_name GFCombatPayloads
extends Node


# --- 内部类 ---

## Buff 已应用事件。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 3.17.0
class GFBuffAppliedPayload extends GFPayload:
	## 目标对象。
	## [br]
	## @api public
	var target: Object
	
	## 已应用的 Buff 实例。
	## [br]
	## @api public
	var buff: GFBuff
	
	func _init(p_target: Object, p_buff: GFBuff) -> void:
		target = p_target
		buff = p_buff


## Buff 已变动/刷新事件。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 3.17.0
class GFBuffRefreshedPayload extends GFPayload:
	## 目标对象。
	## [br]
	## @api public
	var target: Object
	
	## 已刷新的 Buff 实例。
	## [br]
	## @api public
	var buff: GFBuff
	
	func _init(p_target: Object, p_buff: GFBuff) -> void:
		target = p_target
		buff = p_buff


## Buff 已移除事件。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 3.17.0
class GFBuffRemovedPayload extends GFPayload:
	## 目标对象。
	## [br]
	## @api public
	var target: Object
	
	## 被移除的 Buff ID。
	## [br]
	## @api public
	var buff_id: StringName

	## 移除原因。
	## [br]
	## @api public
	## [br]
	## @since 8.0.0
	var reason: StringName

	## Buff 移除生命周期报告。
	## [br]
	## @api public
	## [br]
	## @since 8.0.0
	## [br]
	## @schema lifecycle_report: Dictionary，GFBuff.on_remove() 返回报告的深副本。
	var lifecycle_report: Dictionary
	
	func _init(
		p_target: Object,
		p_buff_id: StringName,
		p_reason: StringName,
		p_lifecycle_report: Dictionary
	) -> void:
		target = p_target
		buff_id = p_buff_id
		reason = p_reason
		lifecycle_report = p_lifecycle_report.duplicate(true)
