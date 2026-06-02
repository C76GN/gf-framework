# GFSkillActivationContext

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/skills/gf_skill_activation_context.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.20.0`

技能激活上下文。 保存一次技能激活过程中的 owner、目标、位置、失败原因和项目元数据。 它只承载通用上下文，不解释成本、阵营、属性或具体玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`skill`](#member-gfskillactivationcontext-properties-skill) | `var skill: GFSkill = null` |
| 属性 | [`owner`](#member-gfskillactivationcontext-properties-owner) | `var owner: Object = null` |
| 属性 | [`manual_target`](#member-gfskillactivationcontext-properties-manual_target) | `var manual_target: Object = null` |
| 属性 | [`cast_center`](#member-gfskillactivationcontext-properties-cast_center) | `var cast_center: Variant = null` |
| 属性 | [`resolved_center`](#member-gfskillactivationcontext-properties-resolved_center) | `var resolved_center: Vector2 = Vector2.ZERO` |
| 属性 | [`targets`](#member-gfskillactivationcontext-properties-targets) | `var targets: Array[Object] = []` |
| 属性 | [`failure_reason`](#member-gfskillactivationcontext-properties-failure_reason) | `var failure_reason: StringName = &""` |
| 属性 | [`metadata`](#member-gfskillactivationcontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfskillactivationcontext-methods-configure) | `func configure( p_skill: GFSkill, p_owner: Object, p_manual_target: Object = null, p_cast_center: Variant = null, p_resolved_center: Vector2 = Vector2.ZERO, p_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`fail`](#member-gfskillactivationcontext-methods-fail) | `func fail(reason: StringName, extra_metadata: Dictionary = {}) -> void:` |
| 方法 | [`is_ok`](#member-gfskillactivationcontext-methods-is_ok) | `func is_ok() -> bool:` |
| 方法 | [`to_report`](#member-gfskillactivationcontext-methods-to_report) | `func to_report() -> Dictionary:` |

## 属性

<a id="member-gfskillactivationcontext-properties-skill"></a>

### `skill`

- API：`public`

```gdscript
var skill: GFSkill = null
```

技能实例。

<a id="member-gfskillactivationcontext-properties-owner"></a>

### `owner`

- API：`public`

```gdscript
var owner: Object = null
```

技能拥有者。

<a id="member-gfskillactivationcontext-properties-manual_target"></a>

### `manual_target`

- API：`public`

```gdscript
var manual_target: Object = null
```

手动传入的目标。

<a id="member-gfskillactivationcontext-properties-cast_center"></a>

### `cast_center`

- API：`public`

```gdscript
var cast_center: Variant = null
```

原始施放中心。

结构：

- `cast_center`: Variant，可为 null 或 Vector2。

<a id="member-gfskillactivationcontext-properties-resolved_center"></a>

### `resolved_center`

- API：`public`

```gdscript
var resolved_center: Vector2 = Vector2.ZERO
```

解析后的施放中心。

<a id="member-gfskillactivationcontext-properties-targets"></a>

### `targets`

- API：`public`

```gdscript
var targets: Array[Object] = []
```

最终目标列表。

结构：

- `targets`: Array[Object]，经过项目目标规则过滤后的目标。

<a id="member-gfskillactivationcontext-properties-failure_reason"></a>

### `failure_reason`

- API：`public`

```gdscript
var failure_reason: StringName = &""
```

激活报告中的失败原因。空值表示尚未失败。

<a id="member-gfskillactivationcontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目持有的成本、日志、调试或表现数据。

## 方法

<a id="member-gfskillactivationcontext-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_skill: GFSkill, p_owner: Object, p_manual_target: Object = null, p_cast_center: Variant = null, p_resolved_center: Vector2 = Vector2.ZERO, p_metadata: Dictionary = {} ) -> RefCounted:
```

配置上下文并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_skill` | 技能实例。 |
| `p_owner` | 技能拥有者。 |
| `p_manual_target` | 手动传入目标。 |
| `p_cast_center` | 原始施放中心。 |
| `p_resolved_center` | 解析后的施放中心。 |
| `p_metadata` | 项目自定义元数据。 |

返回：当前上下文。

结构：

- `p_cast_center`: Variant，可为 null 或 Vector2。
- `p_metadata`: Dictionary，复制到上下文中供项目检查、提交或诊断使用。
- `return`: GFSkillActivationContext 当前上下文。

<a id="member-gfskillactivationcontext-methods-fail"></a>

### `fail`

- API：`public`

```gdscript
func fail(reason: StringName, extra_metadata: Dictionary = {}) -> void:
```

标记激活失败。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失败原因。 |
| `extra_metadata` | 追加到上下文的元数据。 |

结构：

- `extra_metadata`: Dictionary，复制到 metadata 中供项目诊断或串联使用。

<a id="member-gfskillactivationcontext-methods-is_ok"></a>

### `is_ok`

- API：`public`

```gdscript
func is_ok() -> bool:
```

检查上下文当前是否未失败。

返回：未失败时返回 true。

<a id="member-gfskillactivationcontext-methods-to_report"></a>

### `to_report`

- API：`public`

```gdscript
func to_report() -> Dictionary:
```

创建报告字典。

返回：报告字典。

结构：

- `return`: Dictionary，包含 ok、reason、skill_id、target_count 和 metadata。
