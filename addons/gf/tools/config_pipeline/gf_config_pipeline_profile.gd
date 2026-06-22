## GFConfigPipelineProfile: 配置导表工具的批量构建声明。
##
## 描述一组表来源、数据库标识、输出路径和构建选项，供编辑器工具、CI 或项目脚本复用。
## 该资源属于可选 tool package，只表达制作期或 CI 期通用导表任务，不规定项目目录结构、业务字段语义或发布流程。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 5.2.0
class_name GFConfigPipelineProfile
extends Resource


# --- 导出变量 ---

## Profile 稳定标识。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var profile_id: StringName = &""

## 生成数据库资源的标识。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var database_id: StringName = &""

## 写入数据库资源的版本字符串。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var version: String = ""

## 导出目标路径。通常指向 .tres、.res 或 .json。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var output_path: String = ""

## 可选访问器脚本输出路径。为空时不生成访问器。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var access_output_path: String = ""

## 可选访问器脚本 class_name。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var access_class_name: String = "GFConfigAccess"

## 可选访问器脚本默认 provider 获取表达式。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var access_provider_accessor: String = "null"

## 单表来源列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema sources: Array[GFConfigPipelineTableSource]。
@export var sources: Array[GFConfigPipelineTableSource] = []

## 传给 GFConfigPipeline.build_database() 的构建选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema build_options: Dictionary，可包含 database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
@export var build_options: Dictionary = {}

## 传给 GFConfigPipeline.save_database() 的保存选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema save_options: Dictionary，可包含 output_format、include_schema、include_indexes、indent 和 sort_keys。
@export var save_options: Dictionary = {}

## 传给 GFConfigAccessGenerator 的访问器生成选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema access_options: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix 和 overwrite_existing。
@export var access_options: Dictionary = {}

## 附加到生成数据库资源的元数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema metadata: Dictionary，保存项目工具、编辑器或 CI 附加的构建信息。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 合成构建选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次构建的覆盖选项；build_options 子字典和直接字段都会覆盖 Profile 默认值。
## [br]
## @schema overrides: Dictionary，可包含 build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
## [br]
## @return: 传给 GFConfigPipeline.build_database() 的选项。
## [br]
## @schema return: Dictionary，包含合成后的构建选项。
func make_build_options(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = build_options.duplicate(true)
	if database_id != &"":
		result["database_id"] = database_id
	if not version.is_empty():
		result["version"] = version
	if not metadata.is_empty():
		var merged_metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata").duplicate(true)
		var _merge_profile_metadata_result: Dictionary = GFVariantData.merge_dictionary(merged_metadata, metadata)
		result["metadata"] = merged_metadata

	var _merge_build_options_result: Dictionary = GFVariantData.merge_dictionary(result, GFVariantData.get_option_dictionary(overrides, "build_options"))
	var direct_overrides: Dictionary = overrides.duplicate(true)
	var _build_options_removed: bool = direct_overrides.erase("build_options")
	var _save_options_removed: bool = direct_overrides.erase("save_options")
	var _output_path_removed: bool = direct_overrides.erase("output_path")
	var _access_options_removed: bool = direct_overrides.erase("access_options")
	var _access_output_path_removed: bool = direct_overrides.erase("access_output_path")
	var _access_class_name_removed: bool = direct_overrides.erase("access_class_name")
	var _access_provider_accessor_removed: bool = direct_overrides.erase("access_provider_accessor")
	var _merge_direct_overrides_result: Dictionary = GFVariantData.merge_dictionary(result, direct_overrides)
	return result


## 合成保存选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次导出的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 save_options。
## [br]
## @return: 传给 GFConfigPipeline.save_database() 的选项。
## [br]
## @schema return: Dictionary，包含合成后的保存选项。
func make_save_options(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = save_options.duplicate(true)
	var _merge_save_options_result: Dictionary = GFVariantData.merge_dictionary(result, GFVariantData.get_option_dictionary(overrides, "save_options"))
	return result


## 合成访问器生成选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次访问器生成的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 access_options。
## [br]
## @return: 传给 GFConfigAccessGenerator 的生成选项。
## [br]
## @schema return: Dictionary，包含合成后的访问器生成选项。
func make_access_options(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = access_options.duplicate(true)
	var _merge_access_options_result: Dictionary = GFVariantData.merge_dictionary(result, GFVariantData.get_option_dictionary(overrides, "access_options"))
	return result


## 获取本次导出的输出路径。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次导出的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 output_path。
## [br]
## @return: 覆盖后的输出路径；未覆盖时返回 output_path。
func resolve_output_path(overrides: Dictionary = {}) -> String:
	var override_path: String = GFVariantData.get_option_string(overrides, "output_path")
	if not override_path.is_empty():
		return override_path
	return output_path


## 获取本次访问器生成的输出路径。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次访问器生成的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 access_output_path。
## [br]
## @return: 覆盖后的访问器输出路径；未配置时返回空字符串。
func resolve_access_output_path(overrides: Dictionary = {}) -> String:
	var override_path: String = GFVariantData.get_option_string(overrides, "access_output_path")
	if not override_path.is_empty():
		return override_path
	return access_output_path


## 获取本次访问器生成的 class_name。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次访问器生成的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 access_class_name。
## [br]
## @return: 覆盖后的访问器 class_name。
func resolve_access_class_name(overrides: Dictionary = {}) -> String:
	var override_class_name: String = GFVariantData.get_option_string(overrides, "access_class_name")
	if not override_class_name.is_empty():
		return override_class_name
	return access_class_name if not access_class_name.is_empty() else "GFConfigAccess"


## 获取本次访问器生成的默认 provider 获取表达式。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次访问器生成的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 access_provider_accessor。
## [br]
## @return: 覆盖后的 provider 获取表达式。
func resolve_access_provider_accessor(overrides: Dictionary = {}) -> String:
	var override_accessor: String = GFVariantData.get_option_string(overrides, "access_provider_accessor")
	if not override_accessor.is_empty():
		return override_accessor
	return access_provider_accessor if not access_provider_accessor.is_empty() else "null"


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新 Profile 资源。
func duplicate_profile() -> GFConfigPipelineProfile:
	var duplicated: Variant = duplicate(true)
	if duplicated is GFConfigPipelineProfile:
		var profile: GFConfigPipelineProfile = duplicated
		return profile
	return GFConfigPipelineProfile.new()


## 导出 Profile 摘要。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: Profile 摘要字典。
## [br]
## @schema return: Dictionary，包含 profile_id、database_id、version、output_path、access_output_path、access_class_name、access_provider_accessor、source_count、sources、build_options、save_options、access_options 和 metadata。
func describe() -> Dictionary:
	return {
		"profile_id": profile_id,
		"database_id": database_id,
		"version": version,
		"output_path": output_path,
		"access_output_path": access_output_path,
		"access_class_name": access_class_name,
		"access_provider_accessor": access_provider_accessor,
		"source_count": sources.size(),
		"sources": _describe_sources(),
		"build_options": build_options.duplicate(true),
		"save_options": save_options.duplicate(true),
		"access_options": access_options.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _describe_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: GFConfigPipelineTableSource in sources:
		if source == null:
			result.append({ "valid": false })
			continue
		result.append(source.describe())
	return result
