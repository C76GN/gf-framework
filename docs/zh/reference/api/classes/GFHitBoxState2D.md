# GFHitBoxState2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_hit_box_state_2d.gd`
- 模块：`Combat`
- 继承：`Node2D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

2D 命中区域状态组。 统一启停子树内的 GFHitBox2D、GFHurtBox2D 与 Area2D，不处理伤害、阵营或技能规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`active_changed`](#member-gfhitboxstate2d-signals-active_changed) | `signal active_changed(active: bool)` |
| 属性 | [`active`](#member-gfhitboxstate2d-properties-active) | `var active: bool = true:` |
| 属性 | [`apply_on_ready`](#member-gfhitboxstate2d-properties-apply_on_ready) | `var apply_on_ready: bool = true` |
| 属性 | [`recursive`](#member-gfhitboxstate2d-properties-recursive) | `var recursive: bool = true` |
| 属性 | [`manage_enabled`](#member-gfhitboxstate2d-properties-manage_enabled) | `var manage_enabled: bool = true` |
| 属性 | [`manage_monitoring`](#member-gfhitboxstate2d-properties-manage_monitoring) | `var manage_monitoring: bool = true` |
| 属性 | [`manage_visibility`](#member-gfhitboxstate2d-properties-manage_visibility) | `var manage_visibility: bool = false` |
| 方法 | [`activate`](#member-gfhitboxstate2d-methods-activate) | `func activate() -> void:` |
| 方法 | [`deactivate`](#member-gfhitboxstate2d-methods-deactivate) | `func deactivate() -> void:` |
| 方法 | [`set_active_state`](#member-gfhitboxstate2d-methods-set_active_state) | `func set_active_state(value: bool) -> void:` |
| 方法 | [`apply_state`](#member-gfhitboxstate2d-methods-apply_state) | `func apply_state() -> void:` |
| 方法 | [`get_managed_nodes`](#member-gfhitboxstate2d-methods-get_managed_nodes) | `func get_managed_nodes() -> Array[Node]:` |

## 信号

<a id="member-gfhitboxstate2d-signals-active_changed"></a>

### `active_changed`

- API：`public`

```gdscript
signal active_changed(active: bool)
```

状态应用后发出。

参数：

| 名称 | 说明 |
|---|---|
| `active` | 当前是否激活。 |

## 属性

<a id="member-gfhitboxstate2d-properties-active"></a>

### `active`

- API：`public`

```gdscript
var active: bool = true:
```

当前状态是否激活。

<a id="member-gfhitboxstate2d-properties-apply_on_ready"></a>

### `apply_on_ready`

- API：`public`

```gdscript
var apply_on_ready: bool = true
```

是否在 _ready() 时应用当前状态。

<a id="member-gfhitboxstate2d-properties-recursive"></a>

### `recursive`

- API：`public`

```gdscript
var recursive: bool = true
```

是否递归管理子节点。

<a id="member-gfhitboxstate2d-properties-manage_enabled"></a>

### `manage_enabled`

- API：`public`

```gdscript
var manage_enabled: bool = true
```

是否同步 GFHitBox2D/GFHurtBox2D 的 enabled 字段。

<a id="member-gfhitboxstate2d-properties-manage_monitoring"></a>

### `manage_monitoring`

- API：`public`

```gdscript
var manage_monitoring: bool = true
```

是否同步 Area2D 的 monitoring 与 monitorable。

<a id="member-gfhitboxstate2d-properties-manage_visibility"></a>

### `manage_visibility`

- API：`public`

```gdscript
var manage_visibility: bool = false
```

是否同步 CanvasItem.visible。

## 方法

<a id="member-gfhitboxstate2d-methods-activate"></a>

### `activate`

- API：`public`

```gdscript
func activate() -> void:
```

激活状态组。

<a id="member-gfhitboxstate2d-methods-deactivate"></a>

### `deactivate`

- API：`public`

```gdscript
func deactivate() -> void:
```

关闭状态组。

<a id="member-gfhitboxstate2d-methods-set_active_state"></a>

### `set_active_state`

- API：`public`

```gdscript
func set_active_state(value: bool) -> void:
```

设置状态组激活状态。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 是否激活。 |

<a id="member-gfhitboxstate2d-methods-apply_state"></a>

### `apply_state`

- API：`public`

```gdscript
func apply_state() -> void:
```

应用当前状态到所有受管理节点。

<a id="member-gfhitboxstate2d-methods-get_managed_nodes"></a>

### `get_managed_nodes`

- API：`public`

```gdscript
func get_managed_nodes() -> Array[Node]:
```

获取受管理节点列表。

返回：节点列表。
