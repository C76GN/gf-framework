# GFUIMotionRecipe

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_recipe.gd`
- 模块：`Action Queue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

描述同一宿主的双页与局部动效，引用目标由每次播放调用显式提供。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`enter_delay`](#member-gfuimotionrecipe-properties-enter_delay) | `var enter_delay: float = 0.0` |
| 属性 | [`enter_seconds`](#member-gfuimotionrecipe-properties-enter_seconds) | `var enter_seconds: float = 0.4` |
| 属性 | [`exit_delay`](#member-gfuimotionrecipe-properties-exit_delay) | `var exit_delay: float = 0.0` |
| 属性 | [`exit_seconds`](#member-gfuimotionrecipe-properties-exit_seconds) | `var exit_seconds: float = 0.3` |
| 属性 | [`tracks`](#member-gfuimotionrecipe-properties-tracks) | `var tracks: Array[GFUIMotionTrack] = []` |
| 方法 | [`duplicate_recipe`](#member-gfuimotionrecipe-methods-duplicate_recipe) | `func duplicate_recipe() -> GFUIMotionRecipe:` |

## 属性

<a id="member-gfuimotionrecipe-properties-enter_delay"></a>

### `enter_delay`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 60, 0.001, "or_greater")
var enter_delay: float = 0.0
```

新页开始进入前的等待秒数。

<a id="member-gfuimotionrecipe-properties-enter_seconds"></a>

### `enter_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 60, 0.001, "or_greater")
var enter_seconds: float = 0.4
```

新页入场时长，独立于页内轨道和旧页。

<a id="member-gfuimotionrecipe-properties-exit_delay"></a>

### `exit_delay`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 60, 0.001, "or_greater")
var exit_delay: float = 0.0
```

旧页开始退出前的等待秒数。

<a id="member-gfuimotionrecipe-properties-exit_seconds"></a>

### `exit_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export_range(0, 60, 0.001, "or_greater")
var exit_seconds: float = 0.3
```

旧页退出时长，独立于新页。

<a id="member-gfuimotionrecipe-properties-tracks"></a>

### `tracks`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var tracks: Array[GFUIMotionTrack] = []
```

同一时刻按声明顺序触发，各目标的局部持续时间可超过页时钟。

## 方法

<a id="member-gfuimotionrecipe-methods-duplicate_recipe"></a>

### `duplicate_recipe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_recipe() -> GFUIMotionRecipe:
```

深复制配方内嵌的轨道和效果，对外部资源保留显式引用。

返回：可独立调整的配方副本；资源复制失败时为空。
