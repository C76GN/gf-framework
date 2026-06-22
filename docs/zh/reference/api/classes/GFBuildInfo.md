# GFBuildInfo

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_build_info.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

运行时构建信息快照。 用统一 Resource 承载项目版本、GF 版本、构建号、提交号和运行平台信息， 便于诊断、日志、存档元数据或项目自己的版本界面复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`BUILD_ID_SETTING`](#member-gfbuildinfo-constants-build_id_setting) | `const BUILD_ID_SETTING: String = "gf/build/id"` |
| 常量 | [`COMMIT_HASH_SETTING`](#member-gfbuildinfo-constants-commit_hash_setting) | `const COMMIT_HASH_SETTING: String = "gf/build/commit_hash"` |
| 常量 | [`BRANCH_SETTING`](#member-gfbuildinfo-constants-branch_setting) | `const BRANCH_SETTING: String = "gf/build/branch"` |
| 常量 | [`TAG_SETTING`](#member-gfbuildinfo-constants-tag_setting) | `const TAG_SETTING: String = "gf/build/tag"` |
| 常量 | [`COMMIT_COUNT_SETTING`](#member-gfbuildinfo-constants-commit_count_setting) | `const COMMIT_COUNT_SETTING: String = "gf/build/commit_count"` |
| 常量 | [`IS_DIRTY_SETTING`](#member-gfbuildinfo-constants-is_dirty_setting) | `const IS_DIRTY_SETTING: String = "gf/build/is_dirty"` |
| 常量 | [`TIME_UTC_SETTING`](#member-gfbuildinfo-constants-time_utc_setting) | `const TIME_UTC_SETTING: String = "gf/build/time_utc"` |
| 常量 | [`METADATA_SETTING`](#member-gfbuildinfo-constants-metadata_setting) | `const METADATA_SETTING: String = "gf/build/metadata"` |
| 常量 | [`PROJECT_NAME_SETTING`](#member-gfbuildinfo-constants-project_name_setting) | `const PROJECT_NAME_SETTING: String = "application/config/name"` |
| 常量 | [`PROJECT_VERSION_SETTING`](#member-gfbuildinfo-constants-project_version_setting) | `const PROJECT_VERSION_SETTING: String = "application/config/version"` |
| 属性 | [`project_name`](#member-gfbuildinfo-properties-project_name) | `var project_name: String = ""` |
| 属性 | [`project_version`](#member-gfbuildinfo-properties-project_version) | `var project_version: String = ""` |
| 属性 | [`framework_version`](#member-gfbuildinfo-properties-framework_version) | `var framework_version: String = ""` |
| 属性 | [`build_id`](#member-gfbuildinfo-properties-build_id) | `var build_id: String = ""` |
| 属性 | [`commit_hash`](#member-gfbuildinfo-properties-commit_hash) | `var commit_hash: String = ""` |
| 属性 | [`branch`](#member-gfbuildinfo-properties-branch) | `var branch: String = ""` |
| 属性 | [`tag`](#member-gfbuildinfo-properties-tag) | `var tag: String = ""` |
| 属性 | [`commit_count`](#member-gfbuildinfo-properties-commit_count) | `var commit_count: int = 0` |
| 属性 | [`is_dirty`](#member-gfbuildinfo-properties-is_dirty) | `var is_dirty: bool = false` |
| 属性 | [`build_time_utc`](#member-gfbuildinfo-properties-build_time_utc) | `var build_time_utc: String = ""` |
| 属性 | [`engine_version`](#member-gfbuildinfo-properties-engine_version) | `var engine_version: String = ""` |
| 属性 | [`platform_name`](#member-gfbuildinfo-properties-platform_name) | `var platform_name: String = ""` |
| 属性 | [`is_debug_build`](#member-gfbuildinfo-properties-is_debug_build) | `var is_debug_build: bool = false` |
| 属性 | [`metadata`](#member-gfbuildinfo-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfbuildinfo-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfbuildinfo-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`collect`](#member-gfbuildinfo-methods-collect) | `static func collect() -> GFBuildInfo:` |
| 方法 | [`from_dict`](#member-gfbuildinfo-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFBuildInfo:` |
| 方法 | [`write_metadata_to_project_settings`](#member-gfbuildinfo-methods-write_metadata_to_project_settings) | `static func write_metadata_to_project_settings( build_data: Dictionary = {}, extra_metadata: Dictionary = {}, save_settings: bool = false ) -> Dictionary:` |
| 方法 | [`duplicate_info`](#member-gfbuildinfo-methods-duplicate_info) | `func duplicate_info() -> GFBuildInfo:` |

## 常量

<a id="member-gfbuildinfo-constants-build_id_setting"></a>

### `BUILD_ID_SETTING`

- API：`public`

```gdscript
const BUILD_ID_SETTING: String = "gf/build/id"
```

构建标识 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-commit_hash_setting"></a>

### `COMMIT_HASH_SETTING`

- API：`public`

```gdscript
const COMMIT_HASH_SETTING: String = "gf/build/commit_hash"
```

提交哈希 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-branch_setting"></a>

### `BRANCH_SETTING`

- API：`public`

```gdscript
const BRANCH_SETTING: String = "gf/build/branch"
```

分支名 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-tag_setting"></a>

### `TAG_SETTING`

- API：`public`

```gdscript
const TAG_SETTING: String = "gf/build/tag"
```

标签名 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-commit_count_setting"></a>

### `COMMIT_COUNT_SETTING`

- API：`public`

```gdscript
const COMMIT_COUNT_SETTING: String = "gf/build/commit_count"
```

提交数量 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-is_dirty_setting"></a>

### `IS_DIRTY_SETTING`

- API：`public`

```gdscript
const IS_DIRTY_SETTING: String = "gf/build/is_dirty"
```

工作区 dirty 状态 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-time_utc_setting"></a>

### `TIME_UTC_SETTING`

- API：`public`

```gdscript
const TIME_UTC_SETTING: String = "gf/build/time_utc"
```

构建 UTC 时间 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-metadata_setting"></a>

### `METADATA_SETTING`

- API：`public`

```gdscript
const METADATA_SETTING: String = "gf/build/metadata"
```

项目自定义构建元数据 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-project_name_setting"></a>

### `PROJECT_NAME_SETTING`

- API：`public`

```gdscript
const PROJECT_NAME_SETTING: String = "application/config/name"
```

项目名称 ProjectSettings 键。

<a id="member-gfbuildinfo-constants-project_version_setting"></a>

### `PROJECT_VERSION_SETTING`

- API：`public`

```gdscript
const PROJECT_VERSION_SETTING: String = "application/config/version"
```

项目版本 ProjectSettings 键。

## 属性

<a id="member-gfbuildinfo-properties-project_name"></a>

### `project_name`

- API：`public`

```gdscript
var project_name: String = ""
```

项目名称。

<a id="member-gfbuildinfo-properties-project_version"></a>

### `project_version`

- API：`public`

```gdscript
var project_version: String = ""
```

项目版本。

<a id="member-gfbuildinfo-properties-framework_version"></a>

### `framework_version`

- API：`public`

```gdscript
var framework_version: String = ""
```

GF Framework 版本。

<a id="member-gfbuildinfo-properties-build_id"></a>

### `build_id`

- API：`public`

```gdscript
var build_id: String = ""
```

构建流水线或发行流程写入的构建标识。

<a id="member-gfbuildinfo-properties-commit_hash"></a>

### `commit_hash`

- API：`public`

```gdscript
var commit_hash: String = ""
```

构建对应的提交哈希。

<a id="member-gfbuildinfo-properties-branch"></a>

### `branch`

- API：`public`

```gdscript
var branch: String = ""
```

构建对应的分支名。

<a id="member-gfbuildinfo-properties-tag"></a>

### `tag`

- API：`public`

```gdscript
var tag: String = ""
```

构建对应的标签名。

<a id="member-gfbuildinfo-properties-commit_count"></a>

### `commit_count`

- API：`public`

```gdscript
var commit_count: int = 0
```

构建对应的提交数量或流水线序号。

<a id="member-gfbuildinfo-properties-is_dirty"></a>

### `is_dirty`

- API：`public`

```gdscript
var is_dirty: bool = false
```

构建来源工作区是否存在未提交改动。

<a id="member-gfbuildinfo-properties-build_time_utc"></a>

### `build_time_utc`

- API：`public`

```gdscript
var build_time_utc: String = ""
```

构建时间，建议使用 UTC ISO 文本。

<a id="member-gfbuildinfo-properties-engine_version"></a>

### `engine_version`

- API：`public`

```gdscript
var engine_version: String = ""
```

当前运行的 Godot 引擎版本文本。

<a id="member-gfbuildinfo-properties-platform_name"></a>

### `platform_name`

- API：`public`

```gdscript
var platform_name: String = ""
```

当前运行平台名称。

<a id="member-gfbuildinfo-properties-is_debug_build"></a>

### `is_debug_build`

- API：`public`

```gdscript
var is_debug_build: bool = false
```

当前运行扩展是否为 debug build。

<a id="member-gfbuildinfo-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义构建元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目自定义构建元数据。

## 方法

<a id="member-gfbuildinfo-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：构建信息字典。

结构：

- `return`: Dictionary，包含 project_name、project_version、framework_version、build_id、commit_hash、branch、tag、commit_count、is_dirty、build_time_utc、engine_version、platform_name、is_debug_build 和 metadata 字段。

<a id="member-gfbuildinfo-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 构建信息字典。 |

结构：

- `data`: Dictionary，可包含 project_name、project_version、framework_version、build_id、commit_hash、branch、tag、commit_count、is_dirty、build_time_utc、engine_version、platform_name、is_debug_build 和 metadata 字段。

<a id="member-gfbuildinfo-methods-collect"></a>

### `collect`

- API：`public`

```gdscript
static func collect() -> GFBuildInfo:
```

创建当前运行环境的构建信息。

返回：构建信息快照。

<a id="member-gfbuildinfo-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFBuildInfo:
```

从 Dictionary 创建构建信息。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 构建信息字典。 |

返回：新构建信息。

结构：

- `data`: Dictionary，可包含 GFBuildInfo.to_dict() 输出的字段。

<a id="member-gfbuildinfo-methods-write_metadata_to_project_settings"></a>

### `write_metadata_to_project_settings`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func write_metadata_to_project_settings( build_data: Dictionary = {}, extra_metadata: Dictionary = {}, save_settings: bool = false ) -> Dictionary:
```

把外部构建流水线提供的构建元数据写入 ProjectSettings，供 collect() 在运行时读取。

参数：

| 名称 | 说明 |
|---|---|
| `build_data` | 构建流水线提供的构建元数据。 |
| `extra_metadata` | 项目自定义构建元数据。 |
| `save_settings` | 是否立即保存 ProjectSettings。 |

返回：实际写入的构建元数据。

结构：

- `build_data`: Dictionary，可包含 build_id、commit_hash、branch、tag、commit_count、is_dirty、build_time_utc 和 metadata 字段。
- `extra_metadata`: Dictionary，保存项目自定义构建元数据。
- `return`: Dictionary，包含已写入的构建元数据。

<a id="member-gfbuildinfo-methods-duplicate_info"></a>

### `duplicate_info`

- API：`public`

```gdscript
func duplicate_info() -> GFBuildInfo:
```

复制构建信息。

返回：深拷贝后的构建信息。
