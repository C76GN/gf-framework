## GFTextureSetClassifier: 纹理集命名分类与导入计划构建工具。
##
## 根据常见后缀把贴图文件归并为材质纹理集，诊断重复或缺失角色，并可生成
## GFImportPlan。它只做路径解析和计划输出，不创建材质、不执行导入、不绑定编辑器 UI。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFTextureSetClassifier
extends RefCounted


# --- 常量 ---

## Albedo/BaseColor 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_ALBEDO: StringName = &"albedo"

## Normal 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_NORMAL: StringName = &"normal"

## Roughness 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_ROUGHNESS: StringName = &"roughness"

## Metallic/Metalness 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_METALLIC: StringName = &"metallic"

## Packed Occlusion/Roughness/Metallic 贴图角色。
## [br]
## @api public
## [br]
## @since 8.0.0
const ROLE_ORM: StringName = &"orm"

## Ambient Occlusion 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_AO: StringName = &"ao"

## Height/Displacement 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_HEIGHT: StringName = &"height"

## Emission 贴图角色。
## [br]
## @api public
## [br]
## @since 6.0.0
const ROLE_EMISSION: StringName = &"emission"

const _DEFAULT_SUFFIX_RULES: Dictionary = {
	&"albedo": ["albedo", "basecolor", "base_color", "diffuse", "color", "col"],
	&"normal": ["normal", "normalgl", "normaldx", "nrm", "nor"],
	&"roughness": ["roughness", "rough", "rgh"],
	&"metallic": ["metallic", "metalness", "metal", "mtl"],
	&"orm": ["orm", "rma", "mra", "arm", "mro"],
	&"ao": ["ao", "ambientocclusion", "ambient_occlusion", "occlusion"],
	&"height": ["height", "displacement", "disp"],
	&"emission": ["emission", "emissive", "emit"],
}

const _DEFAULT_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "tga", "webp", "exr", "hdr"]


# --- 公共方法 ---

## 分类纹理路径。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param paths: 输入路径列表。
## [br]
## @param options: 分类选项。
## [br]
## @schema paths: PackedStringArray texture file paths.
## [br]
## @schema options: Dictionary，可包含 suffix_rules:Dictionary、allowed_extensions:Array[String] 和 required_roles:Array[StringName|String]；suffix_rules 的角色声明顺序决定重叠后缀的匹配优先级。
## [br]
## @return 分类报告。
## [br]
## `ok` 仅在至少匹配一个文件且所有集合均无重复角色、无缺失必需角色时为 true。
## 每个 set 包含 ok:bool、set_id:String、directory:String、base_name:String、
## textures:Dictionary[StringName, String]、source_paths:Array[String]、
## duplicate_roles:Array[Dictionary]、missing_roles:Array[StringName] 和 issues:Array[Dictionary]。
## duplicate_roles 元素包含 role:StringName 与 paths:Array[String]；unmatched 元素包含
## path:String 与 reason:StringName；issue 包含 kind:StringName、set_id:String、role:StringName，
## duplicate_role 还包含 paths:Array[String]。
## [br]
## @schema return: Dictionary with ok:bool, sets:Array[Dictionary], unmatched:Array[Dictionary], matched_count:int, unmatched_count:int, suffix_rules:Dictionary, required_roles:Array[StringName], valid_set_count:int, invalid_set_count:int, duplicate_role_count:int, missing_role_count:int, and issues:Array[Dictionary].
static func classify_files(paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var suffix_rules: Dictionary = _get_suffix_rules(options)
	var allowed_extensions: Array[String] = _get_allowed_extensions(options)
	var required_roles: Array[StringName] = _get_required_roles(options)
	var sets: Dictionary = {}
	var unmatched: Array[Dictionary] = []
	var matched_count: int = 0
	var sorted_paths: PackedStringArray = paths.duplicate()
	sorted_paths.sort()

	for path: String in sorted_paths:
		var normalized_path: String = path.strip_edges()
		var extension: String = normalized_path.get_extension().to_lower()
		if normalized_path.is_empty() or not allowed_extensions.has(extension):
			unmatched.append(_make_unmatched(normalized_path, &"unsupported_extension"))
			continue

		var match_result: Dictionary = _match_texture_role(normalized_path, suffix_rules)
		if not GFVariantData.get_option_bool(match_result, "ok"):
			unmatched.append(_make_unmatched(normalized_path, &"unknown_role"))
			continue

		var directory: String = normalized_path.get_base_dir()
		var base_id: String = GFVariantData.get_option_string(match_result, "base_name")
		var role: StringName = GFVariantData.get_option_string_name(match_result, "role")
		var set_id: String = _make_set_id(directory, base_id)
		var texture_set: Dictionary = GFVariantData.get_option_dictionary(sets, set_id)
		if texture_set.is_empty():
			texture_set = {
				"set_id": set_id,
				"directory": directory,
				"base_name": base_id,
				"_role_paths": {},
				"source_paths": [],
			}

		var role_paths_by_role: Dictionary = GFVariantData.get_option_dictionary(texture_set, "_role_paths")
		var role_paths: Array = GFVariantData.get_option_array(role_paths_by_role, role)
		if not role_paths.has(normalized_path):
			role_paths.append(normalized_path)
		role_paths_by_role[role] = role_paths
		texture_set["_role_paths"] = role_paths_by_role
		var source_paths: Array = GFVariantData.get_option_array(texture_set, "source_paths")
		if not source_paths.has(normalized_path):
			source_paths.append(normalized_path)
		texture_set["source_paths"] = source_paths
		sets[set_id] = texture_set
		matched_count += 1

	var classified_sets: Array[Dictionary] = _finalize_sets(sets, required_roles)
	var issues: Array[Dictionary] = []
	var valid_set_count: int = 0
	var invalid_set_count: int = 0
	var duplicate_role_count: int = 0
	var missing_role_count: int = 0
	for texture_set: Dictionary in classified_sets:
		if GFVariantData.get_option_bool(texture_set, "ok"):
			valid_set_count += 1
		else:
			invalid_set_count += 1
		duplicate_role_count += GFVariantData.get_option_array(texture_set, "duplicate_roles").size()
		missing_role_count += GFVariantData.get_option_array(texture_set, "missing_roles").size()
		for issue_value: Variant in GFVariantData.get_option_array(texture_set, "issues"):
			issues.append(GFVariantData.as_dictionary(issue_value).duplicate(true))

	return {
		"ok": matched_count > 0 and invalid_set_count == 0,
		"sets": classified_sets,
		"unmatched": unmatched,
		"matched_count": matched_count,
		"unmatched_count": unmatched.size(),
		"suffix_rules": suffix_rules,
		"required_roles": required_roles,
		"valid_set_count": valid_set_count,
		"invalid_set_count": invalid_set_count,
		"duplicate_role_count": duplicate_role_count,
		"missing_role_count": missing_role_count,
		"issues": issues,
	}


## 从纹理路径构建材质导入计划。重复或缺少必需角色的集合不会生成条目，诊断会保留在计划 metadata。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param paths: 输入路径列表。
## [br]
## @param target_root: 目标材质目录。
## [br]
## @param options: 构建选项。
## [br]
## @schema paths: PackedStringArray texture file paths.
## [br]
## @schema options: Dictionary，可包含 material_extension、type_hint、suffix_rules、allowed_extensions、required_roles 和 metadata。
## [br]
## @return 导入计划。
static func build_material_import_plan(
	paths: PackedStringArray,
	target_root: String,
	options: Dictionary = {}
) -> GFImportPlan:
	var plan: GFImportPlan = GFImportPlan.new()
	plan.metadata = GFVariantData.get_option_dictionary(options, "metadata")
	var classification: Dictionary = classify_files(paths, options)
	plan.metadata["texture_set_count"] = GFVariantData.get_option_array(classification, "sets").size()
	plan.metadata["valid_texture_set_count"] = GFVariantData.get_option_int(classification, "valid_set_count")
	plan.metadata["invalid_texture_set_count"] = GFVariantData.get_option_int(classification, "invalid_set_count")
	plan.metadata["duplicate_role_count"] = GFVariantData.get_option_int(classification, "duplicate_role_count")
	plan.metadata["missing_role_count"] = GFVariantData.get_option_int(classification, "missing_role_count")
	plan.metadata["texture_set_issues"] = GFVariantData.get_option_array(classification, "issues").duplicate(true)
	plan.metadata["unmatched_count"] = GFVariantData.get_option_int(classification, "unmatched_count")
	var extension: String = GFVariantData.get_option_string(options, "material_extension", "tres").strip_edges()
	if extension.begins_with("."):
		extension = extension.substr(1)
	if extension.is_empty():
		extension = "tres"

	for set_value: Variant in GFVariantData.get_option_array(classification, "sets"):
		var texture_set: Dictionary = GFVariantData.as_dictionary(set_value)
		if not GFVariantData.get_option_bool(texture_set, "ok"):
			continue
		var source_paths: Array = GFVariantData.get_option_array(texture_set, "source_paths")
		if source_paths.is_empty():
			continue
		var base_id: String = GFVariantData.get_option_string(texture_set, "base_name")
		var target_path: String = _join_path(target_root, "%s.%s" % [base_id, extension])
		var _updated_plan: GFImportPlan = plan.add_entry(
			GFVariantData.to_text(source_paths[0]),
			target_path,
			GFImportPlan.OPERATION_CONVERT,
			{
				"source_format": "texture_set",
				"target_format": extension,
				"type_hint": GFVariantData.get_option_string(options, "type_hint", "material"),
				"source_trace": {
					"set_id": GFVariantData.get_option_string(texture_set, "set_id"),
					"source_paths": source_paths.duplicate(true),
				},
				"repair_actions": [
					{
						"kind": "create_parent_directory",
					},
				],
				"metadata": {
					"textures": GFVariantData.get_option_dictionary(texture_set, "textures"),
					"base_name": base_id,
				},
			}
		)
	return plan


## 获取默认后缀规则。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 后缀规则副本。
## [br]
## @schema return: Dictionary mapping role StringName to Array[String] suffixes.
static func get_default_suffix_rules() -> Dictionary:
	return _DEFAULT_SUFFIX_RULES.duplicate(true)


# --- 私有/辅助方法 ---

static func _get_suffix_rules(options: Dictionary) -> Dictionary:
	var custom_rules: Dictionary = GFVariantData.get_option_dictionary(options, "suffix_rules")
	if custom_rules.is_empty():
		return get_default_suffix_rules()
	return custom_rules.duplicate(true)


static func _get_allowed_extensions(options: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var configured: Array = GFVariantData.get_option_array(options, "allowed_extensions")
	if configured.is_empty():
		configured = _DEFAULT_EXTENSIONS.duplicate()
	for extension_value: Variant in configured:
		var extension: String = GFVariantData.to_text(extension_value).strip_edges().to_lower()
		if extension.begins_with("."):
			extension = extension.substr(1)
		if not extension.is_empty() and not result.has(extension):
			result.append(extension)
	return result


static func _get_required_roles(options: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for role_value: Variant in GFVariantData.get_option_array(options, "required_roles"):
		var role: StringName = GFVariantData.to_string_name(role_value)
		if role != &"" and not result.has(role):
			result.append(role)
	result.sort()
	return result


static func _match_texture_role(path: String, suffix_rules: Dictionary) -> Dictionary:
	var stem: String = path.get_file().get_basename()
	var normalized_stem: String = _normalize_token(stem)
	for role_value: Variant in suffix_rules.keys():
		var role: StringName = GFVariantData.to_string_name(role_value)
		if role == &"":
			continue
		for suffix_value: Variant in GFVariantData.get_option_array(suffix_rules, role):
			var suffix: String = _normalize_token(GFVariantData.to_text(suffix_value))
			var base_name: String = _strip_suffix(stem, normalized_stem, suffix)
			if base_name.is_empty():
				continue
			return {
				"ok": true,
				"role": role,
				"base_name": base_name,
			}
	return { "ok": false, "role": &"", "base_name": "" }


static func _strip_suffix(original_stem: String, normalized_stem: String, suffix: String) -> String:
	if suffix.is_empty():
		return ""
	if normalized_stem == suffix:
		return original_stem
	for separator: String in ["_", "-", ".", " "]:
		var token: String = separator + suffix
		if normalized_stem.ends_with(token):
			var base_length: int = original_stem.length() - token.length()
			return original_stem.substr(0, base_length).strip_edges()
	return ""


static func _normalize_token(value: String) -> String:
	var result: String = value.strip_edges().to_lower()
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace(".", "_")
	while result.contains("__"):
		result = result.replace("__", "_")
	return result.trim_suffix("_")


static func _make_set_id(directory: String, base_id: String) -> String:
	if directory.is_empty():
		return base_id
	return "%s/%s" % [directory.trim_suffix("/"), base_id]


static func _make_unmatched(path: String, reason: StringName) -> Dictionary:
	return {
		"path": path,
		"reason": reason,
	}


static func _finalize_sets(sets: Dictionary, required_roles: Array[StringName]) -> Array[Dictionary]:
	var keys: Array = sets.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for set_key: Variant in keys:
		var texture_set: Dictionary = GFVariantData.get_option_dictionary(sets, set_key)
		var set_id: String = GFVariantData.get_option_string(texture_set, "set_id")
		var role_paths_by_role: Dictionary = GFVariantData.get_option_dictionary(texture_set, "_role_paths")
		var textures: Dictionary = {}
		var duplicate_roles: Array[Dictionary] = []
		var missing_roles: Array[StringName] = []
		var issues: Array[Dictionary] = []
		var roles: Array[StringName] = []
		for role_value: Variant in role_paths_by_role.keys():
			var role_name: StringName = GFVariantData.to_string_name(role_value)
			if role_name != &"" and not roles.has(role_name):
				roles.append(role_name)
		roles.sort()

		for role: StringName in roles:
			var role_paths: Array = GFVariantData.get_option_array(role_paths_by_role, role)
			role_paths.sort()
			if role_paths.size() == 1:
				textures[role] = GFVariantData.to_text(role_paths[0])
				continue
			if role_paths.size() <= 1:
				continue
			var duplicate_role: Dictionary = {
				"role": role,
				"paths": role_paths.duplicate(),
			}
			duplicate_roles.append(duplicate_role)
			issues.append({
				"kind": &"duplicate_role",
				"set_id": set_id,
				"role": role,
				"paths": role_paths.duplicate(),
			})

		for required_role: StringName in required_roles:
			var required_paths: Array = GFVariantData.get_option_array(role_paths_by_role, required_role)
			if not required_paths.is_empty():
				continue
			missing_roles.append(required_role)
			issues.append({
				"kind": &"missing_required_role",
				"set_id": set_id,
				"role": required_role,
			})

		var source_paths: Array = GFVariantData.get_option_array(texture_set, "source_paths")
		source_paths.sort()
		var finalized_set: Dictionary = texture_set.duplicate(true)
		var _erased_role_paths: bool = finalized_set.erase("_role_paths")
		finalized_set["ok"] = issues.is_empty()
		finalized_set["textures"] = textures
		finalized_set["duplicate_roles"] = duplicate_roles
		finalized_set["missing_roles"] = missing_roles
		finalized_set["issues"] = issues
		finalized_set["source_paths"] = source_paths
		result.append(finalized_set)
	return result


static func _join_path(base_path: String, file_name: String) -> String:
	var root: String = base_path.strip_edges()
	if root.is_empty():
		return file_name
	return "%s/%s" % [root.trim_suffix("/"), file_name]
