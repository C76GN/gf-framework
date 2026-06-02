# GFProjectileEmitter3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_emitter_3d.gd`
- 模块：`Combat`
- 继承：`Node3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 3D 发射体生成节点。 负责按场景目录和生成点模式实例化发射体，并把本次发射上下文交给 发射体的 launch()。它不解释伤害、阵营、弹药、冷却或特效规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`projectile_emitted`](#member-gfprojectileemitter3d-signals-projectile_emitted) | `signal projectile_emitted(projectile: Node, projectile_context: Dictionary)` |
| 信号 | [`projectile_emit_failed`](#member-gfprojectileemitter3d-signals-projectile_emit_failed) | `signal projectile_emit_failed(reason: StringName, details: Dictionary)` |
| 属性 | [`projectile_scene`](#member-gfprojectileemitter3d-properties-projectile_scene) | `var projectile_scene: PackedScene = null` |
| 属性 | [`projectile_catalog`](#member-gfprojectileemitter3d-properties-projectile_catalog) | `var projectile_catalog: GFProjectileCatalog = null` |
| 属性 | [`default_projectile_id`](#member-gfprojectileemitter3d-properties-default_projectile_id) | `var default_projectile_id: StringName = &""` |
| 属性 | [`spawn_pattern`](#member-gfprojectileemitter3d-properties-spawn_pattern) | `var spawn_pattern: GFProjectileSpawnPattern3D = null` |
| 属性 | [`default_context`](#member-gfprojectileemitter3d-properties-default_context) | `var default_context: Dictionary = {}` |
| 属性 | [`spawn_parent_path`](#member-gfprojectileemitter3d-properties-spawn_parent_path) | `var spawn_parent_path: NodePath = NodePath("")` |
| 属性 | [`launch_after_spawn`](#member-gfprojectileemitter3d-properties-launch_after_spawn) | `var launch_after_spawn: bool = true` |
| 属性 | [`disable_auto_launch_before_add`](#member-gfprojectileemitter3d-properties-disable_auto_launch_before_add) | `var disable_auto_launch_before_add: bool = true` |
| 属性 | [`use_object_pool`](#member-gfprojectileemitter3d-properties-use_object_pool) | `var use_object_pool: bool = false` |
| 属性 | [`release_pooled_projectile_on_finish`](#member-gfprojectileemitter3d-properties-release_pooled_projectile_on_finish) | `var release_pooled_projectile_on_finish: bool = true` |
| 属性 | [`object_pool_utility`](#member-gfprojectileemitter3d-properties-object_pool_utility) | `var object_pool_utility: GFObjectPoolUtility = null` |
| 方法 | [`emit_projectile`](#member-gfprojectileemitter3d-methods-emit_projectile) | `func emit_projectile(projectile_context: Dictionary = {}, projectile_id: StringName = &"") -> Node:` |
| 方法 | [`emit_projectiles`](#member-gfprojectileemitter3d-methods-emit_projectiles) | `func emit_projectiles( projectile_context: Dictionary = {}, projectile_id: StringName = &"", emit_count: int = -1 ) -> Array[Node]:` |
| 方法 | [`resolve_projectile_scene`](#member-gfprojectileemitter3d-methods-resolve_projectile_scene) | `func resolve_projectile_scene(projectile_id: StringName = &"") -> PackedScene:` |
| 方法 | [`resolve_spawn_parent`](#member-gfprojectileemitter3d-methods-resolve_spawn_parent) | `func resolve_spawn_parent() -> Node:` |
| 方法 | [`prewarm_projectiles`](#member-gfprojectileemitter3d-methods-prewarm_projectiles) | `func prewarm_projectiles(count: int, projectile_id: StringName = &"") -> bool:` |

## 信号

<a id="member-gfprojectileemitter3d-signals-projectile_emitted"></a>

### `projectile_emitted`

- API：`public`

```gdscript
signal projectile_emitted(projectile: Node, projectile_context: Dictionary)
```

发射体已生成。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 生成的发射体节点。 |
| `projectile_context` | 本次发射上下文。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文副本，包含默认上下文、调用方上下文和 spawn 信息。

<a id="member-gfprojectileemitter3d-signals-projectile_emit_failed"></a>

### `projectile_emit_failed`

- API：`public`

```gdscript
signal projectile_emit_failed(reason: StringName, details: Dictionary)
```

发射失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失败原因。 |
| `details` | 失败细节。 |

结构：

- `details`: Dictionary，失败上下文，通常包含 projectile_id、spawn_index 等诊断字段。

## 属性

<a id="member-gfprojectileemitter3d-properties-projectile_scene"></a>

### `projectile_scene`

- API：`public`

```gdscript
var projectile_scene: PackedScene = null
```

默认发射体场景。未使用目录或目录缺少 ID 时使用。

<a id="member-gfprojectileemitter3d-properties-projectile_catalog"></a>

### `projectile_catalog`

- API：`public`

```gdscript
var projectile_catalog: GFProjectileCatalog = null
```

可选发射体目录。

<a id="member-gfprojectileemitter3d-properties-default_projectile_id"></a>

### `default_projectile_id`

- API：`public`

```gdscript
var default_projectile_id: StringName = &""
```

默认目录 ID。

<a id="member-gfprojectileemitter3d-properties-spawn_pattern"></a>

### `spawn_pattern`

- API：`public`

```gdscript
var spawn_pattern: GFProjectileSpawnPattern3D = null
```

3D 发射点模式。为空时使用发射器自身全局变换。

<a id="member-gfprojectileemitter3d-properties-default_context"></a>

### `default_context`

- API：`public`

```gdscript
var default_context: Dictionary = {}
```

默认上下文。每次发射会深拷贝后再合并调用方上下文。

结构：

- `default_context`: Dictionary，默认发射上下文；每次发射会深拷贝后合并调用方上下文。

<a id="member-gfprojectileemitter3d-properties-spawn_parent_path"></a>

### `spawn_parent_path`

- API：`public`

```gdscript
var spawn_parent_path: NodePath = NodePath("")
```

可选生成父节点路径。为空时优先使用发射器父节点。

<a id="member-gfprojectileemitter3d-properties-launch_after_spawn"></a>

### `launch_after_spawn`

- API：`public`

```gdscript
var launch_after_spawn: bool = true
```

是否在生成后调用发射体的 launch(context)。

<a id="member-gfprojectileemitter3d-properties-disable_auto_launch_before_add"></a>

### `disable_auto_launch_before_add`

- API：`public`

```gdscript
var disable_auto_launch_before_add: bool = true
```

生成前是否关闭常见发射体的 auto_launch_on_ready，避免进入树时使用空上下文启动。

<a id="member-gfprojectileemitter3d-properties-use_object_pool"></a>

### `use_object_pool`

- API：`public`

```gdscript
var use_object_pool: bool = false
```

是否使用 GFObjectPoolUtility 获取节点。池化场景应把 projectile 的 auto_launch_on_ready 设为 false。

<a id="member-gfprojectileemitter3d-properties-release_pooled_projectile_on_finish"></a>

### `release_pooled_projectile_on_finish`

- API：`public`

```gdscript
var release_pooled_projectile_on_finish: bool = true
```

使用对象池时，是否在 projectile_finished 后自动归还节点。

<a id="member-gfprojectileemitter3d-properties-object_pool_utility"></a>

### `object_pool_utility`

- API：`public`

```gdscript
var object_pool_utility: GFObjectPoolUtility = null
```

可选对象池工具。为空时会从注入架构或最近的 GFNodeContext 查询。

## 方法

<a id="member-gfprojectileemitter3d-methods-emit_projectile"></a>

### `emit_projectile`

- API：`public`

```gdscript
func emit_projectile(projectile_context: Dictionary = {}, projectile_id: StringName = &"") -> Node:
```

发射单个发射体。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_context` | 本次发射上下文。 |
| `projectile_id` | 可选目录 ID；为空时使用 default_projectile_id。 |

返回：生成的发射体节点；失败时返回 null。

结构：

- `projectile_context`: Dictionary，本次发射上下文；会与 default_context 合并后传给发射体。

<a id="member-gfprojectileemitter3d-methods-emit_projectiles"></a>

### `emit_projectiles`

- API：`public`

```gdscript
func emit_projectiles( projectile_context: Dictionary = {}, projectile_id: StringName = &"", emit_count: int = -1 ) -> Array[Node]:
```

按当前模式发射一批发射体。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_context` | 本次发射上下文。 |
| `projectile_id` | 可选目录 ID；为空时使用 default_projectile_id。 |
| `emit_count` | 请求生成数量；小于等于 0 时由 spawn_pattern 决定。 |

返回：成功生成的发射体节点列表。

结构：

- `projectile_context`: Dictionary，本次发射上下文；会与 default_context 合并后传给每个发射体。

<a id="member-gfprojectileemitter3d-methods-resolve_projectile_scene"></a>

### `resolve_projectile_scene`

- API：`public`

```gdscript
func resolve_projectile_scene(projectile_id: StringName = &"") -> PackedScene:
```

解析当前要使用的发射体场景。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 可选目录 ID。 |

返回：找到时返回 PackedScene，否则返回 null。

<a id="member-gfprojectileemitter3d-methods-resolve_spawn_parent"></a>

### `resolve_spawn_parent`

- API：`public`

```gdscript
func resolve_spawn_parent() -> Node:
```

解析发射体生成父节点。

返回：有效父节点；找不到时返回 null。

<a id="member-gfprojectileemitter3d-methods-prewarm_projectiles"></a>

### `prewarm_projectiles`

- API：`public`

```gdscript
func prewarm_projectiles(count: int, projectile_id: StringName = &"") -> bool:
```

预热对象池。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 预热数量。 |
| `projectile_id` | 可选目录 ID。 |

返回：预热请求被接受时返回 true。
