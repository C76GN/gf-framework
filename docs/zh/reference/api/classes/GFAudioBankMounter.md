# GFAudioBankMounter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_bank_mounter.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

场景生命周期驱动的音频集合挂载节点。 进入树时把 `GFAudioBank` 注册到 `GFAudioUtility`，退出树时按需恢复或卸载， 让场景、UI 或模块可以拥有自己的音频事件集合而不写全局业务逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`bank_mounted`](#member-gfaudiobankmounter-signals-bank_mounted) | `signal bank_mounted(bank_id: StringName)` |
| 信号 | [`bank_unmounted`](#member-gfaudiobankmounter-signals-bank_unmounted) | `signal bank_unmounted(bank_id: StringName)` |
| 属性 | [`bank_id`](#member-gfaudiobankmounter-properties-bank_id) | `var bank_id: StringName = &""` |
| 属性 | [`bank`](#member-gfaudiobankmounter-properties-bank) | `var bank: GFAudioBank = null` |
| 属性 | [`mount_on_ready`](#member-gfaudiobankmounter-properties-mount_on_ready) | `var mount_on_ready: bool = true` |
| 属性 | [`unmount_on_exit`](#member-gfaudiobankmounter-properties-unmount_on_exit) | `var unmount_on_exit: bool = true` |
| 属性 | [`restore_previous_bank`](#member-gfaudiobankmounter-properties-restore_previous_bank) | `var restore_previous_bank: bool = true` |
| 属性 | [`audio_utility`](#member-gfaudiobankmounter-properties-audio_utility) | `var audio_utility: GFAudioUtility = null` |
| 方法 | [`set_audio_utility`](#member-gfaudiobankmounter-methods-set_audio_utility) | `func set_audio_utility(utility: GFAudioUtility) -> void:` |
| 方法 | [`mount`](#member-gfaudiobankmounter-methods-mount) | `func mount() -> bool:` |
| 方法 | [`unmount`](#member-gfaudiobankmounter-methods-unmount) | `func unmount() -> bool:` |
| 方法 | [`is_mounted`](#member-gfaudiobankmounter-methods-is_mounted) | `func is_mounted() -> bool:` |

## 信号

<a id="member-gfaudiobankmounter-signals-bank_mounted"></a>

### `bank_mounted`

- API：`public`

```gdscript
signal bank_mounted(bank_id: StringName)
```

音频集合挂载完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |

<a id="member-gfaudiobankmounter-signals-bank_unmounted"></a>

### `bank_unmounted`

- API：`public`

```gdscript
signal bank_unmounted(bank_id: StringName)
```

音频集合卸载完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |

## 属性

<a id="member-gfaudiobankmounter-properties-bank_id"></a>

### `bank_id`

- API：`public`

```gdscript
var bank_id: StringName = &""
```

音频集合标识。

<a id="member-gfaudiobankmounter-properties-bank"></a>

### `bank`

- API：`public`

```gdscript
var bank: GFAudioBank = null
```

音频集合资源。

<a id="member-gfaudiobankmounter-properties-mount_on_ready"></a>

### `mount_on_ready`

- API：`public`

```gdscript
var mount_on_ready: bool = true
```

ready 后是否自动挂载。

<a id="member-gfaudiobankmounter-properties-unmount_on_exit"></a>

### `unmount_on_exit`

- API：`public`

```gdscript
var unmount_on_exit: bool = true
```

退出树时是否自动卸载。

<a id="member-gfaudiobankmounter-properties-restore_previous_bank"></a>

### `restore_previous_bank`

- API：`public`

```gdscript
var restore_previous_bank: bool = true
```

卸载时是否恢复同 ID 的旧音频集合。

<a id="member-gfaudiobankmounter-properties-audio_utility"></a>

### `audio_utility`

- API：`public`

```gdscript
var audio_utility: GFAudioUtility = null
```

可选音频工具实例；为空时从全局架构查询。

## 方法

<a id="member-gfaudiobankmounter-methods-set_audio_utility"></a>

### `set_audio_utility`

- API：`public`

```gdscript
func set_audio_utility(utility: GFAudioUtility) -> void:
```

设置音频工具实例。

参数：

| 名称 | 说明 |
|---|---|
| `utility` | 音频工具实例。 |

<a id="member-gfaudiobankmounter-methods-mount"></a>

### `mount`

- API：`public`

```gdscript
func mount() -> bool:
```

挂载音频集合。

返回：挂载成功返回 true。

<a id="member-gfaudiobankmounter-methods-unmount"></a>

### `unmount`

- API：`public`

```gdscript
func unmount() -> bool:
```

卸载音频集合。

返回：卸载成功返回 true。

<a id="member-gfaudiobankmounter-methods-is_mounted"></a>

### `is_mounted`

- API：`public`

```gdscript
func is_mounted() -> bool:
```

检查音频集合是否已挂载。

返回：已挂载返回 true。
