# GFFlowGraphEditorModel

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/editor/gf_flow_graph_editor_model.gd`
- 模块：`Flow`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

FlowGraph 编辑器视图模型构建器。 将 GFFlowGraph 转换为 GraphEdit、自定义编辑器或项目工具可直接消费的 节点、端口、连接和校验结构。它只整理数据，不绑定具体 UI 实现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`default_node_size`](#member-gfflowgrapheditormodel-properties-default_node_size) | `var default_node_size: Vector2 = Vector2(220.0, 120.0)` |
| 属性 | [`include_invalid_connections`](#member-gfflowgrapheditormodel-properties-include_invalid_connections) | `var include_invalid_connections: bool = true` |
| 方法 | [`build_view_model`](#member-gfflowgrapheditormodel-methods-build_view_model) | `func build_view_model(graph: Resource) -> Dictionary:` |
| 方法 | [`build_editor_report`](#member-gfflowgrapheditormodel-methods-build_editor_report) | `func build_editor_report(graph: Resource) -> Dictionary:` |
| 方法 | [`build_editor_catalog`](#member-gfflowgrapheditormodel-methods-build_editor_catalog) | `func build_editor_catalog(graph: Resource) -> Dictionary:` |
| 方法 | [`validate_graph_for_editor`](#member-gfflowgrapheditormodel-methods-validate_graph_for_editor) | `func validate_graph_for_editor(graph: Resource) -> Dictionary:` |
| 方法 | [`validate_metadata_for_editor`](#member-gfflowgrapheditormodel-methods-validate_metadata_for_editor) | `func validate_metadata_for_editor(target_metadata: Dictionary, schema: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_node_layout`](#member-gfflowgrapheditormodel-methods-apply_node_layout) | `func apply_node_layout( graph: GFFlowGraph, node_id: StringName, position: Vector2, size: Vector2 = Vector2.ZERO, collapsed: bool = false ) -> bool:` |
| 方法 | [`apply_node_positions`](#member-gfflowgrapheditormodel-methods-apply_node_positions) | `func apply_node_positions(graph: GFFlowGraph, positions: Dictionary) -> int:` |
| 方法 | [`auto_layout`](#member-gfflowgrapheditormodel-methods-auto_layout) | `func auto_layout(graph: GFFlowGraph, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_selection_package`](#member-gfflowgrapheditormodel-methods-build_selection_package) | `func build_selection_package(graph: GFFlowGraph, node_ids: PackedStringArray) -> Dictionary:` |
| 方法 | [`paste_selection_package`](#member-gfflowgrapheditormodel-methods-paste_selection_package) | `func paste_selection_package( graph: GFFlowGraph, selection_package: Dictionary, offset: Vector2 = Vector2.ZERO, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`remove_nodes`](#member-gfflowgrapheditormodel-methods-remove_nodes) | `func remove_nodes(graph: GFFlowGraph, node_ids: PackedStringArray) -> Dictionary:` |

## 属性

<a id="member-gfflowgrapheditormodel-properties-default_node_size"></a>

### `default_node_size`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var default_node_size: Vector2 = Vector2(220.0, 120.0)
```

节点未显式设置尺寸时使用的默认编辑器尺寸。

<a id="member-gfflowgrapheditormodel-properties-include_invalid_connections"></a>

### `include_invalid_connections`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var include_invalid_connections: bool = true
```

是否把校验失败的连接也写入视图模型。

## 方法

<a id="member-gfflowgrapheditormodel-methods-build_view_model"></a>

### `build_view_model`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_view_model(graph: Resource) -> Dictionary:
```

构建流程图编辑器视图模型。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |

返回：视图模型字典。

结构：

- `return`: Dictionary，包含 ok、start_node_id、node_count、connection_count、nodes、node_lookup、connections、groups、metadata、validation。

<a id="member-gfflowgrapheditormodel-methods-build_editor_report"></a>

### `build_editor_report`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_editor_report(graph: Resource) -> Dictionary:
```

构建 FlowGraph 编辑器报告。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |

返回：编辑器诊断、目录和元数据报告。

结构：

- `return`: Dictionary，包含 ok、healthy、summary、next_action、validation、catalog 和 editor。

<a id="member-gfflowgrapheditormodel-methods-build_editor_catalog"></a>

### `build_editor_catalog`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_editor_catalog(graph: Resource) -> Dictionary:
```

获取编辑器可消费的节点目录，不调用节点/端口脚本方法。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |

返回：节点目录字典。

结构：

- `return`: Dictionary，包含 node_count、nodes 和 categories；nodes 为节点目录记录数组。

<a id="member-gfflowgrapheditormodel-methods-validate_graph_for_editor"></a>

### `validate_graph_for_editor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func validate_graph_for_editor(graph: Resource) -> Dictionary:
```

校验 FlowGraph 结构，不调用项目节点/端口脚本方法。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |

返回：校验报告。

结构：

- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action 和计数字段。

<a id="member-gfflowgrapheditormodel-methods-validate_metadata_for_editor"></a>

### `validate_metadata_for_editor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func validate_metadata_for_editor(target_metadata: Dictionary, schema: Dictionary = {}) -> Dictionary:
```

校验编辑器元数据。

参数：

| 名称 | 说明 |
|---|---|
| `target_metadata` | 待校验元数据。 |
| `schema` | 轻量 Schema。 |

返回：校验报告。

结构：

- `target_metadata`: Dictionary，待校验的编辑器或项目工具元数据。
- `schema`: Dictionary，键为元数据 key，值为包含 required、allow_null、type、class_name、allowed_values 等字段的规则字典。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action 和计数字段。

<a id="member-gfflowgrapheditormodel-methods-apply_node_layout"></a>

### `apply_node_layout`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func apply_node_layout( graph: GFFlowGraph, node_id: StringName, position: Vector2, size: Vector2 = Vector2.ZERO, collapsed: bool = false ) -> bool:
```

应用单个节点布局。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `node_id` | 节点标识。 |
| `position` | 编辑器坐标。 |
| `size` | 编辑器尺寸；Vector2.ZERO 表示使用默认尺寸。 |
| `collapsed` | 是否折叠。 |

返回：应用成功返回 true。

<a id="member-gfflowgrapheditormodel-methods-apply_node_positions"></a>

### `apply_node_positions`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func apply_node_positions(graph: GFFlowGraph, positions: Dictionary) -> int:
```

批量应用节点位置。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `positions` | node_id 到 Vector2 的映射。 |

返回：成功更新的节点数量。

结构：

- `positions`: Dictionary，键为节点标识，值为 Vector2 编辑器坐标。

<a id="member-gfflowgrapheditormodel-methods-auto_layout"></a>

### `auto_layout`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func auto_layout(graph: GFFlowGraph, options: Dictionary = {}) -> Dictionary:
```

自动生成并应用节点布局。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `options` | 布局选项，透传给 GFGraphLayoutUtility.make_layered_layout()。 |

返回：布局报告，包含 positions 与 changed_count。

结构：

- `options`: Dictionary，传给 GFGraphLayoutUtility.make_layered_layout() 的布局选项。
- `return`: Dictionary，包含 ok、positions、changed_count，失败时包含 error。

<a id="member-gfflowgrapheditormodel-methods-build_selection_package"></a>

### `build_selection_package`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_selection_package(graph: GFFlowGraph, node_ids: PackedStringArray) -> Dictionary:
```

构建节点选择包，用于编辑器复制、剪切或跨工具传递。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `node_ids` | 选中的节点标识列表。 |

返回：选择包字典。

结构：

- `return`: Dictionary，包含 ok、node_count、connection_count、nodes、connections 和 node_ids。

<a id="member-gfflowgrapheditormodel-methods-paste_selection_package"></a>

### `paste_selection_package`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func paste_selection_package( graph: GFFlowGraph, selection_package: Dictionary, offset: Vector2 = Vector2.ZERO, options: Dictionary = {} ) -> Dictionary:
```

将选择包粘贴到流程图。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `selection_package` | build_selection_package() 返回的选择包。 |
| `offset` | 粘贴时叠加到节点编辑器位置的偏移。 |
| `options` | 可选参数，支持 keep_original_ids。 |

返回：粘贴报告。

结构：

- `selection_package`: Dictionary，由 build_selection_package() 返回，包含 nodes、connections 和 node_ids。
- `options`: Dictionary，可包含 keep_original_ids。
- `return`: Dictionary，包含 ok、added_node_ids、added_node_count、added_connection_count、failed_connection_count 和 id_map。

<a id="member-gfflowgrapheditormodel-methods-remove_nodes"></a>

### `remove_nodes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func remove_nodes(graph: GFFlowGraph, node_ids: PackedStringArray) -> Dictionary:
```

从流程图移除一组节点及其相关连接。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `node_ids` | 节点标识列表。 |

返回：移除报告。

结构：

- `return`: Dictionary，包含 ok、removed_node_ids、removed_node_count 和 connection_count。
