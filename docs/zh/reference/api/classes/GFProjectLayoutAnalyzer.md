# GFProjectLayoutAnalyzer

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/gf_project_layout_analyzer.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

只读的项目结构分析器。 捕获项目目录库存，并按可选 profile 分析目录分区、Feature 模块契约、命名、生成物边界和大桶目录增长。 所有公开操作都只读取项目；该类型不会创建、移动、删除或改写任何项目文件。 未知选项、字段、错误类型和非规范相对路径都会失败关闭；扫描预算在流式枚举期间全局生效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH`](#member-gfprojectlayoutanalyzer-constants-example_feature_cohesive_profile_path) | `const EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"` |
| 方法 | [`analyze`](#member-gfprojectlayoutanalyzer-methods-analyze) | `func analyze(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`analyze_example_profile`](#member-gfprojectlayoutanalyzer-methods-analyze_example_profile) | `func analyze_example_profile(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`analyze_profile_path`](#member-gfprojectlayoutanalyzer-methods-analyze_profile_path) | `func analyze_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`analyze_profile`](#member-gfprojectlayoutanalyzer-methods-analyze_profile) | `func analyze_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`analyze_snapshot`](#member-gfprojectlayoutanalyzer-methods-analyze_snapshot) | `func analyze_snapshot(snapshot: Dictionary) -> Dictionary:` |
| 方法 | [`analyze_profile_snapshot`](#member-gfprojectlayoutanalyzer-methods-analyze_profile_snapshot) | `func analyze_profile_snapshot( profile: Dictionary, snapshot: Dictionary ) -> Dictionary:` |
| 方法 | [`explain_finding`](#member-gfprojectlayoutanalyzer-methods-explain_finding) | `func explain_finding(analysis: Dictionary, finding_id: String) -> Dictionary:` |
| 方法 | [`analyze_change_impact`](#member-gfprojectlayoutanalyzer-methods-analyze_change_impact) | `func analyze_change_impact(analysis: Dictionary, change: Dictionary) -> Dictionary:` |

## 常量

<a id="member-gfprojectlayoutanalyzer-constants-example_feature_cohesive_profile_path"></a>

### `EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
```

Feature 内聚式示例 profile 路径。

## 方法

<a id="member-gfprojectlayoutanalyzer-methods-analyze"></a>

### `analyze`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze(options: Dictionary = {}) -> Dictionary:
```

不加载 profile，只捕获并归一化当前项目结构。 该入口适合第一次使用 Project Layout 的项目：它只建立观察图，不假定任何推荐目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 分析选项。 |

返回：只读分析报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；graph 精确包含 schema_version、kind、complete、capture_status、scope、dependency_coverage、nodes、edges 和 evidence；effects 精确包含 writes_project=false。

<a id="member-gfprojectlayoutanalyzer-methods-analyze_example_profile"></a>

### `analyze_example_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_example_profile(options: Dictionary = {}) -> Dictionary:
```

按 Feature 内聚式示例 profile 分析项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项。 |

返回：校验报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；capabilities 在编译前或 contract/registry 失败时为 {}，否则精确包含 executor_id、operation、rule_kinds、rule_fields 和 zone_fields；effects 精确包含 writes_project=false。

<a id="member-gfprojectlayoutanalyzer-methods-analyze_profile_path"></a>

### `analyze_profile_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

从项目结构 profile 文件分析项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | JSON profile 路径。 |
| `options` | 校验选项。 |

返回：校验报告。

结构：

- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；capabilities 在编译前或 contract/registry 失败时为 {}，否则精确包含 executor_id、operation、rule_kinds、rule_fields 和 zone_fields；effects 精确包含 writes_project=false。

<a id="member-gfprojectlayoutanalyzer-methods-analyze_profile"></a>

### `analyze_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
```

按已解析的项目结构 profile 分析项目结构。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 项目结构 profile 字典。 |
| `options` | 校验选项。 |

返回：校验报告。

结构：

- `profile`: Dictionary，包含 schema_version、id、zones 和 rules。
- `options`: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；capabilities 在编译前或 contract/registry 失败时为 {}，否则精确包含 executor_id、operation、rule_kinds、rule_fields 和 zone_fields；effects 精确包含 writes_project=false。

<a id="member-gfprojectlayoutanalyzer-methods-analyze_snapshot"></a>

### `analyze_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_snapshot(snapshot: Dictionary) -> Dictionary:
```

分析已经冻结的 data-only 项目库存，不再访问文件系统。 Editor Dock 用主线程分批捕获 snapshot，再把该值交给后台 worker。snapshot 必须包含 schema_version、kind、root_path、scope、complete、capture_status、files 和 directories。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | data-only 项目库存。 |

返回：observation-only 只读分析报告。

结构：

- `snapshot`: Dictionary，字段闭集为 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和可选 issues；root_path 必须是规范 res:// 根或子根，scope 精确包含 kind、root_path、include_hidden、excluded_prefixes 与三项捕获预算，files/directories 必须形成完整父目录闭包。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutanalyzer-methods-analyze_profile_snapshot"></a>

### `analyze_profile_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_profile_snapshot( profile: Dictionary, snapshot: Dictionary ) -> Dictionary:
```

按 profile 分析已经冻结的 data-only 项目库存，不再扫描项目目录。 该便捷入口会只读加载 canonical contract、编译 profile，并在传入的冻结库存上完成分析。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 已解析的严格 profile。 |
| `snapshot` | data-only 项目库存。 |

返回：带 policy findings 的只读分析报告。

结构：

- `profile`: Dictionary，包含 schema_version、id、zones 和 rules。
- `snapshot`: Dictionary，字段闭集为 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和可选 issues；scope 必须描述 project_source 捕获范围，files/directories 必须形成完整父目录闭包。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutanalyzer-methods-explain_finding"></a>

### `explain_finding`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func explain_finding(analysis: Dictionary, finding_id: String) -> Dictionary:
```

解释分析报告中的一条 finding。

参数：

| 名称 | 说明 |
|---|---|
| `analysis` | 本类型生成的项目结构分析报告。 |
| `finding_id` | finding 的稳定 ID。 |

返回：只读解释，包含 observation、implication、next_steps、certainty 和 evidence。

结构：

- `analysis`: Dictionary，必须是本类型生成并通过闭合 analysis/graph contract 的完整 project_layout_analysis 报告，不能手工拼装字段子集。
- `return`: Dictionary，精确包含 schema_version、kind、complete、finding_id、headline、observation、implication、next_steps、certainty、evidence、issues 和 effects；effects 精确包含 writes_project=false。

<a id="member-gfprojectlayoutanalyzer-methods-analyze_change_impact"></a>

### `analyze_change_impact`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_change_impact(analysis: Dictionary, change: Dictionary) -> Dictionary:
```

在冻结分析图上模拟 move、rename 或 delete 的影响。 该方法只返回影响状态和 blocker，不执行变更。依赖覆盖不完整时必须返回 unknown， 不能把“没有观察到引用”解释成安全。

参数：

| 名称 | 说明 |
|---|---|
| `analysis` | 本类型生成的项目结构分析报告。 |
| `change` | Dictionary，包含 kind、source_path，move/rename 还需 target_path。 |

返回：只读影响报告，status 为 safe、unsafe 或 unknown。

结构：

- `analysis`: Dictionary，必须是本类型生成并通过闭合 analysis/graph contract 的完整 project_layout_analysis 报告，不能手工拼装字段子集。
- `change`: Dictionary，字段闭集为 kind、source_path 和 target_path；kind 只能是 delete、move 或 rename。
- `return`: Dictionary，精确包含 schema_version、kind、complete、status、source_analysis_digest、change、affected_node_ids、blockers、evidence_ids、issues 和 effects；effects 精确包含 writes_project=false。
