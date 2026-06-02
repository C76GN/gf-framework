# GFTrait

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/traits/gf_trait.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用被动特征数据。 用于描述“某个来源对某个目标键产生的数值或标记影响”。 它不限定属性、伤害、装备等业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CombineMode`](#member-gftrait-enums-combinemode) | `enum CombineMode` |
| 属性 | [`trait_id`](#member-gftrait-properties-trait_id) | `var trait_id: StringName = &""` |
| 属性 | [`target_id`](#member-gftrait-properties-target_id) | `var target_id: StringName = &""` |
| 属性 | [`category`](#member-gftrait-properties-category) | `var category: StringName = &""` |
| 属性 | [`value`](#member-gftrait-properties-value) | `var value: float = 0.0` |
| 属性 | [`combine_mode`](#member-gftrait-properties-combine_mode) | `var combine_mode: CombineMode = CombineMode.ADD` |
| 属性 | [`priority`](#member-gftrait-properties-priority) | `var priority: int = 0` |
| 属性 | [`metadata`](#member-gftrait-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`apply_number`](#member-gftrait-methods-apply_number) | `func apply_number(current_value: float) -> float:` |

## 枚举

<a id="member-gftrait-enums-combinemode"></a>

### `CombineMode`

- API：`public`

```gdscript
enum CombineMode { ## 与当前值相加。 ADD,  ## 与当前值相乘。 MULTIPLY,  ## 直接覆盖当前值。 SET,  ## 取当前值与特征值中的较大值。 MAX,  ## 取当前值与特征值中的较小值。 MIN, }
```

数值合并方式。

## 属性

<a id="member-gftrait-properties-trait_id"></a>

### `trait_id`

- API：`public`

```gdscript
var trait_id: StringName = &""
```

特征标识。

<a id="member-gftrait-properties-target_id"></a>

### `target_id`

- API：`public`

```gdscript
var target_id: StringName = &""
```

目标键，例如属性名、规则名或项目自定义键。

<a id="member-gftrait-properties-category"></a>

### `category`

- API：`public`

```gdscript
var category: StringName = &""
```

可选分类，用于过滤不同规则域。

<a id="member-gftrait-properties-value"></a>

### `value`

- API：`public`

```gdscript
var value: float = 0.0
```

数值。

<a id="member-gftrait-properties-combine_mode"></a>

### `combine_mode`

- API：`public`

```gdscript
var combine_mode: CombineMode = CombineMode.ADD
```

合并方式。

<a id="member-gftrait-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

排序优先级，值越小越先应用。

<a id="member-gftrait-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义特征元数据；GF 不读取或改写其中字段。

## 方法

<a id="member-gftrait-methods-apply_number"></a>

### `apply_number`

- API：`public`

```gdscript
func apply_number(current_value: float) -> float:
```

将当前特征应用到数值上。

参数：

| 名称 | 说明 |
|---|---|
| `current_value` | 当前值。 |

返回：应用后的值。
