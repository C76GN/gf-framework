# GFFlowNode

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/resources/gf_flow_node.gd`
- 模块：`Flow`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用流程图节点基类。 节点只描述执行入口和默认后继节点。具体条件、命令、等待逻辑由项目继承实现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`node_id`](#member-gfflownode-properties-node_id) | `var node_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfflownode-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`category`](#member-gfflownode-properties-category) | `var category: StringName = &""` |
| 属性 | [`next_node_ids`](#member-gfflownode-properties-next_node_ids) | `var next_node_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`wait_for_result`](#member-gfflownode-properties-wait_for_result) | `var wait_for_result: bool = true` |
| 属性 | [`input_ports`](#member-gfflownode-properties-input_ports) | `var input_ports: Array[GFFlowPort] = []` |
| 属性 | [`output_ports`](#member-gfflownode-properties-output_ports) | `var output_ports: Array[GFFlowPort] = []` |
| 属性 | [`metadata`](#member-gfflownode-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`editor_position`](#member-gfflownode-properties-editor_position) | `var editor_position: Vector2 = Vector2.ZERO` |
| 属性 | [`editor_size`](#member-gfflownode-properties-editor_size) | `var editor_size: Vector2 = Vector2.ZERO` |
| 属性 | [`editor_collapsed`](#member-gfflownode-properties-editor_collapsed) | `var editor_collapsed: bool = false` |
| 方法 | [`execute`](#member-gfflownode-methods-execute) | `func execute(_context: GFFlowContext, _execution: GFFlowNodeExecution) -> Variant:` |
| 方法 | [`get_next_nodes`](#member-gfflownode-methods-get_next_nodes) | `func get_next_nodes(_context: GFFlowContext) -> PackedStringArray:` |
| 方法 | [`get_display_name`](#member-gfflownode-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`get_input_ports`](#member-gfflownode-methods-get_input_ports) | `func get_input_ports() -> Array[GFFlowPort]:` |
| 方法 | [`get_output_ports`](#member-gfflownode-methods-get_output_ports) | `func get_output_ports() -> Array[GFFlowPort]:` |
| 方法 | [`get_input_port`](#member-gfflownode-methods-get_input_port) | `func get_input_port(port_id: StringName) -> GFFlowPort:` |
| 方法 | [`get_output_port`](#member-gfflownode-methods-get_output_port) | `func get_output_port(port_id: StringName) -> GFFlowPort:` |
| 方法 | [`describe_ports`](#member-gfflownode-methods-describe_ports) | `func describe_ports() -> Dictionary:` |
| 方法 | [`describe_editor`](#member-gfflownode-methods-describe_editor) | `func describe_editor() -> Dictionary:` |
| 方法 | [`describe_node`](#member-gfflownode-methods-describe_node) | `func describe_node() -> Dictionary:` |

## 属性

<a id="member-gfflownode-properties-node_id"></a>

### `node_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var node_id: StringName = &""
```

节点稳定标识。

<a id="member-gfflownode-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var display_name: String = ""
```

节点显示名；为空时回退到 node_id。

<a id="member-gfflownode-properties-category"></a>

### `category`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var category: StringName = &""
```

节点分类，仅供编辑器、搜索或项目工具使用。

<a id="member-gfflownode-properties-next_node_ids"></a>

### `next_node_ids`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var next_node_ids: PackedStringArray = PackedStringArray()
```

默认后继节点列表。

<a id="member-gfflownode-properties-wait_for_result"></a>

### `wait_for_result`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var wait_for_result: bool = true
```

返回 Signal 时是否等待。

<a id="member-gfflownode-properties-input_ports"></a>

### `input_ports`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var input_ports: Array[GFFlowPort] = []
```

输入端口描述。仅用于编辑器、校验和项目层数据连接。

<a id="member-gfflownode-properties-output_ports"></a>

### `output_ports`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var output_ports: Array[GFFlowPort] = []
```

输出端口描述。仅用于编辑器、校验和项目层数据连接。

<a id="member-gfflownode-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

<a id="member-gfflownode-properties-editor_position"></a>

### `editor_position`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var editor_position: Vector2 = Vector2.ZERO
```

编辑器中的节点位置。

<a id="member-gfflownode-properties-editor_size"></a>

### `editor_size`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var editor_size: Vector2 = Vector2.ZERO
```

编辑器中的节点尺寸；为 ZERO 时表示由编辑器自行决定。

<a id="member-gfflownode-properties-editor_collapsed"></a>

### `editor_collapsed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
@export
var editor_collapsed: bool = false
```

编辑器中是否折叠显示。

## 方法

<a id="member-gfflownode-methods-execute"></a>

### `execute`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func execute(_context: GFFlowContext, _execution: GFFlowNodeExecution) -> Variant:
```

执行节点。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 各次流程运行可共享的业务上下文。 |
| `_execution` | 当前帧本次节点调用独有的运行状态写入句柄。 |

返回：可返回 null 或 Signal。

结构：

- `return`: null、Signal 或项目节点实现约定的结果值。

<a id="member-gfflownode-methods-get_next_nodes"></a>

### `get_next_nodes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_next_nodes(_context: GFFlowContext) -> PackedStringArray:
```

获取执行完成后的后继节点。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 调度默认后继时可读取的业务上下文。 |

返回：后继节点标识列表。

<a id="member-gfflownode-methods-get_display_name"></a>

### `get_display_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_display_name() -> String:
```

获取节点显示名。

返回：显示名。

<a id="member-gfflownode-methods-get_input_ports"></a>

### `get_input_ports`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_input_ports() -> Array[GFFlowPort]:
```

获取输入端口。

返回：输入端口数组。

<a id="member-gfflownode-methods-get_output_ports"></a>

### `get_output_ports`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_output_ports() -> Array[GFFlowPort]:
```

获取输出端口。

返回：输出端口数组。

<a id="member-gfflownode-methods-get_input_port"></a>

### `get_input_port`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_input_port(port_id: StringName) -> GFFlowPort:
```

按端口标识查找输入端口。

参数：

| 名称 | 说明 |
|---|---|
| `port_id` | 端口标识。 |

返回：输入端口；不存在时返回 null。

<a id="member-gfflownode-methods-get_output_port"></a>

### `get_output_port`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_output_port(port_id: StringName) -> GFFlowPort:
```

按端口标识查找输出端口。

参数：

| 名称 | 说明 |
|---|---|
| `port_id` | 端口标识。 |

返回：输出端口；不存在时返回 null。

<a id="member-gfflownode-methods-describe_ports"></a>

### `describe_ports`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func describe_ports() -> Dictionary:
```

描述节点端口。

返回：端口描述字典。

结构：

- `return`: 包含 inputs 和 outputs 字段的 Dictionary；每个字段为端口描述数组。

<a id="member-gfflownode-methods-describe_editor"></a>

### `describe_editor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func describe_editor() -> Dictionary:
```

描述节点编辑器元数据。

返回：编辑器元数据字典。

结构：

- `return`: 包含 display_name、category、position、size 和 collapsed 字段的 Dictionary。

<a id="member-gfflownode-methods-describe_node"></a>

### `describe_node`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func describe_node() -> Dictionary:
```

描述节点。

返回：节点描述字典。

结构：

- `return`: 包含 node_id、display_name、category、next_node_ids、wait_for_result、ports、editor 和 metadata 字段的 Dictionary。
