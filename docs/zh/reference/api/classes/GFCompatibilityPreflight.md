# GFCompatibilityPreflight

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/policy/gf_compatibility_preflight.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用兼容性预检报告构建器。 将版本、平台、功能、包、artifact 和外部报告合并为标准校验报告。它只做显式声明的 预检，不安装包、不下载资源、不执行代码，也不把项目发布策略写入框架。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`MATCH_ANY`](#member-gfcompatibilitypreflight-constants-match_any) | `const MATCH_ANY: StringName = &"any"` |
| 常量 | [`MATCH_ALL`](#member-gfcompatibilitypreflight-constants-match_all) | `const MATCH_ALL: StringName = &"all"` |
| 属性 | [`subject`](#member-gfcompatibilitypreflight-properties-subject) | `var subject: String = _DEFAULT_SUBJECT` |
| 属性 | [`target_id`](#member-gfcompatibilitypreflight-properties-target_id) | `var target_id: StringName = &""` |
| 属性 | [`target_version`](#member-gfcompatibilitypreflight-properties-target_version) | `var target_version: String = ""` |
| 属性 | [`profile`](#member-gfcompatibilitypreflight-properties-profile) | `var profile: GFCompatibilityProfile = null` |
| 属性 | [`checks`](#member-gfcompatibilitypreflight-properties-checks) | `var checks: Array[Dictionary] = []` |
| 属性 | [`issues`](#member-gfcompatibilitypreflight-properties-issues) | `var issues: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfcompatibilitypreflight-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfcompatibilitypreflight-methods-configure) | `func configure( p_subject: String = _DEFAULT_SUBJECT, p_profile: GFCompatibilityProfile = null, p_metadata: Dictionary = {} ) -> GFCompatibilityPreflight:` |
| 方法 | [`clear`](#member-gfcompatibilitypreflight-methods-clear) | `func clear() -> void:` |
| 方法 | [`set_profile`](#member-gfcompatibilitypreflight-methods-set_profile) | `func set_profile(p_profile: GFCompatibilityProfile) -> GFCompatibilityPreflight:` |
| 方法 | [`require_godot_version`](#member-gfcompatibilitypreflight-methods-require_godot_version) | `func require_godot_version( minimum_version: String = "", maximum_version_exclusive: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`require_framework_version`](#member-gfcompatibilitypreflight-methods-require_framework_version) | `func require_framework_version( minimum_version: String = "", maximum_version_exclusive: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`require_platforms`](#member-gfcompatibilitypreflight-methods-require_platforms) | `func require_platforms( required_platforms: PackedStringArray, mode: StringName = MATCH_ANY, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`require_features`](#member-gfcompatibilitypreflight-methods-require_features) | `func require_features( required_features: PackedStringArray, mode: StringName = MATCH_ALL, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`require_package`](#member-gfcompatibilitypreflight-methods-require_package) | `func require_package( package_id: StringName, minimum_version: String = "", maximum_version_exclusive: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`require_artifact`](#member-gfcompatibilitypreflight-methods-require_artifact) | `func require_artifact(artifact_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_check`](#member-gfcompatibilitypreflight-methods-add_check) | `func add_check(check_id: StringName, ok: bool, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`merge_report`](#member-gfcompatibilitypreflight-methods-merge_report) | `func merge_report(report: Dictionary, options: Dictionary = {}) -> GFCompatibilityPreflight:` |
| 方法 | [`get_report`](#member-gfcompatibilitypreflight-methods-get_report) | `func get_report(options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfcompatibilitypreflight-constants-match_any"></a>

### `MATCH_ANY`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const MATCH_ANY: StringName = &"any"
```

任一候选满足即可。

<a id="member-gfcompatibilitypreflight-constants-match_all"></a>

### `MATCH_ALL`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const MATCH_ALL: StringName = &"all"
```

全部候选都必须满足。

## 属性

<a id="member-gfcompatibilitypreflight-properties-subject"></a>

### `subject`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var subject: String = _DEFAULT_SUBJECT
```

报告主题。

<a id="member-gfcompatibilitypreflight-properties-target_id"></a>

### `target_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_id: StringName = &""
```

预检目标 ID。

<a id="member-gfcompatibilitypreflight-properties-target_version"></a>

### `target_version`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_version: String = ""
```

预检目标版本。

<a id="member-gfcompatibilitypreflight-properties-profile"></a>

### `profile`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var profile: GFCompatibilityProfile = null
```

当前使用的 Profile。

<a id="member-gfcompatibilitypreflight-properties-checks"></a>

### `checks`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var checks: Array[Dictionary] = []
```

预检检查记录。

结构：

- `checks`: Array[Dictionary]，每项包含 check_id、kind、ok、expected_value、actual_value 和 metadata。

<a id="member-gfcompatibilitypreflight-properties-issues"></a>

### `issues`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var issues: Array[Dictionary] = []
```

预检问题。

结构：

- `issues`: Array[Dictionary] GFValidationReportDictionary-compatible issue payloads.

<a id="member-gfcompatibilitypreflight-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined preflight metadata.

## 方法

<a id="member-gfcompatibilitypreflight-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_subject: String = _DEFAULT_SUBJECT, p_profile: GFCompatibilityProfile = null, p_metadata: Dictionary = {} ) -> GFCompatibilityPreflight:
```

配置预检构建器。

参数：

| 名称 | 说明 |
|---|---|
| `p_subject` | 报告主题。 |
| `p_profile` | 兼容性 Profile。 |
| `p_metadata` | 调用方元数据。 |

返回：当前构建器。

结构：

- `p_metadata`: Dictionary caller-defined preflight metadata.

<a id="member-gfcompatibilitypreflight-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空检查和问题。

<a id="member-gfcompatibilitypreflight-methods-set_profile"></a>

### `set_profile`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_profile(p_profile: GFCompatibilityProfile) -> GFCompatibilityPreflight:
```

设置 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `p_profile` | 兼容性 Profile。 |

返回：当前构建器。

<a id="member-gfcompatibilitypreflight-methods-require_godot_version"></a>

### `require_godot_version`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func require_godot_version( minimum_version: String = "", maximum_version_exclusive: String = "", options: Dictionary = {} ) -> Dictionary:
```

要求 Godot 版本满足范围。

参数：

| 名称 | 说明 |
|---|---|
| `minimum_version` | 最低版本；为空时不检查。 |
| `maximum_version_exclusive` | 排他最高版本；为空时不检查。 |
| `options` | 检查选项，支持 check_id、severity 和 metadata。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-require_framework_version"></a>

### `require_framework_version`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func require_framework_version( minimum_version: String = "", maximum_version_exclusive: String = "", options: Dictionary = {} ) -> Dictionary:
```

要求 GF 框架版本满足范围。

参数：

| 名称 | 说明 |
|---|---|
| `minimum_version` | 最低版本；为空时不检查。 |
| `maximum_version_exclusive` | 排他最高版本；为空时不检查。 |
| `options` | 检查选项，支持 check_id、severity 和 metadata。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-require_platforms"></a>

### `require_platforms`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func require_platforms( required_platforms: PackedStringArray, mode: StringName = MATCH_ANY, options: Dictionary = {} ) -> Dictionary:
```

要求平台能力满足候选集合。

参数：

| 名称 | 说明 |
|---|---|
| `required_platforms` | 平台标识候选。 |
| `mode` | MATCH_ANY 或 MATCH_ALL。 |
| `options` | 检查选项，支持 check_id、severity 和 metadata。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-require_features"></a>

### `require_features`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func require_features( required_features: PackedStringArray, mode: StringName = MATCH_ALL, options: Dictionary = {} ) -> Dictionary:
```

要求功能能力满足候选集合。

参数：

| 名称 | 说明 |
|---|---|
| `required_features` | 功能能力标识候选。 |
| `mode` | MATCH_ANY 或 MATCH_ALL。 |
| `options` | 检查选项，支持 check_id、severity 和 metadata。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-require_package"></a>

### `require_package`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func require_package( package_id: StringName, minimum_version: String = "", maximum_version_exclusive: String = "", options: Dictionary = {} ) -> Dictionary:
```

要求包存在并可选满足版本范围。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 包 ID。 |
| `minimum_version` | 最低版本；为空时不检查。 |
| `maximum_version_exclusive` | 排他最高版本；为空时不检查。 |
| `options` | 检查选项，支持 check_id、severity 和 metadata。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-require_artifact"></a>

### `require_artifact`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func require_artifact(artifact_id: StringName, options: Dictionary = {}) -> Dictionary:
```

要求 artifact 条目存在，并可选检查声明路径。

参数：

| 名称 | 说明 |
|---|---|
| `artifact_id` | artifact ID。 |
| `options` | 检查选项，支持 check_id、severity、metadata、require_path、expected_path、expected_kind、require_file_exists、expected_sha256 和 expected_size_bytes。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata; require_path checks that the profile entry has a non-empty path, expected_path checks exact declared path when provided, require_file_exists checks the declared file without downloading or installing anything.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-add_check"></a>

### `add_check`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_check(check_id: StringName, ok: bool, options: Dictionary = {}) -> Dictionary:
```

添加自定义检查结果。

参数：

| 名称 | 说明 |
|---|---|
| `check_id` | 检查 ID。 |
| `ok` | 检查是否通过。 |
| `options` | 检查选项，支持 kind、expected_value、actual_value、issue_kind、message、severity 和 metadata。 |

返回：检查记录副本。

结构：

- `options`: Dictionary check metadata.
- `return`: Dictionary check record.

<a id="member-gfcompatibilitypreflight-methods-merge_report"></a>

### `merge_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func merge_report(report: Dictionary, options: Dictionary = {}) -> GFCompatibilityPreflight:
```

合并另一份校验报告的问题。

参数：

| 名称 | 说明 |
|---|---|
| `report` | GFValidationReportDictionary 兼容报告。 |
| `options` | 合并选项，支持 component、phase 和 issue_kind。 |

返回：当前构建器。

结构：

- `report`: Dictionary report payload.
- `options`: Dictionary merge metadata.

<a id="member-gfcompatibilitypreflight-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report(options: Dictionary = {}) -> Dictionary:
```

获取预检报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 报告选项，支持 subject、fallback_action、no_action 和 warnings_as_errors。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary report finalization options.
- `return`: Dictionary with ok, healthy, profile, checks, issues, summary, and next_action.
