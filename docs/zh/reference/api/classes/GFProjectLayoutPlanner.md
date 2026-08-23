# GFProjectLayoutPlanner

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/gf_project_layout_planner.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

基于项目结构分析快照生成只读改进计划。 Planner 的规划核心只消费已经编译的 profile 与完整冻结分析图，不访问当前文件系统， 也不创建、移动、删除或改写项目内容。它输出可审查的相对路径步骤，并用 blocker 显式报告冻结图中已观察到的文件阻塞。 Feature 内聚式 profile 只是显式示例，不是所有项目都必须采用的默认目录规范。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH`](#member-gfprojectlayoutplanner-constants-example_feature_cohesive_profile_path) | `const EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"` |
| 方法 | [`plan_example_profile`](#member-gfprojectlayoutplanner-methods-plan_example_profile) | `func plan_example_profile(source_analysis: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`plan_profile_path`](#member-gfprojectlayoutplanner-methods-plan_profile_path) | `func plan_profile_path( profile_path: String, source_analysis: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`plan_profile`](#member-gfprojectlayoutplanner-methods-plan_profile) | `func plan_profile( profile: Dictionary, source_analysis: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_feature_module_paths`](#member-gfprojectlayoutplanner-methods-make_feature_module_paths) | `func make_feature_module_paths( profile: Dictionary, feature_id: String, options: Dictionary = {} ) -> PackedStringArray:` |

## 常量

<a id="member-gfprojectlayoutplanner-constants-example_feature_cohesive_profile_path"></a>

### `EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
```

Feature 内聚式项目结构示例 profile 路径。

## 方法

<a id="member-gfprojectlayoutplanner-methods-plan_example_profile"></a>

### `plan_example_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func plan_example_profile(source_analysis: Dictionary, options: Dictionary = {}) -> Dictionary:
```

按 Feature 内聚式示例 profile 生成只读改进计划。

参数：

| 名称 | 说明 |
|---|---|
| `source_analysis` | GFProjectLayoutAnalyzer 返回的完整只读分析快照。 |
| `options` | 规划选项。 |

返回：闭合的只读计划。

结构：

- `source_analysis`: Dictionary，必须是 GFProjectLayoutAnalyzer 生成并通过闭合 analysis/graph contract 的完整报告，不能手工拼装字段子集。
- `options`: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
- `return`: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues；capabilities 精确包含 writes_project、planning_scope、supported_rule_kinds 和 ignored_rule_kinds；每个 step 精确包含 step_id、kind、relative_path、requires、evidence_ids、preconditions 和 risk。

<a id="member-gfprojectlayoutplanner-methods-plan_profile_path"></a>

### `plan_profile_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func plan_profile_path( profile_path: String, source_analysis: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

从项目结构 profile 文件生成只读改进计划。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | JSON profile 路径。 |
| `source_analysis` | GFProjectLayoutAnalyzer 返回的完整只读分析快照。 |
| `options` | 规划选项。 |

返回：闭合的只读计划。

结构：

- `source_analysis`: Dictionary，必须是 GFProjectLayoutAnalyzer 生成并通过闭合 analysis/graph contract 的完整报告，不能手工拼装字段子集。
- `options`: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
- `return`: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues；capabilities 精确包含 writes_project、planning_scope、supported_rule_kinds 和 ignored_rule_kinds；每个 step 精确包含 step_id、kind、relative_path、requires、evidence_ids、preconditions 和 risk。

<a id="member-gfprojectlayoutplanner-methods-plan_profile"></a>

### `plan_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func plan_profile( profile: Dictionary, source_analysis: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

按已解析的项目结构 profile 生成只读改进计划。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `source_analysis` | GFProjectLayoutAnalyzer 返回的完整只读分析快照。 |
| `options` | 规划选项。 |

返回：闭合的只读计划。

结构：

- `profile`: Dictionary，包含 schema_version、id、zones 和 rules。
- `source_analysis`: Dictionary，必须是 GFProjectLayoutAnalyzer 生成并通过闭合 analysis/graph contract 的完整报告，不能手工拼装字段子集。
- `options`: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
- `return`: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues；capabilities 精确包含 writes_project、planning_scope、supported_rule_kinds 和 ignored_rule_kinds；每个 step 精确包含 step_id、kind、relative_path、requires、evidence_ids、preconditions 和 risk。

<a id="member-gfprojectlayoutplanner-methods-make_feature_module_paths"></a>

### `make_feature_module_paths`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func make_feature_module_paths( profile: Dictionary, feature_id: String, options: Dictionary = {} ) -> PackedStringArray:
```

根据 Feature 模块契约计算某个 Feature 的相对目录并集。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `feature_id` | Feature 模块 ID。 |
| `options` | 计算选项。 |

返回：去重后的相对目录列表，例如 features/inventory/scripts。

结构：

- `profile`: Dictionary，包含一条或多条 feature_module_contract 规则。
- `options`: Dictionary，可包含 include_optional_feature_subdirs。
