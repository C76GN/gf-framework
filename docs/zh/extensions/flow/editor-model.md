# 编辑器元数据与视图模型

节点可以填写 `display_name`、`category`、`editor_position`、`editor_size` 和 `editor_collapsed`。这些字段只服务编辑器、搜索和可视化工具，不影响运行时执行。

`GFFlowPort` 还提供 `editor_color`、`type_hint`、`class_name_hint` 和 `semantic_tags`，供编辑器颜色、搜索过滤、类名提示和项目工具索引使用。这些字段默认不影响运行时执行。

`get_editor_catalog()` 会按分类输出节点、端口和编辑器元数据。`build_editor_report()` 会组合目录、校验摘要和 `next_action`，适合项目自己的 GraphEdit 面板或导出工具消费。

这些编辑器结构报告只读取 `GFFlowGraph`、`GFFlowNode` 和 `GFFlowPort` 的导出属性，不调用项目自定义 `get_display_name()`、端口查找或描述方法，因此刷新 Inspector 或工作区不要求项目业务节点脚本支持 `@tool`。

`GFFlowGraphEditorModel` 进一步把节点、端口索引、GraphEdit slot、连接端口索引、分组和校验结果整理成视图模型，并提供 `auto_layout()` 复用 `GFGraphLayoutUtility` 写入初始节点位置。

连接条目始终按资源中的原始顺序投影。`include_invalid_connections = true` 时，空连接和其他无效连接也会保留，并以 `valid = false` 和 `invalid_reasons` 说明缺失端点、重复连接、节点/端口缺失、端口方向、值类型/类名或单连接约束；设为 `false` 时，只有通过同一整套结构规则的连接进入视图模型。这样编辑器不会因先过滤坏数据而丢失可修复位置，也不会展示运行时会拒绝的伪合法连接。

项目工具还可以用 `build_selection_package()`、`paste_selection_package()` 和 `remove_nodes()` 实现复制、粘贴、删除或批量改图，而不要求使用 GF 内置 UI。

启用 GF 插件后，选中 `GFFlowGraph` 资源时 Inspector 会提供起始节点选择和校验摘要。GF 工作区中的 `GFFlowGraphDock` 可以加载流程图资源，在独立 GF 工作区窗口中以 GraphEdit 查看节点、拖动位置、建立或移除通用连接、查看节点、连接和问题清单，并显式触发通用自动布局。

这个面板只操作通用编辑器元数据，不提供业务节点库，也不替项目决定流程含义。
