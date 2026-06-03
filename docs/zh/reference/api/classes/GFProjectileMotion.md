# GFProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_motion.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

发射体移动策略基类。 移动策略只负责根据 delta 推进节点位置。需要跨帧保存的数据应写入 projectile_context，避免共享 Resource 在多个发射体之间串状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`setup`](#member-gfprojectilemotion-methods-setup) | `func setup(projectile: Node, projectile_context: Dictionary = {}) -> void:` |
| 方法 | [`step`](#member-gfprojectilemotion-methods-step) | `func step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:` |
| 方法 | [`_setup`](#member-gfprojectilemotion-methods-_setup) | `func _setup(_projectile: Node, _projectile_context: Dictionary = {}) -> void:` |
| 方法 | [`_step`](#member-gfprojectilemotion-methods-_step) | `func _step(_projectile: Node, _delta: float, _projectile_context: Dictionary = {}) -> void:` |

## 方法

<a id="member-gfprojectilemotion-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup(projectile: Node, projectile_context: Dictionary = {}) -> void:
```

发射体启动时调用。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 发射体节点。 |
| `projectile_context` | 本次发射的上下文字典。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文；移动策略可写入跨帧状态。

<a id="member-gfprojectilemotion-methods-step"></a>

### `step`

- API：`public`

```gdscript
func step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:
```

推进一帧移动。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 发射体节点。 |
| `delta` | 物理帧间隔。 |
| `projectile_context` | 本次发射的上下文字典。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文；移动策略可读取或写入跨帧状态。

<a id="member-gfprojectilemotion-methods-_setup"></a>

### `_setup`

- API：`protected`

```gdscript
func _setup(_projectile: Node, _projectile_context: Dictionary = {}) -> void:
```

发射体启动扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_projectile` | 发射体节点。 |
| `_projectile_context` | 本次发射上下文字典。 |

结构：

- `_projectile_context`: Dictionary，本次发射上下文；移动策略可写入跨帧状态。

<a id="member-gfprojectilemotion-methods-_step"></a>

### `_step`

- API：`protected`

```gdscript
func _step(_projectile: Node, _delta: float, _projectile_context: Dictionary = {}) -> void:
```

发射体移动扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_projectile` | 发射体节点。 |
| `_delta` | 物理帧间隔。 |
| `_projectile_context` | 本次发射上下文字典。 |

结构：

- `_projectile_context`: Dictionary，本次发射上下文；移动策略可读取或写入跨帧状态。
