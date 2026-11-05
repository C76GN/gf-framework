# 命令历史与撤销重做

`GFCommandHistoryUtility` 用于管理命令执行历史、撤销、重做、序列化、恢复和异步操作约束。

当你使用 `GFCommand` 编码操作指令时，可以接入 GF Framework 提供的基于 `GFUndoableCommand` 的撤销重做栈扩展体系。基本接入步骤是：让命令继承 `GFUndoableCommand`，使用 `GFCommandHistoryUtility.execute_command(cmd)` 统一执行，再通过历史工具统一撤销和重做。

## 执行与记录

`await history.execute_command(command)` 负责调用 `execute()`，完成后根据 `should_record(result)` 决定是否压栈。`history.record(command)` 只记录一条**已经执行完成**的命令，不执行命令，也不替调用方检查执行结果或 `should_record()`。

二者应按提交方式择一使用：让历史工具执行时，不要先修改模型或调用 `command.execute()`，也不要随后再次 `record()`；由其他入口执行完成后补记历史时，调用方先确认成功，再调用一次 `record()`。重复应用可能重复发出事件、扣除资源或覆盖撤销所需的初值。

## 一次用户操作，一条撤销记录

拖拽、笔画或连续调整滑块会产生多次预览，但通常只应撤销一次。项目可以在开始时记住最初值，将预览留在编辑会话中；确认时用最初值和最终值创建一个命令，取消时丢弃草稿。最终值回到最初值时不提交命令，已有重做分支也应保留。

下面是完整的位置编辑示例，可保存为 `res://position_edit_session.gd`。模型通过信号通知正式变更；预览视图读取 `get_preview_position()`，不把预览反写到模型。命令保存固定的两个端点，重做时不会重新捕获初值。

```gdscript
# 项目侧位置编辑会话：预览不写模型，确认后只提交一个命令。
# 调用方在同一文档生命周期持有模型与历史，编辑期间排除其他写入和撤销入口。
extends RefCounted


# --- 私有变量 ---

## 由文档持有的正式模型；本会话只在确认命令中修改它。
var _model: PositionModel

## 由文档持有并负责关闭的历史工具，不由会话独立 dispose。
var _history: GFCommandHistoryUtility

## 当前编辑开始时固定的端点，撤销始终恢复此值。
var _initial_position: Vector2 = Vector2.ZERO

## 仅供预览视图读取的草稿位置，取消时无需补偿模型。
var _preview_position: Vector2 = Vector2.ZERO

## 标记是否接受当前编辑输入，结束后重复确认或取消均返回 false。
var _editing: bool = false


# --- Godot 生命周期方法 ---

## 接收同一文档中的模型和历史；调用方保证编辑期间模型的写入独占。
func _init(model: PositionModel, history: GFCommandHistoryUtility) -> void:
	_model = model
	_history = history


# --- 公共方法 ---

## 开启一轮编辑并固定原始位置；已有活跃编辑时不覆盖撤销端点。
func begin_edit() -> bool:
	if _editing:
		return false
	_initial_position = _model.position
	_preview_position = _initial_position
	_editing = true
	return true


## 仅更新草稿，不触发正式模型变化或新增历史记录。
func update_preview(position: Vector2) -> bool:
	if not _editing:
		return false
	_preview_position = position
	return true


## 编辑中返回草稿，结束后回到正式模型值，供视图统一读取。
func get_preview_position() -> Vector2:
	return _preview_position if _editing else _model.position


## 有净变化时让历史工具执行一次命令；无变化不破坏已有重做分支。
func confirm_edit() -> bool:
	if not _editing:
		return false
	_editing = false
	if _preview_position == _initial_position:
		return false
	var command: MovePositionCommand = MovePositionCommand.new(
		_model, _initial_position, _preview_position
	)
	# 由历史工具执行并记录，不能先写模型再让命令重复应用相同变更。
	var result: Variant = await _history.execute_command(command)
	return GFVariantData.to_bool(result, false)


## 丢弃活跃草稿；预览未写模型，因此不执行撤销或补偿写入。
func cancel_edit() -> bool:
	if not _editing:
		return false
	_editing = false
	return true


# --- 内部类 ---

## 正式位置数据；每次命令写入由信号通知表现层。
class PositionModel:
	extends RefCounted

	## 正式位置已写入时发出，不用于编辑中的草稿预览。
	signal position_changed(position: Vector2)

	## 文档中的已提交位置，预览阶段保持不变。
	var position: Vector2 = Vector2.ZERO:
		set(value):
			position = value
			position_changed.emit(value)


## 保存固定两个端点，使 execute、undo 和 redo 不依赖当前预览状态。
class MovePositionCommand:
	extends GFUndoableCommand

	## 借用同一文档模型，历史存活期间调用方需保持该文档数据有效。
	var _model: PositionModel

	## 创建命令时冻结的撤销端点，重做时不重新捕获。
	var _initial_position: Vector2

	## 确认时冻结的目标端点，执行与重做均使用此值。
	var _final_position: Vector2

	## 捕获本次编辑的两个端点，不在构造时执行正式写入。
	func _init(model: PositionModel, initial_position: Vector2, final_position: Vector2) -> void:
		_model = model
		_initial_position = initial_position
		_final_position = final_position
		action_name = "move_item"

	## 首次执行和重做都写入固定终点，以 true 报告成功。
	func execute() -> Variant:
		_model.position = _final_position
		return true

	## 恢复固定起点，不把当前模型状态重新解释为初值。
	func undo() -> Variant:
		_model.position = _initial_position
		return true
```

调用方持有模型、历史和会话，在输入回调中分别调用开始、更新、确认或取消。以下流程中两次预览只对应一条历史：

```gdscript
## 加载上方保存的项目脚本，复用其模型与会话类型。
const POSITION_EDIT_SESSION_SCRIPT = preload("res://position_edit_session.gd")

## 两次预览只产生一条历史；此演示自行创建并负责释放历史工具。
func demonstrate_edit() -> void:
	var model: POSITION_EDIT_SESSION_SCRIPT.PositionModel = POSITION_EDIT_SESSION_SCRIPT.PositionModel.new()
	model.position = Vector2(2.0, 3.0)
	var history: GFCommandHistoryUtility = GFCommandHistoryUtility.new()
	history.init()
	var session: POSITION_EDIT_SESSION_SCRIPT = POSITION_EDIT_SESSION_SCRIPT.new(model, history)
	var _began: bool = session.begin_edit()
	var _first_preview: bool = session.update_preview(Vector2(4.0, 5.0))
	var _final_preview: bool = session.update_preview(Vector2(8.0, 9.0))
	var changed: bool = await session.confirm_edit()
	if changed:
		var _undone: bool = history.undo_last() # 回到 (2, 3)。
		var _redone: bool = history.redo() # 回到 (8, 9)。
	history.dispose()
```

按 Escape 或放弃编辑时调用 `cancel_edit()`，重新按模型绘制即可，不需要补偿写入或调用撤销。`confirm_edit()` 在没有活跃会话或净变化为零时返回 `false`；重复结束通知不会重复执行。Vector2 示例使用精确相等判断净零；有吸附、量化或浮点容差的项目，应在自己的领域值上统一判断。

这个示例使用同步、内存内的命令，并假设编辑期间该模型由此会话独占修改；会话结束前，项目应阻止其他编辑和撤销/重做入口，或先取消当前预览。异步命令、多人冲突、持久化历史和自动保存需要各自的项目策略，不由这个会话推断。模型和历史应由同一文档生命周期持有，关闭文档时清理历史。

## 使用边界

`GFCommandHistoryUtility` 只管理历史栈和调用顺序。每个命令如何执行、撤销、保存快照和恢复状态，仍由命令类自己负责。

`undo()` 或重做阶段的 `execute()` 进入终态，并不一定代表业务状态已经成功变更。命令可以覆盖 `is_undo_successful(result)` 与 `is_redo_successful(result)` 报告终态结果；只有 hook 返回 `true`，历史工具才会把命令原子地移动到另一侧栈。返回 `false` 时，历史 API 同样返回 `false`，命令保持在来源栈原位置，另一侧栈的身份、顺序与容量均不改变。

```gdscript
## 将恢复结果显式反馈给历史工具，避免失败恢复仍移动历史栈。
class_name RestoreDocumentCommand
extends GFUndoableCommand

## 返回业务恢复的真实结果，供成功判定 Hook 使用。
func undo() -> Variant:
	return _restore_document()

## 只有明确可转换为 true 的终态才允许把命令移入重做栈。
func is_undo_successful(undo_result: Variant) -> bool:
	return GFVariantData.to_bool(undo_result, false)
```

两个 hook 默认返回 `true`，因此未覆盖它们的既有命令以及返回 `null` 的命令继续采用成功语义。

通过 `execute_command()`、撤销或重做进入的命令回调统一运行在非重入历史操作内，包括命令的 `execute()` / `undo()`、`should_record()` 和两个结果 hook。回调返回前，新的执行、记录、撤销、重做、清空、容量修改和历史恢复请求都会被拒绝；需要触发后续命令时，应把意图交给项目层队列，并在当前历史 API 完成后再执行。只读计数、历史副本和序列化仍可使用，并始终观察最近一次完整提交的栈，不暴露等待中或 hook 内的临时移动。

## 阅读入口

- [序列化与恢复](persistence.md)：`serialize_history()`、`deserialize_history()`、命令构建器和历史容量。
- [异步撤销与重做](async-constraints.md)：Signal 终态 payload、停滞告警、原子处理锁、并发操作拒绝和项目层排队。

命令历史、快照历史和流程编排的更多用法，可继续阅读 [本地存储、编码、同步与快照](../../../standard/utilities/io/storage-snapshot/index.md) 与 [撤销历史与指令序列](../../../standard/input-flow/command-sequence/index.md)。
