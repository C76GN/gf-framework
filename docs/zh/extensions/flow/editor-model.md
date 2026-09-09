# 编辑器元数据与视图模型

## 编辑器数据与视图模型

节点可以填写 `display_name`、`category`、`editor_position`、`editor_size` 和 `editor_collapsed`。这些字段只服务编辑器、搜索和可视化工具，不影响运行时执行。

`GFFlowPort` 还提供 `editor_color`、`type_hint`、`class_name_hint` 和 `semantic_tags`，供编辑器颜色、搜索过滤、类名提示和项目工具索引使用。这些字段默认不影响运行时执行。

`get_editor_catalog()` 会按分类输出节点、端口和编辑器元数据。`build_editor_report()` 会组合目录、校验摘要和 `next_action`，适合项目自己的 GraphEdit 面板或导出工具消费。

这些编辑器结构报告只读取 `GFFlowGraph`、`GFFlowNode` 和 `GFFlowPort` 的导出属性，不调用项目自定义 `get_display_name()`、端口查找或描述方法，因此刷新 Inspector 或工作区不要求项目业务节点脚本支持 `@tool`。

`GFFlowGraphEditorModel` 进一步把节点、端口索引、GraphEdit slot、连接端口索引、分组和校验结果整理成视图模型，并提供 `auto_layout()` 复用 `GFGraphLayoutUtility` 写入初始节点位置。

连接条目始终按资源中的原始顺序投影。`include_invalid_connections = true` 时，空连接和其他无效连接也会保留，并以 `valid = false` 和 `invalid_reasons` 说明缺失端点、重复连接、节点/端口缺失、端口方向、值类型/类名或单连接约束；设为 `false` 时，只有通过同一整套结构规则的连接进入视图模型。这样编辑器不会因先过滤坏数据而丢失可修复位置，也不会展示运行时会拒绝的伪合法连接。

项目工具还可以用 `build_selection_package()`、`paste_selection_package()` 和 `remove_nodes()` 实现复制、粘贴、删除或批量改图，而不要求使用 GF 内置 UI。

## 面板编辑与撤销

启用 GF 插件后，选中 `GFFlowGraph` 资源时 Inspector 会提供起始节点选择和校验摘要。GF 工作区中的 `GFFlowGraphDock` 可以加载流程图资源，在独立 GF 工作区窗口中以 GraphEdit 查看节点、拖动位置、建立或移除通用连接、查看节点、连接和问题清单，并显式触发通用自动布局。

这个面板操作通用图结构及编辑器元数据，不提供业务节点库，也不替项目决定流程含义。

Flow 面板中的连接增删、节点删除、拖动和自动布局通过编辑器命令提交，支持 Godot 编辑器的撤销与重做。删除节点及其关联连接、执行后继引用属于同一个动作；撤销会恢复原节点资源身份和连接元数据。删除起始节点时清空 `start_node_id`，撤销同时恢复。一次拖动结束才提交位置，未改变位置和被拒绝的连接请求不会增加历史。

这些动作按导出属性查找节点并规划修改，不调用已加载图、节点或端口资源的脚本查询和执行方法；项目业务资源无需为使用内置面板而启用 `@tool`。

## 编辑上下文与资源生命周期

GF 工作区会自动提供编辑器上下文。项目独立创建面板时，需要从自己的 `EditorPlugin` 注入上下文：

```gdscript
var dock: GFFlowGraphDock = GFFlowGraphDock.new()
dock.set_editor_context(GFEditorToolContext.from_plugin(self))
dock.set_graph(flow_graph)
```

未设置有效的 UndoRedo 上下文、调用 `set_editor_context(null)` 或面板离树时，面板保持只读，并放弃未提交的拖动。`GFFlowGraphEditorModel` 的直接数据操作方法仍可独立使用；它们不隐式创建编辑器历史。

编辑历史归属于实际图资源。一次动作涉及其他独立资源历史时会整体拒绝，不会只修改其中一部分。保存只把已提交的资源状态写入磁盘，不清空撤销历史，也不顺便提交画布中的未完成拖动。撤销保存前后的动作仍会改变内存资源；需要再次保存才能写回磁盘。

成功执行或撤销后，面板会随资源变化刷新。切换图资源会断开旧图的视图订阅；关闭面板后，已有历史仍可作用于原图，命令不会保留面板。属性事务失败时会显示诊断；仅在补偿未完整完成时显示“恢复编辑”，恢复前暂停编辑、保存和切换资源。恢复针对失败操作开始前的属性状态，不承诺撤销项目 setter 的外部副作用。
