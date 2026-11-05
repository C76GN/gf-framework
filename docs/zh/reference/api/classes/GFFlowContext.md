# GFFlowContext

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/runtime/gf_flow_context.gd`
- 模块：`Flow`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

各次流程运行共享的业务上下文。 用于在流程节点之间共享数据，并提供可选的 GFArchitecture 访问入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`values`](#member-gfflowcontext-properties-values) | `var values: Dictionary = {}` |
| 方法 | [`set_architecture`](#member-gfflowcontext-methods-set_architecture) | `func set_architecture(architecture: GFArchitecture) -> void:` |
| 方法 | [`get_architecture`](#member-gfflowcontext-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`set_value`](#member-gfflowcontext-methods-set_value) | `func set_value(key: StringName, value: Variant) -> GFFlowContext:` |
| 方法 | [`get_value`](#member-gfflowcontext-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`register_condition_handler`](#member-gfflowcontext-methods-register_condition_handler) | `func register_condition_handler(condition_id: StringName, handler: Callable) -> bool:` |
| 方法 | [`unregister_condition_handler`](#member-gfflowcontext-methods-unregister_condition_handler) | `func unregister_condition_handler(condition_id: StringName) -> void:` |
| 方法 | [`has_condition_handler`](#member-gfflowcontext-methods-has_condition_handler) | `func has_condition_handler(condition_id: StringName) -> bool:` |
| 方法 | [`clear_condition_handlers`](#member-gfflowcontext-methods-clear_condition_handlers) | `func clear_condition_handlers() -> void:` |
| 方法 | [`query_condition`](#member-gfflowcontext-methods-query_condition) | `func query_condition( condition_id: StringName, payload: Variant = null, default_value: Variant = false ) -> Dictionary:` |
| 方法 | [`create_data_snapshot`](#member-gfflowcontext-methods-create_data_snapshot) | `func create_data_snapshot(options: Dictionary = {}) -> Dictionary:` |

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

<a id="member-gfflowcontext-methods-create_data_snapshot"></a>

### `create_data_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func create_data_snapshot(options: Dictionary = {}) -> Dictionary:
```

捕获业务值和可选条件处理器标识。JSON 投影供日志使用，原始值副本供项目保存。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可提供 json_compatible、include_condition_handler_ids 和 metadata。 |

返回：独立业务数据快照。

结构：

- `options`: 可选布尔开关与项目附加的 metadata 字典。
- `return`: 包含 values、metadata 以及可选 condition_handler_ids。
