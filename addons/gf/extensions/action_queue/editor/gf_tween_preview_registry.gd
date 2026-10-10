@tool

## GFTweenPreviewRegistry: 显式选择的有界数值预览适配器目录。
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


# --- 框架内部方法 ---

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

## 先移除全部失效 owner，再发出一次变更信号；不持有 owner 强引用。
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
	if not retired.is_empty():
		changed.emit()
