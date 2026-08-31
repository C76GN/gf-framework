## GFBackgroundWorkTask: 后台工作记录。
##
## 保存后台工作状态、进度、输入数据、结果、错误文本和应用回调。
## 任务本身不直接启动线程；执行由 GFBackgroundWorkUtility 统一协调。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFBackgroundWorkTask
extends RefCounted


# --- 枚举 ---

## 后台工作类型。
## [br]
## @api public
enum Kind {
	## CPU 计算型线程任务。
	CPU,
	## IO 型线程任务。
	IO,
	## ResourceLoader 线程资源加载任务。
	RESOURCE,
}

## 后台工作生命周期状态。
## [br]
## @api public
enum Status {
	## 已入队，等待启动。
	QUEUED,
	## 正在后台运行或等待资源加载。
	RUNNING,
	## 正在等待主线程应用回调。
	APPLYING,
	## 已成功完成。
	COMPLETED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
}


# --- 公共变量 ---

## 工作 ID。
## [br]
## @api public
var work_id: StringName = &""

## 工作类型。
## [br]
## @api public
var kind: Kind = Kind.CPU

## 当前状态。
## [br]
## @api public
var status: Status = Status.QUEUED

## 优先级，数值越大越早从等待队列启动。
## [br]
## @api public
var priority: int = 0

## 工作输入数据。默认应只包含纯 Variant 数据。
## [br]
## @api public
## [br]
## @schema input_data: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
var input_data: Variant = null

## 工作结果。线程任务返回值或资源加载结果会写入该字段。
## [br]
## @api public
## [br]
## @schema result: Variant，工作线程结果、资源加载结果或失败载荷。
var result: Variant = null

## 主线程应用回调的返回值。
## [br]
## @api public
## [br]
## @schema apply_result: Variant，由可选主线程 apply 回调返回。
var apply_result: Variant = null

## 错误文本。
## [br]
## @api public
var error_message: String = ""

## 进度，范围建议为 0.0 到 1.0。
## [br]
## @api public
var progress: float = 0.0

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，复制到后台任务中的项目侧元数据。
var metadata: Dictionary = {}

## 资源加载路径，仅 RESOURCE 任务使用。
## [br]
## @api public
var resource_path: String = ""

## 资源类型提示，仅 RESOURCE 任务使用。
## [br]
## @api public
var resource_type_hint: String = ""

## 是否已请求取消。正在执行的线程任务不会被强行终止。
## 显式接收 GFBackgroundWorkContext 的 worker 可协作退出；其余 worker 返回后转入取消终态。
## [br]
## @api public
## [br]
## @since 3.17.0
var cancel_requested: bool = false

## 创建时间。
## [br]
## @api public
var created_msec: int = 0

## 开始时间。
## [br]
## @api public
var started_msec: int = 0

## 结束时间。
## [br]
## @api public
var finished_msec: int = 0


# --- 私有变量 ---

var _worker_callback: Callable = Callable()
var _apply_callback: Callable = Callable()
var _worker_callback_target: RefCounted = null
var _apply_callback_target: RefCounted = null
var _cancellation_context: GFBackgroundWorkContext = null
var _worker_receives_cancellation_context: bool = false


# --- 公共方法 ---

## 当前工作是否已经进入终态。
## [br]
## @api public
## [br]
## @return 已完成、失败或取消时返回 true。
func is_finished() -> bool:
	return status == Status.COMPLETED or status == Status.FAILED or status == Status.CANCELLED


## 获取框架拥有的只读协作取消上下文。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已接纳 CPU/IO 工作的取消上下文；提交被拒绝或 RESOURCE 工作返回 null。
func get_cancellation_context() -> GFBackgroundWorkContext:
	return _cancellation_context


## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return 工作字典。
## [br]
## @schema return: Dictionary，包含 work_id、kind、kind_name、status、status_name、priority、progress、error_message、metadata、资源字段、cancel_requested、时间戳和结果标记。
func to_dict() -> Dictionary:
	return {
		"work_id": String(work_id),
		"kind": kind,
		"kind_name": kind_name(kind),
		"status": status,
		"status_name": status_name(status),
		"priority": priority,
		"progress": progress,
		"error_message": error_message,
		"metadata": metadata.duplicate(true),
		"resource_path": resource_path,
		"resource_type_hint": resource_type_hint,
		"cancel_requested": cancel_requested,
		"created_msec": created_msec,
		"started_msec": started_msec,
		"finished_msec": finished_msec,
		"has_result": result != null,
		"has_apply_result": apply_result != null,
	}


## 获取工作类型名称。
## [br]
## @api public
## [br]
## @param value: 工作类型枚举值。
## [br]
## @return 工作类型名称。
static func kind_name(value: Kind) -> String:
	match value:
		Kind.CPU:
			return "cpu"
		Kind.IO:
			return "io"
		Kind.RESOURCE:
			return "resource"
	return "unknown"


## 获取状态名称。
## [br]
## @api public
## [br]
## @param value: 状态枚举值。
## [br]
## @return 状态名称。
static func status_name(value: Status) -> String:
	match value:
		Status.QUEUED:
			return "queued"
		Status.RUNNING:
			return "running"
		Status.APPLYING:
			return "applying"
		Status.COMPLETED:
			return "completed"
		Status.FAILED:
			return "failed"
		Status.CANCELLED:
			return "cancelled"
	return "unknown"


# --- 框架内部方法 ---

## 设置后台工作回调。
## [br]
## @api framework_internal
## [br]
## @param worker_callback: 后台线程或加载任务完成前执行的回调。
## [br]
## @param apply_callback: 主线程应用阶段回调。
func set_internal_callbacks(worker_callback: Callable, apply_callback: Callable) -> void:
	# Callable 不会替 RefCounted target 持有引用；先捕获新 target，避免替换时出现零引用窗口。
	var worker_target: RefCounted = _get_ref_counted_callback_target(worker_callback)
	var apply_target: RefCounted = _get_ref_counted_callback_target(apply_callback)
	_worker_callback = worker_callback
	_apply_callback = apply_callback
	_worker_callback_target = worker_target
	_apply_callback_target = apply_target


## 获取后台工作回调。
## [br]
## @api framework_internal
## [br]
## @return 后台线程回调。
func get_worker_callback() -> Callable:
	return _worker_callback


## 获取主线程应用回调。
## [br]
## @api framework_internal
## [br]
## @return 主线程应用回调。
func get_apply_callback() -> Callable:
	return _apply_callback


## 设置框架拥有的协作取消上下文和 worker 调用形状。
## [br]
## @api framework_internal
## [br]
## @param context: CPU/IO 工作独占的取消上下文。
## [br]
## @param worker_receives_context: worker 是否接收 context 作为第二个参数。
func set_cancellation_context_for_framework(
	context: GFBackgroundWorkContext,
	worker_receives_context: bool
) -> void:
	_cancellation_context = context
	_worker_receives_cancellation_context = worker_receives_context


## 返回 worker 是否接收协作取消上下文。
## [br]
## @api framework_internal
## [br]
## @return 启用双参数 worker 契约时返回 true。
func worker_receives_cancellation_context_for_framework() -> bool:
	return _worker_receives_cancellation_context


# --- 私有/辅助方法 ---

func _get_ref_counted_callback_target(callback: Callable) -> RefCounted:
	if not callback.is_valid():
		return null
	var callback_target: Object = callback.get_object()
	if callback_target is RefCounted:
		var retained_target: RefCounted = callback_target
		return retained_target
	return null
