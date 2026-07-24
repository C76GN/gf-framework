# Enforces process-wide test lifecycle invariants after GUT has settled queued frees.
extends GutHookScript


# --- 常量 ---

const ORPHAN_BASELINE_META_KEY: StringName = &"_gf_test_orphan_baseline"
const SENTINEL_PREFIX: String = "GF_TEST_LIFECYCLE_GATE="
const REPORT_SCHEMA_VERSION: int = 1
const EXIT_FAILURE: int = 1
const MAX_DETAIL_COUNT: int = 20
const SETTLE_FRAME_COUNT: int = 3


# --- 可重写钩子 / 虚方法 ---

func run() -> void:
	var report: Dictionary = _make_empty_report()
	if not gut is GutMain:
		report["ok"] = false
		report["configuration_error"] = "gut_instance_unavailable"
		_emit_report(report)
		set_exit_code(EXIT_FAILURE)
		return

	var gut_main: GutMain = gut
	for _frame_index: int in range(SETTLE_FRAME_COUNT):
		await gut_main.get_tree().process_frame

	var baseline_result: Dictionary = _read_orphan_baseline(gut_main)
	var baseline_available: bool = _dictionary_bool(baseline_result, "ok")
	report["baseline_available"] = baseline_available
	if not baseline_available:
		report["configuration_error"] = "orphan_baseline_unavailable"

	var warning_result: Dictionary = _collect_unhandled_warnings(gut_main)
	var warning_tracking_available: bool = _dictionary_bool(warning_result, "ok")
	report["warning_tracking_available"] = warning_tracking_available
	if not warning_tracking_available:
		report["configuration_error"] = "warning_tracker_unavailable"

	var unhandled_warnings: Array[Dictionary] = []
	var raw_warnings: Variant = warning_result.get("warnings")
	if raw_warnings is Array:
		var warning_values: Array = raw_warnings
		for raw_warning: Variant in warning_values:
			if raw_warning is Dictionary:
				var warning_detail: Dictionary = raw_warning
				unhandled_warnings.append(warning_detail)

	var new_orphans: Array[Dictionary] = []
	if baseline_available:
		var raw_baseline_ids: Variant = baseline_result.get("orphan_ids")
		if raw_baseline_ids is Dictionary:
			var baseline_ids: Dictionary = raw_baseline_ids
			new_orphans = _collect_new_orphans(baseline_ids)
		else:
			baseline_available = false
			report["baseline_available"] = false
			report["configuration_error"] = "orphan_baseline_invalid"

	report["unhandled_warning_count"] = unhandled_warnings.size()
	report["orphan_count"] = new_orphans.size()
	report["warnings"] = unhandled_warnings.slice(0, MAX_DETAIL_COUNT)
	report["orphans"] = new_orphans.slice(0, MAX_DETAIL_COUNT)
	report["details_truncated"] = (
		unhandled_warnings.size() > MAX_DETAIL_COUNT
		or new_orphans.size() > MAX_DETAIL_COUNT
	)
	report["ok"] = (
		baseline_available
		and warning_tracking_available
		and unhandled_warnings.is_empty()
		and new_orphans.is_empty()
	)

	_emit_report(report)
	if not _dictionary_bool(report, "ok"):
		set_exit_code(EXIT_FAILURE)


# --- 私有/辅助方法 ---

func _make_empty_report() -> Dictionary:
	return {
		"schema_version": REPORT_SCHEMA_VERSION,
		"ok": true,
		"baseline_available": false,
		"warning_tracking_available": false,
		"unhandled_warning_count": 0,
		"orphan_count": 0,
		"warnings": [],
		"orphans": [],
		"details_truncated": false,
		"configuration_error": "",
	}


func _read_orphan_baseline(gut_main: GutMain) -> Dictionary:
	if not gut_main.has_meta(ORPHAN_BASELINE_META_KEY):
		return {
			"ok": false,
			"orphan_ids": {},
		}

	var raw_baseline: Variant = gut_main.get_meta(ORPHAN_BASELINE_META_KEY)
	gut_main.remove_meta(ORPHAN_BASELINE_META_KEY)
	if not raw_baseline is Dictionary:
		return {
			"ok": false,
			"orphan_ids": {},
		}

	var baseline_ids: Dictionary = raw_baseline
	return {
		"ok": true,
		"orphan_ids": baseline_ids,
	}


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

	var raw_error_groups: Variant = error_tracker.get("errors")
	if not raw_error_groups is Object:
		return {
			"ok": false,
			"warnings": warning_details,
		}

	var error_groups: Object = raw_error_groups
	var raw_items: Variant = error_groups.get("items")
	if not raw_items is Dictionary:
		return {
			"ok": false,
			"warnings": warning_details,
		}

	var grouped_errors: Dictionary = raw_items
	for test_id_value: Variant in grouped_errors:
		var raw_errors: Variant = grouped_errors.get(test_id_value)
		if not raw_errors is Array:
			return {
				"ok": false,
				"warnings": warning_details,
			}

		var tracked_errors: Array = raw_errors
		for raw_error: Variant in tracked_errors:
			if not raw_error is GutTrackedError:
				return {
					"ok": false,
					"warnings": warning_details,
				}

			var tracked_error: GutTrackedError = raw_error
			var handled_value: Variant = tracked_error.get("handled")
			if not handled_value is bool:
				return {
					"ok": false,
					"warnings": warning_details,
				}
			var handled: bool = handled_value
			if tracked_error.is_push_warning() and not handled:
				warning_details.append(_warning_detail(test_id_value, tracked_error))

	return {
		"ok": true,
		"warnings": warning_details,
	}


func _warning_detail(test_id_value: Variant, tracked_error: GutTrackedError) -> Dictionary:
	return {
		"test_id": _variant_to_text(test_id_value),
		"code": _variant_to_text(tracked_error.get("code")),
		"file": _variant_to_text(tracked_error.get("file")),
		"line": _variant_to_int(tracked_error.get("line")),
	}


func _collect_new_orphans(baseline_ids: Dictionary) -> Array[Dictionary]:
	var orphan_details: Array[Dictionary] = []
	for orphan_id: int in Node.get_orphan_node_ids():
		if baseline_ids.has(orphan_id):
			continue
		orphan_details.append(_orphan_detail(orphan_id))
	return orphan_details


func _orphan_detail(orphan_id: int) -> Dictionary:
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
	detail["class"] = orphan_node.get_class()
	detail["name"] = String(orphan_node.name)
	return detail


func _emit_report(report: Dictionary) -> void:
	print(SENTINEL_PREFIX + JSON.stringify(report))


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
