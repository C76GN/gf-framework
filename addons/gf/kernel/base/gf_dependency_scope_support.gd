# 架构依赖作用域共享实现。
#
# 该脚本供 GFModel、GFSystem、GFUtility、GFCommand 与 GFQuery 复用，
# 用于保持注入架构、释放状态和全局回退规则一致。
extends RefCounted


# --- 常量 ---

## 读取作用域字典中可能为 Variant 的状态字段。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 框架内部方法 ---

## 为模块或执行对象创建未绑定作用域；只有从未绑定的作用域允许全局架构回退。
## [br]
## @api framework_internal
## [br]
## @return: 独立的可变作用域字典。
## [br]
## @schema return: {"type":"Dictionary","description":"architecture_ref 为 WeakRef 或 null；was_bound、released 为状态标记，lifecycle_serial 为代次，-1 表示未限定代次。"}
static func _make_scope() -> Dictionary:
	return {
		"architecture_ref": null,
		"was_bound": false,
		"released": false,
		"lifecycle_serial": -1,
	}


## 更新作用域弱引用；同一架构未指定代次时保留旧代次，换架构时清除旧代次。
## [br]
## @api framework_internal
## [br]
## @param scope: 要原地更新的依赖作用域。
## [br]
## @param architecture: 注入架构；null 表示释放作用域。
## [br]
## @param lifecycle_serial: 非负值限定生命周期代次，-1 保留或清除已有代次。
## [br]
## @schema scope: {"type":"Dictionary","description":"由 _make_scope 创建，包含 architecture_ref、was_bound、released、lifecycle_serial。"}
static func _bind_scope(scope: Dictionary, architecture: GFArchitecture, lifecycle_serial: int = -1) -> void:
	if architecture == null:
		_release_scope(scope)
		return

	var previous_architecture: GFArchitecture = _get_bound_architecture_or_null(scope)
	scope["was_bound"] = true
	scope["released"] = false
	scope["architecture_ref"] = weakref(architecture)
	if lifecycle_serial >= 0:
		scope["lifecycle_serial"] = lifecycle_serial
	elif previous_architecture != architecture:
		scope["lifecycle_serial"] = -1


## 清除架构弱引用和生命周期代次；曾绑定过架构的作用域会保留 released 标记。
## [br]
## @api framework_internal
## [br]
## @param scope: 要原地释放的作用域；未曾绑定的作用域不设置 released。
## [br]
## @schema scope: {"type":"Dictionary","description":"由 _make_scope 创建的作用域状态字典。"}
static func _release_scope(scope: Dictionary) -> void:
	scope["architecture_ref"] = null
	scope["lifecycle_serial"] = -1
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "was_bound"):
		scope["released"] = true


## 读取仍属于当前代次的注入架构；释放或弱引用失效时拒绝全局回退。
## [br]
## @api framework_internal
## [br]
## @param scope: 要读取的依赖作用域。
## [br]
## @param owner_label: 诊断消息中标识调用方的名称。
## [br]
## @return: 有效注入架构、尚未绑定时的全局架构，或 null。
## [br]
## @schema scope: {"type":"Dictionary","description":"由 _make_scope 创建并由 _bind_scope/_release_scope 维护的状态。"}
static func _get_architecture_or_null(scope: Dictionary, owner_label: String) -> GFArchitecture:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "released"):
		push_error("[GFDependencyScopeSupport][dependency_scope_support.scope_disposed] %s cannot access the architecture because its dependency scope is disposed." % owner_label)
		return null

	var architecture_ref: WeakRef = _get_scope_architecture_ref_or_null(scope)
	if architecture_ref != null:
		var architecture: GFArchitecture = _get_architecture_from_ref_or_null(architecture_ref)
		if architecture != null:
			if not _is_scope_lifecycle_current(scope, architecture):
				return null
			return architecture
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "was_bound"):
			push_error("[GFDependencyScopeSupport][dependency_scope_support.architecture_invalid] %s cannot fall back to the global architecture because its injected architecture is invalid." % owner_label)
			return null
	return GFAutoload.get_architecture_or_null()


## 在未曾绑定且未释放时允许创建全局架构；已绑定作用域不能借全局架构恢复失效引用。
## [br]
## @api framework_internal
## [br]
## @param scope: 要读取的依赖作用域。
## [br]
## @param owner_label: 传给作用域诊断的调用方名称。
## [br]
## @return: 有效注入或全局架构；已绑定但不可用时返回 null。
## [br]
## @schema scope: {"type":"Dictionary","description":"由 _make_scope 创建的架构弱引用与绑定、释放、代次状态。"}
static func _get_architecture_or_global(scope: Dictionary, owner_label: String) -> GFArchitecture:
	var architecture: GFArchitecture = _get_architecture_or_null(scope, owner_label)
	if architecture != null:
		return architecture
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "was_bound")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "released")
	):
		return null
	return GFAutoload.get_architecture()


## 仅解析字典中当前的 WeakRef，不执行生命周期检查或全局架构回退。
## [br]
## @api framework_internal
## [br]
## @param scope: 要读取绑定引用的作用域。
## [br]
## @return: 弱引用指向的 GFArchitecture，无法解析时返回 null。
## [br]
## @schema scope: {"type":"Dictionary","description":"读取 architecture_ref；其他作用域字段在此查询中不参与判定。"}
static func _get_bound_architecture_or_null(scope: Dictionary) -> GFArchitecture:
	var architecture_ref: WeakRef = _get_scope_architecture_ref_or_null(scope)
	if architecture_ref == null:
		return null
	return _get_architecture_from_ref_or_null(architecture_ref)


## 先按作用域代次解析架构，再查询架构生命周期是否仍活动。
## [br]
## @api framework_internal
## [br]
## @param scope: 调用对象的依赖作用域。
## [br]
## @param owner_label: 解析失败诊断中的调用方名称。
## [br]
## @return: 作用域可解析且架构生命周期活动时为 true。
## [br]
## @schema scope: {"type":"Dictionary","description":"由 _make_scope 创建的架构引用、绑定状态及生命周期代次。"}
static func _is_lifecycle_active(scope: Dictionary, owner_label: String) -> bool:
	var architecture: GFArchitecture = _get_architecture_or_null(scope, owner_label)
	return architecture != null and architecture.is_lifecycle_active()


# --- 私有/辅助方法 ---

## 未记录生命周期代次时视为当前；否则由架构确认该代次仍然活动。
## [br]
## @api private
static func _is_scope_lifecycle_current(scope: Dictionary, architecture: GFArchitecture) -> bool:
	var lifecycle_serial: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scope, "lifecycle_serial", -1)
	if lifecycle_serial < 0:
		return true
	return architecture.is_lifecycle_generation_active(lifecycle_serial)


## 从作用域字典读取 architecture_ref；字段不是 WeakRef 时返回 null。
## [br]
## @api private
static func _get_scope_architecture_ref_or_null(scope: Dictionary) -> WeakRef:
	var raw_ref: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(scope, "architecture_ref")
	if raw_ref is WeakRef:
		return raw_ref
	return null


## 解析弱引用，并仅返回 GFArchitecture 实例。
## [br]
## @api private
static func _get_architecture_from_ref_or_null(architecture_ref: WeakRef) -> GFArchitecture:
	var raw_architecture: Variant = architecture_ref.get_ref()
	if raw_architecture is GFArchitecture:
		var architecture: GFArchitecture = raw_architecture
		return architecture
	return null
