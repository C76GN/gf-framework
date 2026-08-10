## GFScriptTypeInspector: GDScript 类型关系查询器。
##
## 提供脚本继承链查询和继承判断，供运行时容器、编辑器工具和扩展模块复用。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFScriptTypeInspector
extends RefCounted


# --- 框架内部方法 ---

## 判断 candidate 是否等于或继承 expected。
## [br]
## @api framework_internal
## [br]
## @param candidate: 待检查脚本。
## [br]
## @param expected: 期望脚本。
## [br]
## @return candidate 等于或继承 expected 时返回 true。
static func script_extends_or_equals(candidate: Script, expected: Script) -> bool:
	if candidate == null or expected == null:
		return false

	var current: Script = candidate
	while current != null:
		if current == expected:
			return true
		current = current.get_base_script()
	return false


## 判断 candidate 是否等于或继承列表中的任一脚本。
## [br]
## @api framework_internal
## [br]
## @param candidate: 待检查脚本。
## [br]
## @param expected_scripts: 期望脚本列表。
## [br]
## @schema expected_scripts: Array[Script]
## [br]
## @return 命中任一脚本时返回 true。
static func script_extends_any(candidate: Script, expected_scripts: Array) -> bool:
	for expected_variant: Variant in expected_scripts:
		if not (expected_variant is Script):
			continue
		var expected: Script = expected_variant
		if expected != null and script_extends_or_equals(candidate, expected):
			return true
	return false


## 获取脚本继承链，包含 candidate 自身。
## [br]
## @api framework_internal
## [br]
## @param candidate: 待查询脚本。
## [br]
## @return 从自身到根基类脚本的继承链。
static func get_inheritance_chain(candidate: Script) -> Array[Script]:
	var result: Array[Script] = []
	var current: Script = candidate
	while current != null:
		result.append(current)
		current = current.get_base_script()
	return result
