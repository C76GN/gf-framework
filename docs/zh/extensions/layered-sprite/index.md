# Layered Sprite 共享时间轴分层精灵

Layered Sprite 扩展把多张同步变化的 2D 纹理组织为“时间轴 + 稳定层 + 层内变体”。它适合需要运行时组合外观、但所有可见层必须严格保持同帧的场景。扩展不解释层的业务含义，也不负责资源发现、下载、导入、缓存或项目存档。

扩展默认关闭，包 ID 为 `gf.extension.layered_sprite`，不会自动加入 2D 预设。只有项目确实需要共享时间轴组合时才应安装；单张 `AnimatedSprite2D`、独立播放的特效层或只在制作期合并的纹理无需使用它。

## 核心模型

- `GFLayeredSpriteDefinition` 持有唯一 `SpriteFrames` 时间轴和层集合。时间轴拥有动画名称、循环、速度和相对帧时长。
- `GFLayeredSpriteLayerDefinition` 用稳定 `layer_id` 描述绘制顺序、偏移、初始可见性和初始调制色。
- `GFLayeredSpriteVariant` 用稳定 `variant_id` 关联该层的一组 `SpriteFrames`。每个变体的动画名称集合和各动画帧数必须与时间轴完全一致；变体自身的速度和循环配置不会成为第二个时钟。
- `GFLayeredSprite2D` 先有界校验并复制完整拓扑，再一次性替换运行态。失败配置不会清除或部分改写旧配置。

```gdscript
var sprite := GFLayeredSprite2D.new()
add_child(sprite)

if sprite.configure(definition):
	sprite.set_layer_variant(&"overlay", &"alternate")
	sprite.play(&"idle")
```

层 ID 和变体 ID 只是项目定义的稳定键。框架不内建角色、服装、装备、武器、方向或材质槽等业务词汇；项目可用同一机制表达任何需要同步帧拓扑的视觉组合。

## 播放与确定性

节点只推进一份时间轴状态，并按同一个动画 ID 与帧索引读取全部可见层。`play()` 支持有限、非零的正反向速度；`pause()` 保留当前位置；`seek()` 接受帧索引和帧内进度；`advance()` 可用于确定性测试或外部模拟时钟。节点入树并处于播放态时会自动以 `_process()` 的 `delta` 调用同一入口。

每次推进最多跨越 `MAX_FRAME_ADVANCES_PER_TICK` 个帧边界，速度绝对值也受硬上限约束。极端时间跳跃不会触发无界循环；调用方若收到 `false`，可读取 `get_last_rejection_reason()` 并决定丢弃该次推进、缩小步长或记录诊断。

配置、动画和帧信号都是同步信号。监听器若在回调内重新配置，后提交的完整配置获胜，外层调用不会再补发陈旧帧事件；`animation_started` 监听器只调用 `pause()`、`stop(false)` 或以新速度重播同一动画时，不会替换刚提交的动画/帧身份，因此对应 `frame_changed` 仍会恰好发出。监听器若在 `frame_changed` 中调用 `play()`、`seek()`、`pause()` 或 `stop()`，当前 `advance()` 会停止消费剩余时间，不会把旧时间量推进到新的播放代际。

## 配置不变量和预算

配置必须满足以下条件：

- 时间轴、层、默认变体和每个变体资源均存在；所有稳定 ID 非空、无首尾空白且在各自作用域唯一。
- 时间轴至少含一个动画，每个动画至少含一帧；速度和相对帧时长必须为有限正数。
- 每个变体与时间轴拥有完全相同的动画名称和帧数。这样切换变体不会改变共享时钟拓扑。
- 层数、单层变体数、动画数、单动画帧数、总帧引用数和唯一纹理数都受公开硬上限约束。
- 偏移与调制色的全部浮点分量必须有限。

配置成功后，节点持有隔离的 `SpriteFrames` 拓扑快照；调用方随后修改原定义、数组或 `SpriteFrames` 不会改变已提交状态。纹理资源本身仍作为不可变绘制资产共享，节点不会复制像素数据或接管纹理生命周期。

## 使用边界

Layered Sprite 是运行时渲染组合，不是素材库、角色外观系统或编辑器图形工具。项目仍需自行决定定义资源如何创建、稳定 ID 如何版本化、选择状态是否进入存档、网络上同步动画还是同步帧，以及纹理何时加载和卸载。若不同层需要独立时钟、骨骼混合、任意节点变换、Shader 参数图或异步流式资源，应由项目组合其他节点或专用渲染系统，不应把这些职责塞入本扩展。

源码入口为 `addons/gf/extensions/layered_sprite/`，聚焦回归位于 `tests/gf_core/extensions/layered_sprite/test_gf_layered_sprite_2d.gd`。

## API Reference

生成后的完整类、属性、信号和方法列表见 [Layered Sprite API Reference](../../reference/api/extensions-layered-sprite.md)。
