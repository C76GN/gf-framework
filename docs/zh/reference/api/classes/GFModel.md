# GFModel

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_model.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

数据层抽象基类。 负责管理应用数据和业务状态。 子类可以实现 'init'、'async_init'、'ready'、'dispose' 来管理其生命周期。 三阶段初始化约定： - 'init'       阶段：只允许初始化自身内部变量，禁止跨模块获取依赖。 - 'async_init' 阶段：可使用 await，用于异步资源加载等操作。 - 'ready'      阶段：架构内所有模块均已完成 'init'，可安全跨模块获取依赖。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`lifecycle_priority`](#member-gfmodel-properties-lifecycle_priority) | `var lifecycle_priority: int = 0` |
| 方法 | [`init`](#member-gfmodel-methods-init) | `func init() -> void:` |
| 方法 | [`async_init`](#member-gfmodel-methods-async_init) | `func async_init(_scope: GFAsyncScope) -> void:` |
| 方法 | [`ready`](#member-gfmodel-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfmodel-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`release_dependencies`](#member-gfmodel-methods-release_dependencies) | `func release_dependencies() -> void:` |
| 方法 | [`get_save_key`](#member-gfmodel-methods-get_save_key) | `func get_save_key() -> StringName:` |
| 方法 | [`to_dict`](#member-gfmodel-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfmodel-methods-from_dict) | `func from_dict(_data: Dictionary) -> void:` |
| 方法 | [`is_lifecycle_active`](#member-gfmodel-methods-is_lifecycle_active) | `func is_lifecycle_active() -> bool:` |
| 方法 | [`is_ready_in_architecture`](#member-gfmodel-methods-is_ready_in_architecture) | `func is_ready_in_architecture() -> bool:` |
| 方法 | [`get_utility`](#member-gfmodel-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`send_event`](#member-gfmodel-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfmodel-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |

## 属性

<a id="member-gfmodel-properties-lifecycle_priority"></a>

### `lifecycle_priority`

- API：`public`

```gdscript
var lifecycle_priority: int = 0
```

生命周期优先级。数值越大越早执行 init/async_init/ready，dispose 时越晚释放。 默认 0 表示同优先级下按注册顺序执行；只有存在明确依赖顺序时才建议设置。

## 方法

<a id="member-gfmodel-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化。子类可以重写此方法。 约束：只允许初始化自身内部变量，不得跨模块获取依赖。

<a id="member-gfmodel-methods-async_init"></a>

### `async_init`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func async_init(_scope: GFAsyncScope) -> void:
```

异步初始化阶段。子类可以重写此方法并在其中使用 await。 Godot 4 支持在 void 函数内部使用 await，框架的 Gf.init() 会串行且安全地 await 每个模块的 async_init()。 约束：在 init() 之后、ready() 之前执行；首个 await 前仍运行在主线程， 不应放入长同步工作。需要耗时处理时应在 await 或外部回调之间检查 scope。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前模块异步初始化的取消作用域。 |

<a id="member-gfmodel-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

第三阶段初始化。子类可以重写此方法。 约束：此时所有模块已完成 'init'，可安全跨模块获取依赖。

<a id="member-gfmodel-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

销毁模型。子类可以重写此方法。

<a id="member-gfmodel-methods-release_dependencies"></a>

### `release_dependencies`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func release_dependencies() -> void:
```

释放架构注入作用域和模块缓存的外部依赖引用。 架构会在 dispose() 之后调用该方法；子类重写时应先释放自身缓存的 Model/System/Utility 引用，再调用 super.release_dependencies()。

<a id="member-gfmodel-methods-get_save_key"></a>

### `get_save_key`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_save_key() -> StringName:
```

获取架构级存档使用的稳定键。 默认返回空字符串，表示由 GFArchitecture 使用 class_name。

返回：稳定存档键；为空时使用框架默认规则。

<a id="member-gfmodel-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

将此模型的状态序列化为字典，用于存档、状态快照等。 子类应重写此方法以包含所有需要持久化的字段。 "type": "Dictionary", "additional_properties": true }

返回：包含模型状态数据的字典。

结构：

- `return {`:

<a id="member-gfmodel-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(_data: Dictionary) -> void:
```

从字典反序列化并恢复此模型的状态。 子类应重写此方法以恢复所有相关字段。 "type": "Dictionary", "additional_properties": true }

参数：

| 名称 | 说明 |
|---|---|
| `_data` | 包含状态数据的字典（通常来自 to_dict() 的结果）。 |

结构：

- `_data {`:

<a id="member-gfmodel-methods-is_lifecycle_active"></a>

### `is_lifecycle_active`

- API：`public`

```gdscript
func is_lifecycle_active() -> bool:
```

检查所属架构生命周期是否仍可安全继续异步写回。 async_init() 或其他 await 之后写入状态前建议检查该值。

返回：所属架构仍处于活动生命周期时返回 true。

<a id="member-gfmodel-methods-is_ready_in_architecture"></a>

### `is_ready_in_architecture`

- API：`public`

```gdscript
func is_ready_in_architecture() -> bool:
```

检查当前模块是否已经完成 ready 阶段。

返回：当前模块完成 ready 阶段时返回 true。

<a id="member-gfmodel-methods-get_utility"></a>

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

<a id="member-gfmodel-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

向架构发送事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfmodel-methods-send_simple_event"></a>

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
