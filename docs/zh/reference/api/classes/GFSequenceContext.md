# GFSequenceContext

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_sequence_context.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

指令序列执行上下文。 用于在一组序列步骤之间传递共享数据，并为步骤提供架构访问入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`values`](#member-gfsequencecontext-properties-values) | `var values: Dictionary = {}` |
| 方法 | [`set_architecture`](#member-gfsequencecontext-methods-set_architecture) | `func set_architecture(architecture: GFArchitecture) -> void:` |
| 方法 | [`get_architecture`](#member-gfsequencecontext-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`set_value`](#member-gfsequencecontext-methods-set_value) | `func set_value(key: StringName, value: Variant) -> GFSequenceContext:` |
| 方法 | [`get_value`](#member-gfsequencecontext-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |

## 属性

<a id="member-gfsequencecontext-properties-values"></a>

### `values`

- API：`public`

```gdscript
var values: Dictionary = {}
```

共享数据表。

结构：

- `values`: Dictionary shared by sequence steps.

## 方法

<a id="member-gfsequencecontext-methods-set_architecture"></a>

### `set_architecture`

- API：`public`

```gdscript
func set_architecture(architecture: GFArchitecture) -> void:
```

设置上下文所属架构。

参数：

| 名称 | 说明 |
|---|---|
| `architecture` | 架构实例。 |

<a id="member-gfsequencecontext-methods-get_architecture"></a>

### `get_architecture`

- API：`public`

```gdscript
func get_architecture() -> GFArchitecture:
```

获取上下文所属架构。

返回：架构实例；不可用时返回 null。

<a id="member-gfsequencecontext-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant) -> GFSequenceContext:
```

写入共享值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `value` | 值。 |

返回：当前上下文，便于链式构造。

结构：

- `value`: Variant value stored in the sequence context.

<a id="member-gfsequencecontext-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取共享值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `default_value` | 默认值。 |

返回：共享值或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant stored value or fallback value.
