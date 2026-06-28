# GFCompatibilityProfile

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/policy/gf_compatibility_profile.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`7.0.0`

通用兼容性与能力 Profile。 用纯数据描述当前运行环境、目标构建、包集合、平台和功能能力。它只承载 预检所需的声明式信息，不执行安装、下载、动态代码启用或项目业务策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`profile_id`](#member-gfcompatibilityprofile-properties-profile_id) | `var profile_id: StringName = &""` |
| 属性 | [`godot_version`](#member-gfcompatibilityprofile-properties-godot_version) | `var godot_version: String = ""` |
| 属性 | [`framework_version`](#member-gfcompatibilityprofile-properties-framework_version) | `var framework_version: String = ""` |
| 属性 | [`platforms`](#member-gfcompatibilityprofile-properties-platforms) | `var platforms: PackedStringArray = PackedStringArray()` |
| 属性 | [`features`](#member-gfcompatibilityprofile-properties-features) | `var features: PackedStringArray = PackedStringArray()` |
| 属性 | [`packages`](#member-gfcompatibilityprofile-properties-packages) | `var packages: Array[Dictionary] = []` |
| 属性 | [`artifacts`](#member-gfcompatibilityprofile-properties-artifacts) | `var artifacts: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfcompatibilityprofile-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfcompatibilityprofile-methods-configure) | `func configure( p_profile_id: StringName, p_godot_version: String = "", p_framework_version: String = "", p_platforms: PackedStringArray = PackedStringArray(), p_features: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {} ) -> GFCompatibilityProfile:` |
| 方法 | [`clear`](#member-gfcompatibilityprofile-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_platform`](#member-gfcompatibilityprofile-methods-add_platform) | `func add_platform(platform_id: String) -> bool:` |
| 方法 | [`has_platform`](#member-gfcompatibilityprofile-methods-has_platform) | `func has_platform(platform_id: String) -> bool:` |
| 方法 | [`add_feature`](#member-gfcompatibilityprofile-methods-add_feature) | `func add_feature(feature_id: StringName) -> bool:` |
| 方法 | [`has_feature`](#member-gfcompatibilityprofile-methods-has_feature) | `func has_feature(feature_id: StringName) -> bool:` |
| 方法 | [`add_package`](#member-gfcompatibilityprofile-methods-add_package) | `func add_package(package_id: StringName, version: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_package`](#member-gfcompatibilityprofile-methods-get_package) | `func get_package(package_id: StringName) -> Dictionary:` |
| 方法 | [`has_package`](#member-gfcompatibilityprofile-methods-has_package) | `func has_package(package_id: StringName) -> bool:` |
| 方法 | [`add_artifact`](#member-gfcompatibilityprofile-methods-add_artifact) | `func add_artifact(artifact_id: StringName, path: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_artifact`](#member-gfcompatibilityprofile-methods-get_artifact) | `func get_artifact(artifact_id: StringName) -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfcompatibilityprofile-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfcompatibilityprofile-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_profile`](#member-gfcompatibilityprofile-methods-duplicate_profile) | `func duplicate_profile() -> GFCompatibilityProfile:` |
| 方法 | [`from_current_environment`](#member-gfcompatibilityprofile-methods-from_current_environment) | `static func from_current_environment(options: Dictionary = {}) -> GFCompatibilityProfile:` |
| 方法 | [`from_dict`](#member-gfcompatibilityprofile-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFCompatibilityProfile:` |

## 属性

<a id="member-gfcompatibilityprofile-properties-profile_id"></a>

### `profile_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var profile_id: StringName = &""
```

Profile 稳定标识。

<a id="member-gfcompatibilityprofile-properties-godot_version"></a>

### `godot_version`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var godot_version: String = ""
```

Godot 版本字符串。

<a id="member-gfcompatibilityprofile-properties-framework_version"></a>

### `framework_version`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var framework_version: String = ""
```

GF 框架版本字符串。

<a id="member-gfcompatibilityprofile-properties-platforms"></a>

### `platforms`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var platforms: PackedStringArray = PackedStringArray()
```

当前或目标平台标识列表。

<a id="member-gfcompatibilityprofile-properties-features"></a>

### `features`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var features: PackedStringArray = PackedStringArray()
```

当前或目标功能能力标识列表。

<a id="member-gfcompatibilityprofile-properties-packages"></a>

### `packages`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var packages: Array[Dictionary] = []
```

已知包条目列表。

结构：

- `packages`: Array[Dictionary]，每项至少包含 id 或 package_id，可选 version、kind 和 metadata。

<a id="member-gfcompatibilityprofile-properties-artifacts"></a>

### `artifacts`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var artifacts: Array[Dictionary] = []
```

已知 artifact 条目列表。

结构：

- `artifacts`: Array[Dictionary]，每项至少包含 id 或 artifact_id，可选 path、sha256、size_bytes、kind 和 metadata。

<a id="member-gfcompatibilityprofile-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined profile metadata.

## 方法

<a id="member-gfcompatibilityprofile-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_profile_id: StringName, p_godot_version: String = "", p_framework_version: String = "", p_platforms: PackedStringArray = PackedStringArray(), p_features: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {} ) -> GFCompatibilityProfile:
```

配置 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `p_profile_id` | Profile 稳定标识。 |
| `p_godot_version` | Godot 版本字符串。 |
| `p_framework_version` | GF 框架版本字符串。 |
| `p_platforms` | 平台标识列表。 |
| `p_features` | 功能能力标识列表。 |
| `p_metadata` | 调用方元数据。 |

返回：当前 Profile。

结构：

- `p_metadata`: Dictionary caller-defined profile metadata.

<a id="member-gfcompatibilityprofile-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空 Profile。

<a id="member-gfcompatibilityprofile-methods-add_platform"></a>

### `add_platform`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_platform(platform_id: String) -> bool:
```

添加平台标识。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |

返回：成功添加或已存在时返回 true。

<a id="member-gfcompatibilityprofile-methods-has_platform"></a>

### `has_platform`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_platform(platform_id: String) -> bool:
```

检查平台是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `platform_id` | 平台标识。 |

返回：存在返回 true。

<a id="member-gfcompatibilityprofile-methods-add_feature"></a>

### `add_feature`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_feature(feature_id: StringName) -> bool:
```

添加功能能力标识。

参数：

| 名称 | 说明 |
|---|---|
| `feature_id` | 功能能力标识。 |

返回：成功添加或已存在时返回 true。

<a id="member-gfcompatibilityprofile-methods-has_feature"></a>

### `has_feature`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_feature(feature_id: StringName) -> bool:
```

检查功能能力是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `feature_id` | 功能能力标识。 |

返回：存在返回 true。

<a id="member-gfcompatibilityprofile-methods-add_package"></a>

### `add_package`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_package(package_id: StringName, version: String = "", options: Dictionary = {}) -> Dictionary:
```

添加包条目。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 包 ID。 |
| `version` | 包版本。 |
| `options` | 附加字段，支持 kind 和 metadata，也允许调用方自定义字段。 |

返回：添加后的包条目副本。

结构：

- `options`: Dictionary package entry fields.
- `return`: Dictionary package entry.

<a id="member-gfcompatibilityprofile-methods-get_package"></a>

### `get_package`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_package(package_id: StringName) -> Dictionary:
```

获取包条目。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 包 ID。 |

返回：包条目副本；不存在时为空字典。

结构：

- `return`: Dictionary package entry.

<a id="member-gfcompatibilityprofile-methods-has_package"></a>

### `has_package`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_package(package_id: StringName) -> bool:
```

检查包是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 包 ID。 |

返回：存在返回 true。

<a id="member-gfcompatibilityprofile-methods-add_artifact"></a>

### `add_artifact`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_artifact(artifact_id: StringName, path: String = "", options: Dictionary = {}) -> Dictionary:
```

添加 artifact 条目。

参数：

| 名称 | 说明 |
|---|---|
| `artifact_id` | artifact ID。 |
| `path` | artifact 路径。 |
| `options` | 附加字段，支持 kind、sha256、size_bytes 和 metadata，也允许调用方自定义字段。 |

返回：添加后的 artifact 条目副本。

结构：

- `options`: Dictionary artifact entry fields.
- `return`: Dictionary artifact entry.

<a id="member-gfcompatibilityprofile-methods-get_artifact"></a>

### `get_artifact`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_artifact(artifact_id: StringName) -> Dictionary:
```

获取 artifact 条目。

参数：

| 名称 | 说明 |
|---|---|
| `artifact_id` | artifact ID。 |

返回：artifact 条目副本；不存在时为空字典。

结构：

- `return`: Dictionary artifact entry.

<a id="member-gfcompatibilityprofile-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：Profile 字典。

结构：

- `return`: Dictionary with profile_id, godot_version, framework_version, platforms, features, packages, artifacts, and metadata.

<a id="member-gfcompatibilityprofile-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用 Profile 字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Profile 字典。 |

结构：

- `data`: Dictionary with profile_id, godot_version, framework_version, platforms, features, packages, artifacts, and metadata.

<a id="member-gfcompatibilityprofile-methods-duplicate_profile"></a>

### `duplicate_profile`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func duplicate_profile() -> GFCompatibilityProfile:
```

创建 Profile 深拷贝。

返回：新 Profile。

<a id="member-gfcompatibilityprofile-methods-from_current_environment"></a>

### `from_current_environment`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_current_environment(options: Dictionary = {}) -> GFCompatibilityProfile:
```

创建当前运行环境 Profile。 features、framework_version、packages 和 artifacts 由调用方显式传入；GF 不猜测项目能力或包闭包。

参数：

| 名称 | 说明 |
|---|---|
| `options` | Profile 选项。 |

返回：新 Profile。

结构：

- `options`: Dictionary，可包含 profile_id、framework_version、platforms、features、packages、artifacts 和 metadata。

<a id="member-gfcompatibilityprofile-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFCompatibilityProfile:
```

从字典创建 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Profile 字典。 |

返回：新 Profile。

结构：

- `data`: Dictionary with profile_id, godot_version, framework_version, platforms, features, packages, artifacts, and metadata.
