# 只在当前已打开项目中读取文件依赖；不加载 Resource，不实例化业务场景。
@tool
extends RefCounted


# --- 常量 ---

## 纯数据结构和摘要权威。
## [br]
## @api private
const _DEPENDENCIES_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_dependencies.gd")


# --- 私有变量 ---

## 当前冻结输入及有限捕获状态。
## [br]
## @api private
var _capture: Dictionary = {}

## 已准入的排序文件路径。
## [br]
## @api private
var _files: PackedStringArray = []

## 当前项目中的捕获根 URI。
## [br]
## @api private
var _root: String = ""

## 原始读取和复核读取分别维护游标。
## [br]
## @api private
var _cursor: int = 0

## 是否进入内容复核阶段。
## [br]
## @api private
var _verifying: bool = false

## 是否已有终态。
## [br]
## @api private
var _finished: bool = true

## 只允许收紧的捕获限额。
## [br]
## @api private
var _limits: Dictionary = {}

## 已捕获源文件字节数；复核最多再读取相同字节数。
## [br]
## @api private
var _bytes: int = 0

## 累计原始依赖条数。
## [br]
## @api private
var _edges: int = 0

## 当前引擎可识别的资源扩展名。
## [br]
## @api private
var _extensions: PackedStringArray = []


# --- 框架内部方法 ---

## 开始捕获当前项目已准入库存；不访问绝对外部项目。
## [br]
## @api framework_internal
## [br]
## @param snapshot: 已冻结的 Project Layout 库存。
## [br]
## @schema snapshot: Dictionary，至少包含scope:Dictionary、root_path:String、files:Array[String]。根必须为当前项目res://范围。
## [br]
## @param options: 可选收紧限额。
## [br]
## @schema options: Dictionary，可含max_files:int<=4096、max_edges:int<=16384、max_file_bytes:int<=4194304、max_total_bytes:int<=33554432；均为正整数。每次原生get_dependencies调用不具备毫秒中断保证。
## [br]
## @return 输入能否开始；失败不会执行资源枚举。
func begin(snapshot: Dictionary, options: Dictionary = {}) -> bool:
	_capture = {}
	_files = []
	_cursor = 0
	_bytes = 0
	_edges = 0
	_verifying = false
	_finished = true
	_limits = {
		"max_files": 4096,
		"max_edges": 16384,
		"max_file_bytes": 4194304,
		"max_total_bytes": 33554432,
	}
	for key: Variant in options:
		if (
			not key is String
			or not _limits.has(key)
			or not options[key] is int
			or options[key] < 1
			or options[key] > _limits[key]
		):
			return false
		_limits[key] = options[key]
	if (
		not snapshot.get("root_path") is String
		or not snapshot.get("files") is Array
		or not snapshot.get("scope") is Dictionary
	):
		return false
	_root = snapshot["root_path"]
	if (
		(
			_root != "res://"
			and not _resource_path(_root)
		)
		or _linked(_root)
	):
		return false
	var paths: Array = snapshot["files"]
	if paths.size() > 20000:
		return false
	for raw: Variant in paths:
		if not raw is String:
			return false
		var path: String = raw
		if (
			path.is_empty()
			or path.length() > 4096
			or path.simplify_path() != path
			or path.begins_with("/")
			or path.contains(":")
			or path.contains("\\")
			or path.begins_with("../")
		):
			return false
		var _appended: bool = _files.append(path)
	_files.sort()
	var scope: Dictionary = snapshot["scope"]
	var inventory_digest: String = _DEPENDENCIES_SCRIPT.inventory_key(scope, _files)
	if inventory_digest.is_empty():
		return false
	_capture = {
		"schema_version": 1,
		"kind": "resource_dependency_capture",
		"inventory_digest": inventory_digest,
		"status": "captured",
		"provenance": {
			"method": "ResourceLoader.get_dependencies",
			"engine_version": str(Engine.get_version_info()["string"]),
			"root_path": _root,
		},
		"files": [],
		"issues": [],
	}
	_extensions = ResourceLoader.get_recognized_extensions_for_type("")
	_finished = false
	return true


## 每步有界处理文件；原始遍历结束后逐个复核捕获字节及 UID 映射。
## [br]
## @api framework_internal
## [br]
## @param max_files: 本步最多处理1至64个文件。
## [br]
## @return 是否已经结束。
func step(max_files: int = 8) -> bool:
	if _finished:
		return true
	if max_files < 1 or max_files > 64:
		_abort(
			"partial",
			"invalid_step_budget",
			""
		)
		return true
	for _index: int in range(max_files):
		var entries: Array = _capture["files"]
		if _verifying:
			if _cursor >= entries.size():
				_finish()
				break
			var entry: Dictionary = entries[_cursor]
			var verified_path: String = entry["path"]
			var current: Dictionary = _read_bytes(verified_path)
			if (
				current.is_empty()
				or current["sha256"] != entry["sha256"]
				or current["bytes"] != entry["bytes"]
			):
				_abort(
					"stale",
					"source_changed",
					verified_path
				)
				break
			for dependency: Dictionary in entry["dependencies"]:
				var raw: String = dependency["raw"]
				if decode_dependency(raw) != dependency:
					_abort(
						"stale",
						"uid_mapping_changed",
						verified_path
					)
					break
			_cursor += 1
			if _finished:
				break
			continue
		if _cursor >= _files.size() or _cursor >= _limits["max_files"]:
			if _cursor < _files.size():
				_issue("file_budget_exceeded", "")
				_capture["status"] = "partial"
			_verifying = true
			_cursor = 0
			continue
		var path: String = _files[_cursor]
		_cursor += 1
		var record: Dictionary = _read_bytes(path)
		if record.is_empty():
			_capture["status"] = "partial"
			_issue("source_unavailable_or_over_budget", path)
			continue
		var source_bytes: int = record["bytes"]
		if _bytes + source_bytes > _limits["max_total_bytes"]:
			_capture["status"] = "partial"
			_issue("source_byte_budget_exceeded", path)
			_verifying = true
			_cursor = 0
			continue
		_bytes += source_bytes
		var dependencies: Array[Dictionary] = []
		if _extensions.has(path.get_extension().to_lower()):
			var raw_dependencies: PackedStringArray = ResourceLoader.get_dependencies(_root.path_join(path))
			raw_dependencies.sort()
			var previous: String = ""
			for raw: String in raw_dependencies:
				if raw == previous:
					continue
				previous = raw
				_edges += 1
				if _edges > _limits["max_edges"] or raw.length() > 4096:
					_capture["status"] = "partial"
					_issue("dependency_budget_exceeded", path)
					break
				dependencies.append(decode_dependency(raw))
		entries.append(
			{
				"path": path,
				"sha256": record["sha256"],
				"bytes": record["bytes"],
				"dependencies": dependencies,
			}
		)
		if _edges > _limits["max_edges"]:
			_verifying = true
			_cursor = 0
	return _finished


## 取消捕获；不把被取消的部分数据当成可复用证据。
## [br]
## @api framework_internal
func cancel() -> void:
	_capture = {}
	_finished = true


## 返回隔离的完整或有限覆盖证据；进行中及取消时为空。
## [br]
## @api framework_internal
## [br]
## @return 封存证据或空字典。
## [br]
## @schema return: Dictionary，非空时精确含schema_version、kind、inventory_digest、status、provenance、files、issues、digest；status为captured/partial/stale。
func get_capture() -> Dictionary:
	return _capture.duplicate(true) if _finished else {}


## 解析引擎的一段路径或 UID::::fallback 表达，优先有效 UID，未知 UID 保留 fallback。
## [br]
## @api framework_internal
## [br]
## @param raw: ResourceLoader.get_dependencies 返回的原始条目。
## [br]
## @return 规范解析证据，不打开目标文件。
## [br]
## @schema return: Dictionary，精确含raw、target、uid、fallback、resolution，均为String。resolution为path/uid/fallback/unresolved；不合法或无目标时target为空。
static func decode_dependency(raw: String) -> Dictionary:
	var result: Dictionary = {
		"raw": raw,
		"target": "",
		"uid": "",
		"fallback": "",
		"resolution": "unresolved",
	}
	var parts: PackedStringArray = raw.split("::", true)
	if parts.size() == 1:
		if _resource_path(raw):
			result["target"] = raw
			result["resolution"] = "path"
	elif (
		parts.size() == 3
		and parts[1].is_empty()
		and parts[0].begins_with("uid://")
	):
		result["uid"] = parts[0]
		result["fallback"] = parts[2]
		var id: int = ResourceUID.text_to_id(parts[0])
		if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
			var resolved: String = ResourceUID.get_id_path(id)
			if _resource_path(resolved):
				result["target"] = resolved
				result["resolution"] = "uid"
		if result["target"] == "" and _resource_path(parts[2]):
			result["target"] = parts[2]
			result["resolution"] = "fallback"
	return result


# --- 私有/辅助方法 ---

## 有界读取已选路径；不穿过链接，不执行脚本或资源反序列化。
## [br]
## @api private
func _read_bytes(relative_path: String) -> Dictionary:
	var path: String = _root.path_join(relative_path)
	if _linked(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var length: int = file.get_length()
	if length > _limits["max_file_bytes"]:
		file.close()
		return {}
	var bytes: PackedByteArray = file.get_buffer(length)
	var unchanged: bool = bytes.size() == length and file.get_length() == length
	file.close()
	if not unchanged or _linked(path):
		return {}
	var hasher: HashingContext = HashingContext.new()
	if hasher.start(HashingContext.HASH_SHA256) != OK or hasher.update(bytes) != OK:
		return {}
	return { "bytes": length, "sha256": hasher.finish().hex_encode() }


## 添加有限捕获问题；每个文件至多产生常数条记录。
## [br]
## @api private
func _issue(kind: String, path: String) -> void:
	var issues: Array = _capture["issues"]
	issues.append({ "kind": kind, "path": path })


## 结束异常捕获并保留明确状态。
## [br]
## @api private
func _abort(
	status: String,
	kind: String,
	path: String
) -> void:
	_capture["status"] = status
	_issue(kind, path)
	_finish()


## 完成摘要；超出证据总预算时拒绝发布。
## [br]
## @api private
func _finish() -> void:
	_capture = _DEPENDENCIES_SCRIPT.seal_capture(_capture)
	_finished = true


## 规范当前项目资源 URI，拒绝路径回退和分隔符别名。
## [br]
## @api private
static func _resource_path(path: String) -> bool:
	if (
		not path.begins_with("res://")
		or path.length() <= 6
		or path.length() > 4096
		or path.simplify_path() != path
		or path.contains("\\")
	):
		return false
	for part: String in path.substr(6).split("/", true):
		if part in [
			"",
			".",
			"..",
		] or part.contains(":"):
			return false
	for index: int in range(path.length()):
		if path.unicode_at(index) < 32:
			return false
	return true


## 检查每级目录及叶子，拒绝符号链接和目录联接。
## [br]
## @api private
static func _linked(path: String) -> bool:
	var absolute: String = ProjectSettings.globalize_path(path)
	while not absolute.is_empty() and absolute != absolute.get_base_dir():
		var parent: String = absolute.get_base_dir()
		var directory: DirAccess = DirAccess.open(parent)
		if directory == null or directory.is_link(absolute.get_file()):
			return true
		absolute = parent
	return false
