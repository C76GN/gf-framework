# GFProjectileEmitter3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_emitter_3d.gd`
- 模块：`Combat`
- 继承：`Node3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

在安全点借用完整场景，以一次等待原子发射一批 3D projectile。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`projectile_emitted`](#member-gfprojectileemitter3d-signals-projectile_emitted) | `signal projectile_emitted( projectile_root: Node, session: GFProjectileSession, launch_input: GFProjectileLaunchInput3D )` |
| 信号 | [`projectile_emit_failed`](#member-gfprojectileemitter3d-signals-projectile_emit_failed) | `signal projectile_emit_failed(reason: StringName, details: Dictionary)` |
| 属性 | [`projectile_definition`](#member-gfprojectileemitter3d-properties-projectile_definition) | `var projectile_definition: GFProjectileDefinition3D = null` |
| 属性 | [`projectile_catalog`](#member-gfprojectileemitter3d-properties-projectile_catalog) | `var projectile_catalog: GFProjectileCatalog = null` |
| 属性 | [`default_projectile_id`](#member-gfprojectileemitter3d-properties-default_projectile_id) | `var default_projectile_id: StringName = &""` |
| 属性 | [`spawn_pattern`](#member-gfprojectileemitter3d-properties-spawn_pattern) | `var spawn_pattern: GFProjectileSpawnPattern3D = null` |
| 属性 | [`emission_policy`](#member-gfprojectileemitter3d-properties-emission_policy) | `var emission_policy: GFProjectileEmissionPolicy = null` |
| 属性 | [`hard_projectile_limit_per_request`](#member-gfprojectileemitter3d-properties-hard_projectile_limit_per_request) | `var hard_projectile_limit_per_request: int = 4096:` |
| 属性 | [`default_launch_input`](#member-gfprojectileemitter3d-properties-default_launch_input) | `var default_launch_input: GFProjectileLaunchInput3D = null` |
| 属性 | [`spawn_parent_path`](#member-gfprojectileemitter3d-properties-spawn_parent_path) | `var spawn_parent_path: NodePath = NodePath("")` |
| 属性 | [`object_pool_utility`](#member-gfprojectileemitter3d-properties-object_pool_utility) | `var object_pool_utility: GFObjectPoolUtility = null` |
| 方法 | [`emit_pattern`](#member-gfprojectileemitter3d-methods-emit_pattern) | `func emit_pattern( launch_input: GFProjectileLaunchInput3D = null, projectile_id: StringName = &"", emit_count: int = -1 ) -> GFProjectileEmissionResult:` |
| 方法 | [`resolve_projectile_definition`](#member-gfprojectileemitter3d-methods-resolve_projectile_definition) | `func resolve_projectile_definition( projectile_id: StringName = &"" ) -> GFProjectileDefinition3D:` |
| 方法 | [`resolve_spawn_parent`](#member-gfprojectileemitter3d-methods-resolve_spawn_parent) | `func resolve_spawn_parent() -> Node:` |

## 信号

<a id="member-gfprojectileemitter3d-signals-projectile_emitted"></a>

### `projectile_emitted`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal projectile_emitted( projectile_root: Node, session: GFProjectileSession, launch_input: GFProjectileLaunchInput3D )
```

单个 root 的 session 已 ACTIVE 且 started 已按稳定顺序发布后发出。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_root` | allocator 管理的完整实例 root。 |
| `session` | 对应 ACTIVE session。 |
| `launch_input` | 该候选独立的最终 typed input 快照。 |

<a id="member-gfprojectileemitter3d-signals-projectile_emit_failed"></a>

### `projectile_emit_failed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal projectile_emit_failed(reason: StringName, details: Dictionary)
```

本次发射在返回任何 root 前失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定失败原因。 |
| `details` | 有界诊断详情。 |

结构：

- `details`: Dictionary，最多 16 项；键仅限 ok、reason、binding_failure_reason、policy_id、projectile_id、requested_count、emit_count、emitted_count、hard_limit、now_msec、state、published、committed、compensated、rolled_back、remaining_cooldown_seconds、available_charges、required_charges、consumed_charges、emission_count、policy_instance_id、policy_state_generation、policy_enabled；binding_failure_reason 为 GFProjectileBinding.FailureReason；值仅限 null、bool、int、有限 float、String（至多 256 字符）、StringName（至多 128 字符）或 NodePath（至多 256 字符）。

## 属性

<a id="member-gfprojectileemitter3d-properties-projectile_definition"></a>

### `projectile_definition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var projectile_definition: GFProjectileDefinition3D = null
```

未使用 catalog ID 时的直接 typed definition。

<a id="member-gfprojectileemitter3d-properties-projectile_catalog"></a>

### `projectile_catalog`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var projectile_catalog: GFProjectileCatalog = null
```

可选 ID 到 typed definition 目录。

<a id="member-gfprojectileemitter3d-properties-default_projectile_id"></a>

### `default_projectile_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var default_projectile_id: StringName = &""
```

调用未指定 ID 时使用的目录 ID。

<a id="member-gfprojectileemitter3d-properties-spawn_pattern"></a>

### `spawn_pattern`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var spawn_pattern: GFProjectileSpawnPattern3D = null
```

可选 typed 3D spawn pattern。

<a id="member-gfprojectileemitter3d-properties-emission_policy"></a>

### `emission_policy`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var emission_policy: GFProjectileEmissionPolicy = null
```

可选限流、charge 与 cooldown 策略。

<a id="member-gfprojectileemitter3d-properties-hard_projectile_limit_per_request"></a>

### `hard_projectile_limit_per_request`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var hard_projectile_limit_per_request: int = 4096:
```

单次请求的不可绕过候选硬上限。

<a id="member-gfprojectileemitter3d-properties-default_launch_input"></a>

### `default_launch_input`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var default_launch_input: GFProjectileLaunchInput3D = null
```

null 调用输入的默认值；每次请求和候选均深复制。

<a id="member-gfprojectileemitter3d-properties-spawn_parent_path"></a>

### `spawn_parent_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var spawn_parent_path: NodePath = NodePath("")
```

相对 emitter 的生成父节点路径；空路径使用当前父节点。

<a id="member-gfprojectileemitter3d-properties-object_pool_utility"></a>

### `object_pool_utility`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var object_pool_utility: GFObjectPoolUtility = null
```

可选共享对象池；null 时使用发射器私有且不缓存的池。 项目负责共享池的生命周期；发射器只归还自己的 Lease。

## 方法

<a id="member-gfprojectileemitter3d-methods-emit_pattern"></a>

### `emit_pattern`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func emit_pattern( launch_input: GFProjectileLaunchInput3D = null, projectile_id: StringName = &"", emit_count: int = -1 ) -> GFProjectileEmissionResult:
```

在安全点原子发射一批 3D projectile，并返回唯一终态。 请求期间只允许一次在途发射；需要单发时将 emit_count 设为 1。 输入、生成位置和配置身份在等待前冻结；等待期间配置变动会取消本次请求。

参数：

| 名称 | 说明 |
|---|---|
| `launch_input` | 可选 typed 调用输入；容器值复制，目标节点保持弱引用。 |
| `projectile_id` | 可选 catalog ID；空值使用默认配置。 |
| `emit_count` | 正数覆盖 pattern 数量；负值使用 pattern 默认值。 |

返回：唯一结果；失败时不交付部分 Session，成功数量可以受发射策略和硬上限限制。

<a id="member-gfprojectileemitter3d-methods-resolve_projectile_definition"></a>

### `resolve_projectile_definition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func resolve_projectile_definition( projectile_id: StringName = &"" ) -> GFProjectileDefinition3D:
```

解析本次发射使用的 typed 3D definition。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 可选 catalog ID。 |

返回：匹配的 3D definition；缺失或维度不匹配时返回 null。

<a id="member-gfprojectileemitter3d-methods-resolve_spawn_parent"></a>

### `resolve_spawn_parent`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func resolve_spawn_parent() -> Node:
```

解析完整实例 root 的生成父节点。

返回：configured parent、emitter parent 或 tree 内 emitter；不可用时返回 null。
