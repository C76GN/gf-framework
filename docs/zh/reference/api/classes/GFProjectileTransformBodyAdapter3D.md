# GFProjectileTransformBodyAdapter3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_transform_body_adapter_3d.gd`
- 模块：`Combat`
- 继承：`GFProjectileBodyAdapter3D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

直接应用 Node3D 变换的 body adapter。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_validate_root`](#member-gfprojectiletransformbodyadapter3d-methods-_validate_root) | `func _validate_root(root: Node) -> Error:` |
| 方法 | [`_capture_body`](#member-gfprojectiletransformbodyadapter3d-methods-_capture_body) | `func _capture_body(root: Node) -> GFProjectileBodyResult3D:` |
| 方法 | [`_apply_intent`](#member-gfprojectiletransformbodyadapter3d-methods-_apply_intent) | `func _apply_intent( root: Node, intent: GFProjectileMotionIntent3D ) -> GFProjectileBodyResult3D:` |
| 方法 | [`_stop`](#member-gfprojectiletransformbodyadapter3d-methods-_stop) | `func _stop(root: Node) -> GFProjectileBodyResult3D:` |

## 方法

<a id="member-gfprojectiletransformbodyadapter3d-methods-_validate_root"></a>

### `_validate_root`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _validate_root(root: Node) -> Error:
```

接纳仍存活且未排队删除的普通 Node3D，并排除需要物理运动协议的 PhysicsBody3D。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 待直接修改全局位置的根节点；此处不检查是否已进入场景树。 |

返回：可直接驱动时为 OK；无效节点为 ERR_INVALID_PARAMETER，PhysicsBody3D 为 ERR_UNAVAILABLE。

<a id="member-gfprojectiletransformbodyadapter3d-methods-_capture_body"></a>

### `_capture_body`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _capture_body(root: Node) -> GFProjectileBodyResult3D:
```

重新校验普通 Node3D 后捕获全局变换，不修改节点位置。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 要捕获快照的非物理发射体根节点。 |

返回：变换有限时为全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。

<a id="member-gfprojectiletransformbodyadapter3d-methods-_apply_intent"></a>

### `_apply_intent`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _apply_intent( root: Node, intent: GFProjectileMotionIntent3D ) -> GFProjectileBodyResult3D:
```

按 MOVE 的速度乘以时长直接写入 Node3D.global_position，不执行碰撞移动。 写入前检查位移与目标位置是否有限；其他有效 intent 种类保持位置不变。 结果工厂若因最终变换或实际位置差非有限而失败，不撤销已经写入的位置。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 可由本适配器直接移动的非物理根节点。 |
| `intent` | 本帧 intent；空值或 REJECTED 会在写入前失败，并尽量保留 intent 的失败原因。 |

返回：成功时为操作后的变换与实际位置差；root、intent 或目标位移非法时失败，最终变换或实际位置差非有限时返回 non_finite_body_result。

<a id="member-gfprojectiletransformbodyadapter3d-methods-_stop"></a>

### `_stop`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _stop(root: Node) -> GFProjectileBodyResult3D:
```

读取普通 Node3D 的当前变换并构造静止快照；本适配器不持有持续速度，因此无需写入节点。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 要结束直接位移驱动的非物理根节点。 |

返回：变换有限时为当前全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。
