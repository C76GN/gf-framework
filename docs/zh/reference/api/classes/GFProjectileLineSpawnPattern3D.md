# GFProjectileLineSpawnPattern3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_3d.gd`
- 模块：`Combat`
- 继承：`GFProjectileSpawnPattern3D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

沿 3D 局部线段生成发射点。 只描述发射点分布，适合多炮口、轨道点或沿空间线段生成发射体。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`point_count`](#member-gfprojectilelinespawnpattern3d-properties-point_count) | `var point_count: int = 1` |
| 属性 | [`local_start`](#member-gfprojectilelinespawnpattern3d-properties-local_start) | `var local_start: Vector3 = Vector3.ZERO` |
| 属性 | [`local_end`](#member-gfprojectilelinespawnpattern3d-properties-local_end) | `var local_end: Vector3 = Vector3.ZERO` |
| 属性 | [`rotate_to_line`](#member-gfprojectilelinespawnpattern3d-properties-rotate_to_line) | `var rotate_to_line: bool = false` |
| 方法 | [`_get_spawn_transforms`](#member-gfprojectilelinespawnpattern3d-methods-_get_spawn_transforms) | `func _get_spawn_transforms( emitter: Node3D, _launch_input: GFProjectileLaunchInput3D = null, emit_count: int = -1 ) -> Array[Transform3D]:` |

## 属性

<a id="member-gfprojectilelinespawnpattern3d-properties-point_count"></a>

### `point_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var point_count: int = 1
```

默认发射数量。

<a id="member-gfprojectilelinespawnpattern3d-properties-local_start"></a>

### `local_start`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var local_start: Vector3 = Vector3.ZERO
```

线段局部起点。

<a id="member-gfprojectilelinespawnpattern3d-properties-local_end"></a>

### `local_end`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var local_end: Vector3 = Vector3.ZERO
```

线段局部终点。

<a id="member-gfprojectilelinespawnpattern3d-properties-rotate_to_line"></a>

### `rotate_to_line`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var rotate_to_line: bool = false
```

生成变换是否朝向线段方向。

## 方法

<a id="member-gfprojectilelinespawnpattern3d-methods-_get_spawn_transforms"></a>

### `_get_spawn_transforms`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _get_spawn_transforms( emitter: Node3D, _launch_input: GFProjectileLaunchInput3D = null, emit_count: int = -1 ) -> Array[Transform3D]:
```

生成 3D 线段发射变换。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `_launch_input` | 本次 typed 发射输入；当前实现不读取。 |
| `emit_count` | 调用方请求的数量；小于等于 0 时使用 point_count。 |

返回：全局 Transform3D 列表。
