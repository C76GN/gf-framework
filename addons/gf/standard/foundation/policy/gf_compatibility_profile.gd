## GFCompatibilityProfile: 通用兼容性与能力 Profile。
##
## 用纯数据描述当前运行环境、目标构建、包集合、平台和功能能力。它只承载
## 预检所需的声明式信息，不执行安装、下载、动态代码启用或项目业务策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 7.0.0
class_name GFCompatibilityProfile
extends Resource


# --- 导出变量 ---

## Profile 稳定标识。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var profile_id: StringName = &""

## Godot 版本字符串。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var godot_version: String = ""

## GF 框架版本字符串。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var framework_version: String = ""

## 当前或目标平台标识列表。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var platforms: PackedStringArray = PackedStringArray()

## 当前或目标功能能力标识列表。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var features: PackedStringArray = PackedStringArray()

## 已知包条目列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema packages: Array[Dictionary]，每项至少包含 id 或 package_id，可选 version、kind 和 metadata。
@export var packages: Array[Dictionary] = []

## 已知 artifact 条目列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema artifacts: Array[Dictionary]，每项至少包含 id 或 artifact_id，可选 path、sha256、size_bytes、kind 和 metadata。
@export var artifacts: Array[Dictionary] = []

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary caller-defined profile metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置 Profile。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_profile_id: Profile 稳定标识。
## [br]
## @param p_godot_version: Godot 版本字符串。
## [br]
## @param p_framework_version: GF 框架版本字符串。
## [br]
## @param p_platforms: 平台标识列表。
## [br]
## @param p_features: 功能能力标识列表。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined profile metadata.
## [br]
## @return 当前 Profile。
func configure(
	p_profile_id: StringName,
	p_godot_version: String = "",
	p_framework_version: String = "",
	p_platforms: PackedStringArray = PackedStringArray(),
	p_features: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> GFCompatibilityProfile:
	profile_id = p_profile_id
	godot_version = p_godot_version.strip_edges()
	framework_version = p_framework_version.strip_edges()
	platforms = _normalize_string_set(p_platforms)
	features = _normalize_string_set(p_features)
	metadata = p_metadata.duplicate(true)
	return self


## 清空 Profile。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	profile_id = &""
	godot_version = ""
	framework_version = ""
	platforms.clear()
	features.clear()
	packages.clear()
	artifacts.clear()
	metadata.clear()


## 添加平台标识。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @return 成功添加或已存在时返回 true。
func add_platform(platform_id: String) -> bool:
	var normalized: String = platform_id.strip_edges()
	if normalized.is_empty():
		return false
	if not platforms.has(normalized):
		var _appended: bool = platforms.append(normalized)
	return true


## 检查平台是否存在。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @return 存在返回 true。
func has_platform(platform_id: String) -> bool:
	return platforms.has(platform_id.strip_edges())


## 添加功能能力标识。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param feature_id: 功能能力标识。
## [br]
## @return 成功添加或已存在时返回 true。
func add_feature(feature_id: StringName) -> bool:
	var normalized: String = String(feature_id).strip_edges()
	if normalized.is_empty():
		return false
	if not features.has(normalized):
		var _appended: bool = features.append(normalized)
	return true


## 检查功能能力是否存在。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param feature_id: 功能能力标识。
## [br]
## @return 存在返回 true。
func has_feature(feature_id: StringName) -> bool:
	return features.has(String(feature_id).strip_edges())


## 添加包条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param package_id: 包 ID。
## [br]
## @param version: 包版本。
## [br]
## @param options: 附加字段，支持 kind 和 metadata，也允许调用方自定义字段。
## [br]
## @schema options: Dictionary package entry fields.
## [br]
## @return 添加后的包条目副本。
## [br]
## @schema return: Dictionary package entry.
func add_package(package_id: StringName, version: String = "", options: Dictionary = {}) -> Dictionary:
	if package_id == &"":
		return {}
	var entry: Dictionary = options.duplicate(true)
	entry["id"] = package_id
	entry["package_id"] = package_id
	entry["version"] = version.strip_edges()
	var existing_index: int = _find_entry_index(packages, package_id, "package_id")
	if existing_index >= 0:
		packages[existing_index] = entry
	else:
		packages.append(entry)
	return entry.duplicate(true)


## 获取包条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param package_id: 包 ID。
## [br]
## @return 包条目副本；不存在时为空字典。
## [br]
## @schema return: Dictionary package entry.
func get_package(package_id: StringName) -> Dictionary:
	for entry: Dictionary in packages:
		if _get_entry_id(entry, "package_id") == package_id:
			return entry.duplicate(true)
	return {}


## 检查包是否存在。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param package_id: 包 ID。
## [br]
## @return 存在返回 true。
func has_package(package_id: StringName) -> bool:
	return not get_package(package_id).is_empty()


## 添加 artifact 条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param artifact_id: artifact ID。
## [br]
## @param path: artifact 路径。
## [br]
## @param options: 附加字段，支持 kind、sha256、size_bytes 和 metadata，也允许调用方自定义字段。
## [br]
## @schema options: Dictionary artifact entry fields.
## [br]
## @return 添加后的 artifact 条目副本。
## [br]
## @schema return: Dictionary artifact entry.
func add_artifact(artifact_id: StringName, path: String = "", options: Dictionary = {}) -> Dictionary:
	if artifact_id == &"":
		return {}
	var entry: Dictionary = options.duplicate(true)
	entry["id"] = artifact_id
	entry["artifact_id"] = artifact_id
	entry["path"] = path.strip_edges()
	var existing_index: int = _find_entry_index(artifacts, artifact_id, "artifact_id")
	if existing_index >= 0:
		artifacts[existing_index] = entry
	else:
		artifacts.append(entry)
	return entry.duplicate(true)


## 获取 artifact 条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param artifact_id: artifact ID。
## [br]
## @return artifact 条目副本；不存在时为空字典。
## [br]
## @schema return: Dictionary artifact entry.
func get_artifact(artifact_id: StringName) -> Dictionary:
	for entry: Dictionary in artifacts:
		if _get_entry_id(entry, "artifact_id") == artifact_id:
			return entry.duplicate(true)
	return {}


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return Profile 字典。
## [br]
## @schema return: Dictionary with profile_id, godot_version, framework_version, platforms, features, packages, artifacts, and metadata.
func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"godot_version": godot_version,
		"framework_version": framework_version,
		"platforms": platforms.duplicate(),
		"features": features.duplicate(),
		"packages": _copy_entries(packages),
		"artifacts": _copy_entries(artifacts),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用 Profile 字段。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param data: Profile 字典。
## [br]
## @schema data: Dictionary with profile_id, godot_version, framework_version, platforms, features, packages, artifacts, and metadata.
func apply_dict(data: Dictionary) -> void:
	profile_id = GFVariantData.get_option_string_name(data, "profile_id")
	godot_version = GFVariantData.get_option_string(data, "godot_version").strip_edges()
	framework_version = GFVariantData.get_option_string(data, "framework_version").strip_edges()
	platforms = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "platforms"))
	features = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "features"))
	packages = _copy_entries_from_array(GFVariantData.get_option_array(data, "packages"))
	artifacts = _copy_entries_from_array(GFVariantData.get_option_array(data, "artifacts"))
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建 Profile 深拷贝。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 新 Profile。
func duplicate_profile() -> GFCompatibilityProfile:
	var result: GFCompatibilityProfile = GFCompatibilityProfile.new()
	result.apply_dict(to_dict())
	return result


## 创建当前运行环境 Profile。
## [br]
## features、framework_version、packages 和 artifacts 由调用方显式传入；GF 不猜测项目能力或包闭包。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: Profile 选项。
## [br]
## @schema options: Dictionary，可包含 profile_id、framework_version、platforms、features、packages、artifacts 和 metadata。
## [br]
## @return 新 Profile。
static func from_current_environment(options: Dictionary = {}) -> GFCompatibilityProfile:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var version_info: Dictionary = Engine.get_version_info()
	var godot_text: String = GFVariantData.get_option_string(version_info, "string")
	if godot_text.is_empty():
		godot_text = "%d.%d.%d" % [
			GFVariantData.get_option_int(version_info, "major"),
			GFVariantData.get_option_int(version_info, "minor"),
			GFVariantData.get_option_int(version_info, "patch"),
		]

	var option_platforms: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "platforms")
	if option_platforms.is_empty():
		var _platform_appended: bool = option_platforms.append(OS.get_name())
	var _configured: GFCompatibilityProfile = profile.configure(
		GFVariantData.get_option_string_name(options, "profile_id", &"current"),
		godot_text,
		GFVariantData.get_option_string(options, "framework_version"),
		option_platforms,
		GFVariantData.get_option_packed_string_array(options, "features"),
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	profile.packages = _copy_entries_from_array(GFVariantData.get_option_array(options, "packages"))
	profile.artifacts = _copy_entries_from_array(GFVariantData.get_option_array(options, "artifacts"))
	return profile


## 从字典创建 Profile。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param data: Profile 字典。
## [br]
## @schema data: Dictionary with profile_id, godot_version, framework_version, platforms, features, packages, artifacts, and metadata.
## [br]
## @return 新 Profile。
static func from_dict(data: Dictionary) -> GFCompatibilityProfile:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	profile.apply_dict(data)
	return profile


# --- 私有/辅助方法 ---

static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	result.sort()
	return result


static func _copy_entries(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source_entries:
		result.append(entry.duplicate(true))
	return result


static func _copy_entries_from_array(source_entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value: Variant in source_entries:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			result.append(entry.duplicate(true))
	return result


static func _get_entry_id(entry: Dictionary, fallback_key: String) -> StringName:
	return GFVariantData.get_option_string_name(
		entry,
		"id",
		GFVariantData.get_option_string_name(entry, fallback_key)
	)


static func _find_entry_index(entries: Array[Dictionary], entry_id: StringName, fallback_key: String) -> int:
	for index: int in range(entries.size()):
		if _get_entry_id(entries[index], fallback_key) == entry_id:
			return index
	return -1
