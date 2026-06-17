# GFAudioBank

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_bank.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

音频片段配置集合。 用 StringName 管理一组 `GFAudioClip`，便于 UI、表现动作或项目配置 通过稳定 ID 播放音频。单个 ID 可保存一个片段或多个候选片段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`LifecycleState`](#member-gfaudiobank-enums-lifecyclestate) | `enum LifecycleState` |
| 属性 | [`clips`](#member-gfaudiobank-properties-clips) | `var clips: Dictionary = {}` |
| 属性 | [`fallback_separator`](#member-gfaudiobank-properties-fallback_separator) | `var fallback_separator: String = "+"` |
| 属性 | [`lifecycle_state`](#member-gfaudiobank-properties-lifecycle_state) | `var lifecycle_state: LifecycleState = LifecycleState.UNLOADED` |
| 属性 | [`lifecycle_reason`](#member-gfaudiobank-properties-lifecycle_reason) | `var lifecycle_reason: StringName = &""` |
| 方法 | [`set_clip`](#member-gfaudiobank-methods-set_clip) | `func set_clip(clip_id: StringName, clip: GFAudioClip) -> void:` |
| 方法 | [`set_clips`](#member-gfaudiobank-methods-set_clips) | `func set_clips(clip_id: StringName, clip_list: Array[GFAudioClip]) -> void:` |
| 方法 | [`get_clip`](#member-gfaudiobank-methods-get_clip) | `func get_clip(clip_id: StringName) -> GFAudioClip:` |
| 方法 | [`get_clips`](#member-gfaudiobank-methods-get_clips) | `func get_clips(clip_id: StringName) -> Array[GFAudioClip]:` |
| 方法 | [`get_weighted_clip`](#member-gfaudiobank-methods-get_weighted_clip) | `func get_weighted_clip(clip_id: StringName, rng: RandomNumberGenerator = null) -> GFAudioClip:` |
| 方法 | [`get_clip_with_fallback`](#member-gfaudiobank-methods-get_clip_with_fallback) | `func get_clip_with_fallback(clip_id: StringName, rng: RandomNumberGenerator = null) -> GFAudioClip:` |
| 方法 | [`resolve_clip`](#member-gfaudiobank-methods-resolve_clip) | `func resolve_clip(clip_id: StringName, rng: RandomNumberGenerator = null) -> Dictionary:` |
| 方法 | [`has_clip`](#member-gfaudiobank-methods-has_clip) | `func has_clip(clip_id: StringName) -> bool:` |
| 方法 | [`get_clip_ids`](#member-gfaudiobank-methods-get_clip_ids) | `func get_clip_ids() -> PackedStringArray:` |
| 方法 | [`set_lifecycle_state`](#member-gfaudiobank-methods-set_lifecycle_state) | `func set_lifecycle_state(state: LifecycleState, reason: StringName = &"") -> void:` |
| 方法 | [`get_lifecycle_snapshot`](#member-gfaudiobank-methods-get_lifecycle_snapshot) | `func get_lifecycle_snapshot() -> Dictionary:` |
| 方法 | [`validate_bank`](#member-gfaudiobank-methods-validate_bank) | `func validate_bank(check_resource_exists: bool = false) -> GFValidationReport:` |

## 枚举

<a id="member-gfaudiobank-enums-lifecyclestate"></a>

### `LifecycleState`

- API：`public`

```gdscript
enum LifecycleState {
	## 尚未加载。
	UNLOADED,
	## 正在加载。
	LOADING,
	## 已加载。
	LOADED,
	## 加载失败。
	FAILED,
}
```

音频集合加载状态。

## 属性

<a id="member-gfaudiobank-properties-clips"></a>

### `clips`

- API：`public`

```gdscript
var clips: Dictionary = {}
```

音频片段表。

结构：

- `clips`: Key 为 StringName 片段 ID，Value 为 GFAudioClip 或 GFAudioClip 数组。

<a id="member-gfaudiobank-properties-fallback_separator"></a>

### `fallback_separator`

- API：`public`

```gdscript
var fallback_separator: String = "+"
```

分层事件 ID 的回退分隔符。例如 `ui+confirm+primary` 可回退到 `ui+confirm` 再到 `ui`。

<a id="member-gfaudiobank-properties-lifecycle_state"></a>

### `lifecycle_state`

- API：`public`

```gdscript
var lifecycle_state: LifecycleState = LifecycleState.UNLOADED
```

加载状态。框架只记录状态，不假设具体加载后端。

<a id="member-gfaudiobank-properties-lifecycle_reason"></a>

### `lifecycle_reason`

- API：`public`

```gdscript
var lifecycle_reason: StringName = &""
```

最近一次加载或卸载结果原因。

## 方法

<a id="member-gfaudiobank-methods-set_clip"></a>

### `set_clip`

- API：`public`

```gdscript
func set_clip(clip_id: StringName, clip: GFAudioClip) -> void:
```

设置一个音频片段。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |
| `clip` | 片段配置。 |

<a id="member-gfaudiobank-methods-set_clips"></a>

### `set_clips`

- API：`public`

```gdscript
func set_clips(clip_id: StringName, clip_list: Array[GFAudioClip]) -> void:
```

设置一个音频片段候选列表。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |
| `clip_list` | 片段候选列表。 |

结构：

- `clip_list`: GFAudioClip 候选数组。

<a id="member-gfaudiobank-methods-get_clip"></a>

### `get_clip`

- API：`public`

```gdscript
func get_clip(clip_id: StringName) -> GFAudioClip:
```

获取音频片段。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |

返回：片段配置；多个候选时返回第一个有效片段，不存在时返回 null。

<a id="member-gfaudiobank-methods-get_clips"></a>

### `get_clips`

- API：`public`

```gdscript
func get_clips(clip_id: StringName) -> Array[GFAudioClip]:
```

获取音频片段候选列表。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |

返回：片段候选列表。

结构：

- `return`: GFAudioClip 候选数组。

<a id="member-gfaudiobank-methods-get_weighted_clip"></a>

### `get_weighted_clip`

- API：`public`

```gdscript
func get_weighted_clip(clip_id: StringName, rng: RandomNumberGenerator = null) -> GFAudioClip:
```

按候选权重获取片段。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |
| `rng` | 可选随机数生成器；为空时返回第一个有效片段。 |

返回：片段配置；不存在时返回 null。

<a id="member-gfaudiobank-methods-get_clip_with_fallback"></a>

### `get_clip_with_fallback`

- API：`public`

```gdscript
func get_clip_with_fallback(clip_id: StringName, rng: RandomNumberGenerator = null) -> GFAudioClip:
```

按 ID 获取片段；找不到时按 fallback_separator 逐级回退。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |
| `rng` | 可选随机数生成器。 |

返回：片段配置；不存在时返回 null。

<a id="member-gfaudiobank-methods-resolve_clip"></a>

### `resolve_clip`

- API：`public`

```gdscript
func resolve_clip(clip_id: StringName, rng: RandomNumberGenerator = null) -> Dictionary:
```

解析片段并返回诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |
| `rng` | 可选随机数生成器。 |

返回：解析报告。

结构：

- `return`: Dictionary，包含 ok、requested_id、resolved_id、fallback_used、attempted_ids 和 clip 字段。

<a id="member-gfaudiobank-methods-has_clip"></a>

### `has_clip`

- API：`public`

```gdscript
func has_clip(clip_id: StringName) -> bool:
```

检查是否存在指定片段。

参数：

| 名称 | 说明 |
|---|---|
| `clip_id` | 片段标识。 |

返回：存在时返回 true。

<a id="member-gfaudiobank-methods-get_clip_ids"></a>

### `get_clip_ids`

- API：`public`

```gdscript
func get_clip_ids() -> PackedStringArray:
```

获取全部片段 ID。

返回：按字典序排列的片段 ID。

<a id="member-gfaudiobank-methods-set_lifecycle_state"></a>

### `set_lifecycle_state`

- API：`public`

```gdscript
func set_lifecycle_state(state: LifecycleState, reason: StringName = &"") -> void:
```

设置音频集合加载状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 新状态。 |
| `reason` | 可选原因。 |

<a id="member-gfaudiobank-methods-get_lifecycle_snapshot"></a>

### `get_lifecycle_snapshot`

- API：`public`

```gdscript
func get_lifecycle_snapshot() -> Dictionary:
```

获取加载状态快照。

返回：状态快照字典。

结构：

- `return`: Dictionary，包含 state、reason 和 clip_count 字段。

<a id="member-gfaudiobank-methods-validate_bank"></a>

### `validate_bank`

- API：`public`

```gdscript
func validate_bank(check_resource_exists: bool = false) -> GFValidationReport:
```

校验音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `check_resource_exists` | 是否检查 path 指向的资源存在。 |

返回：校验报告。
