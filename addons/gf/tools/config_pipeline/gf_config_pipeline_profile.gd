@tool

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


# --- 常量 ---

## 允许从 Profile 构建选项顶层覆盖的键名清单。
## [br]
## @api private
## [br]
const _BUILD_OPTION_KEYS: PackedStringArray = [
	"database_id",
	"version",
	"metadata",
	"validate_database",
	"validate_schema",
	"parse_options",
	"rebuild_indexes",
	"max_validation_cells",
	"max_source_file_bytes",
	"max_xlsx_file_bytes",
	"work_limits",
]


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

## 导出目标 URI。导出时必须位于 res:// 或 user://，通常以 .tres、.res 或 .json 结尾。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var output_path: String = ""

## 可选访问器脚本输出 URI。非空时必须位于 res:// 或 user://；为空时不生成访问器。
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
## @schema build_options: Dictionary，可包含 database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes 和 work_limits。work_limits 是 GFConfigWorkBudget 的有限限额；Profile 不持有 work_budget，每次构建创建新会话。
@export var build_options: Dictionary = {}

## 传给 GFConfigPipeline.save_database() 的保存选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema save_options: Dictionary，可包含 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run；parent opt-in 不能越过 resource URI 根。
@export var save_options: Dictionary = {}

## 传给 GFConfigAccessGenerator 的访问器生成选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema access_options: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run；parent opt-in 不能越过 resource URI 根。
@export var access_options: Dictionary = {}

## 附加到生成数据库资源的元数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema metadata: Dictionary，保存项目工具、编辑器或 CI 附加的构建信息。
@export var metadata: Dictionary = {}

## 可选消费目标；声明后每次构建必须选中一个目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema consumer_targets: Array[GFConfigPipelineConsumerTarget]，最多64项，ID唯一；每个目标需要独立的非空输出路径。
@export var consumer_targets: Array[GFConfigPipelineConsumerTarget] = []

## 没有显式 target 选项时使用的消费目标；不自动选中第一项。
## [br]
## @api public
## [br]
## @since unreleased
@export var default_consumer_target: StringName = &""

## 可选项目所有的稳定 ID 登记簿 JSON URI；空值时不启用登记。
## [br]
## @api public
## [br]
## @since unreleased
@export var stable_id_registry_path: String = ""

## 明确选择需要数字 ID 稳定性检查的作者表；其他表的 ID 类型不受影响。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema stable_id_bindings: Dictionary[String,Dictionary]，每表仅包含 symbol_field:String、id_field:String；来源记录必须提供非空精确符号及1至2147483647的int ID。最多4096表、总计65536条记录；完整作者表参与登记，不受消费目标裁剪影响。
@export var stable_id_bindings: Dictionary = {}

## 显式限制本次稳定 ID 对账的表范围；空数组保留整簿对账，未绑定的历史表会退役。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema stable_id_scope_tables: Array[String]，最多4096个唯一精确表名；非空时必须与stable_id_bindings的表集合相同，范围外历史表保持不变。范围内需要整表退役时，绑定一张有schema但没有记录的作者表。
@export var stable_id_scope_tables: Array[String] = []

## 明确允许原身份从退役状态恢复；不分配 ID、不改号，也不允许把历史 ID 交给其他符号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema stable_id_restorations: Dictionary[String,Dictionary[String,String]]，table到symbol到原ID的规范十进制文本，例如{"items":{"potion":"1"}}。作者表ID仍必须为int；表和符号必须同时存在于本次对账映射及历史登记中。已活动的同一声明幂等；声明随Profile进入预览摘要并通过register-ids事务提交。
@export var stable_id_restorations: Dictionary = {}


# --- 公共方法 ---

## 解析消费目标并冻结声明；无目标声明的 Profile 沿用完整数据库构建。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 本次选项；target 选择目标，显式输出路径覆盖目标默认路径。
## [br]
## @schema options: Dictionary，可含 target:String/StringName、output_path:String 和 access_output_path:String；其他选项原样转交既有构建链。
## [br]
## @return 解析结果；失败时不提供可执行选项。
## [br]
## @schema return: 封闭 Dictionary，success:bool、target:GFConfigPipelineConsumerTarget/null、options:Dictionary、error:String；成功目标是声明的独立副本。
func resolve_consumer(options: Dictionary = {}) -> Dictionary:
	var failure: Dictionary = {
		"success": false,
		"target": null,
		"options": {},
		"error": "消费目标声明或选择无效。",
	}
	var selected: Variant = options.get("target", default_consumer_target)
	if not selected is String and not selected is StringName:
		return failure
	var selected_id: StringName = GFVariantData.to_string_name(selected)
	if consumer_targets.size() > 64:
		return failure
	if consumer_targets.is_empty():
		if selected_id != &"":
			return failure
		return {
			"success": true,
			"target": null,
			"options": options.duplicate(),
			"error": "",
		}
	var ids: Dictionary = {}
	var paths: Dictionary = {}
	var target: GFConfigPipelineConsumerTarget
	for declaration: GFConfigPipelineConsumerTarget in consumer_targets:
		if declaration == null or ids.has(declaration.target_id):
			return failure
		var captured: Dictionary = declaration.capture()
		if not GFVariantData.get_option_bool(captured, "success") or declaration.output_path.is_empty():
			return failure
		ids[declaration.target_id] = true
		for role: String in ["output_path", "access_output_path"]:
			var path: String = declaration.output_path if role == "output_path" else declaration.access_output_path
			if path.is_empty():
				continue
			var resolved_path: Dictionary = _resolve_consumer_path(
				path,
				role,
				options
			)
			if not GFVariantData.get_option_bool(resolved_path, "success"):
				return failure
			var canonical: String = GFVariantData.get_option_string(resolved_path, "path").to_lower()
			if paths.has(canonical):
				return failure
			paths[canonical] = [declaration.target_id, role]
		if declaration.target_id == selected_id:
			target = declaration.duplicate_target()
	if target == null:
		return failure
	var effective: Dictionary = options.duplicate()
	effective["target"] = String(selected_id)
	if not effective.has("output_path"):
		effective["output_path"] = target.output_path
	if not effective.has("access_output_path"):
		effective["access_output_path"] = target.access_output_path
	var effective_paths: Dictionary = {}
	for role: String in ["output_path", "access_output_path"]:
		if not effective[role] is String:
			return failure
		var path: String = effective[role]
		if path.is_empty() and role == "access_output_path":
			continue
		var resolved_path: Dictionary = _resolve_consumer_path(
			path,
			role,
			options
		)
		if not GFVariantData.get_option_bool(resolved_path, "success"):
			return failure
		var canonical: String = GFVariantData.get_option_string(resolved_path, "path")
		var identity: String = canonical.to_lower()
		if (
			effective_paths.has(identity)
			or (
				paths.has(identity)
				and paths[identity] != [selected_id, role]
			)
		):
			return failure
		effective_paths[identity] = true
		effective[role] = canonical
	return {
		"success": true,
		"target": target,
		"options": effective,
		"error": "",
	}


## 合成构建选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次构建的覆盖选项；build_options 子字典和直接字段都会覆盖 Profile 默认值。
## [br]
## @schema overrides: Dictionary，可包含 build_options、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、max_validation_cells、max_source_file_bytes、max_xlsx_file_bytes 和 work_limits；直接字段覆盖 Profile 同名选项。work_limits 由 Pipeline 在复制前解析为本次新会话，parse_options 不得设置预算。
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

	var _merge_build_options_result: Dictionary = GFVariantData.merge_dictionary(
		result,
		GFVariantData.get_option_dictionary(overrides, "build_options")
	)
	for key: String in _BUILD_OPTION_KEYS:
		if overrides.has(key):
			result[key] = GFVariantData.duplicate_variant(overrides[key])
	return result


## 合成保存选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次导出的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 save_options；save_options 可包含 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run。
## [br]
## @return: 传给 GFConfigPipeline.save_database() 的选项。
## [br]
## @schema return: Dictionary，包含合成后的保存选项。
func make_save_options(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = save_options.duplicate(true)
	var _merge_save_options_result: Dictionary = GFVariantData.merge_dictionary(
		result,
		GFVariantData.get_option_dictionary(overrides, "save_options")
	)
	return result


## 合成访问器生成选项。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param overrides: 本次访问器生成的覆盖选项。
## [br]
## @schema overrides: Dictionary，可包含 access_options；access_options 可包含生成器选项、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run。
## [br]
## @return: 传给 GFConfigAccessGenerator 的生成选项。
## [br]
## @schema return: Dictionary，包含合成后的访问器生成选项。
func make_access_options(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = access_options.duplicate(true)
	var _merge_access_options_result: Dictionary = GFVariantData.merge_dictionary(
		result,
		GFVariantData.get_option_dictionary(overrides, "access_options")
	)
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


## 创建同内容拷贝；逐来源确认显式 Schema 可复制后，才采用完整 Profile 副本。
## 来源委托 duplicate_source()，嵌套声明遵循各自领域复制方法的扩展契约。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新 Profile 资源；任一非空来源或 Profile 无法复制时返回 null，不交付部分来源列表。
func duplicate_profile() -> GFConfigPipelineProfile:
	var copied_sources: Array[GFConfigPipelineTableSource] = []
	for source: GFConfigPipelineTableSource in sources:
		if source == null:
			copied_sources.append(null)
			continue
		var copied_source: GFConfigPipelineTableSource = source.duplicate_source()
		if copied_source == null:
			return null
		copied_sources.append(copied_source)
	# 保留 Profile 子类导出字段的深复制语义；受控来源副本只在全部成功后替换。
	var duplicated: Variant = duplicate(true)
	if duplicated is GFConfigPipelineProfile:
		var profile: GFConfigPipelineProfile = duplicated
		profile.sources = copied_sources
		return profile
	return null


## 导出 Profile 摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: Profile 摘要字典。
## [br]
## @schema return: Dictionary，包含 profile_id、database_id、version、output_path、access_output_path、access_class_name、access_provider_accessor、source_count、sources、build_options、save_options、access_options 和 metadata。另含consumer_targets:Array[Dictionary]（各目标capture结果）、default_consumer_target:String、stable_id_registry_path:String、stable_id_bindings:Dictionary、stable_id_scope_tables:Array[String]和stable_id_restorations:Dictionary[String,Dictionary[String,String]]；对账范围和恢复声明均保留到输入摘要。
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
		"consumer_targets": _describe_consumers(),
		"default_consumer_target": String(default_consumer_target),
		"stable_id_registry_path": stable_id_registry_path,
		"stable_id_bindings": stable_id_bindings.duplicate(true),
		"stable_id_scope_tables": stable_id_scope_tables.duplicate(),
		"stable_id_restorations": stable_id_restorations.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 与 writer 共用路径策略；只读取两项权限，不复制尚未准入的导出数据图。
## [br]
## @api private
func _resolve_consumer_path(
	path: String,
	role: String,
	options: Dictionary
) -> Dictionary:
	const OUTPUT_PATH_POLICY_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd")
	var option_key: String = "save_options" if role == "output_path" else "access_options"
	var profile_options: Dictionary = save_options if role == "output_path" else access_options
	var raw_overrides: Variant = options.get(option_key)
	var overrides: Dictionary = {}
	if raw_overrides is Dictionary:
		overrides = raw_overrides
	var path_options: Dictionary = {}
	for key: String in ["allow_parent_output_path", "allow_gf_source_output"]:
		var selected: Dictionary = overrides if overrides.has(key) else profile_options
		path_options[key] = GFVariantData.get_option_bool(selected, key)
	return OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(
		path,
		path_options,
		"消费目标"
	)


## 声明摘要包含失败状态，不把无效目标当作可用空目标。
## [br]
## @api private
func _describe_consumers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target: GFConfigPipelineConsumerTarget in consumer_targets:
		result.append(target.capture() if target != null else { "success": false })
	return result


## 按来源列表顺序生成摘要；空引用转换为 valid=false 标记。
## [br]
## @api private
## [br]
func _describe_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: GFConfigPipelineTableSource in sources:
		if source == null:
			result.append({ "valid": false })
			continue
		result.append(source.describe())
	return result
