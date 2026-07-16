# GFSkillActivationStep

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/skills/gf_skill_activation_step.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

技能激活事务步骤协议。 项目侧通过继承实现验证、应用与回滚；步骤不保存单次施放状态，所有运行时数据 应写入 GFSkillActivationContext 或项目自己的事务对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`step_id`](#member-gfskillactivationstep-properties-step_id) | `var step_id: StringName = &""` |
| 属性 | [`rollback_required`](#member-gfskillactivationstep-properties-rollback_required) | `var rollback_required: bool = true` |
| 方法 | [`configure`](#member-gfskillactivationstep-methods-configure) | `func configure( p_step_id: StringName, p_rollback_required: bool = true ) -> GFSkillActivationStep:` |
| 方法 | [`_validate_activation`](#member-gfskillactivationstep-methods-_validate_activation) | `func _validate_activation(_context: GFSkillActivationContext) -> Variant:` |
| 方法 | [`_apply_activation`](#member-gfskillactivationstep-methods-_apply_activation) | `func _apply_activation(_context: GFSkillActivationContext) -> Variant:` |
| 方法 | [`_rollback_activation`](#member-gfskillactivationstep-methods-_rollback_activation) | `func _rollback_activation(_context: GFSkillActivationContext) -> Variant:` |

## 属性

<a id="member-gfskillactivationstep-properties-step_id"></a>

### `step_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var step_id: StringName = &""
```

步骤 ID；同一技能中的步骤 ID 必须唯一且非空。

<a id="member-gfskillactivationstep-properties-rollback_required"></a>

### `rollback_required`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var rollback_required: bool = true
```

应用成功后是否必须支持回滚。

## 方法

<a id="member-gfskillactivationstep-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_step_id: StringName, p_rollback_required: bool = true ) -> GFSkillActivationStep:
```

配置步骤并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_step_id` | 步骤 ID。 |
| `p_rollback_required` | 应用成功后是否必须支持回滚。 |

返回：当前步骤。

<a id="member-gfskillactivationstep-methods-_validate_activation"></a>

### `_validate_activation`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _validate_activation(_context: GFSkillActivationContext) -> Variant:
```

无副作用地验证当前步骤。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 本次技能激活上下文。 |

返回：`bool`、`Error` 或包含 `ok`、`reason`、`metadata` 的 Dictionary。

结构：

- `return`: Variant，可为 bool、Error 或 Dictionary；回调必须同步返回。

<a id="member-gfskillactivationstep-methods-_apply_activation"></a>

### `_apply_activation`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _apply_activation(_context: GFSkillActivationContext) -> Variant:
```

应用步骤副作用。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 本次技能激活上下文。 |

返回：`bool`、`Error` 或包含 `ok`、`reason`、`metadata` 的 Dictionary。

结构：

- `return`: Variant，可为 bool、Error 或 Dictionary；回调必须同步返回。

<a id="member-gfskillactivationstep-methods-_rollback_activation"></a>

### `_rollback_activation`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _rollback_activation(_context: GFSkillActivationContext) -> Variant:
```

回滚已经成功应用的步骤。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 本次技能激活上下文。 |

返回：`bool`、`Error` 或包含 `ok`、`reason`、`metadata` 的 Dictionary。

结构：

- `return`: Variant，可为 bool、Error 或 Dictionary；回调必须同步返回。
