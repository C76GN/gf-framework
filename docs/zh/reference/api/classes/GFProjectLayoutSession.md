# GFProjectLayoutSession

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/gf_project_layout_session.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

拥有一次编译与一次冻结分析的只读 Layout 会话。 会话不执行目标项目代码；结果通过深复制导出，查询复用内部 compilation 与验证索引。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`open_profile_text`](#member-gfprojectlayoutsession-methods-open_profile_text) | `func open_profile_text(text: String, source_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`open_profile`](#member-gfprojectlayoutsession-methods-open_profile) | `func open_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`observe`](#member-gfprojectlayoutsession-methods-observe) | `func observe(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_analysis`](#member-gfprojectlayoutsession-methods-get_analysis) | `func get_analysis() -> Dictionary:` |
| 方法 | [`plan`](#member-gfprojectlayoutsession-methods-plan) | `func plan(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`explain`](#member-gfprojectlayoutsession-methods-explain) | `func explain(finding_id: String) -> Dictionary:` |
| 方法 | [`impact`](#member-gfprojectlayoutsession-methods-impact) | `func impact(change: Dictionary) -> Dictionary:` |
| 方法 | [`close`](#member-gfprojectlayoutsession-methods-close) | `func close() -> void:` |

## 方法

<a id="member-gfprojectlayoutsession-methods-open_profile_text"></a>

### `open_profile_text`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func open_profile_text(text: String, source_path: String, options: Dictionary = {}) -> Dictionary:
```

严格准入真实来源文件的原始 JSON，编译一次后捕获只读库存。 source_path 必须位于 options.source_root 中且 bytes 与 text 完全一致。 失败不捕获来源；此入口不加载场景、资源脚本或目标项目配置。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 有界严格 UTF-8 Profile JSON 原文。 |
| `source_path` | 根内真实 Profile 文件路径。 |
| `options` | 有限捕获配置。 |

返回：闭合 v2 analysis report。

结构：

- `options`: Dictionary，可包含 root_path、source_root、capture_scope、profile_source_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；profile_source_path 若给出必须等于 source_path。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutsession-methods-open_profile"></a>

### `open_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func open_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
```

编译已拥有的纯数据 Profile 并捕获一次库存；不授予任何文件来源身份。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 闭合 schema v2 Profile。 |
| `options` | 与 open_profile_text 相同的有限捕获选项。 |

返回：与 open_profile_text 相同的闭合 v2 analysis report。

结构：

- `profile`: Dictionary，必需 schema_version、id、zones、rules；可选 display_name、description、metadata、capture_scope。
- `options`: Dictionary，可包含 root_path、source_root、capture_scope、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；不允许 profile_source_path。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutsession-methods-observe"></a>

### `observe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func observe(options: Dictionary = {}) -> Dictionary:
```

无 Profile 时只观察明确捕获范围，不执行项目结构规则。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 有限来源捕获选项。 |

返回：闭合 v2 analysis report，rule_results 为空。

结构：

- `options`: Dictionary，与 open_profile 的捕获字段相同。
- `return`: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。

<a id="member-gfprojectlayoutsession-methods-get_analysis"></a>

### `get_analysis`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_analysis() -> Dictionary:
```

返回当前冻结报告的深复制；外部修改不会改变会话查询。

返回：最近报告，未打开或 close 后为空字典。

结构：

- `return`: Dictionary，空字典或 open_profile_text 的完整 report。

<a id="member-gfprojectlayoutsession-methods-plan"></a>

### `plan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func plan(options: Dictionary = {}) -> Dictionary:
```

用当前已编译策略及已验证冻结库存生成只读目录候选计划。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 有限规划选项。 |

返回：闭合 v2 plan；会话未准备好时 complete=false。

结构：

- `options`: Dictionary，可包含 feature_ids、include_optional_zones、include_optional_feature_subdirs。
- `return`: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers、issues。

<a id="member-gfprojectlayoutsession-methods-explain"></a>

### `explain`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func explain(finding_id: String) -> Dictionary:
```

从当前冻结 finding 与证据解释，不重新扫描或编译。

参数：

| 名称 | 说明 |
|---|---|
| `finding_id` | 当前报告中的 finding ID。 |

返回：闭合只读解释。

结构：

- `return`: Dictionary，精确包含 schema_version、kind、complete、finding_id、headline、observation、implication、next_steps、certainty、evidence、issues、effects。

<a id="member-gfprojectlayoutsession-methods-impact"></a>

### `impact`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func impact(change: Dictionary) -> Dictionary:
```

对显式路径变更计算冻结库存影响；不执行变更。

参数：

| 名称 | 说明 |
|---|---|
| `change` | 有限变更声明。 |

返回：闭合只读影响报告。

结构：

- `change`: Dictionary，精确包含 kind、source_path、target_path；kind 为 delete、move 或 rename。
- `return`: Dictionary，精确包含 schema_version、kind、complete、status、source_analysis_digest、change、affected_node_ids、blockers、evidence_ids、issues、effects。

<a id="member-gfprojectlayoutsession-methods-close"></a>

### `close`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func close() -> void:
```

释放本次 compilation、冻结报告与查询索引。
