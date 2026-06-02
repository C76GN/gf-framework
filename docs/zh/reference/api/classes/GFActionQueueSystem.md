# GFActionQueueSystem

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/core/gf_action_queue_system.gd`
- 模块：`Action Queue`
- 继承：`GFSystem`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

逻辑与表现解耦的动作队列系统。 负责串行或并行消费动作对象，并在等待 Signal 时对发射源失效做防死锁保护。 动作可继承 `GFVisualAction`，也可直接实现 execute()/can_execute()/cancel() 等同名协议方法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`queue_drained`](#member-gfactionqueuesystem-signals-queue_drained) | `signal queue_drained` |
| 属性 | [`is_processing`](#member-gfactionqueuesystem-properties-is_processing) | `var is_processing: bool = false` |
| 方法 | [`init`](#member-gfactionqueuesystem-methods-init) | `func init() -> void:` |
| 方法 | [`ready`](#member-gfactionqueuesystem-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfactionqueuesystem-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`enqueue`](#member-gfactionqueuesystem-methods-enqueue) | `func enqueue(action: Object) -> void:` |
| 方法 | [`enqueue_fire_and_forget`](#member-gfactionqueuesystem-methods-enqueue_fire_and_forget) | `func enqueue_fire_and_forget(action: Object) -> void:` |
| 方法 | [`enqueue_parallel`](#member-gfactionqueuesystem-methods-enqueue_parallel) | `func enqueue_parallel(actions: Array) -> void:` |
| 方法 | [`push_front`](#member-gfactionqueuesystem-methods-push_front) | `func push_front(action: Object) -> void:` |
| 方法 | [`push_front_fire_and_forget`](#member-gfactionqueuesystem-methods-push_front_fire_and_forget) | `func push_front_fire_and_forget(action: Object) -> void:` |
| 方法 | [`push_front_parallel`](#member-gfactionqueuesystem-methods-push_front_parallel) | `func push_front_parallel(actions: Array) -> void:` |
| 方法 | [`clear_queue`](#member-gfactionqueuesystem-methods-clear_queue) | `func clear_queue(stop_current: bool = false) -> void:` |
| 方法 | [`get_named_queue`](#member-gfactionqueuesystem-methods-get_named_queue) | `func get_named_queue(queue_name: StringName) -> GFActionQueueSystem:` |
| 方法 | [`get_linked_queue`](#member-gfactionqueuesystem-methods-get_linked_queue) | `func get_linked_queue(queue_name: StringName, linked_node: Node) -> GFActionQueueSystem:` |
| 方法 | [`bind_to_node`](#member-gfactionqueuesystem-methods-bind_to_node) | `func bind_to_node(linked_node: Node) -> void:` |
| 方法 | [`add_interceptor`](#member-gfactionqueuesystem-methods-add_interceptor) | `func add_interceptor(interceptor: GFActionInterceptor) -> bool:` |
| 方法 | [`remove_interceptor`](#member-gfactionqueuesystem-methods-remove_interceptor) | `func remove_interceptor(interceptor: GFActionInterceptor) -> bool:` |
| 方法 | [`set_interceptors`](#member-gfactionqueuesystem-methods-set_interceptors) | `func set_interceptors(interceptors: Array[GFActionInterceptor]) -> void:` |
| 方法 | [`clear_interceptors`](#member-gfactionqueuesystem-methods-clear_interceptors) | `func clear_interceptors() -> void:` |
| 方法 | [`get_interceptors`](#member-gfactionqueuesystem-methods-get_interceptors) | `func get_interceptors() -> Array[GFActionInterceptor]:` |
| 方法 | [`enqueue_to`](#member-gfactionqueuesystem-methods-enqueue_to) | `func enqueue_to(queue_name: StringName, action: Object) -> void:` |
| 方法 | [`enqueue_fire_and_forget_to`](#member-gfactionqueuesystem-methods-enqueue_fire_and_forget_to) | `func enqueue_fire_and_forget_to(queue_name: StringName, action: Object) -> void:` |
| 方法 | [`enqueue_parallel_to`](#member-gfactionqueuesystem-methods-enqueue_parallel_to) | `func enqueue_parallel_to(queue_name: StringName, actions: Array) -> void:` |
| 方法 | [`push_front_to`](#member-gfactionqueuesystem-methods-push_front_to) | `func push_front_to(queue_name: StringName, action: Object) -> void:` |
| 方法 | [`clear_named_queue`](#member-gfactionqueuesystem-methods-clear_named_queue) | `func clear_named_queue(queue_name: StringName, stop_current: bool = false) -> void:` |
| 方法 | [`clear_all_named_queues`](#member-gfactionqueuesystem-methods-clear_all_named_queues) | `func clear_all_named_queues(stop_current: bool = false) -> void:` |
| 方法 | [`skip_current_action`](#member-gfactionqueuesystem-methods-skip_current_action) | `func skip_current_action() -> void:` |
| 方法 | [`pause_current_action`](#member-gfactionqueuesystem-methods-pause_current_action) | `func pause_current_action() -> bool:` |
| 方法 | [`resume_current_action`](#member-gfactionqueuesystem-methods-resume_current_action) | `func resume_current_action() -> bool:` |
| 方法 | [`finish_current_action`](#member-gfactionqueuesystem-methods-finish_current_action) | `func finish_current_action() -> void:` |
| 方法 | [`get_current_action`](#member-gfactionqueuesystem-methods-get_current_action) | `func get_current_action() -> Object:` |
| 方法 | [`get_debug_snapshot`](#member-gfactionqueuesystem-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`tick`](#member-gfactionqueuesystem-methods-tick) | `func tick(_delta: float) -> void:` |

## 信号

<a id="member-gfactionqueuesystem-signals-queue_drained"></a>

### `queue_drained`

- API：`public`

```gdscript
signal queue_drained
```

当队列从有内容变为全部执行完毕时发出。

## 属性

<a id="member-gfactionqueuesystem-properties-is_processing"></a>

### `is_processing`

- API：`public`

```gdscript
var is_processing: bool = false
```

是否正在处理队列。

## 方法

<a id="member-gfactionqueuesystem-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化主队列、命名队列和拦截器状态。

<a id="member-gfactionqueuesystem-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

注册诊断工具快照。

<a id="member-gfactionqueuesystem-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放当前队列、命名队列和诊断注册。

<a id="member-gfactionqueuesystem-methods-enqueue"></a>

### `enqueue`

- API：`public`

```gdscript
func enqueue(action: Object) -> void:
```

将一个动作加入顺序队列。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-enqueue_fire_and_forget"></a>

### `enqueue_fire_and_forget`

- API：`public`

```gdscript
func enqueue_fire_and_forget(action: Object) -> void:
```

将一个动作以显式 fire-and-forget 模式加入队列。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-enqueue_parallel"></a>

### `enqueue_parallel`

- API：`public`

```gdscript
func enqueue_parallel(actions: Array) -> void:
```

将一批动作加入队列并并行执行。

参数：

| 名称 | 说明 |
|---|---|
| `actions` | 要处理的动作对象列表。 |

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfactionqueuesystem-methods-push_front"></a>

### `push_front`

- API：`public`

```gdscript
func push_front(action: Object) -> void:
```

将一个动作插入队列头部。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-push_front_fire_and_forget"></a>

### `push_front_fire_and_forget`

- API：`public`

```gdscript
func push_front_fire_and_forget(action: Object) -> void:
```

将一个动作以显式 fire-and-forget 模式插入队列头部。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-push_front_parallel"></a>

### `push_front_parallel`

- API：`public`

```gdscript
func push_front_parallel(actions: Array) -> void:
```

将一批并行动作插入队列头部。

参数：

| 名称 | 说明 |
|---|---|
| `actions` | 要处理的动作对象列表。 |

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfactionqueuesystem-methods-clear_queue"></a>

### `clear_queue`

- API：`public`

```gdscript
func clear_queue(stop_current: bool = false) -> void:
```

清空队列中尚未执行的动作。

参数：

| 名称 | 说明 |
|---|---|
| `stop_current` | 为 true 时同时取消当前正在等待 Signal 的动作队列消费。 |

<a id="member-gfactionqueuesystem-methods-get_named_queue"></a>

### `get_named_queue`

- API：`public`

```gdscript
func get_named_queue(queue_name: StringName) -> GFActionQueueSystem:
```

获取或创建一个命名动作队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |

返回：命名队列；queue_name 为空时返回 null。

<a id="member-gfactionqueuesystem-methods-get_linked_queue"></a>

### `get_linked_queue`

- API：`public`

```gdscript
func get_linked_queue(queue_name: StringName, linked_node: Node) -> GFActionQueueSystem:
```

创建或获取一个绑定到节点生命周期的命名队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |
| `linked_node` | 与队列生命周期绑定的节点。 |

返回：绑定后的命名队列；queue_name 为空时返回 null。

<a id="member-gfactionqueuesystem-methods-bind_to_node"></a>

### `bind_to_node`

- API：`public`

```gdscript
func bind_to_node(linked_node: Node) -> void:
```

将当前队列绑定到节点生命周期；节点失效后队列会停止并清空。

参数：

| 名称 | 说明 |
|---|---|
| `linked_node` | 与队列生命周期绑定的节点。 |

<a id="member-gfactionqueuesystem-methods-add_interceptor"></a>

### `add_interceptor`

- API：`public`

```gdscript
func add_interceptor(interceptor: GFActionInterceptor) -> bool:
```

添加动作执行拦截器。

参数：

| 名称 | 说明 |
|---|---|
| `interceptor` | 拦截器实例。 |

返回：添加成功返回 true。

<a id="member-gfactionqueuesystem-methods-remove_interceptor"></a>

### `remove_interceptor`

- API：`public`

```gdscript
func remove_interceptor(interceptor: GFActionInterceptor) -> bool:
```

移除动作执行拦截器。

参数：

| 名称 | 说明 |
|---|---|
| `interceptor` | 拦截器实例。 |

返回：移除成功返回 true。

<a id="member-gfactionqueuesystem-methods-set_interceptors"></a>

### `set_interceptors`

- API：`public`

```gdscript
func set_interceptors(interceptors: Array[GFActionInterceptor]) -> void:
```

批量替换动作执行拦截器。

参数：

| 名称 | 说明 |
|---|---|
| `interceptors` | 新拦截器列表。 |

<a id="member-gfactionqueuesystem-methods-clear_interceptors"></a>

### `clear_interceptors`

- API：`public`

```gdscript
func clear_interceptors() -> void:
```

清空动作执行拦截器。

<a id="member-gfactionqueuesystem-methods-get_interceptors"></a>

### `get_interceptors`

- API：`public`

```gdscript
func get_interceptors() -> Array[GFActionInterceptor]:
```

获取动作执行拦截器副本。

返回：拦截器列表副本。

<a id="member-gfactionqueuesystem-methods-enqueue_to"></a>

### `enqueue_to`

- API：`public`

```gdscript
func enqueue_to(queue_name: StringName, action: Object) -> void:
```

将动作加入指定命名队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-enqueue_fire_and_forget_to"></a>

### `enqueue_fire_and_forget_to`

- API：`public`

```gdscript
func enqueue_fire_and_forget_to(queue_name: StringName, action: Object) -> void:
```

将动作以 fire-and-forget 模式加入指定命名队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-enqueue_parallel_to"></a>

### `enqueue_parallel_to`

- API：`public`

```gdscript
func enqueue_parallel_to(queue_name: StringName, actions: Array) -> void:
```

将一批动作加入指定命名队列并行执行。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |
| `actions` | 要处理的动作对象列表。 |

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfactionqueuesystem-methods-push_front_to"></a>

### `push_front_to`

- API：`public`

```gdscript
func push_front_to(queue_name: StringName, action: Object) -> void:
```

将动作插入指定命名队列头部。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |
| `action` | 要处理的动作对象。 |

<a id="member-gfactionqueuesystem-methods-clear_named_queue"></a>

### `clear_named_queue`

- API：`public`

```gdscript
func clear_named_queue(queue_name: StringName, stop_current: bool = false) -> void:
```

清理指定命名队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 动作队列名称。 |
| `stop_current` | 是否停止当前正在执行的动作。 |

<a id="member-gfactionqueuesystem-methods-clear_all_named_queues"></a>

### `clear_all_named_queues`

- API：`public`

```gdscript
func clear_all_named_queues(stop_current: bool = false) -> void:
```

清理所有命名队列。

参数：

| 名称 | 说明 |
|---|---|
| `stop_current` | 是否停止当前正在执行的动作。 |

<a id="member-gfactionqueuesystem-methods-skip_current_action"></a>

### `skip_current_action`

- API：`public`

```gdscript
func skip_current_action() -> void:
```

跳过当前动作并继续消费后续动作。

<a id="member-gfactionqueuesystem-methods-pause_current_action"></a>

### `pause_current_action`

- API：`public`

```gdscript
func pause_current_action() -> bool:
```

暂停当前动作。

返回：存在当前动作时返回 true。

<a id="member-gfactionqueuesystem-methods-resume_current_action"></a>

### `resume_current_action`

- API：`public`

```gdscript
func resume_current_action() -> bool:
```

恢复当前动作。

返回：存在当前动作时返回 true。

<a id="member-gfactionqueuesystem-methods-finish_current_action"></a>

### `finish_current_action`

- API：`public`

```gdscript
func finish_current_action() -> void:
```

将当前动作标记为立即完成并继续消费后续动作。

<a id="member-gfactionqueuesystem-methods-get_current_action"></a>

### `get_current_action`

- API：`public`

```gdscript
func get_current_action() -> Object:
```

获取当前正在执行或等待的动作。

返回：当前动作；没有动作时返回 null。

<a id="member-gfactionqueuesystem-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取动作队列诊断快照。

返回：诊断快照字典。

结构：

- `return`: Dictionary，包含 is_processing、queued_count、has_current_action、processing_serial、named_queue_count、named_queues、linked_node_alive 和 interceptor_count。

<a id="member-gfactionqueuesystem-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float) -> void:
```

驱动命名队列的生命周期清理。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |
