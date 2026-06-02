# GFWaitSequenceStep

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_wait_sequence_step.gd`
- 模块：`Standard`
- 继承：`GFSequenceStep`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用等待步骤。 用于在 `GFCommandSequence` 中插入时间间隔。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`duration`](#member-gfwaitsequencestep-properties-duration) | `var duration: float = 0.0` |
| 属性 | [`respect_engine_time_scale`](#member-gfwaitsequencestep-properties-respect_engine_time_scale) | `var respect_engine_time_scale: bool = true` |
| 方法 | [`execute`](#member-gfwaitsequencestep-methods-execute) | `func execute(_context: GFSequenceContext) -> Variant:` |

## 属性

<a id="member-gfwaitsequencestep-properties-duration"></a>

### `duration`

- API：`public`

```gdscript
var duration: float = 0.0
```

等待时长，单位秒。

<a id="member-gfwaitsequencestep-properties-respect_engine_time_scale"></a>

### `respect_engine_time_scale`

- API：`public`

```gdscript
var respect_engine_time_scale: bool = true
```

是否受 Engine.time_scale 影响。

## 方法

<a id="member-gfwaitsequencestep-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute(_context: GFSequenceContext) -> Variant:
```

执行等待步骤。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 序列上下文。 |

返回：等待用 Signal，时长小于等于 0 时返回 null。

结构：

- `return`: Variant, null or Signal.
