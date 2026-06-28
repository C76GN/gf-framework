@tool

# GFPackageManagerBackend: 内核包管理器的 Godot 原生状态后端。
#
# 这个脚本只依赖 Godot 内置 JSON / FileAccess / DirAccess 能力，用于逐步替代用户侧
# 对 Python 包工具的硬依赖。安装事务和联网下载仍由后续阶段补齐。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## GF 包 archive 允许写入的根路径前缀。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const GF_PACKAGE_ROOT_PREFIX: String = "addons/" + "gf/"

## registry index schema 版本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const REGISTRY_SCHEMA_VERSION: int = 2

## lockfile schema 版本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const LOCKFILE_SCHEMA_VERSION: int = 1

## 允许记录到 lockfile 的安装原因。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const VALID_REASONS: Array[String] = ["bundled", "dev", "manual", "preset"]

## 阻止普通卸载的安装原因。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const PROTECTED_REASONS: Array[String] = ["bundled", "dev", "preset"]

## 卸载引用扫描会检查的项目文件扩展名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const PROJECT_SCAN_EXTENSIONS: Array[String] = [".cfg", ".gd", ".godot", ".json", ".tres", ".tscn"]

## 卸载引用扫描会跳过的项目目录前缀。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const PROJECT_SCAN_EXCLUDED_PREFIXES: Array[String] = [
	".git/",
	".gf/",
	".godot/",
	".import/",
	GF_PACKAGE_ROOT_PREFIX,
	"addons/gut/",
	"ai_analysis/",
	"build/",
]

## 包 archive 中禁止出现的目录名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const BLOCKED_DIR_NAMES: Array[String] = [".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"]

## 包 archive 中禁止出现的文件名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const BLOCKED_FILE_NAMES: Array[String] = [".DS_Store", "Thumbs.db"]

## 包 archive 中禁止出现的文件后缀。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const BLOCKED_SUFFIXES: Array[String] = [".import", ".pyc", ".pyo", ".tmp", ".log"]

## 单个 registry JSON 下载最大字节数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_REGISTRY_DOWNLOAD_BYTES: int = 16 * 1024 * 1024

## 单个 package archive 下载最大字节数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_DOWNLOAD_BYTES: int = 1024 * 1024 * 1024

## 单个 package archive 允许的最多文件条目数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_ENTRY_COUNT: int = 20000

## 单个 package archive entry 允许的最大解压后字节数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES: int = 64 * 1024 * 1024

## 单个 package archive 允许的最大解压后总字节数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES: int = 512 * 1024 * 1024

## 单个 package archive entry 允许的最大压缩比。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_COMPRESSION_RATIO: int = 100

## 单个 package archive entry 路径允许的最大字符数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_ENTRY_PATH_LENGTH: int = 512

## 单个 package archive entry 路径允许的最大目录深度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MAX_ARCHIVE_ENTRY_PATH_DEPTH: int = 32

## 文件复制使用的固定块大小。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const FILE_COPY_CHUNK_BYTES: int = 1024 * 1024

## HTTP 建连超时时间（毫秒）。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const HTTP_CONNECT_TIMEOUT_MSEC: int = 30000

## HTTP 响应读取超时时间（毫秒）。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const HTTP_READ_TIMEOUT_MSEC: int = 30000

## HTTP 下载最多跟随的重定向次数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const HTTP_MAX_REDIRECTS: int = 5

## HTTP 下载遇到临时失败响应后的最多重试次数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const HTTP_RETRY_ATTEMPTS: int = 2

## HTTP 下载重试基础退避时间（毫秒）。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const HTTP_RETRY_DELAY_MSEC: int = 150

## 默认按当前 GF 版本固定的 release registry source URL 模板。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const DEFAULT_REGISTRY_SOURCE_RELEASE_URL_TEMPLATE: String = "https://github.com/C76GN/gf-framework/releases/download/%s/gf-registry-source.json"

## 开发版无法解析 SemVer 时使用的 release registry source URL。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const DEFAULT_REGISTRY_SOURCE_LATEST_URL: String = "https://github.com/C76GN/gf-framework/releases/latest/download/gf-registry-source.json"

## 覆盖默认 release registry source URL 的环境变量。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const DEFAULT_REGISTRY_SOURCE_ENV: String = "GF_PACKAGE_DEFAULT_REGISTRY_SOURCE"

## Godot 原生验签实现前必须拒绝的 registry source 签名字段。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS: Array[String] = [
	"registry_signature",
	"registry_signature_algorithm",
	"registry_signature_sha256",
	"registry_signature_size_bytes",
	"registry_signature_url",
	"registry_signing_key_id",
	"signature",
	"signature_algorithm",
	"signature_sha256",
	"signature_url",
	"signing_key_id",
]

# Godot 原生验签实现前必须拒绝的 registry package 签名字段。
const _UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS: Array[String] = [
	"public_key",
	"public_keys",
	"registry_signature",
	"registry_signature_algorithm",
	"registry_signature_sha256",
	"registry_signature_size_bytes",
	"registry_signature_url",
	"registry_signing_key_id",
	"signature",
	"signature_algorithm",
	"signature_public_key",
	"signature_sha256",
	"signature_url",
	"signing_key",
	"signing_key_id",
	"signing_keys",
]

# status / uninstall preview 内部复用的项目引用扫描缓存键。
const _PROJECT_REFERENCE_SCAN_CACHE_KEY: String = "_gf_project_reference_scan_cache"

# 远程 registry cache sidecar 文件后缀，记录 source manifest 校验过的 raw 元数据。
const _REMOTE_REGISTRY_CACHE_METADATA_SUFFIX: String = ".metadata.json"

# 非 tool 运行时包不能夹带会暗示外部安装器的工具载荷。
const _RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_SUFFIXES: Array[String] = [
	".bash",
	".bat",
	".cmd",
	".ps1",
	".py",
	".pyw",
	".sh",
	".zsh",
]
const _RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_FILES: Array[String] = [
	"npm-shrinkwrap.json",
	"package-lock.json",
	"package.json",
	"pipfile",
	"pipfile.lock",
	"pnpm-lock.yaml",
	"poetry.lock",
	"pyproject.toml",
	"requirements.txt",
	"yarn.lock",
]
const _OFFLINE_BUNDLE_REGISTRY_ENTRY: String = "registry/index.json"
const _OFFLINE_BUNDLE_REGISTRY_PREFIX: String = "registry/"
const _OFFLINE_BUNDLE_PACKAGE_PREFIX: String = "packages/"
const _OFFLINE_BUNDLE_JSON_SUFFIX: String = ".json"
const _OFFLINE_BUNDLE_ARCHIVE_SUFFIX: String = ".zip"
const _PACKAGE_OPERATION_CANCELLED_ISSUE: String = "Package manager operation was cancelled."


# --- 公共方法 ---

## 返回用户侧默认 registry source URL。
## [br]
## @api framework_internal
## [br]
## @return 默认 registry source URL，环境变量存在时返回环境变量值。
static func get_default_registry_source_url() -> String:
	var environment_value: String = OS.get_environment(DEFAULT_REGISTRY_SOURCE_ENV).strip_edges()
	if not environment_value.is_empty():
		return environment_value
	var framework_version: String = _read_project_framework_version(_resolve_project_root("res://"))
	if not _parse_semver(framework_version).is_empty():
		return DEFAULT_REGISTRY_SOURCE_RELEASE_URL_TEMPLATE % framework_version
	return DEFAULT_REGISTRY_SOURCE_LATEST_URL


## 读取 registry 与项目 lockfile，并返回编辑器包管理器状态。
## [br]
## @api framework_internal
## [br]
## @param registry_path: registry index.json 路径，支持绝对路径、相对项目路径、res:// 路径和 HTTP(S) URL。
## [br]
## @schema registry_path: String，本地 JSON 文件路径或 HTTP(S) registry URL。
## [br]
## @param project_root: 目标 Godot 项目根目录。
## [br]
## @schema project_root: String，绝对路径或 res:// 项目路径。
## [br]
## @param lockfile_path: lockfile 路径，非绝对路径时相对 project_root。
## [br]
## @schema lockfile_path: String，默认 .gf/packages.lock.json。
## [br]
## @param options: 内部包管理参数。
## [br]
## @schema options: Dictionary，可包含 cache_dir、channel、cancel_callback。
## [br]
## @return 与 Python status 命令兼容的状态 Dictionary。
## [br]
## @schema return: 包状态 JSON，包含 packages、install_preview、uninstall_preview、issues 等字段。
static func make_status(
	registry_path: String,
	project_root: String,
	lockfile_path: String = ".gf/packages.lock.json",
	options: Dictionary = {}
) -> Dictionary:
	var resolved_project_root: String = _resolve_project_root(project_root)
	var resolved_lockfile_path: String = _resolve_lockfile_path(resolved_project_root, lockfile_path)
	var issues: PackedStringArray = PackedStringArray()
	_append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	if _append_cancelled_if_requested(options, issues):
		return _make_status_result(
			false,
			registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			false,
			[],
			PackedStringArray(),
			{ "ok": false, "issues": _packed_to_array(issues) },
			issues
		)
	var registry_source: Dictionary = {}
	if issues.is_empty():
		registry_source = _prepare_registry_source(registry_path, resolved_project_root, options, issues)
	var resolved_registry_path: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "path", registry_path)
	var registry_remote: bool = _GF_VARIANT_ACCESS.get_option_bool(registry_source, "remote")
	if not issues.is_empty():
		return _make_status_result(
			false,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			registry_remote,
			[],
			PackedStringArray(),
			{ "ok": false, "issues": _packed_to_array(issues) },
			issues,
			registry_source
		)

	var registry: Dictionary = _load_registry(resolved_registry_path)
	var lockfile: Dictionary = _load_lockfile(resolved_lockfile_path)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(registry, "issues"))
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(lockfile, "issues"))

	var registry_packages: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var lockfile_data: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "data")
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile_data, "installed")
	var current_framework_version: String = _read_project_framework_version(resolved_project_root)
	_append_string_array(
		issues,
		_framework_compatibility_issues(
			registry,
			registry_packages,
			_sorted_dictionary_keys(registry_packages),
			current_framework_version
		)
	)
	var lockfile_verify: Dictionary = { "ok": false, "issues": [] }
	if issues.is_empty():
		lockfile_verify = verify_lock_data(
			registry_packages,
			lockfile_data,
			_GF_VARIANT_ACCESS.get_option_string(registry, "framework_version")
		)
		_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(lockfile_verify, "issues"))

	var status_options: Dictionary = options
	if not installed.is_empty():
		status_options = _with_project_reference_scan_cache(resolved_project_root, options)

	var package_entries: Array[Dictionary] = []
	for package_id: String in _sorted_dictionary_keys(registry_packages):
		if _append_cancelled_if_requested(options, issues):
			break
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		var lock_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		package_entries.append(
			_make_status_package_entry(
				package_id,
				registry_entry,
				lock_entry,
				registry_packages,
				lockfile_data,
				resolved_project_root,
				resolved_lockfile_path,
				_GF_VARIANT_ACCESS.get_option_string(registry, "framework_version"),
				current_framework_version,
				status_options
			)
		)
		if _append_cancelled_if_requested(options, issues):
			break

	var orphan_packages: PackedStringArray = PackedStringArray()
	for package_id: String in _sorted_dictionary_keys(installed):
		if not registry_packages.has(package_id):
			var _append_orphan: bool = orphan_packages.append(package_id)

	return _make_status_result(
		issues.is_empty(),
		resolved_registry_path,
		resolved_project_root,
		resolved_lockfile_path,
		registry_remote,
		package_entries,
		orphan_packages,
		{
			"ok": _GF_VARIANT_ACCESS.get_option_bool(lockfile_verify, "ok", false),
			"issues": _GF_VARIANT_ACCESS.get_option_array(lockfile_verify, "issues"),
		},
		issues,
		registry_source
	)


## 计算安装闭包和 lockfile 预览，不写入磁盘。
## [br]
## @api framework_internal
## [br]
## @param registry_packages: registry packages 对象。
## [br]
## @schema registry_packages: Dictionary，key 为 package_id，value 为 registry package entry。
## [br]
## @param lockfile_data: 当前 lockfile 数据。
## [br]
## @schema lockfile_data: Dictionary，包含 installed。
## [br]
## @param package_ids: 请求安装的 package id。
## [br]
## @schema package_ids: String 数组。
## [br]
## @param reason: 根包安装原因。
## [br]
## @schema reason: manual、preset、bundled 或 dev。
## [br]
## @param lockfile_path: 用于显示的 lockfile 路径。
## [br]
## @schema lockfile_path: String。
## [br]
## @param registry_framework_version: registry 根节点声明的 GF 框架版本。
## [br]
## @schema registry_framework_version: String。
## [br]
## @param current_framework_version: 当前项目安装的 GF 框架版本；为空时允许 bootstrap 安装。
## [br]
## @schema current_framework_version: String。
## [br]
## @param registry_source: registry source 元数据。
## [br]
## @schema registry_source: Dictionary written into planned lockfile registry_source.
## [br]
## @return 安装计划 Dictionary。
## [br]
## @schema return: install_order、to_install、to_update、planned_lockfile 与 issues。
static func make_install_plan(
	registry_packages: Dictionary,
	lockfile_data: Dictionary,
	package_ids: PackedStringArray,
	reason: String = "manual",
	lockfile_path: String = ".gf/packages.lock.json",
	registry_framework_version: String = "",
	current_framework_version: String = "",
	registry_source: Dictionary = {}
) -> Dictionary:
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile_data, "installed").duplicate(true)
	var issues: PackedStringArray = PackedStringArray()
	if not VALID_REASONS.has(reason):
		var _append_reason_issue: bool = issues.append("Invalid install reason: %s" % reason)
	if not issues.is_empty():
		return _make_plan_result(false, "install", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, lockfile_data, lockfile_path)

	var closure: Dictionary = _resolve_dependency_closure(registry_packages, package_ids)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(closure, "issues"))
	if not issues.is_empty():
		return _make_plan_result(false, "install", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, lockfile_data, lockfile_path)
	var order: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(closure, "order")
	_append_string_array(issues, _registry_packages_compatibility_issues(registry_packages, order, current_framework_version))
	if not issues.is_empty():
		return _make_plan_result(false, "install", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, lockfile_data, lockfile_path)

	var original_installed: Dictionary = installed.duplicate(true)
	var requested_package_ids: Dictionary = {}
	for package_id: String in package_ids:
		requested_package_ids[package_id] = true

	for package_id: String in order:
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		var entry: Dictionary = _make_lock_entry(registry_entry)
		var existing: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		var reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(existing, "reason")
		var existing_files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(existing, "files")
		if not existing_files.is_empty():
			entry["files"] = _packed_to_array(existing_files)
		if requested_package_ids.has(package_id):
			_append_unique(reasons, reason)
		elif package_id == "gf.kernel":
			_append_unique(reasons, "bundled")
		else:
			_append_unique(reasons, "dependency")
		reasons.sort()
		entry["reason"] = _packed_to_array(reasons)
		installed[package_id] = entry

	_recompute_required_by(installed, registry_packages)
	var planned_lockfile: Dictionary = _make_lockfile(lockfile_data, installed, registry_framework_version, registry_source)
	var to_install: PackedStringArray = PackedStringArray()
	var to_update: PackedStringArray = PackedStringArray()
	for package_id: String in order:
		if not original_installed.has(package_id):
			var _append_install: bool = to_install.append(package_id)
			continue
		var original_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(original_installed, package_id)
		var planned_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if _lock_entry_changed(original_entry, planned_entry):
			var _append_update: bool = to_update.append(package_id)

	var plan_entries: Array[Dictionary] = _make_install_update_plan_entries(
		"install",
		order,
		to_install,
		to_update,
		requested_package_ids,
		original_installed,
		installed,
		registry_packages
	)
	return _make_plan_result(true, "install", order, to_install, to_update, PackedStringArray(), issues, planned_lockfile, lockfile_path, [], plan_entries)


## 计算已安装包的更新闭包和 lockfile 预览，不写入磁盘。
## [br]
## @api framework_internal
## [br]
## @param registry_packages: registry packages 对象。
## [br]
## @schema registry_packages: Dictionary，key 为 package_id，value 为 registry package entry。
## [br]
## @param lockfile_data: 当前 lockfile 数据。
## [br]
## @schema lockfile_data: Dictionary，包含 installed。
## [br]
## @param package_ids: 请求更新的已安装 package id。
## [br]
## @schema package_ids: String 数组。
## [br]
## @param update_all_installed: 是否更新 lockfile 中全部已安装 package。
## [br]
## @schema update_all_installed: bool。
## [br]
## @param lockfile_path: 用于显示的 lockfile 路径。
## [br]
## @schema lockfile_path: String。
## [br]
## @param registry_framework_version: registry 根节点声明的 GF 框架版本。
## [br]
## @schema registry_framework_version: String。
## [br]
## @param current_framework_version: 当前项目安装的 GF 框架版本，用于拒绝不兼容的更新计划。
## [br]
## @schema current_framework_version: String。
## [br]
## @param registry_source: registry source 元数据。
## [br]
## @schema registry_source: Dictionary written into planned lockfile registry_source.
## [br]
## @return 更新计划 Dictionary。
## [br]
## @schema return: install_order、to_install、to_update、planned_lockfile 与 issues。
static func make_update_plan(
	registry_packages: Dictionary,
	lockfile_data: Dictionary,
	package_ids: PackedStringArray,
	update_all_installed: bool = false,
	lockfile_path: String = ".gf/packages.lock.json",
	registry_framework_version: String = "",
	current_framework_version: String = "",
	registry_source: Dictionary = {}
) -> Dictionary:
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile_data, "installed").duplicate(true)
	var issues: PackedStringArray = PackedStringArray()
	var target_ids: PackedStringArray = _collect_update_targets(
		package_ids,
		update_all_installed,
		installed,
		registry_packages,
		issues
	)
	if not issues.is_empty():
		return _make_plan_result(false, "update", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, lockfile_data, lockfile_path)
	if target_ids.is_empty():
		var no_target_lockfile: Dictionary = _make_lockfile(lockfile_data, installed, registry_framework_version, registry_source)
		return _make_plan_result(true, "update", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, no_target_lockfile, lockfile_path)

	var closure: Dictionary = _resolve_dependency_closure(registry_packages, target_ids)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(closure, "issues"))
	if not issues.is_empty():
		return _make_plan_result(false, "update", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, lockfile_data, lockfile_path)
	var order: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(closure, "order")
	_append_string_array(issues, _registry_packages_compatibility_issues(registry_packages, order, current_framework_version))
	if not issues.is_empty():
		return _make_plan_result(false, "update", PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), issues, lockfile_data, lockfile_path)

	var original_installed: Dictionary = installed.duplicate(true)
	for package_id: String in order:
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		var entry: Dictionary = _make_lock_entry(registry_entry)
		var existing: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		var reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(existing, "reason")
		var existing_files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(existing, "files")
		if not existing_files.is_empty():
			entry["files"] = _packed_to_array(existing_files)
		if reasons.is_empty():
			_append_unique(reasons, "bundled" if package_id == "gf.kernel" else "dependency")
		reasons.sort()
		entry["reason"] = _packed_to_array(reasons)
		installed[package_id] = entry

	_recompute_required_by(installed, registry_packages)
	var planned_lockfile: Dictionary = _make_lockfile(lockfile_data, installed, registry_framework_version, registry_source)
	var to_install: PackedStringArray = PackedStringArray()
	var to_update: PackedStringArray = PackedStringArray()
	for package_id: String in order:
		if not original_installed.has(package_id):
			var _append_install: bool = to_install.append(package_id)
			continue
		var original_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(original_installed, package_id)
		var planned_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if _lock_entry_changed(original_entry, planned_entry):
			var _append_update: bool = to_update.append(package_id)

	var requested_package_ids: Dictionary = {}
	for package_id: String in target_ids:
		requested_package_ids[package_id] = true
	var plan_entries: Array[Dictionary] = _make_install_update_plan_entries(
		"update",
		order,
		to_install,
		to_update,
		requested_package_ids,
		original_installed,
		installed,
		registry_packages
	)
	return _make_plan_result(true, "update", order, to_install, to_update, PackedStringArray(), issues, planned_lockfile, lockfile_path, [], plan_entries)


## 计算卸载预览，不写入磁盘。
## [br]
## @api framework_internal
## [br]
## @param registry_packages: registry packages 对象。
## [br]
## @schema registry_packages: Dictionary，key 为 package_id，value 为 registry package entry。
## [br]
## @param lockfile_data: 当前 lockfile 数据。
## [br]
## @schema lockfile_data: Dictionary，包含 installed。
## [br]
## @param package_ids: 请求卸载的 package id。
## [br]
## @schema package_ids: String 数组。
## [br]
## @param project_root: 目标 Godot 项目根目录。
## [br]
## @schema project_root: String。
## [br]
## @param lockfile_path: 用于显示的 lockfile 路径。
## [br]
## @schema lockfile_path: String。
## [br]
## @param force: 是否忽略 required_by、保护原因和项目引用阻断。
## [br]
## @schema force: bool。
## [br]
## @param options: 内部包管理参数。
## [br]
## @schema options: Dictionary，可包含 cancel_callback。
## [br]
## @return 卸载计划 Dictionary。
## [br]
## @schema return: to_remove、blocked、planned_lockfile 与 issues。
static func make_uninstall_plan(
	registry_packages: Dictionary,
	lockfile_data: Dictionary,
	package_ids: PackedStringArray,
	project_root: String,
	lockfile_path: String = ".gf/packages.lock.json",
	force: bool = false,
	options: Dictionary = {}
) -> Dictionary:
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile_data, "installed").duplicate(true)
	var original_installed: Dictionary = installed.duplicate(true)
	var blocked: Array[Dictionary] = []
	var to_remove: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	for package_id: String in package_ids:
		if _append_cancelled_if_requested(options, issues):
			return _make_plan_result(
				false,
				"uninstall",
				PackedStringArray(),
				PackedStringArray(),
				PackedStringArray(),
				PackedStringArray(),
				issues,
				lockfile_data,
				lockfile_path,
				blocked,
				_make_blocked_uninstall_plan_entries(blocked, original_installed)
			)
		var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if entry.is_empty():
			blocked.append({ "id": package_id, "reason": "not_installed" })
			continue

		var reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "reason")
		var required_by: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "required_by")
		var protected_reasons: PackedStringArray = _intersect_strings(reasons, PROTECTED_REASONS)
		var references: Array[Dictionary] = scan_project_references(project_root, registry_packages, package_id, options)
		if _append_cancelled_if_requested(options, issues):
			return _make_plan_result(
				false,
				"uninstall",
				PackedStringArray(),
				PackedStringArray(),
				PackedStringArray(),
				PackedStringArray(),
				issues,
				lockfile_data,
				lockfile_path,
				blocked,
				_make_blocked_uninstall_plan_entries(blocked, original_installed)
			)
		if not required_by.is_empty() and not force:
			blocked.append({ "id": package_id, "reason": "required_by", "required_by": _packed_to_array(required_by) })
			continue
		if not protected_reasons.is_empty() and not force:
			blocked.append({ "id": package_id, "reason": "protected_reason", "protected_reasons": _packed_to_array(protected_reasons) })
			continue
		if not references.is_empty() and not force:
			blocked.append({ "id": package_id, "reason": "project_references", "references": references.slice(0, 20) })
			continue
		_append_unique(to_remove, package_id)

	if not blocked.is_empty():
		return _make_plan_result(
			false,
			"uninstall",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(["Uninstall blocked."]),
			lockfile_data,
			lockfile_path,
			blocked,
			_make_blocked_uninstall_plan_entries(blocked, original_installed)
		)

	for package_id: String in to_remove:
		var _removed: bool = installed.erase(package_id)
	_recompute_required_by(installed, registry_packages)
	var prune_blocked: Array[Dictionary] = _collect_dependency_prune_blockers(
		installed,
		registry_packages,
		project_root,
		force,
		options
	)
	if _append_cancelled_if_requested(options, issues):
		return _make_plan_result(
			false,
			"uninstall",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			issues,
			lockfile_data,
			lockfile_path,
			prune_blocked,
			_make_blocked_uninstall_plan_entries(prune_blocked, original_installed)
		)
	if not prune_blocked.is_empty():
		return _make_plan_result(
			false,
			"uninstall",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(["Uninstall blocked."]),
			lockfile_data,
			lockfile_path,
			prune_blocked,
			_make_blocked_uninstall_plan_entries(prune_blocked, original_installed)
		)
	var pruned: PackedStringArray = _prune_dependency_only_packages(installed, registry_packages, force)
	if _append_cancelled_if_requested(options, issues):
		return _make_plan_result(
			false,
			"uninstall",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray(),
			issues,
			lockfile_data,
			lockfile_path,
			[],
			[]
		)
	var planned_lockfile: Dictionary = _make_lockfile(lockfile_data, installed)
	var all_removed: PackedStringArray = to_remove.duplicate()
	for package_id: String in pruned:
		_append_unique(all_removed, package_id)
	all_removed.sort()
	return _make_plan_result(
		true,
		"uninstall",
		PackedStringArray(),
		PackedStringArray(),
		PackedStringArray(),
		all_removed,
		PackedStringArray(),
		planned_lockfile,
		lockfile_path,
		[],
		_make_uninstall_plan_entries(to_remove, pruned, original_installed)
	)


## 从 registry 和 archive 安装包闭包。
## [br]
## @api framework_internal
## [br]
## @param package_ids: 请求安装的 package id。
## [br]
## @schema package_ids: String 数组。
## [br]
## @param registry_path: registry index.json 路径。
## [br]
## @schema registry_path: String，本地 JSON 文件路径或 HTTP(S) registry URL。
## [br]
## @param project_root: 目标 Godot 项目根目录。
## [br]
## @schema project_root: String。
## [br]
## @param lockfile_path: lockfile 路径，非绝对路径时相对 project_root。
## [br]
## @schema lockfile_path: String。
## [br]
## @param reason: 根包安装原因。
## [br]
## @schema reason: manual、preset、bundled 或 dev。
## [br]
## @param dry_run: 是否只校验计划与 archive，不写项目文件或 lockfile。
## [br]
## @schema dry_run: bool。
## [br]
## @param options: 内部测试和后续安装参数。
## [br]
## @schema options: Dictionary，可包含 cache_dir、channel、simulate_copy_failure_after、cancel_callback。
## [br]
## @return 安装结果 Dictionary。
## [br]
## @schema return: 与 Python install 命令兼容的安装结果字段。
static func install_packages(
	package_ids: PackedStringArray,
	registry_path: String,
	project_root: String,
	lockfile_path: String = ".gf/packages.lock.json",
	reason: String = "manual",
	dry_run: bool = false,
	options: Dictionary = {}
) -> Dictionary:
	var resolved_project_root: String = _resolve_project_root(project_root)
	var resolved_lockfile_path: String = _resolve_lockfile_path(resolved_project_root, lockfile_path)
	var issues: PackedStringArray = PackedStringArray()
	_append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	if _append_cancelled_if_requested(options, issues):
		return _make_install_result(false, registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, dry_run, false, issues)
	var registry_source: Dictionary = {}
	if issues.is_empty():
		registry_source = _prepare_registry_source(registry_path, resolved_project_root, options, issues)
	var resolved_registry_path: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "path", registry_path)
	var cache_root: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "cache_dir")
	if not issues.is_empty():
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, dry_run, false, issues, registry_source)

	var registry: Dictionary = _load_registry(resolved_registry_path)
	var lockfile: Dictionary = _load_lockfile(resolved_lockfile_path)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(registry, "issues"))
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(lockfile, "issues"))
	if not issues.is_empty():
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, dry_run, false, issues, registry_source)

	var registry_packages: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var lockfile_data: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "data")
	var current_framework_version: String = _read_project_framework_version(resolved_project_root)
	_append_string_array(
		issues,
		_compatibility_range_issues(
			"registry",
			current_framework_version,
			_GF_VARIANT_ACCESS.get_option_string(registry, "minimum_framework_version"),
			_GF_VARIANT_ACCESS.get_option_string(registry, "maximum_framework_version_exclusive")
		)
	)
	if not issues.is_empty():
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, dry_run, false, issues, registry_source)
	var target_package_ids: PackedStringArray = _collect_install_targets(package_ids, registry_packages, options, issues)
	if not issues.is_empty():
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, {}, PackedStringArray(), 0, dry_run, false, issues, registry_source)
	var plan: Dictionary = make_install_plan(
		registry_packages,
		lockfile_data,
		target_package_ids,
		reason,
		resolved_lockfile_path,
		_GF_VARIANT_ACCESS.get_option_string(registry, "framework_version"),
		current_framework_version,
		registry_source
	)
	if not _GF_VARIANT_ACCESS.get_option_bool(plan, "ok"):
		return _make_install_result(
			false,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			target_package_ids,
			plan,
			PackedStringArray(),
			0,
			dry_run,
			false,
			_GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "issues"),
			registry_source
		)

	var packages_to_change: PackedStringArray = _packages_to_change_from_plan(plan)
	if packages_to_change.is_empty():
		return _make_install_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, PackedStringArray(), 0, dry_run, false, PackedStringArray(), registry_source)

	var packages_to_stage: PackedStringArray = _packages_requiring_archive(packages_to_change, registry_packages)
	if dry_run:
		var dry_run_archive_issues: PackedStringArray = _audit_package_archives(
			packages_to_stage,
			registry_packages,
			resolved_registry_path,
			cache_root,
			options,
			registry_source
		)
		if not dry_run_archive_issues.is_empty():
			return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, packages_to_change, 0, true, false, dry_run_archive_issues, registry_source)
		return _make_install_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, packages_to_change, 0, true, false, PackedStringArray(), registry_source)

	var temp_root: String = _make_temp_root(resolved_project_root)
	var staging_root: String = temp_root.path_join("staging")
	var backup_root: String = temp_root.path_join("backup")
	var staged_files: Array[Dictionary] = _stage_package_archives(
		packages_to_stage,
		registry_packages,
		resolved_registry_path,
		cache_root,
		staging_root,
		issues,
		options,
		registry_source
	)
	if not issues.is_empty():
		_remove_path_recursive_absolute(temp_root)
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, packages_to_change, 0, dry_run, false, issues, registry_source)

	var planned_lockfile: Dictionary = _lockfile_with_installed_files(
		_GF_VARIANT_ACCESS.get_option_dictionary(plan, "planned_lockfile"),
		staged_files
	)
	_append_existing_target_ownership_issues(
		staged_files,
		resolved_project_root,
		lockfile_data,
		issues
	)
	if not issues.is_empty():
		_remove_path_recursive_absolute(temp_root)
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, packages_to_change, 0, false, true, issues, registry_source)
	var simulate_copy_failure_after: int = _GF_VARIANT_ACCESS.get_option_int(options, "simulate_copy_failure_after", 0)
	var obsolete_targets: Array[Dictionary] = []
	var installed_file_count: int = _copy_staged_files_to_project(
		staged_files,
		resolved_project_root,
		resolved_lockfile_path,
		planned_lockfile,
		obsolete_targets,
		backup_root,
		simulate_copy_failure_after,
		issues,
		options
	)
	_remove_path_recursive_absolute(temp_root)
	if not issues.is_empty():
		return _make_install_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, packages_to_change, 0, false, true, issues, registry_source)
	return _make_install_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, target_package_ids, plan, packages_to_change, installed_file_count, false, false, PackedStringArray(), registry_source)


## 从 registry 更新当前 lockfile 中已安装的包。
## [br]
## @api framework_internal
## [br]
## @param package_ids: 请求更新的已安装 package id。
## [br]
## @schema package_ids: String 数组。
## [br]
## @param registry_path: registry index.json 路径。
## [br]
## @schema registry_path: String，本地 JSON 文件路径或 HTTP(S) registry URL。
## [br]
## @param project_root: 目标 Godot 项目根目录。
## [br]
## @schema project_root: String。
## [br]
## @param lockfile_path: lockfile 路径，非绝对路径时相对 project_root。
## [br]
## @schema lockfile_path: String。
## [br]
## @param update_all_installed: 是否更新 lockfile 中全部已安装 package。
## [br]
## @schema update_all_installed: bool。
## [br]
## @param dry_run: 是否只校验更新计划和 archive，不复制文件或写 lockfile。
## [br]
## @schema dry_run: bool。
## [br]
## @param options: 内部测试和后续更新参数。
## [br]
## @schema options: Dictionary，可包含 cache_dir、channel、simulate_copy_failure_after、cancel_callback。
## [br]
## @return 更新结果 Dictionary。
## [br]
## @schema return: 与 Python update 命令兼容的更新结果字段。
static func update_packages(
	package_ids: PackedStringArray,
	registry_path: String,
	project_root: String,
	lockfile_path: String = ".gf/packages.lock.json",
	update_all_installed: bool = false,
	dry_run: bool = false,
	options: Dictionary = {}
) -> Dictionary:
	var resolved_project_root: String = _resolve_project_root(project_root)
	var resolved_lockfile_path: String = _resolve_lockfile_path(resolved_project_root, lockfile_path)
	var issues: PackedStringArray = PackedStringArray()
	_append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	if _append_cancelled_if_requested(options, issues):
		return _make_update_result(false, registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, {}, PackedStringArray(), 0, dry_run, false, false, issues)
	var registry_source: Dictionary = {}
	if issues.is_empty():
		registry_source = _prepare_registry_source(registry_path, resolved_project_root, options, issues)
	var resolved_registry_path: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "path", registry_path)
	var cache_root: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "cache_dir")
	if not issues.is_empty():
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, {}, PackedStringArray(), 0, dry_run, false, false, issues, registry_source)

	var registry: Dictionary = _load_registry(resolved_registry_path)
	var lockfile: Dictionary = _load_lockfile(resolved_lockfile_path)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(registry, "issues"))
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(lockfile, "issues"))
	if not issues.is_empty():
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, {}, PackedStringArray(), 0, dry_run, false, false, issues, registry_source)

	var registry_packages: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var lockfile_data: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "data")
	var current_framework_version: String = _read_project_framework_version(resolved_project_root)
	_append_string_array(
		issues,
		_compatibility_range_issues(
			"registry",
			current_framework_version,
			_GF_VARIANT_ACCESS.get_option_string(registry, "minimum_framework_version"),
			_GF_VARIANT_ACCESS.get_option_string(registry, "maximum_framework_version_exclusive")
		)
	)
	if not issues.is_empty():
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, {}, PackedStringArray(), 0, dry_run, false, false, issues, registry_source)
	var plan: Dictionary = make_update_plan(
		registry_packages,
		lockfile_data,
		package_ids,
		update_all_installed,
		resolved_lockfile_path,
		_GF_VARIANT_ACCESS.get_option_string(registry, "framework_version"),
		current_framework_version,
		registry_source
	)
	if not _GF_VARIANT_ACCESS.get_option_bool(plan, "ok"):
		return _make_update_result(
			false,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			update_all_installed,
			plan,
			PackedStringArray(),
			0,
			dry_run,
			false,
			false,
			_GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "issues"),
			registry_source
		)

	var packages_to_change: PackedStringArray = _packages_to_change_from_plan(plan)
	var planned_lockfile: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(plan, "planned_lockfile")
	var lockfile_changed: bool = _lockfile_data_changed(lockfile_data, planned_lockfile)
	if packages_to_change.is_empty():
		if dry_run or not lockfile_changed:
			return _make_update_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, PackedStringArray(), 0, dry_run, false, false, PackedStringArray(), registry_source)
		var write_issues: PackedStringArray = PackedStringArray()
		if _append_cancelled_if_requested(options, write_issues):
			return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, PackedStringArray(), 0, false, false, false, write_issues, registry_source)
		var lockfile_written: bool = _write_lockfile_last(resolved_lockfile_path, planned_lockfile, write_issues)
		if not lockfile_written:
			return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, PackedStringArray(), 0, false, false, false, write_issues, registry_source)
		return _make_update_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, PackedStringArray(), 0, false, false, true, PackedStringArray(), registry_source)

	var packages_to_stage: PackedStringArray = _packages_requiring_archive(packages_to_change, registry_packages)
	if dry_run:
		var dry_run_archive_issues: PackedStringArray = _audit_package_archives(
			packages_to_stage,
			registry_packages,
			resolved_registry_path,
			cache_root,
			options,
			registry_source
		)
		if not dry_run_archive_issues.is_empty():
			return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, 0, true, false, false, dry_run_archive_issues, registry_source)
		return _make_update_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, 0, true, false, false, PackedStringArray(), registry_source)

	var temp_root: String = _make_temp_root(resolved_project_root)
	var staging_root: String = temp_root.path_join("staging")
	var backup_root: String = temp_root.path_join("backup")
	var staged_files: Array[Dictionary] = _stage_package_archives(
		packages_to_stage,
		registry_packages,
		resolved_registry_path,
		cache_root,
		staging_root,
		issues,
		options,
		registry_source
	)
	if not issues.is_empty():
		_remove_path_recursive_absolute(temp_root)
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, 0, dry_run, false, false, issues, registry_source)

	planned_lockfile = _lockfile_with_installed_files(planned_lockfile, staged_files)
	_append_modified_existing_update_file_issues(
		packages_to_change,
		lockfile_data,
		planned_lockfile,
		resolved_project_root,
		issues
	)
	_append_existing_target_ownership_issues(
		staged_files,
		resolved_project_root,
		lockfile_data,
		issues
	)
	if not issues.is_empty():
		_remove_path_recursive_absolute(temp_root)
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, 0, false, true, false, issues, registry_source)
	var obsolete_targets: Array[Dictionary] = _collect_update_obsolete_targets(
		packages_to_change,
		lockfile_data,
		planned_lockfile,
		resolved_project_root,
		issues
	)
	if not issues.is_empty():
		_remove_path_recursive_absolute(temp_root)
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, 0, false, true, false, issues, registry_source)
	var simulate_copy_failure_after: int = _GF_VARIANT_ACCESS.get_option_int(options, "simulate_copy_failure_after", 0)
	var updated_file_count: int = _copy_staged_files_to_project(
		staged_files,
		resolved_project_root,
		resolved_lockfile_path,
		planned_lockfile,
		obsolete_targets,
		backup_root,
		simulate_copy_failure_after,
		issues,
		options
	)
	_remove_path_recursive_absolute(temp_root)
	if not issues.is_empty():
		return _make_update_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, 0, false, true, false, issues, registry_source)
	return _make_update_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, update_all_installed, plan, packages_to_change, updated_file_count, false, false, true, PackedStringArray(), registry_source)


## 从 registry 和 lockfile 卸载包，并按 lockfile 文件清单删除包文件。
## [br]
## @api framework_internal
## [br]
## @param package_ids: 请求卸载的 package id。
## [br]
## @schema package_ids: String 数组。
## [br]
## @param registry_path: registry index.json 路径。
## [br]
## @schema registry_path: String，本地 JSON 文件路径或 HTTP(S) registry URL。
## [br]
## @param project_root: 目标 Godot 项目根目录。
## [br]
## @schema project_root: String。
## [br]
## @param lockfile_path: lockfile 路径，非绝对路径时相对 project_root。
## [br]
## @schema lockfile_path: String。
## [br]
## @param force: 是否忽略 required_by、保护 reason 和项目引用阻断。
## [br]
## @schema force: bool。
## [br]
## @param dry_run: 是否只校验卸载计划和目标文件，不删除文件或写 lockfile。
## [br]
## @schema dry_run: bool。
## [br]
## @param options: 内部测试和后续卸载参数。
## [br]
## @schema options: Dictionary，可包含 cache_dir、channel、simulate_delete_failure_after、cancel_callback。
## [br]
## @return 卸载结果 Dictionary。
## [br]
## @schema return: 与 Python uninstall 命令兼容的卸载结果字段。
static func uninstall_packages(
	package_ids: PackedStringArray,
	registry_path: String,
	project_root: String,
	lockfile_path: String = ".gf/packages.lock.json",
	force: bool = false,
	dry_run: bool = false,
	options: Dictionary = {}
) -> Dictionary:
	var resolved_project_root: String = _resolve_project_root(project_root)
	var resolved_lockfile_path: String = _resolve_lockfile_path(resolved_project_root, lockfile_path)
	var issues: PackedStringArray = PackedStringArray()
	_append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	if _append_cancelled_if_requested(options, issues):
		return _make_uninstall_result(false, registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, 0, dry_run, force, false, issues)
	var registry_source: Dictionary = {}
	if issues.is_empty():
		registry_source = _prepare_registry_source(registry_path, resolved_project_root, options, issues)
	var resolved_registry_path: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "path", registry_path)
	if not issues.is_empty():
		return _make_uninstall_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, 0, dry_run, force, false, issues, registry_source)

	var registry: Dictionary = _load_registry(resolved_registry_path)
	var lockfile: Dictionary = _load_lockfile(resolved_lockfile_path)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(registry, "issues"))
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(lockfile, "issues"))
	if not issues.is_empty():
		return _make_uninstall_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, {}, PackedStringArray(), 0, 0, dry_run, force, false, issues, registry_source)

	var registry_packages: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var lockfile_data: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "data")
	var plan: Dictionary = make_uninstall_plan(
		registry_packages,
		lockfile_data,
		package_ids,
		resolved_project_root,
		resolved_lockfile_path,
		force,
		options
	)
	if not _GF_VARIANT_ACCESS.get_option_bool(plan, "ok"):
		return _make_uninstall_result(
			false,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			PackedStringArray(),
			0,
			0,
			dry_run,
			force,
			false,
			_GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "issues"),
			registry_source
		)

	var to_remove: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "to_remove")
	if to_remove.is_empty():
		return _make_uninstall_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, plan, PackedStringArray(), 0, 0, dry_run, force, false, PackedStringArray(), registry_source)

	var targets: Array[Dictionary] = _collect_uninstall_targets(
		to_remove,
		lockfile_data,
		registry_packages,
		resolved_project_root,
		issues
	)
	if not issues.is_empty():
		return _make_uninstall_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, plan, to_remove, targets.size(), 0, dry_run, force, false, issues, registry_source)
	if dry_run:
		return _make_uninstall_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, plan, to_remove, targets.size(), 0, true, force, false, PackedStringArray(), registry_source)

	var temp_root: String = _make_temp_root(resolved_project_root)
	var backup_root: String = temp_root.path_join("uninstall_backup")
	var simulate_delete_failure_after: int = _GF_VARIANT_ACCESS.get_option_int(options, "simulate_delete_failure_after", 0)
	var removed_file_count: int = _delete_package_files_from_project(
		targets,
		resolved_project_root,
		resolved_lockfile_path,
		_GF_VARIANT_ACCESS.get_option_dictionary(plan, "planned_lockfile"),
		backup_root,
		simulate_delete_failure_after,
		issues,
		options
	)
	_remove_path_recursive_absolute(temp_root)
	if not issues.is_empty():
		return _make_uninstall_result(false, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, plan, to_remove, targets.size(), 0, false, force, true, issues, registry_source)
	return _make_uninstall_result(true, resolved_registry_path, resolved_project_root, resolved_lockfile_path, package_ids, plan, to_remove, targets.size(), removed_file_count, false, force, false, PackedStringArray(), registry_source)


## 校验 lockfile 与 registry 是否一致。
## [br]
## @api framework_internal
## [br]
## @param registry_packages: registry packages 对象。
## [br]
## @schema registry_packages: Dictionary。
## [br]
## @param lockfile_data: lockfile 数据。
## [br]
## @schema lockfile_data: Dictionary。
## [br]
## @param registry_framework_version: registry 根节点声明的 GF 框架版本；非空时必须与 lockfile 一致。
## [br]
## @schema registry_framework_version: String。
## [br]
## @return 校验结果 Dictionary。
## [br]
## @schema return: ok 与 issues。
static func verify_lock_data(
	registry_packages: Dictionary,
	lockfile_data: Dictionary,
	registry_framework_version: String = ""
) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile_data, "installed")
	var lockfile_framework_version: String = _GF_VARIANT_ACCESS.get_option_string(lockfile_data, "framework_version")
	if not lockfile_framework_version.is_empty() and not registry_framework_version.is_empty() and lockfile_framework_version != registry_framework_version:
		var _append_framework_version_issue: bool = issues.append(
			"Lockfile framework_version differs from registry framework_version: %s != %s" % [
				lockfile_framework_version,
				registry_framework_version,
			]
		)
	var expected: Dictionary = installed.duplicate(true)
	_recompute_required_by(expected, registry_packages)
	for package_id: String in _sorted_dictionary_keys(installed):
		var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		if registry_entry.is_empty():
			var _append_missing: bool = issues.append("Installed package is missing from registry: %s" % package_id)
			continue
		if _package_requires_archive(registry_entry) and _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "files").is_empty():
			var _append_missing_files: bool = issues.append("Installed package lockfile entry is missing files list: %s" % package_id)
		if _GF_VARIANT_ACCESS.get_option_string(entry, "sha256") != _GF_VARIANT_ACCESS.get_option_string(registry_entry, "sha256"):
			var _append_sha: bool = issues.append("Installed package sha256 differs from registry: %s" % package_id)
		var current_required_by: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "required_by")
		var expected_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(expected, package_id)
		var expected_required_by: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(expected_entry, "required_by")
		current_required_by.sort()
		expected_required_by.sort()
		if current_required_by != expected_required_by:
			var _append_required_stale: bool = issues.append("Installed package required_by is stale: %s" % package_id)
	return { "ok": issues.is_empty(), "issues": _packed_to_array(issues) }


## 扫描项目脚本和资源中是否仍引用指定包。
## [br]
## @api framework_internal
## [br]
## @param project_root: 目标项目根目录。
## [br]
## @schema project_root: String。
## [br]
## @param registry_packages: registry packages 对象。
## [br]
## @schema registry_packages: Dictionary。
## [br]
## @param package_id: 待扫描的 package id。
## [br]
## @schema package_id: String。
## [br]
## @param options: 内部包管理参数。
## [br]
## @schema options: Dictionary，可包含 cancel_callback。
## [br]
## @return 引用记录数组。
## [br]
## @schema return: 每项包含 path 与 symbol。
static func scan_project_references(
	project_root: String,
	registry_packages: Dictionary,
	package_id: String,
	options: Dictionary = {}
) -> Array[Dictionary]:
	if _is_cancel_requested(options):
		return []
	var package_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
	if package_entry.is_empty():
		return []

	var resolved_project_root: String = _resolve_project_root(project_root)
	var tokens: PackedStringArray = _package_path_tokens(_GF_VARIANT_ACCESS.get_option_packed_string_array(package_entry, "paths"))
	var symbols: PackedStringArray = _collect_package_class_names(resolved_project_root, package_entry, options)
	for symbol: String in symbols:
		_append_unique(tokens, symbol)
	_append_unique(tokens, package_id)
	if tokens.is_empty():
		return []

	var references: Array[Dictionary] = []
	var scan_cache: Dictionary = _get_project_reference_scan_cache(resolved_project_root, options)
	var project_files: PackedStringArray = _get_project_reference_scan_files(resolved_project_root, scan_cache, options)
	for absolute_path: String in project_files:
		if _is_cancel_requested(options):
			return references
		var source: String = _get_project_reference_scan_source(absolute_path, scan_cache)
		if source.is_empty():
			continue
		var relative_path: String = _relative_to_root(absolute_path, resolved_project_root)
		for token: String in tokens:
			if token.begins_with("GF"):
				if _source_contains_identifier(source, token):
					references.append({ "path": relative_path, "symbol": token })
					break
			elif source.contains(token):
				references.append({ "path": relative_path, "symbol": token })
				break
	return references


# --- 私有/辅助方法 ---

static func _load_registry(path: String) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var data: Dictionary = _read_json_dictionary(path, "registry", issues)
	if data.is_empty() and not issues.is_empty():
		return { "packages": {}, "framework_version": "", "issues": _packed_to_array(issues) }
	if _GF_VARIANT_ACCESS.get_option_int(data, "schema_version", -1) != REGISTRY_SCHEMA_VERSION:
		var _append_schema_issue: bool = issues.append("Registry schema_version must be %d." % REGISTRY_SCHEMA_VERSION)
	for field_name: String in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
		if not data.has(field_name):
			var _append_compatibility_field_issue: bool = issues.append("Registry %s field is required." % field_name)
	var raw_packages: Variant = data.get("packages", {})
	var packages: Dictionary = {}
	if raw_packages is Dictionary:
		var raw_package_dictionary: Dictionary = raw_packages
		for package_id: String in _sorted_dictionary_keys(raw_package_dictionary):
			if not _package_id_is_valid(package_id):
				var _append_package_id_issue: bool = issues.append("Registry contains invalid package id: %s" % package_id)
				continue
			var package_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(raw_package_dictionary, package_id)
			if not package_entry.is_empty():
				var issue_count_before_signature: int = issues.size()
				_append_unsupported_registry_package_signature_issues(package_id, package_entry, issues)
				for field_name: String in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
					if not package_entry.has(field_name):
						var _append_package_compatibility_field_issue: bool = issues.append("Registry package %s is missing %s." % [package_id, field_name])
				if issues.size() == issue_count_before_signature:
					packages[package_id] = package_entry
	else:
		var _append_packages_issue: bool = issues.append("Registry packages must be an object.")
	return {
		"packages": packages,
		"framework_version": _GF_VARIANT_ACCESS.get_option_string(data, "framework_version"),
		"minimum_framework_version": _GF_VARIANT_ACCESS.get_option_string(data, "minimum_framework_version"),
		"maximum_framework_version_exclusive": _GF_VARIANT_ACCESS.get_option_string(data, "maximum_framework_version_exclusive"),
		"issues": _packed_to_array(issues),
	}


static func _load_lockfile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "data": _empty_lockfile(), "issues": [] }
	var issues: PackedStringArray = PackedStringArray()
	var data: Dictionary = _read_json_dictionary(path, "lockfile", issues)
	if data.is_empty() and not issues.is_empty():
		return { "data": _empty_lockfile(), "issues": _packed_to_array(issues) }
	if _GF_VARIANT_ACCESS.get_option_int(data, "schema_version", -1) != LOCKFILE_SCHEMA_VERSION:
		var _append_schema_issue: bool = issues.append("Lockfile schema_version must be %d." % LOCKFILE_SCHEMA_VERSION)
	var raw_installed: Variant = data.get("installed", {})
	var installed: Dictionary = {}
	if raw_installed is Dictionary:
		var installed_dictionary: Dictionary = raw_installed
		for package_id: String in _sorted_dictionary_keys(installed_dictionary):
			if not _package_id_is_valid(package_id):
				var _append_package_id_issue: bool = issues.append("Lockfile contains invalid package id: %s" % package_id)
				continue
			var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed_dictionary, package_id)
			if not entry.is_empty():
				installed[package_id] = entry
	else:
		var _append_installed_issue: bool = issues.append("Lockfile installed must be an object.")
	data["installed"] = installed
	return { "data": data, "issues": _packed_to_array(issues) }


static func _read_json_dictionary(path: String, label: String, issues: PackedStringArray) -> Dictionary:
	if not FileAccess.file_exists(path):
		var _append_missing: bool = issues.append("Could not read %s: file does not exist: %s" % [label, path])
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var _append_open: bool = issues.append("Could not read %s: %s" % [label, error_string(FileAccess.get_open_error())])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		var _append_parse: bool = issues.append("%s root must be an object." % label.capitalize())
		return {}
	var data: Dictionary = parsed
	return data


static func _make_status_package_entry(
	package_id: String,
	registry_entry: Dictionary,
	lock_entry: Dictionary,
	registry_packages: Dictionary,
	lockfile_data: Dictionary,
	project_root: String,
	lockfile_path: String,
	registry_framework_version: String = "",
	current_framework_version: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var installed: bool = not lock_entry.is_empty()
	var install_preview: Dictionary = make_install_plan(
		registry_packages,
		lockfile_data,
		PackedStringArray([package_id]),
		"manual",
		lockfile_path,
		registry_framework_version,
		current_framework_version
	)
	var uninstall_preview: Dictionary = {}
	if installed:
		uninstall_preview = make_uninstall_plan(
			registry_packages,
			lockfile_data,
			PackedStringArray([package_id]),
			project_root,
			lockfile_path,
			false,
			options
		)
	return {
		"id": package_id,
		"kind": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind"),
		"version": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "version"),
		"display_name": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "display_name"),
		"description": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "description"),
		"dependencies": _GF_VARIANT_ACCESS.get_option_array(registry_entry, "dependencies"),
		"packages": _GF_VARIANT_ACCESS.get_option_array(registry_entry, "packages"),
		"paths": _GF_VARIANT_ACCESS.get_option_array(registry_entry, "paths"),
		"enable_extension": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "enable_extension"),
		"installed": installed,
		"reason": _GF_VARIANT_ACCESS.get_option_array(lock_entry, "reason"),
		"required_by": _GF_VARIANT_ACCESS.get_option_array(lock_entry, "required_by"),
		"file_count": _GF_VARIANT_ACCESS.get_option_array(lock_entry, "files").size(),
		"can_install": _GF_VARIANT_ACCESS.get_option_bool(install_preview, "ok"),
		"install_preview": _compact_install_preview(install_preview),
		"can_uninstall": _GF_VARIANT_ACCESS.get_option_bool(uninstall_preview, "ok") if installed else false,
		"uninstall_preview": _compact_uninstall_preview(uninstall_preview) if installed else {},
	}


static func _compact_install_preview(plan: Dictionary) -> Dictionary:
	return {
		"ok": _GF_VARIANT_ACCESS.get_option_bool(plan, "ok"),
		"install_order": _GF_VARIANT_ACCESS.get_option_array(plan, "install_order"),
		"to_install": _GF_VARIANT_ACCESS.get_option_array(plan, "to_install"),
		"to_update": _GF_VARIANT_ACCESS.get_option_array(plan, "to_update"),
		"plan_entries": _GF_VARIANT_ACCESS.get_option_array(plan, "plan_entries"),
		"plan_summary": _GF_VARIANT_ACCESS.get_option_dictionary(plan, "plan_summary"),
		"issues": _GF_VARIANT_ACCESS.get_option_array(plan, "issues"),
	}


static func _compact_uninstall_preview(plan: Dictionary) -> Dictionary:
	return {
		"ok": _GF_VARIANT_ACCESS.get_option_bool(plan, "ok"),
		"to_remove": _GF_VARIANT_ACCESS.get_option_array(plan, "to_remove"),
		"blocked": _GF_VARIANT_ACCESS.get_option_array(plan, "blocked"),
		"plan_entries": _GF_VARIANT_ACCESS.get_option_array(plan, "plan_entries"),
		"plan_summary": _GF_VARIANT_ACCESS.get_option_dictionary(plan, "plan_summary"),
		"issues": _GF_VARIANT_ACCESS.get_option_array(plan, "issues"),
	}


static func _make_status_result(
	ok: bool,
	registry_path: String,
	project_root: String,
	lockfile_path: String,
	registry_remote: bool,
	packages: Array[Dictionary],
	orphan_packages: PackedStringArray,
	lockfile_verify: Dictionary,
	issues: PackedStringArray,
	registry_source: Dictionary = {}
) -> Dictionary:
	var installed_count: int = 0
	var kind_counts: Dictionary = {}
	for package_entry: Dictionary in packages:
		if _GF_VARIANT_ACCESS.get_option_bool(package_entry, "installed"):
			installed_count += 1
		var kind: String = _GF_VARIANT_ACCESS.get_option_string(package_entry, "kind")
		kind_counts[kind] = _GF_VARIANT_ACCESS.to_int(kind_counts.get(kind, 0)) + 1

	var kind_count_entries: Array[Dictionary] = []
	for kind: String in _sorted_dictionary_keys(kind_counts):
		kind_count_entries.append({ "kind": kind, "count": _GF_VARIANT_ACCESS.to_int(kind_counts.get(kind, 0)) })

	var result: Dictionary = {
		"ok": ok,
		"operation": "status",
		"backend": "godot_native",
		"project_root": _display_path(project_root),
		"registry": _display_path(registry_path),
		"registry_remote": registry_remote,
		"lockfile": _display_path(lockfile_path),
		"package_count": packages.size(),
		"installed_count": installed_count,
		"available_count": packages.size() - installed_count,
		"kind_counts": kind_count_entries,
		"orphan_packages": _packed_to_array(orphan_packages),
		"lockfile_verify": lockfile_verify,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
		"cancelled": _issues_include_cancelled(issues),
		"packages": packages,
	}
	_append_registry_source_fields(result, registry_source)
	return result


static func _make_lock_entry(registry_entry: Dictionary) -> Dictionary:
	var entry: Dictionary = {
		"version": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "version"),
		"kind": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind"),
		"reason": [],
		"required_by": [],
		"paths": _GF_VARIANT_ACCESS.get_option_array(registry_entry, "paths"),
		"archive": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "archive"),
		"sha256": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "sha256"),
	}
	if _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind") == "preset":
		entry["packages"] = _GF_VARIANT_ACCESS.get_option_array(registry_entry, "packages")
	var enable_extension: String = _GF_VARIANT_ACCESS.get_option_string(registry_entry, "enable_extension")
	if not enable_extension.is_empty():
		entry["enable_extension"] = enable_extension
	return entry


static func _make_lockfile(
	base_lockfile: Dictionary,
	installed: Dictionary,
	framework_version: String = "",
	registry_source: Dictionary = {}
) -> Dictionary:
	var lockfile: Dictionary = {
		"schema_version": LOCKFILE_SCHEMA_VERSION,
		"framework_version": framework_version if not framework_version.is_empty() else _GF_VARIANT_ACCESS.get_option_string(base_lockfile, "framework_version"),
		"installed": _sort_dictionary_by_key(installed),
	}
	var lock_registry_source: Dictionary = _make_lockfile_registry_source(base_lockfile, registry_source)
	if not lock_registry_source.is_empty():
		lockfile["registry_source"] = lock_registry_source
	return lockfile


static func _make_lockfile_registry_source(base_lockfile: Dictionary, registry_source: Dictionary) -> Dictionary:
	var result: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(base_lockfile, "registry_source")
	if registry_source.is_empty():
		return result

	result = {}
	_append_lockfile_source_string(result, registry_source, "source")
	_append_lockfile_source_string(result, registry_source, "registry_source_manifest", "source_manifest")
	_append_lockfile_source_string(result, registry_source, "channel")
	_append_lockfile_source_string(result, registry_source, "offline_bundle")
	_append_lockfile_source_string(result, registry_source, "registry_sha256")
	if registry_source.has("remote"):
		result["remote"] = _GF_VARIANT_ACCESS.get_option_bool(registry_source, "remote", false)
	if registry_source.has("mirror_index"):
		result["mirror_index"] = _GF_VARIANT_ACCESS.get_option_int(registry_source, "mirror_index", -2)
	if registry_source.has("registry_size_bytes"):
		result["registry_size_bytes"] = _GF_VARIANT_ACCESS.get_option_int(registry_source, "registry_size_bytes", 0)
	return result


static func _append_lockfile_source_string(
	target: Dictionary,
	source: Dictionary,
	source_key: String,
	target_key: String = ""
) -> void:
	var value: String = _GF_VARIANT_ACCESS.get_option_string(source, source_key)
	if value.is_empty():
		return
	target[target_key if not target_key.is_empty() else source_key] = value


static func _make_plan_result(
	ok: bool,
	operation: String,
	install_order: PackedStringArray,
	to_install: PackedStringArray,
	to_update: PackedStringArray,
	to_remove: PackedStringArray,
	issues: PackedStringArray,
	lockfile: Dictionary,
	lockfile_path: String,
	blocked: Array[Dictionary] = [],
	plan_entries: Array[Dictionary] = []
) -> Dictionary:
	return {
		"ok": ok,
		"operation": operation,
		"install_order": _packed_to_array(install_order),
		"to_install": _packed_to_array(to_install),
		"to_update": _packed_to_array(to_update),
		"to_remove": _packed_to_array(to_remove),
		"blocked": blocked,
		"plan_entries": plan_entries,
		"plan_summary": _make_plan_summary(operation, plan_entries, issues, blocked),
		"lockfile_written": false,
		"lockfile": _display_path(lockfile_path),
		"installed_count": _GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed").size(),
		"issues": _packed_to_array(issues),
		"cancelled": _issues_include_cancelled(issues),
		"planned_lockfile": lockfile,
	}


static func _make_plan_summary(
	operation: String,
	plan_entries: Array[Dictionary],
	issues: PackedStringArray,
	blocked: Array[Dictionary]
) -> Dictionary:
	var action_counts: Dictionary = {}
	var requested_count: int = 0
	var archive_required_count: int = 0
	for entry: Dictionary in plan_entries:
		var action: String = _GF_VARIANT_ACCESS.get_option_string(entry, "action", "unknown")
		action_counts[action] = _GF_VARIANT_ACCESS.get_option_int(action_counts, action, 0) + 1
		if _GF_VARIANT_ACCESS.get_option_bool(entry, "requested", false):
			requested_count += 1
		if _GF_VARIANT_ACCESS.get_option_bool(entry, "archive_required", false):
			archive_required_count += 1
	return {
		"operation": operation,
		"entry_count": plan_entries.size(),
		"requested_count": requested_count,
		"archive_required_count": archive_required_count,
		"blocked_count": blocked.size(),
		"issue_count": issues.size(),
		"action_counts": _sort_dictionary_by_key(action_counts),
	}


static func _make_install_update_plan_entries(
	operation: String,
	order: PackedStringArray,
	to_install: PackedStringArray,
	to_update: PackedStringArray,
	requested_package_ids: Dictionary,
	original_installed: Dictionary,
	planned_installed: Dictionary,
	registry_packages: Dictionary
) -> Array[Dictionary]:
	var install_lookup: Dictionary = _make_string_lookup(to_install)
	var update_lookup: Dictionary = _make_string_lookup(to_update)
	var result: Array[Dictionary] = []
	for package_id: String in order:
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		var planned_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(planned_installed, package_id)
		var original_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(original_installed, package_id)
		var action: String = "keep"
		if install_lookup.has(package_id):
			action = "install"
		elif update_lookup.has(package_id):
			action = "update"
		var requested: bool = requested_package_ids.has(package_id)
		var decision_reasons: PackedStringArray = PackedStringArray()
		_append_unique(decision_reasons, "requested" if requested else "dependency")
		if action == "install":
			_append_unique(decision_reasons, "missing_from_lockfile")
		elif action == "update":
			_append_unique(decision_reasons, "lockfile_changed")
		else:
			_append_unique(decision_reasons, "already_satisfied")
		if _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind") == "preset":
			_append_unique(decision_reasons, "preset")

		result.append({
			"package_id": package_id,
			"operation": operation,
			"action": action,
			"requested": requested,
			"decision_reasons": _packed_to_array(decision_reasons),
			"kind": _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind"),
			"version": _GF_VARIANT_ACCESS.get_option_string(planned_entry, "version"),
			"previous_version": _GF_VARIANT_ACCESS.get_option_string(original_entry, "version"),
			"reason": _GF_VARIANT_ACCESS.get_option_array(planned_entry, "reason"),
			"required_by": _GF_VARIANT_ACCESS.get_option_array(planned_entry, "required_by"),
			"dependencies": _packed_to_array(_package_dependency_ids(registry_entry)),
			"archive_required": _package_requires_archive(registry_entry),
		})
	return result


static func _make_uninstall_plan_entries(
	to_remove: PackedStringArray,
	pruned: PackedStringArray,
	original_installed: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var requested_lookup: Dictionary = _make_string_lookup(to_remove)
	for package_id: String in to_remove:
		result.append(_make_uninstall_plan_entry(
			package_id,
			"remove",
			true,
			PackedStringArray(["requested"]),
			original_installed
		))
	for package_id: String in pruned:
		if requested_lookup.has(package_id):
			continue
		result.append(_make_uninstall_plan_entry(
			package_id,
			"prune_dependency",
			false,
			PackedStringArray(["dependency_no_longer_required"]),
			original_installed
		))
	return result


static func _make_blocked_uninstall_plan_entries(
	blocked: Array[Dictionary],
	original_installed: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for blocked_entry: Dictionary in blocked:
		var package_id: String = _GF_VARIANT_ACCESS.get_option_string(blocked_entry, "id")
		var reason: String = _GF_VARIANT_ACCESS.get_option_string(blocked_entry, "reason", "blocked")
		var decision_reasons: PackedStringArray = PackedStringArray([reason])
		var entry: Dictionary = _make_uninstall_plan_entry(
			package_id,
			"blocked",
			true,
			decision_reasons,
			original_installed
		)
		entry["blocked"] = blocked_entry.duplicate(true)
		result.append(entry)
	return result


static func _make_uninstall_plan_entry(
	package_id: String,
	action: String,
	requested: bool,
	decision_reasons: PackedStringArray,
	original_installed: Dictionary
) -> Dictionary:
	var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(original_installed, package_id)
	return {
		"package_id": package_id,
		"operation": "uninstall",
		"action": action,
		"requested": requested,
		"decision_reasons": _packed_to_array(decision_reasons),
		"kind": _GF_VARIANT_ACCESS.get_option_string(entry, "kind"),
		"version": _GF_VARIANT_ACCESS.get_option_string(entry, "version"),
		"reason": _GF_VARIANT_ACCESS.get_option_array(entry, "reason"),
		"required_by": _GF_VARIANT_ACCESS.get_option_array(entry, "required_by"),
		"archive_required": not entry.is_empty() and _package_requires_archive(entry),
	}


static func _make_install_result(
	ok: bool,
	registry_path: String,
	project_root: String,
	lockfile_path: String,
	requested_packages: PackedStringArray,
	plan: Dictionary,
	installed_packages: PackedStringArray,
	installed_file_count: int,
	dry_run: bool,
	rolled_back: bool,
	issues: PackedStringArray,
	registry_source: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"operation": "install",
		"backend": "godot_native",
		"project_root": _display_path(project_root),
		"registry": _display_path(registry_path),
		"lockfile": _display_path(lockfile_path),
		"requested_packages": _packed_to_array(requested_packages),
		"install_order": _GF_VARIANT_ACCESS.get_option_array(plan, "install_order"),
		"to_install": _GF_VARIANT_ACCESS.get_option_array(plan, "to_install"),
		"to_update": _GF_VARIANT_ACCESS.get_option_array(plan, "to_update"),
		"plan_entries": _GF_VARIANT_ACCESS.get_option_array(plan, "plan_entries"),
		"plan_summary": _GF_VARIANT_ACCESS.get_option_dictionary(plan, "plan_summary"),
		"installed_packages": _packed_to_array(installed_packages),
		"installed_file_count": installed_file_count,
		"lockfile_written": ok and not dry_run and not installed_packages.is_empty(),
		"dry_run": dry_run,
		"rolled_back": rolled_back,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
		"cancelled": _issues_include_cancelled(issues),
	}
	_append_registry_source_fields(result, registry_source)
	return result


static func _make_update_result(
	ok: bool,
	registry_path: String,
	project_root: String,
	lockfile_path: String,
	requested_packages: PackedStringArray,
	update_all_installed: bool,
	plan: Dictionary,
	updated_packages: PackedStringArray,
	updated_file_count: int,
	dry_run: bool,
	rolled_back: bool,
	lockfile_written: bool,
	issues: PackedStringArray,
	registry_source: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"operation": "update",
		"backend": "godot_native",
		"project_root": _display_path(project_root),
		"registry": _display_path(registry_path),
		"lockfile": _display_path(lockfile_path),
		"requested_packages": _packed_to_array(requested_packages),
		"all_installed": update_all_installed,
		"install_order": _GF_VARIANT_ACCESS.get_option_array(plan, "install_order"),
		"to_install": _GF_VARIANT_ACCESS.get_option_array(plan, "to_install"),
		"to_update": _GF_VARIANT_ACCESS.get_option_array(plan, "to_update"),
		"plan_entries": _GF_VARIANT_ACCESS.get_option_array(plan, "plan_entries"),
		"plan_summary": _GF_VARIANT_ACCESS.get_option_dictionary(plan, "plan_summary"),
		"updated_packages": _packed_to_array(updated_packages),
		"installed_packages": _packed_to_array(updated_packages),
		"updated_file_count": updated_file_count,
		"installed_file_count": updated_file_count,
		"lockfile_written": ok and not dry_run and lockfile_written,
		"dry_run": dry_run,
		"rolled_back": rolled_back,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
		"cancelled": _issues_include_cancelled(issues),
	}
	_append_registry_source_fields(result, registry_source)
	return result


static func _make_uninstall_result(
	ok: bool,
	registry_path: String,
	project_root: String,
	lockfile_path: String,
	requested_packages: PackedStringArray,
	plan: Dictionary,
	removed_packages: PackedStringArray,
	planned_file_count: int,
	removed_file_count: int,
	dry_run: bool,
	force: bool,
	rolled_back: bool,
	issues: PackedStringArray,
	registry_source: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"operation": "uninstall",
		"backend": "godot_native",
		"project_root": _display_path(project_root),
		"registry": _display_path(registry_path),
		"lockfile": _display_path(lockfile_path),
		"requested_packages": _packed_to_array(requested_packages),
		"plan": plan,
		"to_remove": _GF_VARIANT_ACCESS.get_option_array(plan, "to_remove"),
		"blocked": _GF_VARIANT_ACCESS.get_option_array(plan, "blocked"),
		"plan_entries": _GF_VARIANT_ACCESS.get_option_array(plan, "plan_entries"),
		"plan_summary": _GF_VARIANT_ACCESS.get_option_dictionary(plan, "plan_summary"),
		"removed_packages": _packed_to_array(removed_packages),
		"planned_file_count": planned_file_count,
		"removed_file_count": removed_file_count,
		"lockfile_written": ok and not dry_run and not removed_packages.is_empty(),
		"dry_run": dry_run,
		"force": force,
		"rolled_back": rolled_back,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
		"cancelled": _issues_include_cancelled(issues),
		"planned_lockfile": _GF_VARIANT_ACCESS.get_option_dictionary(plan, "planned_lockfile"),
	}
	_append_registry_source_fields(result, registry_source)
	return result


static func _append_registry_source_fields(result: Dictionary, registry_source: Dictionary) -> void:
	if registry_source.is_empty():
		return

	result["registry_remote"] = _GF_VARIANT_ACCESS.get_option_bool(registry_source, "remote")
	var source_value: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "source")
	if not source_value.is_empty():
		result["registry_source"] = _display_path(source_value)
	var offline_bundle: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "offline_bundle")
	if not offline_bundle.is_empty():
		result["registry_offline_bundle"] = _display_path(offline_bundle)
	var offline_bundle_extracted: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "offline_bundle_extracted")
	if not offline_bundle_extracted.is_empty():
		result["registry_offline_bundle_extracted"] = _display_path(offline_bundle_extracted)
	var source_manifest: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "registry_source_manifest")
	if not source_manifest.is_empty():
		result["registry_source_manifest"] = _display_path(source_manifest)
	var channel: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "channel")
	if not channel.is_empty():
		result["registry_channel"] = channel
	if registry_source.has("mirror_index"):
		result["registry_mirror_index"] = _GF_VARIANT_ACCESS.get_option_int(registry_source, "mirror_index", -2)
	var registry_sha: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "registry_sha256")
	if not registry_sha.is_empty():
		result["registry_source_sha256"] = registry_sha
	if registry_source.has("registry_size_bytes"):
		result["registry_source_size_bytes"] = _GF_VARIANT_ACCESS.get_option_int(registry_source, "registry_size_bytes", 0)
	var cache_dir: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "cache_dir")
	if not cache_dir.is_empty():
		result["registry_cache_dir"] = _display_path(cache_dir)


static func _append_cancelled_if_requested(options: Dictionary, issues: PackedStringArray) -> bool:
	if not _is_cancel_requested(options):
		return false
	_append_unique(issues, _PACKAGE_OPERATION_CANCELLED_ISSUE)
	return true


static func _is_cancel_requested(options: Dictionary) -> bool:
	var raw_callback: Variant = options.get("cancel_callback")
	if raw_callback is Callable:
		var callback: Callable = raw_callback
		if callback.is_valid():
			var callback_result: Variant = callback.call()
			return _GF_VARIANT_ACCESS.to_bool(callback_result, false)
	return _GF_VARIANT_ACCESS.get_option_bool(options, "cancel_requested", false)


static func _issues_include_cancelled(issues: PackedStringArray) -> bool:
	return issues.has(_PACKAGE_OPERATION_CANCELLED_ISSUE)


static func _packages_to_change_from_plan(plan: Dictionary) -> PackedStringArray:
	var change_set: Dictionary = {}
	for package_id: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "to_install"):
		change_set[package_id] = true
	for package_id: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "to_update"):
		change_set[package_id] = true

	var result: PackedStringArray = PackedStringArray()
	for package_id: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(plan, "install_order"):
		if change_set.has(package_id):
			var _append_package: bool = result.append(package_id)
	return result


static func _packages_requiring_archive(package_ids: PackedStringArray, registry_packages: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for package_id: String in package_ids:
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		if _package_requires_archive(registry_entry):
			var _append_package: bool = result.append(package_id)
	return result


static func _collect_update_targets(
	package_ids: PackedStringArray,
	update_all_installed: bool,
	installed: Dictionary,
	registry_packages: Dictionary,
	issues: PackedStringArray
) -> PackedStringArray:
	var requested_ids: PackedStringArray = PackedStringArray()
	for package_id: String in package_ids:
		var trimmed_id: String = package_id.strip_edges()
		if not trimmed_id.is_empty():
			var _append_requested: bool = requested_ids.append(trimmed_id)
	if update_all_installed:
		for raw_package_id: Variant in installed.keys():
			var installed_id: String = _GF_VARIANT_ACCESS.to_text(raw_package_id)
			if not installed_id.is_empty():
				var _append_installed: bool = requested_ids.append(installed_id)
	if requested_ids.is_empty():
		var _append_missing: bool = issues.append("Missing package id. Use --all-installed to update every installed package.")
		return PackedStringArray()

	var result: PackedStringArray = PackedStringArray()
	for package_id: String in requested_ids:
		if result.has(package_id):
			continue
		if not _package_id_is_valid(package_id):
			var _append_invalid_id: bool = issues.append("Invalid package id: %s" % package_id)
			continue
		if not installed.has(package_id):
			var _append_not_installed: bool = issues.append("Package is not installed: %s. Use install to add it." % package_id)
			continue
		if not registry_packages.has(package_id):
			var _append_missing_registry: bool = issues.append("Installed package is missing from registry: %s" % package_id)
			continue
		var _append_target: bool = result.append(package_id)
	return result


static func _collect_install_targets(
	package_ids: PackedStringArray,
	registry_packages: Dictionary,
	options: Dictionary,
	issues: PackedStringArray
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for package_id: String in package_ids:
		var trimmed_id: String = package_id.strip_edges()
		if trimmed_id.is_empty() or result.has(trimmed_id):
			continue
		var _append_explicit: bool = result.append(trimmed_id)

	var selected_ids: PackedStringArray = _select_registry_package_ids(registry_packages, options)
	for package_id: String in selected_ids:
		if result.has(package_id):
			continue
		var _append_selected: bool = result.append(package_id)

	if result.is_empty():
		var _append_missing: bool = issues.append("Missing package id or matching package selector.")
		return result

	for package_id: String in result:
		if not _package_id_is_valid(package_id):
			var _append_invalid_id: bool = issues.append("Invalid package id: %s" % package_id)
			continue
		if not registry_packages.has(package_id):
			var _append_missing_registry: bool = issues.append("Missing package: %s" % package_id)
	return result


static func _select_registry_package_ids(registry_packages: Dictionary, options: Dictionary) -> PackedStringArray:
	var all_concrete: bool = _GF_VARIANT_ACCESS.get_option_bool(options, "all_concrete", false)
	var include_kinds: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(options, "include_kinds")
	var exclude_kinds: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(options, "exclude_kinds")
	if not all_concrete and include_kinds.is_empty() and exclude_kinds.is_empty():
		return PackedStringArray()

	var result: PackedStringArray = PackedStringArray()
	for package_id: String in _sorted_dictionary_keys(registry_packages):
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		var package_kind: String = _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind")
		if all_concrete and package_kind == "preset":
			continue
		if not include_kinds.is_empty() and not include_kinds.has(package_kind):
			continue
		if exclude_kinds.has(package_kind):
			continue
		var _append_package: bool = result.append(package_id)
	return result


static func _package_requires_archive(registry_entry: Dictionary) -> bool:
	return _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind") != "preset"


static func _audit_package_archives(
	package_ids: PackedStringArray,
	registry_packages: Dictionary,
	registry_path: String,
	cache_root: String,
	options: Dictionary = {},
	registry_source: Dictionary = {}
) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for package_id: String in package_ids:
		if _append_cancelled_if_requested(options, issues):
			return issues
		if not _package_id_is_valid(package_id):
			var _append_package_id_issue: bool = issues.append("%s: invalid package id." % package_id)
			continue
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		if registry_entry.is_empty():
			var _append_missing: bool = issues.append("%s: missing registry package entry." % package_id)
			continue
		var archive_path: String = _resolve_archive_path(
			_GF_VARIANT_ACCESS.get_option_string(registry_entry, "archive"),
			registry_path,
			package_id,
			registry_entry,
			cache_root,
			issues,
			options,
			registry_source
		)
		if archive_path.is_empty():
			continue
		_append_string_array(issues, _audit_package_archive(package_id, registry_entry, archive_path))
	return issues


static func _lockfile_data_changed(current_lockfile: Dictionary, planned_lockfile: Dictionary) -> bool:
	return JSON.stringify(current_lockfile, "\t", false) != JSON.stringify(planned_lockfile, "\t", false)


static func _stage_package_archives(
	package_ids: PackedStringArray,
	registry_packages: Dictionary,
	registry_path: String,
	cache_root: String,
	staging_root: String,
	issues: PackedStringArray,
	options: Dictionary = {},
	registry_source: Dictionary = {}
) -> Array[Dictionary]:
	var staged_files: Array[Dictionary] = []
	for package_id: String in package_ids:
		if _append_cancelled_if_requested(options, issues):
			return staged_files
		if not _package_id_is_valid(package_id):
			var _append_package_id_issue: bool = issues.append("%s: invalid package id." % package_id)
			continue
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		if registry_entry.is_empty():
			var _append_missing: bool = issues.append("%s: missing registry package entry." % package_id)
			continue
		var archive_path: String = _resolve_archive_path(
			_GF_VARIANT_ACCESS.get_option_string(registry_entry, "archive"),
			registry_path,
			package_id,
			registry_entry,
			cache_root,
			issues,
			options,
			registry_source
		)
		if archive_path.is_empty():
			continue
		var archive_issues: PackedStringArray = _audit_package_archive(package_id, registry_entry, archive_path)
		_append_string_array(issues, archive_issues)
		if not archive_issues.is_empty():
			continue

		var reader: ZIPReader = ZIPReader.new()
		var open_error: Error = reader.open(archive_path)
		if open_error != OK:
			var _append_open: bool = issues.append("%s: invalid zip archive: %s" % [package_id, error_string(open_error)])
			continue
		var file_names: PackedStringArray = reader.get_files()
		file_names.sort()
		for file_name: String in file_names:
			if _append_cancelled_if_requested(options, issues):
				var _close_cancelled_reader: Variant = reader.close()
				return staged_files
			if file_name.is_empty() or file_name.ends_with("/"):
				continue
			var normalized: String = _normalize_archive_name(file_name)
			if normalized.is_empty():
				continue
			var staged_path: String = _package_staging_directory(staging_root, package_id).path_join(normalized)
			var make_error: Error = DirAccess.make_dir_recursive_absolute(staged_path.get_base_dir())
			if make_error != OK:
				var _append_make: bool = issues.append("%s: could not create staging directory: %s" % [package_id, error_string(make_error)])
				continue
			var bytes: PackedByteArray = reader.read_file(file_name)
			if bytes.size() > MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES:
				var _append_large_entry: bool = issues.append("%s: archive entry is too large after decompression: %s" % [package_id, normalized])
				continue
			if not _write_binary_file(staged_path, bytes, issues, "%s: staging %s" % [package_id, normalized]):
				continue
			staged_files.append({
				"package_id": package_id,
				"relative_path": normalized,
				"staged_path": staged_path,
				"sha256": FileAccess.get_sha256(staged_path).to_lower(),
				"size_bytes": bytes.size(),
			})
		var _close_reader: Variant = reader.close()
	return staged_files


static func _audit_package_archive(package_id: String, registry_entry: Dictionary, archive_path: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	if not FileAccess.file_exists(archive_path):
		var _append_missing: bool = issues.append("%s: archive is missing: %s" % [package_id, archive_path])
		return issues

	var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(registry_entry, "size_bytes", 0)
	var actual_size: int = _file_size(archive_path)
	if expected_size > 0 and actual_size != expected_size:
		var _append_size: bool = issues.append("%s: archive size does not match registry size_bytes." % package_id)
	var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(registry_entry, "sha256").strip_edges().to_lower()
	if not expected_sha.is_empty():
		var actual_sha: String = FileAccess.get_sha256(archive_path).to_lower()
		if actual_sha != expected_sha:
			var _append_sha: bool = issues.append("%s: archive sha256 does not match registry sha256." % package_id)
	if not issues.is_empty():
		return issues

	var metadata: Dictionary = _read_zip_archive_metadata(archive_path, package_id)
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(metadata, "issues"))
	if not _GF_VARIANT_ACCESS.get_option_bool(metadata, "ok", false):
		return issues
	var archive_entries: Array = _GF_VARIANT_ACCESS.get_option_array(metadata, "entries")
	if archive_entries.size() > MAX_ARCHIVE_ENTRY_COUNT:
		var _append_entry_count: bool = issues.append("%s: archive contains too many file entries: %d > %d" % [package_id, archive_entries.size(), MAX_ARCHIVE_ENTRY_COUNT])

	var seen: Dictionary = {}
	var package_paths: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(registry_entry, "paths")
	var total_uncompressed_size: int = 0
	for entry_variant: Variant in archive_entries:
		var metadata_entry: Dictionary = _GF_VARIANT_ACCESS.as_dictionary(entry_variant)
		var file_name: String = _GF_VARIANT_ACCESS.get_option_string(metadata_entry, "path")
		if file_name.is_empty() or file_name.ends_with("/"):
			continue
		var compressed_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata_entry, "compressed_size", 0)
		var uncompressed_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata_entry, "uncompressed_size", 0)
		total_uncompressed_size += uncompressed_size
		var normalized: String = _normalize_archive_name(file_name)
		if normalized.is_empty():
			var _append_unsafe: bool = issues.append("%s: unsafe archive entry path: %s" % [package_id, file_name])
			continue
		if normalized.length() > MAX_ARCHIVE_ENTRY_PATH_LENGTH:
			var _append_path_length: bool = issues.append("%s: archive entry path is too long: %s" % [package_id, normalized])
		if normalized.split("/", false).size() > MAX_ARCHIVE_ENTRY_PATH_DEPTH:
			var _append_path_depth: bool = issues.append("%s: archive entry path is too deep: %s" % [package_id, normalized])
		if uncompressed_size > MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES:
			var _append_entry_size: bool = issues.append("%s: archive entry exceeds decompressed size limit: %s" % [package_id, normalized])
		if compressed_size <= 0 and uncompressed_size > 0:
			var _append_zero_compressed: bool = issues.append("%s: archive entry has invalid compressed size: %s" % [package_id, normalized])
		elif compressed_size > 0 and uncompressed_size > compressed_size * MAX_ARCHIVE_COMPRESSION_RATIO:
			var _append_ratio: bool = issues.append("%s: archive entry compression ratio exceeds limit: %s" % [package_id, normalized])
		if seen.has(normalized):
			var _append_duplicate: bool = issues.append("%s: duplicate archive entry path: %s" % [package_id, normalized])
			continue
		seen[normalized] = true
		if not normalized.begins_with(GF_PACKAGE_ROOT_PREFIX):
			var _append_outside: bool = issues.append("%s: archive entry is outside addons/gf: %s" % [package_id, normalized])
		if not _path_matches_any_manifest_path(normalized, package_paths):
			var _append_uncovered: bool = issues.append("%s: archive entry is not covered by registry paths: %s" % [package_id, normalized])
		if _archive_path_has_blocked_dir(normalized):
			var _append_blocked_dir: bool = issues.append("%s: archive entry contains blocked directory: %s" % [package_id, normalized])
		if _archive_path_has_blocked_file(normalized):
			var _append_blocked_file: bool = issues.append("%s: archive entry contains blocked generated file: %s" % [package_id, normalized])
		if _runtime_package_has_external_tool_payload(package_id, registry_entry, normalized):
			var _append_tool_payload: bool = issues.append("%s: runtime package archive contains external tool payload: %s" % [package_id, normalized])
	if total_uncompressed_size > MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES:
		var _append_total_size: bool = issues.append("%s: archive decompressed size exceeds limit: %d > %d" % [package_id, total_uncompressed_size, MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES])
	return issues


static func _read_zip_archive_metadata(archive_path: String, package_id: String) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(archive_path)
	if open_error != OK:
		var _append_open: bool = issues.append("%s: invalid zip archive: %s" % [package_id, error_string(open_error)])
		return { "ok": false, "entries": [], "issues": _packed_to_array(issues) }
	var _close_reader: Variant = reader.close()

	var file: FileAccess = FileAccess.open(archive_path, FileAccess.READ)
	if file == null:
		var _append_file: bool = issues.append("%s: could not read archive metadata: %s" % [package_id, error_string(FileAccess.get_open_error())])
		return { "ok": false, "entries": [], "issues": _packed_to_array(issues) }
	var file_size: int = file.get_length()
	var search_size: int = mini(file_size, 65557)
	file.seek(file_size - search_size)
	var search_buffer: PackedByteArray = file.get_buffer(search_size)
	var eocd_index: int = _find_zip_eocd_index(search_buffer)
	if eocd_index < 0:
		file.close()
		var _append_eocd: bool = issues.append("%s: zip archive is missing central directory." % package_id)
		return { "ok": false, "entries": [], "issues": _packed_to_array(issues) }

	var entry_count: int = _read_uint16_le(search_buffer, eocd_index + 10)
	var central_directory_size: int = _read_uint32_le(search_buffer, eocd_index + 12)
	var central_directory_offset: int = _read_uint32_le(search_buffer, eocd_index + 16)
	if entry_count == 0xffff or central_directory_size == 0xffffffff or central_directory_offset == 0xffffffff:
		file.close()
		var _append_zip64: bool = issues.append("%s: zip64 archives are not supported by the native package installer." % package_id)
		return { "ok": false, "entries": [], "issues": _packed_to_array(issues) }
	if central_directory_offset < 0 or central_directory_size < 0 or central_directory_offset + central_directory_size > file_size:
		file.close()
		var _append_bounds: bool = issues.append("%s: zip central directory is outside the archive bounds." % package_id)
		return { "ok": false, "entries": [], "issues": _packed_to_array(issues) }
	if entry_count > MAX_ARCHIVE_ENTRY_COUNT:
		file.close()
		var _append_count: bool = issues.append("%s: archive contains too many file entries: %d > %d" % [package_id, entry_count, MAX_ARCHIVE_ENTRY_COUNT])
		return { "ok": false, "entries": [], "issues": _packed_to_array(issues) }

	file.seek(central_directory_offset)
	var central_directory: PackedByteArray = file.get_buffer(central_directory_size)
	file.close()

	var entries: Array[Dictionary] = []
	var offset: int = 0
	while offset + 46 <= central_directory.size():
		if not _zip_signature_matches(central_directory, offset, 0x50, 0x4b, 0x01, 0x02):
			var _append_header: bool = issues.append("%s: invalid zip central directory entry." % package_id)
			break
		var compressed_size: int = _read_uint32_le(central_directory, offset + 20)
		var uncompressed_size: int = _read_uint32_le(central_directory, offset + 24)
		var file_name_length: int = _read_uint16_le(central_directory, offset + 28)
		var extra_length: int = _read_uint16_le(central_directory, offset + 30)
		var comment_length: int = _read_uint16_le(central_directory, offset + 32)
		var file_name_offset: int = offset + 46
		var next_offset: int = file_name_offset + file_name_length + extra_length + comment_length
		if next_offset > central_directory.size():
			var _append_truncated: bool = issues.append("%s: truncated zip central directory entry." % package_id)
			break
		if compressed_size == 0xffffffff or uncompressed_size == 0xffffffff:
			var _append_zip64_entry: bool = issues.append("%s: zip64 archive entries are not supported." % package_id)
			break
		var file_name_bytes: PackedByteArray = central_directory.slice(file_name_offset, file_name_offset + file_name_length)
		entries.append({
			"path": file_name_bytes.get_string_from_utf8(),
			"compressed_size": compressed_size,
			"uncompressed_size": uncompressed_size,
		})
		offset = next_offset

	if issues.is_empty() and entries.size() != entry_count:
		var _append_mismatch: bool = issues.append("%s: zip central directory entry count does not match archive footer." % package_id)
	return { "ok": issues.is_empty(), "entries": entries, "issues": _packed_to_array(issues) }


static func _find_zip_eocd_index(bytes: PackedByteArray) -> int:
	for index: int in range(bytes.size() - 22, -1, -1):
		if _zip_signature_matches(bytes, index, 0x50, 0x4b, 0x05, 0x06):
			return index
	return -1


static func _zip_signature_matches(bytes: PackedByteArray, offset: int, first: int, second: int, third: int, fourth: int) -> bool:
	return (
		offset >= 0
		and offset + 3 < bytes.size()
		and bytes[offset] == first
		and bytes[offset + 1] == second
		and bytes[offset + 2] == third
		and bytes[offset + 3] == fourth
	)


static func _read_uint16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 1 >= bytes.size():
		return 0
	return bytes[offset] | (bytes[offset + 1] << 8)


static func _read_uint32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 3 >= bytes.size():
		return 0
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)


static func _registry_file_matches_metadata(path: String, expected_sha: String, expected_size: int, issues: PackedStringArray) -> bool:
	var starting_issue_count: int = issues.size()
	if not FileAccess.file_exists(path):
		var _append_missing: bool = issues.append("registry: file is missing: %s" % path)
		return false

	if expected_size > 0 and _file_size(path) != expected_size:
		var _append_size: bool = issues.append("registry: registry size does not match registry source metadata.")
	var normalized_sha: String = expected_sha.strip_edges().to_lower()
	if not normalized_sha.is_empty() and FileAccess.get_sha256(path).to_lower() != normalized_sha:
		var _append_sha: bool = issues.append("registry: registry sha256 does not match registry source metadata.")
	return issues.size() == starting_issue_count


static func _registry_source_sha_is_valid(value: String) -> bool:
	var text: String = value.strip_edges()
	if text.length() != 64:
		return false
	var hex_digits: String = "0123456789abcdefABCDEF"
	for index: int in range(text.length()):
		if hex_digits.find(text.substr(index, 1)) < 0:
			return false
	return true


static func _is_non_negative_int_variant(value: Variant) -> bool:
	if value is int:
		var int_value: int = value
		return int_value >= 0
	if value is float:
		var float_value: float = value
		return float_value >= 0.0 and floor(float_value) == float_value
	if value is String:
		var text: String = value
		return text.is_valid_int() and int(text) >= 0
	return false


static func _variant_is_blank(value: Variant) -> bool:
	if value == null:
		return true
	if value is String:
		var text: String = value
		return text.strip_edges().is_empty()
	return false


static func _package_id_is_valid(package_id: String) -> bool:
	var text: String = package_id.strip_edges()
	if text != package_id or text.is_empty():
		return false
	if not text.begins_with("gf."):
		return false
	if text.contains("/") or text.contains("\\") or text.contains(":"):
		return false
	if text.contains(".."):
		return false
	var parts: PackedStringArray = text.split(".", false)
	if parts.size() < 2:
		return false
	for part: String in parts:
		if part.is_empty():
			return false
		for index: int in range(part.length()):
			var character: String = part.substr(index, 1)
			if not _package_id_character_is_valid(character):
				return false
	return true


static func _package_id_character_is_valid(character: String) -> bool:
	if character == "_" or character == "-":
		return true
	var code: int = character.unicode_at(0)
	return (
		(code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
	)


static func _package_staging_directory(staging_root: String, package_id: String) -> String:
	return staging_root.path_join("%s-%s" % [_safe_cache_name(package_id), _sha256_text(package_id).substr(0, 12)])


static func _lockfile_with_installed_files(planned_lockfile: Dictionary, staged_files: Array[Dictionary]) -> Dictionary:
	var lockfile: Dictionary = planned_lockfile.duplicate(true)
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var files_by_package: Dictionary = {}
	var metadata_by_package: Dictionary = {}
	for item: Dictionary in staged_files:
		var package_id: String = _GF_VARIANT_ACCESS.get_option_string(item, "package_id")
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "relative_path")
		if package_id.is_empty() or relative_path.is_empty():
			continue
		var files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(files_by_package, package_id)
		_append_unique(files, relative_path)
		files_by_package[package_id] = _packed_to_array(files)
		var package_metadata: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(metadata_by_package, package_id)
		package_metadata[relative_path] = {
			"sha256": _GF_VARIANT_ACCESS.get_option_string(item, "sha256"),
			"size_bytes": _GF_VARIANT_ACCESS.get_option_int(item, "size_bytes", 0),
		}
		metadata_by_package[package_id] = package_metadata
	for package_id: String in _sorted_dictionary_keys(files_by_package):
		var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if entry.is_empty():
			continue
		var files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(files_by_package, package_id)
		files.sort()
		entry["files"] = _packed_to_array(files)
		entry["file_metadata"] = _sort_dictionary_by_key(_GF_VARIANT_ACCESS.get_option_dictionary(metadata_by_package, package_id))
		installed[package_id] = entry
	lockfile["installed"] = installed
	return lockfile


static func _collect_uninstall_targets(
	package_ids: PackedStringArray,
	lockfile_data: Dictionary,
	registry_packages: Dictionary,
	project_root: String,
	issues: PackedStringArray
) -> Array[Dictionary]:
	var targets_by_path: Dictionary = {}
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(lockfile_data, "installed")
	var removing: Dictionary = {}
	for package_id: String in package_ids:
		removing[package_id] = true

	for package_id: String in package_ids:
		var lock_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if lock_entry.is_empty():
			var _append_missing: bool = issues.append("%s: package is not installed in the current lockfile." % package_id)
			continue
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		if _package_requires_archive(lock_entry) == false or _package_requires_archive(registry_entry) == false:
			continue
		var patterns: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(lock_entry, "paths")
		if patterns.is_empty():
			patterns = _GF_VARIANT_ACCESS.get_option_packed_string_array(registry_entry, "paths")
		var file_paths: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(lock_entry, "files")
		if file_paths.is_empty():
			var _append_missing_files: bool = issues.append("%s: lockfile entry is missing the installed files list; reinstall or repair the package before uninstalling." % package_id)
			continue
		for relative_path: String in file_paths:
			var normalized: String = _normalize_archive_name(relative_path)
			if normalized.is_empty():
				var _append_unsafe: bool = issues.append("%s: unsafe installed file path in lockfile: %s" % [package_id, relative_path])
				continue
			if not normalized.begins_with(GF_PACKAGE_ROOT_PREFIX):
				var _append_outside: bool = issues.append("%s: uninstall target is outside addons/gf: %s" % [package_id, normalized])
				continue
			if not _path_matches_any_manifest_path(normalized, patterns):
				var _append_uncovered: bool = issues.append("%s: uninstall target is not covered by package paths: %s" % [package_id, normalized])
				continue
			var remaining_owner: String = _remaining_package_owner(normalized, installed, registry_packages, removing)
			if not remaining_owner.is_empty():
				var _append_owned: bool = issues.append("%s: uninstall target is still owned by installed package %s: %s" % [package_id, remaining_owner, normalized])
				continue
			if targets_by_path.has(normalized):
				continue
			var target_path: String = _project_target_path(project_root, normalized, issues)
			if target_path.is_empty():
				continue
			targets_by_path[normalized] = {
				"package_id": package_id,
				"relative_path": normalized,
				"target_path": target_path,
			}

	var targets: Array[Dictionary] = []
	for relative_path: String in _sorted_dictionary_keys(targets_by_path):
		targets.append(_GF_VARIANT_ACCESS.get_option_dictionary(targets_by_path, relative_path))
	return targets


static func _append_modified_existing_update_file_issues(
	package_ids: PackedStringArray,
	current_lockfile: Dictionary,
	planned_lockfile: Dictionary,
	project_root: String,
	issues: PackedStringArray
) -> void:
	var current_installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_lockfile, "installed")
	var planned_installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(planned_lockfile, "installed")
	for package_id: String in package_ids:
		var current_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_installed, package_id)
		var planned_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(planned_installed, package_id)
		if current_entry.is_empty() or planned_entry.is_empty():
			continue

		var current_files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(current_entry, "files")
		var planned_files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(planned_entry, "files")
		var current_metadata: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_entry, "file_metadata")
		for relative_path: String in current_files:
			var normalized: String = _normalize_archive_name(relative_path)
			if normalized.is_empty() or not planned_files.has(normalized):
				continue

			var target_path: String = _project_target_path(project_root, normalized, issues)
			if target_path.is_empty() or not FileAccess.file_exists(target_path):
				continue

			var metadata: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_metadata, normalized)
			var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(metadata, "sha256")
			var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata, "size_bytes", -1)
			if expected_sha.is_empty() or expected_size < 0:
				var _append_missing_metadata: bool = issues.append("%s: installed file is missing lockfile metadata; reinstall before updating: %s" % [package_id, normalized])
				continue
			if _file_size(target_path) != expected_size or FileAccess.get_sha256(target_path).to_lower() != expected_sha:
				var _append_modified: bool = issues.append("%s: installed file was modified; refusing to overwrite it during update: %s" % [package_id, normalized])


static func _append_existing_target_ownership_issues(
	staged_files: Array[Dictionary],
	project_root: String,
	current_lockfile: Dictionary,
	issues: PackedStringArray
) -> void:
	var installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_lockfile, "installed")
	for item: Dictionary in staged_files:
		var package_id: String = _GF_VARIANT_ACCESS.get_option_string(item, "package_id")
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "relative_path")
		var normalized: String = _normalize_archive_name(relative_path)
		if package_id.is_empty() or normalized.is_empty():
			continue
		var target_path: String = _project_target_path(project_root, normalized, issues)
		if target_path.is_empty() or not FileAccess.file_exists(target_path):
			continue
		var owner: String = _installed_file_owner(normalized, installed)
		if owner.is_empty():
			if _target_matches_staged_file(target_path, item):
				continue
			var _append_unowned: bool = issues.append("%s: package target already exists but is not owned by the lockfile: %s" % [package_id, normalized])
			continue
		if owner != package_id:
			var _append_other_owner: bool = issues.append("%s: package target is owned by installed package %s: %s" % [package_id, owner, normalized])


static func _target_matches_staged_file(target_path: String, staged_file: Dictionary) -> bool:
	var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(staged_file, "size_bytes", -1)
	var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(staged_file, "sha256").strip_edges().to_lower()
	if expected_size < 0 or expected_sha.is_empty():
		return false
	if _file_size(target_path) != expected_size:
		return false
	return FileAccess.get_sha256(target_path).to_lower() == expected_sha


static func _collect_update_obsolete_targets(
	package_ids: PackedStringArray,
	current_lockfile: Dictionary,
	planned_lockfile: Dictionary,
	project_root: String,
	issues: PackedStringArray
) -> Array[Dictionary]:
	var targets_by_path: Dictionary = {}
	var current_installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_lockfile, "installed")
	var planned_installed: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(planned_lockfile, "installed")
	for package_id: String in package_ids:
		var current_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_installed, package_id)
		var planned_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(planned_installed, package_id)
		if current_entry.is_empty() or planned_entry.is_empty():
			continue
		var current_files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(current_entry, "files")
		var planned_files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(planned_entry, "files")
		var current_metadata: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_entry, "file_metadata")
		for relative_path: String in current_files:
			var normalized: String = _normalize_archive_name(relative_path)
			if normalized.is_empty() or planned_files.has(normalized) or targets_by_path.has(normalized):
				continue
			var remaining_owner: String = _remaining_package_file_owner(normalized, current_installed, package_id)
			if not remaining_owner.is_empty():
				continue
			var target_path: String = _project_target_path(project_root, normalized, issues)
			if target_path.is_empty() or not FileAccess.file_exists(target_path):
				continue
			var metadata: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(current_metadata, normalized)
			var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(metadata, "sha256")
			var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata, "size_bytes", -1)
			if expected_sha.is_empty() or expected_size < 0:
				var _append_missing_metadata: bool = issues.append("%s: obsolete installed file is missing lockfile metadata; reinstall before updating: %s" % [package_id, normalized])
				continue
			if _file_size(target_path) != expected_size or FileAccess.get_sha256(target_path).to_lower() != expected_sha:
				var _append_modified: bool = issues.append("%s: obsolete installed file was modified; refusing to delete it during update: %s" % [package_id, normalized])
				continue
			targets_by_path[normalized] = {
				"package_id": package_id,
				"relative_path": normalized,
				"target_path": target_path,
			}

	var targets: Array[Dictionary] = []
	for relative_path: String in _sorted_dictionary_keys(targets_by_path):
		targets.append(_GF_VARIANT_ACCESS.get_option_dictionary(targets_by_path, relative_path))
	return targets


static func _installed_file_owner(relative_path: String, installed: Dictionary) -> String:
	for package_id: String in _sorted_dictionary_keys(installed):
		var lock_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		var files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(lock_entry, "files")
		if files.has(relative_path):
			return package_id
	return ""


static func _remaining_package_file_owner(relative_path: String, installed: Dictionary, current_package_id: String) -> String:
	for package_id: String in _sorted_dictionary_keys(installed):
		if package_id == current_package_id:
			continue
		var lock_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		var files: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(lock_entry, "files")
		if files.has(relative_path):
			return package_id
	return ""


static func _remaining_package_owner(
	relative_path: String,
	installed: Dictionary,
	registry_packages: Dictionary,
	removing: Dictionary
) -> String:
	for package_id: String in _sorted_dictionary_keys(installed):
		if removing.has(package_id):
			continue
		var lock_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if lock_entry.is_empty():
			continue
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		var patterns: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(lock_entry, "paths")
		if patterns.is_empty():
			patterns = _GF_VARIANT_ACCESS.get_option_packed_string_array(registry_entry, "paths")
		if _path_matches_any_manifest_path(relative_path, patterns):
			return package_id
	return ""


static func _copy_staged_files_to_project(
	staged_files: Array[Dictionary],
	project_root: String,
	lockfile_path: String,
	planned_lockfile: Dictionary,
	obsolete_targets: Array[Dictionary],
	backup_root: String,
	simulate_copy_failure_after: int,
	issues: PackedStringArray,
	options: Dictionary = {}
) -> int:
	if _append_cancelled_if_requested(options, issues):
		return 0
	var make_project_error: Error = DirAccess.make_dir_recursive_absolute(project_root)
	if make_project_error != OK:
		var _append_project: bool = issues.append("Could not create project root: %s" % error_string(make_project_error))
		return 0

	var created_files: PackedStringArray = PackedStringArray()
	var created_dirs: PackedStringArray = PackedStringArray()
	var backups: Array[Dictionary] = []
	var copied_count: int = 0
	for item: Dictionary in staged_files:
		if _append_cancelled_if_requested(options, issues):
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "relative_path")
		var staged_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "staged_path")
		var target_path: String = _project_target_path(project_root, relative_path, issues)
		if target_path.is_empty():
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		if not _make_parent_dirs(target_path.get_base_dir(), project_root, created_dirs, issues):
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		if DirAccess.dir_exists_absolute(target_path):
			var _append_dir: bool = issues.append("Cannot overwrite directory with package file: %s" % target_path)
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		if FileAccess.file_exists(target_path):
			var backup_path: String = backup_root.path_join(relative_path)
			var backup_make_error: Error = DirAccess.make_dir_recursive_absolute(backup_path.get_base_dir())
			if backup_make_error != OK:
				var _append_backup_dir: bool = issues.append("Could not create package backup directory: %s" % error_string(backup_make_error))
				_rollback_install_files(created_files, backups, created_dirs, issues)
				return 0
			if not _copy_file(target_path, backup_path, issues, "backup %s" % relative_path):
				_rollback_install_files(created_files, backups, created_dirs, issues)
				return 0
			backups.append({ "target": target_path, "backup": backup_path })
		else:
			var _append_created: bool = created_files.append(target_path)
		if not _copy_file(staged_path, target_path, issues, "install %s" % relative_path):
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		copied_count += 1
		if simulate_copy_failure_after > 0 and copied_count >= simulate_copy_failure_after:
			var _append_simulated: bool = issues.append("Simulated package install copy failure.")
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0

	for item: Dictionary in obsolete_targets:
		if _append_cancelled_if_requested(options, issues):
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "relative_path")
		var target_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "target_path")
		if target_path.is_empty() or not FileAccess.file_exists(target_path):
			continue
		var backup_path: String = backup_root.path_join("obsolete").path_join(relative_path)
		var backup_make_error: Error = DirAccess.make_dir_recursive_absolute(backup_path.get_base_dir())
		if backup_make_error != OK:
			var _append_backup_dir: bool = issues.append("Could not create obsolete package backup directory: %s" % error_string(backup_make_error))
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		if not _copy_file(target_path, backup_path, issues, "backup obsolete %s" % relative_path):
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0
		backups.append({ "target": target_path, "backup": backup_path })
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK:
			var _append_remove: bool = issues.append("Could not delete obsolete package file: %s (%s)" % [target_path, error_string(remove_error)])
			_rollback_install_files(created_files, backups, created_dirs, issues)
			return 0

	if _append_cancelled_if_requested(options, issues):
		_rollback_install_files(created_files, backups, created_dirs, issues)
		return 0
	if not _write_lockfile_last(lockfile_path, planned_lockfile, issues):
		_rollback_install_files(created_files, backups, created_dirs, issues)
		return 0
	return copied_count


static func _delete_package_files_from_project(
	targets: Array[Dictionary],
	project_root: String,
	lockfile_path: String,
	planned_lockfile: Dictionary,
	backup_root: String,
	simulate_delete_failure_after: int,
	issues: PackedStringArray,
	options: Dictionary = {}
) -> int:
	var backups: Array[Dictionary] = []
	var touched_dirs: PackedStringArray = PackedStringArray()
	var deleted_count: int = 0
	for item: Dictionary in targets:
		if _append_cancelled_if_requested(options, issues):
			_restore_deleted_files(backups, issues)
			return 0
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "relative_path")
		var target_path: String = _GF_VARIANT_ACCESS.get_option_string(item, "target_path")
		if target_path.is_empty():
			var _append_target: bool = issues.append("Invalid uninstall target path: %s" % relative_path)
			_restore_deleted_files(backups, issues)
			return 0
		if not FileAccess.file_exists(target_path) and not DirAccess.dir_exists_absolute(target_path):
			continue
		if DirAccess.dir_exists_absolute(target_path):
			var _append_dir: bool = issues.append("Refusing to delete directory as a package file: %s" % target_path)
			_restore_deleted_files(backups, issues)
			return 0
		var backup_path: String = backup_root.path_join(relative_path)
		var make_backup_error: Error = DirAccess.make_dir_recursive_absolute(backup_path.get_base_dir())
		if make_backup_error != OK:
			var _append_backup_dir: bool = issues.append("Could not create package uninstall backup directory: %s" % error_string(make_backup_error))
			_restore_deleted_files(backups, issues)
			return 0
		if not _copy_file(target_path, backup_path, issues, "backup uninstall %s" % relative_path):
			_restore_deleted_files(backups, issues)
			return 0
		backups.append({ "target": target_path, "backup": backup_path })
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK:
			var _append_remove: bool = issues.append("Could not delete package file: %s (%s)" % [target_path, error_string(remove_error)])
			_restore_deleted_files(backups, issues)
			return 0
		deleted_count += 1
		_append_unique(touched_dirs, target_path.get_base_dir())
		if simulate_delete_failure_after > 0 and deleted_count >= simulate_delete_failure_after:
			var _append_simulated: bool = issues.append("Simulated package uninstall delete failure.")
			_restore_deleted_files(backups, issues)
			return 0

	_remove_empty_project_dirs(touched_dirs, project_root)
	if _append_cancelled_if_requested(options, issues):
		_restore_deleted_files(backups, issues)
		return 0
	if not _write_lockfile_last(lockfile_path, planned_lockfile, issues):
		_restore_deleted_files(backups, issues)
		return 0
	return deleted_count


static func _restore_deleted_files(backups: Array[Dictionary], issues: PackedStringArray) -> void:
	for index: int in range(backups.size() - 1, -1, -1):
		var backup: Dictionary = backups[index]
		var target_path: String = _GF_VARIANT_ACCESS.get_option_string(backup, "target")
		var backup_path: String = _GF_VARIANT_ACCESS.get_option_string(backup, "backup")
		if FileAccess.file_exists(backup_path):
			var _copy_back: bool = _copy_file(backup_path, target_path, issues, "restore %s" % target_path)


static func _remove_empty_project_dirs(directories: PackedStringArray, project_root: String) -> void:
	var normalized_root: String = _trim_trailing_path_separators(project_root.replace("\\", "/"))
	for directory_path: String in directories:
		var current: String = _trim_trailing_path_separators(directory_path.replace("\\", "/"))
		while not current.is_empty() and current != current.get_base_dir():
			if not _is_path_inside(normalized_root, current) or current == normalized_root:
				break
			if not DirAccess.dir_exists_absolute(current):
				current = current.get_base_dir()
				continue
			if current == normalized_root.path_join("addons"):
				break
			var remove_error: Error = DirAccess.remove_absolute(current)
			if remove_error != OK:
				break
			current = current.get_base_dir()


static func _rollback_install_files(
	created_files: PackedStringArray,
	backups: Array[Dictionary],
	created_dirs: PackedStringArray,
	issues: PackedStringArray
) -> void:
	for index: int in range(created_files.size() - 1, -1, -1):
		var path: String = created_files[index]
		if FileAccess.file_exists(path):
			var _remove_file_error: Error = DirAccess.remove_absolute(path)
	for index: int in range(backups.size() - 1, -1, -1):
		var backup: Dictionary = backups[index]
		var target_path: String = _GF_VARIANT_ACCESS.get_option_string(backup, "target")
		var backup_path: String = _GF_VARIANT_ACCESS.get_option_string(backup, "backup")
		if FileAccess.file_exists(backup_path):
			var _copy_back: bool = _copy_file(backup_path, target_path, issues, "restore %s" % target_path)
	for index: int in range(created_dirs.size() - 1, -1, -1):
		var directory_path: String = created_dirs[index]
		if DirAccess.dir_exists_absolute(directory_path):
			var _remove_dir_error: Error = DirAccess.remove_absolute(directory_path)


static func _write_lockfile_last(lockfile_path: String, planned_lockfile: Dictionary, issues: PackedStringArray) -> bool:
	var directory_path: String = lockfile_path.get_base_dir()
	var make_error: Error = DirAccess.make_dir_recursive_absolute(directory_path)
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create lockfile directory: %s" % error_string(make_error))
		return false

	var temp_path: String = lockfile_path + ".tmp"
	var backup_path: String = lockfile_path + ".bak"
	if not _write_text_file_absolute(temp_path, JSON.stringify(planned_lockfile, "\t", false) + "\n", issues, "write lockfile temp"):
		return false

	var had_lockfile: bool = FileAccess.file_exists(lockfile_path)
	if had_lockfile:
		if not _copy_file(lockfile_path, backup_path, issues, "backup lockfile"):
			var _remove_temp_error: Error = DirAccess.remove_absolute(temp_path)
			return false
		var remove_error: Error = DirAccess.remove_absolute(lockfile_path)
		if remove_error != OK:
			var _append_remove: bool = issues.append("Could not replace existing lockfile: %s" % error_string(remove_error))
			var _remove_temp_after_error: Error = DirAccess.remove_absolute(temp_path)
			return false

	var rename_error: Error = DirAccess.rename_absolute(temp_path, lockfile_path)
	if rename_error != OK:
		var _append_rename: bool = issues.append("Could not write lockfile: %s" % error_string(rename_error))
		if had_lockfile and FileAccess.file_exists(backup_path):
			var _restore_lock: bool = _copy_file(backup_path, lockfile_path, issues, "restore lockfile")
		var _remove_temp_error: Error = DirAccess.remove_absolute(temp_path)
		return false

	if FileAccess.file_exists(backup_path):
		var _remove_backup_error: Error = DirAccess.remove_absolute(backup_path)
	return true


static func _prepare_registry_source(
	registry_value: String,
	project_root: String,
	options: Dictionary,
	issues: PackedStringArray
) -> Dictionary:
	var cache_root: String = _resolve_cache_dir(project_root, options)
	var effective_registry_value: String = _resolve_registry_value(registry_value)
	var candidate_issues: PackedStringArray = PackedStringArray()
	var source: Dictionary = _prepare_registry_candidate(effective_registry_value, project_root, cache_root, candidate_issues, "", 0, options)
	if not candidate_issues.is_empty():
		_append_string_array(issues, candidate_issues)
		return source
	if _registry_file_is_source_manifest(_GF_VARIANT_ACCESS.get_option_string(source, "path")):
		return _prepare_registry_source_channel(source, project_root, cache_root, options, issues)
	return source


static func _resolve_registry_value(registry_value: String) -> String:
	var text: String = registry_value.strip_edges()
	if text.is_empty():
		return get_default_registry_source_url()
	return text


static func _prepare_registry_candidate(
	registry_value: String,
	project_root: String,
	cache_root: String,
	issues: PackedStringArray,
	expected_sha: String = "",
	expected_size: int = 0,
	options: Dictionary = {}
) -> Dictionary:
	var registry: String = registry_value.strip_edges()
	if _append_cancelled_if_requested(options, issues):
		return {
			"path": registry,
			"cache_dir": cache_root,
			"remote": _is_http_url(registry),
			"source": registry,
		}
	if _is_http_url(registry):
		var cache_path: String = cache_root.path_join("registries").path_join("%s.json" % _sha256_text(registry))
		var raw_path: String = cache_path + ".raw"
		if _remote_registry_cache_matches_metadata(cache_path, registry, expected_sha, expected_size):
			return {
				"path": cache_path,
				"cache_dir": cache_root,
				"remote": true,
				"source": registry,
			}
		if not _download_url_to_file(registry, raw_path, "registry", issues, MAX_REGISTRY_DOWNLOAD_BYTES, 0, 0, options):
			return {
				"path": cache_path,
				"cache_dir": cache_root,
				"remote": true,
				"source": registry,
			}
		if not _registry_file_matches_metadata(raw_path, expected_sha, expected_size, issues):
			if FileAccess.file_exists(raw_path):
				var _remove_invalid_raw: Error = DirAccess.remove_absolute(raw_path)
			return {
				"path": cache_path,
				"cache_dir": cache_root,
				"remote": true,
				"source": registry,
			}
		_rewrite_remote_registry(raw_path, cache_path, registry, issues)
		if FileAccess.file_exists(cache_path):
			_write_remote_registry_cache_metadata(cache_path, registry, raw_path, expected_sha, expected_size, issues)
		if FileAccess.file_exists(raw_path):
			var _remove_raw: Error = DirAccess.remove_absolute(raw_path)
		return {
			"path": cache_path,
			"cache_dir": cache_root,
			"remote": true,
			"source": registry,
		}
	var registry_path: String = _resolve_path(registry_value, project_root)
	if _registry_path_is_offline_bundle(registry_path):
		if not _registry_file_matches_metadata(registry_path, expected_sha, expected_size, issues):
			return {
				"path": registry_path,
				"cache_dir": cache_root,
				"remote": false,
				"source": registry_value,
			}
		return _prepare_offline_bundle_registry_candidate(registry_path, registry_value, cache_root, issues, options)
	var _registry_matches_metadata: bool = _registry_file_matches_metadata(registry_path, expected_sha, expected_size, issues)
	return {
		"path": registry_path,
		"cache_dir": cache_root,
		"remote": false,
		"source": registry_value,
	}


static func _registry_file_is_source_manifest(path: String) -> bool:
	var issues: PackedStringArray = PackedStringArray()
	var data: Dictionary = _read_json_dictionary(path, "registry source", issues)
	return issues.is_empty() and _GF_VARIANT_ACCESS.get_option_dictionary(data, "channels").is_empty() == false


static func _registry_path_is_offline_bundle(path: String) -> bool:
	return path.get_extension().to_lower() == "zip"


static func _prepare_offline_bundle_registry_candidate(
	bundle_path: String,
	registry_value: String,
	cache_root: String,
	issues: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	var bundle_sha: String = FileAccess.get_sha256(bundle_path).to_lower()
	if bundle_sha.is_empty():
		bundle_sha = _sha256_text(bundle_path)
	var extract_root: String = cache_root.path_join("offline_bundles").path_join(bundle_sha).replace("\\", "/")
	var registry_path: String = extract_root.path_join(_OFFLINE_BUNDLE_REGISTRY_ENTRY).replace("\\", "/")
	if not _extract_offline_bundle_registry(bundle_path, extract_root, issues, options):
		return {
			"path": registry_path,
			"cache_dir": cache_root,
			"remote": false,
			"source": registry_value,
			"offline_bundle": bundle_path,
			"offline_bundle_extracted": extract_root,
		}
	if not FileAccess.file_exists(registry_path):
		var _append_missing: bool = issues.append("Offline bundle is missing registry/index.json: %s" % bundle_path)
	return {
		"path": registry_path,
		"cache_dir": cache_root,
		"remote": false,
		"source": registry_value,
		"offline_bundle": bundle_path,
		"offline_bundle_extracted": extract_root,
	}


static func _extract_offline_bundle_registry(
	bundle_path: String,
	extract_root: String,
	issues: PackedStringArray,
	options: Dictionary = {}
) -> bool:
	var starting_issue_count: int = issues.size()
	if _append_cancelled_if_requested(options, issues):
		return false
	var validation_issues: PackedStringArray = _validate_offline_bundle_archive(bundle_path)
	_append_string_array(issues, validation_issues)
	if not validation_issues.is_empty():
		return false

	_remove_path_recursive_absolute(extract_root)
	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(bundle_path)
	if open_error != OK:
		var _append_open: bool = issues.append("Offline bundle is not a valid zip archive: %s (%s)" % [bundle_path, error_string(open_error)])
		return false
	var seen: Dictionary = {}
	var file_names: PackedStringArray = reader.get_files()
	file_names.sort()
	for file_name: String in file_names:
		if _append_cancelled_if_requested(options, issues):
			var _close_cancelled_reader: Variant = reader.close()
			return false
		if file_name.is_empty() or file_name.ends_with("/"):
			continue
		var normalized: String = _normalize_offline_bundle_entry_name(file_name)
		if normalized.is_empty():
			var _append_unsafe: bool = issues.append("Offline bundle contains unsafe entry path: %s" % file_name)
			continue
		if seen.has(normalized):
			var _append_duplicate: bool = issues.append("Offline bundle contains duplicate entry path: %s" % normalized)
			continue
		seen[normalized] = true
		if not _offline_bundle_entry_is_allowed(normalized):
			var _append_blocked: bool = issues.append("Offline bundle contains unsupported entry path: %s" % normalized)
			continue
		var target_path: String = extract_root.path_join(normalized).replace("\\", "/")
		if not _is_path_inside(extract_root, target_path):
			var _append_outside: bool = issues.append("Offline bundle entry target is outside extraction root: %s" % normalized)
			continue
		var bytes: PackedByteArray = reader.read_file(file_name)
		if bytes.size() > MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES:
			var _append_large_entry: bool = issues.append("Offline bundle entry is too large after decompression: %s" % normalized)
			continue
		var _wrote_file: bool = _write_binary_file(target_path, bytes, issues, "extract offline bundle %s" % normalized)
	var _close_reader: Variant = reader.close()
	return issues.size() == starting_issue_count


static func _validate_offline_bundle_archive(bundle_path: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var metadata: Dictionary = _read_zip_archive_metadata(bundle_path, "offline bundle")
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(metadata, "issues"))
	if not _GF_VARIANT_ACCESS.get_option_bool(metadata, "ok", false):
		return issues

	var archive_entries: Array = _GF_VARIANT_ACCESS.get_option_array(metadata, "entries")
	if archive_entries.size() > MAX_ARCHIVE_ENTRY_COUNT:
		var _append_entry_count: bool = issues.append("Offline bundle contains too many file entries: %d > %d" % [archive_entries.size(), MAX_ARCHIVE_ENTRY_COUNT])

	var seen: Dictionary = {}
	var total_uncompressed_size: int = 0
	for entry_variant: Variant in archive_entries:
		var metadata_entry: Dictionary = _GF_VARIANT_ACCESS.as_dictionary(entry_variant)
		var file_name: String = _GF_VARIANT_ACCESS.get_option_string(metadata_entry, "path")
		if file_name.is_empty() or file_name.ends_with("/"):
			continue

		var compressed_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata_entry, "compressed_size", 0)
		var uncompressed_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata_entry, "uncompressed_size", 0)
		total_uncompressed_size += uncompressed_size
		var normalized: String = _normalize_offline_bundle_entry_name(file_name)
		if normalized.is_empty():
			var _append_unsafe: bool = issues.append("Offline bundle contains unsafe entry path: %s" % file_name)
			continue
		if normalized.length() > MAX_ARCHIVE_ENTRY_PATH_LENGTH:
			var _append_path_length: bool = issues.append("Offline bundle entry path is too long: %s" % normalized)
		if normalized.split("/", false).size() > MAX_ARCHIVE_ENTRY_PATH_DEPTH:
			var _append_path_depth: bool = issues.append("Offline bundle entry path is too deep: %s" % normalized)
		if uncompressed_size > MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES:
			var _append_entry_size: bool = issues.append("Offline bundle entry exceeds decompressed size limit: %s" % normalized)
		if compressed_size <= 0 and uncompressed_size > 0:
			var _append_zero_compressed: bool = issues.append("Offline bundle entry has invalid compressed size: %s" % normalized)
		elif compressed_size > 0 and uncompressed_size > compressed_size * MAX_ARCHIVE_COMPRESSION_RATIO:
			var _append_ratio: bool = issues.append("Offline bundle entry compression ratio exceeds limit: %s" % normalized)
		if seen.has(normalized):
			var _append_duplicate: bool = issues.append("Offline bundle contains duplicate entry path: %s" % normalized)
			continue
		seen[normalized] = true
		if not _offline_bundle_entry_is_allowed(normalized):
			var _append_blocked: bool = issues.append("Offline bundle contains unsupported entry path: %s" % normalized)
	if total_uncompressed_size > MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES:
		var _append_total_size: bool = issues.append("Offline bundle decompressed size exceeds limit: %d > %d" % [total_uncompressed_size, MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES])
	return issues


static func _normalize_offline_bundle_entry_name(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if normalized.begins_with("/") or normalized.begins_with("res://") or normalized.begins_with("user://") or normalized.contains(":"):
		return ""
	while normalized.begins_with("./"):
		normalized = normalized.substr(2)
	var parts: PackedStringArray = normalized.split("/", false)
	var safe_parts: PackedStringArray = PackedStringArray()
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..":
			return ""
		var _append_part: bool = safe_parts.append(part)
	return "/".join(safe_parts)


static func _offline_bundle_entry_is_allowed(path: String) -> bool:
	var normalized: String = path.to_lower()
	if normalized.begins_with(_OFFLINE_BUNDLE_REGISTRY_PREFIX) and normalized.ends_with(_OFFLINE_BUNDLE_JSON_SUFFIX):
		return true
	return normalized.begins_with(_OFFLINE_BUNDLE_PACKAGE_PREFIX) and normalized.ends_with(_OFFLINE_BUNDLE_ARCHIVE_SUFFIX)


static func _prepare_registry_source_channel(
	source: Dictionary,
	project_root: String,
	cache_root: String,
	options: Dictionary,
	issues: PackedStringArray
) -> Dictionary:
	var source_path: String = _GF_VARIANT_ACCESS.get_option_string(source, "path")
	var data: Dictionary = _read_json_dictionary(source_path, "registry source", issues)
	if not issues.is_empty():
		return source
	var validation_issues: PackedStringArray = _validate_registry_source_manifest(data)
	if not validation_issues.is_empty():
		_append_string_array(issues, validation_issues)
		return source

	var selected_channel: String = _GF_VARIANT_ACCESS.get_option_string(options, "channel").strip_edges()
	if selected_channel.is_empty():
		selected_channel = _GF_VARIANT_ACCESS.get_option_string(data, "default_channel").strip_edges()
	var channels: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(data, "channels")
	var channel_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(channels, selected_channel)
	if channel_entry.is_empty():
		var _append_missing: bool = issues.append("Registry source channel is missing: %s" % selected_channel)
		return source

	var candidates: PackedStringArray = PackedStringArray()
	var registry: String = _GF_VARIANT_ACCESS.get_option_string(channel_entry, "registry").strip_edges()
	if not registry.is_empty():
		var _append_registry: bool = candidates.append(registry)
	for mirror: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(channel_entry, "mirrors"):
		var text: String = mirror.strip_edges()
		if not text.is_empty():
			var _append_mirror: bool = candidates.append(text)

	var candidate_errors: PackedStringArray = PackedStringArray()
	var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(channel_entry, "registry_sha256").strip_edges().to_lower()
	var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(channel_entry, "registry_size_bytes", 0)
	for index: int in range(candidates.size()):
		var resolved_candidate: String = _resolve_registry_source_reference(candidates[index], source, source_path, project_root)
		var candidate_issues: PackedStringArray = PackedStringArray()
		var result: Dictionary = _prepare_registry_candidate(
			resolved_candidate,
			project_root,
			cache_root,
			candidate_issues,
			expected_sha,
			expected_size,
			options
		)
		if candidate_issues.is_empty():
			result["registry_source_manifest"] = _GF_VARIANT_ACCESS.get_option_string(source, "source")
			result["channel"] = selected_channel
			result["mirror_index"] = index - 1
			if not expected_sha.is_empty():
				result["registry_sha256"] = expected_sha
			if expected_size > 0:
				result["registry_size_bytes"] = expected_size
			return result
		_append_string_array(candidate_errors, candidate_issues)
	_append_string_array(issues, candidate_errors)
	return source


static func _validate_registry_source_manifest(data: Dictionary) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	_append_unsupported_registry_source_signature_issues(data, issues)
	if _GF_VARIANT_ACCESS.get_option_int(data, "schema_version", 0) != 1:
		var _append_schema: bool = issues.append("Registry source manifest schema_version must be 1.")
	var default_channel: String = _GF_VARIANT_ACCESS.get_option_string(data, "default_channel").strip_edges()
	if default_channel.is_empty():
		var _append_default: bool = issues.append("Registry source manifest default_channel is required.")
	var channels: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(data, "channels")
	if channels.is_empty():
		var _append_channels: bool = issues.append("Registry source manifest channels must be a non-empty object.")
		return issues
	if not default_channel.is_empty() and not channels.has(default_channel):
		var _append_missing_default: bool = issues.append("Registry source default_channel is missing from channels: %s" % default_channel)
	for channel_name: String in _sorted_dictionary_keys(channels):
		var channel_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(channels, channel_name)
		if channel_entry.is_empty():
			var _append_entry: bool = issues.append("Registry source channel must be an object: %s" % channel_name)
			continue
		if _GF_VARIANT_ACCESS.get_option_string(channel_entry, "registry").strip_edges().is_empty():
			var _append_registry: bool = issues.append("Registry source channel registry is required: %s" % channel_name)
		var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(channel_entry, "registry_sha256").strip_edges()
		if not expected_sha.is_empty() and not _registry_source_sha_is_valid(expected_sha):
			var _append_sha: bool = issues.append("Registry source channel registry_sha256 must be a sha256 hex digest: %s" % channel_name)
		var raw_size: Variant = channel_entry.get("registry_size_bytes", 0)
		if not _variant_is_blank(raw_size) and not _is_non_negative_int_variant(raw_size):
			var _append_size: bool = issues.append("Registry source channel registry_size_bytes must be a non-negative integer: %s" % channel_name)
		var raw_mirrors: Variant = channel_entry.get("mirrors", [])
		if not (raw_mirrors is Array):
			var _append_mirrors: bool = issues.append("Registry source channel mirrors must be an array: %s" % channel_name)
		else:
			var mirror_values: Array = raw_mirrors
			for mirror_index: int in range(mirror_values.size()):
				var mirror_value: Variant = mirror_values[mirror_index]
				if not (mirror_value is String):
					var _append_mirror_type: bool = issues.append("Registry source channel mirror must be a string: %s[%d]" % [channel_name, mirror_index])
					continue
				var mirror_text_value: String = mirror_value
				var mirror_text: String = mirror_text_value.strip_edges()
				if mirror_text.is_empty():
					var _append_mirror_empty: bool = issues.append("Registry source channel mirror must be non-empty: %s[%d]" % [channel_name, mirror_index])
	return issues


static func _append_unsupported_registry_source_signature_issues(data: Dictionary, issues: PackedStringArray) -> void:
	for field_name: String in UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS:
		if data.has(field_name):
			var _append_root_field: bool = issues.append(
				"Registry source manifest signature field is not supported until native verification is implemented: %s" % field_name
			)
	var channels: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(data, "channels")
	for channel_name: String in _sorted_dictionary_keys(channels):
		var channel_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(channels, channel_name)
		if channel_entry.is_empty():
			continue
		for field_name: String in UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS:
			if channel_entry.has(field_name):
				var _append_channel_field: bool = issues.append(
					"Registry source channel signature field is not supported until native verification is implemented: %s.%s" % [channel_name, field_name]
				)


static func _append_unsupported_registry_package_signature_issues(package_id: String, data: Dictionary, issues: PackedStringArray) -> void:
	for field_name: String in _UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS:
		if data.has(field_name):
			var _append_package_field: bool = issues.append(
				"Registry package signature field is not supported until native verification is implemented: %s.%s" % [package_id, field_name]
			)


static func _resolve_registry_source_reference(
	value: String,
	source: Dictionary,
	source_path: String,
	_project_root: String
) -> String:
	var text: String = value.strip_edges()
	if _is_http_url(text):
		return text
	var source_value: String = _GF_VARIANT_ACCESS.get_option_string(source, "source").strip_edges()
	if _is_http_url(source_value):
		return _join_remote_url(source_value, text)
	if text.begins_with("res://") or text.begins_with("user://") or text.is_absolute_path():
		return text
	return source_path.get_base_dir().path_join(text).replace("\\", "/")


static func _rewrite_remote_registry(
	raw_path: String,
	cache_path: String,
	registry_url: String,
	issues: PackedStringArray
) -> void:
	var data: Dictionary = _read_json_dictionary(raw_path, "downloaded registry", issues)
	if data.is_empty() and not issues.is_empty():
		return
	var packages: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(data, "packages")
	for package_id: String in _sorted_dictionary_keys(packages):
		var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
		var archive: String = _GF_VARIANT_ACCESS.get_option_string(entry, "archive").strip_edges()
		var resolved_archive: String = _resolve_remote_archive_reference(package_id, archive, registry_url, issues)
		if resolved_archive.is_empty():
			continue
		entry["archive"] = resolved_archive
		packages[package_id] = entry
	if not issues.is_empty():
		return
	data["packages"] = packages
	var text: String = JSON.stringify(data, "\t", false) + "\n"
	if not _write_text_file_absolute(cache_path, text, issues, "write cached registry"):
		return


static func _remote_registry_cache_matches_metadata(
	cache_path: String,
	registry_url: String,
	expected_sha: String,
	expected_size: int
) -> bool:
	if expected_sha.is_empty() or expected_size <= 0:
		return false
	if not FileAccess.file_exists(cache_path):
		return false

	var metadata: Dictionary = _read_json_dictionary_if_exists(_remote_registry_cache_metadata_path(cache_path))
	if metadata.is_empty():
		return false
	if _GF_VARIANT_ACCESS.get_option_string(metadata, "registry_url") != registry_url:
		return false
	var normalized_expected_sha: String = expected_sha.strip_edges().to_lower()
	if _GF_VARIANT_ACCESS.get_option_string(metadata, "raw_sha256").to_lower() != normalized_expected_sha:
		return false
	if _GF_VARIANT_ACCESS.get_option_int(metadata, "raw_size_bytes", 0) != expected_size:
		return false
	var cached_sha: String = _GF_VARIANT_ACCESS.get_option_string(metadata, "cache_sha256").to_lower()
	var cached_size: int = _GF_VARIANT_ACCESS.get_option_int(metadata, "cache_size_bytes", 0)
	if cached_sha.is_empty() or cached_size <= 0:
		return false
	if _file_size(cache_path) != cached_size:
		return false
	if FileAccess.get_sha256(cache_path).to_lower() != cached_sha:
		return false
	return not _read_json_dictionary_if_exists(cache_path).is_empty()


static func _write_remote_registry_cache_metadata(
	cache_path: String,
	registry_url: String,
	raw_path: String,
	expected_sha: String,
	expected_size: int,
	issues: PackedStringArray
) -> void:
	var raw_sha: String = expected_sha
	if raw_sha.is_empty() and FileAccess.file_exists(raw_path):
		raw_sha = FileAccess.get_sha256(raw_path).to_lower()
	raw_sha = raw_sha.strip_edges().to_lower()
	var raw_size: int = expected_size
	if raw_size <= 0 and FileAccess.file_exists(raw_path):
		raw_size = _file_size(raw_path)
	if raw_sha.is_empty() or raw_size <= 0:
		return
	if not FileAccess.file_exists(cache_path):
		return
	var cache_sha: String = FileAccess.get_sha256(cache_path).to_lower()
	var cache_size: int = _file_size(cache_path)
	if cache_sha.is_empty() or cache_size <= 0:
		return

	var metadata: Dictionary = {
		"schema_version": 1,
		"registry_url": registry_url,
		"raw_sha256": raw_sha,
		"raw_size_bytes": raw_size,
		"cache_sha256": cache_sha,
		"cache_size_bytes": cache_size,
	}
	var text: String = JSON.stringify(metadata, "\t", false) + "\n"
	var _write_metadata: bool = _write_text_file_absolute(
		_remote_registry_cache_metadata_path(cache_path),
		text,
		issues,
		"write cached registry metadata"
	)


static func _remote_registry_cache_metadata_path(cache_path: String) -> String:
	return cache_path + _REMOTE_REGISTRY_CACHE_METADATA_SUFFIX


static func _read_json_dictionary_if_exists(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


static func _resolve_remote_archive_reference(
	package_id: String,
	archive: String,
	registry_url: String,
	issues: PackedStringArray
) -> String:
	var text: String = archive.strip_edges()
	if text.is_empty():
		return ""
	if _is_http_url(text):
		return text
	if text.begins_with("res://") or text.begins_with("user://") or text.begins_with("//") or text.contains(":"):
		var _append_local: bool = issues.append("%s: remote registry archive reference is not allowed: %s" % [package_id, text])
		return ""

	var parsed_issues: PackedStringArray = PackedStringArray()
	var parsed: Dictionary = _parse_http_url(registry_url, parsed_issues)
	if parsed.is_empty():
		_append_string_array(issues, parsed_issues)
		return ""

	var request_path: String = _GF_VARIANT_ACCESS.get_option_string(parsed, "request_path")
	var query_index: int = request_path.find("?")
	if query_index >= 0:
		request_path = request_path.substr(0, query_index)
	var joined_path: String = text
	if not text.begins_with("/"):
		var base_dir: String = request_path.get_base_dir()
		if base_dir == ".":
			base_dir = "/"
		if not base_dir.ends_with("/"):
			base_dir += "/"
		joined_path = base_dir + text
	var normalized_path: String = _normalize_url_path(joined_path)
	if normalized_path.is_empty():
		var _append_escape: bool = issues.append("%s: remote registry archive path escapes the URL root: %s" % [package_id, text])
		return ""
	var scheme: String = _GF_VARIANT_ACCESS.get_option_string(parsed, "scheme")
	var authority: String = _format_http_authority(parsed)
	return "%s://%s%s" % [scheme, authority, normalized_path]


static func _resolve_cache_dir(project_root: String, options: Dictionary) -> String:
	var cache_dir: String = _GF_VARIANT_ACCESS.get_option_string(options, "cache_dir").strip_edges()
	if cache_dir.is_empty():
		return project_root.path_join(".gf/package_cache").replace("\\", "/")
	return _resolve_path(cache_dir, project_root)


static func _resolve_archive_path(
	archive_path: String,
	registry_path: String,
	package_id: String,
	registry_entry: Dictionary,
	cache_root: String,
	issues: PackedStringArray,
	options: Dictionary = {},
	registry_source: Dictionary = {}
) -> String:
	if _append_cancelled_if_requested(options, issues):
		return ""
	var text: String = archive_path.strip_edges()
	if text.is_empty():
		var _append_missing: bool = issues.append("%s: registry archive path is empty." % package_id)
		return ""
	if _GF_VARIANT_ACCESS.get_option_bool(registry_source, "remote", false):
		if not _is_http_url(text):
			var _append_remote_local: bool = issues.append("%s: remote registry archive must resolve to an HTTP(S) URL: %s" % [package_id, text])
			return ""
		return _cache_remote_archive(package_id, text, registry_entry, cache_root, issues, options)
	var offline_root: String = _GF_VARIANT_ACCESS.get_option_string(registry_source, "offline_bundle_extracted")
	if not offline_root.is_empty():
		if _is_http_url(text) or text.begins_with("res://") or text.begins_with("user://") or text.is_absolute_path() or text.contains(":"):
			var _append_offline_external: bool = issues.append("%s: offline bundle archive must be a relative path inside the bundle cache: %s" % [package_id, text])
			return ""
		var offline_archive_path: String = registry_path.get_base_dir().path_join(text).replace("\\", "/").simplify_path()
		if not _is_path_inside(offline_root, offline_archive_path):
			var _append_offline_outside: bool = issues.append("%s: offline bundle archive path escapes the bundle cache: %s" % [package_id, text])
			return ""
		return offline_archive_path
	if _is_http_url(text):
		return _cache_remote_archive(package_id, text, registry_entry, cache_root, issues, options)
	if text.begins_with("res://") or text.begins_with("user://"):
		return ProjectSettings.globalize_path(text).replace("\\", "/")
	if text.is_absolute_path():
		return text.replace("\\", "/")
	return registry_path.get_base_dir().path_join(text).replace("\\", "/")


static func _cache_remote_archive(
	package_id: String,
	archive_url: String,
	registry_entry: Dictionary,
	cache_root: String,
	issues: PackedStringArray,
	options: Dictionary = {}
) -> String:
	if _append_cancelled_if_requested(options, issues):
		return ""
	var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(registry_entry, "sha256").strip_edges().to_lower()
	var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(registry_entry, "size_bytes", 0)
	if expected_sha.is_empty():
		var _append_sha: bool = issues.append("%s: remote archive requires sha256 in the registry." % package_id)
		return ""
	if expected_size <= 0:
		var _append_size: bool = issues.append("%s: remote archive requires positive size_bytes in the registry." % package_id)
		return ""
	var archive_path: String = cache_root.path_join("archives").path_join("%s-%s.zip" % [_safe_cache_name(package_id), expected_sha.substr(0, 16)])
	if _archive_file_matches_metadata(archive_path, expected_sha, expected_size):
		return archive_path
	var max_bytes: int = mini(MAX_ARCHIVE_DOWNLOAD_BYTES, expected_size + 1)
	if not _download_url_to_file(archive_url, archive_path, "%s archive" % package_id, issues, max_bytes, 0, 0, options):
		return ""
	return archive_path


static func _archive_file_matches_metadata(path: String, expected_sha: String, expected_size: int) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if expected_size > 0 and _file_size(path) != expected_size:
		return false
	if not expected_sha.is_empty() and FileAccess.get_sha256(path).to_lower() != expected_sha:
		return false
	return true


static func _download_url_to_file(
	url: String,
	target_path: String,
	label: String,
	issues: PackedStringArray,
	max_bytes: int,
	redirect_count: int = 0,
	retry_count: int = 0,
	options: Dictionary = {}
) -> bool:
	if _append_cancelled_if_requested(options, issues):
		return false
	if redirect_count > HTTP_MAX_REDIRECTS:
		var _append_redirect_limit: bool = issues.append("%s: too many HTTP redirects." % label)
		return false

	var parsed_url: Dictionary = _parse_http_url(url, issues)
	if parsed_url.is_empty():
		return false

	var client: HTTPClient = HTTPClient.new()
	var use_tls: bool = _GF_VARIANT_ACCESS.get_option_string(parsed_url, "scheme") == "https"
	var tls_options: TLSOptions = TLSOptions.client() if use_tls else null
	var connect_error: Error = client.connect_to_host(
		_GF_VARIANT_ACCESS.get_option_string(parsed_url, "host"),
		_GF_VARIANT_ACCESS.get_option_int(parsed_url, "port"),
		tls_options
	)
	if connect_error != OK:
		var _append_connect: bool = issues.append("%s: download failed: %s" % [label, error_string(connect_error)])
		return false
	if not _poll_http_client(client, label, issues, HTTP_CONNECT_TIMEOUT_MSEC, options):
		return false
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		var _append_status: bool = issues.append("%s: could not connect to remote host." % label)
		return false

	var request_error: Error = client.request(
		HTTPClient.METHOD_GET,
		_GF_VARIANT_ACCESS.get_option_string(parsed_url, "request_path"),
		PackedStringArray(["User-Agent: GF-Package-Installer/1"])
	)
	if request_error != OK:
		var _append_request: bool = issues.append("%s: download request failed: %s" % [label, error_string(request_error)])
		return false
	if not _poll_http_client(client, label, issues, HTTP_READ_TIMEOUT_MSEC, options):
		return false

	var response_code: int = client.get_response_code()
	if response_code >= 300 and response_code < 400:
		var redirect_url: String = _resolve_http_redirect_url(
			_get_http_header_value(client.get_response_headers_as_dictionary(), "location"),
			url,
			parsed_url,
			issues
		)
		client.close()
		if redirect_url.is_empty():
			var _append_redirect: bool = issues.append("%s: redirect response did not include a valid Location header." % label)
			return false
		return _download_url_to_file(redirect_url, target_path, label, issues, max_bytes, redirect_count + 1, retry_count, options)
	if response_code < 200 or response_code >= 300:
		if _http_response_should_retry(response_code) and retry_count < HTTP_RETRY_ATTEMPTS:
			client.close()
			OS.delay_msec(HTTP_RETRY_DELAY_MSEC * (retry_count + 1))
			return _download_url_to_file(url, target_path, label, issues, max_bytes, redirect_count, retry_count + 1, options)
		var _append_response: bool = issues.append("%s: download failed with HTTP %d." % [label, response_code])
		return false

	var temp_path: String = target_path + ".download"
	var make_error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	if make_error != OK:
		var _append_make: bool = issues.append("%s: could not create download cache directory: %s" % [label, error_string(make_error)])
		return false
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var _append_open: bool = issues.append("%s: could not write download cache: %s" % [label, error_string(FileAccess.get_open_error())])
		return false

	var bytes_written: int = 0
	var read_deadline: int = Time.get_ticks_msec() + HTTP_READ_TIMEOUT_MSEC
	while client.get_status() == HTTPClient.STATUS_BODY:
		if _append_cancelled_if_requested(options, issues):
			file.close()
			client.close()
			var _remove_cancelled: Error = DirAccess.remove_absolute(temp_path)
			return false
		var poll_error: Error = client.poll()
		if poll_error != OK:
			file.close()
			var _remove_failed_poll: Error = DirAccess.remove_absolute(temp_path)
			var _append_poll: bool = issues.append("%s: download failed: %s" % [label, error_string(poll_error)])
			return false
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() > read_deadline:
				file.close()
				var _remove_timeout: Error = DirAccess.remove_absolute(temp_path)
				var _append_timeout: bool = issues.append("%s: download timed out." % label)
				return false
			OS.delay_msec(10)
			continue
		read_deadline = Time.get_ticks_msec() + HTTP_READ_TIMEOUT_MSEC
		bytes_written += chunk.size()
		if bytes_written > max_bytes:
			file.close()
			var _remove_large: Error = DirAccess.remove_absolute(temp_path)
			var _append_large: bool = issues.append("%s: remote file exceeded the allowed download limit." % label)
			return false
		var _store_chunk_result: Variant = file.store_buffer(chunk)
	file.close()

	if FileAccess.file_exists(target_path):
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK:
			var _remove_temp: Error = DirAccess.remove_absolute(temp_path)
			var _append_replace: bool = issues.append("%s: could not replace cached download: %s" % [label, error_string(remove_error)])
			return false
	var rename_error: Error = DirAccess.rename_absolute(temp_path, target_path)
	if rename_error != OK:
		var _remove_temp_after_rename: Error = DirAccess.remove_absolute(temp_path)
		var _append_rename: bool = issues.append("%s: could not finalize download cache: %s" % [label, error_string(rename_error)])
		return false
	return true


static func _http_response_should_retry(response_code: int) -> bool:
	return response_code == 408 or response_code == 429 or (response_code >= 500 and response_code <= 599)


static func _get_http_header_value(headers: Dictionary, header_name: String) -> String:
	var expected_name: String = header_name.to_lower()
	for key: Variant in headers.keys():
		var key_text: String = str(key).to_lower()
		if key_text == expected_name:
			return str(headers[key]).strip_edges()
	return ""


static func _resolve_http_redirect_url(
	location: String,
	base_url: String,
	parsed_base_url: Dictionary,
	issues: PackedStringArray
) -> String:
	var text: String = location.strip_edges()
	if text.is_empty():
		return ""
	if _is_http_url(text):
		return _filter_http_redirect_url(text, parsed_base_url, issues)
	if text.begins_with("//"):
		var scheme_relative_url: String = "%s:%s" % [_GF_VARIANT_ACCESS.get_option_string(parsed_base_url, "scheme"), text]
		return _filter_http_redirect_url(scheme_relative_url, parsed_base_url, issues)

	var scheme: String = _GF_VARIANT_ACCESS.get_option_string(parsed_base_url, "scheme")
	var authority: String = _format_http_authority(parsed_base_url)
	if text.begins_with("/"):
		return "%s://%s%s" % [scheme, authority, text]

	var request_path: String = _GF_VARIANT_ACCESS.get_option_string(parsed_base_url, "request_path")
	var query_index: int = request_path.find("?")
	if query_index >= 0:
		request_path = request_path.substr(0, query_index)
	var base_dir: String = request_path.get_base_dir()
	if base_dir == ".":
		base_dir = "/"
	if not base_dir.ends_with("/"):
		base_dir += "/"
	var normalized_path: String = _normalize_url_path(base_dir + text)
	if normalized_path.is_empty():
		var _append_invalid: bool = issues.append("Invalid HTTP redirect Location for %s: %s" % [base_url, location])
		return ""
	return "%s://%s%s" % [scheme, authority, normalized_path]


static func _filter_http_redirect_url(url: String, parsed_base_url: Dictionary, issues: PackedStringArray) -> String:
	var parse_issues: PackedStringArray = PackedStringArray()
	var parsed_redirect: Dictionary = _parse_http_url(url, parse_issues)
	if parsed_redirect.is_empty():
		_append_string_array(issues, parse_issues)
		return ""
	var base_scheme: String = _GF_VARIANT_ACCESS.get_option_string(parsed_base_url, "scheme")
	var redirect_scheme: String = _GF_VARIANT_ACCESS.get_option_string(parsed_redirect, "scheme")
	if base_scheme == "https" and redirect_scheme != "https":
		var _append_downgrade: bool = issues.append("HTTP redirect from https to non-https is not allowed.")
		return ""
	if _format_http_authority(parsed_redirect) != _format_http_authority(parsed_base_url):
		var _append_cross_origin: bool = issues.append("HTTP redirect to a different host is not allowed: %s" % url)
		return ""
	return url


static func _format_http_authority(parsed_url: Dictionary) -> String:
	var scheme: String = _GF_VARIANT_ACCESS.get_option_string(parsed_url, "scheme")
	var host: String = _GF_VARIANT_ACCESS.get_option_string(parsed_url, "host")
	var port: int = _GF_VARIANT_ACCESS.get_option_int(parsed_url, "port")
	var default_port: int = 443 if scheme == "https" else 80
	var authority: String = host
	if authority.find(":") >= 0 and not authority.begins_with("["):
		authority = "[%s]" % authority
	if port != default_port:
		authority = "%s:%d" % [authority, port]
	return authority


static func _normalize_url_path(path: String) -> String:
	var source: String = path
	if not source.begins_with("/"):
		source = "/" + source
	var output: PackedStringArray = PackedStringArray()
	for part: String in source.split("/", false):
		if part.is_empty() or part == ".":
			continue
		if part == "..":
			if output.is_empty():
				return ""
			output.remove_at(output.size() - 1)
			continue
		var _append_part: bool = output.append(part)
	return "/" + "/".join(output)


static func _poll_http_client(
	client: HTTPClient,
	label: String,
	issues: PackedStringArray,
	timeout_msec: int,
	options: Dictionary = {}
) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_msec
	while _http_status_is_pending(client.get_status()):
		if _append_cancelled_if_requested(options, issues):
			client.close()
			return false
		var poll_error: Error = client.poll()
		if poll_error != OK:
			var _append_poll: bool = issues.append("%s: download failed: %s" % [label, error_string(poll_error)])
			return false
		if _http_status_is_error(client.get_status()):
			var _append_status: bool = issues.append("%s: download failed with connection status %d." % [label, client.get_status()])
			return false
		if Time.get_ticks_msec() > deadline:
			var _append_timeout: bool = issues.append("%s: download timed out." % label)
			return false
		OS.delay_msec(10)
	if _http_status_is_error(client.get_status()):
		var _append_final_status: bool = issues.append("%s: download failed with connection status %d." % [label, client.get_status()])
		return false
	return true


static func _http_status_is_pending(status: int) -> bool:
	return (
		status == HTTPClient.STATUS_RESOLVING
		or status == HTTPClient.STATUS_CONNECTING
		or status == HTTPClient.STATUS_REQUESTING
	)


static func _http_status_is_error(status: int) -> bool:
	return (
		status == HTTPClient.STATUS_CANT_RESOLVE
		or status == HTTPClient.STATUS_CANT_CONNECT
		or status == HTTPClient.STATUS_CONNECTION_ERROR
		or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR
	)


static func _parse_http_url(url: String, issues: PackedStringArray) -> Dictionary:
	var text: String = url.strip_edges()
	var scheme_separator: int = text.find("://")
	if scheme_separator <= 0:
		var _append_scheme: bool = issues.append("Invalid HTTP URL: %s" % url)
		return {}
	var scheme: String = text.substr(0, scheme_separator).to_lower()
	if scheme != "http" and scheme != "https":
		var _append_protocol: bool = issues.append("Unsupported HTTP URL scheme: %s" % scheme)
		return {}
	var remainder: String = text.substr(scheme_separator + 3)
	var slash_index: int = remainder.find("/")
	var authority: String = remainder if slash_index < 0 else remainder.substr(0, slash_index)
	var request_path: String = "/" if slash_index < 0 else remainder.substr(slash_index)
	var fragment_index: int = request_path.find("#")
	if fragment_index >= 0:
		request_path = request_path.substr(0, fragment_index)
	if request_path.is_empty():
		request_path = "/"

	var host: String = authority
	var port: int = 443 if scheme == "https" else 80
	if authority.begins_with("["):
		var bracket_end: int = authority.find("]")
		if bracket_end < 0:
			var _append_ipv6: bool = issues.append("Invalid HTTP URL host: %s" % url)
			return {}
		host = authority.substr(1, bracket_end - 1)
		var port_suffix: String = authority.substr(bracket_end + 1)
		if port_suffix.begins_with(":"):
			var port_text: String = port_suffix.substr(1)
			if not port_text.is_valid_int():
				var _append_port: bool = issues.append("Invalid HTTP URL port: %s" % url)
				return {}
			port = port_text.to_int()
	else:
		var colon_index: int = authority.rfind(":")
		if colon_index > 0:
			var port_text: String = authority.substr(colon_index + 1)
			if port_text.is_valid_int():
				host = authority.substr(0, colon_index)
				port = port_text.to_int()
	if host.is_empty() or port <= 0 or port > 65535:
		var _append_host: bool = issues.append("Invalid HTTP URL host or port: %s" % url)
		return {}
	return {
		"scheme": scheme,
		"host": host,
		"port": port,
		"request_path": request_path,
	}


static func _join_remote_url(base_url: String, relative_url: String) -> String:
	if _is_http_url(relative_url):
		return relative_url
	var parsed_issues: PackedStringArray = PackedStringArray()
	var parsed: Dictionary = _parse_http_url(base_url, parsed_issues)
	if parsed.is_empty():
		return relative_url
	var scheme: String = _GF_VARIANT_ACCESS.get_option_string(parsed, "scheme")
	var host: String = _GF_VARIANT_ACCESS.get_option_string(parsed, "host")
	var port: int = _GF_VARIANT_ACCESS.get_option_int(parsed, "port")
	var request_path: String = _GF_VARIANT_ACCESS.get_option_string(parsed, "request_path")
	var default_port: int = 443 if scheme == "https" else 80
	var authority: String = host if port == default_port else "%s:%d" % [host, port]
	var joined_path: String = relative_url
	if not relative_url.begins_with("/"):
		joined_path = request_path.get_base_dir().path_join(relative_url)
	joined_path = joined_path.simplify_path()
	if not joined_path.begins_with("/"):
		joined_path = "/" + joined_path
	return "%s://%s%s" % [scheme, authority, joined_path]


static func _safe_cache_name(value: String) -> String:
	var result: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if _is_safe_cache_name_character(character):
			result += character
		else:
			result += "-"
	result = result.strip_edges(false, true)
	while result.begins_with("-"):
		result = result.substr(1)
	while result.ends_with("-"):
		result = result.substr(0, result.length() - 1)
	return result if not result.is_empty() else "package"


static func _is_safe_cache_name_character(value: String) -> bool:
	if value == "-" or value == "_":
		return true
	if value.is_empty():
		return false
	var code: int = value.unicode_at(0)
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
	)


static func _sha256_text(value: String) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var _update_error: Error = context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


static func _normalize_archive_name(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/")
	if normalized.begins_with("res://") or normalized.contains(":"):
		return ""
	while normalized.begins_with("./"):
		normalized = normalized.substr(2)
	while normalized.begins_with("/"):
		normalized = normalized.substr(1)
	var parts: PackedStringArray = normalized.split("/", false)
	var safe_parts: PackedStringArray = PackedStringArray()
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..":
			return ""
		var _append_part: bool = safe_parts.append(part)
	return "/".join(safe_parts)


static func _path_matches_any_manifest_path(path: String, manifest_paths: PackedStringArray) -> bool:
	for manifest_path: String in manifest_paths:
		var normalized: String = _normalize_manifest_path(manifest_path)
		if normalized.is_empty():
			continue
		if normalized.ends_with("/**"):
			var prefix: String = _trim_trailing_path_separators(normalized.substr(0, normalized.length() - 3))
			if path == prefix or path.begins_with(prefix + "/"):
				return true
			continue
		if normalized.contains("*") or normalized.contains("?"):
			if _wildcard_match(normalized, path):
				return true
			continue
		if path == normalized:
			return true
	return false


static func _wildcard_match(pattern: String, value: String) -> bool:
	var pattern_index: int = 0
	var value_index: int = 0
	var star_index: int = -1
	var match_index: int = 0
	while value_index < value.length():
		if (
			pattern_index < pattern.length()
			and (
				pattern.substr(pattern_index, 1) == "?"
				or pattern.substr(pattern_index, 1) == value.substr(value_index, 1)
			)
		):
			pattern_index += 1
			value_index += 1
		elif pattern_index < pattern.length() and pattern.substr(pattern_index, 1) == "*":
			star_index = pattern_index
			match_index = value_index
			pattern_index += 1
		elif star_index >= 0:
			pattern_index = star_index + 1
			match_index += 1
			value_index = match_index
		else:
			return false
	while pattern_index < pattern.length() and pattern.substr(pattern_index, 1) == "*":
		pattern_index += 1
	return pattern_index == pattern.length()


static func _archive_path_has_blocked_dir(path: String) -> bool:
	var parts: PackedStringArray = path.split("/", false)
	for part: String in parts:
		for blocked_dir: String in BLOCKED_DIR_NAMES:
			if part.to_lower() == blocked_dir.to_lower():
				return true
	return false


static func _archive_path_has_blocked_file(path: String) -> bool:
	var file_name: String = path.get_file()
	for blocked_file: String in BLOCKED_FILE_NAMES:
		if file_name.to_lower() == blocked_file.to_lower():
			return true
	var lower_name: String = file_name.to_lower()
	for suffix: String in BLOCKED_SUFFIXES:
		if lower_name.ends_with(suffix.to_lower()):
			return true
	return false


static func _runtime_package_has_external_tool_payload(package_id: String, registry_entry: Dictionary, path: String) -> bool:
	if package_id.begins_with("gf.tool.") or _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind") == "tool":
		return false
	var file_name: String = path.get_file().to_lower()
	for blocked_file: String in _RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_FILES:
		if file_name == blocked_file.to_lower():
			return true
	for suffix: String in _RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_SUFFIXES:
		if file_name.ends_with(suffix.to_lower()):
			return true
	return false


static func _project_target_path(project_root: String, relative_path: String, issues: PackedStringArray) -> String:
	var normalized: String = _normalize_archive_name(relative_path)
	if normalized.is_empty():
		var _append_path: bool = issues.append("Package file path is unsafe: %s" % relative_path)
		return ""
	var target_path: String = project_root.path_join(normalized).replace("\\", "/")
	if not _is_path_inside(project_root, target_path):
		var _append_outside: bool = issues.append("Package file target is outside project root: %s" % target_path)
		return ""
	return target_path


static func _make_parent_dirs(
	directory_path: String,
	project_root: String,
	created_dirs: PackedStringArray,
	issues: PackedStringArray
) -> bool:
	var normalized_directory: String = _trim_trailing_path_separators(directory_path.replace("\\", "/"))
	if not _is_path_inside(project_root, normalized_directory):
		var _append_outside: bool = issues.append("Package directory is outside project root: %s" % normalized_directory)
		return false
	if DirAccess.dir_exists_absolute(normalized_directory):
		return true

	var missing: PackedStringArray = PackedStringArray()
	var cursor: String = normalized_directory
	var normalized_root: String = _trim_trailing_path_separators(project_root.replace("\\", "/"))
	while _is_path_inside(normalized_root, cursor) and cursor != normalized_root and not DirAccess.dir_exists_absolute(cursor):
		var _append_missing: bool = missing.append(cursor)
		cursor = cursor.get_base_dir()

	var make_error: Error = DirAccess.make_dir_recursive_absolute(normalized_directory)
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create package directory: %s" % error_string(make_error))
		return false
	for index: int in range(missing.size() - 1, -1, -1):
		var _append_created: bool = created_dirs.append(missing[index])
	return true


static func _copy_file(source_path: String, target_path: String, issues: PackedStringArray, context: String) -> bool:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		var _append_open_source: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	var source_length: int = source_file.get_length()
	var source_sha: String = FileAccess.get_sha256(source_path).to_lower()
	var make_error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	if make_error != OK:
		source_file.close()
		var _append_make: bool = issues.append("Could not create directory for %s: %s" % [context, error_string(make_error)])
		return false
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		source_file.close()
		var _append_open_target: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	while source_file.get_position() < source_file.get_length():
		var remaining: int = source_file.get_length() - source_file.get_position()
		var chunk_size: int = mini(FILE_COPY_CHUNK_BYTES, remaining)
		var chunk: PackedByteArray = source_file.get_buffer(chunk_size)
		if source_file.get_error() != OK:
			var _append_read: bool = issues.append("Could not read while copying %s: %s" % [context, error_string(source_file.get_error())])
			source_file.close()
			target_file.close()
			return false
		var _store_chunk_result: Variant = target_file.store_buffer(chunk)
		if target_file.get_error() != OK:
			var _append_write: bool = issues.append("Could not write while copying %s: %s" % [context, error_string(target_file.get_error())])
			source_file.close()
			target_file.close()
			return false
	source_file.close()
	target_file.close()
	if _file_size(target_path) != source_length:
		var _append_size: bool = issues.append("Copied file size mismatch while copying %s: %s" % [context, target_path])
		return false
	if not source_sha.is_empty() and FileAccess.get_sha256(target_path).to_lower() != source_sha:
		var _append_sha: bool = issues.append("Copied file sha256 mismatch while copying %s: %s" % [context, target_path])
		return false
	return true


static func _read_binary_file(path: String, issues: PackedStringArray, context: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var _append_open: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return PackedByteArray()
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	return bytes


static func _write_binary_file(path: String, bytes: PackedByteArray, issues: PackedStringArray, context: String) -> bool:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create directory for %s: %s" % [context, error_string(make_error)])
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var _append_open: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	var _store_bytes_result: Variant = file.store_buffer(bytes)
	file.close()
	return true


static func _write_text_file_absolute(path: String, text: String, issues: PackedStringArray, context: String) -> bool:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create directory for %s: %s" % [context, error_string(make_error)])
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var _append_open: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	var _store_text_result: Variant = file.store_string(text)
	file.close()
	return true


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


static func _make_temp_root(project_root: String) -> String:
	return project_root.path_join(".gf/package_temp/native_install_%d" % Time.get_ticks_usec()).replace("\\", "/")


static func _remove_path_recursive_absolute(path: String) -> void:
	var normalized: String = _trim_trailing_path_separators(path.strip_edges().replace("\\", "/"))
	if normalized.is_empty() or normalized == "/" or normalized.length() < 4:
		return
	if FileAccess.file_exists(normalized):
		var _remove_file_error: Error = DirAccess.remove_absolute(normalized)
		return
	if not DirAccess.dir_exists_absolute(normalized):
		return

	var directory: DirAccess = DirAccess.open(normalized)
	if directory != null:
		var list_error: Error = directory.list_dir_begin()
		if list_error == OK:
			while true:
				var item_name: String = directory.get_next()
				if item_name.is_empty():
					break
				if item_name == "." or item_name == "..":
					continue
				_remove_path_recursive_absolute(normalized.path_join(item_name))
			directory.list_dir_end()
	var _remove_dir_error: Error = DirAccess.remove_absolute(normalized)


static func _is_path_inside(root_path: String, child_path: String) -> bool:
	var root: String = _trim_trailing_path_separators(root_path.replace("\\", "/").simplify_path())
	var child: String = _trim_trailing_path_separators(child_path.replace("\\", "/").simplify_path())
	return child == root or child.begins_with(root + "/")


static func _resolve_dependency_closure(packages: Dictionary, roots: PackedStringArray) -> Dictionary:
	var order: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	var visiting: PackedStringArray = PackedStringArray()
	var visited: Dictionary = {}
	for package_id: String in roots:
		if not _package_id_is_valid(package_id):
			var _append_root_issue: bool = issues.append("Invalid package id: %s" % package_id)
			continue
		_visit_dependency(package_id, packages, order, issues, visiting, visited)
	return { "order": order, "issues": _packed_to_array(issues) }


static func _visit_dependency(
	package_id: String,
	packages: Dictionary,
	order: PackedStringArray,
	issues: PackedStringArray,
	visiting: PackedStringArray,
	visited: Dictionary
) -> void:
	if not _package_id_is_valid(package_id):
		var _append_invalid_id: bool = issues.append("Invalid package id: %s" % package_id)
		return
	if visited.has(package_id):
		return
	if visiting.has(package_id):
		var cycle: PackedStringArray = PackedStringArray()
		var start_index: int = visiting.find(package_id)
		for index: int in range(start_index, visiting.size()):
			var _append_cycle_item: bool = cycle.append(visiting[index])
		var _append_cycle_root: bool = cycle.append(package_id)
		var _append_cycle_issue: bool = issues.append("Package dependency cycle: %s" % " -> ".join(cycle))
		return
	if not packages.has(package_id):
		var _append_missing: bool = issues.append("Missing package: %s" % package_id)
		return

	var _append_visiting: bool = visiting.append(package_id)
	var package_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
	for dependency_id: String in _package_dependency_ids(package_entry):
		if not _package_id_is_valid(dependency_id):
			var _append_dependency_issue: bool = issues.append("%s: invalid dependency package id: %s" % [package_id, dependency_id])
			continue
		_visit_dependency(dependency_id, packages, order, issues, visiting, visited)
	var _removed: bool = _remove_string(visiting, package_id)
	visited[package_id] = true
	_append_unique(order, package_id)


static func _recompute_required_by(installed: Dictionary, packages: Dictionary) -> void:
	for raw_package_id: Variant in installed.keys():
		var package_id: String = _GF_VARIANT_ACCESS.to_text(raw_package_id)
		var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		entry["required_by"] = []
		installed[package_id] = entry
	for package_id: String in _sorted_dictionary_keys(installed):
		var registry_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
		for dependency_id: String in _package_dependency_ids(registry_entry):
			if not installed.has(dependency_id):
				continue
			var dependency_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, dependency_id)
			var required_by: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(dependency_entry, "required_by")
			_append_unique(required_by, package_id)
			required_by.sort()
			dependency_entry["required_by"] = _packed_to_array(required_by)
			installed[dependency_id] = dependency_entry


static func _prune_dependency_only_packages(installed: Dictionary, packages: Dictionary, force: bool) -> PackedStringArray:
	var pruned: PackedStringArray = PackedStringArray()
	var changed: bool = true
	while changed:
		changed = false
		_recompute_required_by(installed, packages)
		for package_id: String in _sorted_dictionary_keys(installed):
			var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
			var reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "reason")
			var required_by: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "required_by")
			if _string_set_within(reasons, PackedStringArray(["dependency"])) and required_by.is_empty():
				if package_id == "gf.kernel" and not force:
					continue
				var _removed: bool = installed.erase(package_id)
				_append_unique(pruned, package_id)
				changed = true
	return pruned


static func _collect_dependency_prune_blockers(
	installed_after_requested_removal: Dictionary,
	packages: Dictionary,
	project_root: String,
	force: bool,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var blockers: Array[Dictionary] = []
	if force:
		return blockers

	var installed: Dictionary = installed_after_requested_removal.duplicate(true)
	var changed: bool = true
	while changed:
		if _is_cancel_requested(options):
			return blockers
		changed = false
		_recompute_required_by(installed, packages)
		for package_id: String in _sorted_dictionary_keys(installed):
			var entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
			var reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "reason")
			var required_by: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "required_by")
			if not (_string_set_within(reasons, PackedStringArray(["dependency"])) and required_by.is_empty()):
				continue
			if package_id == "gf.kernel":
				continue

			var references: Array[Dictionary] = scan_project_references(project_root, packages, package_id, options)
			if not references.is_empty():
				if not _blockers_have_package_id(blockers, package_id):
					blockers.append({
						"id": package_id,
						"reason": "project_references",
						"references": references.slice(0, 20),
					})
				continue

			var _removed: bool = installed.erase(package_id)
			changed = true
	return blockers


static func _blockers_have_package_id(blockers: Array[Dictionary], package_id: String) -> bool:
	for blocker: Dictionary in blockers:
		if _GF_VARIANT_ACCESS.get_option_string(blocker, "id") == package_id:
			return true
	return false


static func _with_project_reference_scan_cache(project_root: String, options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate()
	if not _get_project_reference_scan_cache(project_root, result).is_empty():
		return result
	result[_PROJECT_REFERENCE_SCAN_CACHE_KEY] = _make_project_reference_scan_cache(project_root, options)
	return result


static func _make_project_reference_scan_cache(project_root: String, options: Dictionary) -> Dictionary:
	var files: PackedStringArray = _collect_project_scan_files(project_root, options)
	var sources: Dictionary = {}
	for absolute_path: String in files:
		if _is_cancel_requested(options):
			break
		sources[absolute_path] = _read_text_file(absolute_path)
	return {
		"project_root": project_root,
		"files": _packed_to_array(files),
		"sources": sources,
	}


static func _get_project_reference_scan_cache(project_root: String, options: Dictionary) -> Dictionary:
	var raw_cache: Variant = options.get(_PROJECT_REFERENCE_SCAN_CACHE_KEY)
	if not raw_cache is Dictionary:
		return {}
	var cache: Dictionary = raw_cache
	if _GF_VARIANT_ACCESS.get_option_string(cache, "project_root") != project_root:
		return {}
	return cache


static func _get_project_reference_scan_files(
	project_root: String,
	scan_cache: Dictionary,
	options: Dictionary
) -> PackedStringArray:
	if scan_cache.is_empty():
		return _collect_project_scan_files(project_root, options)
	return _GF_VARIANT_ACCESS.get_option_packed_string_array(scan_cache, "files")


static func _get_project_reference_scan_source(absolute_path: String, scan_cache: Dictionary) -> String:
	if scan_cache.is_empty():
		return _read_text_file(absolute_path)
	var sources: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(scan_cache, "sources")
	if not sources.has(absolute_path):
		return _read_text_file(absolute_path)
	return _GF_VARIANT_ACCESS.to_text(sources.get(absolute_path, ""))


static func _collect_project_scan_files(project_root: String, options: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if _is_cancel_requested(options) or not DirAccess.dir_exists_absolute(project_root):
		return result
	_collect_project_scan_files_recursive(project_root, project_root, result, options)
	result.sort()
	return result


static func _collect_project_scan_files_recursive(
	root: String,
	current: String,
	result: PackedStringArray,
	options: Dictionary = {}
) -> void:
	if _is_cancel_requested(options):
		return
	var directory: DirAccess = DirAccess.open(current)
	if directory == null:
		return
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return
	while true:
		if _is_cancel_requested(options):
			break
		var item_name: String = directory.get_next()
		if item_name.is_empty():
			break
		if item_name == "." or item_name == "..":
			continue
		var absolute_path: String = current.path_join(item_name)
		var relative_path: String = _relative_to_root(absolute_path, root)
		if directory.current_is_dir():
			if _is_excluded_project_path(relative_path + "/"):
				continue
			_collect_project_scan_files_recursive(root, absolute_path, result, options)
			continue
		if _is_excluded_project_path(relative_path):
			continue
		var extension: String = "." + absolute_path.get_extension().to_lower()
		if item_name == "project.godot" or PROJECT_SCAN_EXTENSIONS.has(extension):
			var _append_path: bool = result.append(absolute_path)
	directory.list_dir_end()


static func _collect_package_class_names(
	project_root: String,
	package_entry: Dictionary,
	options: Dictionary = {}
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for pattern: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(package_entry, "paths"):
		if _is_cancel_requested(options):
			return result
		for absolute_path: String in _expand_package_pattern(project_root, pattern, options):
			if _is_cancel_requested(options):
				return result
			if absolute_path.get_extension().to_lower() != "gd":
				continue
			var source: String = _read_text_file(absolute_path)
			for script_class_name: String in _extract_class_names(source):
				_append_unique(result, script_class_name)
	result.sort()
	return result


static func _expand_package_pattern(project_root: String, pattern: String, options: Dictionary = {}) -> PackedStringArray:
	var normalized: String = _normalize_manifest_path(pattern)
	var result: PackedStringArray = PackedStringArray()
	if normalized.is_empty() or _is_cancel_requested(options):
		return result
	if normalized.ends_with("/**"):
		var directory_path: String = project_root.path_join(normalized.substr(0, normalized.length() - 3))
		_collect_files_recursive(directory_path, result, options)
		result.sort()
		return result
	if not normalized.contains("*") and not normalized.contains("?") and not normalized.contains("["):
		var absolute_path: String = project_root.path_join(normalized)
		if FileAccess.file_exists(absolute_path):
			var _append_file: bool = result.append(absolute_path)
	return result


static func _collect_files_recursive(directory_path: String, result: PackedStringArray, options: Dictionary = {}) -> void:
	if _is_cancel_requested(options):
		return
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return
	while true:
		if _is_cancel_requested(options):
			break
		var item_name: String = directory.get_next()
		if item_name.is_empty():
			break
		if item_name == "." or item_name == "..":
			continue
		var absolute_path: String = directory_path.path_join(item_name)
		if directory.current_is_dir():
			_collect_files_recursive(absolute_path, result, options)
		else:
			var _append_path: bool = result.append(absolute_path)
	directory.list_dir_end()


static func _extract_class_names(source: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n", false):
		var stripped: String = line.strip_edges()
		if not stripped.begins_with("class_name "):
			continue
		var parts: PackedStringArray = stripped.split(" ", false)
		if parts.size() >= 2:
			_append_unique(result, parts[1].strip_edges())
	return result


static func _package_path_tokens(paths: PackedStringArray) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var normalized: String = _normalize_manifest_path(path)
		if normalized.is_empty():
			continue
		if normalized.ends_with("/**"):
			normalized = _trim_trailing_path_separators(normalized.substr(0, normalized.length() - 3))
		_append_unique(tokens, normalized)
		_append_unique(tokens, "res://" + normalized)
	return tokens


static func _package_dependency_ids(registry_entry: Dictionary) -> PackedStringArray:
	if _GF_VARIANT_ACCESS.get_option_string(registry_entry, "kind") == "preset":
		return _GF_VARIANT_ACCESS.get_option_packed_string_array(registry_entry, "packages")
	return _GF_VARIANT_ACCESS.get_option_packed_string_array(registry_entry, "dependencies")


static func _lock_entry_changed(left: Dictionary, right: Dictionary) -> bool:
	var left_reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(left, "reason")
	var right_reasons: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(right, "reason")
	left_reasons.sort()
	right_reasons.sort()
	return (
		_GF_VARIANT_ACCESS.get_option_string(left, "version") != _GF_VARIANT_ACCESS.get_option_string(right, "version")
		or _GF_VARIANT_ACCESS.get_option_string(left, "sha256") != _GF_VARIANT_ACCESS.get_option_string(right, "sha256")
		or left_reasons != right_reasons
	)


static func _framework_compatibility_issues(
	registry: Dictionary,
	registry_packages: Dictionary,
	package_ids: PackedStringArray,
	current_framework_version: String
) -> PackedStringArray:
	var issues: PackedStringArray = _compatibility_range_issues(
		"registry",
		current_framework_version,
		_GF_VARIANT_ACCESS.get_option_string(registry, "minimum_framework_version"),
		_GF_VARIANT_ACCESS.get_option_string(registry, "maximum_framework_version_exclusive")
	)
	_append_string_array(issues, _registry_packages_compatibility_issues(
		registry_packages,
		package_ids,
		current_framework_version
	))
	return issues


static func _registry_packages_compatibility_issues(
	registry_packages: Dictionary,
	package_ids: PackedStringArray,
	current_framework_version: String
) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for package_id: String in package_ids:
		var package_entry: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(registry_packages, package_id)
		_append_string_array(issues, _compatibility_range_issues(
			"package %s" % package_id,
			current_framework_version,
			_GF_VARIANT_ACCESS.get_option_string(package_entry, "minimum_framework_version"),
			_GF_VARIANT_ACCESS.get_option_string(package_entry, "maximum_framework_version_exclusive")
		))
	return issues


static func _compatibility_range_issues(
	label: String,
	current_framework_version: String,
	minimum_framework_version: String,
	maximum_framework_version_exclusive: String
) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var current_version: PackedInt32Array = _parse_semver(current_framework_version)
	if current_version.is_empty():
		return issues

	var minimum_version: PackedInt32Array = _parse_semver(minimum_framework_version)
	if not minimum_framework_version.strip_edges().is_empty() and minimum_version.is_empty():
		var _append_minimum_format_issue: bool = issues.append("%s: minimum_framework_version is not SemVer: %s" % [label, minimum_framework_version])
	elif not minimum_version.is_empty() and _compare_semver(current_version, minimum_version) < 0:
		var _append_minimum_issue: bool = issues.append(
			"%s: target GF framework version %s is lower than minimum_framework_version %s" % [
				label,
				current_framework_version,
				minimum_framework_version,
			]
		)

	var maximum_version: PackedInt32Array = _parse_semver(maximum_framework_version_exclusive)
	if not maximum_framework_version_exclusive.strip_edges().is_empty() and maximum_version.is_empty():
		var _append_maximum_format_issue: bool = issues.append("%s: maximum_framework_version_exclusive is not SemVer: %s" % [label, maximum_framework_version_exclusive])
	elif not maximum_version.is_empty() and _compare_semver(current_version, maximum_version) >= 0:
		var _append_maximum_issue: bool = issues.append(
			"%s: target GF framework version %s must be lower than maximum_framework_version_exclusive %s" % [
				label,
				current_framework_version,
				maximum_framework_version_exclusive,
			]
		)
	return issues


static func _parse_semver(version: String) -> PackedInt32Array:
	var text: String = version.strip_edges()
	if text.begins_with("v"):
		text = text.substr(1)
	var pieces: PackedStringArray = text.split(".", false)
	if pieces.size() != 3:
		return PackedInt32Array()
	var result: PackedInt32Array = PackedInt32Array()
	for piece: String in pieces:
		if not _string_is_digits(piece):
			return PackedInt32Array()
		var _append_piece: bool = result.append(piece.to_int())
	return result


static func _compare_semver(left: PackedInt32Array, right: PackedInt32Array) -> int:
	for index: int in range(3):
		if left[index] < right[index]:
			return -1
		if left[index] > right[index]:
			return 1
	return 0


static func _string_is_digits(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


static func _read_project_framework_version(project_root: String) -> String:
	var config_path: String = project_root.path_join("addons/gf/plugin.cfg")
	if not FileAccess.file_exists(config_path):
		return ""
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(config_path)
	if load_error != OK:
		return ""
	return _GF_VARIANT_ACCESS.to_text(config.get_value("plugin", "version", "")).strip_edges()


static func _empty_lockfile() -> Dictionary:
	return {
		"schema_version": LOCKFILE_SCHEMA_VERSION,
		"framework_version": "",
		"installed": {},
	}


static func _resolve_project_root(path: String) -> String:
	var text: String = path.strip_edges()
	if text.is_empty() or text == ".":
		return _trim_trailing_path_separators(ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path())
	if text.begins_with("res://") or text.begins_with("user://"):
		return _trim_trailing_path_separators(ProjectSettings.globalize_path(text).replace("\\", "/").simplify_path())
	return _trim_trailing_path_separators(text.replace("\\", "/").simplify_path())


static func _resolve_path(path: String, base_root: String) -> String:
	var text: String = path.strip_edges()
	if text.begins_with("res://") or text.begins_with("user://"):
		return ProjectSettings.globalize_path(text).replace("\\", "/").simplify_path()
	if text.is_absolute_path():
		return text.replace("\\", "/").simplify_path()
	return base_root.path_join(text).replace("\\", "/").simplify_path()


static func _resolve_lockfile_path(project_root: String, lockfile_path: String) -> String:
	return _resolve_path(lockfile_path, project_root)


static func _append_lockfile_path_issues(
	project_root: String,
	resolved_lockfile_path: String,
	raw_lockfile_path: String,
	issues: PackedStringArray
) -> void:
	if raw_lockfile_path.strip_edges().is_empty():
		var _append_empty: bool = issues.append("Lockfile path is required.")
		return
	if not _is_path_inside(project_root, resolved_lockfile_path):
		var _append_outside: bool = issues.append("Lockfile path must stay inside project root: %s" % resolved_lockfile_path)


static func _display_path(path: String) -> String:
	return path.replace("\\", "/")


static func _normalize_manifest_path(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/")
	if normalized.begins_with("res://"):
		normalized = normalized.substr("res://".length())
	if normalized.begins_with("./"):
		normalized = normalized.substr(2)
	return _strip_path_edges(normalized)


static func _strip_path_edges(path: String) -> String:
	var result: String = path.strip_edges()
	while result.begins_with("/") or result.begins_with("\\"):
		result = result.substr(1)
	return _trim_trailing_path_separators(result)


static func _trim_trailing_path_separators(path: String) -> String:
	var result: String = path
	while result.length() > 1 and (result.ends_with("/") or result.ends_with("\\")):
		result = result.substr(0, result.length() - 1)
	return result


static func _relative_to_root(absolute_path: String, root: String) -> String:
	var normalized_path: String = absolute_path.replace("\\", "/")
	var normalized_root: String = _trim_trailing_path_separators(root.replace("\\", "/"))
	if normalized_path.begins_with(normalized_root + "/"):
		return normalized_path.substr(normalized_root.length() + 1)
	return normalized_path


static func _read_text_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _is_http_url(path: String) -> bool:
	var text: String = path.strip_edges().to_lower()
	return text.begins_with("http://") or text.begins_with("https://")


static func _is_excluded_project_path(relative_path: String) -> bool:
	var normalized: String = relative_path.replace("\\", "/")
	for prefix: String in PROJECT_SCAN_EXCLUDED_PREFIXES:
		if normalized.begins_with(prefix):
			return true
	return false


static func _source_contains_identifier(source: String, identifier: String) -> bool:
	var start: int = 0
	while true:
		var index: int = source.find(identifier, start)
		if index < 0:
			return false
		var before: String = source.substr(index - 1, 1) if index > 0 else ""
		var after_index: int = index + identifier.length()
		var after: String = source.substr(after_index, 1) if after_index < source.length() else ""
		if not _is_identifier_character(before) and not _is_identifier_character(after):
			return true
		start = index + identifier.length()
	return false


static func _is_identifier_character(value: String) -> bool:
	if value.is_empty():
		return false
	var code: int = value.unicode_at(0)
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
		or value == "_"
	)


static func _sorted_dictionary_keys(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _append_key: bool = result.append(_GF_VARIANT_ACCESS.to_text(raw_key))
	result.sort()
	return result


static func _sort_dictionary_by_key(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in _sorted_dictionary_keys(data):
		result[key] = _GF_VARIANT_ACCESS.duplicate_variant(data.get(key, {}), true)
	return result


static func _append_string_array(target: PackedStringArray, source: PackedStringArray) -> void:
	for item: String in source:
		var _append_item: bool = target.append(item)


static func _append_unique(values: PackedStringArray, value: String) -> void:
	if not value.is_empty() and not values.has(value):
		var _append_value: bool = values.append(value)


static func _remove_string(values: PackedStringArray, value: String) -> bool:
	var index: int = values.find(value)
	if index < 0:
		return false
	values.remove_at(index)
	return true


static func _intersect_strings(left: PackedStringArray, right: Array[String]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in left:
		if right.has(item):
			_append_unique(result, item)
	result.sort()
	return result


static func _string_set_within(values: PackedStringArray, allowed: PackedStringArray) -> bool:
	for value: String in values:
		if not allowed.has(value):
			return false
	return true


static func _make_string_lookup(values: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values:
		if not value.is_empty():
			result[value] = true
	return result


static func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
