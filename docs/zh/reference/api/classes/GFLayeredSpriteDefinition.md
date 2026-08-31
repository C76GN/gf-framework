# GFLayeredSpriteDefinition

[API Reference](../index.md) / [Extensions / Layered Sprite](../extensions-layered-sprite.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/layered_sprite/resources/gf_layered_sprite_definition.gd`
- 模块：`Extensions / Layered Sprite`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

GFLayeredSpriteDefinition：分层精灵的时间轴和层集合。 时间轴唯一拥有动画速度、循环和帧时长；各层变体只提供同拓扑的帧纹理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`timeline_frames`](#member-gflayeredspritedefinition-properties-timeline_frames) | `var timeline_frames: SpriteFrames = null` |
| 属性 | [`default_animation`](#member-gflayeredspritedefinition-properties-default_animation) | `var default_animation: StringName = &""` |
| 属性 | [`layers`](#member-gflayeredspritedefinition-properties-layers) | `var layers: Array[GFLayeredSpriteLayerDefinition] = []` |

## 属性

<a id="member-gflayeredspritedefinition-properties-timeline_frames"></a>

### `timeline_frames`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var timeline_frames: SpriteFrames = null
```

共享时间轴。其动画名称、帧数、帧时长和循环设置驱动全部层。

<a id="member-gflayeredspritedefinition-properties-default_animation"></a>

### `default_animation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var default_animation: StringName = &""
```

配置完成后使用的初始动画。为空时按动画名称稳定排序后选择第一项。

<a id="member-gflayeredspritedefinition-properties-layers"></a>

### `layers`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var layers: Array[GFLayeredSpriteLayerDefinition] = []
```

分层定义集合。
