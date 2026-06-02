# GFFlowGraph

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/resources/gf_flow_graph.gd`
- 模块：`Flow`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

资源化通用流程图。 只维护节点集合与起始节点，不规定具体编辑器表现或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`start_node_id`](#member-gfflowgraph-properties-start_node_id) | `var start_node_id: StringName = &""` |
| 属性 | [`nodes`](#member-gfflowgraph-properties-nodes) | `var nodes: Array[GFFlowNode] = []` |
| 属性 | [`connections`](#member-gfflowgraph-properties-connections) | `var connections: Array[Dictionary] = []` |
| 属性 | [`validate_port_compatibility`](#member-gfflowgraph-properties-validate_port_compatibility) | `var validate_port_compatibility: bool = true` |
| 属性 | [`warn_unreachable_nodes`](#member-gfflowgraph-properties-warn_unreachable_nodes) | `var warn_unreachable_nodes: bool = true` |
| 属性 | [`warn_cycles`](#member-gfflowgraph-properties-warn_cycles) | `var warn_cycles: bool = true` |
| 属性 | [`warn_terminal_nodes`](#member-gfflowgraph-properties-warn_terminal_nodes) | `var warn_terminal_nodes: bool = false` |
| 属性 | [`editor_groups`](#member-gfflowgraph-properties-editor_groups) | `var editor_groups: Array[Dictionary] = []` |
| 属性 | [`editor_metadata`](#member-gfflowgraph-properties-editor_metadata) | `var editor_metadata: Dictionary = {}` |
| 属性 | [`metadata_schema`](#member-gfflowgraph-properties-metadata_schema) | `var metadata_schema: Dictionary = {}` |
| 方法 | [`set_node`](#member-gfflowgraph-methods-set_node) | `func set_node(node: GFFlowNode) -> void:` |
| 方法 | [`get_node`](#member-gfflowgraph-methods-get_node) | `func get_node(node_id: StringName) -> GFFlowNode:` |
| 方法 | [`has_node`](#member-gfflowgraph-methods-has_node) | `func has_node(node_id: StringName) -> bool:` |
| 方法 | [`remove_node`](#member-gfflowgraph-methods-remove_node) | `func remove_node(node_id: StringName) -> void:` |
| 方法 | [`add_connection`](#member-gfflowgraph-methods-add_connection) | `func add_connection( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName, metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`remove_connection`](#member-gfflowgraph-methods-remove_connection) | `func remove_connection( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName ) -> bool:` |
| 方法 | [`remove_connections_for_node`](#member-gfflowgraph-methods-remove_connections_for_node) | `func remove_connections_for_node(node_id: StringName) -> void:` |
| 方法 | [`has_connection`](#member-gfflowgraph-methods-has_connection) | `func has_connection( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName ) -> bool:` |
| 方法 | [`get_connections_from`](#member-gfflowgraph-methods-get_connections_from) | `func get_connections_from(node_id: StringName, port_id: StringName = &"") -> Array[Dictionary]:` |
| 方法 | [`get_connections_to`](#member-gfflowgraph-methods-get_connections_to) | `func get_connections_to(node_id: StringName, port_id: StringName = &"") -> Array[Dictionary]:` |
| 方法 | [`get_connected_node_ids_from`](#member-gfflowgraph-methods-get_connected_node_ids_from) | `func get_connected_node_ids_from(node_id: StringName, port_id: StringName = &"") -> PackedStringArray:` |
| 方法 | [`check_connection_compatibility`](#member-gfflowgraph-methods-check_connection_compatibility) | `func check_connection_compatibility( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName ) -> Dictionary:` |
| 方法 | [`get_connection_compatibility_report`](#member-gfflowgraph-methods-get_connection_compatibility_report) | `func get_connection_compatibility_report() -> Array[Dictionary]:` |
| 方法 | [`set_node_editor_position`](#member-gfflowgraph-methods-set_node_editor_position) | `func set_node_editor_position(node_id: StringName, position: Vector2) -> bool:` |
| 方法 | [`set_node_editor_layout`](#member-gfflowgraph-methods-set_node_editor_layout) | `func set_node_editor_layout( node_id: StringName, position: Vector2, size: Vector2 = Vector2.ZERO, collapsed: bool = false ) -> bool:` |
| 方法 | [`get_editor_catalog`](#member-gfflowgraph-methods-get_editor_catalog) | `func get_editor_catalog() -> Dictionary:` |
| 方法 | [`describe_graph`](#member-gfflowgraph-methods-describe_graph) | `func describe_graph() -> Dictionary:` |
| 方法 | [`instantiate_graph`](#member-gfflowgraph-methods-instantiate_graph) | `func instantiate_graph(options: Dictionary = {}) -> GFFlowGraph:` |
| 方法 | [`serialize_runtime_state`](#member-gfflowgraph-methods-serialize_runtime_state) | `func serialize_runtime_state() -> Dictionary:` |
| 方法 | [`deserialize_runtime_state`](#member-gfflowgraph-methods-deserialize_runtime_state) | `func deserialize_runtime_state(data: Dictionary) -> void:` |
| 方法 | [`clear_runtime_state`](#member-gfflowgraph-methods-clear_runtime_state) | `func clear_runtime_state() -> void:` |
| 方法 | [`validate_metadata`](#member-gfflowgraph-methods-validate_metadata) | `func validate_metadata(target_metadata: Dictionary, schema: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_graph_metadata`](#member-gfflowgraph-methods-validate_graph_metadata) | `func validate_graph_metadata() -> Dictionary:` |
| 方法 | [`validate_graph`](#member-gfflowgraph-methods-validate_graph) | `func validate_graph() -> Dictionary:` |
| 方法 | [`build_editor_report`](#member-gfflowgraph-methods-build_editor_report) | `func build_editor_report() -> Dictionary:` |

## 属性

<a id="member-gfflowgraph-properties-start_node_id"></a>

### `start_node_id`

- API：`public`

```gdscript
var start_node_id: StringName = &""
```

起始节点标识。

<a id="member-gfflowgraph-properties-nodes"></a>

### `nodes`

- API：`public`

```gdscript
var nodes: Array[GFFlowNode] = []
```

流程节点列表。

<a id="member-gfflowgraph-properties-connections"></a>

### `connections`

- API：`public`

```gdscript
var connections: Array[Dictionary] = []
```

节点连接列表。连接结构为 from_node_id/from_port_id/to_node_id/to_port_id/metadata。

结构：

- `connections`: 连接字典数组；每项包含 from_node_id、from_port_id、to_node_id、to_port_id 和 metadata 字段。

<a id="member-gfflowgraph-properties-validate_port_compatibility"></a>

### `validate_port_compatibility`

- API：`public`

```gdscript
var validate_port_compatibility: bool = true
```

校验时是否把端口值类型和类名提示不兼容视为错误。

<a id="member-gfflowgraph-properties-warn_unreachable_nodes"></a>

### `warn_unreachable_nodes`

- API：`public`

```gdscript
var warn_unreachable_nodes: bool = true
```

校验时是否提示从 start_node_id 无法到达的节点。

<a id="member-gfflowgraph-properties-warn_cycles"></a>

### `warn_cycles`

- API：`public`

```gdscript
var warn_cycles: bool = true
```

校验时是否提示图中的循环。

<a id="member-gfflowgraph-properties-warn_terminal_nodes"></a>

### `warn_terminal_nodes`

- API：`public`

```gdscript
var warn_terminal_nodes: bool = false
```

校验时是否提示没有后继的终端节点。默认关闭，避免把正常结束节点视为问题。

<a id="member-gfflowgraph-properties-editor_groups"></a>

### `editor_groups`

- API：`public`

```gdscript
var editor_groups: Array[Dictionary] = []
```

编辑器分组数据。结构由编辑器工具解释，运行时不读取。

结构：

- `editor_groups`: 编辑器分组字典数组；字段由 FlowGraph 编辑器或项目工具解释。

<a id="member-gfflowgraph-properties-editor_metadata"></a>

### `editor_metadata`

- API：`public`

```gdscript
var editor_metadata: Dictionary = {}
```

编辑器或项目工具的附加元数据。

结构：

- `editor_metadata`: 编辑器或项目工具自定义元数据 Dictionary；运行时不解释其中键值。

<a id="member-gfflowgraph-properties-metadata_schema"></a>

### `metadata_schema`

- API：`public`

```gdscript
var metadata_schema: Dictionary = {}
```

编辑器或项目工具元数据的轻量 Schema。框架只校验结构，不解释业务含义。

结构：

- `metadata_schema`: 轻量元数据校验规则 Dictionary；键为元数据 key，值为包含 required、allow_null、type、class_name、allowed_values 等字段的规则字典。

## 方法

<a id="member-gfflowgraph-methods-set_node"></a>

### `set_node`

- API：`public`

```gdscript
func set_node(node: GFFlowNode) -> void:
```

设置或替换一个节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 流程节点。 |

<a id="member-gfflowgraph-methods-get_node"></a>

### `get_node`

- API：`public`

```gdscript
func get_node(node_id: StringName) -> GFFlowNode:
```

获取节点。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |

返回：流程节点；不存在时返回 null。

<a id="member-gfflowgraph-methods-has_node"></a>

### `has_node`

- API：`public`

```gdscript
func has_node(node_id: StringName) -> bool:
```

检查节点是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |

返回：存在返回 true。

<a id="member-gfflowgraph-methods-remove_node"></a>

### `remove_node`

- API：`public`

```gdscript
func remove_node(node_id: StringName) -> void:
```

移除节点。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |

<a id="member-gfflowgraph-methods-add_connection"></a>

### `add_connection`

- API：`public`

```gdscript
func add_connection( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName, metadata: Dictionary = {} ) -> bool:
```

添加节点连接。

参数：

| 名称 | 说明 |
|---|---|
| `from_node_id` | 来源节点。 |
| `from_port_id` | 来源端口；为空时表示节点级执行连接。 |
| `to_node_id` | 目标节点。 |
| `to_port_id` | 目标端口；为空时表示节点级执行连接。 |
| `metadata` | 项目自定义元数据。 |

返回：添加成功返回 true。

结构：

- `metadata`: 连接自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

<a id="member-gfflowgraph-methods-remove_connection"></a>

### `remove_connection`

- API：`public`

```gdscript
func remove_connection( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName ) -> bool:
```

移除指定节点连接。

参数：

| 名称 | 说明 |
|---|---|
| `from_node_id` | 连接起点节点标识。 |
| `from_port_id` | 连接起点端口标识。 |
| `to_node_id` | 目标标识。 |
| `to_port_id` | 目标标识。 |

返回：移除成功返回 true。

<a id="member-gfflowgraph-methods-remove_connections_for_node"></a>

### `remove_connections_for_node`

- API：`public`

```gdscript
func remove_connections_for_node(node_id: StringName) -> void:
```

移除与指定节点相关的所有连接。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |

<a id="member-gfflowgraph-methods-has_connection"></a>

### `has_connection`

- API：`public`

```gdscript
func has_connection( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName ) -> bool:
```

检查连接是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `from_node_id` | 连接起点节点标识。 |
| `from_port_id` | 连接起点端口标识。 |
| `to_node_id` | 目标标识。 |
| `to_port_id` | 目标标识。 |

返回：存在返回 true。

<a id="member-gfflowgraph-methods-get_connections_from"></a>

### `get_connections_from`

- API：`public`

```gdscript
func get_connections_from(node_id: StringName, port_id: StringName = &"") -> Array[Dictionary]:
```

获取从指定节点或端口发出的连接。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `port_id` | 端口标识；为空时返回该节点所有输出连接。 |

返回：连接副本列表。

结构：

- `return`: 连接字典数组；每项包含 from_node_id、from_port_id、to_node_id、to_port_id 和 metadata 字段。

<a id="member-gfflowgraph-methods-get_connections_to"></a>

### `get_connections_to`

- API：`public`

```gdscript
func get_connections_to(node_id: StringName, port_id: StringName = &"") -> Array[Dictionary]:
```

获取指向指定节点或端口的连接。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `port_id` | 端口标识；为空时返回该节点所有输入连接。 |

返回：连接副本列表。

结构：

- `return`: 连接字典数组；每项包含 from_node_id、from_port_id、to_node_id、to_port_id 和 metadata 字段。

<a id="member-gfflowgraph-methods-get_connected_node_ids_from"></a>

### `get_connected_node_ids_from`

- API：`public`

```gdscript
func get_connected_node_ids_from(node_id: StringName, port_id: StringName = &"") -> PackedStringArray:
```

获取指定节点或端口连接到的目标节点。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `port_id` | 端口标识；为空时返回该节点所有输出目标。 |

返回：目标节点标识列表。

<a id="member-gfflowgraph-methods-check_connection_compatibility"></a>

### `check_connection_compatibility`

- API：`public`

```gdscript
func check_connection_compatibility( from_node_id: StringName, from_port_id: StringName, to_node_id: StringName, to_port_id: StringName ) -> Dictionary:
```

检查指定连接端口的兼容性。

参数：

| 名称 | 说明 |
|---|---|
| `from_node_id` | 来源节点。 |
| `from_port_id` | 来源端口。 |
| `to_node_id` | 目标节点。 |
| `to_port_id` | 目标端口。 |

返回：兼容性报告。

结构：

- `return`: 包含 ok、reason、message、from_node_id、from_port_id、to_node_id 和 to_port_id 等字段的 Dictionary。

<a id="member-gfflowgraph-methods-get_connection_compatibility_report"></a>

### `get_connection_compatibility_report`

- API：`public`

```gdscript
func get_connection_compatibility_report() -> Array[Dictionary]:
```

获取所有连接的兼容性报告。

返回：兼容性报告列表。

结构：

- `return`: 兼容性报告字典数组；每项结构同 check_connection_compatibility() 返回值。

<a id="member-gfflowgraph-methods-set_node_editor_position"></a>

### `set_node_editor_position`

- API：`public`

```gdscript
func set_node_editor_position(node_id: StringName, position: Vector2) -> bool:
```

设置节点编辑器位置。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `position` | 编辑器坐标。 |

返回：设置成功返回 true。

<a id="member-gfflowgraph-methods-set_node_editor_layout"></a>

### `set_node_editor_layout`

- API：`public`

```gdscript
func set_node_editor_layout( node_id: StringName, position: Vector2, size: Vector2 = Vector2.ZERO, collapsed: bool = false ) -> bool:
```

设置节点编辑器布局。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `position` | 编辑器坐标。 |
| `size` | 编辑器尺寸；Vector2.ZERO 表示由编辑器自行决定。 |
| `collapsed` | 是否折叠显示。 |

返回：设置成功返回 true。

<a id="member-gfflowgraph-methods-get_editor_catalog"></a>

### `get_editor_catalog`

- API：`public`

```gdscript
func get_editor_catalog() -> Dictionary:
```

获取编辑器或可视化工具可消费的节点目录。

返回：节点目录字典。

结构：

- `return`: 包含 node_count、nodes 和 categories 字段的 Dictionary；nodes 为节点目录条目数组，categories 按分类名分组。

<a id="member-gfflowgraph-methods-describe_graph"></a>

### `describe_graph`

- API：`public`

```gdscript
func describe_graph() -> Dictionary:
```

描述流程图结构。

返回：图描述字典。

结构：

- `return`: 包含 start_node_id、node_count、nodes、connection_count、connections、validate_port_compatibility、diagnostics 和 editor 字段的 Dictionary。

<a id="member-gfflowgraph-methods-instantiate_graph"></a>

### `instantiate_graph`

- API：`public`

```gdscript
func instantiate_graph(options: Dictionary = {}) -> GFFlowGraph:
```

创建可运行的流程图副本。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 clear_runtime_state。 |

返回：流程图副本；复制失败时返回 null。

结构：

- `options`: 可选项 Dictionary；支持 clear_runtime_state: bool。

<a id="member-gfflowgraph-methods-serialize_runtime_state"></a>

### `serialize_runtime_state`

- API：`public`

```gdscript
func serialize_runtime_state() -> Dictionary:
```

序列化图内节点运行态。

返回：运行态快照。

结构：

- `return`: 包含 nodes 字段的 Dictionary；nodes 按 node_id 保存节点运行态 Dictionary。

<a id="member-gfflowgraph-methods-deserialize_runtime_state"></a>

### `deserialize_runtime_state`

- API：`public`

```gdscript
func deserialize_runtime_state(data: Dictionary) -> void:
```

反序列化图内节点运行态。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 运行态快照。 |

结构：

- `data`: serialize_runtime_state() 返回的运行态快照 Dictionary。

<a id="member-gfflowgraph-methods-clear_runtime_state"></a>

### `clear_runtime_state`

- API：`public`

```gdscript
func clear_runtime_state() -> void:
```

清空图内所有节点运行态。

<a id="member-gfflowgraph-methods-validate_metadata"></a>

### `validate_metadata`

- API：`public`

```gdscript
func validate_metadata(target_metadata: Dictionary, schema: Dictionary = {}) -> Dictionary:
```

校验元数据是否符合轻量 Schema。

参数：

| 名称 | 说明 |
|---|---|
| `target_metadata` | 待校验元数据。 |
| `schema` | 可选 Schema；为空时使用 metadata_schema。 |

返回：校验报告。

结构：

- `target_metadata`: 待校验的元数据 Dictionary。
- `schema`: 可选轻量 Schema Dictionary；为空时使用 metadata_schema。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count 和 warning_count 等字段。

<a id="member-gfflowgraph-methods-validate_graph_metadata"></a>

### `validate_graph_metadata`

- API：`public`

```gdscript
func validate_graph_metadata() -> Dictionary:
```

校验当前图编辑器元数据。

返回：校验报告。

结构：

- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count 和 warning_count 等字段。

<a id="member-gfflowgraph-methods-validate_graph"></a>

### `validate_graph`

- API：`public`

```gdscript
func validate_graph() -> Dictionary:
```

校验流程图结构。

返回：校验报告。

结构：

- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、node_count、connection_count、summary、issues 和 next_action 等字段。

<a id="member-gfflowgraph-methods-build_editor_report"></a>

### `build_editor_report`

- API：`public`

```gdscript
func build_editor_report() -> Dictionary:
```

构建面向编辑器和可视化工具的流程图报告。

返回：包含校验、目录和编辑器元数据的报告。

结构：

- `return`: 包含 ok、healthy、summary、next_action、validation、catalog 和 editor 字段的 Dictionary。
