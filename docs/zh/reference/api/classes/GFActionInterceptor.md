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

## 属性

<a id="member-gfactioninterceptor-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

拦截器优先级，数值越大越早执行。

<a id="member-gfactioninterceptor-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用当前拦截器。
