@tool

# 最小项目创建协调器。文件事务与 ProjectSettings 保存分步执行；只补偿仍由本次拥有的文件。
extends RefCounted


# --- 常量 ---

const _TEMPLATES_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_templates.gd")
const _AUTOLOAD_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_autoload.gd")
const _INSTALLERS: String = "gf/project/installers"
const _MAIN_SCENE: String = "application/run/main_scene"
const _AUTOLOAD: String = "autoload/Gf"
const _DEFAULT_DIRECTORY: String = "res://game/bootstrap"
const _DEFAULT_PREFIX: String = "GameDemo"


# --- 私有变量 ---

static var _busy: bool = false
static var _test_save_error: Error = OK
static var _pending_classes: Dictionary[String, String] = {}
static var _pending_filesystem: WeakRef = null


# --- 框架内部方法 ---

## 只读预检创建路径、类型名和待追加的项目设置。
## [br]
## @api framework_internal
## [br]
## @param directory: 项目源码输出目录，禁止覆盖框架或编辑器缓存。
## [br]
## @param class_prefix: 生成的三个全局类型的前缀。
## [br]
## @param set_main_scene: 是否显式把样例设为主场景。
## [br]
## @return 创建预览；不会写文件或保存设置。
## [br]
## @schema return: Dictionary，包含 ok、issues:Array[String]、directory、class_prefix、set_main_scene、paths:PackedStringArray、classes:Array[String]、installer_path、scene_path、entries:Array[Dictionary]、settings_before:Dictionary、settings_after:Dictionary、project_sha256 和 signature。entries 符合 GFArtifactWriteTransaction 文本 entry；settings_before 的值包含 exists 和 value，其中 autoload/Gf 仅作为只读前提参与签名与提交前校验，不加入 settings_after 或设置补偿。
static func get_plan(directory: String = _DEFAULT_DIRECTORY, class_prefix: String = _DEFAULT_PREFIX, set_main_scene: bool = false) -> Dictionary:
	var issues: Array[String] = []
	var path: String = directory.strip_edges().trim_suffix("/")
	var prefix: String = class_prefix.strip_edges()
	var plan: Dictionary = {
		"ok": false, "issues": issues, "directory": path, "class_prefix": prefix,
		"set_main_scene": set_main_scene, "paths": PackedStringArray(), "classes": [],
		"installer_path": path.path_join("game_installer.gd"), "scene_path": path.path_join("bootstrap.tscn"),
		"entries": [], "settings_before": {}, "settings_after": {},
		"project_sha256": "", "signature": "",
	}
	if not _valid_directory(path):
		issues.append("输出目录须为 res:// 下的项目目录，不能包含父路径、引号、反斜杠或指向 addons/.godot。")
	if not _valid_prefix(prefix):
		issues.append("类名前缀须以英文字母开头，只含字母、数字、下划线，最多 48 个字符。")
	if not issues.is_empty():
		return plan
	var classes: Array[String] = [prefix + "CounterModel", prefix + "CounterSystem", prefix + "Installer"]
	plan["classes"] = classes
	_settle_pending_classes()
	for type_name: String in classes:
		if _pending_classes.has(type_name):
			issues.append("刚创建的类型尚可能正在导入：" + type_name)
		if ClassDB.class_exists(type_name):
			issues.append("类型名称已存在：" + type_name)
		for record: Dictionary in ProjectSettings.get_global_class_list():
			if record.get("class") == type_name:
				issues.append("项目已注册类型：" + type_name)
	var settings_before: Dictionary = {_INSTALLERS: _setting_snapshot(_INSTALLERS), _AUTOLOAD: _setting_snapshot(_AUTOLOAD)}
	var raw_installers: Variant = ProjectSettings.get_setting(_INSTALLERS, [])
	var installers: Variant = _copy_installers(raw_installers)
	if installers == null:
		issues.append("gf/project/installers 不是有效的路径数组；请先修复项目设置。")
		return plan
	var installer_path: String = plan["installer_path"]
	if installers is PackedStringArray:
		var packed_paths: PackedStringArray = installers
		if packed_paths.has(installer_path):
			issues.append("该 Installer 路径已登记，请选择新的输出目录。")
		var _appended: bool = packed_paths.append(installer_path)
		installers = packed_paths
	else:
		var array_paths: Array = installers
		if array_paths.has(installer_path):
			issues.append("该 Installer 路径已登记，请选择新的输出目录。")
		array_paths.append(installer_path)
	var settings_after: Dictionary = {_INSTALLERS: installers}
	if set_main_scene:
		settings_before[_MAIN_SCENE] = _setting_snapshot(_MAIN_SCENE)
		settings_after[_MAIN_SCENE] = plan["scene_path"]
	plan["settings_before"] = settings_before
	plan["settings_after"] = settings_after
	var contents: Dictionary = _TEMPLATES_SCRIPT.render(path, prefix)
	var entries: Array[Dictionary] = []
	var paths: PackedStringArray = PackedStringArray()
	for file_name: String in contents:
		var target: String = path.path_join(file_name)
		var content: String = contents[file_name]
		var _appended: bool = paths.append(target)
		if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
			issues.append("目标已存在，不会覆盖：" + target)
		entries.append(GFArtifactWriteTransaction.make_text_entry(target, content))
	plan["entries"] = entries
	plan["paths"] = paths
	var preflight: Dictionary = GFArtifactWriteTransaction.get_preflight_report(entries, _options(path))
	if preflight.get("ok") != true:
		_append_issues(issues, preflight.get("issues", []))
	var project_hash: String = FileAccess.get_sha256("res://project.godot")
	if project_hash.is_empty():
		issues.append("无法读取 project.godot 的当前内容。")
	if not _AUTOLOAD_SCRIPT.is_registered_singleton():
		issues.append("请先启用指向 GF 核心脚本的 Gf AutoLoad 单例；同名冲突或未启用的配置不会被自动修改。")
	plan["project_sha256"] = project_hash
	plan["ok"] = issues.is_empty()
	plan["signature"] = var_to_str([path, prefix, set_main_scene, settings_before, project_hash, classes]).sha256_text()
	return plan


## 创建项目文件并追加 Installer；设置保存失败时只移除内容身份仍匹配的本次新文件。
## [br]
## @api framework_internal
## [br]
## @param directory: 项目源码输出目录。
## [br]
## @param class_prefix: 类型名称前缀。
## [br]
## @param set_main_scene: 是否显式替换主场景。
## [br]
## @param expected_signature: 可选的预览签名；非空时拒绝过期预览。
## [br]
## @return 操作报告，失败时保留明确的剩余文件与恢复信息。
## [br]
## @schema return: Dictionary，包含 ok、status、issues:Array[String]、paths:PackedStringArray、scene_path、installer_path、settings_saved、files_created、rolled_back、recovery_required、transactions:Array[Dictionary]；transactions 保存 GFArtifactWriteTransaction 的提交/终态报告，必要时含原样 recovery_transaction。
static func create(directory: String = _DEFAULT_DIRECTORY, class_prefix: String = _DEFAULT_PREFIX, set_main_scene: bool = false, expected_signature: String = "") -> Dictionary:
	var report: Dictionary = _report()
	var issues: Array[String] = report["issues"]
	if _busy or not Thread.is_main_thread():
		issues.append("项目创建正在执行，或调用不在主线程。")
		return report
	_busy = true
	var plan: Dictionary = get_plan(directory, class_prefix, set_main_scene)
	if plan.get("ok") != true or (not expected_signature.is_empty() and plan["signature"] != expected_signature):
		_append_issues(issues, plan["issues"])
		if plan.get("ok") == true:
			issues.append("项目设置或文件已变化，请重新预览创建计划。")
		_busy = false
		return report
	report["paths"] = plan["paths"]
	report["scene_path"] = plan["scene_path"]
	report["installer_path"] = plan["installer_path"]
	var output_directory: String = plan["directory"]
	var output_paths: PackedStringArray = plan["paths"]
	var before: Dictionary = plan["settings_before"]
	var options: Dictionary = _options(output_directory)
	var transaction: Dictionary = GFArtifactWriteTransaction.begin(output_paths, options)
	if transaction.get("ok") != true:
		_record_transaction(report, transaction)
		_busy = false
		return report
	var entries: Array[Dictionary] = []
	var entry_values: Array = plan["entries"]
	entries.assign(entry_values)
	var written: Dictionary = GFArtifactWriteTransaction.commit(entries, options)
	_record_transaction(report, written)
	if written.get("ok") != true:
		report["files_created"] = written.get("written_count", 0) > 0 or written.get("recovery_required") == true
		_record_transaction(report, GFArtifactWriteTransaction.complete(transaction))
		report["status"] = "file_commit_failed"
		_busy = false
		return report
	report["files_created"] = true
	var class_names: Array[String] = plan["classes"]
	var class_files: Array[String] = ["counter_model.gd", "counter_system.gd", "game_installer.gd"]
	for index: int in range(class_names.size()):
		_pending_classes[class_names[index]] = output_directory.path_join(class_files[index])
	_observe_pending_class_registration()
	if not _settings_match(before) or FileAccess.get_sha256("res://project.godot") != plan["project_sha256"]:
		issues.append("创建文件期间项目设置发生变化；未保存设置。")
		_compensate_files(plan, transaction, report)
		_busy = false
		return report
	var after: Dictionary = plan["settings_after"]
	for key: String in after:
		ProjectSettings.set_setting(key, after[key])
	var save_error: Error = _test_save_error
	_test_save_error = OK
	if save_error == OK:
		save_error = ProjectSettings.save()
	if save_error != OK:
		issues.append("项目设置保存失败：" + error_string(save_error))
		var restored: bool = _restore_settings(before, after)
		if restored and FileAccess.get_sha256("res://project.godot") == plan["project_sha256"]:
			_compensate_files(plan, transaction, report)
		else:
			issues.append("设置内容或所有权已变化，保留新文件，请检查 project.godot 与 Installer 列表。")
			_retain_files(transaction, report)
		_busy = false
		return report
	report["settings_saved"] = true
	if not _settings_equal(after) or not _saved_settings_equal(after):
		issues.append("保存期间项目设置被其他操作改变；保留已创建文件，请检查 Installer 和主场景。")
		_retain_files(transaction, report)
		_busy = false
		return report
	var completed: Dictionary = GFArtifactWriteTransaction.complete(transaction)
	_record_transaction(report, completed)
	if completed.get("ok") != true:
		report["recovery_required"] = true
	report["ok"] = not report["recovery_required"]
	report["status"] = "created" if report["ok"] else "recovery_required"
	_busy = false
	return report


## 为独立验收注入一次设置保存失败；不写入项目设置。
## [br]
## @api framework_internal
## [br]
## @param error: 下次进入设置保存步骤时返回的 Error，随后自动恢复 OK。
static func configure_test_save_error(error: Error) -> void:
	_test_save_error = error


# --- 私有/辅助方法 ---

## 真实类注册表接管同名同路径后撤销临时占名；文件删除也立即释放。
## 在导入完成信号中执行，不要求用户再次打开预览，不加载或实例化项目脚本。
## [br]
## @api private
static func _settle_pending_classes(indexed_changes: bool = false) -> void:
	var registered: Dictionary[String, String] = {}
	for record: Dictionary in ProjectSettings.get_global_class_list():
		var registered_name: String = record["class"]
		var registered_path: String = record["path"]
		registered[registered_name] = registered_path
	for type_name: String in _pending_classes.keys():
		var path: String = _pending_classes[type_name]
		if not FileAccess.file_exists(path) or registered.get(type_name, "") == path or (indexed_changes and _has_indexed_class_change(path, type_name)):
			var _removed: bool = _pending_classes.erase(type_name)
	if _pending_classes.is_empty():
		_stop_pending_class_observer()


## 类索引完成更新后，已收录的脚本也可能在首次导入前改名或删除声明。
## 只读取编辑器的脚本类型元数据；尚未收录的路径仍保留导入前占名。
## [br]
## @api private
static func _has_indexed_class_change(path: String, type_name: String) -> bool:
	if _pending_filesystem == null:
		return false
	var value: Variant = _pending_filesystem.get_ref()
	if not value is EditorFileSystem:
		return false
	var filesystem: EditorFileSystem = value
	var directory: EditorFileSystemDirectory = filesystem.get_filesystem_path(path.get_base_dir())
	if directory == null:
		return false
	var index: int = directory.find_file_index(path.get_file())
	return index >= 0 and directory.get_file_type(index) == &"GDScript" and directory.get_file_script_class_name(index) != type_name


## 专用信号确认类索引已经更新，普通预览调用不能借未刷新的空 metadata 提前释放占名。
## [br]
## @api private
static func _on_pending_script_classes_updated() -> void:
	_settle_pending_classes(true)


## 只在有待导入类型时监听编辑器真实的全局类列表更新；运行期不访问 EditorInterface。
## [br]
## @api private
static func _observe_pending_class_registration() -> void:
	_settle_pending_classes()
	if _pending_classes.is_empty() or not Engine.is_editor_hint():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return
	if not filesystem.script_classes_updated.is_connected(_on_pending_script_classes_updated):
		var _connected: Error = filesystem.script_classes_updated.connect(_on_pending_script_classes_updated) as Error
	_pending_filesystem = weakref(filesystem)


## 所有临时占名已交还注册表或回滚后，停止监听，不延长编辑器节点的生命期。
## [br]
## @api private
static func _stop_pending_class_observer() -> void:
	if _pending_filesystem == null:
		return
	var value: Variant = _pending_filesystem.get_ref()
	_pending_filesystem = null
	if value is EditorFileSystem:
		var filesystem: EditorFileSystem = value
		if filesystem.script_classes_updated.is_connected(_on_pending_script_classes_updated):
			filesystem.script_classes_updated.disconnect(_on_pending_script_classes_updated)


static func _valid_directory(path: String) -> bool:
	if not path.begins_with("res://") or path.length() > 180:
		return false
	var relative: String = path.trim_prefix("res://")
	if relative.is_empty() or relative.split("/")[0].to_lower() in ["addons", ".godot"]:
		return false
	for part: String in relative.split("/"):
		if part.is_empty() or part in [".", ".."] or not part.is_valid_filename():
			return false
		for character: String in part:
			if character.unicode_at(0) < 32 or character in ["\"", "\\", ":"]:
				return false
	return true


static func _valid_prefix(prefix: String) -> bool:
	if prefix.is_empty() or prefix.length() > 48:
		return false
	for index: int in range(prefix.length()):
		var code: int = prefix.unicode_at(index)
		var letter: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if not letter and (index == 0 or not ((code >= 48 and code <= 57) or code == 95)):
			return false
	return true


static func _copy_installers(raw: Variant) -> Variant:
	if raw is PackedStringArray:
		var packed_paths: PackedStringArray = raw
		return packed_paths.duplicate()
	if raw is Array:
		var array_paths: Array = raw
		for value: Variant in array_paths:
			if not value is String and not value is StringName:
				return null
		return array_paths.duplicate()
	return null


static func _setting_snapshot(key: String) -> Dictionary:
	var value: Variant = ProjectSettings.get_setting(key, null)
	if value is Array:
		var array_value: Array = value
		value = array_value.duplicate(true)
	elif value is Dictionary:
		var dictionary_value: Dictionary = value
		value = dictionary_value.duplicate(true)
	return {"exists": ProjectSettings.has_setting(key), "value": value}


static func _settings_match(before: Dictionary) -> bool:
	for key: String in before:
		if _setting_snapshot(key) != before[key]:
			return false
	return true


static func _settings_equal(values: Dictionary) -> bool:
	for key: String in values:
		if not ProjectSettings.has_setting(key) or ProjectSettings.get_setting(key) != values[key]:
			return false
	return true


static func _saved_settings_equal(values: Dictionary) -> bool:
	var settings_file: ConfigFile = ConfigFile.new()
	var project_path: String = ProjectSettings.globalize_path("res://project.godot")
	if settings_file.load(project_path) != OK:
		return false
	for key: String in values:
		var separator: int = key.find("/")
		if settings_file.get_value(key.left(separator), key.substr(separator + 1), null) != values[key]:
			return false
	return true


static func _restore_settings(before: Dictionary, after: Dictionary) -> bool:
	if not _settings_equal(after):
		return false
	for key: String in after:
		var snapshot: Dictionary = before[key]
		ProjectSettings.set_setting(key, snapshot["value"] if snapshot["exists"] else null)
	return _settings_match(before)


static func _options(directory: String) -> Dictionary:
	return {"allowed_roots": PackedStringArray([directory]), "overwrite_existing": false, "max_file_count": 6, "max_file_bytes": 65536, "max_total_bytes": 262144, "scan_filesystem": false}


static func _report() -> Dictionary:
	var issues: Array[String] = []
	var transactions: Array[Dictionary] = []
	return {"ok": false, "status": "preflight_failed", "issues": issues, "paths": PackedStringArray(), "scene_path": "", "installer_path": "", "settings_saved": false, "files_created": false, "rolled_back": false, "recovery_required": false, "transactions": transactions}


static func _append_issues(issues: Array[String], values: Variant) -> void:
	if values is Array or values is PackedStringArray:
		for value: Variant in values:
			if value is String:
				issues.append(value)


static func _record_transaction(report: Dictionary, transaction: Dictionary) -> void:
	var transactions: Array[Dictionary] = report["transactions"]
	transactions.append(transaction)
	var issues: Array[String] = report["issues"]
	_append_issues(issues, transaction.get("issues", []))
	if transaction.get("recovery_required") == true:
		report["recovery_required"] = true


static func _compensate_files(plan: Dictionary, transaction: Dictionary, report: Dictionary) -> void:
	var issues: Array[String] = report["issues"]
	var current_installers: Variant = _copy_installers(ProjectSettings.get_setting(_INSTALLERS, []))
	if current_installers == null or plan["installer_path"] in current_installers or ProjectSettings.get_setting(_MAIN_SCENE, "") == plan["scene_path"]:
		issues.append("当前项目设置仍引用生成文件，保留文件供检查。")
		_retain_files(transaction, report)
		return
	var entries: Array = plan["entries"]
	for entry: Dictionary in entries:
		var path: String = entry["target_path"]
		var content: String = entry["text"]
		if FileAccess.get_sha256(path) != content.sha256_text():
			issues.append("文件已被其他操作修改，保留全部生成文件：" + path)
			_retain_files(transaction, report)
			return
	# 同一主线程内先校验全部创建内容，再交给事务重新校验路径与删除身份。
	var rollback: Dictionary = GFArtifactWriteTransaction.rollback(transaction)
	_record_transaction(report, rollback)
	report["rolled_back"] = rollback.get("ok") == true
	report["files_created"] = not report["rolled_back"]
	if report["rolled_back"]:
		for type_name: String in plan["classes"]:
			var _removed: bool = _pending_classes.erase(type_name)
		_settle_pending_classes()
	report["status"] = "rolled_back" if report["rolled_back"] else "recovery_required"


static func _retain_files(transaction: Dictionary, report: Dictionary) -> void:
	_record_transaction(report, GFArtifactWriteTransaction.complete(transaction))
	report["recovery_required"] = true
	report["status"] = "recovery_required"
