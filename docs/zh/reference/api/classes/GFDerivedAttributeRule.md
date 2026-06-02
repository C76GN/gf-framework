# GFDerivedAttributeRule

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/attributes/gf_derived_attribute_rule.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用派生属性规则。 通过权重或自定义回调从 GFAttributeSet 的其他属性计算目标属性，不规定属性业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MIN_VALUE`](#member-gfderivedattributerule-constants-default_min_value) | `const DEFAULT_MIN_VALUE: float = -1.0e20` |
| 常量 | [`DEFAULT_MAX_VALUE`](#member-gfderivedattributerule-constants-default_max_value) | `const DEFAULT_MAX_VALUE: float = 1.0e20` |
| 属性 | [`attribute_id`](#member-gfderivedattributerule-properties-attribute_id) | `var attribute_id: StringName = &""` |
| 属性 | [`source_attribute_ids`](#member-gfderivedattributerule-properties-source_attribute_ids) | `var source_attribute_ids: Array[StringName] = []` |
| 属性 | [`source_weights`](#member-gfderivedattributerule-properties-source_weights) | `var source_weights: Dictionary = {}` |
| 属性 | [`flat_bonus`](#member-gfderivedattributerule-properties-flat_bonus) | `var flat_bonus: float = 0.0` |
| 属性 | [`min_value`](#member-gfderivedattributerule-properties-min_value) | `var min_value: float = DEFAULT_MIN_VALUE` |
| 属性 | [`max_value`](#member-gfderivedattributerule-properties-max_value) | `var max_value: float = DEFAULT_MAX_VALUE` |
| 属性 | [`sync_base_value`](#member-gfderivedattributerule-properties-sync_base_value) | `var sync_base_value: bool = false` |
| 属性 | [`compute_callback`](#member-gfderivedattributerule-properties-compute_callback) | `var compute_callback: Callable = Callable()` |
| 方法 | [`calculate`](#member-gfderivedattributerule-methods-calculate) | `func calculate(attribute_set: Object) -> float:` |
| 方法 | [`get_source_attribute_ids`](#member-gfderivedattributerule-methods-get_source_attribute_ids) | `func get_source_attribute_ids() -> Array[StringName]:` |
| 方法 | [`get_source_weight`](#member-gfderivedattributerule-methods-get_source_weight) | `func get_source_weight(source_attribute_id: StringName) -> float:` |
| 方法 | [`depends_on`](#member-gfderivedattributerule-methods-depends_on) | `func depends_on(source_attribute_id: StringName) -> bool:` |
| 方法 | [`duplicate_rule`](#member-gfderivedattributerule-methods-duplicate_rule) | `func duplicate_rule() -> GFDerivedAttributeRule:` |

## 常量

<a id="member-gfderivedattributerule-constants-default_min_value"></a>

### `DEFAULT_MIN_VALUE`

- API：`public`

```gdscript
const DEFAULT_MIN_VALUE: float = -1.0e20
```

默认规则最小值。

<a id="member-gfderivedattributerule-constants-default_max_value"></a>

### `DEFAULT_MAX_VALUE`

- API：`public`

```gdscript
const DEFAULT_MAX_VALUE: float = 1.0e20
```

默认规则最大值。

## 属性

<a id="member-gfderivedattributerule-properties-attribute_id"></a>

### `attribute_id`

- API：`public`

```gdscript
var attribute_id: StringName = &""
```

被写入的目标属性 ID。

<a id="member-gfderivedattributerule-properties-source_attribute_ids"></a>

### `source_attribute_ids`

- API：`public`

```gdscript
var source_attribute_ids: Array[StringName] = []
```

参与计算的来源属性 ID。为空时使用 source_weights 的键。

结构：

- `source_attribute_ids`: Array[StringName]，参与当前派生规则计算的来源属性 ID 列表。

<a id="member-gfderivedattributerule-properties-source_weights"></a>

### `source_weights`

- API：`public`

```gdscript
var source_weights: Dictionary = {}
```

来源属性权重，键为属性 ID，值为数字权重。

结构：

- `source_weights`: Dictionary，键为 StringName 或 String 属性 ID，值为 float 权重。

<a id="member-gfderivedattributerule-properties-flat_bonus"></a>

### `flat_bonus`

- API：`public`

```gdscript
var flat_bonus: float = 0.0
```

固定加值。

<a id="member-gfderivedattributerule-properties-min_value"></a>

### `min_value`

- API：`public`

```gdscript
var min_value: float = DEFAULT_MIN_VALUE
```

规则级最小值。

<a id="member-gfderivedattributerule-properties-max_value"></a>

### `max_value`

- API：`public`

```gdscript
var max_value: float = DEFAULT_MAX_VALUE
```

规则级最大值。

<a id="member-gfderivedattributerule-properties-sync_base_value"></a>

### `sync_base_value`

- API：`public`

```gdscript
var sync_base_value: bool = false
```

是否同步写入目标属性的 base 值。

<a id="member-gfderivedattributerule-properties-compute_callback"></a>

### `compute_callback`

- API：`public`

```gdscript
var compute_callback: Callable = Callable()
```

自定义计算回调，建议签名为 func(attribute_set: GFAttributeSet, rule: GFDerivedAttributeRule) -> Variant。

## 方法

<a id="member-gfderivedattributerule-methods-calculate"></a>

### `calculate`

- API：`public`

```gdscript
func calculate(attribute_set: Object) -> float:
```

计算派生属性值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_set` | 属性集合。 |

返回：计算后的数值。

<a id="member-gfderivedattributerule-methods-get_source_attribute_ids"></a>

### `get_source_attribute_ids`

- API：`public`

```gdscript
func get_source_attribute_ids() -> Array[StringName]:
```

获取来源属性 ID 列表。

返回：来源属性 ID 副本。

结构：

- `return`: Array[StringName]，当前规则实际使用的来源属性 ID 列表。

<a id="member-gfderivedattributerule-methods-get_source_weight"></a>

### `get_source_weight`

- API：`public`

```gdscript
func get_source_weight(source_attribute_id: StringName) -> float:
```

获取来源属性权重。

参数：

| 名称 | 说明 |
|---|---|
| `source_attribute_id` | 来源属性 ID。 |

返回：权重；未配置时返回 1。

<a id="member-gfderivedattributerule-methods-depends_on"></a>

### `depends_on`

- API：`public`

```gdscript
func depends_on(source_attribute_id: StringName) -> bool:
```

判断是否依赖指定属性。

参数：

| 名称 | 说明 |
|---|---|
| `source_attribute_id` | 来源属性 ID。 |

返回：依赖返回 true。

<a id="member-gfderivedattributerule-methods-duplicate_rule"></a>

### `duplicate_rule`

- API：`public`

```gdscript
func duplicate_rule() -> GFDerivedAttributeRule:
```

创建当前规则的深拷贝。

返回：规则副本。
