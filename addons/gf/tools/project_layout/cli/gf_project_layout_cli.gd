# Trusted maintenance entry; never launch with a target game's project.godot.
extends SceneTree


# --- 常量 ---

## Native editor and maintenance calls share this session authority.
## [br]
## @api private
const _SESSION_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_session.gd")

## Maximum transport bytes, including JSON escaping of a bounded profile.
## [br]
## @api private
const _REQUEST_MAX_BYTES: int = 8 * 1024 * 1024

## Bound the complete transport result before publication.
## [br]
## @api private
const _REPORT_MAX_BYTES: int = 16 * 1024 * 1024


# --- 私有变量 ---

## Transport encoding measurement also has a finite occurrence budget.
## [br]
## @api private
var _encoding_work_remaining: int = 4_000_000


# --- Godot 回调方法 ---

## Defer execution until Godot has completed SceneTree initialization.
## [br]
## @api private
func _initialize() -> void:
	_run.call_deferred()


# --- 私有/辅助方法 ---

## Read only the owned transport file and publish one complete native result.
## [br]
## @api private
func _run() -> void:
	var file: FileAccess = FileAccess.open("res://request.json", FileAccess.READ)
	if file == null or file.get_length() > _REQUEST_MAX_BYTES:
		quit(2)
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		quit(2)
		return
	var request: Variant = parser.data
	if not _request_is_valid(request):
		quit(2)
		return
	var admitted_request: Dictionary = request
	var profile_text: String = admitted_request["profile_text"]
	var profile_source_path: String = admitted_request["profile_source_path"]
	var options: Dictionary = admitted_request["options"]
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	var analysis: Dictionary = session.open_profile_text(
		profile_text, profile_source_path, options
	)
	var envelope: Dictionary = {
		"schema_version": 1,
		"kind": "project_layout_cli_result",
		"analysis": analysis,
	}
	if _measure_json_bytes(envelope, _REPORT_MAX_BYTES, 0) < 0:
		quit(3)
		return
	var report: PackedByteArray = JSON.stringify(envelope).to_utf8_buffer()
	if report.size() > _REPORT_MAX_BYTES:
		quit(2)
		return
	var output: FileAccess = FileAccess.open("res://report.json", FileAccess.WRITE)
	if output == null:
		quit(2)
		return
	var stored: bool = output.store_buffer(report)
	var write_error: Error = output.get_error()
	output.close()
	quit(0 if stored and write_error == OK else 2)


## Admit the closed maintenance transport; profile semantics belong to Session.
## [br]
## @api private
func _request_is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var request: Dictionary = value
	if request.size() != 5:
		return false
	for field: String in ["schema_version", "operation", "profile_text", "profile_source_path", "options"]:
		if not request.has(field):
			return false
	return (
		(request["schema_version"] is int or request["schema_version"] is float)
		and request["schema_version"] == 1
		and request["operation"] == "analyze"
		and request["profile_text"] is String
		and request["profile_source_path"] is String
		and request["options"] is Dictionary
	)


## Measure JSON transport bytes before allocating the complete encoded report.
## [br]
## @api private
func _measure_json_bytes(value: Variant, remaining: int, depth: int) -> int:
	_encoding_work_remaining -= 1
	if remaining < 0 or depth > 64 or _encoding_work_remaining < 0:
		return -1
	if value is Array or value is Dictionary:
		var size_bytes: int = 2
		for item: Variant in value:
			if size_bytes > 2:
				size_bytes += 1
			if value is Dictionary:
				if not item is String:
					return -1
				var key_bytes: int = JSON.stringify(item).to_utf8_buffer().size() + 1
				size_bytes += key_bytes
			var child: Variant = value[item] if value is Dictionary else item
			var child_bytes: int = _measure_json_bytes(child, remaining - size_bytes, depth + 1)
			if child_bytes < 0:
				return -1
			size_bytes += child_bytes
		return size_bytes if size_bytes <= remaining else -1
	if not (value == null or value is String or value is bool or value is int or value is float):
		return -1
	var scalar_bytes: int = JSON.stringify(value).to_utf8_buffer().size()
	return scalar_bytes if scalar_bytes <= remaining else -1
