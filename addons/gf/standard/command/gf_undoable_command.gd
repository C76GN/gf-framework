## GFUndoableCommand: 可撤销命令的抽象基类。
##
## 继承自 GFCommand，在标准命令的基础上新增撤销能力。
## 子类须在 execute() 执行前通过 set_snapshot() 保存当前状态快照，
## 并在 undo() 中借助 get_snapshot() 取回快照以还原数据，
## 从而支持编辑器操作、运行时流程回放和项目自定义撤销功能。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFUndoableCommand
extends GFCommand

# --- 公共变量 ---

## 可选命令标签，供项目历史面板、日志或调试工具显示。默认为空，框架不生成用户可见文案。
## [br]
## @api public
var action_name: String = ""


# --- 私有变量 ---

# 执行前保存的状态快照，用于 undo() 时还原。
var _snapshot: Variant = null


# --- 公共方法 ---

## 执行命令逻辑。子类必须重写此方法，并建议在此处先调用 set_snapshot()。
## [br]
## @api public
## [br]
## @return 同步命令返回 null；异步命令可返回 Signal 供外部 await。
## [br]
## @schema return: Variant, null or Signal.
func execute() -> Variant:
	return null


## 撤销命令。子类必须重写此方法，使用 get_snapshot() 还原状态。
## [br]
## @api public
## [br]
## @return 同步命令返回 null；异步命令可返回 Signal 供外部 await。
## [br]
## @schema return: Variant, null or Signal.
func undo() -> Variant:
	return null


## 判断 execute() 返回后是否应该写入命令历史。
## [br]
## @api public
## [br]
## @param _execute_result: execute() 的最终返回值。
## [br]
## @return 返回 false 时，GFCommandHistoryUtility 不会记录该命令。
## [br]
## @schema _execute_result: Variant returned by execute().
func should_record(_execute_result: Variant) -> bool:
	return true


## 保存执行前的状态快照。应在 execute() 内部、修改数据之前调用。
## [br]
## @api public
## [br]
## @param data: 任意可序列化的快照数据（如字典、数值、数组）。
## [br]
## @schema data: Variant snapshot value; Array and Dictionary values are deep-copied.
func set_snapshot(data: Variant) -> void:
	_snapshot = GFVariantData.duplicate_collection(data, true)


## 获取由 set_snapshot() 保存的状态快照。在 undo() 中调用以还原数据。
## [br]
## @api public
## [br]
## @return 之前保存的快照数据，不存在则返回 null。
## [br]
## @schema return: Variant snapshot value or null.
func get_snapshot() -> Variant:
	return GFVariantData.duplicate_collection(_snapshot, true)
