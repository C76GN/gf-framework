# GFProjectLayoutValidator

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/gf_project_layout_validator.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`8.0.0`

Profile 驱动的项目结构校验工具。 按项目结构 profile 检查目录分区、Feature 模块契约、命名、生成物边界和大桶目录增长。 该工具只实现可选制作期校验，不把任意业务项目结构写入 GF 运行时包。 未知选项、字段、错误类型和非规范相对路径都会失败关闭；扫描预算在流式枚举期间全局生效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_FEATURE_COHESIVE_PROFILE_PATH`](#member-gfprojectlayoutvalidator-constants-default_feature_cohesive_profile_path) | `const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"` |
| 方法 | [`validate_default_profile`](#member-gfprojectlayoutvalidator-methods-validate_default_profile) | `func validate_default_profile(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_profile_path`](#member-gfprojectlayoutvalidator-methods-validate_profile_path) | `func validate_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_profile`](#member-gfprojectlayoutvalidator-methods-validate_profile) | `func validate_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfprojectlayoutvalidator-constants-default_feature_cohesive_profile_path"></a>

### `DEFAULT_FEATURE_COHESIVE_PROFILE_PATH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
```

内置 Feature 内聚式项目结构 profile 路径。

## 方法

<a id="member-gfprojectlayoutvalidator-methods-validate_default_profile"></a>

### `validate_default_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate_default_profile(options: Dictionary = {}) -> Dictionary:
```

按内置 Feature 内聚式模板校验项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项。 |

返回：校验报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth、allow_missing_root 和 allow_absolute_root。
- `return`: Dictionary，包含 success、profile_id、root_path、file_count、directory_count、issues、error_count、warning_count、info_count 和 rule_results。

<a id="member-gfprojectlayoutvalidator-methods-validate_profile_path"></a>

### `validate_profile_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

从项目结构 profile 文件校验项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | JSON profile 路径。 |
| `options` | 校验选项。 |

返回：校验报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth、allow_missing_root 和 allow_absolute_root。
- `return`: Dictionary，包含 success、profile_id、root_path、file_count、directory_count、issues、error_count、warning_count、info_count 和 rule_results。

<a id="member-gfprojectlayoutvalidator-methods-validate_profile"></a>

### `validate_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
```

按已解析的项目结构 profile 校验项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `options` | 校验选项。 |

返回：校验报告。

结构：

- `profile`: Dictionary，包含 schema_version、id、zones 和 rules。
- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth、allow_missing_root 和 allow_absolute_root。
- `return`: Dictionary，包含 success、profile_id、root_path、file_count、directory_count、issues、error_count、warning_count、info_count 和 rule_results。
