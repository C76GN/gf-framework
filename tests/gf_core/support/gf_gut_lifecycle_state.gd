# Process-wide lifecycle evidence shared by the GF GUT CLI wrapper and hooks.
extends RefCounted


# --- 枚举 ---

enum CapturePhase {
	IDLE,
	EARLY,
	TRACKED,
	TERMINAL,
	FINALIZED,
}


# --- 常量 ---

const REPORT_SCHEMA_VERSION: int = 1
const MAX_DETAIL_COUNT: int = 20
const MAX_TEXT_UTF8_BYTES: int = 512


# --- 私有变量 ---

static var _mutex: Mutex = Mutex.new()
static var _capture_phase: int = CapturePhase.IDLE
static var _baseline_available: bool = false
static var _warning_tracking_available: bool = false
static var _post_hook_completed: bool = false
static var _orphan_baseline: Dictionary = {}
static var _warning_count: int = 0
static var _warning_details: Array[Dictionary] = []
static var _orphans_by_id: Dictionary = {}
static var _configuration_error: String = ""


# --- 框架内部方法 ---

static func begin_run() -> void:
	_mutex.lock()
	_capture_phase = CapturePhase.EARLY
	_baseline_available = false
	_warning_tracking_available = false
	_post_hook_completed = false
	_orphan_baseline = {}
	_warning_count = 0
	_warning_details = []
	_orphans_by_id = {}
	_configuration_error = ""
	_mutex.unlock()


static func record_configuration_error(error_code: String) -> void:
	_mutex.lock()
	_set_configuration_error_locked(error_code)
	_mutex.unlock()


static func enter_tracking_phase(tracker_registered: bool) -> void:
	_mutex.lock()
	if tracker_registered:
		_capture_phase = CapturePhase.TRACKED
	else:
		_set_configuration_error_locked("warning_tracker_registration_failed")
	_mutex.unlock()


static func begin_terminal_capture() -> void:
	_mutex.lock()
	if _capture_phase == CapturePhase.EARLY or _capture_phase == CapturePhase.TRACKED:
		_capture_phase = CapturePhase.TERMINAL
	elif _capture_phase != CapturePhase.TERMINAL:
		_set_configuration_error_locked("terminal_capture_out_of_order")
	_mutex.unlock()


static func record_raw_warning(code: String, file: String, line: int) -> void:
	_mutex.lock()
	var test_id: String = ""
	if _capture_phase == CapturePhase.EARLY:
		test_id = "early"
	elif _capture_phase == CapturePhase.TERMINAL:
		test_id = "terminal"
	if not test_id.is_empty():
		_append_warning_locked(test_id, code, file, line)
	_mutex.unlock()


static func commit_orphan_baseline(orphan_ids: Dictionary) -> void:
	_mutex.lock()
	_orphan_baseline = orphan_ids.duplicate()
	_baseline_available = true
	_mutex.unlock()


static func snapshot_new_orphans() -> Dictionary:
	_mutex.lock()
	var baseline_available: bool = _baseline_available
	var orphan_baseline: Dictionary = _orphan_baseline.duplicate()
	_mutex.unlock()

	var orphan_details: Array[Dictionary] = []
	if baseline_available:
		for orphan_id: int in Node.get_orphan_node_ids():
			if not orphan_baseline.has(orphan_id):
				orphan_details.append(_orphan_detail(orphan_id))
	return {
		"ok": baseline_available,
		"orphans": orphan_details,
	}


static func commit_post_snapshot(
	tracked_warnings: Array[Dictionary],
	tracker_available: bool,
	orphan_snapshot: Dictionary
) -> bool:
	_mutex.lock()
	_post_hook_completed = true
	_warning_tracking_available = tracker_available
	for warning_detail: Dictionary in tracked_warnings:
		_append_warning_locked(
			_dictionary_string(warning_detail, "test_id"),
			_dictionary_string(warning_detail, "code"),
			_dictionary_string(warning_detail, "file"),
			_dictionary_int(warning_detail, "line")
		)
	_merge_orphan_snapshot_locked(orphan_snapshot)
	if not _baseline_available:
		_set_configuration_error_locked("orphan_baseline_unavailable")
	if not tracker_available:
		_set_configuration_error_locked("warning_tracker_unavailable")
	var snapshot_clean: bool = _snapshot_is_clean_locked()
	_mutex.unlock()
	return snapshot_clean


static func finalize_report() -> Dictionary:
	var final_orphan_snapshot: Dictionary = snapshot_new_orphans()

	_mutex.lock()
	_merge_orphan_snapshot_locked(final_orphan_snapshot)
	if not _post_hook_completed:
		_set_configuration_error_locked("post_hook_unavailable")
	if not _baseline_available:
		_set_configuration_error_locked("orphan_baseline_unavailable")
	if not _warning_tracking_available:
		_set_configuration_error_locked("warning_tracker_unavailable")
	_capture_phase = CapturePhase.FINALIZED

	var orphan_ids: Array = _orphans_by_id.keys()
	orphan_ids.sort()
	var orphan_details: Array[Dictionary] = []
	for orphan_id_value: Variant in orphan_ids.slice(0, MAX_DETAIL_COUNT):
		var raw_detail: Variant = _orphans_by_id.get(orphan_id_value)
		if raw_detail is Dictionary:
			var orphan_detail: Dictionary = raw_detail
			orphan_details.append(orphan_detail.duplicate())

	var orphan_count: int = _orphans_by_id.size()
	var report: Dictionary = {
		"schema_version": REPORT_SCHEMA_VERSION,
		"ok": _snapshot_is_clean_locked(),
		"baseline_available": _baseline_available,
		"warning_tracking_available": _warning_tracking_available,
		"unhandled_warning_count": _warning_count,
		"orphan_count": orphan_count,
		"warnings": _warning_details.duplicate(true),
		"orphans": orphan_details,
		"details_truncated": (
			_warning_count > MAX_DETAIL_COUNT
			or orphan_count > MAX_DETAIL_COUNT
		),
		"configuration_error": _bounded_text(_configuration_error),
	}
	_mutex.unlock()
	return report


# --- 私有/辅助方法 ---

static func _append_warning_locked(
	test_id: String,
	code: String,
	file: String,
	line: int
) -> void:
	_warning_count += 1
	if _warning_details.size() >= MAX_DETAIL_COUNT:
		return
	_warning_details.append({
		"test_id": _bounded_text(test_id),
		"code": _bounded_text(code),
		"file": _bounded_text(file),
		"line": maxi(line, 0),
	})


static func _merge_orphan_snapshot_locked(orphan_snapshot: Dictionary) -> void:
	var raw_orphans: Variant = orphan_snapshot.get("orphans")
	if not raw_orphans is Array:
		return
	var orphan_values: Array = raw_orphans
	for raw_orphan: Variant in orphan_values:
		if not raw_orphan is Dictionary:
			continue
		var orphan_detail: Dictionary = raw_orphan
		var instance_id: int = _dictionary_int(orphan_detail, "instance_id")
		if instance_id <= 0 or _orphans_by_id.has(instance_id):
			continue
		_orphans_by_id[instance_id] = {
			"instance_id": instance_id,
			"class": _bounded_text(_dictionary_string(orphan_detail, "class")),
			"name": _bounded_text(_dictionary_string(orphan_detail, "name")),
		}


static func _snapshot_is_clean_locked() -> bool:
	return (
		_baseline_available
		and _warning_tracking_available
		and _post_hook_completed
		and _warning_count == 0
		and _orphans_by_id.is_empty()
		and _configuration_error.is_empty()
	)


static func _set_configuration_error_locked(error_code: String) -> void:
	if _configuration_error.is_empty() and not error_code.is_empty():
		_configuration_error = _bounded_text(error_code)


static func _orphan_detail(orphan_id: int) -> Dictionary:
	var detail: Dictionary = {
		"instance_id": orphan_id,
		"class": "<released>",
		"name": "",
	}
	if not is_instance_id_valid(orphan_id):
		return detail

	var orphan_object: Object = instance_from_id(orphan_id)
	if not orphan_object is Node:
		return detail

	var orphan_node: Node = orphan_object
	detail["class"] = _bounded_text(orphan_node.get_class())
	detail["name"] = _bounded_text(String(orphan_node.name))
	return detail


static func _bounded_text(value: String) -> String:
	var result: String = ""
	var byte_count: int = 0
	for character_index: int in range(value.length()):
		var character: String = String.chr(value.unicode_at(character_index))
		var character_bytes: int = character.to_utf8_buffer().size()
		if byte_count + character_bytes > MAX_TEXT_UTF8_BYTES:
			break
		result += character
		byte_count += character_bytes
	return result


static func _dictionary_int(source: Dictionary, key: String) -> int:
	var raw_value: Variant = source.get(key, 0)
	return raw_value if raw_value is int else 0


static func _dictionary_string(source: Dictionary, key: String) -> String:
	var raw_value: Variant = source.get(key, "")
	if raw_value is String:
		return raw_value
	if raw_value is StringName:
		var string_name_value: StringName = raw_value
		return String(string_name_value)
	return str(raw_value)
