# GFSkill

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/skills/gf_skill.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

技能基类。 负责冷却、施放校验与目标解析入口， 具体技能逻辑通过子类重写 `_on_execute()` 实现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cooldown_started`](#member-gfskill-signals-cooldown_started) | `signal cooldown_started(skill: GFSkill)` |
| 信号 | [`activation_failed`](#member-gfskill-signals-activation_failed) | `signal activation_failed(skill: GFSkill, context: RefCounted)` |
| 信号 | [`activation_committed`](#member-gfskill-signals-activation_committed) | `signal activation_committed(skill: GFSkill, context: RefCounted)` |
| 属性 | [`id`](#member-gfskill-properties-id) | `var id: StringName = &""` |
| 属性 | [`cooldown_max`](#member-gfskill-properties-cooldown_max) | `var cooldown_max: float = 0.0` |
| 属性 | [`cooldown_left`](#member-gfskill-properties-cooldown_left) | `var cooldown_left: float = 0.0` |
| 属性 | [`require_tags`](#member-gfskill-properties-require_tags) | `var require_tags: Array[StringName] = []` |
| 属性 | [`ignore_tags`](#member-gfskill-properties-ignore_tags) | `var ignore_tags: Array[StringName] = []` |
| 属性 | [`owner`](#member-gfskill-properties-owner) | `var owner: Object = null` |
| 属性 | [`targeting_rule`](#member-gfskill-properties-targeting_rule) | `var targeting_rule: GFSkillTargetingRule2D = null` |
| 属性 | [`activation_query`](#member-gfskill-properties-activation_query) | `var activation_query: GFTagQuery = null` |
| 属性 | [`activation_checks`](#member-gfskill-properties-activation_checks) | `var activation_checks: Array[Callable] = []` |
| 属性 | [`activation_steps`](#member-gfskill-properties-activation_steps) | `var activation_steps: Array[GFSkillActivationStep] = []` |
| 方法 | [`update`](#member-gfskill-methods-update) | `func update(p_delta: float) -> void:` |
| 方法 | [`can_execute`](#member-gfskill-methods-can_execute) | `func can_execute() -> bool:` |
| 方法 | [`build_activation_context`](#member-gfskill-methods-build_activation_context) | `func build_activation_context( manual_target: Object = null, cast_center: Variant = null, activation_metadata: Dictionary = {} ) -> RefCounted:` |
| 方法 | [`get_activation_report`](#member-gfskill-methods-get_activation_report) | `func get_activation_report(context: RefCounted = null) -> Dictionary:` |
| 方法 | [`execute`](#member-gfskill-methods-execute) | `func execute( manual_target: Object = null, cast_center: Variant = null, activation_metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`_custom_can_execute`](#member-gfskill-methods-_custom_can_execute) | `func _custom_can_execute() -> bool:` |
| 方法 | [`_on_execute`](#member-gfskill-methods-_on_execute) | `func _on_execute(_targets: Array[Object]) -> void:` |
| 方法 | [`_try_execute`](#member-gfskill-methods-_try_execute) | `func _try_execute(targets: Array[Object]) -> bool:` |
| 方法 | [`_try_activate`](#member-gfskill-methods-_try_activate) | `func _try_activate(context: RefCounted) -> bool:` |

## 信号

<a id="member-gfskill-signals-cooldown_started"></a>

### `cooldown_started`

- API：`public`

```gdscript
signal cooldown_started(skill: GFSkill)
```

当技能开始进入冷却时发出。

参数：

| 名称 | 说明 |
|---|---|
| `skill` | 进入冷却的技能实例。 |

<a id="member-gfskill-signals-activation_failed"></a>

### `activation_failed`

- API：`public`

```gdscript
signal activation_failed(skill: GFSkill, context: RefCounted)
```

当技能激活失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `skill` | 激活失败的技能实例。 |
| `context` | 技能激活上下文。 |

<a id="member-gfskill-signals-activation_committed"></a>

### `activation_committed`

- API：`public`

```gdscript
signal activation_committed(skill: GFSkill, context: RefCounted)
```

当技能完成激活提交并进入冷却时发出。

参数：

| 名称 | 说明 |
|---|---|
| `skill` | 已提交的技能实例。 |
| `context` | 技能激活上下文。 |

## 属性

<a id="member-gfskill-properties-id"></a>

### `id`

- API：`public`

```gdscript
var id: StringName = &""
```

技能 ID。

<a id="member-gfskill-properties-cooldown_max"></a>

### `cooldown_max`

- API：`public`

```gdscript
var cooldown_max: float = 0.0
```

最大冷却时间。

<a id="member-gfskill-properties-cooldown_left"></a>

### `cooldown_left`

- API：`public`

```gdscript
var cooldown_left: float = 0.0
```

当前剩余冷却时间。

<a id="member-gfskill-properties-require_tags"></a>

### `require_tags`

- API：`public`

```gdscript
var require_tags: Array[StringName] = []
```

释放技能所需标签。

<a id="member-gfskill-properties-ignore_tags"></a>

### `ignore_tags`

- API：`public`

```gdscript
var ignore_tags: Array[StringName] = []
```

释放技能时禁止存在的标签。

<a id="member-gfskill-properties-owner"></a>

### `owner`

- API：`public`

```gdscript
var owner: Object = null
```

技能拥有者。

<a id="member-gfskill-properties-targeting_rule"></a>

### `targeting_rule`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var targeting_rule: GFSkillTargetingRule2D = null
```

2D 技能索敌规则。

<a id="member-gfskill-properties-activation_query"></a>

### `activation_query`

- API：`public`

```gdscript
var activation_query: GFTagQuery = null
```

可选标签查询。为空时使用 require_tags / ignore_tags。

<a id="member-gfskill-properties-activation_checks"></a>

### `activation_checks`

- API：`public`

```gdscript
var activation_checks: Array[Callable] = []
```

激活检查回调。每个回调接收 GFSkillActivationContext，可返回 bool 或 { ok, reason, metadata }。

结构：

- `activation_checks`: Array[Callable]，用于项目自定义成本、状态或上下文检查。

<a id="member-gfskill-properties-activation_steps"></a>

### `activation_steps`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var activation_steps: Array[GFSkillActivationStep] = []
```

激活事务步骤。步骤按顺序验证和应用，失败时按逆序回滚已应用步骤。

结构：

- `activation_steps`: Array[GFSkillActivationStep]，用于项目自定义成本、预留或其他可补偿副作用。

## 方法

<a id="member-gfskill-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(p_delta: float) -> void:
```

更新冷却时间。

参数：

| 名称 | 说明 |
|---|---|
| `p_delta` | 本次更新经过的时间。 |

<a id="member-gfskill-methods-can_execute"></a>

### `can_execute`

- API：`public`

```gdscript
func can_execute() -> bool:
```

检查技能当前是否允许施放。

返回：可施放时返回 `true`。

<a id="member-gfskill-methods-build_activation_context"></a>

### `build_activation_context`

- API：`public`

```gdscript
func build_activation_context( manual_target: Object = null, cast_center: Variant = null, activation_metadata: Dictionary = {} ) -> RefCounted:
```

创建技能激活上下文。

参数：

| 名称 | 说明 |
|---|---|
| `manual_target` | 可选的手动目标。 |
| `cast_center` | 可选施法中心；传入 `null` 时回退到施法者位置。 |
| `activation_metadata` | 项目自定义激活元数据。 |

返回：技能激活上下文。

结构：

- `cast_center`: Variant，可为 null 或 Vector2；为 null 时从 owner.global_position 推导。
- `activation_metadata`: Dictionary，复制到上下文中供项目检查、提交或诊断使用。

<a id="member-gfskill-methods-get_activation_report"></a>

### `get_activation_report`

- API：`public`

```gdscript
func get_activation_report(context: RefCounted = null) -> Dictionary:
```

获取技能激活报告。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 可选激活上下文；为空时创建默认上下文。 |

返回：激活报告。

结构：

- `return`: Dictionary，包含 ok、reason、skill_id、target_count 和 metadata。

<a id="member-gfskill-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute( manual_target: Object = null, cast_center: Variant = null, activation_metadata: Dictionary = {} ) -> bool:
```

执行技能。

参数：

| 名称 | 说明 |
|---|---|
| `manual_target` | 可选的手动目标。 |
| `cast_center` | 可选施法中心；传入 `null` 时回退到施法者位置。 |
| `activation_metadata` | 项目自定义激活元数据。 |

返回：技能实际执行并进入冷却时返回 `true`。

结构：

- `cast_center`: Variant，可为 null 或 Vector2；为 null 时从 owner.global_position 推导。
- `activation_metadata`: Dictionary，复制到上下文中供项目检查、提交或诊断使用。

<a id="member-gfskill-methods-_custom_can_execute"></a>

### `_custom_can_execute`

- API：`protected`

```gdscript
func _custom_can_execute() -> bool:
```

自定义施放检查。

返回：允许施放时返回 `true`。

<a id="member-gfskill-methods-_on_execute"></a>

### `_on_execute`

- API：`protected`

```gdscript
func _on_execute(_targets: Array[Object]) -> void:
```

具体技能逻辑入口。

参数：

| 名称 | 说明 |
|---|---|
| `_targets` | 经过筛选后的最终目标数组。 |

结构：

- `_targets`: Array[Object]，经过 targeting_rule 或手动目标校验后的最终目标列表。

<a id="member-gfskill-methods-_try_execute"></a>

### `_try_execute`

- API：`protected`

```gdscript
func _try_execute(targets: Array[Object]) -> bool:
```

可报告成功/失败的技能执行入口。默认调用旧的 `_on_execute()` 钩子并视为成功。

参数：

| 名称 | 说明 |
|---|---|
| `targets` | 经过筛选后的最终目标数组。 |

返回：技能真正生效时返回 `true`。

结构：

- `targets`: Array[Object]，经过 targeting_rule 或手动目标校验后的最终目标列表。

<a id="member-gfskill-methods-_try_activate"></a>

### `_try_activate`

- API：`protected`

```gdscript
func _try_activate(context: RefCounted) -> bool:
```

基于激活上下文执行技能。默认桥接到旧的 `_try_execute()`。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 技能激活上下文。 |

返回：技能真正生效时返回 `true`。
