## GFProjectLayoutCaptureScope: Layout 唯一声明准入、来源映射及排除根身份校验。
## [br]
## @api framework_internal
## [br]
## @category data
## [br]
## @since unreleased
class_name GFProjectLayoutCaptureScope
extends RefCounted


# --- 常量 ---

## 固定状态根不属于源码观察范围，项目声明不能重复或覆盖它们。
## [br]
## @api private
const _FIXED_EXCLUSIONS: PackedStringArray = [".git", ".godot", ".import"]

## 必须可观察的项目配置与人工契约，不能由排除声明隐藏。
## [br]
## @api private
const _FIXED_PROTECTED_SOURCES: PackedStringArray = ["project.godot", "gf_project_profile.json", ".gf/project_profile.json", "project_profile.json", ".gf/project_contract.json", "addons/gf/tools/project_layout/contracts/project_profile_v2.contract.json"]

## 声明字段闭集；根是锚定 source_root 的逻辑 res:// 容器。
## [br]
## @api private
const _DECLARATION_FIELDS: PackedStringArray = ["schema_version", "root_path", "required_roots", "excluded_roots"]

## 保护集合包含推导来源，仍受有限整体数量约束。
## [br]
## @api private
const _MAX_PROTECTED_ROOTS: int = 256

## 身份资格枚举按条目收费；不会进入排除目录后代或物化整个父目录清单。
## [br]
## @api private
const _MAX_IDENTITY_ENTRIES: int = 40_000


# --- 框架内部方法 ---

## 严格准入声明并复制为规范数组；失败不返回部分声明。
## [br]
## @api framework_internal
## [br]
## @param value: capture_scope 声明。
## [br]
## @schema value: Dictionary，精确包含 schema_version: int=1、root_path: String、required_roots: Array[String] 和 excluded_roots: Array[Dictionary]；每个排除条目精确包含 path: String 与 kind: String，kind 只能是 generated_evidence 或 disposable；root_path 是锚定 source_root 的逻辑 res:// 容器，其余路径必须为规范 literal 相对路径。
## [br]
## @return 闭合 success、declaration 和 error 字典。
## [br]
## @schema return: Dictionary，精确包含 success: bool、declaration: Dictionary 和 error: String。
static func normalize_declaration(value: Dictionary) -> Dictionary:
	if not _exact_fields(value, _DECLARATION_FIELDS) or value.get("schema_version") != 1:
		return _declaration_failure("capture_scope 字段或版本无效。")
	var root_value: Variant = value.get("root_path")
	if not root_value is String:
		return _declaration_failure("capture_scope.root_path 必须是逻辑 res:// 容器。")
	var logical_root: String = root_value
	if not logical_root.begins_with("res://") or (logical_root != "res://" and not literal_path_is_valid(logical_root.substr(6))):
		return _declaration_failure("capture_scope.root_path 不是规范逻辑容器。")
	var required_value: Variant = value.get("required_roots")
	var excluded_value: Variant = value.get("excluded_roots")
	if not required_value is Array or not excluded_value is Array:
		return _declaration_failure("capture_scope 根集合必须为数组。")
	var required_input: Array = required_value
	var excluded_input: Array = excluded_value
	if required_input.size() > 64 or excluded_input.size() > 61:
		return _declaration_failure("capture_scope 根集合超过有限预算。")
	var required: Array[String] = []
	var excluded: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in required_input:
		if not item is String:
			return _declaration_failure("required_roots 只能包含 literal 路径。")
		var path: String = item
		if not literal_path_is_valid(path) or seen.has(path.to_lower()):
			return _declaration_failure("required_roots 存在非法或重复路径。")
		for fixed_path: String in _FIXED_EXCLUSIONS:
			if paths_intersect(path, fixed_path):
				return _declaration_failure("required_roots 与固定状态排除根相交。")
		seen[path.to_lower()] = true
		required.append(path)
	var excluded_paths: PackedStringArray = _FIXED_EXCLUSIONS.duplicate()
	for item: Variant in excluded_input:
		if not item is Dictionary:
			return _declaration_failure("excluded_roots 条目必须是闭合字典。")
		var entry: Dictionary = item
		if not _exact_fields(entry, PackedStringArray(["path", "kind"])) or not entry.get("path") is String:
			return _declaration_failure("excluded_roots 条目字段无效。")
		var path: String = entry["path"]
		if not literal_path_is_valid(path) or not ["generated_evidence", "disposable"].has(entry.get("kind")):
			return _declaration_failure("excluded_roots 路径或用途无效。")
		for other: String in excluded_paths:
			if paths_intersect(path, other):
				return _declaration_failure("排除根重复、重叠或覆盖固定状态根。")
		var _append_excluded_path: bool = excluded_paths.append(path)
		excluded.append({"path": path, "kind": entry["kind"]})
	required.sort()
	excluded.sort_custom(_excluded_precedes)
	return {"success": true, "declaration": {"schema_version": 1, "root_path": logical_root, "required_roots": required, "excluded_roots": excluded}, "error": ""}


## 将唯一 compiled policy 的声明绑定实际 source/capture 根并推导不可隐藏来源。
## [br]
## @api framework_internal
## [br]
## @param profile: 已准入 compiled profile；空字典表示仅观察。
## [br]
## @schema profile: Dictionary，空字典表示 observation-only；非空值遵循 project_profile_v2.contract.json 的闭合 profile 契约，必需 schema_version、id、zones 和 rules，可选 display_name、description、metadata 和 capture_scope；本方法只消费 capture_scope、required zone 的 roots 及 path_exists/feature_module_contract 的保护根。
## [br]
## @param root_path: 请求实际扫描根。
## [br]
## @param options: 闭合调用选项中的 source_root、capture_scope 和 profile_source_path。
## [br]
## @schema options: Dictionary，来自调用方已准入的捕获选项；本方法消费可选 source_root: String、capture_scope: Dictionary 和 profile_source_path: String；capture_scope 遵循 normalize_declaration 的四字段闭集，其余捕获控制字段由调用方准入，本方法不另行解释。
## [br]
## @return 闭合 success、binding 和 error；binding 只含纯数据。
## [br]
## @schema return: Dictionary，精确包含 success: bool、binding: Dictionary 和 error: String；成功 binding 精确包含 capture_scope: Dictionary、source_root: String、root_path: String、protected_roots: Array[String]、profile_source_path: String、excluded_prefixes: Array[String] 和 policy_digest: String；失败 binding 为 {}。
static func prepare(profile: Dictionary, root_path: String, options: Dictionary) -> Dictionary:
	var source_value: Variant = options.get("source_root", "res://")
	if not source_value is String:
		return _binding_failure("source_root 必须是规范来源根。")
	var source_root: String = source_value
	if not root_is_canonical(source_root) or not root_is_canonical(root_path):
		return _binding_failure("来源根或请求捕获根不规范。")
	var source_physical: String = physical_root(source_root)
	var capture_physical: String = physical_root(root_path)
	var default_logical_root: String = "res://"
	if capture_physical.begins_with(source_physical + "/"):
		default_logical_root += capture_physical.substr(source_physical.length() + 1)
	var declaration_value: Variant = profile.get("capture_scope", options.get("capture_scope", {"schema_version": 1, "root_path": default_logical_root, "required_roots": [], "excluded_roots": []}))
	if not declaration_value is Dictionary:
		return _binding_failure("capture_scope 必须是字典。")
	var declaration_input: Dictionary = declaration_value
	var normalized: Dictionary = normalize_declaration(declaration_input)
	if not normalized["success"]:
		var error: String = normalized["error"]
		return _binding_failure(error)
	var declaration: Dictionary = normalized["declaration"]
	if profile.has("capture_scope") and options.has("capture_scope"):
		var option_value: Variant = options["capture_scope"]
		if not option_value is Dictionary:
			return _binding_failure("options.capture_scope 与 Profile 声明不一致。")
		var option_scope: Dictionary = option_value
		var option_normalized: Dictionary = normalize_declaration(option_scope)
		if not option_normalized["success"] or option_normalized["declaration"] != declaration:
			return _binding_failure("options.capture_scope 与 Profile 声明不一致。")
	var logical_root: String = declaration["root_path"]
	var resolved: String = source_physical if logical_root == "res://" else source_physical.path_join(logical_root.substr(6))
	if resolved != capture_physical:
		return _binding_failure("声明容器映射与请求捕获根不一致。")
	var protected: Array[String] = []
	for path: String in declaration["required_roots"]:
		_append_unique(protected, path)
	for fixed_path: String in _FIXED_PROTECTED_SOURCES:
		_append_unique(protected, fixed_path)
	var source_path_value: Variant = options.get("profile_source_path", "")
	if not source_path_value is String:
		return _binding_failure("profile_source_path 必须是来源路径。")
	var profile_source_path: String = source_path_value
	if not profile_source_path.is_empty():
		var profile_physical: String = physical_root(profile_source_path)
		if profile_physical.begins_with(capture_physical + "/"):
			_append_unique(protected, profile_physical.substr(capture_physical.length() + 1))
	for zone_value: Variant in _array(profile, "zones"):
		if not zone_value is Dictionary:
			return _binding_failure("保护 zone 必须为已编译字典。")
		var zone: Dictionary = zone_value
		if zone.get("required", false):
			for path_value: Variant in _array(zone, "roots"):
				if not path_value is String:
					return _binding_failure("保护 zone 根必须为规范路径。")
				var path: String = path_value
				_append_unique(protected, path)
	for rule_value: Variant in _array(profile, "rules"):
		if not rule_value is Dictionary:
			return _binding_failure("保护 rule 必须为已编译字典。")
		var rule: Dictionary = rule_value
		var rule_kind_value: Variant = rule.get("kind", "")
		if not rule_kind_value is String:
			return _binding_failure("保护 rule kind 必须为 String。")
		var rule_kind: String = rule_kind_value
		if rule_kind in ["path_exists", "feature_module_contract"]:
			for path_value: Variant in _array(rule, "paths" if rule_kind == "path_exists" else "roots"):
				if not path_value is String:
					return _binding_failure("保护 rule 根必须为规范路径。")
				var path: String = path_value
				_append_unique(protected, path)
		if protected.size() > _MAX_PROTECTED_ROOTS:
			return _binding_failure("保护来源集合超过有限预算。")
	if protected.size() > _MAX_PROTECTED_ROOTS:
		return _binding_failure("保护来源集合超过有限预算。")
	protected.sort()
	var protected_seen: Dictionary = {}
	for path: String in protected:
		if path.length() > 16_379 or not _relative_shape_is_valid(path) or protected_seen.has(path.to_lower()):
			return _binding_failure("保护来源路径无效或存在大小写 alias。")
		protected_seen[path.to_lower()] = true
	var prefixes: Array[String] = []
	prefixes.assign(_FIXED_EXCLUSIONS)
	for entry: Dictionary in declaration["excluded_roots"]:
		var path: String = entry["path"]
		prefixes.append(path)
	for path: String in prefixes:
		for protected_path: String in protected:
			if paths_intersect(path, protected_path):
				return _binding_failure("排除根与必需来源相交：%s。" % protected_path)
	prefixes.sort()
	var binding: Dictionary = {"capture_scope": declaration, "source_root": source_physical, "root_path": root_path, "protected_roots": protected, "profile_source_path": profile_source_path, "excluded_prefixes": prefixes}
	binding["policy_digest"] = JSON.stringify(binding).sha256_text()
	return {"success": true, "binding": binding, "error": ""}


## 检查闭合 binding 的自身身份，跨消费者使用相同声明/排除/保护映射。
## [br]
## @api framework_internal
## [br]
## @param binding: prepare 返回的 scope 成员。
## [br]
## @schema binding: Dictionary，精确包含 capture_scope: Dictionary、source_root: String、root_path: String、protected_roots: Array[String]、profile_source_path: String、excluded_prefixes: Array[String] 和 policy_digest: String；capture_scope 是规范四字段声明，两个路径数组有序且无重复，policy_digest 精确绑定其余六字段。
## [br]
## @return 是否完整、规范且 digest 精确匹配。
static func binding_is_valid(binding: Dictionary) -> bool:
	if not _exact_fields(binding, PackedStringArray(["capture_scope", "source_root", "root_path", "protected_roots", "profile_source_path", "excluded_prefixes", "policy_digest"])):
		return false
	var declaration_value: Variant = binding.get("capture_scope")
	if not declaration_value is Dictionary or not binding.get("source_root") is String or not binding.get("root_path") is String or not binding.get("profile_source_path") is String:
		return false
	var declaration_input: Dictionary = declaration_value
	var normalized: Dictionary = normalize_declaration(declaration_input)
	if not normalized["success"] or normalized["declaration"] != declaration_input:
		return false
	var protected_value: Variant = binding.get("protected_roots")
	var prefixes_value: Variant = binding.get("excluded_prefixes")
	if not protected_value is Array or not prefixes_value is Array:
		return false
	var protected: Array = protected_value
	var prefixes: Array = prefixes_value
	if protected.size() > _MAX_PROTECTED_ROOTS or prefixes.size() > 64:
		return false
	var previous: String = ""
	var protected_seen: Dictionary = {}
	for path_value: Variant in protected:
		if not path_value is String:
			return false
		var path: String = path_value
		if path.length() > 16_379 or not _relative_shape_is_valid(path) or protected_seen.has(path.to_lower()) or (not previous.is_empty() and previous >= path):
			return false
		protected_seen[path.to_lower()] = true
		previous = path
	var source_root: String = binding["source_root"]
	var root_path: String = binding["root_path"]
	var profile_source_path: String = binding["profile_source_path"]
	if not profile_source_path.is_empty() and (profile_source_path.length() > 16_384 or not root_is_canonical(profile_source_path)):
		return false
	for fixed_path: String in _FIXED_PROTECTED_SOURCES:
		if not protected.has(fixed_path):
			return false
	for required_path: String in declaration_input["required_roots"]:
		if not protected.has(required_path):
			return false
	if not profile_source_path.is_empty():
		var profile_physical: String = physical_root(profile_source_path)
		var capture_physical: String = physical_root(root_path)
		if profile_physical.begins_with(capture_physical + "/") and not protected.has(profile_physical.substr(capture_physical.length() + 1)):
			return false
	var reconstructed: Dictionary = {"capture_scope": declaration_input, "source_root": source_root, "root_path": root_path, "protected_roots": protected, "profile_source_path": profile_source_path, "excluded_prefixes": prefixes}
	if not root_is_canonical(source_root) or source_root.begins_with("res://") or not root_is_canonical(root_path):
		return false
	var logical_root: String = declaration_input["root_path"]
	var resolved: String = source_root if logical_root == "res://" else source_root.path_join(logical_root.substr(6))
	if resolved != physical_root(root_path):
		return false
	var expected_prefixes: Array[String] = []
	expected_prefixes.assign(_FIXED_EXCLUSIONS)
	for entry: Dictionary in declaration_input["excluded_roots"]:
		var path: String = entry["path"]
		expected_prefixes.append(path)
	for path: String in expected_prefixes:
		for protected_path: String in protected:
			if paths_intersect(path, protected_path):
				return false
	expected_prefixes.sort()
	return prefixes == expected_prefixes and binding.get("policy_digest") == JSON.stringify(reconstructed).sha256_text()


## 捕获排除根及其父链的存在/目录/真实路径状态；不枚举排除后代。
## [br]
## @api framework_internal
## [br]
## @param binding: 有效 scope binding。
## [br]
## @schema binding: Dictionary，精确包含 capture_scope: Dictionary、source_root: String、root_path: String、protected_roots: Array[String]、profile_source_path: String、excluded_prefixes: Array[String] 和 policy_digest: String；必须通过 binding_is_valid 的规范路径、保护集合及摘要校验。
## [br]
## @return 闭合 success、states 和 error；失败不给部分身份。
## [br]
## @schema return: Dictionary，精确包含 success: bool、states: Array[Dictionary] 和 error: String。
static func capture_root_states(binding: Dictionary) -> Dictionary:
	if not binding_is_valid(binding):
		return {"success": false, "states": [], "error": "捕获身份必须绑定有效范围声明。"}
	var states: Array[Dictionary] = []
	var identity_requests: Dictionary = {}
	var bound_root: String = binding["root_path"]
	var capture_root: String = physical_root(bound_root)
	var paths: Array[String] = [capture_root]
	for entry: Dictionary in binding["capture_scope"]["excluded_roots"]:
		var relative_path: String = entry["path"]
		var current_path: String = capture_root
		for segment: String in relative_path.split("/"):
			current_path = current_path.path_join(segment)
			_append_unique(paths, current_path)
	for path: String in paths:
		if path_crosses_link(path):
			return {"success": false, "states": [], "error": "排除根或父链不能穿过 link/junction。"}
		var exists: bool = DirAccess.dir_exists_absolute(path)
		if FileAccess.file_exists(path):
			return {"success": false, "states": [], "error": "排除根或父链必须是目录。"}
		var directory: DirAccess = DirAccess.open(path) if exists else null
		if exists and (directory == null or directory.get_current_dir().replace("\\", "/").trim_suffix("/") != path):
			return {"success": false, "states": [], "error": "排除根或父链实际目录 identity 不匹配。"}
		states.append({"path": path, "exists": exists})
		_register_identity_path(path, identity_requests)
	if not _qualify_directory_entries(identity_requests):
		return {"success": false, "states": [], "error": "实际目录条目拼写不匹配或身份枚举超过有限预算。"}
	return {"success": true, "states": states, "error": ""}


## 只接受规范 res:// 根或绝对本地路径，拒绝点段、链接别名与设备/网络路径形状。
## [br]
## @api framework_internal
## [br]
## @param path: 根路径。
## [br]
## @return 路径是否具有规范形状；物理 link 检查独立执行。
static func root_is_canonical(path: String) -> bool:
	if path.is_empty() or path.length() > 16_384 or path != path.strip_edges() or path.contains("\\") or path.ends_with("/") and path != "res://" and path != "/":
		return false
	if path.begins_with("res://"):
		return path == "res://" or _relative_shape_is_valid(path.substr(6))
	if not path.is_absolute_path() or path.begins_with("//") or path.contains("://"):
		return false
	var tail: String = path.substr(3) if path.length() > 2 and path[1] == ":" else path.substr(1)
	return not tail.is_empty() and _relative_shape_is_valid(tail)


## 转成标准斜杠绝对来源根，仅做确定性表示转换，不授权新的读取根。
## [br]
## @api framework_internal
## [br]
## @param path: 已准入根或来源文件路径。
## [br]
## @return 实际绝对路径。
static func physical_root(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").trim_suffix("/")


## 声明根使用 portable ASCII literal，不把 Unicode to_lower 当作完整路径等价。
## [br]
## @api framework_internal
## [br]
## @param path: 项目相对 literal 路径。
## [br]
## @return 路径是否规范且有界。
static func literal_path_is_valid(path: String) -> bool:
	if path.length() > 1_024 or not _relative_shape_is_valid(path):
		return false
	for codepoint: int in path.to_utf8_buffer():
		if codepoint < 33 or codepoint > 126 or codepoint in [34, 42, 60, 62, 63, 91, 93, 124]:
			return false
	for segment: String in path.split("/"):
		if segment.ends_with(".") or segment.ends_with(" "):
			return false
		var stem: String = segment.get_slice(".", 0).to_lower()
		if stem in ["con", "prn", "aux", "nul"] or (stem.length() == 4 and stem.left(3) in ["com", "lpt"] and stem[3] in "123456789"):
			return false
	return true


## 完整路径段双向相交，大小写 alias 不能绕开硬保护。
## [br]
## @api framework_internal
## [br]
## @param left: 第一个 literal 路径。
## [br]
## @param right: 第二个 literal 路径。
## [br]
## @return 是否相同或任一为另一方祖先。
static func paths_intersect(left: String, right: String) -> bool:
	var left_key: String = left.to_lower()
	var right_key: String = right.to_lower()
	return left_key == right_key or left_key.begins_with(right_key + "/") or right_key.begins_with(left_key + "/")


## 逐父目录检查 link，保留 DirAccess 路径级并发窗口，不声称原子 no-follow。
## [br]
## @api framework_internal
## [br]
## @param path: 已准入物理路径。
## [br]
## @return 父链是否发现链接。
static func path_crosses_link(path: String) -> bool:
	var current_path: String = physical_root(path)
	while not current_path.is_empty():
		var parent_path: String = current_path.get_base_dir()
		if parent_path == current_path or parent_path.is_empty():
			break
		var parent: DirAccess = DirAccess.open(parent_path)
		if parent != null and parent.is_link(current_path.get_file()):
			return true
		current_path = parent_path
	return false


# --- 私有/辅助方法 ---

## 收集身份链所需的精确条目；同一父目录只枚举一次，缺失路径保持缺失而不授权别名。
## [br]
## @api private
static func _register_identity_path(path: String, requests: Dictionary) -> void:
	var current: String = path
	while current != "/" and not (current.length() == 3 and current[1] == ":" and current[2] == "/"):
		var separator: int = current.rfind("/")
		if separator < 0:
			return
		var parent: String = current.substr(0, separator)
		if parent.is_empty():
			parent = "/"
		elif parent.ends_with(":"):
			parent += "/"
		if not requests.has(parent):
			requests[parent] = {}
		var names: Dictionary = requests[parent]
		names[current.substr(separator + 1)] = false
		current = parent


## 只保留请求条目的资格标记，枚举总工作量固定有界；OS 同名别名不能替代真实条目。
## [br]
## @api private
static func _qualify_directory_entries(requests: Dictionary) -> bool:
	var entry_count: int = 0
	for parent: String in requests:
		if not DirAccess.dir_exists_absolute(parent):
			continue
		var directory: DirAccess = DirAccess.open(parent)
		if directory == null:
			return false
		directory.include_hidden = true
		if directory.list_dir_begin() != OK:
			return false
		var names: Dictionary = requests[parent]
		var pending: int = names.size()
		var entry_name: String = directory.get_next()
		while not entry_name.is_empty() and pending > 0:
			entry_count += 1
			if entry_count > _MAX_IDENTITY_ENTRIES:
				directory.list_dir_end()
				return false
			if names.has(entry_name) and not names[entry_name] and directory.current_is_dir() and not directory.is_link(entry_name):
				names[entry_name] = true
				pending -= 1
			entry_name = directory.get_next()
		directory.list_dir_end()
		for entry: String in names:
			if not names[entry] and DirAccess.dir_exists_absolute(parent.path_join(entry)):
				return false
	return true

## 相对路径语法允许普通 Unicode 库存名，声明 literal 另有更窄资格。
## [br]
## @api private
static func _relative_shape_is_valid(path: String) -> bool:
	if path.is_empty() or path.contains(":") or path.contains("\\") or path.begins_with("/") or path.ends_with("/"):
		return false
	for segment: String in path.split("/", true):
		if segment.is_empty() or segment in [".", ".."]:
			return false
	return true


## 检查字典只具有指定字段且没有缺项。
## [br]
## @api private
static func _exact_fields(value: Dictionary, fields: PackedStringArray) -> bool:
	if value.size() != fields.size():
		return false
	for key_value: Variant in value.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not fields.has(key):
			return false
	return true


## 从已准入 profile 取数组，不产生新的类型转换。
## [br]
## @api private
static func _array(value: Dictionary, key: String) -> Array:
	var item: Variant = value.get(key, [])
	return item if item is Array else []


## 保留集合唯一成员，数量最终由 authority 整体准入。
## [br]
## @api private
static func _append_unique(paths: Array[String], path: String) -> void:
	if not paths.has(path):
		paths.append(path)


## 有限排除声明按 literal path 稳定排序。
## [br]
## @api private
static func _excluded_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_path: String = left["path"]
	var right_path: String = right["path"]
	return left_path < right_path


## 声明失败不发布部分规范数据。
## [br]
## @api private
static func _declaration_failure(error: String) -> Dictionary:
	return {"success": false, "declaration": {}, "error": error}


## 来源准入失败不发布可执行捕获授权。
## [br]
## @api private
static func _binding_failure(error: String) -> Dictionary:
	return {"success": false, "binding": {}, "error": error}
