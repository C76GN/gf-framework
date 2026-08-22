## GFProjectLayoutValidator: 项目结构分析的兼容校验入口。
##
## 该类型不再维护独立扫描器或规则表；所有调用都委托给 [GFProjectLayoutAnalyzer]。
## 新代码应直接使用 Analyzer，以便同时取得解释、影响和只读规划所需的统一分析结果。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 8.0.0
## [br]
## @deprecated 11.0.0 Use GFProjectLayoutAnalyzer for new integrations.
class_name GFProjectLayoutValidator
extends RefCounted


# --- 常量 ---

## Feature 内聚式示例 profile 路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @deprecated 11.0.0 Use GFProjectLayoutAnalyzer.EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH.
const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = \
	"res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"

const _ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd"
)


# --- 公共方法 ---

## 按 Feature 内聚式示例 profile 校验项目结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @deprecated 11.0.0 Use GFProjectLayoutAnalyzer.analyze_example_profile().
## [br]
## @param options: 分析选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 必须是规范 res:// 路径。
## [br]
## @return: Analyzer 生成的只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func validate_default_profile(options: Dictionary = {}) -> Dictionary:
	var analyzer: _ANALYZER_SCRIPT = _ANALYZER_SCRIPT.new()
	return analyzer.analyze_example_profile(options)


## 从项目结构 profile 文件校验项目结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @deprecated 11.0.0 Use GFProjectLayoutAnalyzer.analyze_profile_path().
## [br]
## @param profile_path: JSON profile 路径。
## [br]
## @param options: 分析选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 必须是规范 res:// 路径。
## [br]
## @return: Analyzer 生成的只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func validate_profile_path(
	profile_path: String,
	options: Dictionary = {}
) -> Dictionary:
	var analyzer: _ANALYZER_SCRIPT = _ANALYZER_SCRIPT.new()
	return analyzer.analyze_profile_path(profile_path, options)


## 按已解析的项目结构 profile 校验项目结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @deprecated 11.0.0 Use GFProjectLayoutAnalyzer.analyze_profile().
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones 和 rules。
## [br]
## @param options: 分析选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 必须是规范 res:// 路径。
## [br]
## @return: Analyzer 生成的只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func validate_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	var analyzer: _ANALYZER_SCRIPT = _ANALYZER_SCRIPT.new()
	return analyzer.analyze_profile(profile, options)
