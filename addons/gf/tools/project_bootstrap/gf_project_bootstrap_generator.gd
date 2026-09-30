@tool

# 空项目初始化协调器。模板声明产物；这里只处理预检、精确创建与项目设置补偿。
extends RefCounted


# --- 常量 ---

const _TEMPLATES_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_templates.gd")
const _AUTOLOAD_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_autoload.gd")
const _INSTALLERS: String = "gf/project/installers"
const _MAIN_SCENE: String = "application/run/main_scene"
const _AUTOLOAD: String = "autoload/Gf"
const _DEFAULT_DIRECTORY: String = "res://app"


# --- 私有变量 ---

static var _busy: bool = false
static var _test_save_error: Error = OK


# --- 框架内部方法 ---

## 只读预检空项目初始化或已有项目接入；不会写文件或保存设置。
## [br]
## @api framework_internal
## [br]
## @param directory: 项目源码目录，禁止指向框架或编辑器缓存；允许已有目录。
## [br]
## @param options: 显式操作模式与可选产物。
## [br]
## @schema options: 闭合 Dictionary，仅允许 mode:String（new_project 或 existing_project，默认 new_project）、create_installer:bool（默认 true）、include_readme:bool（默认 false）。
## [br]
## @return 文件、设置意图和绑定实际模板内容的预览签名。
## [br]
## @schema return: Dictionary，包含 ok:bool、status:String（preflight_failed、planned 或 guidance_only）、issues:Array[String]、directory:String、mode:String、options:Dictionary（规范化的三个选项）、template_id:String、template_version:int、paths:PackedStringArray、scene_path:String（本次创建的 boot 场景，否则为空）、main_scene_path:String、installer_path:String（本次创建的 Installer，否则为空）、integration_snippet:String、guidance_only:bool、entries:Array[Dictionary]、settings_before:Dictionary、settings_after:Dictionary、project_sha256:String 和 signature:String。entries 符合 GFArtifactWriteTransaction 文本 entry；settings_before 的值为 {exists:bool,value:Variant}，绑定原始 AutoLoad、Installer 与主场景设置。AutoLoad 仅作只读前提，不能进入 settings_after 或设置补偿。
static func get_plan(directory: String = _DEFAULT_DIRECTORY, options: Dictionary = {}) -> Dictionary:
	var issues: Array[String] = []
	var normalized: Dictionary = _normalize_options(options, issues)
	var path: String = directory.strip_edges().trim_suffix("/")
	var mode: String = normalized["mode"]
	var plan: Dictionary = {
		"ok": false, "status": "preflight_failed", "issues": issues,
		"directory": path, "mode": mode, "options": normalized,
		"template_id": "", "template_version": 0, "paths": PackedStringArray(),
		"scene_path": "", "main_scene_path": "", "installer_path": "",
		"integration_snippet": "", "guidance_only": false,
		"entries": [], "settings_before": {}, "settings_after": {},
		"project_sha256": "", "signature": "",
	}
	if not _valid_directory(path):
		issues.append("输出目录须为 res:// 下的项目目录，不能包含父路径、引号、反斜杠或指向 addons/.godot。")
	if not issues.is_empty():
		return plan
	var create_installer: bool = normalized["create_installer"]
	var before: Dictionary = {
		_INSTALLERS: _setting_snapshot(_INSTALLERS),
		_MAIN_SCENE: _setting_snapshot(_MAIN_SCENE),
		_AUTOLOAD: _setting_snapshot(_AUTOLOAD),
	}
	plan["settings_before"] = before
	var installers: Variant = _copy_installers(ProjectSettings.get_setting(_INSTALLERS, []))
	if installers == null:
		issues.append("gf/project/installers 不是有效的路径数组；请先修复项目设置。")
		return plan
	var raw_main_scene: Variant = ProjectSettings.get_setting(_MAIN_SCENE, "")
	if not raw_main_scene is String and not raw_main_scene is StringName:
		issues.append("项目主场景设置不是有效的字符串；请先修复项目设置。")
		return plan
	var current_main_scene: String = str(raw_main_scene)
	if mode == "new_project" and (not current_main_scene.is_empty() or not _installers_empty(installers)):
		issues.append("新项目初始化要求主场景与项目 Installer 均为空；已有项目请选择“接入已有项目”。")
	var after: Dictionary = {}
	if mode == "new_project":
		plan["scene_path"] = path.path_join("boot.tscn")
		plan["main_scene_path"] = path.path_join("main.tscn")
		after[_MAIN_SCENE] = plan["scene_path"]
	else:
		plan["main_scene_path"] = _resolve_resource_path(current_main_scene)
	if create_installer:
		var installer_path: String = path.path_join("project_installer.gd")
		plan["installer_path"] = installer_path
		if _installers_contain(installers, installer_path):
			issues.append("该 Installer 路径已登记，请选择新的输出目录。")
		after[_INSTALLERS] = _append_installer(installers, installer_path)
	plan["settings_after"] = after
	var manifest: Dictionary = _TEMPLATES_SCRIPT.get_manifest(normalized)
	plan["template_id"] = manifest["id"]
	plan["template_version"] = manifest["version"]
	var contents: Dictionary = _TEMPLATES_SCRIPT.render(path, normalized)
	var file_names: PackedStringArray = manifest["file_names"]
	if contents.size() != file_names.size():
		issues.append("空项目模板缺失或无法读取；请检查 GF 工具文件。")
	var entries: Array[Dictionary] = []
	var paths: PackedStringArray = PackedStringArray()
	for file_name: String in file_names:
		if not contents.has(file_name):
			continue
		var target: String = path.path_join(file_name)
		var content: String = contents[file_name]
		var _appended: bool = paths.append(target)
		if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
			issues.append("目标已存在，不会覆盖：" + target)
		entries.append(GFArtifactWriteTransaction.make_text_entry(target, content))
	plan["entries"] = entries
	plan["paths"] = paths
	plan["guidance_only"] = file_names.is_empty()
	var snippet: String = _TEMPLATES_SCRIPT.get_integration_snippet()
	plan["integration_snippet"] = snippet
	if snippet.is_empty():
		issues.append("初始化接入说明缺失或无法读取；请检查 GF 工具文件。")
	if not entries.is_empty():
		var preflight: Dictionary = GFArtifactWriteTransaction.get_preflight_report(entries, _transaction_options(path))
		if preflight.get("ok") != true:
			_append_issues(issues, preflight.get("issues", []))
	var project_hash: String = FileAccess.get_sha256("res://project.godot")
	if project_hash.is_empty():
		issues.append("无法读取 project.godot 的当前内容。")
	if not _AUTOLOAD_SCRIPT.is_registered_singleton():
		issues.append("请先启用指向 GF 核心脚本的 Gf AutoLoad 单例；同名冲突或未启用的配置不会被自动修改。")
	plan["project_sha256"] = project_hash
	plan["ok"] = issues.is_empty()
	if plan["ok"]:
		plan["status"] = "guidance_only" if plan["guidance_only"] else "planned"
	plan["signature"] = var_to_str([
		manifest, path, normalized, contents, snippet, before, after, project_hash,
	]).sha256_text()
	return plan


## 按有效预览创建文件并保存明确的设置变更；已有项目纯说明模式为零写入。
## [br]
## @api framework_internal
## [br]
## @param directory: 项目源码目录。
## [br]
## @param options: 与预览相同的显式操作模式及可选产物。
## [br]
## @schema options: 闭合 Dictionary，仅允许 mode:String（new_project 或 existing_project，默认 new_project）、create_installer:bool（默认 true）、include_readme:bool（默认 false）。
## [br]
## @param expected_signature: 可选的预览签名；非空时拒绝模板、文件或设置变化后的旧预览。
## [br]
## @return 操作报告；只有存在 settings_after 时才保存项目设置。
## [br]
## @schema return: Dictionary，包含 ok:bool、status:String、issues:Array[String]、mode:String、paths:PackedStringArray、scene_path:String、main_scene_path:String、installer_path:String、integration_snippet:String、guidance_only:bool、settings_saved:bool、files_created:bool、rolled_back:bool、recovery_required:bool 和 transactions:Array[Dictionary]。transactions 保存 GFArtifactWriteTransaction 的提交与终态报告，必要时含原样 recovery_transaction。guidance_only 成功时无事务、无文件或设置写入。
static func create(directory: String = _DEFAULT_DIRECTORY, options: Dictionary = {}, expected_signature: String = "") -> Dictionary:
	var report: Dictionary = _report()
	var issues: Array[String] = report["issues"]
	if _busy or not Thread.is_main_thread():
		issues.append("项目初始化正在执行，或调用不在主线程。")
		return report
	_busy = true
	var plan: Dictionary = get_plan(directory, options)
	if plan.get("ok") != true or (not expected_signature.is_empty() and plan["signature"] != expected_signature):
		_append_issues(issues, plan["issues"])
		if plan.get("ok") == true:
			issues.append("模板、项目设置或文件已变化，请重新预览初始化计划。")
		_busy = false
		return report
	for key: String in ["mode", "paths", "scene_path", "main_scene_path", "installer_path", "integration_snippet", "guidance_only"]:
		report[key] = plan[key]
	if plan["guidance_only"]:
		report["ok"] = true
		report["status"] = "guidance_only"
		_busy = false
		return report
	var output_directory: String = plan["directory"]
	var output_paths: PackedStringArray = plan["paths"]
	var before: Dictionary = plan["settings_before"]
	var transaction_options: Dictionary = _transaction_options(output_directory)
	var transaction: Dictionary = GFArtifactWriteTransaction.begin(output_paths, transaction_options)
	if transaction.get("ok") != true:
		_record_transaction(report, transaction)
		_busy = false
		return report
	var entries: Array[Dictionary] = []
	var entry_values: Array = plan["entries"]
	entries.assign(entry_values)
	var written: Dictionary = GFArtifactWriteTransaction.commit(entries, transaction_options)
	_record_transaction(report, written)
	if written.get("ok") != true:
		report["files_created"] = written.get("written_count", 0) > 0 or written.get("recovery_required") == true
		_record_transaction(report, GFArtifactWriteTransaction.complete(transaction))
		report["status"] = "file_commit_failed"
		_busy = false
		return report
	report["files_created"] = true
	if not _settings_match(before) or FileAccess.get_sha256("res://project.godot") != plan["project_sha256"]:
		issues.append("创建文件期间项目设置发生变化；未保存设置。")
		_compensate_files(plan, transaction, report)
		_busy = false
		return report
	var after: Dictionary = plan["settings_after"]
	if not after.is_empty():
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


## 为独立验收注入一次设置保存失败；仅真正进入保存步骤时消费。
## [br]
## @api framework_internal
## [br]
## @param error: 下次设置保存步骤返回的 Error，随后自动恢复 OK。
static func configure_test_save_error(error: Error) -> void:
	_test_save_error = error


# --- 私有/辅助方法 ---

static func _normalize_options(options: Dictionary, issues: Array[String]) -> Dictionary:
	var normalized: Dictionary = {"mode": "new_project", "create_installer": true, "include_readme": false}
	for key: Variant in options:
		if not key is String or not normalized.has(key):
			issues.append("初始化选项包含未知字段：" + str(key))
			continue
		var value: Variant = options[key]
		if key == "mode":
			if not value is String or value not in ["new_project", "existing_project"]:
				issues.append("mode 只接受 new_project 或 existing_project。")
				continue
		elif not value is bool:
			issues.append(str(key) + " 必须是 bool。")
			continue
		normalized[key] = value
	return normalized


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


static func _installers_empty(paths: Variant) -> bool:
	if paths is PackedStringArray:
		var packed_paths: PackedStringArray = paths
		return packed_paths.is_empty()
	var array_paths: Array = paths
	return array_paths.is_empty()


static func _installers_contain(paths: Variant, path: String) -> bool:
	if paths is PackedStringArray:
		var packed_paths: PackedStringArray = paths
		return packed_paths.has(path)
	var array_paths: Array = paths
	return array_paths.has(path)


static func _append_installer(paths: Variant, path: String) -> Variant:
	if paths is PackedStringArray:
		var packed_paths: PackedStringArray = paths
		var _appended: bool = packed_paths.append(path)
		return packed_paths
	var array_paths: Array = paths
	array_paths.append(path)
	return array_paths


static func _resolve_resource_path(path: String) -> String:
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
	return path


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


static func _transaction_options(directory: String) -> Dictionary:
	return {"allowed_roots": PackedStringArray([directory]), "overwrite_existing": false, "max_file_count": 5, "max_file_bytes": 65536, "max_total_bytes": 262144, "scan_filesystem": false}


static func _report() -> Dictionary:
	var issues: Array[String] = []
	var transactions: Array[Dictionary] = []
	return {"ok": false, "status": "preflight_failed", "issues": issues, "mode": "", "paths": PackedStringArray(), "scene_path": "", "main_scene_path": "", "installer_path": "", "integration_snippet": "", "guidance_only": false, "settings_saved": false, "files_created": false, "rolled_back": false, "recovery_required": false, "transactions": transactions}


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


## 删除前复核所有新文件的内容身份和当前设置引用，不能移除已经被用户接管的产物。
## [br]
## @api private
static func _compensate_files(plan: Dictionary, transaction: Dictionary, report: Dictionary) -> void:
	var issues: Array[String] = report["issues"]
	var current_installers: Variant = _copy_installers(ProjectSettings.get_setting(_INSTALLERS, []))
	var paths: PackedStringArray = plan["paths"]
	if current_installers == null or _settings_reference_outputs(current_installers, paths):
		issues.append("当前项目设置仍可能引用生成文件，保留文件供检查。")
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
	var rollback: Dictionary = GFArtifactWriteTransaction.rollback(transaction)
	_record_transaction(report, rollback)
	report["rolled_back"] = rollback.get("ok") == true
	report["files_created"] = not report["rolled_back"]
	report["status"] = "rolled_back" if report["rolled_back"] else "recovery_required"


static func _settings_reference_outputs(installers: Variant, paths: PackedStringArray) -> bool:
	var current_main: Variant = ProjectSettings.get_setting(_MAIN_SCENE, "")
	if not current_main is String and not current_main is StringName:
		return true
	if paths.has(_resolve_resource_path(str(current_main))):
		return true
	for value: Variant in installers:
		if paths.has(_resolve_resource_path(str(value))):
			return true
	return false


static func _retain_files(transaction: Dictionary, report: Dictionary) -> void:
	_record_transaction(report, GFArtifactWriteTransaction.complete(transaction))
	report["recovery_required"] = true
	report["status"] = "recovery_required"
