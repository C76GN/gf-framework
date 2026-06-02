# GFCommand

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_command.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

命令抽象基类。 子类必须实现 'execute' 方法来定义命令逻辑。 'execute' 可返回 null（同步命令）或一个 Signal（异步命令）。 调用方可使用 'await send_command(MyCommand.new())' 等待异步命令完成。 提供对 Model、System、Utility 的访问以及发送命令和事件的能力。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`execute`](#member-gfcommand-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`is_lifecycle_active`](#member-gfcommand-methods-is_lifecycle_active) | `func is_lifecycle_active() -> bool:` |
| 方法 | [`get_model`](#member-gfcommand-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfcommand-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfcommand-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`send_command`](#member-gfcommand-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfcommand-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfcommand-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |

## 方法

<a id="member-gfcommand-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行命令逻辑。子类必须重写此方法。 "type": "Variant", "description": "同步命令返回 null；异步命令可返回 Signal。" }

返回：同步命令返回 null；异步命令可返回一个 Signal 供外部 await。

结构：

- `return {`:

<a id="member-gfcommand-methods-is_lifecycle_active"></a>

### `is_lifecycle_active`

- API：`public`

```gdscript
func is_lifecycle_active() -> bool:
```

检查命令所属架构生命周期是否仍可安全继续异步写回。

返回：所属架构仍处于活动生命周期时返回 true。

<a id="member-gfcommand-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例。

<a id="member-gfcommand-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例。

<a id="member-gfcommand-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例。

<a id="member-gfcommand-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

向架构发送命令。支持 await：'await send_command(MyCommand.new())'。 "type": "Variant", "description": "命令执行结果；异步命令可返回 Signal。" }

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要发送的命令实例。 |

返回：命令的执行结果（null 或 Signal）。

结构：

- `return {`:

<a id="member-gfcommand-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

向架构发送类型事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfcommand-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。 "type": "Variant", "description": "事件附加数据；由事件消费者约定结构。" }

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 可选的事件附加数据。 |

结构：

- `payload {`:
