# Flow API

模块：`extensions/flow`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 1 | 19 | 4 |
| [资源定义](#category-resource_definition) | 3 | 80 | 46 |
| [运行时句柄](#category-runtime_handle) | 1 | 22 | 19 |
| [编辑器 API](#category-editor_api) | 2 | 17 | 15 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFFlowRunner`](classes/GFFlowRunner.md#gfflowrunner) | `RefCounted` | `addons/gf/extensions/flow/runtime/gf_flow_runner.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFFlowGraph`](classes/GFFlowGraph.md#gfflowgraph) | `Resource` | `addons/gf/extensions/flow/resources/gf_flow_graph.gd` |
| [`GFFlowNode`](classes/GFFlowNode.md#gfflownode) | `Resource` | `addons/gf/extensions/flow/resources/gf_flow_node.gd` |
| [`GFFlowPort`](classes/GFFlowPort.md#gfflowport) | `Resource` | `addons/gf/extensions/flow/resources/gf_flow_port.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFFlowContext`](classes/GFFlowContext.md#gfflowcontext) | `RefCounted` | `addons/gf/extensions/flow/runtime/gf_flow_context.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFFlowGraphDock`](classes/GFFlowGraphDock.md#gfflowgraphdock) | `Control` | `addons/gf/extensions/flow/editor/gf_flow_graph_dock.gd` |
| [`GFFlowGraphEditorModel`](classes/GFFlowGraphEditorModel.md#gfflowgrapheditormodel) | `RefCounted` | `addons/gf/extensions/flow/editor/gf_flow_graph_editor_model.gd` |
