# GFProjectLayoutValidator

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/gf_project_layout_validator.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`8.0.0`
- 弃用：`11.0.0 Use GFProjectLayoutAnalyzer for new integrations.`

项目结构分析的兼容校验入口。 该类型不再维护独立扫描器或规则表；所有调用都委托给 [GFProjectLayoutAnalyzer]。 新代码应直接使用 Analyzer，以便同时取得解释、影响和只读规划所需的统一分析结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_FEATURE_COHESIVE_PROFILE_PATH`](#member-gfprojectlayoutvalidator-constants-default_feature_cohesive_profile_path) | `const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = \ 	"res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"` |
| 方法 | [`validate_default_profile`](#member-gfprojectlayoutvalidator-methods-validate_default_profile) | `func validate_default_profile(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_profile_path`](#member-gfprojectlayoutvalidator-methods-validate_profile_path) | `func validate_profile_path( profile_path: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`validate_profile`](#member-gfprojectlayoutvalidator-methods-validate_profile) | `func validate_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfprojectlayoutvalidator-constants-default_feature_cohesive_profile_path"></a>

### `DEFAULT_FEATURE_COHESIVE_PROFILE_PATH`

- API：`public`
- 首次版本：`8.0.0`
- 弃用：`11.0.0 Use GFProjectLayoutAnalyzer.EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH.`

```gdscript
const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = \
	"res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
```

Feature 内聚式示例 profile 路径。

## 方法

<a id="member-gfprojectlayoutvalidator-methods-validate_default_profile"></a>

### `validate_default_profile`

- API：`public`
- 首次版本：`8.0.0`
- 弃用：`11.0.0 Use GFProjectLayoutAnalyzer.analyze_example_profile().`

```gdscript
func validate_default_profile(options: Dictionary = {}) -> Dictionary:
```

按 Feature 内聚式示例 profile 校验项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 分析选项。 |

返回：Analyzer 生成的只读分析报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 必须是规范 res:// 路径。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutvalidator-methods-validate_profile_path"></a>

### `validate_profile_path`

- API：`public`
- 首次版本：`8.0.0`
- 弃用：`11.0.0 Use GFProjectLayoutAnalyzer.analyze_profile_path().`

```gdscript
func validate_profile_path( profile_path: String, options: Dictionary = {} ) -> Dictionary:
```

从项目结构 profile 文件校验项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | JSON profile 路径。 |
| `options` | 分析选项。 |

返回：Analyzer 生成的只读分析报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 必须是规范 res:// 路径。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutvalidator-methods-validate_profile"></a>

### `validate_profile`

- API：`public`
- 首次版本：`8.0.0`
- 弃用：`11.0.0 Use GFProjectLayoutAnalyzer.analyze_profile().`

```gdscript
func validate_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
```

按已解析的项目结构 profile 校验项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `options` | 分析选项。 |

返回：Analyzer 生成的只读分析报告。

结构：

- `profile`: Dictionary，包含 schema_version、id、zones 和 rules。
- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 必须是规范 res:// 路径。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
