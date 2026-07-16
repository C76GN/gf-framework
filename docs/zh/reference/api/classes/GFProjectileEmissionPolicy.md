# GFProjectileEmissionPolicy

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_emission_policy.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

发射体发射请求策略。 用于在 GFProjectileEmitter2D / GFProjectileEmitter3D 生成节点前执行通用门控、数量裁剪和节奏控制。 该策略只处理发射请求本身，不解释弹药、阵营、伤害、特效或输入规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`policy_id`](#member-gfprojectileemissionpolicy-properties-policy_id) | `var policy_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfprojectileemissionpolicy-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`cooldown_seconds`](#member-gfprojectileemissionpolicy-properties-cooldown_seconds) | `var cooldown_seconds: float = 0.0` |
| 属性 | [`max_projectiles_per_request`](#member-gfprojectileemissionpolicy-properties-max_projectiles_per_request) | `var max_projectiles_per_request: int = 0` |
| 属性 | [`max_emission_count`](#member-gfprojectileemissionpolicy-properties-max_emission_count) | `var max_emission_count: int = 0` |
| 属性 | [`charge_capacity`](#member-gfprojectileemissionpolicy-properties-charge_capacity) | `var charge_capacity: float = 0.0` |
| 属性 | [`charge_cost_per_request`](#member-gfprojectileemissionpolicy-properties-charge_cost_per_request) | `var charge_cost_per_request: float = 0.0` |
| 属性 | [`charge_cost_per_projectile`](#member-gfprojectileemissionpolicy-properties-charge_cost_per_projectile) | `var charge_cost_per_projectile: float = 0.0` |
| 属性 | [`charge_recovery_seconds`](#member-gfprojectileemissionpolicy-properties-charge_recovery_seconds) | `var charge_recovery_seconds: float = 0.0` |
| 方法 | [`prepare_emission`](#member-gfprojectileemissionpolicy-methods-prepare_emission) | `func prepare_emission( emitter: Node, projectile_id: StringName, projectile_context: Dictionary = {}, requested_count: int = 1, now_msec: int = -1 ) -> Dictionary:` |
| 方法 | [`commit_emission`](#member-gfprojectileemissionpolicy-methods-commit_emission) | `func commit_emission(emitter: Node, prepare_report: Dictionary, emitted_count: int) -> Dictionary:` |
| 方法 | [`reset`](#member-gfprojectileemissionpolicy-methods-reset) | `func reset(now_msec: int = -1) -> void:` |
| 方法 | [`get_available_charges`](#member-gfprojectileemissionpolicy-methods-get_available_charges) | `func get_available_charges(now_msec: int = -1) -> float:` |
| 方法 | [`get_required_charges`](#member-gfprojectileemissionpolicy-methods-get_required_charges) | `func get_required_charges(emit_count: int) -> float:` |
| 方法 | [`get_remaining_cooldown_seconds`](#member-gfprojectileemissionpolicy-methods-get_remaining_cooldown_seconds) | `func get_remaining_cooldown_seconds(now_msec: int = -1) -> float:` |
| 方法 | [`is_configuration_valid`](#member-gfprojectileemissionpolicy-methods-is_configuration_valid) | `func is_configuration_valid() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfprojectileemissionpolicy-methods-get_debug_snapshot) | `func get_debug_snapshot(now_msec: int = -1) -> Dictionary:` |
| 方法 | [`_prepare_emission`](#member-gfprojectileemissionpolicy-methods-_prepare_emission) | `func _prepare_emission(_emitter: Node, _projectile_id: StringName, _prepare_report: Dictionary) -> Dictionary:` |
| 方法 | [`_commit_emission`](#member-gfprojectileemissionpolicy-methods-_commit_emission) | `func _commit_emission(_emitter: Node, _prepare_report: Dictionary, _emitted_count: int) -> void:` |

## 属性

<a id="member-gfprojectileemissionpolicy-properties-policy_id"></a>

### `policy_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var policy_id: StringName = &""
```

策略标识，便于调试或项目工具识别。

<a id="member-gfprojectileemissionpolicy-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var enabled: bool = true
```

是否启用策略。关闭时所有请求直接通过。

<a id="member-gfprojectileemissionpolicy-properties-cooldown_seconds"></a>

### `cooldown_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var cooldown_seconds: float = 0.0
```

两次成功发射请求之间的最小间隔秒数。小于等于 0 表示不限制。

<a id="member-gfprojectileemissionpolicy-properties-max_projectiles_per_request"></a>

### `max_projectiles_per_request`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_projectiles_per_request: int = 0
```

每次请求最多允许生成的发射体数量。小于等于 0 表示不限制。

<a id="member-gfprojectileemissionpolicy-properties-max_emission_count"></a>

### `max_emission_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_emission_count: int = 0
```

最大成功发射请求次数。小于等于 0 表示不限制。

<a id="member-gfprojectileemissionpolicy-properties-charge_capacity"></a>

### `charge_capacity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var charge_capacity: float = 0.0
```

通用 charge 容量。小于等于 0 表示不启用 charge 门控。

<a id="member-gfprojectileemissionpolicy-properties-charge_cost_per_request"></a>

### `charge_cost_per_request`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var charge_cost_per_request: float = 0.0
```

每次成功请求消耗的 charge。

<a id="member-gfprojectileemissionpolicy-properties-charge_cost_per_projectile"></a>

### `charge_cost_per_projectile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var charge_cost_per_projectile: float = 0.0
```

每个实际生成发射体额外消耗的 charge。

<a id="member-gfprojectileemissionpolicy-properties-charge_recovery_seconds"></a>

### `charge_recovery_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var charge_recovery_seconds: float = 0.0
```

恢复 1 点 charge 需要的秒数。小于等于 0 表示不会自动恢复。

## 方法

<a id="member-gfprojectileemissionpolicy-methods-prepare_emission"></a>

### `prepare_emission`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prepare_emission( emitter: Node, projectile_id: StringName, projectile_context: Dictionary = {}, requested_count: int = 1, now_msec: int = -1 ) -> Dictionary:
```

准备一次发射请求。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `projectile_id` | 发射体目录 ID。 |
| `projectile_context` | 调用方发射上下文。 |
| `requested_count` | 本次请求准备生成的发射体数量。 |
| `now_msec` | 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：发射准备报告。

结构：

- `projectile_context`: Dictionary，本次发射上下文；策略会复制后返回，不修改调用方原始字典。
- `return`: Dictionary，包含 ok、reason、policy_id、projectile_id、requested_count、emit_count、projectile_context、now_msec、remaining_cooldown_seconds、available_charges 和 required_charges。

<a id="member-gfprojectileemissionpolicy-methods-commit_emission"></a>

### `commit_emission`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func commit_emission(emitter: Node, prepare_report: Dictionary, emitted_count: int) -> Dictionary:
```

提交一次已生成的发射请求。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `prepare_report` | prepare_emission() 返回的报告。 |
| `emitted_count` | 实际成功生成的发射体数量。 |

返回：提交报告。

结构：

- `prepare_report`: Dictionary，prepare_emission() 返回的报告。
- `return`: Dictionary，包含 ok、committed、reason、emitted_count、emission_count、available_charges 和 consumed_charges。

<a id="member-gfprojectileemissionpolicy-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func reset(now_msec: int = -1) -> void:
```

重置运行时策略状态。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。 |

<a id="member-gfprojectileemissionpolicy-methods-get_available_charges"></a>

### `get_available_charges`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_available_charges(now_msec: int = -1) -> float:
```

获取当前可用 charge。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：当前可用 charge；未启用 charge 门控时返回 0。

<a id="member-gfprojectileemissionpolicy-methods-get_required_charges"></a>

### `get_required_charges`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_required_charges(emit_count: int) -> float:
```

获取指定生成数量需要消耗的 charge。

参数：

| 名称 | 说明 |
|---|---|
| `emit_count` | 预计生成数量。 |

返回：需要消耗的 charge。

<a id="member-gfprojectileemissionpolicy-methods-get_remaining_cooldown_seconds"></a>

### `get_remaining_cooldown_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_remaining_cooldown_seconds(now_msec: int = -1) -> float:
```

获取剩余冷却秒数。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：剩余冷却秒数。

<a id="member-gfprojectileemissionpolicy-methods-is_configuration_valid"></a>

### `is_configuration_valid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_configuration_valid() -> bool:
```

检查策略数值配置是否有限。

返回：所有浮点配置有限时返回 true。

<a id="member-gfprojectileemissionpolicy-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot(now_msec: int = -1) -> Dictionary:
```

获取策略调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：策略状态快照。

结构：

- `return`: Dictionary，包含 policy_id、enabled、cooldown_seconds、remaining_cooldown_seconds、charge_capacity、available_charges、emission_count 和 max_emission_count。

<a id="member-gfprojectileemissionpolicy-methods-_prepare_emission"></a>

### `_prepare_emission`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _prepare_emission(_emitter: Node, _projectile_id: StringName, _prepare_report: Dictionary) -> Dictionary:
```

发射准备扩展点。 返回的字段会合并到 prepare_emission() 报告。子类可修改 ok、reason、emit_count 或 projectile_context。

参数：

| 名称 | 说明 |
|---|---|
| `_emitter` | 发射器节点。 |
| `_projectile_id` | 发射体目录 ID。 |
| `_prepare_report` | 当前准备报告。 |

返回：需要合并到准备报告的字段。

结构：

- `_prepare_report`: Dictionary，当前准备报告。
- `return`: Dictionary，覆盖或附加到准备报告的字段。

<a id="member-gfprojectileemissionpolicy-methods-_commit_emission"></a>

### `_commit_emission`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _commit_emission(_emitter: Node, _prepare_report: Dictionary, _emitted_count: int) -> void:
```

发射提交扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_emitter` | 发射器节点。 |
| `_prepare_report` | prepare_emission() 返回的报告。 |
| `_emitted_count` | 实际成功生成的发射体数量。 |

结构：

- `_prepare_report`: Dictionary，prepare_emission() 返回的报告。
