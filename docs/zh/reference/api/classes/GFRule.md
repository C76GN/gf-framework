# GFRule

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_rule.gd`
- 模块：`Kernel`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

数据驱动规则的抽象基类。 继承自 Resource，可在编辑器中配置并序列化为 .tres 文件。 GFSystem 作为规则的执行者，通过调用 execute() 驱动规则逻辑， 从而避免在 System 内硬编码业务分支，实现策略模式。 子类必须重写 execute() 以实现具体规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`execute`](#member-gfrule-methods-execute) | `func execute(_context: Object = null) -> Variant:` |
| 方法 | [`validate`](#member-gfrule-methods-validate) | `func validate() -> bool:` |

## 方法

<a id="member-gfrule-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute(_context: Object = null) -> Variant:
```

执行规则逻辑。子类必须重写此方法。 "type": "Variant", "description": "规则执行结果；异步规则可返回 Signal 供 await。" }

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 传递给规则的上下文数据，通常是一个 GFPayload 子类实例。 |

返回：规则执行结果，同步返回 Variant，异步返回一个 Signal 供 await。

结构：

- `return {`:

<a id="member-gfrule-methods-validate"></a>

### `validate`

- API：`public`

```gdscript
func validate() -> bool:
```

校验规则的配置数据是否合法。 子类可重写此方法以添加配置校验逻辑。

返回：配置合法返回 true，否则返回 false。
