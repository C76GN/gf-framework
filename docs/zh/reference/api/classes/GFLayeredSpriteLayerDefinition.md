# GFLayeredSpriteLayerDefinition

[API Reference](../index.md) / [Extensions / Layered Sprite](../extensions-layered-sprite.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/layered_sprite/resources/gf_layered_sprite_layer_definition.gd`
- 模块：`Extensions / Layered Sprite`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

GFLayeredSpriteLayerDefinition：分层精灵的单层定义。 层定义只描述稳定身份、绘制属性和可选帧变体；具体业务含义由项目自行解释。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`layer_id`](#member-gflayeredspritelayerdefinition-properties-layer_id) | `var layer_id: StringName = &""` |
| 属性 | [`default_variant_id`](#member-gflayeredspritelayerdefinition-properties-default_variant_id) | `var default_variant_id: StringName = &""` |
| 属性 | [`variants`](#member-gflayeredspritelayerdefinition-properties-variants) | `var variants: Array[GFLayeredSpriteVariant] = []` |
| 属性 | [`offset`](#member-gflayeredspritelayerdefinition-properties-offset) | `var offset: Vector2 = Vector2.ZERO` |
| 属性 | [`modulate`](#member-gflayeredspritelayerdefinition-properties-modulate) | `var modulate: Color = Color.WHITE` |
| 属性 | [`visible`](#member-gflayeredspritelayerdefinition-properties-visible) | `var visible: bool = true` |
| 属性 | [`draw_order`](#member-gflayeredspritelayerdefinition-properties-draw_order) | `var draw_order: int = 0` |

## 属性

<a id="member-gflayeredspritelayerdefinition-properties-layer_id"></a>

### `layer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var layer_id: StringName = &""
```

层稳定 ID。同一定义内必须唯一、非空且无首尾空白。

<a id="member-gflayeredspritelayerdefinition-properties-default_variant_id"></a>

### `default_variant_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var default_variant_id: StringName = &""
```

初始变体 ID，必须引用 [member variants] 中的条目。

<a id="member-gflayeredspritelayerdefinition-properties-variants"></a>

### `variants`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var variants: Array[GFLayeredSpriteVariant] = []
```

同一层可切换的帧变体。

<a id="member-gflayeredspritelayerdefinition-properties-offset"></a>

### `offset`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var offset: Vector2 = Vector2.ZERO
```

相对节点原点的绘制偏移。

<a id="member-gflayeredspritelayerdefinition-properties-modulate"></a>

### `modulate`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var modulate: Color = Color.WHITE
```

初始调制颜色。

<a id="member-gflayeredspritelayerdefinition-properties-visible"></a>

### `visible`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var visible: bool = true
```

初始可见性。

<a id="member-gflayeredspritelayerdefinition-properties-draw_order"></a>

### `draw_order`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var draw_order: int = 0
```

层内绘制顺序；数值较小的层先绘制。相同值保持定义顺序。
