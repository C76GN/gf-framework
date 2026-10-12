# 项目服务示例：有界接纳、显式取消和可排空的异步工作。
extends GFUtility


# --- 公共变量 ---

## 演示延迟；实际项目可以在这里接入自己的异步后端。
var delay_seconds: float = 0.35

## 同时接纳工作的上限，避免按钮连点形成无界积压。
var capacity: int = 4


# --- 私有变量 ---

var _jobs: Dictionary[GFAsyncCompletion, float] = {}
var _drain: GFAsyncCompletion = null
var _disposed: bool = false


# --- GF 生命周期方法 ---

func tick(delta: float) -> void:
	for completion: GFAsyncCompletion in _jobs.keys():
		if not completion.is_pending():
			var _cancelled_removed: bool = _jobs.erase(completion)
			continue
		_jobs[completion] -= maxf(delta, 0.0)
		if _jobs[completion] <= 0.0:
			var _finished_removed: bool = _jobs.erase(completion)
			var _finished: bool = completion.succeed(1)
	if _jobs.is_empty() and _drain != null and _drain.is_pending():
		var _drained: bool = _drain.succeed()


func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
	if _drain == null:
		_drain = GFAsyncCompletion.new()
		if _jobs.is_empty():
			var _drained: bool = _drain.succeed()
	return _drain


func dispose() -> void:
	_disposed = true
	var pending: Array[GFAsyncCompletion] = _jobs.keys()
	_jobs.clear()
	for completion: GFAsyncCompletion in pending:
		if completion.is_pending():
			var _cancelled: bool = completion.cancel(&"session_disposed")
	if _drain != null and _drain.is_pending():
		var _cancelled_drain: bool = _drain.cancel(&"session_disposed")


# --- 公共方法 ---

## 请求一次加分；拒绝、取消、成功均使用同一完成结果。
func request_increment() -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if _disposed or _drain != null:
		var _closed: bool = completion.fail("服务已停止接纳工作。")
	elif _jobs.size() >= capacity:
		var _full: bool = completion.fail("工作队列已满，请等待现有工作完成。")
	else:
		_jobs[completion] = delay_seconds
	return completion
