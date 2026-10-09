## GFControlEditSession: 一个控件的运行期输入会话。
##
## 保存编辑开始时的值和文本，保留 SpinBox 尚未提交的数字原文。
## 宿主负责连接焦点/提交事件、业务转换、验证、模型写入和撤销命令。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFControlEditSession
extends RefCounted


# --- 私有变量 ---

## 当前控件的弱引用，不延长节点生命周期。
## [br]
## @api private
var _control_ref: WeakRef

## 本实例递增的会话代数，零不对应有效会话。
## [br]
## @api private
var _generation: int = 0

## 是否持有尚未结束的编辑会话。
## [br]
## @api private
var _active: bool = false

## 取消恢复期间拒绝新会话，防止值变化回调截获部分恢复状态。
## [br]
## @api private
var _restoring: bool = false

## 编辑开始时的独立控件快照。
## [br]
## @api private
var _baseline: Dictionary = {}


# --- 公共方法 ---

## 开始输入并返回本实例的会话令牌；同一活动控件重复开始保留原基线。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param control: 支持 LineEdit、TextEdit、SpinBox、Range、OptionButton、BaseButton、ColorPickerButton 和 ItemList。
## [br]
## @return 正数令牌；无效/不支持的控件、另一活动控件或恢复期间返回零。
func begin_edit(control: Control) -> int:
	if _restoring or not is_instance_valid(control):
		return 0
	var snapshot: Dictionary = _capture(control)
	if snapshot.is_empty():
		return 0
	var current: Control = _get_control()
	if _active and current != null:
		return _generation if current == control else 0
	_generation += 1
	_control_ref = weakref(control)
	_baseline = snapshot
	_active = true
	return _generation


## 检查令牌是否仍属于活动会话；延期回调必须携带开始时的令牌。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param token: begin_edit 返回的令牌，仅在同一个会话实例内有效。
## [br]
## @return 控件仍有效且令牌属于活动会话时返回 true。
func is_current(token: int) -> bool:
	return token > 0 and token == _generation and _active and _get_control() != null


## 返回本次输入最初的快照，不因重复开始或当前输入变化而更新。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param token: 当前会话令牌。
## [br]
## @return 独立快照；过期令牌返回空字典。
## [br]
## @schema return: Dictionary，value 为控件值；文本控件及 SpinBox 另有 raw_text: String。没有控件或业务对象引用。
func get_baseline(token: int) -> Dictionary:
	return _baseline.duplicate(true) if is_current(token) else {}


## 捕获当前草稿；SpinBox 的原文独立于 Range.value，非法中间输入也会保留。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param token: 当前会话令牌。
## [br]
## @return 独立快照；过期令牌返回空字典。
## [br]
## @schema return: Dictionary，value 为控件值；文本控件及 SpinBox 另有 raw_text: String。没有控件或业务对象引用。
func capture_draft(token: int) -> Dictionary:
	return _capture(_get_control()) if is_current(token) else {}


## 检查原生文本控件的输入法组合；组合尚未结束时提交与取消均拒绝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param token: 当前会话令牌。
## [br]
## @return 有未完成组合时返回 true；其他控件或过期令牌返回 false。
func has_ime_composition(token: int) -> bool:
	if not is_current(token):
		return false
	var control: Control = _get_control()
	if control is TextEdit:
		var text_edit: TextEdit = control
		return text_edit.has_ime_text()
	var editor: LineEdit = _get_line_edit(control)
	return editor != null and editor.has_ime_text()


## 结束会话并交付输入边界，不解析数字、不应用模型、不生成历史。
## 宿主应先验证草稿，接受后调用本方法；净零变化由 changed=false 表示。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param token: 当前会话令牌。
## [br]
## @return 独立的提交快照；过期令牌或未完成输入法组合返回空字典且不结束当前会话。
## [br]
## @schema return: Dictionary，成功时含 changed: bool、before: Dictionary、after: Dictionary；before/after 含 value 和可选 raw_text: String。失败为空字典。
func commit_edit(token: int) -> Dictionary:
	if not is_current(token) or has_ime_composition(token):
		return {}
	var draft: Dictionary = _capture(_get_control())
	var result: Dictionary = {
		"changed": draft != _baseline,
		"before": _baseline.duplicate(true),
		"after": draft,
	}
	clear()
	return result


## 恢复本次输入最初的控件值与原文并结束会话；不发起模型写入。
## 原生值变化信号可能发出，宿主需要自己的写入门禁；恢复期间不能开启新会话。
## SpinBox 的原生延期格式化后再校正原文；clear 或新会话会撤销这次延期校正。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param token: 当前会话令牌。
## [br]
## @return 恢复成功时返回 true，包括没有净变化；过期令牌、输入法组合或恢复时被 clear 失效返回 false。
func cancel_edit(token: int) -> bool:
	if not is_current(token) or has_ime_composition(token):
		return false
	var control: Control = _get_control()
	var baseline: Dictionary = _baseline.duplicate(true)
	_active = false
	_restoring = true
	var restored: bool = GFControlValueAdapter.set_value(control, baseline["value"])
	if restored and token == _generation and is_instance_valid(control):
		var editor: LineEdit = _get_line_edit(control)
		if editor != null:
			editor.text = GFVariantData.get_option_string(baseline, "raw_text")
	else:
		restored = false
	_restoring = false
	if token == _generation:
		clear()
		if restored and control is SpinBox:
			_restore_spin_box_text.call_deferred(
				weakref(control), _generation, GFVariantData.get_option_string(baseline, "raw_text")
			)
	return restored


## 放弃会话并失效所有旧令牌，不恢复控件、不写入模型。
## 宿主在字段解绑、文档切换、退树或释放时调用。
## [br]
## @api public
## [br]
## @since unreleased
func clear() -> void:
	_generation += 1
	_active = false
	_control_ref = null
	_baseline = {}


# --- 私有/辅助方法 ---

## 只捕获有已知值类型的原生控件，避免快照携带自定义业务对象。
## [br]
## @api private
func _capture(control: Control) -> Dictionary:
	if not is_instance_valid(control):
		return {}
	if not (
		control is LineEdit or control is TextEdit or control is SpinBox
		or control is Range or control is OptionButton or control is BaseButton
		or control is ColorPickerButton or control is ItemList
	):
		return {}
	var snapshot: Dictionary = {"value": GFControlValueAdapter.get_value(control)}
	var editor: LineEdit = _get_line_edit(control)
	if editor != null:
		snapshot["raw_text"] = editor.text
	elif control is TextEdit:
		var text_edit: TextEdit = control
		snapshot["raw_text"] = text_edit.text
	return snapshot.duplicate(true)


## 解析仍存活的弱引用控件，失效引用返回 null。
## [br]
## @api private
func _get_control() -> Control:
	if _control_ref == null:
		return null
	var candidate: Variant = _control_ref.get_ref()
	if candidate is Control and is_instance_valid(candidate):
		var control: Control = candidate
		return control
	return null


## 取得文本输入控件；SpinBox 使用内置 LineEdit，不把 Range 值当作原文。
## [br]
## @api private
func _get_line_edit(control: Control) -> LineEdit:
	if control is SpinBox:
		var spin_box: SpinBox = control
		return spin_box.get_line_edit()
	if control is LineEdit:
		var line_edit: LineEdit = control
		return line_edit
	return null


## 在原生 SpinBox 格式化之后恢复原文，只允许尚未被宿主清空或新会话接管的取消边界写回。
## [br]
## @api private
func _restore_spin_box_text(control_ref: WeakRef, generation: int, text: String) -> void:
	if generation != _generation or _active:
		return
	var candidate: Variant = control_ref.get_ref()
	if candidate is SpinBox and is_instance_valid(candidate):
		var spin_box: SpinBox = candidate
		var editor: LineEdit = spin_box.get_line_edit()
		if not editor.has_ime_text():
			editor.text = text
