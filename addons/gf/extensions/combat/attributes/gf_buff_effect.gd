## GFBuffEffect: Buff 可组合效果基类。
##
## 作为数据化 Buff 的通用效果扩展点，响应 apply、remove、refresh 和 tick 生命周期。
## 基类不规定伤害、治疗、控制等业务语义；项目可通过子类实现具体效果。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 6.0.0
class_name GFBuffEffect
extends Resource


# --- 导出变量 ---

## 效果标识，用于诊断、状态快照或项目侧过滤。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var effect_id: StringName = &""

## 项目自定义元数据。GF 不解释其中字段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary project-defined effect metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 响应 Buff 应用。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema context: Dictionary with buff, owner, event, and metadata.
## [br]
## @schema return: Dictionary with ok, reason, effect_id, and metadata.
func apply(context: Dictionary) -> Dictionary:
	return _normalize_report(_apply(context), &"apply")


## 响应 Buff 移除。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema context: Dictionary with buff, owner, event, reason, and metadata.
## [br]
## @schema return: Dictionary with ok, reason, effect_id, and metadata.
func remove(context: Dictionary) -> Dictionary:
	return _normalize_report(_remove(context), &"remove")


## 响应 Buff 刷新。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema context: Dictionary with buff, owner, event, refresh_duration, and metadata.
## [br]
## @schema return: Dictionary with ok, reason, effect_id, and metadata.
func refresh(context: Dictionary) -> Dictionary:
	return _normalize_report(_refresh(context), &"refresh")


## 响应 Buff tick。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema context: Dictionary with buff, owner, event, delta, and metadata.
## [br]
## @schema return: Dictionary with ok, reason, effect_id, and metadata.
func tick(context: Dictionary) -> Dictionary:
	return _normalize_report(_tick(context), &"tick")


## 获取效果运行时状态快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 状态快照。
## [br]
## @schema return: Dictionary project-defined effect state payload.
func get_state_snapshot() -> Dictionary:
	return _get_state_snapshot()


## 恢复效果运行时状态。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param snapshot: 状态快照。
## [br]
## @schema snapshot: Dictionary project-defined effect state payload.
func restore_state_snapshot(snapshot: Dictionary) -> void:
	_restore_state_snapshot(snapshot)


# --- 可重写钩子 / 虚方法 ---

## Buff 应用钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema _context: Dictionary with buff, owner, event, and metadata.
## [br]
## @schema return: Dictionary with optional ok, reason, and metadata.
func _apply(_context: Dictionary) -> Dictionary:
	return { "ok": true }


## Buff 移除钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema _context: Dictionary with buff, owner, event, reason, and metadata.
## [br]
## @schema return: Dictionary with optional ok, reason, and metadata.
func _remove(_context: Dictionary) -> Dictionary:
	return { "ok": true }


## Buff 刷新钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema _context: Dictionary with buff, owner, event, refresh_duration, and metadata.
## [br]
## @schema return: Dictionary with optional ok, reason, and metadata.
func _refresh(_context: Dictionary) -> Dictionary:
	return { "ok": true }


## Buff tick 钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _context: Buff 生命周期上下文。
## [br]
## @return 效果报告。
## [br]
## @schema _context: Dictionary with buff, owner, event, delta, and metadata.
## [br]
## @schema return: Dictionary with optional ok, reason, and metadata.
func _tick(_context: Dictionary) -> Dictionary:
	return { "ok": true }


## 状态快照钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @return 状态快照。
## [br]
## @schema return: Dictionary project-defined effect state payload.
func _get_state_snapshot() -> Dictionary:
	return {}


## 状态恢复钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _snapshot: 状态快照。
## [br]
## @schema _snapshot: Dictionary project-defined effect state payload.
func _restore_state_snapshot(_snapshot: Dictionary) -> void:
	pass


# --- 私有/辅助方法 ---

func _normalize_report(report: Dictionary, event_name: StringName) -> Dictionary:
	var result: Dictionary = report.duplicate(true)
	result["ok"] = GFVariantData.get_option_bool(result, "ok", true)
	result["reason"] = GFVariantData.get_option_string_name(result, "reason")
	result["effect_id"] = effect_id
	result["event"] = event_name
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")
	var _merged_metadata: Dictionary = GFVariantData.merge_dictionary(report_metadata, metadata, false, true)
	result["metadata"] = report_metadata
	return result
