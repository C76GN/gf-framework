## GFJob: 通用异步/分帧任务记录。
##
## 只保存任务状态、进度、输入数据、结果和错误文本，不绑定具体业务。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFJob
extends RefCounted


# --- 枚举 ---

## 任务生命周期状态。
## [br]
## @api public
enum Status {
	## 已入队，尚未开始执行。
	WAITING,
	## 正在执行。
	ACTIVE,
	## 已成功完成。
	COMPLETED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
}


# --- 公共变量 ---

## 任务 ID。
## [br]
## @api public
var job_id: StringName = &""

## 队列名。
## [br]
## @api public
var queue_name: StringName = &"default"

## 当前状态。
## [br]
## @api public
var status: Status = Status.WAITING

## 任务输入数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema data: Variant，项目侧任务输入载荷。
var data: Variant = null

## 任务结果。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema result: Variant，项目侧任务结果载荷。
var result: Variant = null

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
## @schema metadata: Dictionary，复制到任务中的项目侧元数据。
var metadata: Dictionary = {}

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


# --- 公共方法 ---

## 当前任务是否已经进入终态。
## [br]
## @api public
## [br]
## @return 已完成、失败或取消时返回 true。
func is_finished() -> bool:
	return (
		status == Status.COMPLETED
		or status == Status.FAILED
		or status == Status.CANCELLED
	)


## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return 任务字典。
## [br]
## @schema return: Dictionary，包含 job_id、queue_name、status、status_name、progress、error_message、metadata、时间戳和 has_result。
func to_dict() -> Dictionary:
	return {
		"job_id": String(job_id),
		"queue_name": String(queue_name),
		"status": status,
		"status_name": status_name(status),
		"progress": progress,
		"error_message": error_message,
		"metadata": metadata.duplicate(true),
		"created_msec": created_msec,
		"started_msec": started_msec,
		"finished_msec": finished_msec,
		"has_result": result != null,
	}


## 获取状态名称。
## [br]
## @api public
## [br]
## @param value: 状态枚举值。
## [br]
## @return 状态名称。
static func status_name(value: Status) -> String:
	match value:
		Status.WAITING:
			return "waiting"
		Status.ACTIVE:
			return "active"
		Status.COMPLETED:
			return "completed"
		Status.FAILED:
			return "failed"
		Status.CANCELLED:
			return "cancelled"
	return "unknown"
