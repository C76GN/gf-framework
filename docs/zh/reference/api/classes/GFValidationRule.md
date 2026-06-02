# GFValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_rule.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用校验规则资源。 通过 Callable 或子类钩子校验任意对象、资源、节点或数据。规则只负责把问题写入 GFValidationReport，不约定项目脚本方法名，也不内置业务字段语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`TargetKind`](#member-gfvalidationrule-enums-targetkind) | `enum TargetKind` |
| 属性 | [`rule_id`](#member-gfvalidationrule-properties-rule_id) | `var rule_id: StringName = &""` |
| 属性 | [`description`](#member-gfvalidationrule-properties-description) | `var description: String = ""` |
| 属性 | [`target_kind`](#member-gfvalidationrule-properties-target_kind) | `var target_kind: TargetKind = TargetKind.ANY` |
| 属性 | [`enabled`](#member-gfvalidationrule-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`severity`](#member-gfvalidationrule-properties-severity) | `var severity: GFValidationIssue.Severity = GFValidationIssue.Severity.ERROR` |
| 属性 | [`metadata`](#member-gfvalidationrule-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`callback`](#member-gfvalidationrule-properties-callback) | `var callback: Callable = Callable()` |
| 方法 | [`configure`](#member-gfvalidationrule-methods-configure) | `func configure( p_rule_id: StringName, p_callback: Callable = Callable(), options: Dictionary = {} ) -> GFValidationRule:` |
| 方法 | [`applies_to`](#member-gfvalidationrule-methods-applies_to) | `func applies_to(target: Variant, context: Dictionary = {}) -> bool:` |
| 方法 | [`validate`](#member-gfvalidationrule-methods-validate) | `func validate(target: Variant, context: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`duplicate_rule`](#member-gfvalidationrule-methods-duplicate_rule) | `func duplicate_rule() -> GFValidationRule:` |

## 枚举

<a id="member-gfvalidationrule-enums-targetkind"></a>

### `TargetKind`

- API：`public`

```gdscript
enum TargetKind { ## 接受任意目标。 ANY, ## 接受 Node。 NODE, ## 接受 Resource。 RESOURCE, ## 接受 PackedScene。 PACKED_SCENE, ## 接受 Dictionary。 DICTIONARY, ## 接受 Array。 ARRAY, ## 接受 Object。 OBJECT, }
```

规则适用的目标类型。

## 属性

<a id="member-gfvalidationrule-properties-rule_id"></a>

### `rule_id`

- API：`public`

```gdscript
var rule_id: StringName = &""
```

规则唯一标识。推荐使用稳定的 snake_case 或点分层级标识。

<a id="member-gfvalidationrule-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

面向工具或报告的规则说明。

<a id="member-gfvalidationrule-properties-target_kind"></a>

### `target_kind`

- API：`public`

```gdscript
var target_kind: TargetKind = TargetKind.ANY
```

规则适用的目标类型。

<a id="member-gfvalidationrule-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该规则。

<a id="member-gfvalidationrule-properties-severity"></a>

### `severity`

- API：`public`

```gdscript
var severity: GFValidationIssue.Severity = GFValidationIssue.Severity.ERROR
```

当 Callable 或钩子返回 false / 非空字符串时使用的默认严重级别。

<a id="member-gfvalidationrule-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary of caller-defined rule metadata.

<a id="member-gfvalidationrule-properties-callback"></a>

### `callback`

- API：`public`

```gdscript
var callback: Callable = Callable()
```

可选校验回调，签名为 func(target: Variant, report: GFValidationReport, context: Dictionary) -> Variant。

## 方法

<a id="member-gfvalidationrule-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_rule_id: StringName, p_callback: Callable = Callable(), options: Dictionary = {} ) -> GFValidationRule:
```

配置规则并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_rule_id` | 规则标识。 |
| `p_callback` | 可选校验回调。 |
| `options` | 可选字段，支持 description、target_kind、enabled、severity、metadata。 |

返回：当前规则。

结构：

- `options`: Dictionary rule configuration overrides.

<a id="member-gfvalidationrule-methods-applies_to"></a>

### `applies_to`

- API：`public`

```gdscript
func applies_to(target: Variant, context: Dictionary = {}) -> bool:
```

检查规则是否适用于目标。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 待校验目标。 |
| `context` | 调用方上下文。 |

返回：适用时返回 true。

结构：

- `target`: Variant validation target.
- `context`: Dictionary validation context.

<a id="member-gfvalidationrule-methods-validate"></a>

### `validate`

- API：`public`

```gdscript
func validate(target: Variant, context: Dictionary = {}) -> GFValidationReport:
```

执行规则并返回报告。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 待校验目标。 |
| `context` | 调用方上下文。 |

返回：校验报告。

结构：

- `target`: Variant validation target.
- `context`: Dictionary validation context.

<a id="member-gfvalidationrule-methods-duplicate_rule"></a>

### `duplicate_rule`

- API：`public`

```gdscript
func duplicate_rule() -> GFValidationRule:
```

创建当前规则的浅配置副本。

返回：新规则。
