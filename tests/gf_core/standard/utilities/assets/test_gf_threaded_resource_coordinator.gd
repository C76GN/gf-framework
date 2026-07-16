## 测试 threaded ResourceLoader operation/coordinator 的取消、drain 与复用语义。
extends GutTest


# --- 常量 ---

const _THREADED_RESOURCE_COORDINATOR_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_coordinator.gd")
const _THREADED_RESOURCE_OPERATION_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_operation.gd")


# --- 私有变量 ---

var _coordinator: _THREADED_RESOURCE_COORDINATOR_SCRIPT = null
var _request_count: int = 0
var _poll_status: StringName = &"in_progress"
var _poll_progress: float = 0.0
var _fake_resource: Resource = null


# --- 测试生命周期方法 ---

func before_each() -> void:
	_coordinator = _THREADED_RESOURCE_COORDINATOR_SCRIPT.new()
	_coordinator.configure(
		Callable(self, "_request_resource"),
		Callable(self, "_poll_resource")
	)
	_request_count = 0
	_poll_status = &"in_progress"
	_poll_progress = 0.0
	_fake_resource = null


func after_each() -> void:
	_coordinator = null
	_fake_resource = null


# --- 测试用例 ---

func test_cancelled_operation_drains_late_loaded_resource_as_suppressed() -> void:
	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _coordinator.request("res://late.tres", "Resource")

	_coordinator.cancel_operation(operation, &"owner_cancelled")
	_poll_status = &"loaded"
	_fake_resource = Resource.new()

	var drained_count: int = _coordinator.drain_cancelled_operations()
	var snapshot: Dictionary = _coordinator.get_debug_snapshot()

	assert_eq(drained_count, 1, "取消后的请求迟到完成时应被 drain。")
	assert_eq(operation.get_status(), _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_SUPPRESSED, "取消后的迟到结果应进入 suppressed 终态。")
	assert_null(operation.get_resource(), "suppressed 终态不应继续持有加载资源。")
	assert_eq(GFVariantData.get_option_int(snapshot, "operation_count"), 0, "drain 后 coordinator 不应保留终态 operation。")


func test_cancelled_operation_can_be_reused_before_terminal_poll() -> void:
	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _coordinator.request("res://retry.tres", "Resource")
	_coordinator.cancel_operation(operation, &"owner_cancelled")

	var reused_operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _coordinator.request("res://retry.tres", "Resource")
	_poll_status = &"loaded"
	_fake_resource = Resource.new()
	var poll_result: Dictionary = _coordinator.poll_operation(reused_operation)

	assert_eq(_request_count, 1, "取消后重试应复用仍在进行的底层请求。")
	assert_same(reused_operation, operation, "重试应复用同一个 operation。")
	assert_eq(GFVariantData.get_option_string_name(poll_result, "status"), _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_COMPLETED, "复用后的完成结果应可交付。")
	var completed_resource_value: Variant = GFVariantData.get_option_value(poll_result, "resource")
	var is_completed_resource_same: bool = completed_resource_value == _fake_resource
	assert_true(is_completed_resource_same, "完成结果应保留加载资源。")


# --- 私有/辅助方法 ---

func _request_resource(_path: String, _type_hint: String) -> Error:
	_request_count += 1
	return OK


func _poll_resource(_path: String, previous_progress: float) -> Dictionary:
	var progress: float = _poll_progress
	if _poll_status == &"in_progress":
		progress = maxf(previous_progress, _poll_progress)
	return {
		"status": _poll_status,
		"progress": progress,
		"resource": _fake_resource,
		"has_resource": _fake_resource != null,
		"error": "" if _poll_status == &"loaded" or _poll_status == &"in_progress" else "failed",
	}
