@tool

## GF Package 文件系统 Artifact Store。
##
## 该内部实现只保存经过完整 SHA-256 与大小验证的不可变对象。工作目录由 cache policy
## 固定在项目 .gf 下，从而为未来替换其他 store provider 保留稳定的内部调用边界。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/package
class_name GFPackageFilesystemCacheStore
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PACKAGE_CACHE_POLICY = preload("res://addons/gf/kernel/package/gf_package_cache_policy.gd")
const _COPY_CHUNK_BYTES: int = 1024 * 1024


# --- 公共方法 ---

## 在当前上下文的只读根列表中查找并验证不可变 artifact。
## [br]
## @api framework_internal
## [br]
## @param context: GFPackageCachePolicy 解析出的上下文。
## [br]
## @schema context: Dictionary，包含 artifact_read_roots。
## [br]
## @param expected_sha: 完整 SHA-256 十六进制文本。
## [br]
## @param expected_size: 预期字节数。
## [br]
## @param suffix: 文件格式后缀，只影响本地布局，不参与信任判断。
## [br]
## @return 命中且校验成功的 artifact 绝对路径，否则为空字符串。
static func find_artifact(context: Dictionary, expected_sha: String, expected_size: int, suffix: String) -> String:
	var normalized_sha: String = expected_sha.strip_edges().to_lower()
	if not _is_sha256(normalized_sha) or expected_size <= 0 or not _is_safe_suffix(suffix):
		return ""
	var read_roots: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(context, "artifact_read_roots")
	for read_root: String in read_roots:
		var candidate: String = artifact_path(read_root, normalized_sha, suffix)
		if _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, candidate) and _artifact_matches(candidate, normalized_sha, expected_size):
			return candidate
	return ""


## 把已校验源文件提交为不可变 artifact。
## [br]
## @api framework_internal
## [br]
## @param context: GFPackageCachePolicy 解析出的上下文。
## [br]
## @schema context: Dictionary，包含 artifact_write_root。
## [br]
## @param source_path: 已下载或生成的源文件。
## [br]
## @param expected_sha: 完整 SHA-256 十六进制文本。
## [br]
## @param expected_size: 预期字节数。
## [br]
## @param suffix: 文件格式后缀。
## [br]
## @param issues: 接收校验与提交错误。
## [br]
## @return 提交或并发命中的 artifact 绝对路径，否则为空字符串。
static func commit_artifact(
	context: Dictionary,
	source_path: String,
	expected_sha: String,
	expected_size: int,
	suffix: String,
	issues: PackedStringArray
) -> String:
	var normalized_sha: String = expected_sha.strip_edges().to_lower()
	if not _is_sha256(normalized_sha) or expected_size <= 0:
		var _append_metadata: bool = issues.append("Package cache artifact requires a full sha256 and positive size.")
		return ""
	if not _is_safe_suffix(suffix):
		var _append_suffix: bool = issues.append("Package cache artifact suffix is unsafe: %s" % suffix)
		return ""
	if not _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, source_path) or not _artifact_matches(source_path, normalized_sha, expected_size):
		var _append_source: bool = issues.append("Package cache artifact source does not match expected sha256 and size: %s" % source_path)
		return ""
	var write_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "artifact_write_root")
	if write_root.is_empty():
		var _append_root: bool = issues.append("Package cache context does not permit artifact writes.")
		return ""
	if not _GF_PACKAGE_CACHE_POLICY.ensure_write_root(context, issues):
		return ""
	var target_path: String = artifact_path(write_root, normalized_sha, suffix)
	if not _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, target_path):
		var _append_target: bool = issues.append("Package cache artifact target leaves its context boundary or crosses a filesystem link: %s" % target_path)
		return ""
	if _artifact_matches(target_path, normalized_sha, expected_size):
		return target_path
	var make_error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create package artifact directory: %s" % error_string(make_error))
		return ""
	var temp_path: String = target_path + ".tmp-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if (
		not _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, target_path)
		or not _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, temp_path)
	):
		var _append_changed_target: bool = issues.append("Package cache artifact path became unsafe: %s" % target_path)
		return ""
	if not _copy_file(source_path, temp_path, issues):
		return ""
	if not _artifact_matches(temp_path, normalized_sha, expected_size):
		var _remove_invalid: Error = DirAccess.remove_absolute(temp_path)
		var _append_copy: bool = issues.append("Copied package cache artifact failed integrity verification.")
		return ""
	if (
		not _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, target_path)
		or not _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, temp_path)
	):
		var _append_unsafe: bool = issues.append("Package cache artifact path became unsafe before publish: %s" % target_path)
		return ""
	if FileAccess.file_exists(target_path):
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK and not _artifact_matches(target_path, normalized_sha, expected_size):
			var _remove_temp: Error = DirAccess.remove_absolute(temp_path)
			var _append_replace: bool = issues.append("Could not replace invalid package cache artifact: %s" % error_string(remove_error))
			return ""
	var rename_error: Error = DirAccess.rename_absolute(temp_path, target_path)
	if rename_error != OK:
		if _artifact_matches(target_path, normalized_sha, expected_size):
			var _remove_raced_temp: Error = DirAccess.remove_absolute(temp_path)
			return target_path
		var _remove_failed_temp: Error = DirAccess.remove_absolute(temp_path)
		var _append_rename: bool = issues.append("Could not finalize package cache artifact: %s" % error_string(rename_error))
		return ""
	return target_path


## 计算内容寻址 artifact 的稳定路径。
## [br]
## @api framework_internal
## [br]
## @param cache_root: 已通过 policy 验证的 artifact 根目录。
## [br]
## @param expected_sha: 完整 SHA-256 十六进制文本。
## [br]
## @param suffix: 文件格式后缀。
## [br]
## @return objects/sha256 两级布局中的绝对路径。
static func artifact_path(cache_root: String, expected_sha: String, suffix: String) -> String:
	var normalized_sha: String = expected_sha.strip_edges().to_lower()
	return cache_root.path_join("objects/sha256").path_join(normalized_sha.substr(0, 2)).path_join(normalized_sha + suffix).replace("\\", "/")


## 为本次项目创建唯一 workspace 文件路径。
## [br]
## @api framework_internal
## [br]
## @param context: GFPackageCachePolicy 解析出的上下文。
## [br]
## @schema context: Dictionary，包含 workspace_root。
## [br]
## @param category: 固定内部类别名。
## [br]
## @param suffix: 文件格式后缀。
## [br]
## @return 位于项目 package workspace 内的唯一绝对路径。
static func make_workspace_temp_path(context: Dictionary, category: String, suffix: String) -> String:
	var workspace_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "workspace_root")
	var safe_category: String = _safe_segment(category)
	var safe_suffix: String = suffix if _is_safe_suffix(suffix) else ""
	var result: String = workspace_root.path_join(safe_category).path_join("%d-%d%s" % [OS.get_process_id(), Time.get_ticks_usec(), safe_suffix]).replace("\\", "/")
	return result if _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, result) else ""


## 计算项目 workspace 中的稳定派生文件路径。
## [br]
## @api framework_internal
## [br]
## @param context: GFPackageCachePolicy 解析出的上下文。
## [br]
## @schema context: Dictionary，包含 workspace_root。
## [br]
## @param category: 固定内部类别名。
## [br]
## @param key: 已由 URL 或内容哈希生成的稳定 key。
## [br]
## @param suffix: 文件格式后缀。
## [br]
## @return 位于项目 package workspace 内的稳定绝对路径。
static func workspace_path(context: Dictionary, category: String, key: String, suffix: String) -> String:
	var workspace_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "workspace_root")
	var safe_suffix: String = suffix if _is_safe_suffix(suffix) else ""
	var result: String = workspace_root.path_join(_safe_segment(category)).path_join(_safe_segment(key) + safe_suffix).replace("\\", "/")
	return result if _GF_PACKAGE_CACHE_POLICY._context_path_is_safe(context, result) else ""


# --- 私有/辅助方法 ---

static func _artifact_matches(path: String, expected_sha: String, expected_size: int) -> bool:
	if _GF_PACKAGE_CACHE_POLICY._path_has_link_component(path) or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var actual_size: int = file.get_length()
	file.close()
	if actual_size != expected_size:
		return false
	return FileAccess.get_sha256(path).to_lower() == expected_sha


static func _copy_file(source_path: String, target_path: String, issues: PackedStringArray) -> bool:
	if _GF_PACKAGE_CACHE_POLICY._path_has_link_component(source_path) or _GF_PACKAGE_CACHE_POLICY._path_has_link_component(target_path):
		var _append_link: bool = issues.append("Package cache copy path crosses a filesystem link.")
		return false
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		var _append_source: bool = issues.append("Could not read package cache artifact source: %s" % error_string(FileAccess.get_open_error()))
		return false
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		source_file.close()
		var _append_target: bool = issues.append("Could not write package cache artifact: %s" % error_string(FileAccess.get_open_error()))
		return false
	while source_file.get_position() < source_file.get_length():
		var chunk_size: int = mini(_COPY_CHUNK_BYTES, source_file.get_length() - source_file.get_position())
		var chunk: PackedByteArray = source_file.get_buffer(chunk_size)
		if source_file.get_error() != OK:
			var read_error: Error = source_file.get_error()
			source_file.close()
			target_file.close()
			var _remove_partial: Error = DirAccess.remove_absolute(target_path)
			var _append_read: bool = issues.append("Could not read package cache artifact: %s" % error_string(read_error))
			return false
		var _store_result: Variant = target_file.store_buffer(chunk)
		if target_file.get_error() != OK:
			var write_error: Error = target_file.get_error()
			source_file.close()
			target_file.close()
			var _remove_write_partial: Error = DirAccess.remove_absolute(target_path)
			var _append_write: bool = issues.append("Could not write package cache artifact: %s" % error_string(write_error))
			return false
	source_file.close()
	target_file.close()
	return true


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if "0123456789abcdef".find(character) < 0:
			return false
	return true


static func _is_safe_suffix(value: String) -> bool:
	if value.is_empty():
		return true
	if not value.begins_with(".") or value.contains("/") or value.contains("\\") or value.contains(":"):
		return false
	return value.length() <= 16


static func _safe_segment(value: String) -> String:
	var result: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		var code: int = character.unicode_at(0)
		if (
			(code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or character == "-"
			or character == "_"
		):
			result += character
		else:
			result += "-"
	return result.strip_edges(false, true) if not result.is_empty() else "item"
