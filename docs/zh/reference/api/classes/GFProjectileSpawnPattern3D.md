# GFProjectileSpawnPattern3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_spawn_pattern_3d.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

3D 发射体生成点模式基类。 模式只返回全局 Transform3D 列表，不实例化节点，也不解释伤害、弹药或阵营。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_spawn_transforms`](#member-gfprojectilespawnpattern3d-methods-get_spawn_transforms) | `func get_spawn_transforms( emitter: Node3D, projectile_context: Dictionary = {}, emit_count: int = -1 ) -> Array[Transform3D]:` |
| 方法 | [`_get_spawn_transforms`](#member-gfprojectilespawnpattern3d-methods-_get_spawn_transforms) | `func _get_spawn_transforms( emitter: Node3D, _projectile_context: Dictionary = {}, _emit_count: int = -1 ) -> Array[Transform3D]:` |

## 方法

<a id="member-gfprojectilespawnpattern3d-methods-get_spawn_transforms"></a>

### `get_spawn_transforms`

- API：`public`

```gdscript
func get_spawn_transforms( emitter: Node3D, projectile_context: Dictionary = {}, emit_count: int = -1 ) -> Array[Transform3D]:
```

计算本次发射的全局生成变换。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `projectile_context` | 本次发射上下文。 |
| `emit_count` | 调用方请求的数量；小于等于 0 时由模式自行决定。 |

返回：全局 Transform3D 列表。

结构：

- `projectile_context`: Dictionary，本次发射上下文；模式只读取调用方约定的数据。

<a id="member-gfprojectilespawnpattern3d-methods-_get_spawn_transforms"></a>

### `_get_spawn_transforms`

- API：`protected`

```gdscript
func _get_spawn_transforms( emitter: Node3D, _projectile_context: Dictionary = {}, _emit_count: int = -1 ) -> Array[Transform3D]:
```

生成点计算扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `_projectile_context` | 本次发射上下文。 |
| `_emit_count` | 调用方请求的数量；小于等于 0 时由模式自行决定。 |

返回：全局 Transform3D 列表。

结构：

- `_projectile_context`: Dictionary，本次发射上下文；模式只读取调用方约定的数据。
