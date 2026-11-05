# 基础执行

## 节点与图

`GFFlowNode` 是项目节点的继承点。节点在 `execute(context, execution)` 中读取项目业务数据，用本次执行的句柄选择后继，异步工作可返回所属任务的完成 Signal。

```gdscript
## 根据项目上下文选择开门分支；分支节点 ID 必须与项目图定义一致。
class_name CheckDoorNode
extends GFFlowNode


## 本节点同步完成分支选择，返回 null 表示没有额外等待任务。
func execute(context: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
	if context.get_value(&"has_key", false):
		var _selected: bool = execution.set_next_nodes(PackedStringArray(["open"]))
	else:
		var _selected: bool = execution.set_next_nodes(PackedStringArray(["locked"]))
	return null
```

`GFFlowGraph` 保存起始节点和节点资源列表，`GFFlowRunner` 负责从起点执行并推进后继。

## 执行与报告

```gdscript
var graph := GFFlowGraph.new()
graph.start_node_id = &"check_door"
# 每个节点的 ID 都显式对应图起点和分支选择；框架不会从类名推导 ID。
var check_door := CheckDoorNode.new()
check_door.node_id = &"check_door"
var open_door := OpenDoorNode.new()
open_door.node_id = &"open"
var locked_hint := ShowLockedHintNode.new()
locked_hint.node_id = &"locked"
graph.nodes = [
	check_door,
	open_door,
	locked_hint,
]

var runner := GFFlowRunner.new()
# 即使各节点都同步完成，也等待运行器的最终报告，不能从启动推断成功。
var report := await runner.run(
	graph,
	GFFlowContext.new(Gf.architecture, { &"has_key": true })
)

if report.outcome != "completed":
	push_warning("Flow 未正常完成：%s" % report.reason)
```

`run()` 返回可直接写入日志或诊断面板的结构化报告；节点即使全部同步，也应通过 `await` 接收最终报告。

## 使用边界

Flow 不解释节点业务含义，也不内置剧情、任务、教程或 UI 节点。项目应把领域动作封装在自己的 `GFFlowNode` 子类中，并只把通用编排交给 Flow。
