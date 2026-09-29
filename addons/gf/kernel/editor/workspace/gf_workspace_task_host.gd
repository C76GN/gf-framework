@tool

# 工作区任务与资源动作宿主；仅通过已声明的页面路由，不依赖具体工具。
extends RefCounted


# --- 常量 ---

## 有限路由命令。
## [br]
## @api private
const _ROUTE_COMMAND_SCRIPT = preload("res://addons/gf/kernel/editor/workspace/gf_workspace_route_command.gd")

## 纯数据扩展贡献读取器；保留实际 size_bytes，以同份已读取数据核算总预算。
## [br]
## @api private
const _JSON_READER_SCRIPT = preload("res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd")

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

## 当前同步调用帧的接收方结果；嵌套调用保存并恢复外层槽位，防止内层结果泄漏。
## [br]
## @api private
var _last_report: Dictionary = {}


# --- 框架内部方法 ---

## 注入经过贡献读取器校验的数据和本代导航对象。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param tasks: 已校验的任务记录，注册时深复制。
## [br]
## @param actions: 已校验的资源动作记录，注册时深复制。
## [br]
## @param pages: 当前启用且可导航的页面记录。
## [br]
## @param navigator: 提供 open_workspace_page 的导航对象，仅保留弱引用。
## [br]
## @schema tasks: Array[Dictionary]；每项包含 owner_package_id、全局 source_id、title、description、keywords、group、page_path、action_id。
## [br]
## @schema actions: Array[Dictionary]；任务记录字段加 resource_types: Array[String]、max_selection: int；action_id 非空。
## [br]
## @schema pages: Array[Dictionary]；使用各项 path: String 建立当前可用页面集合，其他页面字段由导航宿主管理。
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
	_last_report = {}


## 查询任务快照，不调用工厂或创建工具页面。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return: 按注册顺序返回任务记录的深复制快照。
## [br]
## @schema return: Array[Dictionary]；保留配置时的任务字段，并添加 available: bool 和 reason: String。
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
## [br]
## @param source_id: 查询快照中的全局任务来源标识。
## [br]
## @return: 注册动作的执行报告；不可用页面返回扩展选择页导航结果，已撤销任务返回失败。
## [br]
## @schema return: Dictionary；包含 ok: bool 和 message: String，可含 error_code、status、action_id、replaced、metadata。同代接收报告保存在 receiver_report，原注册表状态为 registry_status；文本 status 和 message/reason/status 原因可提升，执行字段仍由注册表决定。扩展选择导航的 status 为 selection_required。
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
## [br]
## @param paths: 当前选择的完整项目资源路径，仅通过原生文件系统类型信息检查。
## [br]
## @return: 按注册顺序返回动作可用性快照，查询不创建页面。
## [br]
## @schema return: Array[Dictionary]；每项包含 action_id: String（全局来源 ID）、title: String、available: bool、reason: String。
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
## [br]
## @param action_id: 查询快照中的全局资源动作来源标识。
## [br]
## @param paths: 当前选择的独立 res:// 资源文件路径，须满足动作类型与数量限制。
## [br]
## @return: 注册动作执行报告或可向用户呈现的校验失败结果。
## [br]
## @schema return: Dictionary；包含 ok: bool 和 message: String，可含 error_code、status、action_id、replaced、metadata。同代接收报告深复制为 receiver_report，原注册表状态为 registry_status；文本 status 和 message/reason/status 原因可提升，ok、error_code、action_id、replaced、metadata 仍由注册表决定。过期或非法路由不附带接收报告。
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
## [br]
## @param source_id: 已注册的全局任务或资源动作来源标识。
## [br]
## @param paths: 资源动作的选择路径副本；普通任务使用空数组。
## [br]
## @param generation: 命令创建时捕获的宿主代次，必须与当前代次相同。
## [br]
## @return: 成功为 OK；过期或页面失效为 ERR_UNAVAILABLE，资源不适用为 ERR_INVALID_PARAMETER，缺少接收方法为 ERR_METHOD_NOT_FOUND，响应非法为 ERR_INVALID_DATA，接收方拒绝为 FAILED。
func invoke_workspace_record(source_id: String, paths: PackedStringArray, generation: int) -> Error:
	if generation != _generation or not _records.has(source_id):
		return ERR_UNAVAILABLE
	var record: Dictionary = _get_record(source_id)
	if not _page_available(record):
		return ERR_UNAVAILABLE
	if _resource_actions.has(source_id) and not _resource_reason(record, paths).is_empty():
		return ERR_INVALID_PARAMETER
	var page: Control = _open_page(str(record.get("page_path", "")))
	if generation != _generation or not _is_live_page(page):
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
	if generation != _generation or not _is_live_page(page):
		return ERR_UNAVAILABLE
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
## [br]
## @param manifests: 已发现扩展的 manifest，可包括禁用扩展；按输入顺序在预算内读取贡献文件。
## [br]
## @return: 通过协议与所属扩展路径边界校验的任务和资源动作记录；无效文件被跳过。
## [br]
## @schema return: Dictionary；task_records 和 resource_action_records 均为 Array[Dictionary]，保持规范化贡献字段并将 page_path 解析为所属扩展内的完整 res:// 路径。
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
		var declared_bytes: int = file.get_length()
		file.close()
		if declared_bytes > 1_048_576:
			continue
		var remaining_bytes: int = 4_194_304 - consumed_bytes
		if remaining_bytes <= 0 or declared_bytes > remaining_bytes:
			break
		# 预检与实际读取之间文件可能变化；剩余预算必须由 reader 同份 bytes 校验并计费。
		var read: Dictionary = _JSON_READER_SCRIPT.read_object(path, mini(1_048_576, remaining_bytes), 64)
		var observed_bytes: int = read.get("size_bytes", 0)
		consumed_bytes += clampi(observed_bytes, 0, remaining_bytes)
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


## 隔离同步嵌套调用的报告；同代接收方只补充状态与原因，不覆盖注册表的执行结果和 metadata。
## [br]
## @api private
func _invoke_registered(source_id: String, context: Dictionary = {}) -> Dictionary:
	var previous_report: Dictionary = _last_report
	var generation: int = _generation
	_last_report = {}
	var report: Dictionary = _registry.invoke_action(StringName(source_id), context)
	var receiver_report: Dictionary = _last_report
	_last_report = previous_report
	if generation != _generation or receiver_report.is_empty():
		return report
	var receiver_error: Error = OK if receiver_report.get("ok", false) == true else FAILED
	if report.get("error_code") != receiver_error:
		return report
	report["registry_status"] = report.get("status")
	report["receiver_report"] = receiver_report.duplicate(true)
	var receiver_status: String = _receiver_text(receiver_report, "status")
	if not receiver_status.is_empty():
		report["status"] = receiver_status
	for field: String in ["message", "reason", "status"]:
		var message: String = _receiver_text(receiver_report, field)
		if not message.is_empty():
			report["message"] = message
			break
	return report


## 只提升文本状态或原因；其他接收方值保留在原始报告中，不隐式执行对象字符串转换。
## [br]
## @api private
func _receiver_text(report: Dictionary, field: String) -> String:
	var value: Variant = report.get(field)
	return str(value) if value is String or value is StringName else ""


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
		var type_name: String = _get_native_resource_type(_get_file_type(path))
		var accepted: bool = false
		for accepted_type: String in types:
			if type_name == accepted_type or ClassDB.is_parent_class(type_name, accepted_type):
				accepted = true
				break
		if not accepted:
			return "所选资源类型不适用于此动作。"
	return ""


## 只读取编辑器已有文件系统索引；类型查询不能加载所选资源或执行项目脚本。
## [br]
## @api private
func _get_file_type(path: String) -> String:
	if Engine.is_editor_hint():
		var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
		if filesystem != null:
			return filesystem.get_file_type(path)
	return ""


## 沿全局脚本类的缓存 base 链解析原生 Resource 类型；未知、循环与非资源类型均拒绝。
## [br]
## @api private
func _get_native_resource_type(type_name: String) -> String:
	var seen: Dictionary = {}
	var global_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	while not type_name.is_empty() and not seen.has(type_name):
		if ClassDB.class_exists(type_name):
			return type_name if type_name == "Resource" or ClassDB.is_parent_class(type_name, "Resource") else ""
		seen[type_name] = true
		var base_type: String = ""
		for global_class: Dictionary in global_classes:
			if str(global_class.get("class", "")) == type_name:
				base_type = str(global_class.get("base", "")).strip_edges()
				break
		type_name = base_type
	return ""


## 接收入口与回调返回都必须仍是活动页面；queue_free 在实际释放前也已撤销执行资格。
## [br]
## @api private
func _is_live_page(page: Control) -> bool:
	return is_instance_valid(page) and not page.is_queued_for_deletion() and page.is_inside_tree()


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
