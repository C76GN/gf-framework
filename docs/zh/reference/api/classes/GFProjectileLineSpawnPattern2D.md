# GFProjectileLineSpawnPattern2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_2d.gd`
- 模块：`Combat`
- 继承：`GFProjectileSpawnPattern2D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

沿 2D 局部线段生成发射点。 只描述发射点分布，适合多炮口、线性随机点或沿武器边缘生成发射体。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`point_count`](#member-gfprojectilelinespawnpattern2d-properties-point_count) | `var point_count: int = 1` |
| 属性 | [`local_start`](#member-gfprojectilelinespawnpattern2d-properties-local_start) | `var local_start: Vector2 = Vector2.ZERO` |
| 属性 | [`local_end`](#member-gfprojectilelinespawnpattern2d-properties-local_end) | `var local_end: Vector2 = Vector2.ZERO` |
| 属性 | [`rotate_to_line`](#member-gfprojectilelinespawnpattern2d-properties-rotate_to_line) | `var rotate_to_line: bool = false` |
| 方法 | [`_get_spawn_transforms`](#member-gfprojectilelinespawnpattern2d-methods-_get_spawn_transforms) | `func _get_spawn_transforms( emitter: Node2D, _projectile_context: Dictionary = {}, emit_count: int = -1 ) -> Array[Transform2D]:` |

## 属性

<a id="member-gfprojectilelinespawnpattern2d-properties-point_count"></a>

### `point_count`

- API：`public`

```gdscript
var point_count: int = 1
```

默认发射数量。

<a id="member-gfprojectilelinespawnpattern2d-properties-local_start"></a>

### `local_start`

- API：`public`

```gdscript
var local_start: Vector2 = Vector2.ZERO
```

线段局部起点。

<a id="member-gfprojectilelinespawnpattern2d-properties-local_end"></a>

### `local_end`

- API：`public`

```gdscript
var local_end: Vector2 = Vector2.ZERO
```

线段局部终点。

<a id="member-gfprojectilelinespawnpattern2d-properties-rotate_to_line"></a>

### `rotate_to_line`

- API：`public`

```gdscript
var rotate_to_line: bool = false
```

生成变换是否朝向线段方向。

## 方法

<a id="member-gfprojectilelinespawnpattern2d-methods-_get_spawn_transforms"></a>

### `_get_spawn_transforms`

- API：`protected`

```gdscript
func _get_spawn_transforms( emitter: Node2D, _projectile_context: Dictionary = {}, emit_count: int = -1 ) -> Array[Transform2D]:
```

生成 2D 线段发射变换。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `_projectile_context` | 本次发射上下文。 |
| `emit_count` | 调用方请求的数量；小于等于 0 时使用 point_count。 |

返回：全局 Transform2D 列表。

结构：

- `_projectile_context`: Dictionary，本次发射上下文；当前实现不读取该字典。
