@tool

## GFTweenPreviewContext: 同一原生资源的编辑器预览选择、起态与属性目录。
##
## 不加载实际场景或执行样机；无声明首次只选择唯一兼容候选，来源编辑不抹掉已接纳用途。
## 面板与步骤编辑器共用此实例，刷新不改变已捕获的播放会话。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFTweenPreviewContext
extends RefCounted


# --- 信号 ---

## 选择、初值或兼容性实际改变时发出；消费者按目标租约判断会话是否需要撤销。
## [br]
## @api framework_internal
signal changed

## 请求选中仍与来源身份一致的步骤；接收者须用 is_navigation_request_current 再次验证同步重入。
## [br]
## @api framework_internal
## [br]
## @param request: 当前请求的纯值快照。
## [br]
## @schema request: Dictionary，serial: int、step_index: int、field: StringName、snapshot: Dictionary（同 get_navigation_snapshot）。
signal step_selection_requested(request: Dictionary)


# --- 常量 ---

## 仅接受此精确配置，读取其原生字段不执行项目 getter。
## [br]
## @api private
const _CONFIG_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd")

## 原生和项目数值属性的共同目录与校验。
## [br]
## @api private
const _RECORDS_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_property_records.gd")

## 有界纯值来源签名；未变化时不重复烘焙和编译所有候选。
## [br]
## @api private
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")

## 三个内置样机的稳定编辑器标识；点号不能与项目标识符冲突。
## [br]
## @api private
const _NATIVE_IDS: Array[StringName] = [&"gf.preview.2d", &"gf.preview.ui", &"gf.preview.3d"]

## 内置样机显示用途，不代表真实项目场景。
## [br]
## @api private
const _NATIVE_LABELS: Array[String] = ["2D 属性演示", "UI 属性演示", "3D 属性演示"]

## 作者表单可定位的字段；空字段只选择步骤，不推断本地化错误文本。
## [br]
## @api private
const _NAVIGATION_FIELDS: Array[StringName] = [
	&"", &"resource_name", &"property_name", &"target_value", &"duration", &"delay",
	&"as_relative", &"parallel", &"transition_type", &"ease_type", &"easing_curve", &"marker_id",
]


# --- 私有变量 ---

## 弱来源引用，不延长 Inspector 资源生命周期。
## [br]
## @api private
var _source: WeakRef = null

## 目录所有者；工具上下文不持有项目插件或样机。
## [br]
## @api private
var _registry: GFTweenPreviewRegistry = null

## 完整有限候选目录，包括不兼容理由供作者选择前查看。
## [br]
## @api private
var _choices: Array[Dictionary] = []

## 当前解析结果；每次向消费者提供深副本。
## [br]
## @api private
var _target: Dictionary = {}

## 当前上下文明确选中的用途；没有选择时为空名。
## [br]
## @api private
var _manual_id: StringName = &""

## 此上下文已自动接纳的唯一用途；来源编辑保留它，目录失效不猜测另一个用途。
## [br]
## @api private
var _automatic_id: StringName = &""

## 作者修改的初值；不回写来源或共享声明。
## [br]
## @api private
var _overrides: Dictionary = {}

## 防止查询目录时的失效清理信号重入同一次解析。
## [br]
## @api private
var _refreshing: bool = false

## 上次完整解析的纯值输入；深复制防止初值编辑改变历史签名。
## [br]
## @api private
var _last_signature: Array = []

## 每个选择或重绑请求使用新序号；同步嵌套请求撤销之前的焦点资格。
## [br]
## @api private
var _navigation_serial: int = 0

## 最后交付的有界请求，不含控件和资源引用。
## [br]
## @api private
var _navigation_request: Dictionary = {}

## 每个用途的同源准入诊断；来源签名变化时整体重建，最多 35 项。
## [br]
## @api private
var _diagnostics: Dictionary = {}


# --- 框架内部方法 ---

## 绑定来源和目录，恢复本次会话选择后解析默认用途。
## [br]
## @api framework_internal
## [br]
## @param config: 精确原生 Tween 配置；其他资源得到不可用结果。
## [br]
## @param registry: 可选工具目录；null 使用官方共享目录。
func configure(config: Resource, registry: GFTweenPreviewRegistry = null) -> void:
	_navigation_serial += 1
	_navigation_request.clear()
	if _registry != null and _registry.changed.is_connected(_on_registry_changed):
		_registry.changed.disconnect(_on_registry_changed)
	_source = weakref(config) if config != null else null
	_registry = registry if registry != null else GFTweenPreviewRegistry.get_shared()
	var _connected: int = _registry.changed.connect(_on_registry_changed, CONNECT_DEFERRED)
	_manual_id = &""
	_automatic_id = &""
	_overrides.clear()
	_last_signature.clear()
	var selection: Dictionary = _registry._get_selection(config)
	if not selection.is_empty():
		_manual_id = selection["id"]
		var initial_values: Dictionary = selection["initial_values"]
		_overrides = initial_values.duplicate(true)
	refresh()


## 解析声明、兼容候选和初值，不创建样机或改动播放快照。
## [br]
## @api framework_internal
func refresh() -> void:
	if _refreshing or _registry == null:
		return
	_refreshing = true
	var config: Resource = _get_source()
	var descriptors: Array[Dictionary] = _registry.get_descriptors()
	var adapter_leases: Array[int] = []
	for descriptor: Dictionary in descriptors:
		var id_text: String = descriptor["id"]
		var entry: Dictionary = _registry._get_entry(StringName(id_text))
		var lease: int = entry["lease"] if not entry.is_empty() else 0
		adapter_leases.append(lease)
	var binding: Dictionary = _registry._get_binding_entry(config.resource_path) if config != null else {}
	var binding_signature: Array = []
	if not binding.is_empty():
		binding_signature = [binding["lease"], binding["target_id"], binding["initial_values"], binding["label"]]
	var signature: Array = [_SNAPSHOT_SCRIPT.capture(config), descriptors, adapter_leases, binding_signature, _manual_id, _overrides]
	if signature == _last_signature:
		_refreshing = false
		return
	_last_signature = signature.duplicate(true)
	var previous: Dictionary = _target
	var previous_choices: Array[Dictionary] = _choices
	_diagnostics.clear()
	_choices = _build_choices(config, descriptors)
	if config == null or config.get_script() != _CONFIG_SCRIPT:
		_target = _unavailable("请选择原生 Tween 配置资源。")
	else:
		if _manual_id != &"":
			_target = _find_target(_manual_id)
			if _target["id"] == &"":
				_target = _unavailable("选择的预览场景已不可用，请重新选择。")
			else:
				var effective_overrides: Dictionary = _overrides.duplicate(true)
				if not binding.is_empty() and binding["target_id"] == _manual_id:
					_target["binding_lease"] = binding["lease"]
					var label: String = binding["label"]
					if not label.is_empty():
						_target["label"] = label
					var declared_values: Dictionary = binding["initial_values"]
					effective_overrides = declared_values.duplicate(true)
					effective_overrides.merge(_overrides, true)
				_apply_overrides(_target, effective_overrides)
		elif not binding.is_empty():
			var target_id: StringName = binding["target_id"]
			_target = _find_target(target_id)
			if _target["id"] == &"":
				_target = _unavailable("资源声明的预览场景尚未注册：%s。" % String(target_id))
				_target["id"] = target_id
				_target["adapter_id"] = target_id
				_target["binding_lease"] = binding["lease"]
			else:
				_target["binding_lease"] = binding["lease"]
				var label: String = binding["label"]
				if not label.is_empty():
					_target["label"] = label
				var declared_values: Dictionary = binding["initial_values"]
				_apply_overrides(_target, declared_values)
		elif _automatic_id != &"":
			_target = _find_target(_automatic_id)
			if _target["id"] == &"":
				_target = _unavailable("原预览场景已不可用，请重新选择用途。")
		else:
			var compatible: Array[Dictionary] = []
			for choice: Dictionary in _choices:
				if choice["supported"]:
					compatible.append(choice)
			if compatible.size() == 1:
				_target = compatible[0].duplicate(true)
				_automatic_id = _target["id"]
			elif compatible.is_empty():
				_target = _unavailable("没有兼容的预览场景；请登记支持此配置的样机，或检查步骤与预览范围。")
			else:
				_target = _unavailable("有多个兼容的预览场景，请选择用途；选择会在本次编辑器会话中保留。")
	_refreshing = false
	if _navigation_target_identity(previous) != _navigation_target_identity(_target):
		_navigation_serial += 1
		_navigation_request.clear()
	if previous != _target or previous_choices != _choices:
		changed.emit()


## 获取有限候选和兼容性说明的独立副本。
## [br]
## @api framework_internal
## [br]
## @return: 最多 35 个内置与项目候选。
## [br]
## @schema return: Array[Dictionary]，每项 id/adapter_id: StringName、label: String、kind: int（项目为 -1）、supported: bool、reason: String、initial_values: Dictionary、lease/binding_lease/revision: int。
func get_choices() -> Array[Dictionary]:
	return _choices.duplicate(true)


## 获取当前预览用途；不可用结果仍携带稳定字段和面向作者的原因。
## [br]
## @api framework_internal
## [br]
## @return: 当前目标的独立副本。
## [br]
## @schema return: Dictionary，字段同 get_choices 单项；无选择 id 为空、kind=-1、supported=false。
func get_target() -> Dictionary:
	return _target.duplicate(true)


## 取得当前用途同一准入链的结构化错误；全局错误可以展示但没有步骤跳转资格。
## [br]
## @api framework_internal
## [br]
## @return: 四字段独立诊断，成功时位置为空。
## [br]
## @schema return: Dictionary，step_index: int（-1 为全局）、field/error_kind: StringName、message: String。
func get_diagnostic() -> Dictionary:
	var diagnostic_value: Variant = _diagnostics.get(_target.get("id", &""))
	if diagnostic_value is Dictionary:
		var diagnostic: Dictionary = diagnostic_value
		return diagnostic.duplicate(true)
	var reason_value: Variant = _target.get("reason", "")
	var reason: String = ""
	if reason_value is String:
		reason = reason_value
	return {"step_index": -1, "field": &"", "error_kind": &"target_unavailable" if not reason.is_empty() else &"", "message": reason}


## 读取当前来源的作者定位签名；不改变预览快照或来源资源。
## [br]
## @api framework_internal
## [br]
## @return: 有界纯值快照，来源不可编辑时为空。
## [br]
## @schema return: Dictionary，空或 source_id: int、step_ids: PackedInt64Array、names: Array[StringName]、values: Array（播放纯值签名）。
func get_navigation_snapshot() -> Dictionary:
	return _SNAPSHOT_SCRIPT.capture_editing(_get_source())


## 验证来源与步骤实例、名称及纯值仍完全一致；旧快照可以定位画面但不能定位新表单。
## [br]
## @api framework_internal
## [br]
## @param snapshot: get_navigation_snapshot 返回的作者快照。
## [br]
## @schema snapshot: Dictionary，同 get_navigation_snapshot。
## [br]
## @return: 同一有效来源和目录仍拥有定位资格时为 true。
func is_navigation_current(snapshot: Dictionary) -> bool:
	return not snapshot.is_empty() and is_target_current() and snapshot == get_navigation_snapshot()


## 点击时先冻结作者身份，再刷新同一上下文取得诊断；通知改写来源或用途后拒绝旧请求。
## 不把缓存诊断配给新来源签名，不重新准备或修改已经接纳的播放快照。
## [br]
## @api framework_internal
## [br]
## @return: 同一次刷新诊断可交给仍有效的步骤来源时为 true；全局错误或重入失权为 false。
func request_error_selection() -> bool:
	if _refreshing or _registry == null:
		return false
	var config: Resource = _get_source()
	var registry: GFTweenPreviewRegistry = _registry
	var serial: int = _navigation_serial
	var target_identity: Array = _navigation_target_identity(_target)
	var snapshot: Dictionary = get_navigation_snapshot()
	if not is_navigation_current(snapshot):
		return false
	refresh()
	var current: bool = is_navigation_current(snapshot)
	if (
		not current or _get_source() != config or _registry != registry or serial != _navigation_serial
		or target_identity != _navigation_target_identity(_target)
	):
		return false
	var diagnostic: Dictionary = get_diagnostic()
	var index_value: Variant = diagnostic.get("step_index")
	var field_value: Variant = diagnostic.get("field")
	if not index_value is int or not field_value is StringName:
		return false
	var index: int = index_value
	var field_name: StringName = field_value
	if index < 0 or field_name == &"":
		return false
	return request_step_selection(index, field_name, snapshot)


## 把当前合法的步骤及字段交给共享表单；每次通知后再确认来源，重入不会冒充定位成功。
## [br]
## @api framework_internal
## [br]
## @param step_index: 来源的零基步骤索引，必须小于 128。
## [br]
## @param field: 有限步骤字段；空名仅选择步骤。
## [br]
## @param snapshot: 请求来源的有界作者快照。
## [br]
## @schema snapshot: Dictionary，同 get_navigation_snapshot。
## [br]
## @return: 通知后请求仍有效时为 true，不表示有监听表单或执行任何写入。
func request_step_selection(step_index: int, field: StringName, snapshot: Dictionary) -> bool:
	if step_index < 0 or step_index >= 128 or not _NAVIGATION_FIELDS.has(field) or not is_navigation_current(snapshot):
		return false
	var ids_value: Variant = snapshot.get("step_ids")
	if not ids_value is PackedInt64Array:
		return false
	var step_ids: PackedInt64Array = ids_value
	if step_index >= step_ids.size():
		return false
	_navigation_serial += 1
	_navigation_request = {"serial": _navigation_serial, "step_index": step_index, "field": field, "snapshot": snapshot.duplicate(true)}
	var request: Dictionary = _navigation_request.duplicate(true)
	step_selection_requested.emit(request)
	return is_navigation_request_current(request)


## 接收者在通知回调与聚焦后复核同一请求；较新请求、重绑和来源替换均撤销资格。
## [br]
## @api framework_internal
## [br]
## @param request: step_selection_requested 的完整载荷。
## [br]
## @schema request: Dictionary，同 step_selection_requested。
## [br]
## @return: 请求序号和当前作者身份都相同才为 true。
func is_navigation_request_current(request: Dictionary) -> bool:
	if request.is_empty() or request != _navigation_request:
		return false
	var snapshot_value: Variant = request.get("snapshot")
	if not snapshot_value is Dictionary:
		return false
	var snapshot: Dictionary = snapshot_value
	return is_navigation_current(snapshot)


## 获取与选择一致的目录，供样机控制器验证同一目录的租约。
## [br]
## @api framework_internal
## [br]
## @return: configure 时绑定的目录。
func get_registry() -> GFTweenPreviewRegistry:
	return _registry


## 只检查目录和声明租约，不重新编译来源；推进前用来阻止撤销后的旧会话。
## [br]
## @api framework_internal
## [br]
## @return: 当前目标租约仍有效时为 true；无目标本身不需要撤销会话。
func is_target_current() -> bool:
	if _target.is_empty() or _target["id"] == &"":
		return true
	var adapter_id: StringName = _target["adapter_id"]
	var lease: int = _target["lease"]
	if adapter_id != &"" and not _registry._has_lease(adapter_id, lease):
		return false
	var binding_lease: int = _target["binding_lease"]
	var config: Resource = _get_source()
	if config == null:
		return false
	return binding_lease == 0 or _registry._has_binding_lease(config.resource_path, binding_lease)


## 明确切换预览用途并清除旧场景的初值覆盖；不修改动画配置。
## [br]
## @api framework_internal
## [br]
## @param target_id: get_choices 返回的目标 ID；可选择暂不兼容的目录来纠正配置。
## [br]
## @return: 目标存在且选择被接纳时为 true；是否可预览由 get_target 的 supported 指示。
func select_target(target_id: StringName) -> bool:
	var next: Dictionary = _find_target(target_id)
	if next["id"] == &"":
		return false
	_navigation_serial += 1
	_navigation_request.clear()
	_manual_id = target_id
	_overrides.clear()
	_registry._remember_selection(_get_source(), target_id, _overrides)
	refresh()
	return true


## 为当前有效目录设置根属性起态；完整候选可修复旧计划的初值错误，拒绝保持原选择和原初值。
## [br]
## @api framework_internal
## [br]
## @param property_name: 当前目录中的完整根属性名。
## [br]
## @param value: 与目录类型和边界一致的候选初值。
## [br]
## @schema value: Variant，有限 int/float/Vector2/Vector3/Color。
## [br]
## @return: 覆盖被接纳时为 true。
func set_initial_value(property_name: StringName, value: Variant) -> bool:
	if _target.is_empty() or _target["id"] == &"" or not is_target_current():
		return false
	var current_values: Dictionary = _target["initial_values"]
	var values: Dictionary = current_values.duplicate(true)
	values[String(property_name)] = value
	var candidate: Dictionary = _target.duplicate(true)
	var effective_overrides: Dictionary = values.duplicate(true)
	var config: Resource = _get_source()
	var binding: Dictionary = _registry._get_binding_entry(config.resource_path) if config != null else {}
	if not binding.is_empty() and binding["target_id"] == _target["id"]:
		var declared_values: Dictionary = binding["initial_values"]
		effective_overrides = declared_values.duplicate(true)
		effective_overrides.merge(values, true)
	_apply_overrides(candidate, effective_overrides)
	if not candidate["supported"]:
		return false
	_manual_id = _target["id"]
	_overrides = values
	_registry._remember_selection(_get_source(), _manual_id, _overrides)
	refresh()
	return true


## 使用当前用途和起态提供属性浏览记录；不枚举真实场景或来源 getter。
## [br]
## @api framework_internal
## [br]
## @param query: 至多 128 字符的名称子串。
## [br]
## @return: 与当前预览一致的独立目录。
## [br]
## @schema return: Array[Dictionary]，name: String、type: int、initial: 数值或向量、minimum/maximum: float、source: String、supported: bool、reason: String。
func get_property_records(query: String = "") -> Array[Dictionary]:
	if _target.is_empty() or _target["id"] == &"":
		return []
	var kind: int = _target["kind"]
	var records: Array[Dictionary] = []
	if kind >= 0:
		records = _RECORDS_SCRIPT.get_native_records(kind)
	else:
		var adapter_id: StringName = _target["adapter_id"]
		records = _registry.get_property_records(adapter_id)
	var values: Dictionary = _target["initial_values"]
	for record: Dictionary in records:
		var property_name: String = record["name"]
		var root_name: String = property_name.get_slice(":", 0)
		var root_value: Variant = values.get(root_name)
		if root_name == "rotation_degrees":
			var rotation: Variant = values.get("rotation")
			if rotation is float:
				var angle: float = rotation
				root_value = rad_to_deg(angle)
			elif rotation is Vector3:
				var angles: Vector3 = rotation
				root_value = angles * (180.0 / PI)
		if not property_name.contains(":") and root_value != null:
			record["initial"] = root_value
		elif property_name.contains(":"):
			var component: String = property_name.get_slice(":", 1)
			if root_value is Vector2:
				var vector: Vector2 = root_value
				record["initial"] = vector.x if component == "x" else vector.y
			elif root_value is Vector3:
				var vector: Vector3 = root_value
				record["initial"] = vector.x if component == "x" else (vector.y if component == "y" else vector.z)
			elif root_value is Color:
				var color: Color = root_value
				record["initial"] = color["rgba".find(component)]
	return _RECORDS_SCRIPT.search(records, query)


# --- 私有/辅助方法 ---

## 比较影响定位资格的目标身份；标签或兼容提示变化不撤销相同目录身份。
## [br]
## @api private
func _navigation_target_identity(target: Dictionary) -> Array:
	return [target.get("id"), target.get("kind"), target.get("adapter_id"), target.get("initial_values"), target.get("lease"), target.get("binding_lease"), target.get("revision")]


## 收窄弱来源；资源被释放时返回 null。
## [br]
## @api private
func _get_source() -> Resource:
	if _source != null:
		var source: Variant = _source.get_ref()
		if source is Resource:
			var config: Resource = source
			return config
	return null


## 使用已有工具准入和运行采样器检查最多 35 个候选，不调用样机钩子。
## [br]
## @api private
func _build_choices(config: Resource, descriptors: Array[Dictionary]) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for kind: int in range(3):
		var choice: Dictionary = _unavailable("")
		choice["id"] = _NATIVE_IDS[kind]
		choice["label"] = _NATIVE_LABELS[kind]
		choice["kind"] = kind
		choice["initial_values"] = GFTweenPreviewPlan.get_initial_values(kind)
		_check_target(choice, config)
		choices.append(choice)
	for descriptor: Dictionary in descriptors:
		var choice: Dictionary = _unavailable("")
		var id_text: String = descriptor["id"]
		var adapter_id: StringName = StringName(id_text)
		choice["id"] = adapter_id
		choice["adapter_id"] = adapter_id
		choice["label"] = descriptor["label"]
		choice["revision"] = descriptor["revision"]
		var entry: Dictionary = _registry._get_entry(adapter_id)
		if entry.is_empty():
			continue
		choice["lease"] = entry["lease"]
		var values: Dictionary = {}
		var properties: Array = descriptor["properties"]
		for property_value: Variant in properties:
			var property: Dictionary = property_value
			values[property["name"]] = property["initial"]
		choice["initial_values"] = values
		_check_target(choice, config)
		choices.append(choice)
	return choices


## 查找目标的独立值快照；不存在时保留完整不可用字段。
## [br]
## @api private
func _find_target(target_id: StringName) -> Dictionary:
	for choice: Dictionary in _choices:
		if choice["id"] == target_id:
			return choice.duplicate(true)
	return _unavailable("预览场景未注册。")


## 闭合不可用结果，避免控件把缺失选择解释为内置二维样机。
## [br]
## @api private
func _unavailable(reason: String) -> Dictionary:
	return {
		"id": &"", "adapter_id": &"", "kind": -1, "label": "",
		"supported": false, "reason": reason, "initial_values": {},
		"lease": 0, "binding_lease": 0, "revision": 0,
	}


## 覆盖仅限同一目录完整属性；再用同一准入链复核初值影响的相对和往返采样。
## [br]
## @api private
func _apply_overrides(target: Dictionary, overrides: Dictionary) -> void:
	var current_values: Dictionary = target["initial_values"]
	var values: Dictionary = current_values.duplicate(true)
	for key: Variant in overrides:
		if not key is String or not values.has(key):
			target["supported"] = false
			target["reason"] = "预览初值包含当前场景未声明的根属性。"
			return
		values[key] = overrides[key]
	target["initial_values"] = values
	_check_target(target, _get_source())


## 同时验证属性、初值和完整有限计划，不复制另一套缓动或分组规则。
## [br]
## @api private
func _check_target(target: Dictionary, config: Resource) -> void:
	var kind: int = target["kind"]
	var values: Dictionary = target["initial_values"]
	var plan: GFTweenPreviewPlan = null
	var error: String = ""
	if kind >= 0:
		for key: Variant in values:
			var property_name: String = key
			if not GFTweenPreviewPlan.validate_initial_value(StringName(property_name), values[key], kind).is_empty():
				error = "预览初值的类型或数值范围无效：%s。" % property_name
				break
		if error.is_empty():
			plan = GFTweenPreviewPlan.capture(config, kind)
			if plan.error.is_empty() and plan.controlled:
				var baseline: Dictionary = GFTweenPreviewPlan.build_controlled_baseline(plan.steps, values)
				var controlled: GFTweenPlaybackPlan = GFTweenPlaybackPlan.capture_data(plan.steps, baseline, plan.loop_count, 1.0, plan.ping_pong)
				error = controlled.error
	else:
		var adapter_id: StringName = target["adapter_id"]
		var entry: Dictionary = _registry._get_entry(adapter_id)
		if entry.is_empty():
			error = "预览场景已注销。"
		else:
			var descriptor: Dictionary = entry["descriptor"]
			var raw_records: Array = descriptor["properties"]
			var records: Array[Dictionary] = []
			for value: Variant in raw_records:
				var property: Dictionary = value
				var record: Dictionary = property.duplicate(true)
				record["initial"] = values[record["name"]]
				records.append(record)
			error = _RECORDS_SCRIPT.validate_numeric(records)
			if error.is_empty():
				plan = GFTweenPreviewPlan.capture_numeric(config, records)
				if plan.error.is_empty():
					var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture(plan.get_numeric_definition(), records)
					error = timeline.get_error()
	if error.is_empty() and plan != null:
		error = plan.error
	target["supported"] = error.is_empty() and plan != null
	target["reason"] = "" if target["supported"] else error
	var diagnostic: Dictionary = {"step_index": -1, "field": &"", "error_kind": &"preview_unavailable" if not error.is_empty() else &"", "message": error}
	if plan != null and not plan.error.is_empty():
		diagnostic = plan.diagnostic.duplicate(true)
	_diagnostics[target["id"]] = diagnostic


# --- 信号处理函数 ---

## 延迟合并注册事件；查询中的失效清理不能重入同一次解析。
## [br]
## @api private
func _on_registry_changed() -> void:
	refresh()
