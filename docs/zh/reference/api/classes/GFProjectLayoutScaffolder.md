# GFProjectLayoutScaffolder

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/gf_project_layout_scaffolder.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`8.0.0`

Profile 驱动的项目目录脚手架工具。 按项目结构 profile 创建必需目录和可选 Feature 模块目录，并返回可审查报告。 该工具只实现目录创建机制，不要求所有项目采用同一业务结构，也不把参考项目约定 写入 GF 运行时包。 所有选项和 profile 字段都会在写入前严格校验，dry-run 与 apply 共用目录可创建性预检。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_FEATURE_COHESIVE_PROFILE_PATH`](#member-gfprojectlayoutscaffolder-constants-default_feature_cohesive_profile_path) | `const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"` |
| 方法 | [`scaffold_default_profile`](#member-gfprojectlayoutscaffolder-methods-scaffold_default_profile) | `func scaffold_default_profile(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`scaffold_profile_path`](#member-gfprojectlayoutscaffolder-methods-scaffold_profile_path) | `func scaffold_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`scaffold_profile`](#member-gfprojectlayoutscaffolder-methods-scaffold_profile) | `func scaffold_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_feature_module_paths`](#member-gfprojectlayoutscaffolder-methods-make_feature_module_paths) | `func make_feature_module_paths(profile: Dictionary, feature_id: String, options: Dictionary = {}) -> PackedStringArray:` |

## 常量

<a id="member-gfprojectlayoutscaffolder-constants-default_feature_cohesive_profile_path"></a>

### `DEFAULT_FEATURE_COHESIVE_PROFILE_PATH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
```

内置 Feature 内聚式项目结构 profile 路径。

## 方法

<a id="member-gfprojectlayoutscaffolder-methods-scaffold_default_profile"></a>

### `scaffold_default_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func scaffold_default_profile(options: Dictionary = {}) -> Dictionary:
```

按内置 Feature 内聚式模板创建目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 脚手架选项。 |

返回：脚手架报告。

结构：

- `options`: Dictionary，可包含 root_path、feature_ids、dry_run、include_optional_zones、include_optional_feature_subdirs 和 allow_absolute_root。
- `return`: Dictionary，包含 success、profile_id、root_path、dry_run、planned_paths、created_paths、existing_paths、rolled_back_paths、rollback_failed_paths、operations、issues、error_count 和 warning_count。

<a id="member-gfprojectlayoutscaffolder-methods-scaffold_profile_path"></a>

### `scaffold_profile_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func scaffold_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

从项目结构 profile 文件创建目录。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | JSON profile 路径。 |
| `options` | 脚手架选项。 |

返回：脚手架报告。

结构：

- `options`: Dictionary，可包含 root_path、feature_ids、dry_run、include_optional_zones、include_optional_feature_subdirs 和 allow_absolute_root。
- `return`: Dictionary，包含 success、profile_id、root_path、dry_run、planned_paths、created_paths、existing_paths、rolled_back_paths、rollback_failed_paths、operations、issues、error_count 和 warning_count。

<a id="member-gfprojectlayoutscaffolder-methods-scaffold_profile"></a>

### `scaffold_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func scaffold_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
```

按已解析的项目结构 profile 创建目录。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `options` | 脚手架选项。 |

返回：脚手架报告。

结构：

- `profile`: Dictionary，包含 schema_version、id、zones 和 rules。
- `options`: Dictionary，可包含 root_path、feature_ids、dry_run、include_optional_zones、include_optional_feature_subdirs 和 allow_absolute_root。
- `return`: Dictionary，包含 success、profile_id、root_path、dry_run、planned_paths、created_paths、existing_paths、rolled_back_paths、rollback_failed_paths、operations、issues、error_count 和 warning_count。

<a id="member-gfprojectlayoutscaffolder-methods-make_feature_module_paths"></a>

### `make_feature_module_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_feature_module_paths(profile: Dictionary, feature_id: String, options: Dictionary = {}) -> PackedStringArray:
```

根据 Feature 模块契约计算某个 Feature 应创建的相对目录。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `feature_id` | Feature 模块 ID。 |
| `options` | 计算选项。 |

返回：相对目录列表，例如 features/inventory/scripts。

结构：

- `profile`: Dictionary，包含 feature_module_contract 规则。
- `options`: Dictionary，可包含 include_optional_feature_subdirs。
