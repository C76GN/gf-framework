# GFAsyncCall: 内核内部的显式分离调用辅助。
# [br]
# @api framework_internal
# [br]
# @layer kernel/core
extends RefCounted

# --- 公共方法 ---

## 启动 Callable，并明确丢弃其返回值。
## 该辅助只分离返回值，不创建线程，也不能抢占 callback 在首个 await
## 前执行的同步代码；需要超时或取消语义的调用方必须在任务内部拆分检查点。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param callback: 要启动的 Callable，可为同步或异步入口。
## [br]
## @param arguments: 传给 callback 的参数列表。
## [br]
## @schema arguments: Callable 参数数组。
static func run_detached(callback: Callable, arguments: Array = []) -> void:
	if not callback.is_valid():
		return
	var _ignored_call_result: Variant = callback.callv(arguments)
