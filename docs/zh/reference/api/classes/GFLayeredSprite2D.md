# GFLayeredSprite2D

[API Reference](../index.md) / [Extensions / Layered Sprite](../extensions-layered-sprite.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/layered_sprite/nodes/gf_layered_sprite_2d.gd`
- 模块：`Extensions / Layered Sprite`
- 继承：`Node2D`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`11.0.0`

GFLayeredSprite2D：由单一时间轴驱动的通用分层精灵节点。 配置会先完整校验并复制帧拓扑，再原子替换当前状态。节点只负责层、变体和播放， 不拥有资源发现、下载、缓存或任何项目业务分类。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`configuration_changed`](#member-gflayeredsprite2d-signals-configuration_changed) | `signal configuration_changed` |
| 信号 | [`animation_started`](#member-gflayeredsprite2d-signals-animation_started) | `signal animation_started(animation: StringName)` |
| 信号 | [`animation_finished`](#member-gflayeredsprite2d-signals-animation_finished) | `signal animation_finished(animation: StringName)` |
| 信号 | [`frame_changed`](#member-gflayeredsprite2d-signals-frame_changed) | `signal frame_changed(animation: StringName, frame: int)` |
| 信号 | [`layer_variant_changed`](#member-gflayeredsprite2d-signals-layer_variant_changed) | `signal layer_variant_changed(layer_id: StringName, variant_id: StringName)` |
| 常量 | [`MAX_LAYERS`](#member-gflayeredsprite2d-constants-max_layers) | `const MAX_LAYERS: int = 32` |
| 常量 | [`MAX_VARIANTS_PER_LAYER`](#member-gflayeredsprite2d-constants-max_variants_per_layer) | `const MAX_VARIANTS_PER_LAYER: int = 64` |
| 常量 | [`MAX_ANIMATIONS`](#member-gflayeredsprite2d-constants-max_animations) | `const MAX_ANIMATIONS: int = 128` |
| 常量 | [`MAX_FRAMES_PER_ANIMATION`](#member-gflayeredsprite2d-constants-max_frames_per_animation) | `const MAX_FRAMES_PER_ANIMATION: int = 4096` |
| 常量 | [`MAX_TOTAL_FRAME_REFERENCES`](#member-gflayeredsprite2d-constants-max_total_frame_references) | `const MAX_TOTAL_FRAME_REFERENCES: int = 65536` |
| 常量 | [`MAX_UNIQUE_TEXTURES`](#member-gflayeredsprite2d-constants-max_unique_textures) | `const MAX_UNIQUE_TEXTURES: int = 8192` |
| 常量 | [`MAX_FRAME_ADVANCES_PER_TICK`](#member-gflayeredsprite2d-constants-max_frame_advances_per_tick) | `const MAX_FRAME_ADVANCES_PER_TICK: int = 4096` |
| 常量 | [`MAX_SPEED_SCALE`](#member-gflayeredsprite2d-constants-max_speed_scale) | `const MAX_SPEED_SCALE: float = 1024.0` |
| 方法 | [`configure`](#member-gflayeredsprite2d-methods-configure) | `func configure(definition: GFLayeredSpriteDefinition) -> bool:` |
| 方法 | [`clear_configuration`](#member-gflayeredsprite2d-methods-clear_configuration) | `func clear_configuration() -> void:` |
| 方法 | [`is_configured`](#member-gflayeredsprite2d-methods-is_configured) | `func is_configured() -> bool:` |
| 方法 | [`get_animation_names`](#member-gflayeredsprite2d-methods-get_animation_names) | `func get_animation_names() -> Array[StringName]:` |
| 方法 | [`get_layer_ids`](#member-gflayeredsprite2d-methods-get_layer_ids) | `func get_layer_ids() -> Array[StringName]:` |
| 方法 | [`play`](#member-gflayeredsprite2d-methods-play) | `func play( animation: StringName, speed_scale: float = 1.0, from_end: bool = false ) -> bool:` |
| 方法 | [`pause`](#member-gflayeredsprite2d-methods-pause) | `func pause() -> void:` |
| 方法 | [`stop`](#member-gflayeredsprite2d-methods-stop) | `func stop(reset_to_start: bool = true) -> void:` |
| 方法 | [`seek`](#member-gflayeredsprite2d-methods-seek) | `func seek(frame: int, frame_progress: float = 0.0) -> bool:` |
| 方法 | [`advance`](#member-gflayeredsprite2d-methods-advance) | `func advance(delta_seconds: float) -> bool:` |
| 方法 | [`is_playing`](#member-gflayeredsprite2d-methods-is_playing) | `func is_playing() -> bool:` |
| 方法 | [`get_current_animation`](#member-gflayeredsprite2d-methods-get_current_animation) | `func get_current_animation() -> StringName:` |
| 方法 | [`get_current_frame`](#member-gflayeredsprite2d-methods-get_current_frame) | `func get_current_frame() -> int:` |
| 方法 | [`get_frame_progress`](#member-gflayeredsprite2d-methods-get_frame_progress) | `func get_frame_progress() -> float:` |
| 方法 | [`set_layer_variant`](#member-gflayeredsprite2d-methods-set_layer_variant) | `func set_layer_variant(layer_id: StringName, variant_id: StringName) -> bool:` |
| 方法 | [`get_layer_variant`](#member-gflayeredsprite2d-methods-get_layer_variant) | `func get_layer_variant(layer_id: StringName) -> StringName:` |
| 方法 | [`set_layer_visible`](#member-gflayeredsprite2d-methods-set_layer_visible) | `func set_layer_visible(layer_id: StringName, layer_visible: bool) -> bool:` |
| 方法 | [`is_layer_visible`](#member-gflayeredsprite2d-methods-is_layer_visible) | `func is_layer_visible(layer_id: StringName) -> bool:` |
| 方法 | [`set_layer_modulate`](#member-gflayeredsprite2d-methods-set_layer_modulate) | `func set_layer_modulate(layer_id: StringName, layer_modulate: Color) -> bool:` |
| 方法 | [`set_layer_offset`](#member-gflayeredsprite2d-methods-set_layer_offset) | `func set_layer_offset(layer_id: StringName, layer_offset: Vector2) -> bool:` |
| 方法 | [`get_last_rejection_reason`](#member-gflayeredsprite2d-methods-get_last_rejection_reason) | `func get_last_rejection_reason() -> StringName:` |

## 信号

<a id="member-gflayeredsprite2d-signals-configuration_changed"></a>

### `configuration_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal configuration_changed
```

完整配置成功替换后发出。

<a id="member-gflayeredsprite2d-signals-animation_started"></a>

### `animation_started`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal animation_started(animation: StringName)
```

动画开始或恢复播放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `animation` | 已开始或恢复的动画 ID。 |

<a id="member-gflayeredsprite2d-signals-animation_finished"></a>

### `animation_finished`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal animation_finished(animation: StringName)
```

非循环动画到达边界时发出。

参数：

| 名称 | 说明 |
|---|---|
| `animation` | 已到达非循环边界的动画 ID。 |

<a id="member-gflayeredsprite2d-signals-frame_changed"></a>

### `frame_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal frame_changed(animation: StringName, frame: int)
```

当前帧身份改变时发出。

参数：

| 名称 | 说明 |
|---|---|
| `animation` | 当前动画 ID。 |
| `frame` | 当前从 0 开始的帧索引。 |

<a id="member-gflayeredsprite2d-signals-layer_variant_changed"></a>

### `layer_variant_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal layer_variant_changed(layer_id: StringName, variant_id: StringName)
```

某层成功切换变体后发出。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 已切换的稳定层 ID。 |
| `variant_id` | 新的稳定变体 ID。 |

## 常量

<a id="member-gflayeredsprite2d-constants-max_layers"></a>

### `MAX_LAYERS`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_LAYERS: int = 32
```

单个定义允许的最大层数。

<a id="member-gflayeredsprite2d-constants-max_variants_per_layer"></a>

### `MAX_VARIANTS_PER_LAYER`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_VARIANTS_PER_LAYER: int = 64
```

单层允许的最大变体数。

<a id="member-gflayeredsprite2d-constants-max_animations"></a>

### `MAX_ANIMATIONS`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_ANIMATIONS: int = 128
```

时间轴允许的最大动画数。

<a id="member-gflayeredsprite2d-constants-max_frames_per_animation"></a>

### `MAX_FRAMES_PER_ANIMATION`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_FRAMES_PER_ANIMATION: int = 4096
```

单动画允许的最大帧数。

<a id="member-gflayeredsprite2d-constants-max_total_frame_references"></a>

### `MAX_TOTAL_FRAME_REFERENCES`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_TOTAL_FRAME_REFERENCES: int = 65536
```

一个配置允许引用的最大总帧数。

<a id="member-gflayeredsprite2d-constants-max_unique_textures"></a>

### `MAX_UNIQUE_TEXTURES`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_UNIQUE_TEXTURES: int = 8192
```

一个配置允许引用的最大唯一纹理数。

<a id="member-gflayeredsprite2d-constants-max_frame_advances_per_tick"></a>

### `MAX_FRAME_ADVANCES_PER_TICK`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_FRAME_ADVANCES_PER_TICK: int = 4096
```

单次推进允许跨越的最大帧边界数。

<a id="member-gflayeredsprite2d-constants-max_speed_scale"></a>

### `MAX_SPEED_SCALE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_SPEED_SCALE: float = 1024.0
```

播放速度绝对值上限。

## 方法

<a id="member-gflayeredsprite2d-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func configure(definition: GFLayeredSpriteDefinition) -> bool:
```

原子配置时间轴与全部层。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 待验证并复制的定义资源。 |

返回：配置完整有效且已替换时返回 true；失败时保留原配置。

<a id="member-gflayeredsprite2d-methods-clear_configuration"></a>

### `clear_configuration`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func clear_configuration() -> void:
```

清除当前配置和播放状态。

<a id="member-gflayeredsprite2d-methods-is_configured"></a>

### `is_configured`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_configured() -> bool:
```

是否持有完整有效的配置快照。

返回：已配置时返回 true。

<a id="member-gflayeredsprite2d-methods-get_animation_names"></a>

### `get_animation_names`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_animation_names() -> Array[StringName]:
```

返回稳定排序的动画名称快照。

返回：与内部数组隔离的动画名称数组。

<a id="member-gflayeredsprite2d-methods-get_layer_ids"></a>

### `get_layer_ids`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_layer_ids() -> Array[StringName]:
```

返回按绘制顺序排列的层 ID 快照。

返回：与内部数组隔离的层 ID 数组。

<a id="member-gflayeredsprite2d-methods-play"></a>

### `play`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func play( animation: StringName, speed_scale: float = 1.0, from_end: bool = false ) -> bool:
```

播放指定动画。 暂停或显式定位后的同名动画会从保留游标继续；首次播放、停止或完成后的 同名动画会按速度方向重新初始化，反向播放从末端开始。[param from_end] 会显式强制从末端重新开始。

参数：

| 名称 | 说明 |
|---|---|
| `animation` | 时间轴动画 ID。 |
| `speed_scale` | 有限且非零的播放速度；负值表示反向播放。 |
| `from_end` | 是否从动画末帧开始。 |

返回：参数有效且已开始播放时返回 true。

<a id="member-gflayeredsprite2d-methods-pause"></a>

### `pause`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func pause() -> void:
```

暂停并保留当前帧位置。

<a id="member-gflayeredsprite2d-methods-stop"></a>

### `stop`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func stop(reset_to_start: bool = true) -> void:
```

停止播放。

参数：

| 名称 | 说明 |
|---|---|
| `reset_to_start` | 是否将当前动画重置到首帧。 |

<a id="member-gflayeredsprite2d-methods-seek"></a>

### `seek`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func seek(frame: int, frame_progress: float = 0.0) -> bool:
```

将当前动画定位到指定帧和帧内进度。

参数：

| 名称 | 说明 |
|---|---|
| `frame` | 从 0 开始的帧索引。 |
| `frame_progress` | 当前帧内 0..1 的时间进度。 |

返回：定位参数有效时返回 true。

<a id="member-gflayeredsprite2d-methods-advance"></a>

### `advance`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func advance(delta_seconds: float) -> bool:
```

以秒为单位推进共享时间轴。 节点在播放时会自动调用本方法；确定性模拟也可在节点未入树时显式调用。

参数：

| 名称 | 说明 |
|---|---|
| `delta_seconds` | 非负、有限的推进时间。 |

返回：完整消费本次推进量时返回 true；参数非法或跨帧预算耗尽时返回 false。

<a id="member-gflayeredsprite2d-methods-is_playing"></a>

### `is_playing`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_playing() -> bool:
```

当前是否正在播放。

返回：正在自动推进时返回 true。

<a id="member-gflayeredsprite2d-methods-get_current_animation"></a>

### `get_current_animation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_current_animation() -> StringName:
```

返回当前动画 ID。

返回：当前动画 ID；未配置时为空。

<a id="member-gflayeredsprite2d-methods-get_current_frame"></a>

### `get_current_frame`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_current_frame() -> int:
```

返回当前帧索引。

返回：当前帧索引。

<a id="member-gflayeredsprite2d-methods-get_frame_progress"></a>

### `get_frame_progress`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_frame_progress() -> float:
```

返回当前帧内的 0..1 时间进度。

返回：当前帧内进度。

<a id="member-gflayeredsprite2d-methods-set_layer_variant"></a>

### `set_layer_variant`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_layer_variant(layer_id: StringName, variant_id: StringName) -> bool:
```

切换指定层的帧变体。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 待切换的稳定层 ID。 |
| `variant_id` | 该层中已配置的稳定变体 ID。 |

返回：层和变体均存在时返回 true。

<a id="member-gflayeredsprite2d-methods-get_layer_variant"></a>

### `get_layer_variant`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_layer_variant(layer_id: StringName) -> StringName:
```

返回指定层的当前变体 ID。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 待读取的稳定层 ID。 |

返回：当前变体 ID；层不存在时为空。

<a id="member-gflayeredsprite2d-methods-set_layer_visible"></a>

### `set_layer_visible`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_layer_visible(layer_id: StringName, layer_visible: bool) -> bool:
```

设置指定层可见性。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 待修改的稳定层 ID。 |
| `layer_visible` | 新可见状态。 |

返回：层存在时返回 true。

<a id="member-gflayeredsprite2d-methods-is_layer_visible"></a>

### `is_layer_visible`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_layer_visible(layer_id: StringName) -> bool:
```

返回指定层可见性。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 待读取的稳定层 ID。 |

返回：层存在且可见时返回 true。

<a id="member-gflayeredsprite2d-methods-set_layer_modulate"></a>

### `set_layer_modulate`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_layer_modulate(layer_id: StringName, layer_modulate: Color) -> bool:
```

设置指定层调制颜色。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 待修改的稳定层 ID。 |
| `layer_modulate` | 所有分量均须有限的新调制颜色。 |

返回：层存在且颜色分量均有限时返回 true。

<a id="member-gflayeredsprite2d-methods-set_layer_offset"></a>

### `set_layer_offset`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_layer_offset(layer_id: StringName, layer_offset: Vector2) -> bool:
```

设置指定层绘制偏移。

参数：

| 名称 | 说明 |
|---|---|
| `layer_id` | 待修改的稳定层 ID。 |
| `layer_offset` | 两分量均须有限的新绘制偏移。 |

返回：层存在且偏移分量均有限时返回 true。

<a id="member-gflayeredsprite2d-methods-get_last_rejection_reason"></a>

### `get_last_rejection_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_last_rejection_reason() -> StringName:
```

返回最近一次拒绝原因。

返回：稳定原因 ID；最近一次操作成功时为空。
