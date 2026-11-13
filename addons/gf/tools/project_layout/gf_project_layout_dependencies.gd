# Project Layout 的纯数据依赖证据解释器；不读取文件或加载资源。
extends RefCounted


# --- 框架内部方法 ---

## 规范化项目声明；不推断启动场景、所有权或运行性能。
## [br]
## @api framework_internal
## [br]
## @param declaration: 可省略字段的项目声明。
## [br]
## @schema declaration: Dictionary，可含 startup_roots:Array[String]、owners:Array[{id:String,roots:Array[String],max_source_bytes:int}]、edges:Array[{from:String,to:String}]、max_startup_files:int、max_startup_source_bytes:int。路径为规范库存相对路径，owners.roots可为点；预算-1表示未声明。
## [br]
## @return 规范声明，输入错误返回空字典。
## [br]
## @schema return: Dictionary，成功时精确包含上述五个字段；最多256启动根、256所有者、4096声明边，预算上限1TiB，文件数上限4096。
static func normalize_declaration(declaration: Dictionary) -> Dictionary:
	if not _admit(declaration) or not _fields(
		declaration,
		[
			"startup_roots",
			"owners",
			"edges",
			"max_startup_files",
			"max_startup_source_bytes",
		],
		false
	):
		return {}
	var result: Dictionary = {
		"startup_roots": [],
		"owners": [],
		"edges": [],
		"max_startup_files": -1,
		"max_startup_source_bytes": -1,
	}
	result.merge(
		declaration.duplicate(true),
		true
	)
	if (
		not _paths(
			result["startup_roots"],
			256
		)
		or not result["owners"] is Array
		or not result["edges"] is Array
	):
		return {}
	if not _budget(
		result["max_startup_files"],
		4096
	) or not _budget(
		result["max_startup_source_bytes"],
		1099511627776
	):
		return {}
	var owners: Array = result["owners"]
	var edges: Array = result["edges"]
	if owners.size() > 256 or edges.size() > 4096:
		return {}
	var ids: Dictionary = {}
	for raw: Variant in owners:
		if not raw is Dictionary:
			return {}
		var owner: Dictionary = raw
		if (
			not _fields(
				owner,
				[
					"id",
					"roots",
					"max_source_bytes",
				]
			)
			or not _label(owner["id"])
			or ids.has(owner["id"])
			or not _paths(
				owner["roots"],
				256,
				true
			)
			or not _budget(
				owner["max_source_bytes"],
				1099511627776
			)
		):
			return {}
		ids[owner["id"]] = true
	var seen: Dictionary = {}
	for raw: Variant in edges:
		if not raw is Dictionary:
			return {}
		var edge: Dictionary = raw
		if (
			not _fields(
				edge,
				["from", "to"]
			)
			or not _path(edge["from"])
			or not _path(edge["to"])
		):
			return {}
		var key: String = JSON.stringify([edge["from"], edge["to"]])
		if seen.has(key):
			return {}
		seen[key] = true
	return result


## 绑定规范捕获范围和排序后的库存路径；不声称覆盖文件内容。
## [br]
## @api framework_internal
## [br]
## @param scope: 已准入的库存范围。
## [br]
## @schema scope: Project Layout project_source scope。
## [br]
## @param files: 已准入的唯一相对路径。
## [br]
## @return SHA-256 范围凭据；超预算返回空字符串。
static func inventory_key(scope: Dictionary, files: PackedStringArray) -> String:
	var sorted: PackedStringArray = files.duplicate()
	sorted.sort()
	return _digest({ "scope": scope, "files": Array(sorted) })


## 为捕获器持有的有界纯数据添加内容摘要。
## [br]
## @api framework_internal
## [br]
## @param capture: 尚未带摘要的捕获记录。
## [br]
## @schema capture: Dictionary，包含 schema_version、kind、inventory_digest、status、provenance、files、issues；具体封闭结构由 analyze 验证。
## [br]
## @return 独立副本，增加 digest；超预算返回空字典。
## [br]
## @schema return: Dictionary，沿用 capture 并增加 digest:String。
static func seal_capture(capture: Dictionary) -> Dictionary:
	var digest: String = _digest(capture)
	if digest.is_empty():
		return {}
	var result: Dictionary = capture.duplicate(true)
	result["digest"] = digest
	return result


## 从冻结证据计算闭包、跨所有权边、重复拥有与显式源文件预算。
## [br]
## @api framework_internal
## [br]
## @param input: 三类相互独立的证据。
## [br]
## @schema input: 封闭 Dictionary，capture:Dictionary、declaration:Dictionary、observations:Array。capture为空或带摘要的resource_dependency_capture；observations条目精确含from、to、sample_id、config_digest、observed_at_msec，均为项目提交的历史观测，不证明完整覆盖。
## [br]
## @param inventory_digest: 当前冻结库存范围凭据。
## [br]
## @param root_path: 捕获库存根。
## [br]
## @param files: 库存文件路径。
## [br]
## @param checkpoint: 可选逐工作项取消/预算检查。
## [br]
## @return 完整推导报告；格式、摘要、绑定或工作预算错误返回空字典。
## [br]
## @schema return: Dictionary，精确含input、digest、coverage、capture_status、edges、startup_files、startup_source_bytes、startup_complete、unreachable_files、duplicate_owners、cross_owner_edges、cycles、issues。coverage恒为partial；edges含evidence_id、kind、from、to、provenance；issues含kind、path。所有结果仅描述本次冻结证据。
static func analyze(
	input: Dictionary,
	inventory_digest: String,
	root_path: String,
	files: PackedStringArray,
	checkpoint: Callable = Callable()
) -> Dictionary:
	if (
		not _admit(input)
		or not _fields(
			input,
			[
				"capture",
				"declaration",
				"observations",
			]
		)
		or not input["capture"] is Dictionary
		or not input["declaration"] is Dictionary
		or not input["observations"] is Array
	):
		return {}
	var raw_declaration: Dictionary = input["declaration"]
	var declaration: Dictionary = normalize_declaration(raw_declaration)
	var capture: Dictionary = input["capture"]
	var observations: Array = input["observations"]
	if (
		declaration.is_empty()
		or observations.size() > 4096
		or files.size() > 20000
		or not _hash(inventory_digest)
	):
		return {}
	var known: Dictionary = {}
	for path: String in files:
		known[path] = true
	if not _valid_capture(
		capture,
		inventory_digest,
		root_path,
		known
	):
		return {}
	var result: Dictionary = {
		"input": input.duplicate(true),
		"digest": _digest(input),
		"coverage": "partial",
		"capture_status": capture.get("status", "unavailable"),
		"edges": [],
		"startup_files": [],
		"startup_source_bytes": 0,
		"startup_complete": false,
		"unreachable_files": [],
		"duplicate_owners": [],
		"cross_owner_edges": [],
		"cycles": [],
		"issues": [],
	}
	var edges: Array = result["edges"]
	var issues: Array = result["issues"]
	var duplicate_owners: Array = result["duplicate_owners"]
	var cross_owner_edges: Array = result["cross_owner_edges"]
	var unreachable_files: Array = result["unreachable_files"]
	var cycles: Array = result["cycles"]
	var captured: Dictionary = {}
	var capture_files: Array = capture.get("files", [])
	var usable: bool = capture.get("status") in ["captured", "partial"]
	for raw: Dictionary in capture_files:
		if not _step(checkpoint):
			return {}
		var path: String = raw["path"]
		if usable:
			captured[path] = raw
			for dependency: Dictionary in raw["dependencies"]:
				var target_uri: String = dependency["target"]
				var target: String = _relative(target_uri, root_path)
				edges.append(
					_edge(
						"static_resource_dependency",
						path,
						target,
						dependency
					)
				)
	for edge: Dictionary in declaration["edges"]:
		var from: String = edge["from"]
		var to: String = edge["to"]
		edges.append(
			_edge(
				"project_declared_dependency",
				from,
				to,
				{}
			)
		)
	var sample_ids: Dictionary = {}
	for raw: Variant in observations:
		if not raw is Dictionary:
			return {}
		var observation: Dictionary = raw
		if (
			not _fields(
				observation,
				[
					"from",
					"to",
					"sample_id",
					"config_digest",
					"observed_at_msec",
				]
			)
			or not _path(observation["from"])
			or not _path(observation["to"])
			or not _label(observation["sample_id"])
			or not _hash(observation["config_digest"])
			or not observation["observed_at_msec"] is int
			or observation["observed_at_msec"] < 0
			or observation["observed_at_msec"] > 9007199254740991
		):
			return {}
		var sample_key: String = JSON.stringify(observation)
		if sample_ids.has(sample_key):
			return {}
		sample_ids[sample_key] = true
		var from: String = observation["from"]
		var to: String = observation["to"]
		edges.append(
			_edge(
				"runtime_dependency_observation",
				from,
				to,
				observation
			)
		)
	var adjacency: Dictionary = {}
	var owner_by_path: Dictionary = {}
	var owner_bytes: Dictionary = {}
	var owners: Array = declaration["owners"]
	var owners_by_root: Dictionary = {}
	var root_count: int = 0
	for owner: Dictionary in owners:
		var id: String = owner["id"]
		for prefix: String in owner["roots"]:
			root_count += 1
			if root_count > 4096 or not _step(checkpoint):
				return {}
			var root_owners: Array = owners_by_root.get(prefix, [])
			root_owners.append(id)
			owners_by_root[prefix] = root_owners
	for path: String in files:
		var membership_set: Dictionary = {}
		var prefix: String = path
		while not prefix.is_empty():
			if not _step(checkpoint):
				return {}
			for id: String in owners_by_root.get(prefix, []):
				membership_set[id] = true
			if prefix == ".":
				prefix = ""
			else:
				prefix = prefix.get_base_dir() if prefix.contains("/") else "."
		var membership: Array = membership_set.keys()
		var source: Dictionary = captured.get(path, {})
		var source_bytes: int = source.get("bytes", 0)
		for id: String in membership:
			var previous: int = owner_bytes.get(id, 0)
			owner_bytes[id] = previous + source_bytes
		membership.sort()
		owner_by_path[path] = membership
		if membership.size() > 1:
			duplicate_owners.append({ "path": path, "owners": membership })
	var edge_ids: Dictionary = {}
	for edge: Dictionary in edges:
		if not _step(checkpoint):
			return {}
		if edge_ids.has(edge["evidence_id"]):
			return {}
		edge_ids[edge["evidence_id"]] = true
		var from: String = edge["from"]
		var to: String = edge["to"]
		if not known.has(from) or not known.has(to):
			issues.append({ "kind": "dependency_target_unobserved", "path": to })
		if not adjacency.has(from):
			adjacency[from] = []
		var targets: Array = adjacency[from]
		targets.append(to)
		var source_owners: Array = owner_by_path.get(from, [])
		var target_owners: Array = owner_by_path.get(to, [])
		if (
			not source_owners.is_empty()
			and not target_owners.is_empty()
			and source_owners != target_owners
		):
			cross_owner_edges.append(edge["evidence_id"])
	var reached: Dictionary = {}
	var startup_roots: Array = declaration["startup_roots"]
	var queue: Array = startup_roots.duplicate()
	var cursor: int = 0
	var startup_complete: bool = usable and capture.get("status") == "captured"
	while cursor < queue.size():
		if not _step(checkpoint):
			return {}
		var path: String = queue[cursor]
		cursor += 1
		if reached.has(path):
			continue
		reached[path] = true
		if not known.has(path) or not captured.has(path):
			startup_complete = false
			issues.append({ "kind": "startup_path_unobserved", "path": path })
		if captured.has(path):
			var source: Dictionary = captured[path]
			var source_bytes: int = source["bytes"]
			result["startup_source_bytes"] += source_bytes
		var next: Array = adjacency.get(path, [])
		queue.append_array(next)
	var startup_files: Array = reached.keys()
	startup_files.sort()
	result["startup_files"] = startup_files
	result["startup_complete"] = startup_complete
	for path: String in files:
		if not reached.has(path):
			unreachable_files.append(path)
	if not _find_cycles(
		adjacency,
		cycles,
		checkpoint
	):
		return {}
	if declaration["max_startup_files"] >= 0 and startup_files.size() > declaration["max_startup_files"]:
		issues.append({ "kind": "startup_file_budget_exceeded", "path": "" })
	if declaration["max_startup_source_bytes"] >= 0 and result["startup_source_bytes"] > declaration["max_startup_source_bytes"]:
		issues.append({ "kind": "startup_source_budget_exceeded", "path": "" })
	for owner: Dictionary in owners:
		var total_bytes: int = owner_bytes.get(
			owner["id"],
			0
		)
		if owner["max_source_bytes"] >= 0 and total_bytes > owner["max_source_bytes"]:
			issues.append({ "kind": "owner_source_budget_exceeded", "path": owner["id"] })
	return result if _admit(result) else {}


# --- 私有/辅助方法 ---

## 检查已封存捕获及逐文件依赖结构，摘要只是完整性凭据，不是来源认证。
## [br]
## @api private
static func _valid_capture(
	capture: Dictionary,
	inventory_digest: String,
	root_path: String,
	known: Dictionary
) -> bool:
	if capture.is_empty():
		return true
	if (
		not _fields(
			capture,
			[
				"schema_version",
				"kind",
				"inventory_digest",
				"status",
				"provenance",
				"files",
				"issues",
				"digest",
			]
		)
		or capture["schema_version"] != 1
		or not capture["schema_version"] is int
		or capture["kind"] != "resource_dependency_capture"
		or capture["inventory_digest"] != inventory_digest
		or capture["status"] not in [
			"captured",
			"partial",
			"stale",
			"unavailable",
		]
		or not capture["files"] is Array
		or not capture["issues"] is Array
		or not capture["provenance"] is Dictionary
	):
		return false
	var payload: Dictionary = capture.duplicate(true)
	var _removed: bool = payload.erase("digest")
	if _digest(payload) != capture["digest"]:
		return false
	var provenance: Dictionary = capture["provenance"]
	if (
		not _fields(
			provenance,
			[
				"method",
				"engine_version",
				"root_path",
			]
		)
		or provenance["method"] != "ResourceLoader.get_dependencies"
		or not _label(provenance["engine_version"])
		or provenance["root_path"] != root_path
	):
		return false
	var seen: Dictionary = {}
	var edge_count: int = 0
	var source_bytes: int = 0
	var entries: Array = capture["files"]
	if entries.size() > 4096:
		return false
	for raw: Variant in capture["files"]:
		if not raw is Dictionary:
			return false
		var entry: Dictionary = raw
		if (
			not _fields(
				entry,
				[
					"path",
					"sha256",
					"bytes",
					"dependencies",
				]
			)
			or not known.has(entry["path"])
			or seen.has(entry["path"])
			or not _hash(entry["sha256"])
			or not entry["bytes"] is int
			or entry["bytes"] < 0
			or entry["bytes"] > 4194304
			or not entry["dependencies"] is Array
		):
			return false
		seen[entry["path"]] = true
		var length: int = entry["bytes"]
		source_bytes += length
		if source_bytes > 33554432:
			return false
		var dependencies: Array = entry["dependencies"]
		edge_count += dependencies.size()
		if edge_count > 16384:
			return false
		for dependency_value: Variant in entry["dependencies"]:
			if not dependency_value is Dictionary:
				return false
			var dependency: Dictionary = dependency_value
			if (
				not _fields(
					dependency,
					[
						"raw",
						"target",
						"uid",
						"fallback",
						"resolution",
					]
				)
				or not dependency["raw"] is String
				or not dependency["target"] is String
				or not dependency["uid"] is String
				or not dependency["fallback"] is String
				or dependency["resolution"] not in [
					"path",
					"uid",
					"fallback",
					"unresolved",
				]
			):
				return false
			var target: String = dependency["target"]
			if (
				not target.is_empty()
				and (
					not target.begins_with("res://")
					or not _path(target.substr(6))
				)
			):
				return false
			if not _dependency_resolution_is_consistent(dependency):
				return false
	for raw: Variant in capture["issues"]:
		if not raw is Dictionary:
			return false
		var issue: Dictionary = raw
		if (
			not _fields(
				issue,
				["kind", "path"]
			)
			or not _label(issue["kind"])
			or not issue["path"] is String
		):
			return false
	return capture["status"] != "captured" or seen.size() == known.size()


## 验证原始表达与解析方式的一致性；UID映射事实属于捕获来源，不在纯分析时重新查询。
## [br]
## @api private
static func _dependency_resolution_is_consistent(dependency: Dictionary) -> bool:
	var raw: String = dependency["raw"]
	var target: String = dependency["target"]
	var uid: String = dependency["uid"]
	var fallback: String = dependency["fallback"]
	var resolution: String = dependency["resolution"]
	var parts: PackedStringArray = raw.split("::", true)
	if resolution == "path":
		return (
			parts.size() == 1
			and target == raw
			and not target.is_empty()
			and uid.is_empty()
			and fallback.is_empty()
		)
	if resolution == "unresolved":
		return (
			target.is_empty()
			and (
				uid.is_empty()
				and fallback.is_empty()
				or parts.size() == 3
				and parts[0] == uid
				and parts[1].is_empty()
				and parts[2] == fallback
			)
		)
	if (
		parts.size() != 3
		or not parts[1].is_empty()
		or parts[0] != uid
		or not uid.begins_with("uid://")
		or parts[2] != fallback
		or target.is_empty()
	):
		return false
	return (
		resolution == "uid"
		or resolution == "fallback"
		and target == fallback
	)


## 显式栈三色遍历，输出闭环边；不会递归展开循环。
## [br]
## @api private
static func _find_cycles(
	adjacency: Dictionary,
	cycles: Array,
	checkpoint: Callable
) -> bool:
	var color: Dictionary = {}
	var roots: Array = adjacency.keys()
	roots.sort()
	for root: String in roots:
		if color.has(root):
			continue
		var stack: Array[Dictionary] = [
			{ "path": root, "cursor": 0 },
		]
		color[root] = 1
		while not stack.is_empty():
			if not _step(checkpoint):
				return false
			var frame: Dictionary = stack[-1]
			var path: String = frame["path"]
			var next: Array = adjacency.get(path, [])
			var cursor: int = frame["cursor"]
			if cursor == next.size():
				color[path] = 2
				var _popped: Dictionary = stack.pop_back()
				continue
			frame["cursor"] = cursor + 1
			var target: String = next[cursor]
			if color.get(target, 0) == 1:
				cycles.append({ "from": path, "to": target })
			elif not color.has(target):
				color[target] = 1
				stack.append({ "path": target, "cursor": 0 })
	return true


## 按证据种类和原始来源生成稳定身份。
## [br]
## @api private
static func _edge(
	kind: String,
	from: String,
	to: String,
	provenance: Dictionary
) -> Dictionary:
	return {
		"evidence_id": "dependency:" + _digest(
			[
				kind,
				from,
				to,
				provenance,
			]
		),
		"kind": kind,
		"from": from,
		"to": to,
		"provenance": provenance.duplicate(true),
	}


## 将当前根内 URI 转为相对路径，范围外保持 URI 以显式报告未知。
## [br]
## @api private
static func _relative(path: String, root: String) -> String:
	var prefix: String = root if root.ends_with("/") else root + "/"
	return path.substr(prefix.length()) if path.begins_with(prefix) else path


## 纯数据准入先于复制与编码；限制整棵树而非仅顶层条数。
## [br]
## @api private
static func _admit(value: Variant) -> bool:
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		value,
		{
			"max_depth": 16,
			"max_items": 400000,
			"max_output_bytes": 8388608,
			"max_string_length": 4096,
		}
	)
	return GFVariantData.get_option_bool(measured, "ok")


## 使用稳定键排序编码有界数据；本契约不接受浮点业务数值。
## [br]
## @api private
static func _digest(value: Variant) -> String:
	return JSON.stringify(
		value,
		"",
		true,
		true
	).sha256_text() if _admit(value) else ""


## 检查字段闭集和实际 String 键。
## [br]
## @api private
static func _fields(
	value: Dictionary,
	fields: PackedStringArray,
	exact: bool = true
) -> bool:
	if exact and value.size() != fields.size():
		return false
	for key: Variant in value:
		if not key is String:
			return false
		var name: String = key
		if not fields.has(name):
			return false
	return true


## 检查路径数组有界、唯一且类型精确。
## [br]
## @api private
static func _paths(
	value: Variant,
	limit: int,
	allow_dot: bool = false
) -> bool:
	if not value is Array:
		return false
	var paths: Array = value
	if paths.size() > limit:
		return false
	var seen: Dictionary = {}
	for path: Variant in paths:
		if (
			not path is String
			or (
				not (
					allow_dot
					and path == "."
				)
				and not _path(path)
			)
		):
			return false
		if seen.has(path):
			return false
		seen[path] = true
	return true


## 只接受非空的规范相对文件路径。
## [br]
## @api private
static func _path(value: Variant) -> bool:
	if not value is String:
		return false
	var path: String = value
	if (
		path.is_empty()
		or path.length() > 4096
		or path.strip_edges() != path
		or path.contains(":")
		or path.contains("\\")
		or path.begins_with("/")
	):
		return false
	for part: String in path.split("/", true):
		if part in [
			"",
			".",
			"..",
		]:
			return false
	for index: int in range(path.length()):
		if path.unicode_at(index) < 32:
			return false
	return true


## 检查非空短身份。
## [br]
## @api private
static func _label(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return (
		not text.is_empty()
		and text.length() <= 256
		and text.strip_edges() == text
	)


## 检查规范 SHA-256 文本。
## [br]
## @api private
static func _hash(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.length() != 64:
		return false
	for code: int in text.to_ascii_buffer():
		if not (
			code >= 48
			and code <= 57
			or code >= 97
			and code <= 102
		):
			return false
	return true


## 整数预算允许显式未声明值，不接受浮点近似。
## [br]
## @api private
static func _budget(value: Variant, maximum: int) -> bool:
	return (
		value is int
		and value >= -1
		and value <= maximum
	)


## 逐项消费调用方的取消与工作预算。
## [br]
## @api private
static func _step(checkpoint: Callable) -> bool:
	if not checkpoint.is_valid():
		return true
	var allowed: Variant = checkpoint.call()
	return allowed is bool and allowed
