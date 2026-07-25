# Compiles transient GDScript source and dismantles inner-script reference cycles afterwards.
extends RefCounted


# --- 框架内部方法 ---

static func compile_and_release(source: String) -> Dictionary:
	var runtime_script: GDScript = GDScript.new()
	if (
		not runtime_script.resource_path.is_empty()
		or not runtime_script.is_built_in()
		or not runtime_script.get_global_name().is_empty()
	):
		return {
			"ok": false,
			"compile_error": ERR_INVALID_DATA,
			"cleanup_errors": [],
			"configuration_error": "transient_script_root_is_not_anonymous",
		}
	runtime_script.source_code = source
	var compile_error: Error = runtime_script.reload(false)
	var cleanup_errors: Array[int] = []
	var configuration_error: String = (
		""
		if runtime_script.get_global_name().is_empty()
		else "transient_script_root_declares_global_name"
	)
	cleanup_errors = release(runtime_script)
	return {
		"ok": (
			compile_error == OK
			and cleanup_errors.is_empty()
			and configuration_error.is_empty()
		),
		"compile_error": compile_error,
		"cleanup_errors": cleanup_errors,
		"configuration_error": configuration_error,
	}


static func release(runtime_script: GDScript) -> Array[int]:
	var cleanup_errors: Array[int] = []
	if runtime_script == null:
		cleanup_errors.append(ERR_INVALID_PARAMETER)
		return cleanup_errors
	_release_script_graph(
		runtime_script,
		runtime_script.resource_path,
		{},
		cleanup_errors
	)
	return cleanup_errors


# --- 私有/辅助方法 ---

static func _release_script_graph(
	runtime_script: GDScript,
	root_resource_path: String,
	visited: Dictionary,
	cleanup_errors: Array[int]
) -> void:
	var instance_id: int = runtime_script.get_instance_id()
	if visited.has(instance_id):
		return
	visited[instance_id] = true

	for constant_value: Variant in runtime_script.get_script_constant_map().values():
		if not constant_value is GDScript:
			continue
		var inner_script: GDScript = constant_value
		if (
			inner_script.resource_path != root_resource_path
			or not inner_script.is_built_in()
			or not inner_script.get_global_name().is_empty()
		):
			continue
		_release_script_graph(inner_script, root_resource_path, visited, cleanup_errors)

	runtime_script.source_code = "extends RefCounted\n"
	var cleanup_error: Error = runtime_script.reload(false)
	if cleanup_error != OK:
		cleanup_errors.append(cleanup_error)
