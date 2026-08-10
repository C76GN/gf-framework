# GFActionInterceptor

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/core/gf_action_interceptor.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

动作队列的通用拦截器基类。 拦截器可在表现动作执行前后做横切处理，例如跳过、替换、停止后续队列、 记录诊断或根据运行时状态调整表现，不绑定任何具体玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`priority`](#member-gfactioninterceptor-properties-priority) | `var priority: int = 0` |
| 属性 | [`enabled`](#member-gfactioninterceptor-properties-enabled) | `var enabled: bool = true` |
| 方法 | [`_before_execute`](#member-gfactioninterceptor-methods-_before_execute) | `func _before_execute( _action: Object, _queue: GFActionQueueSystem ) -> GFActionInterceptionResult:` |
| 方法 | [`_after_execute`](#member-gfactioninterceptor-methods-_after_execute) | `func _after_execute( _action: Object, _queue: GFActionQueueSystem, _execute_result: Variant ) -> GFActionInterceptionResult:` |

## 属性

<a id="member-gfactioninterceptor-properties-priority"></a>

### `priority`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var priority: int = 0
```

拦截器优先级，数值越大越早执行。运行期修改从下一次拦截阶段快照开始生效； 相同优先级按注册顺序执行。

<a id="member-gfactioninterceptor-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用当前拦截器。

## 方法

<a id="member-gfactioninterceptor-methods-_before_execute"></a>

### `_before_execute`

- API：`protected`

```gdscript
func _before_execute( _action: Object, _queue: GFActionQueueSystem ) -> GFActionInterceptionResult:
```

动作执行前调用。

参数：

| 名称 | 说明 |
|---|---|
| `_action` | 即将执行的动作。 |
| `_queue` | 当前动作队列。 |

返回：拦截结果；返回 null 等价于继续。

<a id="member-gfactioninterceptor-methods-_after_execute"></a>

### `_after_execute`

- API：`protected`

```gdscript
func _after_execute( _action: Object, _queue: GFActionQueueSystem, _execute_result: Variant ) -> GFActionInterceptionResult:
```

动作执行并完成等待后调用。

参数：

| 名称 | 说明 |
|---|---|
| `_action` | 已执行的动作。 |
| `_queue` | 当前动作队列。 |
| `_execute_result` | 动作 execute() 的原始返回值。 |

返回：拦截结果；当前仅 STOP_QUEUE 会影响后续队列。

结构：

- `_execute_result`: Variant，由动作 execute() 返回的原始结果，可能是 Signal 或项目自定义值。
