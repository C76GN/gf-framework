# GFFlowGraphDock

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/editor/gf_flow_graph_dock.gd`
- 模块：`Flow`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

FlowGraph 图形化编辑与结构检查工作区页面。 为资源化流程图提供路径加载、GraphEdit 预览/连线、校验摘要、节点/连接清单 和通用自动布局，不提供业务节点库，也不解释项目自定义元数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_graph`](#member-gfflowgraphdock-methods-set_graph) | `func set_graph(graph: GFFlowGraph, path: String = "") -> void:` |
| 方法 | [`set_graph_path`](#member-gfflowgraphdock-methods-set_graph_path) | `func set_graph_path(path: String) -> void:` |
| 方法 | [`refresh`](#member-gfflowgraphdock-methods-refresh) | `func refresh() -> void:` |
| 方法 | [`get_last_view_model`](#member-gfflowgraphdock-methods-get_last_view_model) | `func get_last_view_model() -> Dictionary:` |

## 方法

<a id="member-gfflowgraphdock-methods-set_graph"></a>

### `set_graph`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_graph(graph: GFFlowGraph, path: String = "") -> void:
```

设置当前查看的 FlowGraph。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `path` | 可选资源路径。 |

<a id="member-gfflowgraphdock-methods-set_graph_path"></a>

### `set_graph_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_graph_path(path: String) -> void:
```

设置并加载当前 FlowGraph 资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `path` | `res://` 资源路径。 |

<a id="member-gfflowgraphdock-methods-refresh"></a>

### `refresh`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func refresh() -> void:
```

刷新当前 FlowGraph 视图。

<a id="member-gfflowgraphdock-methods-get_last_view_model"></a>

### `get_last_view_model`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_last_view_model() -> Dictionary:
```

获取最近一次 FlowGraph 视图模型。

返回：视图模型字典副本。

结构：

- `return`: Dictionary，由 GFFlowGraphEditorModel.build_view_model() 生成的视图模型副本。
