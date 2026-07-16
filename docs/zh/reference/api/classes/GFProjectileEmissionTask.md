# GFProjectileEmissionTask

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_emission_task.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

单次发射请求事务。 在任何生成点或节点分配前统一执行策略门控、硬预算和时间快照，随后只允许 提交一次实际生成数量。任务不解释 2D/3D 变换、伤害、弹药或对象池规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATE_PENDING`](#member-gfprojectileemissiontask-constants-state_pending) | `const STATE_PENDING: StringName = &"pending"` |
| 常量 | [`STATE_PREPARED`](#member-gfprojectileemissiontask-constants-state_prepared) | `const STATE_PREPARED: StringName = &"prepared"` |
| 常量 | [`STATE_COMMITTED`](#member-gfprojectileemissiontask-constants-state_committed) | `const STATE_COMMITTED: StringName = &"committed"` |
| 常量 | [`STATE_ROLLED_BACK`](#member-gfprojectileemissiontask-constants-state_rolled_back) | `const STATE_ROLLED_BACK: StringName = &"rolled_back"` |
| 常量 | [`STATE_FAILED`](#member-gfprojectileemissiontask-constants-state_failed) | `const STATE_FAILED: StringName = &"failed"` |
| 属性 | [`state`](#member-gfprojectileemissiontask-properties-state) | `var state: StringName = STATE_PENDING` |
| 方法 | [`configure`](#member-gfprojectileemissiontask-methods-configure) | `func configure( emitter: Node, policy: GFProjectileEmissionPolicy, projectile_id: StringName, projectile_context: Dictionary, requested_count: int, hard_limit: int, now_msec: int ) -> GFProjectileEmissionTask:` |
| 方法 | [`prepare`](#member-gfprojectileemissiontask-methods-prepare) | `func prepare() -> Dictionary:` |
| 方法 | [`commit`](#member-gfprojectileemissiontask-methods-commit) | `func commit(emitted_count: int) -> Dictionary:` |
| 方法 | [`rollback`](#member-gfprojectileemissiontask-methods-rollback) | `func rollback(reason: StringName = &"emission_rolled_back") -> Dictionary:` |
| 方法 | [`get_allowed_count`](#member-gfprojectileemissiontask-methods-get_allowed_count) | `func get_allowed_count() -> int:` |
| 方法 | [`get_projectile_context`](#member-gfprojectileemissiontask-methods-get_projectile_context) | `func get_projectile_context() -> Dictionary:` |

## 常量

<a id="member-gfprojectileemissiontask-constants-state_pending"></a>

### `STATE_PENDING`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATE_PENDING: StringName = &"pending"
```

等待准备。

<a id="member-gfprojectileemissiontask-constants-state_prepared"></a>

### `STATE_PREPARED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATE_PREPARED: StringName = &"prepared"
```

已通过门控，可进入生成阶段。

<a id="member-gfprojectileemissiontask-constants-state_committed"></a>

### `STATE_COMMITTED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATE_COMMITTED: StringName = &"committed"
```

已提交策略状态。

<a id="member-gfprojectileemissiontask-constants-state_rolled_back"></a>

### `STATE_ROLLED_BACK`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATE_ROLLED_BACK: StringName = &"rolled_back"
```

生成失败或调用方取消后已回滚。

<a id="member-gfprojectileemissiontask-constants-state_failed"></a>

### `STATE_FAILED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATE_FAILED: StringName = &"failed"
```

门控或提交失败。

## 属性

<a id="member-gfprojectileemissiontask-properties-state"></a>

### `state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var state: StringName = STATE_PENDING
```

当前任务状态。

## 方法

<a id="member-gfprojectileemissiontask-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( emitter: Node, policy: GFProjectileEmissionPolicy, projectile_id: StringName, projectile_context: Dictionary, requested_count: int, hard_limit: int, now_msec: int ) -> GFProjectileEmissionTask:
```

配置新任务。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `policy` | 可选发射策略。 |
| `projectile_id` | 发射体目录 ID。 |
| `projectile_context` | 调用方上下文。 |
| `requested_count` | 模式解析后的请求数量。 |
| `hard_limit` | 分配前不可绕过的硬上限。 |
| `now_msec` | 本次事务统一使用的单调时钟毫秒值。 |

返回：当前任务。

结构：

- `projectile_context`: Dictionary，任务会深复制，不修改调用方字典。

<a id="member-gfprojectileemissiontask-methods-prepare"></a>

### `prepare`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prepare() -> Dictionary:
```

执行分配前门控。

返回：准备报告。

结构：

- `return`: Dictionary，包含 ok、reason、state、requested_count、emit_count、hard_limit、now_msec 和 projectile_context。

<a id="member-gfprojectileemissiontask-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func commit(emitted_count: int) -> Dictionary:
```

提交实际生成数量。

参数：

| 名称 | 说明 |
|---|---|
| `emitted_count` | 实际成功创建的节点数量。 |

返回：提交报告。

结构：

- `return`: Dictionary，包含 ok、committed、state、emitted_count、emit_count、hard_limit 和 now_msec。

<a id="member-gfprojectileemissiontask-methods-rollback"></a>

### `rollback`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func rollback(reason: StringName = &"emission_rolled_back") -> Dictionary:
```

回滚尚未提交的任务。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 回滚原因。 |

返回：回滚报告。

结构：

- `return`: Dictionary，包含 ok、rolled_back、reason、state、emit_count、hard_limit 和 now_msec。

<a id="member-gfprojectileemissiontask-methods-get_allowed_count"></a>

### `get_allowed_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_allowed_count() -> int:
```

获取策略允许的生成数量。

返回：准备成功后返回允许数量，否则返回 0。

<a id="member-gfprojectileemissiontask-methods-get_projectile_context"></a>

### `get_projectile_context`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_projectile_context() -> Dictionary:
```

获取准备阶段合并后的发射上下文。

返回：发射上下文副本。

结构：

- `return`: Dictionary，策略返回的 projectile_context 深副本。
