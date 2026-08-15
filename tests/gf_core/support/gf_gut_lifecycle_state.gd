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
const GUT_OBSERVATION_SCHEMA_VERSION: int = 1
const MAX_DETAIL_COUNT: int = 20
const MAX_TEXT_UTF8_BYTES: int = 512
const MAX_GUT_OBSERVATION_JUNIT_BYTES: int = 32 * 1024 * 1024
const MAX_GUT_OBSERVATION_JSON_BYTES: int = 8 * 1024 * 1024
const GUT_OBSERVATION_NONCE_ENVIRONMENT: String = (
	"GF_GUT_SHARD_OBSERVATION_NONCE"
)
const GUT_OBSERVATION_PATH_ENVIRONMENT: String = (
	"GF_GUT_SHARD_OBSERVATION_PATH"
)
const GUT_OBSERVATION_NONCE_HEX_LENGTH: int = 64
const GUT_OBSERVATION_JUNIT_FILENAME: String = "gut-authoritative.xml"
const GUT_OBSERVATION_SIDECAR_FILENAME: String = (
	"gut-authoritative-provenance.json"
)


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
static var _gut_observation_enabled: bool = false
static var _gut_observation_nonce: String = ""
static var _gut_observation_path: String = ""
static var _gut_observation_timing_connected: bool = false
static var _gut_observation_current_script_key: String = ""
static var _gut_observation_current_script_started_usec: int = 0
static var _gut_observation_script_durations_usec: Dictionary = {}
static var _gut_observation_implicit_end_keys: Dictionary = {}
static var _gut_observation_snapshot: Dictionary = {}
static var _gut_observation_snapshot_available: bool = false
static var _gut_observation_published: bool = false


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
	_reset_gut_observation_locked()
	_configure_gut_observation_locked()
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


static func gut_observation_is_enabled() -> bool:
	_mutex.lock()
	var enabled: bool = _gut_observation_enabled
	_mutex.unlock()
	return enabled


static func commit_gut_observation_timing_connections(
	start_connected: bool,
	end_connected: bool
) -> bool:
	_mutex.lock()
	if not _gut_observation_enabled:
		_mutex.unlock()
		return true
	if _gut_observation_timing_connected or not start_connected or not end_connected:
		_set_configuration_error_locked(
			"gut_observation_timing_connection_failed"
		)
		_mutex.unlock()
		return false
	_gut_observation_timing_connected = true
	_mutex.unlock()
	return true


static func record_gut_observation_script_started(
	test_script_value: Variant
) -> void:
	var identity: Dictionary = _gut_observation_script_identity(test_script_value)
	var identity_ok_value: Variant = identity.get("ok", false)
	if not identity_ok_value is bool or not identity_ok_value:
		record_configuration_error("gut_observation_script_identity_invalid")
		return
	var script_key_value: Variant = identity.get("key", "")
	if not script_key_value is String:
		record_configuration_error("gut_observation_script_identity_invalid")
		return
	var script_key: String = script_key_value
	var started_usec: int = Time.get_ticks_usec()

	_mutex.lock()
	if not _gut_observation_enabled:
		_mutex.unlock()
		return
	if not _gut_observation_timing_connected:
		_set_configuration_error_locked("gut_observation_timing_unavailable")
		_mutex.unlock()
		return
	if not _gut_observation_current_script_key.is_empty():
		_finish_gut_observation_script_timing_locked(started_usec, true)
	if _gut_observation_script_durations_usec.has(script_key):
		_set_configuration_error_locked("gut_observation_script_duplicate")
		_mutex.unlock()
		return
	_gut_observation_current_script_key = script_key
	_gut_observation_current_script_started_usec = started_usec
	_mutex.unlock()


static func record_gut_observation_script_ended() -> void:
	var ended_usec: int = Time.get_ticks_usec()
	_mutex.lock()
	if not _gut_observation_enabled:
		_mutex.unlock()
		return
	if _gut_observation_current_script_key.is_empty():
		_set_configuration_error_locked("gut_observation_timing_protocol_invalid")
		_mutex.unlock()
		return
	_finish_gut_observation_script_timing_locked(ended_usec, false)
	_mutex.unlock()


static func capture_gut_observation(gut_main: GutMain) -> bool:
	if not gut_observation_is_enabled():
		return true

	var captured_usec: int = Time.get_ticks_usec()
	_mutex.lock()
	if not _gut_observation_current_script_key.is_empty():
		_finish_gut_observation_script_timing_locked(captured_usec, true)
	var timing_connected: bool = _gut_observation_timing_connected
	var durations_usec: Dictionary = (
		_gut_observation_script_durations_usec.duplicate()
	)
	var implicit_end_keys: Dictionary = (
		_gut_observation_implicit_end_keys.duplicate()
	)
	_mutex.unlock()

	if not timing_connected or not _gut_observation_junit_configuration_is_valid(
		gut_main
	):
		record_configuration_error("gut_observation_configuration_invalid")
		return false

	var collector_value: Variant = gut_main.get_test_collector()
	if not collector_value is Object:
		record_configuration_error("gut_observation_collector_unavailable")
		return false
	var collector: Object = collector_value
	var raw_scripts: Variant = collector.get("scripts")
	if not raw_scripts is Array:
		record_configuration_error("gut_observation_scripts_invalid")
		return false

	var filters_empty: bool = (
		_gut_observation_filter_is_empty(gut_main.get("unit_test_name"))
		and _gut_observation_filter_is_empty(gut_main.get("inner_class_name"))
		and _gut_observation_filter_is_empty(gut_main.get("_script_name"))
		and _gut_observation_filter_is_empty(gut_main.get("_select_script"))
	)
	var unfiltered: bool = filters_empty
	var scripts: Array[Dictionary] = []
	var seen_script_keys: Dictionary = {}
	var script_values: Array = raw_scripts
	for raw_script: Variant in script_values:
		var captured_script: Dictionary = _capture_gut_observation_script(
			raw_script,
			durations_usec,
			implicit_end_keys
		)
		var captured_ok_value: Variant = captured_script.get("ok", false)
		if not captured_ok_value is bool or not captured_ok_value:
			record_configuration_error("gut_observation_script_invalid")
			return false
		var record_value: Variant = captured_script.get("record")
		if not record_value is Dictionary:
			record_configuration_error("gut_observation_script_invalid")
			return false
		var script_record: Dictionary = record_value
		var identity: Dictionary = _gut_observation_record_identity(script_record)
		var identity_ok_value: Variant = identity.get("ok", false)
		var script_key_value: Variant = identity.get("key", "")
		if (
			not identity_ok_value is bool
			or not identity_ok_value
			or not script_key_value is String
		):
			record_configuration_error("gut_observation_script_identity_invalid")
			return false
		var script_key: String = script_key_value
		if seen_script_keys.has(script_key):
			record_configuration_error("gut_observation_script_duplicate")
			return false
		seen_script_keys[script_key] = true
		scripts.append(script_record)
		var complete_value: Variant = captured_script.get("complete", false)
		if not complete_value is bool or not complete_value:
			unfiltered = false

	if durations_usec.size() != seen_script_keys.size():
		unfiltered = false
	scripts.sort_custom(_compare_gut_observation_script_records)
	var snapshot: Dictionary = {
		"unfiltered": unfiltered,
		"script_count": scripts.size(),
		"scripts": scripts,
	}

	_mutex.lock()
	if _gut_observation_snapshot_available:
		_set_configuration_error_locked("gut_observation_snapshot_duplicate")
		_mutex.unlock()
		return false
	_gut_observation_snapshot = snapshot
	_gut_observation_snapshot_available = true
	_mutex.unlock()
	return true


static func publish_gut_observation() -> bool:
	_mutex.lock()
	if not _gut_observation_enabled:
		_mutex.unlock()
		return true
	if _gut_observation_published or not _gut_observation_snapshot_available:
		_set_configuration_error_locked("gut_observation_snapshot_unavailable")
		_mutex.unlock()
		return false
	var nonce: String = _gut_observation_nonce
	var sidecar_path: String = _gut_observation_path
	var snapshot: Dictionary = _gut_observation_snapshot.duplicate(true)
	_mutex.unlock()

	var junit_path: String = _expected_gut_observation_junit_path(nonce)
	var junit_bytes: PackedByteArray = _read_gut_observation_junit(junit_path)
	if junit_bytes.is_empty():
		record_configuration_error("gut_observation_junit_unavailable")
		return false
	var junit_sha256: String = _gut_observation_sha256_bytes(junit_bytes)
	if not _gut_observation_nonce_is_valid(junit_sha256):
		record_configuration_error("gut_observation_junit_hash_failed")
		return false
	var payload: Dictionary = {
		"schema_version": GUT_OBSERVATION_SCHEMA_VERSION,
		"nonce": nonce,
		"junit_sha256": junit_sha256,
		"unfiltered": snapshot.get("unfiltered", false),
		"script_count": snapshot.get("script_count", 0),
		"scripts": snapshot.get("scripts", []),
	}
	var json_text: String = JSON.stringify(payload, "", true) + "\n"
	if json_text.to_utf8_buffer().size() > MAX_GUT_OBSERVATION_JSON_BYTES:
		record_configuration_error("gut_observation_sidecar_oversized")
		return false
	if not _write_gut_observation_sidecar(sidecar_path, json_text):
		record_configuration_error("gut_observation_sidecar_write_failed")
		return false

	_mutex.lock()
	_gut_observation_published = true
	_mutex.unlock()
	return true


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

static func _reset_gut_observation_locked() -> void:
	_gut_observation_enabled = false
	_gut_observation_nonce = ""
	_gut_observation_path = ""
	_gut_observation_timing_connected = false
	_gut_observation_current_script_key = ""
	_gut_observation_current_script_started_usec = 0
	_gut_observation_script_durations_usec = {}
	_gut_observation_implicit_end_keys = {}
	_gut_observation_snapshot = {}
	_gut_observation_snapshot_available = false
	_gut_observation_published = false


static func _configure_gut_observation_locked() -> void:
	var nonce_present: bool = OS.has_environment(
		GUT_OBSERVATION_NONCE_ENVIRONMENT
	)
	var path_present: bool = OS.has_environment(
		GUT_OBSERVATION_PATH_ENVIRONMENT
	)
	if not nonce_present and not path_present:
		return
	if not nonce_present or not path_present:
		_set_configuration_error_locked("gut_observation_environment_incomplete")
		return

	var nonce: String = OS.get_environment(GUT_OBSERVATION_NONCE_ENVIRONMENT)
	var sidecar_path: String = OS.get_environment(
		GUT_OBSERVATION_PATH_ENVIRONMENT
	)
	if not _gut_observation_nonce_is_valid(nonce):
		_set_configuration_error_locked("gut_observation_nonce_invalid")
		return
	if sidecar_path != _expected_gut_observation_sidecar_path(nonce):
		_set_configuration_error_locked("gut_observation_path_invalid")
		return

	_gut_observation_enabled = true
	_gut_observation_nonce = nonce
	_gut_observation_path = sidecar_path


static func _gut_observation_nonce_is_valid(value: String) -> bool:
	if value.length() != GUT_OBSERVATION_NONCE_HEX_LENGTH:
		return false
	for character_index: int in range(value.length()):
		var codepoint: int = value.unicode_at(character_index)
		if not (
			(codepoint >= 48 and codepoint <= 57)
			or (codepoint >= 97 and codepoint <= 102)
		):
			return false
	return true


static func _expected_gut_observation_directory(nonce: String) -> String:
	return "res://build/gut-sharding/" + nonce


static func _expected_gut_observation_junit_path(nonce: String) -> String:
	return (
		_expected_gut_observation_directory(nonce)
		+ "/"
		+ GUT_OBSERVATION_JUNIT_FILENAME
	)


static func _expected_gut_observation_sidecar_path(nonce: String) -> String:
	return (
		_expected_gut_observation_directory(nonce)
		+ "/"
		+ GUT_OBSERVATION_SIDECAR_FILENAME
	)


static func _finish_gut_observation_script_timing_locked(
	ended_usec: int,
	implicit_end: bool
) -> void:
	var duration_usec: int = maxi(
		ended_usec - _gut_observation_current_script_started_usec,
		0
	)
	_gut_observation_script_durations_usec[
		_gut_observation_current_script_key
	] = duration_usec
	if implicit_end:
		_gut_observation_implicit_end_keys[
			_gut_observation_current_script_key
		] = true
	_gut_observation_current_script_key = ""
	_gut_observation_current_script_started_usec = 0


static func _gut_observation_script_identity(value: Variant) -> Dictionary:
	if not value is Object:
		return {"ok": false}
	var script_object: Object = value
	var script_result: Dictionary = _gut_observation_required_text(
		script_object.get("path"),
		false
	)
	var inner_result: Dictionary = _gut_observation_required_text(
		script_object.get("inner_class_name"),
		true
	)
	if not script_result.get("ok", false) or not inner_result.get("ok", false):
		return {"ok": false}
	var script: String = script_result.get("value", "")
	var inner_class: String = inner_result.get("value", "")
	if not script.begins_with("res://"):
		return {"ok": false}
	return {
		"ok": true,
		"script": script,
		"inner_class": inner_class,
		"key": _gut_observation_script_key(script, inner_class),
	}


static func _gut_observation_record_identity(record: Dictionary) -> Dictionary:
	var script_result: Dictionary = _gut_observation_required_text(
		record.get("script"),
		false
	)
	var inner_result: Dictionary = _gut_observation_required_text(
		record.get("inner_class"),
		true
	)
	if not script_result.get("ok", false) or not inner_result.get("ok", false):
		return {"ok": false}
	var script: String = script_result.get("value", "")
	var inner_class: String = inner_result.get("value", "")
	return {
		"ok": true,
		"key": _gut_observation_script_key(script, inner_class),
	}


static func _gut_observation_script_key(
	script: String,
	inner_class: String
) -> String:
	return script + "\u001f" + inner_class


static func _capture_gut_observation_script(
	raw_script: Variant,
	durations_usec: Dictionary,
	implicit_end_keys: Dictionary
) -> Dictionary:
	var identity: Dictionary = _gut_observation_script_identity(raw_script)
	if not identity.get("ok", false) or not raw_script is Object:
		return {"ok": false}
	var script_object: Object = raw_script
	var was_run_result: Dictionary = _gut_observation_required_bool(
		script_object.get("was_run")
	)
	var was_skipped_result: Dictionary = _gut_observation_required_bool(
		script_object.get("was_skipped")
	)
	var raw_tests: Variant = script_object.get("tests")
	var raw_lifecycle_tests: Variant = script_object.get(
		"setup_teardown_tests"
	)
	if (
		not was_run_result.get("ok", false)
		or not was_skipped_result.get("ok", false)
		or not raw_tests is Array
		or not raw_lifecycle_tests is Array
	):
		return {"ok": false}

	var tests: Array[Dictionary] = []
	var seen_test_names: Dictionary = {}
	var testcase_assertion_count: int = 0
	var all_tests_ran: bool = true
	var test_values: Array = raw_tests
	for raw_test: Variant in test_values:
		var captured_test: Dictionary = _capture_gut_observation_test(raw_test)
		if not captured_test.get("ok", false):
			return {"ok": false}
		var record_value: Variant = captured_test.get("record")
		if not record_value is Dictionary:
			return {"ok": false}
		var test_record: Dictionary = record_value
		var test_name_value: Variant = test_record.get("name")
		if not test_name_value is String:
			return {"ok": false}
		var test_name: String = test_name_value
		if seen_test_names.has(test_name):
			return {"ok": false}
		seen_test_names[test_name] = true
		var assertion_count_value: Variant = test_record.get("assertion_count")
		if not assertion_count_value is int:
			return {"ok": false}
		testcase_assertion_count += assertion_count_value
		tests.append(test_record)
		if not captured_test.get("complete", false):
			all_tests_ran = false
	tests.sort_custom(_compare_gut_observation_test_records)

	var lifecycle_assertion_count: int = 0
	var lifecycle_names: Dictionary = {}
	var lifecycle_values: Array = raw_lifecycle_tests
	for raw_lifecycle_test: Variant in lifecycle_values:
		if not raw_lifecycle_test is Object:
			return {"ok": false}
		var lifecycle_test: Object = raw_lifecycle_test
		var lifecycle_name_result: Dictionary = _gut_observation_required_text(
			lifecycle_test.get("name"),
			false
		)
		if not lifecycle_name_result.get("ok", false):
			return {"ok": false}
		var lifecycle_name_value: Variant = lifecycle_name_result.get("value")
		if not lifecycle_name_value is String:
			return {"ok": false}
		var lifecycle_name: String = lifecycle_name_value
		if (
			lifecycle_name not in ["before_all", "after_all"]
			or lifecycle_names.has(lifecycle_name)
		):
			return {"ok": false}
		lifecycle_names[lifecycle_name] = true
		var lifecycle_count: int = _gut_observation_test_assertion_count(
			lifecycle_test
		)
		if lifecycle_count < 0:
			return {"ok": false}
		lifecycle_assertion_count += lifecycle_count

	var script_key_value: Variant = identity.get("key")
	var script_value: Variant = identity.get("script")
	var inner_class_value: Variant = identity.get("inner_class")
	var was_run_value: Variant = was_run_result.get("value")
	var was_skipped_value: Variant = was_skipped_result.get("value")
	if (
		not script_key_value is String
		or not script_value is String
		or not inner_class_value is String
		or not was_run_value is bool
		or not was_skipped_value is bool
	):
		return {"ok": false}
	var script_key: String = script_key_value
	var duration_usec: int = 0
	var timing_complete: bool = false
	if durations_usec.has(script_key):
		var duration_value: Variant = durations_usec.get(script_key)
		if not duration_value is int or duration_value < 0:
			return {"ok": false}
		duration_usec = duration_value
		timing_complete = not implicit_end_keys.has(script_key)

	var lifecycle_complete: bool = (
		lifecycle_names.size() == 2
		and lifecycle_names.has("before_all")
		and lifecycle_names.has("after_all")
	)
	var complete: bool = (
		was_run_value
		and not was_skipped_value
		and timing_complete
		and lifecycle_complete
		and all_tests_ran
	)
	return {
		"ok": true,
		"complete": complete,
		"record": {
			"script": script_value,
			"inner_class": inner_class_value,
			"was_run": was_run_value,
			"was_skipped": was_skipped_value,
			"duration_seconds": float(duration_usec) / 1_000_000.0,
			"assertion_count": (
				testcase_assertion_count + lifecycle_assertion_count
			),
			"lifecycle_assertion_count": lifecycle_assertion_count,
			"tests": tests,
		},
	}


static func _capture_gut_observation_test(raw_test: Variant) -> Dictionary:
	if not raw_test is Object:
		return {"ok": false}
	var test_object: Object = raw_test
	var name_result: Dictionary = _gut_observation_required_text(
		test_object.get("name"),
		false
	)
	var was_run_result: Dictionary = _gut_observation_required_bool(
		test_object.get("was_run")
	)
	var duration_result: Dictionary = _gut_observation_nonnegative_float(
		test_object.get("time_taken")
	)
	var status_result: Dictionary = _gut_observation_required_text(
		test_object.call(&"get_status_text"),
		false
	)
	var assertion_count: int = _gut_observation_test_assertion_count(
		test_object
	)
	if (
		not name_result.get("ok", false)
		or not was_run_result.get("ok", false)
		or not duration_result.get("ok", false)
		or not status_result.get("ok", false)
		or assertion_count < 0
	):
		return {"ok": false}

	var name_value: Variant = name_result.get("value")
	var was_run_value: Variant = was_run_result.get("value")
	var duration_value: Variant = duration_result.get("value")
	var status_value: Variant = status_result.get("value")
	if (
		not name_value is String
		or not was_run_value is bool
		or not duration_value is float
		or not status_value is String
	):
		return {"ok": false}
	var status: String = status_value
	return {
		"ok": true,
		"complete": (
			was_run_value
			and status != GutUtils.TEST_STATUSES.NOT_RUN
			and status != GutUtils.TEST_STATUSES.SKIPPED
		),
		"record": {
			"name": name_value,
			"was_run": was_run_value,
			"status": status,
			"assertion_count": assertion_count,
			"duration_seconds": duration_value,
		},
	}


static func _gut_observation_test_assertion_count(
	test_object: Object
) -> int:
	var raw_pass_texts: Variant = test_object.get("pass_texts")
	var raw_fail_texts: Variant = test_object.get("fail_texts")
	if not raw_pass_texts is Array or not raw_fail_texts is Array:
		return -1
	var pass_texts: Array = raw_pass_texts
	var fail_texts: Array = raw_fail_texts
	return pass_texts.size() + fail_texts.size()


static func _gut_observation_required_text(
	value: Variant,
	allow_empty: bool
) -> Dictionary:
	var text_value: String = ""
	if value is String:
		text_value = value
	elif value is StringName:
		var string_name_value: StringName = value
		text_value = String(string_name_value)
	else:
		return {"ok": false}
	if not allow_empty and text_value.is_empty():
		return {"ok": false}
	for character_index: int in range(text_value.length()):
		if text_value.unicode_at(character_index) < 32:
			return {"ok": false}
	return {
		"ok": true,
		"value": text_value,
	}


static func _gut_observation_required_bool(value: Variant) -> Dictionary:
	if not value is bool:
		return {"ok": false}
	return {
		"ok": true,
		"value": value,
	}


static func _gut_observation_nonnegative_float(value: Variant) -> Dictionary:
	var number: float = 0.0
	if value is float:
		number = value
	elif value is int:
		var integer_value: int = value
		number = float(integer_value)
	else:
		return {"ok": false}
	if not is_finite(number) or number < 0.0:
		return {"ok": false}
	return {
		"ok": true,
		"value": number,
	}


static func _gut_observation_filter_is_empty(value: Variant) -> bool:
	if value == null:
		return true
	if value is String:
		var string_value: String = value
		return string_value.is_empty()
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value.is_empty()
	return false


static func _gut_observation_junit_configuration_is_valid(
	gut_main: GutMain
) -> bool:
	var timestamp_value: Variant = gut_main.get("junit_xml_timestamp")
	if not timestamp_value is bool or timestamp_value:
		return false
	var junit_path_result: Dictionary = _gut_observation_required_text(
		gut_main.get("junit_xml_file"),
		false
	)
	if not junit_path_result.get("ok", false):
		return false
	var junit_path_value: Variant = junit_path_result.get("value")
	if not junit_path_value is String:
		return false
	var junit_path: String = junit_path_value
	var expected_absolute: String = ProjectSettings.globalize_path(
		_expected_gut_observation_junit_path(_gut_observation_nonce)
	)
	var actual_absolute: String = ProjectSettings.globalize_path(junit_path)
	return (
		_normalized_gut_observation_path(actual_absolute)
		== _normalized_gut_observation_path(expected_absolute)
	)


static func _normalized_gut_observation_path(value: String) -> String:
	var normalized: String = value.replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		normalized = normalized.to_lower()
	return normalized


static func _compare_gut_observation_script_records(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_script: String = _dictionary_string(left, "script")
	var right_script: String = _dictionary_string(right, "script")
	if left_script != right_script:
		return left_script < right_script
	return (
		_dictionary_string(left, "inner_class")
		< _dictionary_string(right, "inner_class")
	)


static func _compare_gut_observation_test_records(
	left: Dictionary,
	right: Dictionary
) -> bool:
	return _dictionary_string(left, "name") < _dictionary_string(right, "name")


static func _read_gut_observation_junit(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length: int = file.get_length()
	if length <= 0 or length > MAX_GUT_OBSERVATION_JUNIT_BYTES:
		file.close()
		return PackedByteArray()
	var data: PackedByteArray = file.get_buffer(length)
	file.close()
	if data.size() != length:
		return PackedByteArray()
	return data


static func _gut_observation_sha256_bytes(data: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(data)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func _write_gut_observation_sidecar(
	path: String,
	json_text: String
) -> bool:
	var directory_path: String = path.get_base_dir()
	var absolute_directory: String = ProjectSettings.globalize_path(directory_path)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		return false
	var temporary_path: String = path + ".tmp"
	if FileAccess.file_exists(path) or FileAccess.file_exists(temporary_path):
		return false

	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(json_text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if not stored or write_error != OK:
		var failed_temporary_absolute: String = ProjectSettings.globalize_path(
			temporary_path
		)
		if FileAccess.file_exists(temporary_path):
			var _remove_failed_temporary_result: Error = (
				DirAccess.remove_absolute(failed_temporary_absolute)
			)
		return false

	var temporary_absolute: String = ProjectSettings.globalize_path(
		temporary_path
	)
	var final_absolute: String = ProjectSettings.globalize_path(path)
	var rename_error: Error = DirAccess.rename_absolute(
		temporary_absolute,
		final_absolute
	)
	if rename_error != OK:
		if FileAccess.file_exists(temporary_path):
			var _remove_temporary_result: Error = DirAccess.remove_absolute(
				temporary_absolute
			)
		return false
	return true


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
