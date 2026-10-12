@tool

## GFTweenPreviewRegistry: 编辑器预览样机与资源关联的有界目录。
##
## owner 使用弱引用；ID 不自动覆盖，内置样机不进入此目录。注册不读取来源或执行适配器。
## 工具插件应持有返回句柄并在退出时 release；owner 失效与租约变化使旧会话失效。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since unreleased
class_name GFTweenPreviewRegistry
extends RefCounted


# --- 信号 ---

## 目录有实际增删时发出；观察者应重新获取独立快照。
## [br]
## @api public
## [br]
## @since unreleased
signal changed


# --- 常量 ---

## 共用有界数值记录校验与搜索，不枚举实际对象。
## [br]
## @api private
const _RECORDS_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_property_records.gd")


# --- 私有变量 ---

## 当前 Inspector 使用的共享目录；普通 new 可创建隔离目录供宿主工具或测试。
## [br]
## @api private
static var _shared: GFTweenPreviewRegistry = null

## ID 到 owner/adapter/descriptor/lease 的内部条目，不公开对象引用。
## [br]
## @api private
var _entries: Dictionary = {}

## 规范资源路径到编辑器预览意图；所有者弱持有，不加载关联资源。
## [br]
## @api private
var _bindings: Dictionary = {}

## 未保存或无声明资源在本次编辑器会话的选择；弱来源防止延长资源生命。
## [br]
## @api private
var _selections: Dictionary = {}

## 每次成功注册递增，旧句柄不能撤销重注册条目。
## [br]
## @api private
var _next_lease: int = 0


# --- 公共方法 ---

## 获取原生 Tween Inspector 与步骤选择器使用的共享目录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 共享注册表；不在此处自动发现或执行项目脚本。
static func get_shared() -> GFTweenPreviewRegistry:
	if _shared == null:
		_shared = GFTweenPreviewRegistry.new()
	return _shared


## 注册完整描述；重复 ID、无效 owner 或超出 32 个适配器预算时整组拒绝。
## revision 改变须先释放旧句柄再重新注册，不做隐式优先级选择。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 有效弱持有者；通常为项目 EditorPlugin。
## [br]
## @param descriptor: 闭合纯值描述。
## [br]
## @schema descriptor: Dictionary，恰含 id: String（1..64 字符标识符）、revision: int（1..2147483647）、label: String（1..96 字符）、properties: Array[Dictionary]（结构同 GFTweenNumericTimeline.capture 的 properties）。
## [br]
## @param adapter: 受信任的隔离样机实现，不应强持 owner 或来源配置。
## [br]
## @return: 成功所有权句柄；拒绝返回 null，不产生部分注册。
func register_adapter(owner: Object, descriptor: Dictionary, adapter: GFTweenPreviewAdapter) -> GFTweenPreviewRegistration:
	_prune()
	if not is_instance_valid(owner) or adapter == null or _entries.size() >= 32 or descriptor.size() != 4:
		return null
	for key: Variant in descriptor:
		if not (key is String) or not key in ["id", "revision", "label", "properties"]:
			return null
	if not (descriptor.get("id") is String) or not (descriptor.get("label") is String) or not (descriptor.get("revision") is int) or not (descriptor.get("properties") is Array):
		return null
	var id_text: String = descriptor["id"]
	var label: String = descriptor["label"]
	var revision: int = descriptor["revision"]
	if id_text.is_empty() or id_text.length() > 64 or not id_text.is_valid_identifier() or _entries.has(StringName(id_text)):
		return null
	if label.is_empty() or label.length() > 96 or revision < 1 or revision > 2147483647:
		return null
	var values: Array = descriptor["properties"]
	if values.size() > 32:
		return null
	var properties: Array[Dictionary] = []
	for value: Variant in values:
		if not (value is Dictionary):
			return null
		var property: Dictionary = value
		properties.append(property)
	if not _RECORDS_SCRIPT.validate_numeric(properties).is_empty():
		return null
	_next_lease += 1
	var id: StringName = StringName(id_text)
	_entries[id] = {"owner": weakref(owner), "adapter": adapter, "descriptor": descriptor.duplicate(true), "lease": _next_lease}
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistration.new()
	handle._bind(self, id, _next_lease)
	changed.emit()
	return handle


## 获取全部有效描述，不暴露 owner、adapter 或内部租约。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 最多 32 项独立描述，按 ID 字典序排序。
## [br]
## @schema return: Array[Dictionary]，每项同 register_adapter 的 descriptor。
func get_descriptors() -> Array[Dictionary]:
	_prune()
	var results: Array[Dictionary] = []
	var ids: Array = _entries.keys()
	ids.sort()
	for id: Variant in ids:
		var entry: Dictionary = _entries[id]
		var descriptor: Dictionary = entry["descriptor"]
		results.append(descriptor.duplicate(true))
	return results


## 搜索显式适配器的有限属性目录；不触发样机或来源 getter。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param adapter_id: 已注册 ID。
## [br]
## @param query: 大小写无关子串，最多 128 字符。
## [br]
## @return: 独立匹配记录；失效 ID 或超限搜索为空。
## [br]
## @schema return: Array[Dictionary]，name: String、type: int、initial: int/float、minimum/maximum: int/float、source: String、supported: bool、reason: String。
func get_property_records(adapter_id: StringName, query: String = "") -> Array[Dictionary]:
	var entry: Dictionary = _get_entry(adapter_id)
	if entry.is_empty():
		return []
	var descriptor: Dictionary = entry["descriptor"]
	var properties: Array[Dictionary] = []
	var values: Array = descriptor["properties"]
	for value: Variant in values:
		var property: Dictionary = value
		properties.append(property)
	return _RECORDS_SCRIPT.search(_RECORDS_SCRIPT.get_numeric_records(properties, String(adapter_id)), query)


## 声明已保存资源的默认预览用途和起态；不改写或加载运行配置。
## 每个规范 res:// 路径只能有一个有效声明，最多 256 条；目标可稍后注册。
## 初值按目标属性目录二次校验，错误声明不会自动回退其他样机。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 弱持有的编辑器插件所有者。
## [br]
## @param resource_path: 至多 1024 字符的规范 res:// 资源路径，可包含子资源标识。
## [br]
## @param target_id: 项目适配器 ID，或 gf.preview.2d、gf.preview.ui、gf.preview.3d。
## [br]
## @param initial_values: 至多 32 个样机初值表根属性的覆盖；不接受分量路径。原生旋转使用 rotation 弧度，不以 rotation_degrees 别名声明初值。
## [br]
## @schema initial_values: Dictionary，String 属性名映射到有限 int/float/Vector2/Vector3/Color，分量绝对值不超过 1000000。
## [br]
## @param label: 可选用途名称，至多 96 字符；空串使用样机名称。
## [br]
## @return: 成功租约；无效声明、重复路径或超出预算返回 null，不产生部分登记。
func register_binding(
	owner: Object, resource_path: String, target_id: StringName,
	initial_values: Dictionary = {}, label: String = ""
) -> GFTweenPreviewRegistration:
	_prune()
	var id_text: String = String(target_id)
	var native: bool = target_id in [&"gf.preview.2d", &"gf.preview.ui", &"gf.preview.3d"]
	if (
		not is_instance_valid(owner) or not _valid_resource_path(resource_path)
		or _bindings.has(resource_path) or _bindings.size() >= 256
		or id_text.is_empty() or id_text.length() > 64
		or (not native and not id_text.is_valid_identifier())
		or label.length() > 96 or not _valid_initial_values(initial_values)
	):
		return null
	_next_lease += 1
	_bindings[resource_path] = {
		"owner": weakref(owner), "lease": _next_lease,
		"resource_path": resource_path, "target_id": target_id,
		"initial_values": initial_values.duplicate(true), "label": label,
	}
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistration.new()
	handle._bind(self, StringName(resource_path), _next_lease, true)
	changed.emit()
	return handle


## 查询资源默认预览声明的独立纯值副本；不执行适配器或资源方法。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param resource_path: 注册时的规范资源路径。
## [br]
## @return: 有效声明；没有声明或所有者失效时为空。
## [br]
## @schema return: Dictionary，空或 resource_path: String、target_id: StringName、initial_values: Dictionary（同 register_binding）、label: String；不含所有者或租约。
func get_binding(resource_path: String) -> Dictionary:
	var entry: Dictionary = _get_binding_entry(resource_path)
	if entry.is_empty():
		return {}
	var initial_values: Dictionary = entry["initial_values"]
	return {
		"resource_path": entry["resource_path"], "target_id": entry["target_id"],
		"initial_values": initial_values.duplicate(true), "label": entry["label"],
	}


# --- 框架内部方法 ---

## 获取有界声明及租约；调用者不得强持有其弱所有者。
## [br]
## @api framework_internal
## [br]
## @param resource_path: 规范资源路径。
## [br]
## @return: 内部条目副本或空字典。
## [br]
## @schema return: Dictionary，空或 get_binding 字段，加 owner: WeakRef、lease: int。
func _get_binding_entry(resource_path: String) -> Dictionary:
	_prune()
	var entry: Dictionary = _bindings.get(resource_path, {})
	return entry.duplicate(true)


## 验证资源关联租约仍由有效所有者持有。
## [br]
## @api framework_internal
## [br]
## @param resource_path: 关联路径。
## [br]
## @param lease: 捕获的正租约。
## [br]
## @return: 当前租约仍有效时为 true。
func _has_binding_lease(resource_path: String, lease: int) -> bool:
	var entry: Dictionary = _get_binding_entry(resource_path)
	return lease > 0 and not entry.is_empty() and entry["lease"] == lease


## 只撤销当前匹配的资源关联；旧句柄不能移除后续声明。
## [br]
## @api framework_internal
## [br]
## @param resource_path: 关联路径。
## [br]
## @param lease: 句柄持有的正租约。
func _release_binding(resource_path: String, lease: int) -> void:
	var entry: Dictionary = _bindings.get(resource_path, {})
	if not entry.is_empty() and entry["lease"] == lease:
		var _removed: bool = _bindings.erase(resource_path)
		changed.emit()


## 读取同一来源仍存活时的工具选择；不会跨来源实例继承隐式选择。
## [br]
## @api framework_internal
## [br]
## @param config: 精确原生来源实例。
## [br]
## @return: 选择副本或空字典。
## [br]
## @schema return: Dictionary，空或 id: StringName、initial_values: Dictionary（同 register_binding）。
func _get_selection(config: Resource) -> Dictionary:
	_prune()
	if not is_instance_valid(config):
		return {}
	var entry: Dictionary = _selections.get(config.get_instance_id(), {})
	if entry.is_empty():
		return {}
	var source: WeakRef = entry["source"]
	if source.get_ref() != config:
		return {}
	var initial_values: Dictionary = entry["initial_values"]
	return {"id": entry["id"], "initial_values": initial_values.duplicate(true)}


## 在当前编辑器会话记住人工选择；不会写入 Resource 或项目设置。
## [br]
## @api framework_internal
## [br]
## @param config: 弱持有的精确来源实例。
## [br]
## @param target_id: 选择的目标 ID。
## [br]
## @param initial_values: 已按目标校验的根属性覆盖。
## [br]
## @schema initial_values: Dictionary，同 register_binding。
func _remember_selection(config: Resource, target_id: StringName, initial_values: Dictionary) -> void:
	_prune()
	if not is_instance_valid(config) or not _valid_initial_values(initial_values):
		return
	var key: int = config.get_instance_id()
	if not _selections.has(key) and _selections.size() >= 256:
		return
	_selections[key] = {"source": weakref(config), "id": target_id, "initial_values": initial_values.duplicate(true)}

## 取得内部条目副本；只有 GF 自有预览控制器消费 adapter 引用。
## [br]
## @api framework_internal
## [br]
## @param adapter_id: 明确选择的 ID。
## [br]
## @return: 内部条目或空字典。
## [br]
## @schema return: Dictionary，空或 owner: WeakRef、adapter: GFTweenPreviewAdapter、descriptor: Dictionary（register_adapter schema）、lease: int。
func _get_entry(adapter_id: StringName) -> Dictionary:
	_prune()
	if not _entries.has(adapter_id):
		return {}
	var entry: Dictionary = _entries[adapter_id]
	return entry.duplicate(true)


## 验证正租约仍归有效 owner。
## [br]
## @api framework_internal
## [br]
## @param adapter_id: 注册 ID。
## [br]
## @param lease: 捕获租约。
## [br]
## @return: 仍有效时为 true。
func _has_lease(adapter_id: StringName, lease: int) -> bool:
	var entry: Dictionary = _get_entry(adapter_id)
	return lease > 0 and not entry.is_empty() and entry["lease"] == lease


## 仅释放匹配租约；先删记录再发信号以允许重入重新注册。
## [br]
## @api framework_internal
## [br]
## @param adapter_id: 注册 ID。
## [br]
## @param lease: 句柄持有的租约。
func _release(adapter_id: StringName, lease: int) -> void:
	if _entries.has(adapter_id):
		var entry: Dictionary = _entries[adapter_id]
		if entry["lease"] == lease:
			var _removed: bool = _entries.erase(adapter_id)
			changed.emit()


# --- 私有/辅助方法 ---

## 先移除失效所有者与弱来源；目录或关联变化只发一次信号，不持有所有者强引用。
## [br]
## @api private
func _prune() -> void:
	var retired: Array[StringName] = []
	for id: Variant in _entries:
		var entry: Dictionary = _entries[id]
		var owner: WeakRef = entry["owner"]
		if not is_instance_valid(owner.get_ref()):
			retired.append(id)
	for id: StringName in retired:
		var _removed: bool = _entries.erase(id)
	var retired_bindings: Array[String] = []
	for path: Variant in _bindings:
		var entry: Dictionary = _bindings[path]
		var owner: WeakRef = entry["owner"]
		if not is_instance_valid(owner.get_ref()):
			retired_bindings.append(path)
	for path: String in retired_bindings:
		var _removed: bool = _bindings.erase(path)
	var retired_selections: Array[int] = []
	for key: Variant in _selections:
		var entry: Dictionary = _selections[key]
		var source: WeakRef = entry["source"]
		if not is_instance_valid(source.get_ref()):
			retired_selections.append(key)
	for key: int in retired_selections:
		var _removed: bool = _selections.erase(key)
	if not retired.is_empty() or not retired_bindings.is_empty():
		changed.emit()


## 仅接纳精确的 res:// 身份，不修正有歧义的分隔符或目录穿越。
## [br]
## @api private
func _valid_resource_path(resource_path: String) -> bool:
	if not resource_path.begins_with("res://") or resource_path.length() > 1024:
		return false
	var relative: String = resource_path.trim_prefix("res://")
	if relative.is_empty() or relative.contains("\\") or relative.contains("\n") or relative.contains("\r"):
		return false
	for index: int in range(relative.length()):
		if relative.unicode_at(index) == 0:
			return false
	for part: String in relative.split("/", true):
		if part.is_empty() or part in [".", ".."]:
			return false
	return true


## 初值只允许有界纯标量和数值向量；属性类型及范围由选择的目录校验。
## [br]
## @api private
func _valid_initial_values(values: Dictionary) -> bool:
	if values.size() > 32:
		return false
	for key: Variant in values:
		if not key is String:
			return false
		var property_name: String = key
		if property_name.length() > 64 or not property_name.is_valid_identifier():
			return false
		var value: Variant = values[key]
		var numbers: Array[float] = []
		if value is float:
			var number: float = value
			numbers.append(number)
		elif value is int:
			var number: int = value
			numbers.append(float(number))
		elif value is Vector2:
			var vector: Vector2 = value
			numbers.assign([vector.x, vector.y])
		elif value is Vector3:
			var vector: Vector3 = value
			numbers.assign([vector.x, vector.y, vector.z])
		elif value is Color:
			var color: Color = value
			numbers.assign([color.r, color.g, color.b, color.a])
		else:
			return false
		for number: float in numbers:
			if not is_finite(number) or absf(number) > 1000000.0:
				return false
	return true
