@tool

# GF 包管理器后台执行器。
#
# 仅在编辑器包管理页面内部使用，用于把耗时的 registry 读取、下载缓存、
# archive 校验和文件事务放到后台线程中执行。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PACKAGE_MANAGER_BACKEND = preload("res://addons/gf/kernel/package/gf_package_manager_backend.gd")


# --- 私有变量 ---

var _cancel_mutex: Mutex = Mutex.new()
var _cancel_requested: bool = false


# --- 层内方法 ---

## 请求取消当前后台包管理操作。
## [br]
## @api layer_internal
## [br]
## @layer kernel/editor
func cancel() -> void:
	_cancel_mutex.lock()
	_cancel_requested = true
	_cancel_mutex.unlock()


## 返回当前后台包管理操作是否已被请求取消。
## [br]
## @api layer_internal
## [br]
## @layer kernel/editor
## [br]
## @return 已请求取消时返回 true。
func is_cancel_requested() -> bool:
	_cancel_mutex.lock()
	var result: bool = _cancel_requested
	_cancel_mutex.unlock()
	return result


## 执行包管理后台请求。
## [br]
## @api layer_internal
## [br]
## @layer kernel/editor
## [br]
## @param request: 包管理请求。
## [br]
## @schema request: Dictionary，包含 operation、registry_value、project_root、lockfile_path、options、package_ids、dry_run 等字段。
## [br]
## @return 包管理结果。
## [br]
## @schema return: Dictionary，与 Godot 原生包管理后端 status、install 或 uninstall 结果一致。
func run_request(request: Dictionary) -> Dictionary:
	var operation: String = _GF_VARIANT_ACCESS.get_option_string(request, "operation")
	var registry_value: String = _GF_VARIANT_ACCESS.get_option_string(request, "registry_value")
	var project_root: String = _GF_VARIANT_ACCESS.get_option_string(request, "project_root")
	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(request, "lockfile_path", ".gf/packages.lock.json")
	var options: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(request, "options").duplicate(true)
	options["cancel_callback"] = Callable(self, "is_cancel_requested")
	if is_cancel_requested():
		return _make_cancelled_result(operation)
	if operation == "status":
		return _GF_PACKAGE_MANAGER_BACKEND.make_status(registry_value, project_root, lockfile_path, options)

	var package_ids: PackedStringArray = _read_package_ids(request)
	var dry_run: bool = _GF_VARIANT_ACCESS.get_option_bool(request, "dry_run", false)
	if operation == "install":
		var reason: String = _GF_VARIANT_ACCESS.get_option_string(request, "reason", "manual")
		return _GF_PACKAGE_MANAGER_BACKEND.install_packages(
			package_ids,
			registry_value,
			project_root,
			lockfile_path,
			reason,
			dry_run,
			options
		)
	if operation == "update":
		var update_all_installed: bool = _GF_VARIANT_ACCESS.get_option_bool(request, "all_installed", false)
		return _GF_PACKAGE_MANAGER_BACKEND.update_packages(
			package_ids,
			registry_value,
			project_root,
			lockfile_path,
			update_all_installed,
			dry_run,
			options
		)
	if operation == "uninstall":
		var force: bool = _GF_VARIANT_ACCESS.get_option_bool(request, "force", false)
		return _GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
			package_ids,
			registry_value,
			project_root,
			lockfile_path,
			force,
			dry_run,
			options
		)
	return {
		"ok": false,
		"operation": operation,
		"backend": "godot_native",
		"issues": ["Unsupported package manager operation: %s" % operation],
	}


# --- 私有/辅助方法 ---

func _read_package_ids(request: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var raw_ids: Variant = request.get("package_ids", PackedStringArray())
	if raw_ids is PackedStringArray:
		ids = raw_ids
	elif raw_ids is Array:
		var values: Array = raw_ids
		for value: Variant in values:
			var text_value: String = _GF_VARIANT_ACCESS.to_text(value)
			if not text_value.is_empty():
				var _append_result: bool = ids.append(text_value)
	return ids


func _make_cancelled_result(operation: String) -> Dictionary:
	return {
		"ok": false,
		"operation": operation,
		"backend": "godot_native",
		"cancelled": true,
		"issues": ["Package manager operation was cancelled."],
	}
