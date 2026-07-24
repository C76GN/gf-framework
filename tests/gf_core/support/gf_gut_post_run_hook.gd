# Commits the tracked-test terminal snapshot to the process lifecycle state.
extends GutHookScript


# --- 常量 ---

const GF_GUT_LIFECYCLE_STATE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_state.gd"
)
const EXIT_FAILURE: int = 1
const SETTLE_FRAME_COUNT: int = 3


# --- 可重写钩子 / 虚方法 ---

func run() -> void:
	if not gut is GutMain:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_instance_unavailable"
		)
		set_exit_code(EXIT_FAILURE)
		return

	var gut_main: GutMain = gut
	for _frame_index: int in range(SETTLE_FRAME_COUNT):
		await gut_main.get_tree().process_frame

	# Switch the raw logger first so warnings racing the tracker snapshot fail closed.
	GF_GUT_LIFECYCLE_STATE_SCRIPT.begin_terminal_capture()
	var warning_snapshot: Dictionary = _collect_unhandled_warnings(gut_main)
	var tracked_warnings: Array[Dictionary] = _dictionary_array(
		warning_snapshot,
		"warnings"
	)
	var tracker_available: bool = _dictionary_bool(warning_snapshot, "ok")
	var orphan_snapshot: Dictionary = (
		GF_GUT_LIFECYCLE_STATE_SCRIPT.snapshot_new_orphans()
	)
	var snapshot_clean: bool = (
		GF_GUT_LIFECYCLE_STATE_SCRIPT.commit_post_snapshot(
			tracked_warnings,
			tracker_available,
			orphan_snapshot
		)
	)
	if not snapshot_clean:
		set_exit_code(EXIT_FAILURE)


# --- 私有/辅助方法 ---

func _collect_unhandled_warnings(gut_main: GutMain) -> Dictionary:
	var warning_details: Array[Dictionary] = []
	var raw_tracker: Variant = gut_main.get("error_tracker")
	if not raw_tracker is GutErrorTracker:
		return {
			"ok": false,
			"warnings": warning_details,
		}

	var error_tracker: GutErrorTracker = raw_tracker
	var tracker_disabled_value: Variant = error_tracker.get("disabled")
	if not tracker_disabled_value is bool:
		return {
			"ok": false,
			"warnings": warning_details,
		}
	var tracker_disabled: bool = tracker_disabled_value
	if tracker_disabled or not GutErrorTracker.register_loggers:
		return {
			"ok": false,
			"warnings": warning_details,
		}
	if not GutErrorTracker.registered_loggers.has(error_tracker):
		return {
			"ok": false,
			"warnings": warning_details,
		}

	var raw_mutex: Variant = error_tracker.get("_mutex")
	if not raw_mutex is Mutex:
		return {
			"ok": false,
			"warnings": warning_details,
		}

	var tracker_mutex: Mutex = raw_mutex
	tracker_mutex.lock()
	var snapshot_valid: bool = _copy_warning_snapshot_locked(
		error_tracker,
		warning_details
	)
	tracker_mutex.unlock()
	return {
		"ok": snapshot_valid,
		"warnings": warning_details,
	}


func _copy_warning_snapshot_locked(
	error_tracker: GutErrorTracker,
	warning_details: Array[Dictionary]
) -> bool:
	var raw_error_groups: Variant = error_tracker.get("errors")
	if not raw_error_groups is Object:
		return false

	var error_groups: Object = raw_error_groups
	var raw_items: Variant = error_groups.get("items")
	if not raw_items is Dictionary:
		return false

	var grouped_errors: Dictionary = raw_items
	for test_id_value: Variant in grouped_errors:
		var raw_errors: Variant = grouped_errors.get(test_id_value)
		if not raw_errors is Array:
			return false

		var tracked_errors: Array = raw_errors
		for raw_error: Variant in tracked_errors:
			if not raw_error is GutTrackedError:
				return false

			var tracked_error: GutTrackedError = raw_error
			var handled_value: Variant = tracked_error.get("handled")
			if not handled_value is bool:
				return false
			var handled: bool = handled_value
			if tracked_error.is_push_warning() and not handled:
				warning_details.append(
					_warning_detail(test_id_value, tracked_error)
				)
	return true


func _warning_detail(
	test_id_value: Variant,
	tracked_error: GutTrackedError
) -> Dictionary:
	return {
		"test_id": _variant_to_text(test_id_value),
		"code": _variant_to_text(tracked_error.get("code")),
		"file": _variant_to_text(tracked_error.get("file")),
		"line": _variant_to_int(tracked_error.get("line")),
	}


func _dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_value: Variant = source.get(key)
	if not raw_value is Array:
		return result
	var values: Array = raw_value
	for raw_entry: Variant in values:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			result.append(entry)
	return result


func _dictionary_bool(source: Dictionary, key: String) -> bool:
	var raw_value: Variant = source.get(key, false)
	return raw_value if raw_value is bool else false


func _variant_to_int(value: Variant) -> int:
	return value if value is int else 0


func _variant_to_text(value: Variant) -> String:
	if value is String:
		return value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return str(value)
