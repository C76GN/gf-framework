@tool

# 工作区任务与资源动作宿主；仅通过已声明的页面路由，不依赖具体工具。
extends RefCounted


# --- 常量 ---

## 有限路由命令。
## [br]
## @api private
const _ROUTE_COMMAND_SCRIPT = preload("res://addons/gf/kernel/editor/workspace/gf_workspace_route_command.gd")

## 纯数据扩展贡献读取器。
## [br]
## @api private
const _JSON_READER_SCRIPT = preload("res://addons/gf/kernel/editor/gf_bounded_json_reader.gd")

## 扩展贡献协议。
## [br]
## @api private
const _CONTRIBUTION_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_tool_contribution.gd")


# --- 私有变量 ---

## 复用动作注册表；不另建命令执行协议。
## [br]
## @api private
var _registry: GFEditorCommandRegistry = GFEditorCommandRegistry.new()

## 按稳定来源索引的纯数据记录。
## [br]
## @api private
var _records: Dictionary = {}

## 任务来源顺序。
## [br]
## @api private
var _tasks: Array[String] = []

## 资源动作来源顺序。
## [br]
## @api private
var _resource_actions: Array[String] = []

## 当前可打开页面路径集合。
## [br]
## @api private
var _pages: Dictionary = {}

## 负责窗口和页面生命周期的对象弱引用。
## [br]
## @api private
var _navigator: WeakRef = null

## 每次重配或撤销递增，使旧命令无法调用新工具。
## [br]
## @api private
var _generation: int = 0

## 本次同步路由的接收方结果，用于保留失败原因。
## [br]
## @api private
var _last_report: Dictionary = {}


# --- 框架内部方法 ---

## 注入经过贡献读取器校验的数据和本代导航对象。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func configure(
	tasks: Array[Dictionary], actions: Array[Dictionary], pages: Array[Dictionary], navigator: Object
) -> void:
	clear()
	_navigator = weakref(navigator)
	for page: Dictionary in pages:
		_pages[str(page.get("path", ""))] = true
	_register_records(tasks, false)
	_register_records(actions, true)


## 撤销所有动作及导航引用。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func clear() -> void:
	_generation += 1
	_registry.clear()
	_records.clear()
	_tasks.clear()
	_resource_actions.clear()
	_pages.clear()
	_navigator = null


## 查询任务快照，不调用工厂或创建工具页面。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func get_workspace_tasks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_id: String in _tasks:
		var record: Dictionary = _get_record(source_id).duplicate(true)
		record["available"] = _page_available(record)
		record["reason"] = "" if record["available"] else "请在扩展页面启用此工具，或检查贡献状态。"
		result.append(record)
	return result


## 显式请求任务；未启用扩展只打开扩展选择页。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func request_workspace_task(source_id: String) -> Dictionary:
	if not _tasks.has(source_id):
		return _failure("任务不存在或已撤销。")
	var record: Dictionary = _get_record(source_id)
	if not _page_available(record):
		var page: Control = _open_page("res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd")
		return {"ok": page != null, "status": "selection_required", "message": "请显式选择需要启用的扩展。"}
	return _invoke_registered(source_id)


## 查询资源选择的适用动作，不加载资源内容。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func get_resource_actions(paths: PackedStringArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_id: String in _resource_actions:
		var record: Dictionary = _get_record(source_id)
		var reason: String = _resource_reason(record, paths)
		result.append({
			"action_id": source_id, "title": str(record.get("title", "")),
			"available": reason.is_empty(), "reason": reason,
		})
	return result


## 在执行时重新核对资源类型与页面可用性，再调用注册动作。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func request_resource_action(action_id: String, paths: PackedStringArray) -> Dictionary:
	if not _resource_actions.has(action_id):
		return _failure("资源动作不存在或已撤销。")
	var reason: String = _resource_reason(_get_record(action_id), paths)
	if not reason.is_empty():
		return _failure(reason)
	return _invoke_registered(action_id, {"paths": paths.duplicate()})


## 执行同代路由命令，仅调用固定的工具接收协议。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func invoke_workspace_record(source_id: String, paths: PackedStringArray, generation: int) -> Error:
	if generation != _generation or not _records.has(source_id):
		return ERR_UNAVAILABLE
	var record: Dictionary = _get_record(source_id)
	if not _page_available(record):
		return ERR_UNAVAILABLE
	if _resource_actions.has(source_id) and not _resource_reason(record, paths).is_empty():
		return ERR_INVALID_PARAMETER
	var page: Control = _open_page(str(record.get("page_path", "")))
	if generation != _generation or not is_instance_valid(page):
		return ERR_UNAVAILABLE
	var action_id: String = str(record.get("action_id", ""))
	if action_id.is_empty():
		return OK
	var response: Variant = null
	if _resource_actions.has(source_id):
		if not page.has_method("receive_workspace_resources"):
			return ERR_METHOD_NOT_FOUND
		response = page.call("receive_workspace_resources", action_id, paths.duplicate())
	else:
		if not page.has_method("run_workspace_task"):
			return ERR_METHOD_NOT_FOUND
		response = page.call("run_workspace_task", action_id)
	if response is Dictionary:
		var report: Dictionary = response
		_last_report = report.duplicate(true)
		return OK if report.get("ok", false) == true else FAILED
	return ERR_INVALID_DATA


## 读取已发现扩展的任务描述；包括禁用扩展，但不会实例化其脚本。
## 每个文件最多 1 MiB、累计最多 4 MiB、每类最多 1024 条。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
static func collect_extension_records(manifests: Array[GFExtensionManifest]) -> Dictionary:
	var result: Dictionary = {"task_records": [], "resource_action_records": []}
	var consumed_bytes: int = 0
	for manifest: GFExtensionManifest in manifests:
		var path: String = manifest.root_path.path_join("editor/gf_tool_contribution.json")
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		consumed_bytes += file.get_length()
		file.close()
		if consumed_bytes > 4_194_304:
			break
		var read: Dictionary = _JSON_READER_SCRIPT.read_object(path, 1_048_576, 64)
		if read.get("ok", false) != true:
			continue
		var raw: Dictionary = read.get("data", {})
		var parsed: Dictionary = _CONTRIBUTION_SCRIPT.parse_dictionary(raw, manifest.id)
		if parsed.get("ok", false) != true:
			continue
		var data: Dictionary = parsed.get("data", {})
		for family: String in ["task_records", "resource_action_records"]:
			var target: Array = result[family]
			var incoming: Array = data.get(family, [])
			for record: Dictionary in incoming:
				var page_path: String = str(record.get("page_path", ""))
				if not page_path.begins_with("res://"):
					page_path = manifest.root_path.path_join(page_path).simplify_path()
				if page_path != page_path.simplify_path() or not page_path.begins_with(manifest.root_path.trim_suffix("/") + "/"):
					continue
				if target.size() < 1024:
					var normalized: Dictionary = record.duplicate(true)
					normalized["page_path"] = page_path
					target.append(normalized)
	return result


# --- 私有/辅助方法 ---

## 为纯数据记录建立现有动作定义；工厂只捕获弱引用和代次。
## [br]
## @api private
func _register_records(records: Array[Dictionary], resource_actions: bool) -> void:
	for record: Dictionary in records:
		var source_id: String = str(record.get("source_id", ""))
		if source_id.is_empty() or _records.has(source_id):
			continue
		var action: GFEditorActionDefinition = GFEditorActionDefinition.new()
		action.action_id = StringName(source_id)
		action.source_id = StringName(source_id)
		action.label = str(record.get("title", ""))
		action.tooltip = str(record.get("description", ""))
		action.group = StringName(str(record.get("group", "")))
		action.enabled = _page_available(record)
		action.command_factory = _make_route_command.bind(weakref(self), _generation, source_id)
		var registered: Dictionary = _registry.register_action(action)
		if registered.get("ok", false) != true:
			continue
		_records[source_id] = record.duplicate(true)
		if resource_actions:
			_resource_actions.append(source_id)
		else:
			_tasks.append(source_id)


## 构建尚未执行的路由命令。
## [br]
## @api private
static func _make_route_command(context: Dictionary, host_ref: WeakRef, generation: int, source_id: String) -> GFEditorCommand:
	var value: Variant = host_ref.get_ref()
	if not value is Object or not is_instance_valid(value):
		return null
	var host: Object = value
	var paths_value: Variant = context.get("paths", PackedStringArray())
	var paths: PackedStringArray = paths_value if paths_value is PackedStringArray else PackedStringArray()
	var command: _ROUTE_COMMAND_SCRIPT = _ROUTE_COMMAND_SCRIPT.new()
	command.configure(host, generation, source_id, paths)
	return command


## 取内部记录；调用者对外返回前复制。
## [br]
## @api private
func _get_record(source_id: String) -> Dictionary:
	var record: Dictionary = _records.get(source_id, {})
	return record


## 保留接收工具的可读原因，同时由注册表决定动作是否成功。
## [br]
## @api private
func _invoke_registered(source_id: String, context: Dictionary = {}) -> Dictionary:
	_last_report = {}
	var report: Dictionary = _registry.invoke_action(StringName(source_id), context)
	if _last_report.has("message"):
		report["message"] = str(_last_report["message"])
	return report


## 只检查当前贡献页面集合。
## [br]
## @api private
func _page_available(record: Dictionary) -> bool:
	if not _pages.has(str(record.get("page_path", ""))) or _navigator == null:
		return false
	var navigator: Variant = _navigator.get_ref()
	return navigator is Object and is_instance_valid(navigator)


## 使用原生资源类型信息校验选择；不会 load 项目脚本。
## [br]
## @api private
func _resource_reason(record: Dictionary, paths: PackedStringArray) -> String:
	if not _page_available(record):
		return "接收工具当前不可用。"
	var maximum: int = record.get("max_selection", 1)
	if paths.is_empty() or paths.size() > maximum:
		return "请选择 1 至 %d 个资源。" % maximum
	var types: Array = record.get("resource_types", [])
	for path: String in paths:
		if not path.begins_with("res://") or path != path.simplify_path() or path.contains("::"):
			return "仅支持项目中的独立资源文件。"
		var type_name: String = ""
		if Engine.is_editor_hint():
			var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
			if filesystem != null:
				type_name = filesystem.get_file_type(path)
		var accepted: bool = false
		for accepted_type: String in types:
			if type_name == accepted_type or ClassDB.is_parent_class(type_name, accepted_type):
				accepted = true
				break
		if not accepted:
			return "所选资源类型不适用于此动作。"
	return ""


## 通过弱引用导航并确认返回实际页面。
## [br]
## @api private
func _open_page(path: String) -> Control:
	var value: Variant = _navigator.get_ref() if _navigator != null else null
	if not value is Object or not is_instance_valid(value):
		return null
	var navigator: Object = value
	if not navigator.has_method("open_workspace_page"):
		return null
	var page: Variant = navigator.call("open_workspace_page", path)
	if page is Control:
		var control: Control = page
		return control
	return null


## 返回可向用户呈现的失败原因。
## [br]
## @api private
func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message, "error_code": ERR_UNAVAILABLE}
