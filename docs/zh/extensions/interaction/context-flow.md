# 上下文与链式流程

`GFInteractionContext` 是轻量数据载体，用于在命令、事件或项目自定义方法之间传递 sender、target、payload 和可选分组名。

```gdscript
var context := GFInteractionContext.new(player, enemy, { "amount": 10 }, &"enemies")
```

也可以使用 `GFInteractions` 创建链式交互流程。`GFInteractions.with_sender(...)` 会返回 `GFInteractionFlow`，后者负责继续设置 target、payload、group，并在执行命令或发送事件前把 `GFInteractionContext` 注入到对象中。

```gdscript
var command := DealDamageCommand.new()
GFInteractions.with_sender(player).to(enemy).with_payload({ "amount": 10 }).execute(command)
```

`execute(command)` 会优先通过当前架构发送命令，找不到架构时才回退直接调用命令的 `execute()`。`send_event(event)` 必须依赖当前或全局架构，没有架构时不会派发。命令或事件可通过 `interaction_context` 属性或 `set_interaction_context(context)` 方法接收上下文。对于方法协议，Flow 会在调用前验证参数数量与 `GFInteractionContext` 类型兼容性；同名但要求其他类型的方法会被忽略，不会因名称碰撞产生脚本错误。

Interaction 扩展只组织一次性交互上下文。能力查询、冷却、权限、目标合法性或效果结算应由项目、外部扩展或独立插件显式装配。
