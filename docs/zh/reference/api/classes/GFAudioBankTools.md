# GFAudioBankTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_bank_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`3.17.0`

音频集合扫描、导入和校验辅助。 面向编辑器工具和构建脚本复用；它只生成 `GFAudioBank` / `GFAudioClip` 配置，不接管运行时播放策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ClipIdMode`](#member-gfaudiobanktools-enums-clipidmode) | `enum ClipIdMode` |
| 常量 | [`AUDIO_EXTENSIONS`](#member-gfaudiobanktools-constants-audio_extensions) | `const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3", "opus"]` |
| 常量 | [`DEFAULT_EXCLUDED_PATHS`](#member-gfaudiobanktools-constants-default_excluded_paths) | `const DEFAULT_EXCLUDED_PATHS: PackedStringArray = ["res://addons"]` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfaudiobanktools-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_AUDIO_PATHS`](#member-gfaudiobanktools-constants-default_max_audio_paths) | `const DEFAULT_MAX_AUDIO_PATHS: int = 10000` |
| 常量 | [`DEFAULT_MAX_SCANNED_ENTRIES`](#member-gfaudiobanktools-constants-default_max_scanned_entries) | `const DEFAULT_MAX_SCANNED_ENTRIES: int = 100000` |
| 常量 | [`ABSOLUTE_MAX_SCAN_DEPTH`](#member-gfaudiobanktools-constants-absolute_max_scan_depth) | `const ABSOLUTE_MAX_SCAN_DEPTH: int = 64` |
| 常量 | [`ABSOLUTE_MAX_AUDIO_PATHS`](#member-gfaudiobanktools-constants-absolute_max_audio_paths) | `const ABSOLUTE_MAX_AUDIO_PATHS: int = 100000` |
| 常量 | [`ABSOLUTE_MAX_SCANNED_ENTRIES`](#member-gfaudiobanktools-constants-absolute_max_scanned_entries) | `const ABSOLUTE_MAX_SCANNED_ENTRIES: int = 1000000` |
| 方法 | [`is_audio_path`](#member-gfaudiobanktools-methods-is_audio_path) | `static func is_audio_path(path: String, extensions: PackedStringArray = AUDIO_EXTENSIONS) -> bool:` |
| 方法 | [`scan_audio_paths`](#member-gfaudiobanktools-methods-scan_audio_paths) | `static func scan_audio_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`create_bank_from_paths`](#member-gfaudiobanktools-methods-create_bank_from_paths) | `static func create_bank_from_paths(paths: PackedStringArray, options: Dictionary = {}) -> GFAudioBank:` |
| 方法 | [`create_bank_from_scan`](#member-gfaudiobanktools-methods-create_bank_from_scan) | `static func create_bank_from_scan(root_path: String = "res://", options: Dictionary = {}) -> GFAudioBank:` |
| 方法 | [`add_paths_to_bank`](#member-gfaudiobanktools-methods-add_paths_to_bank) | `static func add_paths_to_bank( bank: GFAudioBank, paths: PackedStringArray, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`sync_bank_from_scan`](#member-gfaudiobanktools-methods-sync_bank_from_scan) | `static func sync_bank_from_scan( bank: GFAudioBank, root_path: String = "res://", options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`validate_bank_playback`](#member-gfaudiobanktools-methods-validate_bank_playback) | `static func validate_bank_playback(bank: GFAudioBank, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`make_clip_id`](#member-gfaudiobanktools-methods-make_clip_id) | `static func make_clip_id(path: String, options: Dictionary = {}) -> StringName:` |

## 枚举

<a id="member-gfaudiobanktools-enums-clipidmode"></a>

### `ClipIdMode`

- API：`public`

```gdscript
enum ClipIdMode {
	## 使用文件名，不包含扩展名。
	BASENAME,
	## 使用相对 base_path 的路径，不包含扩展名。
	RELATIVE_PATH,
	## 使用完整资源路径，不包含扩展名。
	FULL_PATH,
}
```

从音频路径生成片段 ID 的方式。

## 常量

<a id="member-gfaudiobanktools-constants-audio_extensions"></a>

### `AUDIO_EXTENSIONS`

- API：`public`

```gdscript
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3", "opus"]
```

默认音频扩展名白名单，不包含点号。

<a id="member-gfaudiobanktools-constants-default_excluded_paths"></a>

### `DEFAULT_EXCLUDED_PATHS`

- API：`public`

```gdscript
const DEFAULT_EXCLUDED_PATHS: PackedStringArray = ["res://addons"]
```

默认排除的扫描路径。

<a id="member-gfaudiobanktools-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认递归扫描深度上限。

<a id="member-gfaudiobanktools-constants-default_max_audio_paths"></a>

### `DEFAULT_MAX_AUDIO_PATHS`

- API：`public`

```gdscript
const DEFAULT_MAX_AUDIO_PATHS: int = 10000
```

默认单次扫描收集的音频路径数量上限。

<a id="member-gfaudiobanktools-constants-default_max_scanned_entries"></a>

### `DEFAULT_MAX_SCANNED_ENTRIES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_SCANNED_ENTRIES: int = 100000
```

默认单次扫描检查的目录项总数上限。

<a id="member-gfaudiobanktools-constants-absolute_max_scan_depth"></a>

### `ABSOLUTE_MAX_SCAN_DEPTH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SCAN_DEPTH: int = 64
```

单次扫描递归深度的框架绝对硬上限。

<a id="member-gfaudiobanktools-constants-absolute_max_audio_paths"></a>

### `ABSOLUTE_MAX_AUDIO_PATHS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_AUDIO_PATHS: int = 100000
```

单次扫描收集音频路径数量的框架绝对硬上限。

<a id="member-gfaudiobanktools-constants-absolute_max_scanned_entries"></a>

### `ABSOLUTE_MAX_SCANNED_ENTRIES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SCANNED_ENTRIES: int = 1000000
```

单次扫描检查目录项总数的框架绝对硬上限。

## 方法

<a id="member-gfaudiobanktools-methods-is_audio_path"></a>

### `is_audio_path`

- API：`public`

```gdscript
static func is_audio_path(path: String, extensions: PackedStringArray = AUDIO_EXTENSIONS) -> bool:
```

判断路径是否指向 GF 默认支持的音频扩展名。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或文件名。 |
| `extensions` | 可选扩展名白名单，不包含点号。 |

返回：是音频路径时返回 true。

<a id="member-gfaudiobanktools-methods-scan_audio_paths"></a>

### `scan_audio_paths`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func scan_audio_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
```

递归扫描音频路径。 默认跳过 DirAccess 可识别的 symbolic link。三个 `max_*` 预算始终受框架 绝对上限约束：正数会被 clamp，0 表示请求框架绝对上限，负数恢复默认值。 max_scan_depth、max_audio_paths 与 max_scanned_entries。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res:// 下的目录。 |
| `options` | 可选项，支持 recursive、include_addons、excluded_paths、extensions、 |

返回：按字典序排序的音频路径。

结构：

- `options`: Dictionary，可包含 recursive、include_addons、excluded_paths、extensions、max_scan_depth、max_audio_paths 和 max_scanned_entries 字段。

<a id="member-gfaudiobanktools-methods-create_bank_from_paths"></a>

### `create_bank_from_paths`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func create_bank_from_paths(paths: PackedStringArray, options: Dictionary = {}) -> GFAudioBank:
```

从路径列表创建新的音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 音频资源路径列表。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension、bus_name、volume_db、pitch_scale、metadata、metadata_by_path。 |

返回：新建的音频集合。

结构：

- `options`: Dictionary，可包含 id_mode、base_path、path_separator、strip_extension、bus_name、volume_db、pitch_scale、metadata、metadata_by_path 和 overwrite 字段。

<a id="member-gfaudiobanktools-methods-create_bank_from_scan"></a>

### `create_bank_from_scan`

- API：`public`

```gdscript
static func create_bank_from_scan(root_path: String = "res://", options: Dictionary = {}) -> GFAudioBank:
```

扫描目录并创建新的音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res://audio。 |
| `options` | 可选项，同时传给 scan_audio_paths() 与 create_bank_from_paths()。 |

返回：新建的音频集合。

结构：

- `options`: Dictionary，可同时包含扫描选项和片段导入选项。

<a id="member-gfaudiobanktools-methods-add_paths_to_bank"></a>

### `add_paths_to_bank`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func add_paths_to_bank( bank: GFAudioBank, paths: PackedStringArray, options: Dictionary = {} ) -> GFValidationReport:
```

将路径列表加入音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 要写入的音频集合。 |
| `paths` | 音频资源路径列表。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension、overwrite、bus_name、volume_db、pitch_scale、metadata、metadata_by_path。 |

返回：导入报告。

结构：

- `options`: Dictionary，可包含 id_mode、base_path、path_separator、strip_extension、overwrite、bus_name、volume_db、pitch_scale、metadata 和 metadata_by_path 字段。

<a id="member-gfaudiobanktools-methods-sync_bank_from_scan"></a>

### `sync_bank_from_scan`

- API：`public`

```gdscript
static func sync_bank_from_scan( bank: GFAudioBank, root_path: String = "res://", options: Dictionary = {} ) -> GFValidationReport:
```

扫描目录并同步到已有音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 要写入的音频集合。 |
| `root_path` | 扫描起点，通常是 res://audio。 |
| `options` | 可选项，同时传给 scan_audio_paths() 与 add_paths_to_bank()。 |

返回：导入报告。

结构：

- `options`: Dictionary，可同时包含扫描选项和片段导入选项。

<a id="member-gfaudiobanktools-methods-validate_bank_playback"></a>

### `validate_bank_playback`

- API：`public`

```gdscript
static func validate_bank_playback(bank: GFAudioBank, options: Dictionary = {}) -> GFValidationReport:
```

校验音频集合是否适合交给 GFAudioUtility 播放。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 要校验的音频集合。 |
| `options` | 可选项，支持 check_resource_exists、check_bus_exists、extensions。 |

返回：校验报告。

结构：

- `options`: Dictionary，可包含 check_resource_exists、check_bus_exists 和 extensions 字段。

<a id="member-gfaudiobanktools-methods-make_clip_id"></a>

### `make_clip_id`

- API：`public`

```gdscript
static func make_clip_id(path: String, options: Dictionary = {}) -> StringName:
```

按选项从路径生成稳定片段 ID。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 音频资源路径。 |
| `options` | 可选项，支持 id_mode、base_path、path_separator、strip_extension。 |

返回：片段 ID。

结构：

- `options`: Dictionary，可包含 id_mode、base_path、path_separator 和 strip_extension 字段。
