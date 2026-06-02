# GFSequenceStep

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_sequence_step.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

可资源化的序列步骤基类。 子类重写 `execute()` 返回 `Signal` 时，`GFCommandSequence` 默认会等待该信号完成；也可以关闭 `wait_for_result` 让步骤异步旁路。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`step_id`](#member-gfsequencestep-properties-step_id) | `var step_id: StringName = &""` |
| 属性 | [`wait_for_result`](#member-gfsequencestep-properties-wait_for_result) | `var wait_for_result: bool = true` |
| 方法 | [`execute`](#member-gfsequencestep-methods-execute) | `func execute(_context: GFSequenceContext) -> Variant:` |
| 方法 | [`cancel`](#member-gfsequencestep-methods-cancel) | `func cancel(_context: GFSequenceContext) -> void:` |

## 属性

<a id="member-gfsequencestep-properties-step_id"></a>

### `step_id`

- API：`public`

```gdscript
var step_id: StringName = &""
```

步骤标识，便于调试和序列编辑器显示。

<a id="member-gfsequencestep-properties-wait_for_result"></a>

### `wait_for_result`

- API：`public`

```gdscript
var wait_for_result: bool = true
```

是否等待 `execute()` 返回的 Signal。

## 方法

<a id="member-gfsequencestep-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute(_context: GFSequenceContext) -> Variant:
```

执行步骤。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 序列上下文。 |

返回：可返回 null 或 Signal。

结构：

- `return`: Variant, null or Signal.

<a id="member-gfsequencestep-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel(_context: GFSequenceContext) -> void:
```

请求取消步骤。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 序列上下文。 |
