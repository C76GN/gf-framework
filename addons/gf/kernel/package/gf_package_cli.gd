extends SceneTree

# Godot 原生 GF 包管理命令行入口。
#
# 该脚本只做参数解析和输出格式化，所有 registry、lockfile、安装、卸载和回滚语义
# 都委托给 GFPackageManagerBackend，避免用户态 CLI 和编辑器向导产生第二套包语义。


# --- 常量 ---

const _GF_PACKAGE_MANAGER_BACKEND = preload("res://addons/gf/kernel/package/gf_package_manager_backend.gd")
const _GF_PACKAGE_CACHE_POLICY = preload("res://addons/gf/kernel/package/gf_package_cache_policy.gd")
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 默认包 lockfile 相对项目路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const DEFAULT_LOCKFILE_PATH: String = ".gf/packages.lock.json"

## status 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_STATUS: String = "status"

## install 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_INSTALL: String = "install"

## uninstall 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_UNINSTALL: String = "uninstall"

## update 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_UPDATE: String = "update"

## verify 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_VERIFY: String = "verify"

## recover 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_RECOVER: String = "recover"

## cache-init 命令名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const COMMAND_CACHE_INIT: String = "cache-init"


# --- Godot 生命周期方法 ---

func _init() -> void:
	var raw_args: PackedStringArray = _get_cli_args()
	var result: Dictionary = _run_cli(raw_args)
	if _cli_wants_json(raw_args):
		print(_GF_REPORT_VALUE_CODEC_SCRIPT.stringify_json_compatible(result, "", false, {
			"path_redaction": "none",
		}))
	else:
		print(_format_human_result(result))
	quit(0 if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false) else 1)


# --- 私有/辅助方法 ---

func _get_cli_args() -> PackedStringArray:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args

	var all_args: PackedStringArray = OS.get_cmdline_args()
	var result: PackedStringArray = PackedStringArray()
	var script_seen: bool = false
	for argument: String in all_args:
		if script_seen:
			if argument != "--":
				var _append_argument: bool = result.append(argument)
			continue
		if argument.ends_with("gf_package_cli.gd"):
			script_seen = true
	return result


func _run_cli(raw_args: PackedStringArray) -> Dictionary:
	if raw_args.is_empty():
		return _make_usage_error("", PackedStringArray(["Missing command."]))

	var command: String = raw_args[0]
	if command == "--help" or command == "-h":
		return _make_help_result()
	if not _is_valid_command(command):
		return _make_usage_error(command, PackedStringArray(["Unknown command: %s" % command]))

	var parsed: Dictionary = _parse_options(_tail_arguments(raw_args))
	var issues: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(parsed, "issues")
	var options: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(parsed, "options")
	if not issues.is_empty():
		return _make_usage_error(command, issues)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "help", false):
		return _make_help_result()
	if command == COMMAND_CACHE_INIT:
		return _GF_PACKAGE_MANAGER_BACKEND.initialize_package_cache(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "cache_dir")
		)

	var registry_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "registry")
	if command == COMMAND_STATUS:
		return _GF_PACKAGE_MANAGER_BACKEND.make_status(
			registry_path,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "project_root"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "lockfile"),
			_make_backend_options(options)
		)
	if command == COMMAND_VERIFY:
		return _run_verify(registry_path, options)
	if command == COMMAND_RECOVER:
		return _GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "project_root"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "lockfile")
		)

	var package_ids: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, "packages")
	var all_installed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "all_installed", false)
	if package_ids.is_empty() and command == COMMAND_INSTALL and not _install_options_have_selectors(options):
		return _make_usage_error(command, PackedStringArray(["Missing package id."]))
	if package_ids.is_empty() and command == COMMAND_UNINSTALL:
		return _make_usage_error(command, PackedStringArray(["Missing package id."]))
	if command == COMMAND_INSTALL:
		return _GF_PACKAGE_MANAGER_BACKEND.install_packages(
			package_ids,
			registry_path,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "project_root"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "lockfile"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "reason"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run"),
			_make_backend_options(options)
		)
	if command == COMMAND_UPDATE:
		if package_ids.is_empty() and not all_installed:
			return _make_usage_error(command, PackedStringArray(["Missing package id. Use --all-installed to update every installed package."]))
		return _GF_PACKAGE_MANAGER_BACKEND.update_packages(
			package_ids,
			registry_path,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "project_root"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "lockfile"),
			all_installed,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run"),
			_make_backend_options(options)
		)
	return _GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		package_ids,
		registry_path,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "project_root"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "lockfile"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "force"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run"),
		_make_backend_options(options)
	)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"registry": "",
		"project_root": ProjectSettings.globalize_path("res://").replace("\\", "/"),
		"lockfile": DEFAULT_LOCKFILE_PATH,
		"reason": "manual",
		"dry_run": false,
		"force": false,
		"all_installed": false,
		"all_concrete": false,
		"include_kinds": [],
		"exclude_kinds": [],
		"cache_dir": "",
		"cache_mode": _GF_PACKAGE_CACHE_POLICY.MODE_PROJECT_LOCAL,
		"channel": "",
		"packages": [],
	}
	var issues: PackedStringArray = PackedStringArray()
	var package_ids: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < args.size():
		var argument: String = args[index]
		if argument == "--registry":
			index = _read_option_value(args, index, "registry", options, issues)
		elif argument.begins_with("--registry="):
			options["registry"] = argument.substr("--registry=".length()).strip_edges()
		elif argument == "--project-root":
			index = _read_option_value(args, index, "project_root", options, issues)
		elif argument.begins_with("--project-root="):
			options["project_root"] = argument.substr("--project-root=".length()).strip_edges()
		elif argument == "--lockfile":
			index = _read_option_value(args, index, "lockfile", options, issues)
		elif argument.begins_with("--lockfile="):
			options["lockfile"] = argument.substr("--lockfile=".length()).strip_edges()
		elif argument == "--reason":
			index = _read_option_value(args, index, "reason", options, issues)
		elif argument.begins_with("--reason="):
			options["reason"] = argument.substr("--reason=".length()).strip_edges()
		elif argument == "--cache-dir":
			index = _read_option_value(args, index, "cache_dir", options, issues)
		elif argument.begins_with("--cache-dir="):
			options["cache_dir"] = argument.substr("--cache-dir=".length()).strip_edges()
		elif argument == "--cache-mode":
			index = _read_option_value(args, index, "cache_mode", options, issues)
		elif argument.begins_with("--cache-mode="):
			options["cache_mode"] = argument.substr("--cache-mode=".length()).strip_edges()
		elif argument == "--channel":
			index = _read_option_value(args, index, "channel", options, issues)
		elif argument.begins_with("--channel="):
			options["channel"] = argument.substr("--channel=".length()).strip_edges()
		elif argument == "--dry-run":
			options["dry_run"] = true
		elif argument == "--force":
			options["force"] = true
		elif argument == "--all-installed":
			options["all_installed"] = true
		elif argument == "--all-concrete":
			options["all_concrete"] = true
		elif argument == "--kind":
			index = _read_string_list_option_value(args, index, "kind", "include_kinds", options, issues)
		elif argument.begins_with("--kind="):
			_append_string_list_option_values(options, "include_kinds", argument.substr("--kind=".length()))
		elif argument == "--exclude-kind":
			index = _read_string_list_option_value(args, index, "exclude-kind", "exclude_kinds", options, issues)
		elif argument.begins_with("--exclude-kind="):
			_append_string_list_option_values(options, "exclude_kinds", argument.substr("--exclude-kind=".length()))
		elif argument == "--json":
			options["json"] = true
		elif argument == "--help" or argument == "-h":
			options["help"] = true
		elif argument.begins_with("--"):
			var _append_unknown: bool = issues.append("Unknown option: %s" % argument)
		else:
			var _append_package: bool = package_ids.append(argument)
		index += 1
	options["packages"] = _packed_to_array(package_ids)
	return { "options": options, "issues": _packed_to_array(issues) }


func _read_string_list_option_value(
	args: PackedStringArray,
	index: int,
	display_key: String,
	option_key: String,
	options: Dictionary,
	issues: PackedStringArray
) -> int:
	if index + 1 >= args.size():
		var _append_missing: bool = issues.append("Missing value for --%s" % display_key)
		return index
	var value: String = args[index + 1].strip_edges()
	if value.is_empty():
		var _append_empty: bool = issues.append("Empty value for --%s" % display_key)
	else:
		_append_string_list_option_values(options, option_key, value)
	return index + 1


func _append_string_list_option_values(options: Dictionary, key: String, value_text: String) -> void:
	var values: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, key)
	for raw_value: String in value_text.split(",", false):
		var value: String = raw_value.strip_edges()
		if value.is_empty() or values.has(value):
			continue
		var _append_value: bool = values.append(value)
	options[key] = _packed_to_array(values)


func _read_option_value(
	args: PackedStringArray,
	index: int,
	key: String,
	options: Dictionary,
	issues: PackedStringArray
) -> int:
	if index + 1 >= args.size():
		var _append_missing: bool = issues.append("Missing value for --%s" % key.replace("_", "-"))
		return index
	var value: String = args[index + 1].strip_edges()
	if value.is_empty():
		var _append_empty: bool = issues.append("Empty value for --%s" % key.replace("_", "-"))
	else:
		options[key] = value
	return index + 1


func _run_verify(registry_path: String, options: Dictionary) -> Dictionary:
	var status: Dictionary = _GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "project_root"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "lockfile"),
		_make_backend_options(options)
	)
	var lockfile_verify: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(status, "lockfile_verify")
	var issues: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(status, "issues")
	var result: Dictionary = {
		"ok": (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(status, "ok", false)
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(lockfile_verify, "ok", false)
		),
		"operation": COMMAND_VERIFY,
		"backend": "godot_native",
		"project_root": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "project_root"),
		"registry": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "registry"),
		"registry_remote": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(status, "registry_remote"),
		"lockfile": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "lockfile"),
		"lockfile_verify": lockfile_verify,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
	}
	_copy_registry_source_fields(result, status)
	return result


func _make_backend_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"cache_mode": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			options,
			"cache_mode",
			_GF_PACKAGE_CACHE_POLICY.MODE_PROJECT_LOCAL
		),
	}
	var cache_dir: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "cache_dir")
	if not cache_dir.is_empty():
		result["cache_dir"] = cache_dir
	var channel: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "channel")
	if not channel.is_empty():
		result["channel"] = channel
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "all_concrete", false):
		result["all_concrete"] = true
	var include_kinds: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, "include_kinds")
	if not include_kinds.is_empty():
		result["include_kinds"] = _packed_to_array(include_kinds)
	var exclude_kinds: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, "exclude_kinds")
	if not exclude_kinds.is_empty():
		result["exclude_kinds"] = _packed_to_array(exclude_kinds)
	return result


func _install_options_have_selectors(options: Dictionary) -> bool:
	return (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "all_concrete", false)
		or not _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, "include_kinds").is_empty()
		or not _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(options, "exclude_kinds").is_empty()
	)


func _copy_registry_source_fields(target: Dictionary, source: Dictionary) -> void:
	for key: String in [
		"registry_source",
		"registry_source_manifest",
		"registry_channel",
		"registry_mirror_index",
		"registry_source_sha256",
		"registry_source_size_bytes",
		"registry_cache_dir",
		"cache",
	]:
		if source.has(key):
			target[key] = source[key]


func _tail_arguments(args: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for index: int in range(1, args.size()):
		var _append_argument: bool = result.append(args[index])
	return result


func _is_valid_command(command: String) -> bool:
	return (
		command == COMMAND_STATUS
		or command == COMMAND_INSTALL
		or command == COMMAND_UNINSTALL
		or command == COMMAND_UPDATE
		or command == COMMAND_VERIFY
		or command == COMMAND_RECOVER
		or command == COMMAND_CACHE_INIT
	)


func _make_usage_error(command: String, issues: PackedStringArray) -> Dictionary:
	return {
		"ok": false,
		"operation": command,
		"backend": "godot_native",
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
		"usage": _usage_text(),
	}


func _make_help_result() -> Dictionary:
	return {
		"ok": true,
		"operation": "help",
		"backend": "godot_native",
		"usage": _usage_text(),
		"issues": [],
		"issue_count": 0,
	}


func _usage_text() -> String:
	return "\n".join(PackedStringArray([
		"GF Package CLI (Godot native)",
		"Usage:",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- status [--registry <index.json-or-url-or-source.json>] [--channel <name>] [--project-root <target>] [--lockfile <path>] [--cache-mode <mode>] [--cache-dir <path>] [--json]",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- install [<package-id>...] [--all-concrete] [--kind <kind[,kind...]>] [--exclude-kind <kind[,kind...]>] [--registry <index.json-or-url-or-source.json>] [--channel <name>] [--project-root <target>] [--lockfile <path>] [--reason manual|preset|bundled|dev] [--cache-mode <mode>] [--cache-dir <path>] [--dry-run] [--json]",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- update [<package-id>...] [--all-installed] [--registry <index.json-or-url-or-source.json>] [--channel <name>] [--project-root <target>] [--lockfile <path>] [--cache-mode <mode>] [--cache-dir <path>] [--dry-run] [--json]",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- uninstall <package-id>... [--registry <index.json-or-url-or-source.json>] [--channel <name>] [--project-root <target>] [--lockfile <path>] [--cache-mode <mode>] [--cache-dir <path>] [--dry-run] [--force] [--json]",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- verify [--registry <index.json-or-url-or-source.json>] [--channel <name>] [--project-root <target>] [--lockfile <path>] [--cache-mode <mode>] [--cache-dir <path>] [--json]",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- recover [--project-root <target>] [--lockfile <path>] [--json]",
		"  godot --headless --path <project> --script res://addons/gf/kernel/package/gf_package_cli.gd -- cache-init --cache-dir <absolute-path> [--json]",
		"  cache modes: project_local, external_read_only, external_shared_rw.",
		"  --registry is optional; omit it to use the default GF release registry source.",
	]))


func _cli_wants_json(raw_args: PackedStringArray) -> bool:
	for argument: String in raw_args:
		if argument == "--json":
			return true
	return false


func _format_human_result(result: Dictionary) -> String:
	var operation: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "operation")
	if operation == "help":
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "usage")

	var lines: PackedStringArray = PackedStringArray()
	var ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false)
	_append_human_line(lines, "GF Package CLI %s: %s" % [_human_operation_label(operation), "ok" if ok else "failed"])
	_append_human_path_line(lines, "Project", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "project_root"))
	_append_human_path_line(lines, "Registry", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "registry"))
	_append_human_path_line(lines, "Lockfile", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "lockfile"))
	_append_human_registry_source(lines, result)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "registry_remote", false):
		_append_human_line(lines, "Registry source: HTTP(S)")

	if operation == COMMAND_STATUS:
		_append_human_line(lines, "Packages: %d total, %d installed, %d available" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "package_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "installed_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "available_count", 0),
		])
		_append_human_lockfile_verify(lines, result)
	elif operation == COMMAND_INSTALL:
		_append_human_package_list(lines, "Requested", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "requested_packages"))
		_append_human_package_list(lines, "Install order", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "install_order"))
		_append_human_package_list(lines, "Installed packages", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "installed_packages"))
		_append_human_line(lines, "Install plan: %d install, %d update" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "to_install").size(),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "to_update").size(),
		])
		_append_human_count_line(lines, "Installed files", _GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "installed_file_count", 0))
		_append_human_flag_line(lines, "Dry run", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "dry_run", false))
		_append_human_flag_line(lines, "Rolled back", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "rolled_back", false))
	elif operation == COMMAND_UPDATE:
		_append_human_package_list(lines, "Requested", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "requested_packages"))
		_append_human_package_list(lines, "Updated packages", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "updated_packages"))
		_append_human_line(lines, "Update plan: %d install, %d update" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "to_install").size(),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "to_update").size(),
		])
		_append_human_count_line(lines, "Updated files", _GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "updated_file_count", 0))
		_append_human_flag_line(lines, "All installed", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "all_installed", false))
		_append_human_flag_line(lines, "Dry run", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "dry_run", false))
		_append_human_flag_line(lines, "Rolled back", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "rolled_back", false))
	elif operation == COMMAND_UNINSTALL:
		_append_human_package_list(lines, "Requested", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "requested_packages"))
		_append_human_package_list(lines, "Removed packages", _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "removed_packages"))
		_append_human_package_list(lines, "Blocked packages", _blocked_package_ids(_GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "blocked")))
		_append_human_count_line(lines, "Planned files", _GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "planned_file_count", 0))
		_append_human_count_line(lines, "Removed files", _GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "removed_file_count", 0))
		_append_human_flag_line(lines, "Dry run", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "dry_run", false))
		_append_human_flag_line(lines, "Force", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "force", false))
		_append_human_flag_line(lines, "Rolled back", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "rolled_back", false))
	elif operation == COMMAND_VERIFY:
		_append_human_lockfile_verify(lines, result)
	elif operation == COMMAND_RECOVER:
		_append_human_line(lines, "Transaction outcome: %s" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "outcome", "none"))
		_append_human_flag_line(lines, "Recovered", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "recovered", false))
		_append_human_flag_line(lines, "Rolled back", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "rolled_back", false))
		_append_human_flag_line(lines, "Recovery required", _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "recovery_required", false))

	_append_human_issues(lines, _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "issues"))
	if not ok and result.has("usage"):
		_append_human_line(lines, "")
		_append_human_line(lines, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "usage"))
	return "\n".join(lines)


func _append_human_registry_source(lines: PackedStringArray, result: Dictionary) -> void:
	var registry_source: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "registry_source")
	var registry_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "registry")
	if not registry_source.is_empty() and registry_source != registry_path:
		_append_human_path_line(lines, "Registry resolved source", registry_source)
	var source_manifest: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "registry_source_manifest")
	if not source_manifest.is_empty():
		_append_human_path_line(lines, "Registry source manifest", source_manifest)
	var channel: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "registry_channel")
	if not channel.is_empty():
		_append_human_line(lines, "Registry channel: %s" % channel)
	if result.has("registry_mirror_index"):
		var mirror_index: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "registry_mirror_index", -2)
		var mirror_label: String = "primary" if mirror_index < 0 else "mirror %d" % mirror_index
		_append_human_line(lines, "Registry mirror: %s" % mirror_label)


func _human_operation_label(operation: String) -> String:
	if operation.is_empty():
		return "command"
	return operation


func _append_human_path_line(lines: PackedStringArray, label: String, value: String) -> void:
	if value.is_empty():
		return
	_append_human_line(lines, "%s: %s" % [label, value])


func _append_human_package_list(lines: PackedStringArray, label: String, values: Array) -> void:
	if values.is_empty():
		return
	_append_human_line(lines, "%s: %s" % [label, _join_variant_array(values)])


func _append_human_count_line(lines: PackedStringArray, label: String, value: int) -> void:
	if value <= 0:
		return
	_append_human_line(lines, "%s: %d" % [label, value])


func _append_human_flag_line(lines: PackedStringArray, label: String, enabled: bool) -> void:
	if not enabled:
		return
	_append_human_line(lines, "%s: yes" % label)


func _append_human_lockfile_verify(lines: PackedStringArray, result: Dictionary) -> void:
	var lockfile_verify: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(result, "lockfile_verify")
	if lockfile_verify.is_empty():
		return
	_append_human_line(
		lines,
		"Lockfile verify: %s" % ("ok" if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(lockfile_verify, "ok", false) else "failed")
	)


func _append_human_issues(lines: PackedStringArray, issues: Array) -> void:
	if issues.is_empty():
		return
	_append_human_line(lines, "Issues:")
	for issue: Variant in issues:
		_append_human_line(lines, "  - %s" % str(issue))


func _blocked_package_ids(blocked: Array) -> Array:
	var result: Array = []
	for value: Variant in blocked:
		if not value is Dictionary:
			continue
		var blocked_entry: Dictionary = value
		var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(blocked_entry, "id")
		if not package_id.is_empty():
			result.append(package_id)
	return result


func _join_variant_array(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var _append_value: bool = parts.append(str(value))
	return ", ".join(parts)


func _append_human_line(lines: PackedStringArray, text: String) -> void:
	var _append_line: bool = lines.append(text)


func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
