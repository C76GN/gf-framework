# GFHomingProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_homing_projectile_motion.gd`
- 模块：`Combat`
- 继承：`GFProjectileMotion`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

2D/3D 通用追踪发射体移动策略。 目标可通过 launch() 上下文中的 target、target_position、target_position_2d 或 target_position_3d 传入，也可以用 target_path 从发射体节点相对查找。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`speed`](#member-gfhomingprojectilemotion-properties-speed) | `var speed: float = 0.0` |
| 属性 | [`target_path`](#member-gfhomingprojectilemotion-properties-target_path) | `var target_path: NodePath = NodePath("")` |
| 属性 | [`target_context_key`](#member-gfhomingprojectilemotion-properties-target_context_key) | `var target_context_key: StringName = &"target"` |
| 属性 | [`target_position_context_key`](#member-gfhomingprojectilemotion-properties-target_position_context_key) | `var target_position_context_key: StringName = &"target_position"` |
| 属性 | [`arrival_distance`](#member-gfhomingprojectilemotion-properties-arrival_distance) | `var arrival_distance: float = 0.0` |
| 属性 | [`track_target`](#member-gfhomingprojectilemotion-properties-track_target) | `var track_target: bool = true` |
| 属性 | [`stop_when_reached`](#member-gfhomingprojectilemotion-properties-stop_when_reached) | `var stop_when_reached: bool = true` |
| 方法 | [`_setup`](#member-gfhomingprojectilemotion-methods-_setup) | `func _setup(projectile: Node, projectile_context: Dictionary = {}) -> void:` |
| 方法 | [`_step`](#member-gfhomingprojectilemotion-methods-_step) | `func _step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:` |

## 属性

<a id="member-gfhomingprojectilemotion-properties-speed"></a>

### `speed`

- API：`public`

```gdscript
var speed: float = 0.0
```

每秒移动距离。

<a id="member-gfhomingprojectilemotion-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath = NodePath("")
```

可选目标节点路径。为空时只读取 projectile_context。

<a id="member-gfhomingprojectilemotion-properties-target_context_key"></a>

### `target_context_key`

- API：`public`

```gdscript
var target_context_key: StringName = &"target"
```

从 projectile_context 读取目标对象或位置的键。

<a id="member-gfhomingprojectilemotion-properties-target_position_context_key"></a>

### `target_position_context_key`

- API：`public`

```gdscript
var target_position_context_key: StringName = &"target_position"
```

从 projectile_context 读取通用目标位置的键。

<a id="member-gfhomingprojectilemotion-properties-arrival_distance"></a>

### `arrival_distance`

- API：`public`

```gdscript
var arrival_distance: float = 0.0
```

到目标的距离小于等于该值时视为到达。小于 0 表示不标记到达。

<a id="member-gfhomingprojectilemotion-properties-track_target"></a>

### `track_target`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var track_target: bool = true
```

是否每帧重新朝向当前目标。关闭后只在首次解析目标时锁定方向； 对象目标随后释放时仍沿缓存方向继续移动，不再执行距离到达夹取。

<a id="member-gfhomingprojectilemotion-properties-stop_when_reached"></a>

### `stop_when_reached`

- API：`public`

```gdscript
var stop_when_reached: bool = true
```

到达目标范围时是否停止并夹住位移，避免越过目标。

## 方法

<a id="member-gfhomingprojectilemotion-methods-_setup"></a>

### `_setup`

- API：`protected`

```gdscript
func _setup(projectile: Node, projectile_context: Dictionary = {}) -> void:
```

缓存初始追踪方向。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 发射体节点。 |
| `projectile_context` | 本次发射上下文字典。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文；可包含 target、target_position、target_position_2d 或 target_position_3d。

<a id="member-gfhomingprojectilemotion-methods-_step"></a>

### `_step`

- API：`protected`

```gdscript
func _step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:
```

推进追踪移动。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 发射体节点。 |
| `delta` | 物理帧间隔。 |
| `projectile_context` | 本次发射上下文字典。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文；会写入目标距离、速度和到达状态。
