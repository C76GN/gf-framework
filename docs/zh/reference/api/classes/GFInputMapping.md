# GFInputMapping

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_mapping.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

单个动作的输入绑定集合。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`action`](#member-gfinputmapping-properties-action) | `var action: GFInputAction` |
| 属性 | [`bindings`](#member-gfinputmapping-properties-bindings) | `var bindings: Array[GFInputBinding] = []` |
| 属性 | [`modifiers`](#member-gfinputmapping-properties-modifiers) | `var modifiers: Array[GFInputModifier] = []` |
| 属性 | [`triggers`](#member-gfinputmapping-properties-triggers) | `var triggers: Array[GFInputTrigger] = []` |
| 属性 | [`display_name`](#member-gfinputmapping-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`display_category`](#member-gfinputmapping-properties-display_category) | `var display_category: String = ""` |
| 方法 | [`get_action_id`](#member-gfinputmapping-methods-get_action_id) | `func get_action_id() -> StringName:` |
| 方法 | [`get_display_name`](#member-gfinputmapping-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`get_display_category`](#member-gfinputmapping-methods-get_display_category) | `func get_display_category() -> String:` |

## 属性

<a id="member-gfinputmapping-properties-action"></a>

### `action`

- API：`public`

```gdscript
var action: GFInputAction
```

抽象输入动作。

<a id="member-gfinputmapping-properties-bindings"></a>

### `bindings`

- API：`public`

```gdscript
var bindings: Array[GFInputBinding] = []
```

动作绑定列表。多个绑定会合并为同一个动作值。

<a id="member-gfinputmapping-properties-modifiers"></a>

### `modifiers`

- API：`public`

```gdscript
var modifiers: Array[GFInputModifier] = []
```

映射级输入修饰器，按顺序作用于该动作聚合后的值。

<a id="member-gfinputmapping-properties-triggers"></a>

### `triggers`

- API：`public`

```gdscript
var triggers: Array[GFInputTrigger] = []
```

可选触发器，全部满足后动作才会被视为活跃。

<a id="member-gfinputmapping-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

可选显示名称覆盖。

<a id="member-gfinputmapping-properties-display_category"></a>

### `display_category`

- API：`public`

```gdscript
var display_category: String = ""
```

可选显示分类覆盖。

## 方法

<a id="member-gfinputmapping-methods-get_action_id"></a>

### `get_action_id`

- API：`public`

```gdscript
func get_action_id() -> StringName:
```

获取动作标识。

返回：稳定动作标识。

<a id="member-gfinputmapping-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取显示名称。

返回：显示名称。

<a id="member-gfinputmapping-methods-get_display_category"></a>

### `get_display_category`

- API：`public`

```gdscript
func get_display_category() -> String:
```

获取显示分类。

返回：显示分类。
