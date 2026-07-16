# GFFlowContext

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/runtime/gf_flow_context.gd`
- 模块：`Flow`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用流程图执行上下文。 用于在流程节点之间共享数据，并提供可选的 GFArchitecture 访问入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`values`](#member-gfflowcontext-properties-values) | `var values: Dictionary = {}` |
| 属性 | [`next_node_ids`](#member-gfflowcontext-properties-next_node_ids) | `var next_node_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`has_next_node_override`](#member-gfflowcontext-properties-has_next_node_override) | `var has_next_node_override: bool = false` |
| 方法 | [`set_architecture`](#member-gfflowcontext-methods-set_architecture) | `func set_architecture(architecture: GFArchitecture) -> void:` |
| 方法 | [`get_architecture`](#member-gfflowcontext-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`set_value`](#member-gfflowcontext-methods-set_value) | `func set_value(key: StringName, value: Variant) -> GFFlowContext:` |
| 方法 | [`get_value`](#member-gfflowcontext-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`set_next_nodes`](#member-gfflowcontext-methods-set_next_nodes) | `func set_next_nodes(node_ids: PackedStringArray) -> void:` |
| 方法 | [`has_next_nodes_override`](#member-gfflowcontext-methods-has_next_nodes_override) | `func has_next_nodes_override() -> bool:` |
| 方法 | [`clear_next_nodes`](#member-gfflowcontext-methods-clear_next_nodes) | `func clear_next_nodes() -> void:` |
| 方法 | [`register_condition_handler`](#member-gfflowcontext-methods-register_condition_handler) | `func register_condition_handler(condition_id: StringName, handler: Callable) -> bool:` |
| 方法 | [`unregister_condition_handler`](#member-gfflowcontext-methods-unregister_condition_handler) | `func unregister_condition_handler(condition_id: StringName) -> void:` |
| 方法 | [`has_condition_handler`](#member-gfflowcontext-methods-has_condition_handler) | `func has_condition_handler(condition_id: StringName) -> bool:` |
| 方法 | [`clear_condition_handlers`](#member-gfflowcontext-methods-clear_condition_handlers) | `func clear_condition_handlers() -> void:` |
| 方法 | [`query_condition`](#member-gfflowcontext-methods-query_condition) | `func query_condition( condition_id: StringName, payload: Variant = null, default_value: Variant = false ) -> Dictionary:` |
| 方法 | [`set_node_runtime_value`](#member-gfflowcontext-methods-set_node_runtime_value) | `func set_node_runtime_value(node_id: StringName, key: StringName, value: Variant) -> void:` |
| 方法 | [`get_node_runtime_value`](#member-gfflowcontext-methods-get_node_runtime_value) | `func get_node_runtime_value(node_id: StringName, key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`clear_node_runtime_state`](#member-gfflowcontext-methods-clear_node_runtime_state) | `func clear_node_runtime_state(node_id: StringName = &"") -> void:` |
| 方法 | [`create_runtime_snapshot`](#member-gfflowcontext-methods-create_runtime_snapshot) | `func create_runtime_snapshot(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`restore_runtime_snapshot`](#member-gfflowcontext-methods-restore_runtime_snapshot) | `func restore_runtime_snapshot(snapshot: Dictionary) -> bool:` |
| 方法 | [`serialize_runtime_state`](#member-gfflowcontext-methods-serialize_runtime_state) | `func serialize_runtime_state(json_compatible: bool = false) -> Dictionary:` |
| 方法 | [`deserialize_runtime_state`](#member-gfflowcontext-methods-deserialize_runtime_state) | `func deserialize_runtime_state(data: Dictionary) -> void:` |

## 属性

<a id="member-gfflowcontext-properties-values"></a>

### `values`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var values: Dictionary = {}
```

共享数据表。

结构：

- `values`: 流程执行期间共享的项目自定义 Dictionary；键通常为 StringName，值由项目决定。

<a id="member-gfflowcontext-properties-next_node_ids"></a>

### `next_node_ids`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var next_node_ids: PackedStringArray = PackedStringArray()
```

下一个节点覆盖。流程节点可写入该列表动态控制分支。

<a id="member-gfflowcontext-properties-has_next_node_override"></a>

### `has_next_node_override`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var has_next_node_override: bool = false
```

是否显式覆盖了下一个节点。允许节点用空列表表达“停止继续推进”。

## 方法

<a id="member-gfflowcontext-methods-set_architecture"></a>

### `set_architecture`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_architecture(architecture: GFArchitecture) -> void:
```

设置上下文所属架构。

参数：

| 名称 | 说明 |
|---|---|
| `architecture` | 架构实例。 |

<a id="member-gfflowcontext-methods-get_architecture"></a>

### `get_architecture`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_architecture() -> GFArchitecture:
```

获取上下文所属架构。

返回：架构实例；不可用时返回 null。

<a id="member-gfflowcontext-methods-set_value"></a>

### `set_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_value(key: StringName, value: Variant) -> GFFlowContext:
```

写入共享值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `value` | 值。 |

返回：当前上下文，便于链式构造。

结构：

- `value`: 要写入 values 的任意项目值。

<a id="member-gfflowcontext-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取共享值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `default_value` | 默认值。 |

返回：共享值或默认值。

结构：

- `default_value`: key 缺失时返回的任意默认值。
- `return`: values 中的项目值，或传入的 default_value。

<a id="member-gfflowcontext-methods-set_next_nodes"></a>

### `set_next_nodes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_next_nodes(node_ids: PackedStringArray) -> void:
```

覆盖当前节点执行后的下一个节点列表。

参数：

| 名称 | 说明 |
|---|---|
| `node_ids` | 节点标识列表。 |

<a id="member-gfflowcontext-methods-has_next_nodes_override"></a>

### `has_next_nodes_override`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func has_next_nodes_override() -> bool:
```

检查当前节点是否显式覆盖了后继节点。

返回：已覆盖返回 true。

<a id="member-gfflowcontext-methods-clear_next_nodes"></a>

### `clear_next_nodes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_next_nodes() -> void:
```

清空下一个节点覆盖。

<a id="member-gfflowcontext-methods-register_condition_handler"></a>

### `register_condition_handler`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func register_condition_handler(condition_id: StringName, handler: Callable) -> bool:
```

注册条件查询处理器。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件标识。 |
| `handler` | 查询回调，建议签名为 func(condition_id: StringName, payload: Variant, context: GFFlowContext) -> Variant。 |

返回：注册成功返回 true。

<a id="member-gfflowcontext-methods-unregister_condition_handler"></a>

### `unregister_condition_handler`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func unregister_condition_handler(condition_id: StringName) -> void:
```

注销条件查询处理器。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件标识。 |

<a id="member-gfflowcontext-methods-has_condition_handler"></a>

### `has_condition_handler`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func has_condition_handler(condition_id: StringName) -> bool:
```

检查条件查询处理器是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件标识。 |

返回：存在返回 true。

<a id="member-gfflowcontext-methods-clear_condition_handlers"></a>

### `clear_condition_handlers`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_condition_handlers() -> void:
```

清空所有条件查询处理器。

<a id="member-gfflowcontext-methods-query_condition"></a>

### `query_condition`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func query_condition( condition_id: StringName, payload: Variant = null, default_value: Variant = false ) -> Dictionary:
```

查询条件值。

参数：

| 名称 | 说明 |
|---|---|
| `condition_id` | 条件标识。 |
| `payload` | 调用方传入的载荷。 |
| `default_value` | 缺失处理器或处理器未返回值时使用的默认值。 |

返回：统一条件查询结果。

结构：

- `payload`: 条件处理器接收的任意项目载荷；框架只透传。
- `default_value`: 缺失处理器或处理器未返回值时使用的任意默认值。
- `return`: 包含 ok、condition_id、value、reason 和 metadata 字段的 Dictionary。

<a id="member-gfflowcontext-methods-set_node_runtime_value"></a>

### `set_node_runtime_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_node_runtime_value(node_id: StringName, key: StringName, value: Variant) -> void:
```

写入指定流程节点的运行态值。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `key` | 运行态键。 |
| `value` | 运行态值。 |

结构：

- `value`: 要写入指定节点运行态的任意项目值。

<a id="member-gfflowcontext-methods-get_node_runtime_value"></a>

### `get_node_runtime_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_node_runtime_value(node_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
```

读取指定流程节点的运行态值。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |
| `key` | 运行态键。 |
| `default_value` | 缺失时返回的默认值。 |

返回：运行态值或默认值。

结构：

- `default_value`: 运行态缺失时返回的任意默认值。
- `return`: 节点运行态中的项目值，或传入的 default_value。

<a id="member-gfflowcontext-methods-clear_node_runtime_state"></a>

### `clear_node_runtime_state`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_node_runtime_state(node_id: StringName = &"") -> void:
```

清空节点运行态。node_id 为空时清空全部节点运行态。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点标识。 |

<a id="member-gfflowcontext-methods-create_runtime_snapshot"></a>

### `create_runtime_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func create_runtime_snapshot(options: Dictionary = {}) -> Dictionary:
```

创建 Flow 上下文运行快照。 快照包含共享 values、下一个节点覆盖和节点运行态。条件处理器是运行时 Callable， 不会被序列化；恢复快照时也不会修改当前已注册的条件处理器。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 快照选项，支持 metadata、include_condition_handler_ids 和 json_compatible。 |

返回：运行快照。

结构：

- `options`: Dictionary，包含 metadata: Dictionary、include_condition_handler_ids: bool 与 json_compatible: bool。
- `return`: Dictionary，包含 values、next_node_ids、has_next_node_override、runtime_state、condition_handler_ids 和 metadata。

<a id="member-gfflowcontext-methods-restore_runtime_snapshot"></a>

### `restore_runtime_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func restore_runtime_snapshot(snapshot: Dictionary) -> bool:
```

恢复 Flow 上下文运行快照。 只恢复可序列化运行数据，不覆盖 architecture 或条件处理器。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | create_runtime_snapshot() 生成的快照。 |

返回：快照有效并完成恢复时返回 true。

结构：

- `snapshot`: Dictionary，包含 values、next_node_ids、has_next_node_override 和 runtime_state。

<a id="member-gfflowcontext-methods-serialize_runtime_state"></a>

### `serialize_runtime_state`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func serialize_runtime_state(json_compatible: bool = false) -> Dictionary:
```

序列化上下文持有的节点运行态。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时输出 JSON-safe 报告值；默认为 false，保留运行时原始 Variant。 |

返回：运行态快照。

结构：

- `return`: 包含 nodes 字段的 Dictionary；nodes 按 node_id 保存节点运行态 Dictionary。

<a id="member-gfflowcontext-methods-deserialize_runtime_state"></a>

### `deserialize_runtime_state`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func deserialize_runtime_state(data: Dictionary) -> void:
```

反序列化节点运行态到当前上下文。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 运行态快照。 |

结构：

- `data`: serialize_runtime_state() 返回的运行态 Dictionary。
