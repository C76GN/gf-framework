# GFTimedTextImporter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/timeline/gf_timed_text_importer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用时间段文本解析器。 提供 SRT、WebVTT 与 LRC 的轻量解析入口，输出 `GFTimedTextTrack`。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`parse_srt`](#member-gftimedtextimporter-methods-parse_srt) | `static func parse_srt(text: String, track_id: StringName = &"") -> Dictionary:` |
| 方法 | [`parse_vtt`](#member-gftimedtextimporter-methods-parse_vtt) | `static func parse_vtt(text: String, track_id: StringName = &"") -> Dictionary:` |
| 方法 | [`parse_lrc`](#member-gftimedtextimporter-methods-parse_lrc) | `static func parse_lrc( text: String, default_duration: float = 2.0, track_id: StringName = &"" ) -> Dictionary:` |

## 方法

<a id="member-gftimedtextimporter-methods-parse_srt"></a>

### `parse_srt`

- API：`public`

```gdscript
static func parse_srt(text: String, track_id: StringName = &"") -> Dictionary:
```

解析 SRT 文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | SRT 文本。 |
| `track_id` | 可选轨道标识。 |

返回：解析结果字典，包含 success、track 与 error。

结构：

- `return`: Dictionary with success: bool, track: GFTimedTextTrack, error: String.

<a id="member-gftimedtextimporter-methods-parse_vtt"></a>

### `parse_vtt`

- API：`public`

```gdscript
static func parse_vtt(text: String, track_id: StringName = &"") -> Dictionary:
```

解析 WebVTT 文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | WebVTT 文本。 |
| `track_id` | 可选轨道标识。 |

返回：解析结果字典，包含 success、track 与 error。

结构：

- `return`: Dictionary with success: bool, track: GFTimedTextTrack, error: String.

<a id="member-gftimedtextimporter-methods-parse_lrc"></a>

### `parse_lrc`

- API：`public`

```gdscript
static func parse_lrc( text: String, default_duration: float = 2.0, track_id: StringName = &"" ) -> Dictionary:
```

解析 LRC 文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | LRC 文本。 |
| `default_duration` | 单行没有下一行时使用的默认时长。 |
| `track_id` | 可选轨道标识。 |

返回：解析结果字典，包含 success、track 与 error。

结构：

- `return`: Dictionary with success: bool, track: GFTimedTextTrack, error: String.
