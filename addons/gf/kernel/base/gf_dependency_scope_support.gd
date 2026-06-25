# 架构依赖作用域共享实现。
#
# 该脚本供 GFModel、GFSystem、GFUtility、GFCommand 与 GFQuery 复用，
# 用于保持注入架构、释放状态和全局回退规则一致。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有/辅助方法 ---

static func _make_scope() -> Dictionary:
	return {
		"architecture_ref": null,
		"was_bound": false,
		"released": false,
		"lifecycle_serial": -1,
	}


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


static func _release_scope(scope: Dictionary) -> void:
	scope["architecture_ref"] = null
	scope["lifecycle_serial"] = -1
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "was_bound"):
		scope["released"] = true


static func _get_architecture_or_null(scope: Dictionary, owner_label: String) -> GFArchitecture:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "released"):
		push_error("[%s] 依赖作用域已释放，无法继续访问架构。" % owner_label)
		return null

	var architecture_ref: WeakRef = _get_scope_architecture_ref_or_null(scope)
	if architecture_ref != null:
		var architecture: GFArchitecture = _get_architecture_from_ref_or_null(architecture_ref)
		if architecture != null:
			if not _is_scope_lifecycle_current(scope, architecture):
				return null
			return architecture
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scope, "was_bound"):
			push_error("[%s] 注入的架构已失效，无法回退到全局架构。" % owner_label)
			return null
	return GFAutoload.get_architecture_or_null()


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


static func _get_bound_architecture_or_null(scope: Dictionary) -> GFArchitecture:
	var architecture_ref: WeakRef = _get_scope_architecture_ref_or_null(scope)
	if architecture_ref == null:
		return null
	return _get_architecture_from_ref_or_null(architecture_ref)


static func _is_lifecycle_active(scope: Dictionary, owner_label: String) -> bool:
	var architecture: GFArchitecture = _get_architecture_or_null(scope, owner_label)
	return architecture != null and architecture.is_lifecycle_active()


static func _is_scope_lifecycle_current(scope: Dictionary, architecture: GFArchitecture) -> bool:
	var lifecycle_serial: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scope, "lifecycle_serial", -1)
	if lifecycle_serial < 0:
		return true
	return architecture.is_lifecycle_generation_active(lifecycle_serial)


static func _get_scope_architecture_ref_or_null(scope: Dictionary) -> WeakRef:
	var raw_ref: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(scope, "architecture_ref")
	if raw_ref is WeakRef:
		return raw_ref
	return null


static func _get_architecture_from_ref_or_null(architecture_ref: WeakRef) -> GFArchitecture:
	var raw_architecture: Variant = architecture_ref.get_ref()
	if raw_architecture is GFArchitecture:
		var architecture: GFArchitecture = raw_architecture
		return architecture
	return null
