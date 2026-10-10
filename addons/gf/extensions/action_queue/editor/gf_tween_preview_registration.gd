@tool

## GFTweenPreviewRegistration: 一次编辑器数值预览注册的所有权句柄。
##
## release 幂等且只撤销自身租约；旧句柄不能撤销同 ID 后续注册。持有者应在插件卸载时显式释放。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFTweenPreviewRegistration
extends RefCounted


# --- 私有变量 ---

## 负责本次租约的注册表；注册表不反向持有此句柄。
## [br]
## @api private
var _registry: GFTweenPreviewRegistry = null

## 注册 ID。
## [br]
## @api private
var _id: StringName = &""

## 单调租约号；零表示已释放。
## [br]
## @api private
var _lease: int = 0


# --- Godot 生命周期方法 ---

## 最后一个句柄引用释放时先脱离租约，再通知注册表；此时不能调用自身实例方法。
## [br]
## @api private
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var registry: GFTweenPreviewRegistry = _registry
		var adapter_id: StringName = _id
		var lease: int = _lease
		_registry = null
		_lease = 0
		if registry != null:
			registry._release(adapter_id, lease)


# --- 公共方法 ---

## 撤销本句柄注册，允许重复调用。
## [br]
## @api public
## [br]
## @since unreleased
func release() -> void:
	var registry: GFTweenPreviewRegistry = _registry
	var adapter_id: StringName = _id
	var lease: int = _lease
	_registry = null
	_lease = 0
	if registry != null:
		registry._release(adapter_id, lease)


## 返回当前句柄是否仍对应有效 owner 和租约。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 有效时为 true。
func is_active() -> bool:
	return _registry != null and _registry._has_lease(_id, _lease)


# --- 框架内部方法 ---

## 仅由成功注册的表绑定句柄，不替换已有租约。
## [br]
## @api framework_internal
## [br]
## @param registry: 注册所有者。
## [br]
## @param adapter_id: 已接纳 ID。
## [br]
## @param lease: 已接纳的正租约号。
func _bind(registry: GFTweenPreviewRegistry, adapter_id: StringName, lease: int) -> void:
	_registry = registry
	_id = adapter_id
	_lease = lease
