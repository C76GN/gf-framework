# GFInputContext

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_context.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

资源化输入上下文。 上下文用于表示一组可启停的输入映射，例如 gameplay、menu、dialogue。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`context_id`](#member-gfinputcontext-properties-context_id) | `var context_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfinputcontext-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`mappings`](#member-gfinputcontext-properties-mappings) | `var mappings: Array[GFInputMapping] = []` |
| 方法 | [`get_context_id`](#member-gfinputcontext-methods-get_context_id) | `func get_context_id() -> StringName:` |
| 方法 | [`get_display_name`](#member-gfinputcontext-methods-get_display_name) | `func get_display_name() -> String:` |

## 属性

<a id="member-gfinputcontext-properties-context_id"></a>

### `context_id`

- API：`public`

```gdscript
var context_id: StringName = &""
```

上下文稳定标识。

<a id="member-gfinputcontext-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

显示名称。

<a id="member-gfinputcontext-properties-mappings"></a>

### `mappings`

- API：`public`

```gdscript
var mappings: Array[GFInputMapping] = []
```

该上下文中的动作映射。

## 方法

<a id="member-gfinputcontext-methods-get_context_id"></a>

### `get_context_id`

- API：`public`

```gdscript
func get_context_id() -> StringName:
```

获取稳定上下文标识。

返回：上下文标识。

<a id="member-gfinputcontext-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取显示名称。

返回：显示名称。
