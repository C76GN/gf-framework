# GFAudioMetadataTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_metadata_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用音频元数据提取与规范化工具。 负责把 `AudioStream` 属性、`GFAudioClip.metadata` 和常见 ID3v2 文本帧 规范化为纯 Dictionary 报告。该类不接管导入器、不解码封面图片、不定义项目音频命名或播放策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_ID3_BYTES`](#member-gfaudiometadatatools-constants-default_max_id3_bytes) | `const DEFAULT_MAX_ID3_BYTES: int = 1024 * 1024` |
| 常量 | [`ABSOLUTE_MAX_ID3_BYTES`](#member-gfaudiometadatatools-constants-absolute_max_id3_bytes) | `const ABSOLUTE_MAX_ID3_BYTES: int = 8 * 1024 * 1024` |
| 方法 | [`normalize_tag_name`](#member-gfaudiometadatatools-methods-normalize_tag_name) | `static func normalize_tag_name(tag_name: String) -> StringName:` |
| 方法 | [`normalize_metadata`](#member-gfaudiometadatatools-methods-normalize_metadata) | `static func normalize_metadata(metadata: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`merge_metadata`](#member-gfaudiometadatatools-methods-merge_metadata) | `static func merge_metadata( base_metadata: Dictionary, overlay_metadata: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_display_summary`](#member-gfaudiometadatatools-methods-make_display_summary) | `static func make_display_summary(metadata: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`extract_stream_metadata`](#member-gfaudiometadatatools-methods-extract_stream_metadata) | `static func extract_stream_metadata(stream: AudioStream, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`parse_id3v2_metadata`](#member-gfaudiometadatatools-methods-parse_id3v2_metadata) | `static func parse_id3v2_metadata(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`read_path_metadata`](#member-gfaudiometadatatools-methods-read_path_metadata) | `static func read_path_metadata(path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`read_clip_metadata`](#member-gfaudiometadatatools-methods-read_clip_metadata) | `static func read_clip_metadata(clip: GFAudioClip, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_clip_metadata`](#member-gfaudiometadatatools-methods-apply_clip_metadata) | `static func apply_clip_metadata(clip: GFAudioClip, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfaudiometadatatools-constants-default_max_id3_bytes"></a>

### `DEFAULT_MAX_ID3_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_ID3_BYTES: int = 1024 * 1024
```

默认单次 ID3 读取与解析的字节上限（含 10-byte header）。

<a id="member-gfaudiometadatatools-constants-absolute_max_id3_bytes"></a>

### `ABSOLUTE_MAX_ID3_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_ID3_BYTES: int = 8 * 1024 * 1024
```

框架允许的单次 ID3 读取与解析绝对硬上限（含 10-byte header）。 调用方只能收紧或在此范围内放宽 DEFAULT_MAX_ID3_BYTES，不能越过该上限。

## 方法

<a id="member-gfaudiometadatatools-methods-normalize_tag_name"></a>

### `normalize_tag_name`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func normalize_tag_name(tag_name: String) -> StringName:
```

规范化音频元数据标签名。

参数：

| 名称 | 说明 |
|---|---|
| `tag_name` | 原始标签名。 |

返回：规范化后的标签名。

<a id="member-gfaudiometadatatools-methods-normalize_metadata"></a>

### `normalize_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func normalize_metadata(metadata: Dictionary, options: Dictionary = {}) -> Dictionary:
```

规范化音频元数据字典。

参数：

| 名称 | 说明 |
|---|---|
| `metadata` | 原始元数据字典。 |
| `options` | 可选项，支持 \`drop_null_values\`。 |

返回：规范化后的元数据副本。

结构：

- `metadata`: Dictionary audio metadata payload.
- `options`: Dictionary normalization options.
- `return`: Dictionary normalized audio metadata.

<a id="member-gfaudiometadatatools-methods-merge_metadata"></a>

### `merge_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func merge_metadata( base_metadata: Dictionary, overlay_metadata: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

合并两份音频元数据。

参数：

| 名称 | 说明 |
|---|---|
| `base_metadata` | 基础元数据。 |
| `overlay_metadata` | 覆盖元数据。 |
| `options` | 可选项，支持 \`overwrite\` 与 normalize_metadata() 的选项。 |

返回：合并后的元数据副本。

结构：

- `base_metadata`: Dictionary audio metadata payload.
- `overlay_metadata`: Dictionary audio metadata payload.
- `options`: Dictionary merge options.
- `return`: Dictionary merged normalized audio metadata.

<a id="member-gfaudiometadatatools-methods-make_display_summary"></a>

### `make_display_summary`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func make_display_summary(metadata: Dictionary, options: Dictionary = {}) -> Dictionary:
```

从元数据生成展示摘要。

参数：

| 名称 | 说明 |
|---|---|
| `metadata` | 音频元数据。 |
| `options` | 可选项，支持 \`fallback_title\`。 |

返回：展示摘要。

结构：

- `metadata`: Dictionary audio metadata payload.
- `options`: Dictionary summary options.
- `return`: Dictionary with `title`, `artist`, `album`, `album_artist`, `genre`, `track_number`, `track_count`, `year`, `bpm`, `duration_seconds`, and `has_cover`.

<a id="member-gfaudiometadatatools-methods-extract_stream_metadata"></a>

### `extract_stream_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func extract_stream_metadata(stream: AudioStream, options: Dictionary = {}) -> Dictionary:
```

从 AudioStream 提取元数据报告。

参数：

| 名称 | 说明 |
|---|---|
| `stream` | 要读取的音频流。 |
| `options` | 可选项，支持 \`parse_stream_data\`。 |

返回：元数据报告。

结构：

- `options`: Dictionary extraction options.
- `return`: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, and optional `id3_version`.

<a id="member-gfaudiometadatatools-methods-parse_id3v2_metadata"></a>

### `parse_id3v2_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func parse_id3v2_metadata(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:
```

解析 ID3v2 字节中的常见音频元数据。 后者会被约束在 10 到 ABSOLUTE_MAX_ID3_BYTES 之间。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 音频文件开头或完整文件字节。 |
| `options` | 可选项，支持 \`fail_on_frame_error\` 与 \`max_id3_bytes\`； |

返回：ID3v2 元数据报告。

结构：

- `options`: Dictionary ID3 parsing options.
- `return`: Dictionary with `ok: bool`, `recognized: bool`, `partial: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, `id3_version: String`, `id3_flags: int`, `unsupported_features: Array[String]`, `tag_size: int`, `frame_count: int`, `skipped_frame_count: int`, `requested_max_id3_bytes: int`, `effective_max_id3_bytes: int`, `absolute_max_id3_bytes: int`, `limit_clamped: bool`, `input_bytes: int`, and `processed_id3_bytes: int`.

<a id="member-gfaudiometadatatools-methods-read_path_metadata"></a>

### `read_path_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func read_path_metadata(path: String, options: Dictionary = {}) -> Dictionary:
```

从本地路径读取音频元数据报告。 ABSOLUTE_MAX_ID3_BYTES 之间。读取先取固定 header，再按声明长度和有效上限取 body。

参数：

| 名称 | 说明 |
|---|---|
| `path` | \`res://\`、\`user://\` 或绝对路径。 |
| `options` | 可选项，支持 \`max_id3_bytes\`；请求值会被约束在 10 到 |

返回：元数据报告。

结构：

- `options`: Dictionary read options.
- `return`: Dictionary with `ok: bool`, `recognized: bool`, `partial: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, `path: String`, `file_size_bytes: int`, `read_bytes: int`, `requested_max_id3_bytes: int`, `effective_max_id3_bytes: int`, `absolute_max_id3_bytes: int`, and `limit_clamped: bool`.

<a id="member-gfaudiometadatatools-methods-read_clip_metadata"></a>

### `read_clip_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func read_clip_metadata(clip: GFAudioClip, options: Dictionary = {}) -> Dictionary:
```

读取音频片段的合并元数据报告。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 要读取的音频片段。 |
| `options` | 可选项，支持 \`include_stream\`、\`include_path\` 和 \`overwrite_existing\`。 |

返回：元数据报告。

结构：

- `options`: Dictionary clip metadata options.
- `return`: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, and `issue_count: int`.

<a id="member-gfaudiometadatatools-methods-apply_clip_metadata"></a>

### `apply_clip_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func apply_clip_metadata(clip: GFAudioClip, options: Dictionary = {}) -> Dictionary:
```

将读取到的元数据写回音频片段。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 要写入的音频片段。 |
| `options` | 可选项，格式同 read_clip_metadata()。 |

返回：写入报告。

结构：

- `options`: Dictionary clip metadata options.
- `return`: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, and `applied: bool`.
