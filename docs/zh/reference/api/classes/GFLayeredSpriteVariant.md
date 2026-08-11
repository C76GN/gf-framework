# GFLayeredSpriteVariant

[API Reference](../index.md) / [Extensions / Layered Sprite](../extensions-layered-sprite.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/layered_sprite/resources/gf_layered_sprite_variant.gd`
- 模块：`Extensions / Layered Sprite`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

GFLayeredSpriteVariant：分层精灵单层的帧资源变体。 变体只以稳定 ID 关联一组 [SpriteFrames]，不包含服装、装备或角色等业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`variant_id`](#member-gflayeredspritevariant-properties-variant_id) | `var variant_id: StringName = &""` |
| 属性 | [`sprite_frames`](#member-gflayeredspritevariant-properties-sprite_frames) | `var sprite_frames: SpriteFrames = null` |

## 属性

<a id="member-gflayeredspritevariant-properties-variant_id"></a>

### `variant_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var variant_id: StringName = &""
```

变体稳定 ID。同一层内必须唯一、非空且无首尾空白。

<a id="member-gflayeredspritevariant-properties-sprite_frames"></a>

### `sprite_frames`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var sprite_frames: SpriteFrames = null
```

该变体的帧资源。动画名称和每个动画的帧数必须与时间轴完全一致。
