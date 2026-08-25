# GFProjectileBodyAdapter2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_body_adapter_2d.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

2D 发射体宿主运动适配协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`validate_root`](#member-gfprojectilebodyadapter2d-methods-validate_root) | `func validate_root(root: Node) -> Error:` |
| 方法 | [`capture_body`](#member-gfprojectilebodyadapter2d-methods-capture_body) | `func capture_body(root: Node) -> GFProjectileBodyResult2D:` |
| 方法 | [`apply_intent`](#member-gfprojectilebodyadapter2d-methods-apply_intent) | `func apply_intent( root: Node, intent: GFProjectileMotionIntent2D ) -> GFProjectileBodyResult2D:` |
| 方法 | [`stop`](#member-gfprojectilebodyadapter2d-methods-stop) | `func stop(root: Node) -> GFProjectileBodyResult2D:` |
| 方法 | [`_validate_root`](#member-gfprojectilebodyadapter2d-methods-_validate_root) | `func _validate_root(_root: Node) -> Variant:` |
| 方法 | [`_capture_body`](#member-gfprojectilebodyadapter2d-methods-_capture_body) | `func _capture_body(_root: Node) -> Variant:` |
| 方法 | [`_apply_intent`](#member-gfprojectilebodyadapter2d-methods-_apply_intent) | `func _apply_intent( _root: Node, _intent: GFProjectileMotionIntent2D ) -> Variant:` |
| 方法 | [`_stop`](#member-gfprojectilebodyadapter2d-methods-_stop) | `func _stop(_root: Node) -> Variant:` |

## 方法

<a id="member-gfprojectilebodyadapter2d-methods-validate_root"></a>

### `validate_root`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_root(root: Node) -> Error:
```

校验完整实例 root 是否由本 adapter 支持。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 待驱动的完整 projectile root。 |

返回：`OK` 表示支持，否则返回确定错误码。

<a id="member-gfprojectilebodyadapter2d-methods-capture_body"></a>

### `capture_body`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture_body(root: Node) -> GFProjectileBodyResult2D:
```

捕获运动计算所需的当前 body 快照。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 已通过 \`validate_root()\` 的 root。 |

返回：当前 transform 与零实际位移的 typed 结果。

<a id="member-gfprojectilebodyadapter2d-methods-apply_intent"></a>

### `apply_intent`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func apply_intent( root: Node, intent: GFProjectileMotionIntent2D ) -> GFProjectileBodyResult2D:
```

将一次 typed intent 应用于 root。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 已通过 \`validate_root()\` 的 root。 |
| `intent` | 本帧 motion intent。 |

返回：应用后的 transform 与实际 world displacement。

<a id="member-gfprojectilebodyadapter2d-methods-stop"></a>

### `stop`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func stop(root: Node) -> GFProjectileBodyResult2D:
```

停止 root 的运动 authority，不产生额外位移。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 已通过 \`validate_root()\` 的 root。 |

返回：停止后的 body 快照。

<a id="member-gfprojectilebodyadapter2d-methods-_validate_root"></a>

### `_validate_root`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _validate_root(_root: Node) -> Variant:
```

实现具体 root 准入规则。

参数：

| 名称 | 说明 |
|---|---|
| `_root` | 待校验 root。 |

返回：`OK` 或确定错误码。

结构：

- `return`: Variant，必须为 `Error` 整数值；其他值由公开入口收窄为 `ERR_INVALID_DATA`。

<a id="member-gfprojectilebodyadapter2d-methods-_capture_body"></a>

### `_capture_body`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _capture_body(_root: Node) -> Variant:
```

捕获具体 body 快照。

参数：

| 名称 | 说明 |
|---|---|
| `_root` | 已通过校验的 root。 |

返回：typed body 结果。

结构：

- `return`: Variant，必须为 live `GFProjectileBodyResult2D`。

<a id="member-gfprojectilebodyadapter2d-methods-_apply_intent"></a>

### `_apply_intent`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _apply_intent( _root: Node, _intent: GFProjectileMotionIntent2D ) -> Variant:
```

应用具体 body intent。

参数：

| 名称 | 说明 |
|---|---|
| `_root` | 已通过校验的 root。 |
| `_intent` | 本帧 intent。 |

返回：typed body 结果。

结构：

- `return`: Variant，必须为 live `GFProjectileBodyResult2D`。

<a id="member-gfprojectilebodyadapter2d-methods-_stop"></a>

### `_stop`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _stop(_root: Node) -> Variant:
```

停止具体 body。

参数：

| 名称 | 说明 |
|---|---|
| `_root` | 已通过校验的 root。 |

返回：typed body 结果。

结构：

- `return`: Variant，必须为 live `GFProjectileBodyResult2D`。
