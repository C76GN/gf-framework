# GFAudioAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_audio_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

将一次 SFX 播放包装为视觉队列动作。 音效通常不应该阻塞表现队列，因此默认使用 fire-and-forget 完成模式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`path`](#member-gfaudioaction-properties-path) | `var path: String = ""` |
| 属性 | [`clip`](#member-gfaudioaction-properties-clip) | `var clip: GFAudioClip = null` |
| 属性 | [`bank`](#member-gfaudioaction-properties-bank) | `var bank: GFAudioBank = null` |
| 属性 | [`clip_id`](#member-gfaudioaction-properties-clip_id) | `var clip_id: StringName = &""` |
| 方法 | [`execute`](#member-gfaudioaction-methods-execute) | `func execute() -> Variant:` |

## 属性

<a id="member-gfaudioaction-properties-path"></a>

### `path`

- API：`public`

```gdscript
var path: String = ""
```

要播放的音频资源路径。

<a id="member-gfaudioaction-properties-clip"></a>

### `clip`

- API：`public`

```gdscript
var clip: GFAudioClip = null
```

要播放的音频片段配置。优先级高于 path。

<a id="member-gfaudioaction-properties-bank"></a>

### `bank`

- API：`public`

```gdscript
var bank: GFAudioBank = null
```

要播放的音频集合。与 clip_id 配合使用，优先级高于 clip。

<a id="member-gfaudioaction-properties-clip_id"></a>

### `clip_id`

- API：`public`

```gdscript
var clip_id: StringName = &""
```

音频集合中的片段标识。

## 方法

<a id="member-gfaudioaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行动作并通过 GFAudioUtility 播放一次 SFX。

返回：始终返回 null，避免阻塞表现队列。

结构：

- `return`: Variant，始终为 null。
