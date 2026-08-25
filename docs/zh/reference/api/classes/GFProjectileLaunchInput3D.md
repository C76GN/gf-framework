# GFProjectileLaunchInput3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_launch_input_3d.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

3D 发射请求的 typed 快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`TargetKind`](#member-gfprojectilelaunchinput3d-enums-targetkind) | `enum TargetKind` |
| 方法 | [`set_target_none`](#member-gfprojectilelaunchinput3d-methods-set_target_none) | `func set_target_none() -> void:` |
| 方法 | [`set_target_node`](#member-gfprojectilelaunchinput3d-methods-set_target_node) | `func set_target_node(node: Node3D) -> void:` |
| 方法 | [`set_target_position`](#member-gfprojectilelaunchinput3d-methods-set_target_position) | `func set_target_position(position_value: Vector3) -> void:` |
| 方法 | [`get_target_kind`](#member-gfprojectilelaunchinput3d-methods-get_target_kind) | `func get_target_kind() -> TargetKind:` |
| 方法 | [`get_target_node`](#member-gfprojectilelaunchinput3d-methods-get_target_node) | `func get_target_node() -> Node3D:` |
| 方法 | [`get_target_position`](#member-gfprojectilelaunchinput3d-methods-get_target_position) | `func get_target_position() -> Vector3:` |
| 方法 | [`set_metadata`](#member-gfprojectilelaunchinput3d-methods-set_metadata) | `func set_metadata(metadata: Dictionary) -> void:` |
| 方法 | [`get_metadata`](#member-gfprojectilelaunchinput3d-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`duplicate_input`](#member-gfprojectilelaunchinput3d-methods-duplicate_input) | `func duplicate_input() -> GFProjectileLaunchInput3D:` |

## 枚举

<a id="member-gfprojectilelaunchinput3d-enums-targetkind"></a>

### `TargetKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum TargetKind {
	## 未指定目标。
	NONE = 0,
	## 弱引用 Node3D 目标。
	NODE = 1,
	## 固定 world position 目标。
	POSITION = 2,
}
```

定义发射目标的封闭类型。

## 方法

<a id="member-gfprojectilelaunchinput3d-methods-set_target_none"></a>

### `set_target_none`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_target_none() -> void:
```

清除目标。

<a id="member-gfprojectilelaunchinput3d-methods-set_target_node"></a>

### `set_target_node`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_target_node(node: Node3D) -> void:
```

使用弱引用 Node3D 作为目标。

参数：

| 名称 | 说明 |
|---|---|
| `node` | live 目标；null 或失效目标会退化为 NONE。 |

<a id="member-gfprojectilelaunchinput3d-methods-set_target_position"></a>

### `set_target_position`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_target_position(position_value: Vector3) -> void:
```

使用固定 world position 作为目标。

参数：

| 名称 | 说明 |
|---|---|
| `position_value` | 目标 world position。 |

<a id="member-gfprojectilelaunchinput3d-methods-get_target_kind"></a>

### `get_target_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_kind() -> TargetKind:
```

返回当前目标类型。

返回：封闭 `TargetKind` 值。

<a id="member-gfprojectilelaunchinput3d-methods-get_target_node"></a>

### `get_target_node`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_node() -> Node3D:
```

返回当前 live node 目标。

返回：NODE 目标；未设置或已释放时返回 null。

<a id="member-gfprojectilelaunchinput3d-methods-get_target_position"></a>

### `get_target_position`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_position() -> Vector3:
```

返回固定位置目标。

返回：POSITION target 值。

<a id="member-gfprojectilelaunchinput3d-methods-set_metadata"></a>

### `set_metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_metadata(metadata: Dictionary) -> void:
```

深复制调用方 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `metadata` | 项目自定义发射 metadata。 |

结构：

- `metadata`: Dictionary，可包含项目字段；框架不写入 motion/session 私有状态。

<a id="member-gfprojectilelaunchinput3d-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_metadata() -> Dictionary:
```

返回 metadata 深副本。

返回：可由调用方修改的 metadata 副本。

结构：

- `return`: Dictionary，与内部快照完全分离的项目 metadata。

<a id="member-gfprojectilelaunchinput3d-methods-duplicate_input"></a>

### `duplicate_input`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_input() -> GFProjectileLaunchInput3D:
```

创建 target 与 metadata 均独立的 typed 副本。

返回：新的 3D launch input。
