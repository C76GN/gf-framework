# GFProjectileCharacterBodyAdapter2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_character_body_adapter_2d.gd`
- 模块：`Combat`
- 继承：`GFProjectileBodyAdapter2D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

CharacterBody2D 运动适配器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_validate_root`](#member-gfprojectilecharacterbodyadapter2d-methods-_validate_root) | `func _validate_root(root: Node) -> Error:` |
| 方法 | [`_capture_body`](#member-gfprojectilecharacterbodyadapter2d-methods-_capture_body) | `func _capture_body(root: Node) -> GFProjectileBodyResult2D:` |
| 方法 | [`_apply_intent`](#member-gfprojectilecharacterbodyadapter2d-methods-_apply_intent) | `func _apply_intent( root: Node, intent: GFProjectileMotionIntent2D ) -> GFProjectileBodyResult2D:` |
| 方法 | [`_stop`](#member-gfprojectilecharacterbodyadapter2d-methods-_stop) | `func _stop(root: Node) -> GFProjectileBodyResult2D:` |

## 方法

<a id="member-gfprojectilecharacterbodyadapter2d-methods-_validate_root"></a>

### `_validate_root`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _validate_root(root: Node) -> Error:
```

只接纳仍存活且未排队删除的 CharacterBody2D，供后续物理移动与速度写回使用。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 待驱动的完整发射体根节点；此处不检查是否已进入场景树。 |

返回：类型与生命周期符合要求时为 OK，否则为 ERR_INVALID_PARAMETER。

<a id="member-gfprojectilecharacterbodyadapter2d-methods-_capture_body"></a>

### `_capture_body`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _capture_body(root: Node) -> GFProjectileBodyResult2D:
```

重新校验 CharacterBody2D 后捕获其当前全局变换，不读取或修改速度。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 要捕获运动快照的发射体根节点。 |

返回：变换有限时为全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。

<a id="member-gfprojectilecharacterbodyadapter2d-methods-_apply_intent"></a>

### `_apply_intent`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _apply_intent( root: Node, intent: GFProjectileMotionIntent2D ) -> GFProjectileBodyResult2D:
```

将 MOVE 速度写入 CharacterBody2D 后调用 move_and_slide，返回实际产生的全局位移。 intent 时长用于候选位移的有限性预检，实际移动由 move_and_slide 执行；其他有效种类使用零速度。 若移动后位置或位移非有限，只还原本节点先前的变换与速度，不承诺撤销物理查询或其他外部影响。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 仍可用的 CharacterBody2D 根节点；本次调用会修改其速度并尝试移动。 |
| `intent` | 本帧 intent；空值或 REJECTED 会在移动前失败，并尽量保留 intent 的失败原因。 |

返回：移动后的 body 快照及实际位移；root、intent 或运动数值不合法时返回失败结果。

<a id="member-gfprojectilecharacterbodyadapter2d-methods-_stop"></a>

### `_stop`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _stop(root: Node) -> GFProjectileBodyResult2D:
```

校验 root 后先将 CharacterBody2D 的速度清零，再构造当前变换的结果，不调用 move_and_slide 或额外修改位置。 结果工厂因变换非有限返回失败时，不撤销已经完成的速度清零。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 要停止运动的发射体根节点。 |

返回：变换有限时为当前全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。
