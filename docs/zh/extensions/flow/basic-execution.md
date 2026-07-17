# 基础执行

## 节点与图

`GFFlowNode` 是项目节点的继承点。节点在 `execute(context)` 中读取上下文、写入后继节点，或返回一个需要等待的结果。

```gdscript
class_name CheckDoorNode
extends GFFlowNode


func execute(context: GFFlowContext) -> Variant:
	if context.get_value(&"has_key", false):
		context.set_next_nodes(PackedStringArray(["open"]))
	else:
		context.set_next_nodes(PackedStringArray(["locked"]))
	return null
```

`GFFlowGraph` 保存起始节点和节点资源列表，`GFFlowRunner` 负责从起点执行并推进后继。

## 执行与报告

```gdscript
var graph := GFFlowGraph.new()
graph.start_node_id = &"check_door"
graph.nodes = [
	CheckDoorNode.new(),
	OpenDoorNode.new(),
	ShowLockedHintNode.new(),
]

var runner := GFFlowRunner.new()
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
