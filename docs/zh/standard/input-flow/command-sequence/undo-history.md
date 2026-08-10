# 可撤销命令历史

`GFUndoableCommand` 在命令基础语义上增加 `set_snapshot()`、`get_snapshot()` 和 `undo()`，适合编辑器操作、运行时流程回放、预览工具和其他需要按步骤撤销的流程。`GFCommandHistoryUtility` 负责执行命令、自动压栈、撤销和重做。

## 快照语义

`set_snapshot()` 适合保存标量、数组和字典等值数据。如果快照里包含 `Object`、`Resource`、`Node` 或自定义引用，业务层应自行转换为可恢复的纯数据，避免撤销时继续引用同一个运行时对象。

单个快照同时受 128 层深度、100000 个访问值和 16 MiB 保守内存成本预算约束。成本估算包含
容器节点、`String` / `StringName` / `NodePath` 与全部 PackedArray 载荷；任一预算超限时
`set_snapshot()` 返回 `false` 并保留最近一次有效快照。该限制约束的是命令补偿数据，不适合把
文件、网络块或其他大对象原样驻留在历史栈；此类内容应保存到项目负责的有界外部存储，并在快照中
只记录稳定标识和恢复所需元数据。

```gdscript
class_name MoveTileUndoableCommand extends GFUndoableCommand

var new_pos: Vector2

func _init(n_pos):
	new_pos = n_pos

func execute() -> Variant:
	var grid_model := get_model(GridModel) as GridModel
	if grid_model == null:
		return null

	set_snapshot(grid_model.current_pos)
	grid_model.current_pos = new_pos
	return null

func undo() -> Variant:
	var grid_model := get_model(GridModel) as GridModel
	if grid_model == null:
		return null

	grid_model.current_pos = get_snapshot()
	return null
```

## 历史栈

```gdscript
var stack := Gf.get_utility(GFCommandHistoryUtility) as GFCommandHistoryUtility
stack.execute_command(MoveTileUndoableCommand.new(Vector2(5, 6)))

stack.undo_last()
```

`GFUndoableCommand.action_name` 是可选标签，默认保持为空。需要在历史面板、日志或调试工具里显示命令名称时，项目命令应显式设置自己的本地化文案或稳定 ID。

## 使用边界

异步可撤销命令应使用历史工具的异步入口。同步 `undo_last()` / `redo()` 只有调用命令后才能看到返回值是否为 `Signal`；此时返回 `false` 只表示历史栈没有提交移动，不表示命令在返回 `Signal` 前启动的同步或 deferred 副作用已撤销。不能在执行前确定模式的调用方应统一使用异步入口；如果命令需要取消，应在项目命令里显式实现可取消逻辑。超时只告警并继续持有历史锁，不能取消已经开始的命令副作用。

`deserialize_history()` 和 `deserialize_full_history()` 会先在独立候选栈中验证全部条目、调用 builder 并注入依赖，全部成功后才原子替换当前 undo/redo 栈。无效 builder、非 Dictionary 条目或任一 builder 返回非 `GFUndoableCommand` 时都会报告错误，并完整保留调用前的两个历史栈。builder 自身产生的外部副作用仍属于项目代码责任，框架只保证历史栈提交的原子性。
