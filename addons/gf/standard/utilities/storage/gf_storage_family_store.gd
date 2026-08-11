## GFStorageFamilyStore: Storage 私有 family 布局与逻辑 catalog 协作者。
##
## 该类型把 portable logical path 映射为私有、分片、可相互校验的 catalog 与 family。
## descriptor 含有仅供 Storage 协作者使用的物理路径，因此整个类型标记为 framework_internal；
## 该边界不是同进程安全沙箱。此类型不负责业务数据编码、事务提交或异步调度。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
class_name GFStorageFamilyStore
extends RefCounted


# --- 常量 ---

const _PRIVATE_ROOT_NAME: String = ".gf-storage"
const _LAYOUT_VERSION: int = 1
const _PATH_PROFILE: String = "portable-ascii-v1"
const _IDENTITY_ALGORITHM: String = "sha256-domain-nul-uuidv8-v1"
const _MAX_LOGICAL_PATH_BYTES: int = 255
const _MAX_LOGICAL_SEGMENT_BYTES: int = 64
const _MAX_LOGICAL_SEGMENTS: int = 16
const _MAX_EXTENSION_BYTES: int = 16
const _MAX_MANIFEST_BYTES: int = 16 * 1024

const _IDENTITY_DOMAIN: String = "gf.storage.family/v1"
const _LAYOUT_SCHEMA: String = "gf.storage.layout"
const _CATALOG_SCHEMA: String = "gf.storage.catalog-entry"
const _OWNER_SCHEMA: String = "gf.storage.family-owner"
const _PUBLISH_PENDING_SEPARATOR: String = ".pending-"
const _CLAIM_STAGING_SEPARATOR: String = ".claim-"
const _HEX_CHARS: String = "0123456789abcdef"
const _ALLOWED_SEGMENT_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789._-"
const _ALNUM_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789"
const _RESERVED_DEVICE_STEMS: Array[String] = [
	"con", "prn", "aux", "nul",
	"com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
	"lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9",
]


# --- 私有变量 ---

var _storage_root_path: String = ""


# --- 框架内部方法 ---

## 判断文件 logical identity 是否满足 portable-ascii-v1。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param logical_path: 未经改写的调用方输入。
## [br]
## @return 仅在输入本身已经是 canonical logical identity 时返回 true。
static func is_valid_logical_file_path_for_framework(logical_path: String) -> bool:
	return _is_valid_logical_path(logical_path, false)


## 判断逻辑目录 selector 是否满足 portable-ascii-v1；空字符串表示逻辑根。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param logical_path: 未经改写的目录 selector。
## [br]
## @return selector 合法时返回 true。
static func is_valid_logical_directory_path_for_framework(logical_path: String) -> bool:
	return _is_valid_logical_path(logical_path, true)


## 判断 list 扩展名过滤器是否已经是 canonical lowercase token。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param extension_filter: 空字符串或不带点号的 lowercase ASCII token。
## [br]
## @return 过滤器合法时返回 true。
static func is_valid_extension_filter_for_framework(extension_filter: String) -> bool:
	if extension_filter.is_empty():
		return true
	if extension_filter.length() > _MAX_EXTENSION_BYTES:
		return false
	if not _is_ascii_alnum(extension_filter.substr(0, 1)):
		return false
	for index: int in range(extension_filter.length()):
		var character: String = extension_filter.substr(index, 1)
		if not _ALNUM_CHARS.contains(character) and character != "_" and character != "-":
			return false
	return true


## 判断一个框架生成的 private relative path 是否保持在固定 namespace 内。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param relative_path: 未经改写的 private relative path。
## [br]
## @return 仅接受 `.gf-storage/v1/...` 下无别名、无父段的 ASCII 路径。
static func is_valid_private_relative_path_for_framework(relative_path: String) -> bool:
	if (
		relative_path.length() <= _PRIVATE_ROOT_NAME.length() + 4
		or relative_path.length() > 1024
		or not relative_path.begins_with("%s/v%d/" % [_PRIVATE_ROOT_NAME, _LAYOUT_VERSION])
		or relative_path.contains("\\")
	):
		return false
	var segments: PackedStringArray = relative_path.split("/", true)
	if segments.size() < 3:
		return false
	for segment: String in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
		for index: int in range(segment.length()):
			var character: String = segment.substr(index, 1)
			if not _ALLOWED_SEGMENT_CHARS.contains(character):
				return false
	return true


## 由公开 save_dir_name 构造 canonical `user://` Storage root。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param save_dir_name: 空字符串或 portable logical directory。
## [br]
## @return 合法 root；非法时返回空字符串。
static func make_storage_root_path_for_framework(save_dir_name: String) -> String:
	if save_dir_name.is_empty():
		return "user://"
	if not is_valid_logical_directory_path_for_framework(save_dir_name):
		return ""
	return "user://" + save_dir_name


## 从 logical identity 确定性派生 opaque UUID v8 family ID。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param logical_path: portable logical file path。
## [br]
## @return canonical UUID v8；输入非法时返回空字符串。
static func make_family_id_for_framework(logical_path: String) -> String:
	if not is_valid_logical_file_path_for_framework(logical_path):
		return ""
	var digest: String = _make_logical_digest(logical_path)
	if digest.length() != 64:
		return ""
	var raw: String = digest.substr(0, 32)
	var variant_source: int = _HEX_CHARS.find(raw.substr(16, 1))
	var variant_nibble: String = _HEX_CHARS.substr(8 | (variant_source & 3), 1)
	return "%s-%s-8%s-%s-%s" % [
		raw.substr(0, 8),
		raw.substr(8, 4),
		raw.substr(13, 3),
		variant_nibble + raw.substr(17, 3),
		raw.substr(20, 12),
	]


## 纯计算一个 family descriptor；该方法不读取或创建文件。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param storage_root_path: canonical `user://` Storage root。
## [br]
## @param logical_path: portable logical file path。
## [br]
## @return 固定物理布局 descriptor；输入非法时为空字典。
## [br]
## @schema return: Dictionary，包含 logical_path、logical_sha256、family_id、file_key、catalog/family/owner、payload/candidate/backup/resource-stage、prepare/commit record 与 pending record 的物理及相对路径。
static func make_family_descriptor_for_framework(
	storage_root_path: String,
	logical_path: String
) -> Dictionary:
	if not _is_valid_storage_root(storage_root_path):
		return {}
	if not is_valid_logical_file_path_for_framework(logical_path):
		return {}
	var logical_sha256: String = _make_logical_digest(logical_path)
	var family_id: String = make_family_id_for_framework(logical_path)
	if logical_sha256.length() != 64 or family_id.is_empty():
		return {}
	var compact_family_id: String = family_id.replace("-", "")
	var physical_extension: String = _derive_physical_extension(logical_path)
	var catalog_relative_path: String = "%s/v%d/catalog/%s/%s/%s.json" % [
		_PRIVATE_ROOT_NAME,
		_LAYOUT_VERSION,
		logical_sha256.substr(0, 2),
		logical_sha256.substr(2, 2),
		logical_sha256,
	]
	var family_relative_path: String = "%s/v%d/families/%s/%s/%s" % [
		_PRIVATE_ROOT_NAME,
		_LAYOUT_VERSION,
		compact_family_id.substr(0, 2),
		compact_family_id.substr(2, 2),
		family_id,
	]
	var payload_leaf: String = "payload.%s" % physical_extension
	var candidate_leaf: String = "candidate.%s" % physical_extension
	var backup_leaf: String = "backup.%s" % physical_extension
	var resource_stage_leaf: String = "resource-stage.%s" % physical_extension
	return {
		"logical_path": logical_path,
		"logical_sha256": logical_sha256,
		"family_id": family_id,
		"file_key": storage_root_path + "|gf-family|" + family_id,
		"physical_extension": physical_extension,
		"catalog_relative_path": catalog_relative_path,
		"family_relative_path": family_relative_path,
		"owner_relative_path": family_relative_path + "/owner.json",
		"payload_relative_path": family_relative_path + "/" + payload_leaf,
		"candidate_relative_path": family_relative_path + "/" + candidate_leaf,
		"backup_relative_path": family_relative_path + "/" + backup_leaf,
		"transaction_relative_path": family_relative_path + "/transaction.prepare.json",
		"transaction_pending_relative_path": family_relative_path + "/transaction.prepare.pending.json",
		"transaction_commit_relative_path": family_relative_path + "/transaction.commit.json",
		"transaction_commit_pending_relative_path": family_relative_path + "/transaction.commit.pending.json",
		"resource_stage_relative_path": family_relative_path + "/" + resource_stage_leaf,
		"catalog_path": _join_storage_root(storage_root_path, catalog_relative_path),
		"family_path": _join_storage_root(storage_root_path, family_relative_path),
		"owner_path": _join_storage_root(storage_root_path, family_relative_path + "/owner.json"),
		"payload_path": _join_storage_root(storage_root_path, family_relative_path + "/" + payload_leaf),
		"candidate_path": _join_storage_root(storage_root_path, family_relative_path + "/" + candidate_leaf),
		"backup_path": _join_storage_root(storage_root_path, family_relative_path + "/" + backup_leaf),
		"transaction_path": _join_storage_root(storage_root_path, family_relative_path + "/transaction.prepare.json"),
		"transaction_pending_path": _join_storage_root(storage_root_path, family_relative_path + "/transaction.prepare.pending.json"),
		"transaction_commit_path": _join_storage_root(storage_root_path, family_relative_path + "/transaction.commit.json"),
		"transaction_commit_pending_path": _join_storage_root(storage_root_path, family_relative_path + "/transaction.commit.pending.json"),
		"resource_stage_path": _join_storage_root(storage_root_path, family_relative_path + "/" + resource_stage_leaf),
	}


## 绑定一个 canonical Storage root。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param storage_root_path: `user://` 或其 portable 子目录。
## [br]
## @return 配置成功时返回 true。
func configure_for_framework(storage_root_path: String) -> bool:
	if not _is_valid_storage_root(storage_root_path):
		return false
	_storage_root_path = storage_root_path
	return true


## 获取当前绑定的 canonical Storage root。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @return 未配置时为空字符串。
func get_storage_root_path_for_framework() -> String:
	return _storage_root_path


## 确保 private v1 layout manifest 与分片目录存在并严格匹配。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @return Godot Error；未知或损坏布局返回 ERR_FILE_CORRUPT。
func ensure_layout_for_framework() -> Error:
	if _storage_root_path.is_empty():
		return ERR_INVALID_PARAMETER
	var root_error: Error = _ensure_directory(_storage_root_path)
	if root_error != OK:
		return root_error
	var private_root: String = _join_storage_root(_storage_root_path, _PRIVATE_ROOT_NAME)
	var version_root: String = private_root.path_join("v%d" % _LAYOUT_VERSION)
	var layout_path: String = version_root.path_join("layout.json")
	if DirAccess.dir_exists_absolute(private_root):
		var private_entries: Dictionary = _read_directory_entries(private_root)
		if GFVariantData.get_option_int(private_entries, "error", OK) != OK:
			return GFVariantData.get_option_int(private_entries, "error", ERR_FILE_CANT_READ) as Error
		for entry: String in GFVariantData.get_option_array(private_entries, "names"):
			if entry != "v%d" % _LAYOUT_VERSION:
				return ERR_FILE_CORRUPT
	else:
		var private_error: Error = _ensure_directory(private_root)
		if private_error != OK:
			return private_error
	var version_error: Error = _ensure_directory(version_root)
	if version_error != OK:
		return version_error
	var version_entries: Dictionary = _read_directory_entries(version_root)
	if GFVariantData.get_option_int(version_entries, "error", OK) != OK:
		return GFVariantData.get_option_int(version_entries, "error", ERR_FILE_CANT_READ) as Error
	for entry: String in GFVariantData.get_option_array(version_entries, "names"):
		if entry == "layout.json" or entry == "catalog" or entry == "families":
			continue
		if not _is_publish_pending_leaf(entry, "layout.json"):
			return ERR_FILE_CORRUPT
		if DirAccess.dir_exists_absolute(version_root.path_join(entry)):
			return ERR_FILE_CORRUPT
	var publish_error: Error = _publish_json_if_absent(layout_path, _make_layout_manifest())
	if publish_error != OK:
		return publish_error
	var layout_entries: Dictionary = _read_directory_entries(version_root)
	if GFVariantData.get_option_int(layout_entries, "error", OK) != OK:
		return GFVariantData.get_option_int(layout_entries, "error", ERR_FILE_CANT_READ) as Error
	for entry: String in GFVariantData.get_option_array(layout_entries, "names"):
		if (
			entry != "layout.json"
			and entry != "catalog"
			and entry != "families"
		):
			return ERR_FILE_CORRUPT
	var catalog_error: Error = _ensure_directory(version_root.path_join("catalog"))
	if catalog_error != OK:
		return catalog_error
	return _ensure_directory(version_root.path_join("families"))


## 原子、幂等地 claim 一个 descriptor 的 owner 与 catalog。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param descriptor: make_family_descriptor_for_framework() 的结果。
## [br]
## @schema descriptor: Dictionary，必须精确匹配 make_family_descriptor_for_framework() 的固定字段与派生路径。
## [br]
## @return 已有同一 claim 也返回 OK；任何漂移或冲突失败关闭。
func claim_family_for_framework(descriptor: Dictionary) -> Error:
	var descriptor_error: Error = _validate_descriptor(descriptor)
	if descriptor_error != OK:
		return descriptor_error
	var layout_error: Error = ensure_layout_for_framework()
	if layout_error != OK:
		return layout_error
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var family_parent_error: Error = _ensure_directory(family_path.get_base_dir())
	if family_parent_error != OK:
		return family_parent_error
	var staging_recovery_error: Error = _reconcile_claim_staging(descriptor)
	if staging_recovery_error != OK:
		return staging_recovery_error
	var catalog_exists: bool = FileAccess.file_exists(catalog_path)
	var family_exists: bool = DirAccess.dir_exists_absolute(family_path)
	if catalog_exists and family_exists:
		return validate_family_for_framework(descriptor)
	if catalog_exists and not family_exists:
		return ERR_FILE_CORRUPT
	if family_exists:
		var owner_recovery_error: Error = _validate_owner_only_claim(descriptor)
		if owner_recovery_error != OK:
			return owner_recovery_error
		var catalog_recovery_error: Error = _publish_json_if_absent(
			catalog_path,
			_make_identity_record(_CATALOG_SCHEMA, descriptor)
		)
		if catalog_recovery_error != OK:
			return catalog_recovery_error
		return validate_family_for_framework(descriptor)

	var staging_path: String = family_path + _CLAIM_STAGING_SEPARATOR + GFUuid.generate_v4()
	var staging_error: Error = _ensure_directory(staging_path)
	if staging_error != OK:
		return staging_error
	var staging_owner_path: String = staging_path.path_join("owner.json")
	var owner_write_error: Error = _write_json_direct(
		staging_owner_path,
		_make_identity_record(_OWNER_SCHEMA, descriptor)
	)
	if owner_write_error != OK:
		var _staging_cleanup_error: Error = _remove_claim_staging(staging_path)
		return owner_write_error
	var install_error: Error = DirAccess.rename_absolute(staging_path, family_path)
	if install_error != OK:
		var _staging_cleanup_error_after_race: Error = _remove_claim_staging(staging_path)
		if not DirAccess.dir_exists_absolute(family_path):
			return install_error
		var raced_owner_error: Error = _validate_owner_only_claim(descriptor)
		if raced_owner_error != OK:
			return raced_owner_error
	var catalog_publish_error: Error = _publish_json_if_absent(
		catalog_path,
		_make_identity_record(_CATALOG_SCHEMA, descriptor)
	)
	if catalog_publish_error != OK:
		return catalog_publish_error
	return validate_family_for_framework(descriptor)


## 严格校验 descriptor、catalog、owner 与 family 固定条目。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param descriptor: 待验证 descriptor。
## [br]
## @schema descriptor: Dictionary，必须精确匹配 make_family_descriptor_for_framework() 的固定字段与派生路径。
## [br]
## @return family 不存在返回 ERR_FILE_NOT_FOUND；漂移或损坏返回 ERR_FILE_CORRUPT。
func validate_family_for_framework(descriptor: Dictionary) -> Error:
	var descriptor_error: Error = _validate_descriptor(descriptor)
	if descriptor_error != OK:
		return descriptor_error
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
	if not FileAccess.file_exists(catalog_path) and not DirAccess.dir_exists_absolute(family_path):
		return ERR_FILE_NOT_FOUND
	if not FileAccess.file_exists(catalog_path) or not DirAccess.dir_exists_absolute(family_path):
		return ERR_FILE_CORRUPT
	if not FileAccess.file_exists(owner_path):
		return ERR_FILE_CORRUPT
	var catalog_result: Dictionary = _read_json_dictionary(catalog_path)
	var owner_result: Dictionary = _read_json_dictionary(owner_path)
	if (
		not GFVariantData.get_option_bool(catalog_result, "ok")
		or not GFVariantData.get_option_bool(owner_result, "ok")
	):
		return ERR_FILE_CORRUPT
	if not _matches_identity_record(
		GFVariantData.get_option_dictionary(catalog_result, "data"),
		_CATALOG_SCHEMA,
		descriptor
	):
		return ERR_FILE_CORRUPT
	if not _matches_identity_record(
		GFVariantData.get_option_dictionary(owner_result, "data"),
		_OWNER_SCHEMA,
		descriptor
	):
		return ERR_FILE_CORRUPT
	return _validate_family_entries(descriptor)


## 从分片 catalog 投影 logical files。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param directory_name: 空或 portable logical directory。
## [br]
## @param extension_filter: 空或 canonical extension token。
## [br]
## @param recursive: 是否包含逻辑后代目录。
## [br]
## @param max_scan_depth: 相对 selector 的最大逻辑目录深度；0 表示不限制。
## [br]
## @param max_file_count: 最大结果数；0 表示不限制。
## [br]
## @return Dictionary，包含 error 与排序后的 PackedStringArray files。
## [br]
## @schema return: Dictionary，包含 error: Error 和 files: PackedStringArray。
func list_files_for_framework(
	directory_name: String,
	extension_filter: String,
	recursive: bool,
	max_scan_depth: int,
	max_file_count: int
) -> Dictionary:
	var empty_result: Dictionary = {"error": OK, "files": PackedStringArray()}
	if (
		not is_valid_logical_directory_path_for_framework(directory_name)
		or not is_valid_extension_filter_for_framework(extension_filter)
	):
		empty_result["error"] = ERR_INVALID_PARAMETER
		return empty_result
	var layout_error: Error = ensure_layout_for_framework()
	if layout_error != OK:
		empty_result["error"] = layout_error
		return empty_result
	var descriptors_result: Dictionary = list_claimed_family_descriptors_for_framework()
	var descriptors_error: Error = GFVariantData.get_option_int(
		descriptors_result,
		"error",
		OK
	) as Error
	if descriptors_error != OK:
		empty_result["error"] = descriptors_error
		return empty_result
	var result: PackedStringArray = PackedStringArray()
	for descriptor_value: Variant in GFVariantData.get_option_array(
		descriptors_result,
		"descriptors"
	):
		var descriptor: Dictionary = GFVariantData.as_dictionary(descriptor_value)
		var logical_path: String = GFVariantData.get_option_string(descriptor, "logical_path")
		if not FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path")):
			continue
		if not _matches_list_selector(logical_path, directory_name, recursive, max_scan_depth):
			continue
		if not extension_filter.is_empty() and logical_path.get_extension() != extension_filter:
			continue
		var _appended: bool = result.append(logical_path)
	result.sort()
	if max_file_count > 0 and result.size() > max_file_count:
		var _resized: bool = result.resize(max_file_count)
	return {"error": OK, "files": result}


## 枚举并严格校验 catalog-authoritative family descriptor。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @return Dictionary，包含 error 与按 logical_path 排序的 descriptors。
## [br]
## @schema return: Dictionary，包含 error: Error 和 descriptors: Array[Dictionary]。
func list_claimed_family_descriptors_for_framework() -> Dictionary:
	var empty_result: Dictionary = {"error": OK, "descriptors": []}
	var layout_error: Error = ensure_layout_for_framework()
	if layout_error != OK:
		empty_result["error"] = layout_error
		return empty_result
	var catalog_root: String = _join_storage_root(
		_storage_root_path,
		"%s/v%d/catalog" % [_PRIVATE_ROOT_NAME, _LAYOUT_VERSION]
	)
	var pending_recovery_error: Error = _reconcile_catalog_publish_residue(catalog_root)
	if pending_recovery_error != OK:
		empty_result["error"] = pending_recovery_error
		return empty_result
	var catalog_paths_result: Dictionary = _collect_catalog_paths(catalog_root)
	var collect_error: Error = GFVariantData.get_option_int(
		catalog_paths_result,
		"error",
		OK
	) as Error
	if collect_error != OK:
		empty_result["error"] = collect_error
		return empty_result
	var descriptors: Array[Dictionary] = []
	for catalog_path: String in GFVariantData.get_option_array(catalog_paths_result, "paths"):
		var catalog_result: Dictionary = _read_json_dictionary(catalog_path)
		if not GFVariantData.get_option_bool(catalog_result, "ok"):
			return {"error": ERR_FILE_CORRUPT, "descriptors": []}
		var catalog: Dictionary = GFVariantData.get_option_dictionary(catalog_result, "data")
		var logical_path: String = GFVariantData.get_option_string(catalog, "logical_path")
		var descriptor: Dictionary = make_family_descriptor_for_framework(
			_storage_root_path,
			logical_path
		)
		if (
			descriptor.is_empty()
			or GFVariantData.get_option_string(descriptor, "catalog_path") != catalog_path
			or validate_family_for_framework(descriptor) != OK
		):
			return {"error": ERR_FILE_CORRUPT, "descriptors": []}
		descriptors.append(descriptor)
	descriptors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return (
			GFVariantData.get_option_string(left, "logical_path")
			< GFVariantData.get_option_string(right, "logical_path")
		)
	)
	return {"error": OK, "descriptors": descriptors}


## 判断一个已 claim family 是否有 committed payload。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @param descriptor: family descriptor。
## [br]
## @schema descriptor: Dictionary，必须精确匹配 make_family_descriptor_for_framework() 的固定字段与派生路径。
## [br]
## @return catalog/owner 有效且 payload 存在时返回 true。
func has_file_for_framework(descriptor: Dictionary) -> bool:
	return (
		validate_family_for_framework(descriptor) == OK
		and FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path"))
	)


# --- 私有/辅助方法 ---

static func _is_valid_logical_path(logical_path: String, allow_empty: bool) -> bool:
	if logical_path.is_empty():
		return allow_empty
	if logical_path.length() > _MAX_LOGICAL_PATH_BYTES:
		return false
	var segments: PackedStringArray = logical_path.split("/", true)
	if segments.is_empty() or segments.size() > _MAX_LOGICAL_SEGMENTS:
		return false
	for segment: String in segments:
		if not _is_valid_logical_segment(segment):
			return false
	return true


static func _is_valid_logical_segment(segment: String) -> bool:
	if segment.is_empty() or segment.length() > _MAX_LOGICAL_SEGMENT_BYTES:
		return false
	if not _is_ascii_alnum(segment.substr(0, 1)):
		return false
	if not _is_ascii_alnum(segment.substr(segment.length() - 1, 1)):
		return false
	for index: int in range(segment.length()):
		if not _ALLOWED_SEGMENT_CHARS.contains(segment.substr(index, 1)):
			return false
	var stem: String = segment.get_slice(".", 0)
	return not _RESERVED_DEVICE_STEMS.has(stem)


static func _is_ascii_alnum(character: String) -> bool:
	return character.length() == 1 and _ALNUM_CHARS.contains(character)


static func _is_valid_storage_root(storage_root_path: String) -> bool:
	if storage_root_path == "user://":
		return true
	if not storage_root_path.begins_with("user://"):
		return false
	var relative_root: String = storage_root_path.trim_prefix("user://")
	return is_valid_logical_directory_path_for_framework(relative_root)


static func _make_logical_digest(logical_path: String) -> String:
	var hashing: HashingContext = HashingContext.new()
	var start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var domain_error: Error = hashing.update(_IDENTITY_DOMAIN.to_utf8_buffer())
	if domain_error != OK:
		return ""
	var separator_error: Error = hashing.update(PackedByteArray([0]))
	if separator_error != OK:
		return ""
	var logical_error: Error = hashing.update(logical_path.to_utf8_buffer())
	if logical_error != OK:
		return ""
	return hashing.finish().hex_encode()


static func _derive_physical_extension(logical_path: String) -> String:
	var extension: String = logical_path.get_extension()
	if not is_valid_extension_filter_for_framework(extension):
		return "bin"
	return extension if not extension.is_empty() else "bin"


static func _join_storage_root(storage_root_path: String, relative_path: String) -> String:
	if storage_root_path == "user://":
		return "user://" + relative_path
	return storage_root_path + "/" + relative_path


static func _make_layout_manifest() -> Dictionary:
	return {
		"schema": _LAYOUT_SCHEMA,
		"schema_version": _LAYOUT_VERSION,
		"path_profile": _PATH_PROFILE,
		"identity_algorithm": _IDENTITY_ALGORITHM,
		"private_namespace": _PRIVATE_ROOT_NAME,
	}


static func _is_valid_layout_manifest(manifest: Dictionary) -> bool:
	return _records_match_expected(manifest, _make_layout_manifest())


static func _make_identity_record(schema: String, descriptor: Dictionary) -> Dictionary:
	return {
		"schema": schema,
		"schema_version": _LAYOUT_VERSION,
		"path_profile": _PATH_PROFILE,
		"identity_algorithm": _IDENTITY_ALGORITHM,
		"logical_path": GFVariantData.get_option_string(descriptor, "logical_path"),
		"logical_sha256": GFVariantData.get_option_string(descriptor, "logical_sha256"),
		"family_id": GFVariantData.get_option_string(descriptor, "family_id"),
		"payload_leaf": GFVariantData.get_option_string(descriptor, "payload_path").get_file(),
	}


static func _matches_identity_record(record: Dictionary, schema: String, descriptor: Dictionary) -> bool:
	return _records_match_expected(record, _make_identity_record(schema, descriptor))


static func _records_match_expected(record: Dictionary, expected: Dictionary) -> bool:
	if record.size() != expected.size():
		return false
	for key: Variant in expected.keys():
		if not record.has(key):
			return false
		var expected_value: Variant = expected[key]
		var actual_value: Variant = record[key]
		if expected_value is int:
			if GFVariantData.to_exact_int(actual_value, -1) != expected_value:
				return false
		elif typeof(actual_value) != typeof(expected_value) or actual_value != expected_value:
			return false
	return true


func _validate_descriptor(descriptor: Dictionary) -> Error:
	if _storage_root_path.is_empty():
		return ERR_INVALID_PARAMETER
	var logical_path: String = GFVariantData.get_option_string(descriptor, "logical_path")
	var expected: Dictionary = make_family_descriptor_for_framework(_storage_root_path, logical_path)
	if expected.is_empty() or descriptor != expected:
		return ERR_INVALID_PARAMETER
	return OK


func _validate_owner_only_claim(descriptor: Dictionary) -> Error:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
	if not FileAccess.file_exists(owner_path):
		return ERR_FILE_CORRUPT
	var entries: Dictionary = _read_directory_entries(family_path)
	if GFVariantData.get_option_int(entries, "error", OK) != OK:
		return GFVariantData.get_option_int(entries, "error", ERR_FILE_CANT_READ) as Error
	var names: Array = GFVariantData.get_option_array(entries, "names")
	if names != ["owner.json"]:
		return ERR_FILE_CORRUPT
	var owner_result: Dictionary = _read_json_dictionary(owner_path)
	if not GFVariantData.get_option_bool(owner_result, "ok"):
		return ERR_FILE_CORRUPT
	if not _matches_identity_record(
		GFVariantData.get_option_dictionary(owner_result, "data"),
		_OWNER_SCHEMA,
		descriptor
	):
		return ERR_FILE_CORRUPT
	return OK


func _reconcile_claim_staging(descriptor: Dictionary) -> Error:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var family_parent: String = family_path.get_base_dir()
	var entries: Dictionary = _read_directory_entries(family_parent)
	var entries_error: Error = GFVariantData.get_option_int(entries, "error", OK) as Error
	if entries_error != OK:
		return entries_error
	var prefix: String = family_path.get_file() + _CLAIM_STAGING_SEPARATOR
	var staging_paths: Array[String] = []
	for entry: String in GFVariantData.get_option_array(entries, "names"):
		if not entry.begins_with(prefix):
			continue
		var claim_id: String = entry.trim_prefix(prefix)
		if not GFUuid.is_valid(claim_id, 4):
			return ERR_FILE_CORRUPT
		var staging_path: String = family_parent.path_join(entry)
		if not DirAccess.dir_exists_absolute(staging_path):
			return ERR_FILE_CORRUPT
		var staging_error: Error = _validate_claim_staging(descriptor, staging_path)
		if staging_error != OK:
			return staging_error
		staging_paths.append(staging_path)
	staging_paths.sort()
	if not DirAccess.dir_exists_absolute(family_path) and not staging_paths.is_empty():
		var promoted_path: String = staging_paths[0]
		var promote_error: Error = DirAccess.rename_absolute(promoted_path, family_path)
		if promote_error != OK and not DirAccess.dir_exists_absolute(family_path):
			return promote_error
	for staging_path: String in staging_paths:
		if DirAccess.dir_exists_absolute(staging_path):
			var cleanup_error: Error = _remove_claim_staging(staging_path)
			if cleanup_error != OK:
				return cleanup_error
	return OK


func _validate_claim_staging(descriptor: Dictionary, staging_path: String) -> Error:
	var entries: Dictionary = _read_directory_entries(staging_path)
	var entries_error: Error = GFVariantData.get_option_int(entries, "error", OK) as Error
	if entries_error != OK:
		return entries_error
	if GFVariantData.get_option_array(entries, "names") != ["owner.json"]:
		return ERR_FILE_CORRUPT
	var owner_result: Dictionary = _read_json_dictionary(staging_path.path_join("owner.json"))
	if not GFVariantData.get_option_bool(owner_result, "ok"):
		return ERR_FILE_CORRUPT
	return OK if _matches_identity_record(
		GFVariantData.get_option_dictionary(owner_result, "data"),
		_OWNER_SCHEMA,
		descriptor
	) else ERR_FILE_CORRUPT


func _validate_family_entries(descriptor: Dictionary) -> Error:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var entries: Dictionary = _read_directory_entries(family_path)
	var entries_error: Error = GFVariantData.get_option_int(entries, "error", OK) as Error
	if entries_error != OK:
		return entries_error
	var allowed: Dictionary = {
		"owner.json": true,
		GFVariantData.get_option_string(descriptor, "payload_path").get_file(): true,
		GFVariantData.get_option_string(descriptor, "candidate_path").get_file(): true,
		GFVariantData.get_option_string(descriptor, "backup_path").get_file(): true,
		"transaction.prepare.json": true,
		"transaction.prepare.pending.json": true,
		"transaction.commit.json": true,
		"transaction.commit.pending.json": true,
		GFVariantData.get_option_string(descriptor, "resource_stage_path").get_file(): true,
	}
	for entry: String in GFVariantData.get_option_array(entries, "names"):
		if not allowed.has(entry):
			return ERR_FILE_CORRUPT
		if DirAccess.dir_exists_absolute(family_path.path_join(entry)):
			return ERR_FILE_CORRUPT
	return OK


func _collect_catalog_paths(catalog_root: String) -> Dictionary:
	var result: Array[String] = []
	var first_level: Dictionary = _read_directory_entries(catalog_root)
	var first_error: Error = GFVariantData.get_option_int(first_level, "error", OK) as Error
	if first_error != OK:
		return {"error": first_error, "paths": result}
	for first_shard: String in GFVariantData.get_option_array(first_level, "names"):
		if not _is_hex_shard(first_shard):
			return {"error": ERR_FILE_CORRUPT, "paths": []}
		var first_path: String = catalog_root.path_join(first_shard)
		if not DirAccess.dir_exists_absolute(first_path):
			return {"error": ERR_FILE_CORRUPT, "paths": []}
		var second_level: Dictionary = _read_directory_entries(first_path)
		var second_error: Error = GFVariantData.get_option_int(second_level, "error", OK) as Error
		if second_error != OK:
			return {"error": second_error, "paths": []}
		for second_shard: String in GFVariantData.get_option_array(second_level, "names"):
			if not _is_hex_shard(second_shard):
				return {"error": ERR_FILE_CORRUPT, "paths": []}
			var second_path: String = first_path.path_join(second_shard)
			if not DirAccess.dir_exists_absolute(second_path):
				return {"error": ERR_FILE_CORRUPT, "paths": []}
			var leaf_entries: Dictionary = _read_directory_entries(second_path)
			var leaf_error: Error = GFVariantData.get_option_int(leaf_entries, "error", OK) as Error
			if leaf_error != OK:
				return {"error": leaf_error, "paths": []}
			for leaf_name: String in GFVariantData.get_option_array(leaf_entries, "names"):
				if not _is_catalog_leaf(leaf_name, first_shard, second_shard):
					return {"error": ERR_FILE_CORRUPT, "paths": []}
				if DirAccess.dir_exists_absolute(second_path.path_join(leaf_name)):
					return {"error": ERR_FILE_CORRUPT, "paths": []}
				result.append(second_path.path_join(leaf_name))
	result.sort()
	return {"error": OK, "paths": result}


func _reconcile_catalog_publish_residue(catalog_root: String) -> Error:
	var pending_targets: Dictionary = {}
	var first_level: Dictionary = _read_directory_entries(catalog_root)
	var first_error: Error = GFVariantData.get_option_int(first_level, "error", OK) as Error
	if first_error != OK:
		return first_error
	for first_shard: String in GFVariantData.get_option_array(first_level, "names"):
		if not _is_hex_shard(first_shard):
			return ERR_FILE_CORRUPT
		var first_path: String = catalog_root.path_join(first_shard)
		if not DirAccess.dir_exists_absolute(first_path):
			return ERR_FILE_CORRUPT
		var second_level: Dictionary = _read_directory_entries(first_path)
		var second_error: Error = GFVariantData.get_option_int(
			second_level,
			"error",
			OK
		) as Error
		if second_error != OK:
			return second_error
		for second_shard: String in GFVariantData.get_option_array(second_level, "names"):
			if not _is_hex_shard(second_shard):
				return ERR_FILE_CORRUPT
			var second_path: String = first_path.path_join(second_shard)
			if not DirAccess.dir_exists_absolute(second_path):
				return ERR_FILE_CORRUPT
			var leaf_entries: Dictionary = _read_directory_entries(second_path)
			var leaf_error: Error = GFVariantData.get_option_int(
				leaf_entries,
				"error",
				OK
			) as Error
			if leaf_error != OK:
				return leaf_error
			for leaf_name: String in GFVariantData.get_option_array(leaf_entries, "names"):
				if _is_catalog_leaf(leaf_name, first_shard, second_shard):
					continue
				var separator_index: int = leaf_name.find(_PUBLISH_PENDING_SEPARATOR)
				if separator_index <= 0:
					return ERR_FILE_CORRUPT
				var target_leaf: String = leaf_name.substr(0, separator_index)
				if (
					not _is_catalog_leaf(target_leaf, first_shard, second_shard)
					or not _is_publish_pending_leaf(leaf_name, target_leaf)
				):
					return ERR_FILE_CORRUPT
				var pending_path: String = second_path.path_join(leaf_name)
				if DirAccess.dir_exists_absolute(pending_path):
					return ERR_FILE_CORRUPT
				var pending_result: Dictionary = _read_json_dictionary(pending_path)
				if not GFVariantData.get_option_bool(pending_result, "ok"):
					return ERR_FILE_CORRUPT
				var pending_record: Dictionary = GFVariantData.get_option_dictionary(
					pending_result,
					"data"
				)
				var logical_path: String = GFVariantData.get_option_string(
					pending_record,
					"logical_path"
				)
				var descriptor: Dictionary = make_family_descriptor_for_framework(
					_storage_root_path,
					logical_path
				)
				var target_path: String = second_path.path_join(target_leaf)
				var expected: Dictionary = _make_identity_record(_CATALOG_SCHEMA, descriptor)
				if (
					descriptor.is_empty()
					or GFVariantData.get_option_string(descriptor, "catalog_path") != target_path
					or not _records_match_expected(pending_record, expected)
				):
					return ERR_FILE_CORRUPT
				pending_targets[target_path] = expected
	var target_paths: Array[String] = []
	for target_path_value: Variant in pending_targets.keys():
		target_paths.append(GFVariantData.to_text(target_path_value))
	target_paths.sort()
	for target_path: String in target_paths:
		var publish_error: Error = _publish_json_if_absent(
			target_path,
			GFVariantData.get_option_dictionary(pending_targets, target_path)
		)
		if publish_error != OK:
			return publish_error
	return OK


static func _is_hex_shard(value: String) -> bool:
	if value.length() != 2:
		return false
	return _HEX_CHARS.contains(value.substr(0, 1)) and _HEX_CHARS.contains(value.substr(1, 1))


static func _is_catalog_leaf(leaf_name: String, first_shard: String, second_shard: String) -> bool:
	if not leaf_name.ends_with(".json"):
		return false
	var digest: String = leaf_name.trim_suffix(".json")
	if digest.length() != 64 or not digest.begins_with(first_shard + second_shard):
		return false
	for index: int in range(digest.length()):
		if not _HEX_CHARS.contains(digest.substr(index, 1)):
			return false
	return true


static func _is_publish_pending_leaf(leaf_name: String, target_leaf: String) -> bool:
	var prefix: String = target_leaf + _PUBLISH_PENDING_SEPARATOR
	if not leaf_name.begins_with(prefix):
		return false
	return GFUuid.is_valid(leaf_name.trim_prefix(prefix), 4)


static func _matches_list_selector(
	logical_path: String,
	directory_name: String,
	recursive: bool,
	max_scan_depth: int
) -> bool:
	var remainder: String = logical_path
	if not directory_name.is_empty():
		var prefix: String = directory_name + "/"
		if not logical_path.begins_with(prefix):
			return false
		remainder = logical_path.trim_prefix(prefix)
	var directory_depth: int = maxi(remainder.get_slice_count("/") - 1, 0)
	if not recursive and directory_depth > 0:
		return false
	return max_scan_depth <= 0 or directory_depth <= max_scan_depth


func _publish_json_if_absent(path: String, data: Dictionary) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var parent_error: Error = _ensure_directory(path.get_base_dir())
	if parent_error != OK:
		return parent_error
	var pending_recovery_error: Error = _reconcile_publish_pending_files(path, data)
	if pending_recovery_error != OK:
		return pending_recovery_error
	if FileAccess.file_exists(path):
		var existing: Dictionary = _read_json_dictionary(path)
		if not GFVariantData.get_option_bool(existing, "ok"):
			return ERR_FILE_CORRUPT
		return OK if _records_match_expected(
			GFVariantData.get_option_dictionary(existing, "data"),
			data
		) else ERR_FILE_CORRUPT
	var pending_path: String = path + _PUBLISH_PENDING_SEPARATOR + GFUuid.generate_v4()
	var write_error: Error = _write_json_direct(pending_path, data)
	if write_error != OK:
		return write_error
	var pending_result: Dictionary = _read_json_dictionary(pending_path)
	if (
		not GFVariantData.get_option_bool(pending_result, "ok")
		or not _records_match_expected(
			GFVariantData.get_option_dictionary(pending_result, "data"),
			data
		)
	):
		var _invalid_pending_cleanup: Error = _remove_file_if_exists(pending_path)
		return ERR_FILE_CORRUPT
	var publish_error: Error = DirAccess.rename_absolute(pending_path, path)
	if publish_error != OK:
		var _pending_cleanup_after_race: Error = _remove_file_if_exists(pending_path)
		if not FileAccess.file_exists(path):
			return publish_error
		var raced: Dictionary = _read_json_dictionary(path)
		if (
			not GFVariantData.get_option_bool(raced, "ok")
			or not _records_match_expected(
				GFVariantData.get_option_dictionary(raced, "data"),
				data
			)
		):
			return ERR_FILE_CORRUPT
	return OK


func _reconcile_publish_pending_files(path: String, expected: Dictionary) -> Error:
	var parent_path: String = path.get_base_dir()
	var entries: Dictionary = _read_directory_entries(parent_path)
	var entries_error: Error = GFVariantData.get_option_int(entries, "error", OK) as Error
	if entries_error != OK:
		return entries_error
	var target_leaf: String = path.get_file()
	var prefix: String = target_leaf + _PUBLISH_PENDING_SEPARATOR
	var pending_paths: Array[String] = []
	for entry: String in GFVariantData.get_option_array(entries, "names"):
		if not entry.begins_with(prefix):
			continue
		if not _is_publish_pending_leaf(entry, target_leaf):
			return ERR_FILE_CORRUPT
		var pending_path: String = parent_path.path_join(entry)
		if DirAccess.dir_exists_absolute(pending_path):
			return ERR_FILE_CORRUPT
		var pending_result: Dictionary = _read_json_dictionary(pending_path)
		if (
			not GFVariantData.get_option_bool(pending_result, "ok")
			or not _records_match_expected(
				GFVariantData.get_option_dictionary(pending_result, "data"),
				expected
			)
		):
			return ERR_FILE_CORRUPT
		pending_paths.append(pending_path)
	pending_paths.sort()
	if FileAccess.file_exists(path):
		var existing: Dictionary = _read_json_dictionary(path)
		if (
			not GFVariantData.get_option_bool(existing, "ok")
			or not _records_match_expected(
				GFVariantData.get_option_dictionary(existing, "data"),
				expected
			)
		):
			return ERR_FILE_CORRUPT
		for pending_path: String in pending_paths:
			var cleanup_error: Error = _remove_file_if_exists(pending_path)
			if cleanup_error != OK:
				return cleanup_error
		return OK
	if pending_paths.is_empty():
		return OK
	var promoted_path: String = pending_paths[0]
	var promote_error: Error = DirAccess.rename_absolute(promoted_path, path)
	if promote_error != OK and not FileAccess.file_exists(path):
		return promote_error
	var published: Dictionary = _read_json_dictionary(path)
	if (
		not GFVariantData.get_option_bool(published, "ok")
		or not _records_match_expected(
			GFVariantData.get_option_dictionary(published, "data"),
			expected
		)
	):
		return ERR_FILE_CORRUPT
	for pending_path: String in pending_paths:
		if pending_path == promoted_path:
			continue
		var cleanup_error: Error = _remove_file_if_exists(pending_path)
		if cleanup_error != OK:
			return cleanup_error
	return OK


static func _write_json_direct(path: String, data: Dictionary) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_string(JSON.stringify(data, "\t")) != null
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error


static func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": ERR_FILE_NOT_FOUND, "data": {}}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": FileAccess.get_open_error(), "data": {}}
	var length: int = file.get_length()
	if length <= 0 or length > _MAX_MANIFEST_BYTES:
		file.close()
		return {"ok": false, "error": ERR_FILE_CORRUPT, "data": {}}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return {"ok": false, "error": read_error, "data": {}}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": ERR_FILE_CORRUPT, "data": {}}
	var data: Dictionary = parsed
	return {"ok": true, "error": OK, "data": data}


static func _ensure_directory(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)


static func _remove_file_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


static func _remove_claim_staging(staging_path: String) -> Error:
	var owner_error: Error = _remove_file_if_exists(staging_path.path_join("owner.json"))
	if owner_error != OK:
		return owner_error
	if not DirAccess.dir_exists_absolute(staging_path):
		return OK
	return DirAccess.remove_absolute(staging_path)


static func _read_directory_entries(path: String) -> Dictionary:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return {"error": ERR_FILE_CANT_OPEN, "names": []}
	var begin_error: Error = dir.list_dir_begin()
	if begin_error != OK:
		return {"error": begin_error, "names": []}
	var names: Array[String] = []
	var entry: String = dir.get_next()
	while not entry.is_empty():
		names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return {"error": OK, "names": names}
