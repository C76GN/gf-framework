# GFSystem

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_system.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

逻辑层抽象基类。 负责实现核心业务逻辑。 子类可以实现 'init'、'async_init'、'ready'、'dispose' 来管理其生命周期。 三阶段初始化约定： - 'init'       阶段：只允许初始化自身内部变量，禁止跨模块获取依赖。 - 'async_init' 阶段：可使用 await，用于异步资源加载等操作。 - 'ready'      阶段：架构内所有模块均已完成 'init'，可安全跨模块获取依赖。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`ignore_pause`](#member-gfsystem-properties-ignore_pause) | `var ignore_pause: bool = false:` |
| 属性 | [`ignore_time_scale`](#member-gfsystem-properties-ignore_time_scale) | `var ignore_time_scale: bool = false:` |
| 属性 | [`lifecycle_priority`](#member-gfsystem-properties-lifecycle_priority) | `var lifecycle_priority: int = 0` |
| 属性 | [`tick_priority`](#member-gfsystem-properties-tick_priority) | `var tick_priority: int = 0:` |
| 属性 | [`physics_tick_priority`](#member-gfsystem-properties-physics_tick_priority) | `var physics_tick_priority: int = 0:` |
| 属性 | [`tick_enabled`](#member-gfsystem-properties-tick_enabled) | `var tick_enabled: bool = false:` |
| 属性 | [`physics_tick_enabled`](#member-gfsystem-properties-physics_tick_enabled) | `var physics_tick_enabled: bool = false:` |
| 方法 | [`init`](#member-gfsystem-methods-init) | `func init() -> void:` |
| 方法 | [`async_init`](#member-gfsystem-methods-async_init) | `func async_init(_scope: GFAsyncScope) -> void:` |
| 方法 | [`ready`](#member-gfsystem-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfsystem-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`release_dependencies`](#member-gfsystem-methods-release_dependencies) | `func release_dependencies() -> void:` |
| 方法 | [`tick`](#member-gfsystem-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`physics_tick`](#member-gfsystem-methods-physics_tick) | `func physics_tick(_delta: float) -> void:` |
| 方法 | [`is_lifecycle_active`](#member-gfsystem-methods-is_lifecycle_active) | `func is_lifecycle_active() -> bool:` |
| 方法 | [`is_ready_in_architecture`](#member-gfsystem-methods-is_ready_in_architecture) | `func is_ready_in_architecture() -> bool:` |
| 方法 | [`get_model`](#member-gfsystem-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfsystem-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfsystem-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`register_event`](#member-gfsystem-methods-register_event) | `func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_event`](#member-gfsystem-methods-unregister_event) | `func unregister_event(event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_assignable_event`](#member-gfsystem-methods-register_assignable_event) | `func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfsystem-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`send_event`](#member-gfsystem-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`register_simple_event`](#member-gfsystem-methods-register_simple_event) | `func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_simple_event`](#member-gfsystem-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`send_simple_event`](#member-gfsystem-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |

## 属性

<a id="member-gfsystem-properties-ignore_pause"></a>

### `ignore_pause`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var ignore_pause: bool = false:
```

是否忽略全局暂停。为 true 时，即使当前 GFTimeProvider 处于暂停状态， 该 System 仍会接收到原始（未缩放）的 delta 值。 典型场景：暂停菜单动画、设置界面过渡效果等。

<a id="member-gfsystem-properties-ignore_time_scale"></a>

### `ignore_time_scale`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var ignore_time_scale: bool = false:
```

是否忽略当前 GFTimeProvider 的时间缩放。为 true 且未全局暂停时， 该 System 的 tick / physics_tick 会接收到原始 delta。

<a id="member-gfsystem-properties-lifecycle_priority"></a>

### `lifecycle_priority`

- API：`public`

```gdscript
var lifecycle_priority: int = 0
```

生命周期优先级。数值越大越早执行 init/async_init/ready，dispose 时越晚释放。 默认 0 表示同优先级下按注册顺序执行；只有存在明确依赖顺序时才建议设置。

<a id="member-gfsystem-properties-tick_priority"></a>

### `tick_priority`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var tick_priority: int = 0:
```

每帧 tick 优先级。数值越大越早执行 tick()。 默认 0 表示同优先级下按注册顺序执行。

<a id="member-gfsystem-properties-physics_tick_priority"></a>

### `physics_tick_priority`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var physics_tick_priority: int = 0:
```

物理帧 tick 优先级。数值越大越早执行 physics_tick()。 默认 0 表示同优先级下按注册顺序执行。

<a id="member-gfsystem-properties-tick_enabled"></a>

### `tick_enabled`

- API：`public`

```gdscript
var tick_enabled: bool = false:
```

是否显式加入每帧 tick 缓存。 重写 tick() 的旧项目无需设置；仅在需要强制使用基类 tick 模板或动态 tick 入口时启用。

<a id="member-gfsystem-properties-physics_tick_enabled"></a>

### `physics_tick_enabled`

- API：`public`

```gdscript
var physics_tick_enabled: bool = false:
```

是否显式加入物理帧 tick 缓存。 重写 physics_tick() 的旧项目无需设置；仅在需要强制使用基类 physics_tick 模板或动态入口时启用。

## 方法

<a id="member-gfsystem-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化。子类可以重写此方法。 约束：只允许初始化自身内部变量，不得跨模块获取依赖。

<a id="member-gfsystem-methods-async_init"></a>

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

<a id="member-gfsystem-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

第三阶段初始化。子类可以重写此方法。 约束：此时所有模块已完成 'init'，可安全跨模块获取依赖。

<a id="member-gfsystem-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

销毁系统。子类可以重写此方法。

<a id="member-gfsystem-methods-release_dependencies"></a>

### `release_dependencies`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func release_dependencies() -> void:
```

释放架构注入作用域和模块缓存的外部依赖引用。 架构会在 dispose() 之后调用该方法；子类重写时应先释放自身缓存的 Model/System/Utility 引用，再调用 super.release_dependencies()。

<a id="member-gfsystem-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float) -> void:
```

每帧更新回调。子类可以重写此方法以实现帧逻辑。 由架构在 _process 中统一驱动，无需 System 继承 Node。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 距上一帧的时间（秒）。 |

<a id="member-gfsystem-methods-physics_tick"></a>

### `physics_tick`

- API：`public`

```gdscript
func physics_tick(_delta: float) -> void:
```

物理帧更新回调。子类可以重写此方法以实现物理帧逻辑。 由架构在 _physics_process 中统一驱动，无需 System 继承 Node。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 距上一物理帧的时间（秒）。 |

<a id="member-gfsystem-methods-is_lifecycle_active"></a>

### `is_lifecycle_active`

- API：`public`

```gdscript
func is_lifecycle_active() -> bool:
```

检查所属架构生命周期是否仍可安全继续异步写回。 async_init() 或其他 await 之后写入状态前建议检查该值。

返回：所属架构仍处于活动生命周期时返回 true。

<a id="member-gfsystem-methods-is_ready_in_architecture"></a>

### `is_ready_in_architecture`

- API：`public`

```gdscript
func is_ready_in_architecture() -> bool:
```

检查当前模块是否已经完成 ready 阶段。

返回：当前模块完成 ready 阶段时返回 true。

<a id="member-gfsystem-methods-get_model"></a>

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

<a id="member-gfsystem-methods-get_utility"></a>

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

<a id="member-gfsystem-methods-get_system"></a>

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

<a id="member-gfsystem-methods-register_event"></a>

### `register_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

注册类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听的脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfsystem-methods-unregister_event"></a>

### `unregister_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_event(event_type: Script, listener: GFEventListener) -> void:
```

注销类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfsystem-methods-register_assignable_event"></a>

### `register_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

注册可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听的基类脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfsystem-methods-unregister_assignable_event"></a>

### `unregister_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:
```

注销可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfsystem-methods-send_event"></a>

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

<a id="member-gfsystem-methods-register_simple_event"></a>

### `register_simple_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:
```

注册轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 简单事件监听器契约。 |

<a id="member-gfsystem-methods-unregister_simple_event"></a>

### `unregister_simple_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:
```

注销轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 要移除的简单事件监听器契约。 |

<a id="member-gfsystem-methods-send_simple_event"></a>

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
