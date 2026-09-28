@tool

# 将配置预览接入启用 action_queue 扩展后的原生 Inspector。
extends EditorInspectorPlugin


# --- 常量 ---

## 用于识别动作队列 Tween 配置资源的脚本。
## [br]
## @api private
const _CONFIG_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd")

## 用于检查 action_queue 扩展是否已启用的设置脚本。
## [br]
## @api private
const _EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

## 跟踪创建的预览面板弱引用，以便清理失效项和释放预览。
## [br]
## @api private
var _panels: Array[WeakRef] = []


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	return (
		object is Resource
		and object.get_script() == _CONFIG_SCRIPT
		and _EXTENSION_SETTINGS_SCRIPT.is_extension_enabled("gf.action_queue")
	)


func _parse_begin(object: Object) -> void:
	if not object is Resource or not _can_handle(object):
		return
	for index: int in range(_panels.size() - 1, -1, -1):
		if _panels[index].get_ref() == null:
			_panels.remove_at(index)
	var config: Resource = object
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(config)
	_panels.append(weakref(panel))
	add_custom_control(panel)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for panel_reference: WeakRef in _panels:
		var value: Variant = panel_reference.get_ref()
		if value is GFTweenPreviewPanel:
			var panel: GFTweenPreviewPanel = value
			panel.dispose_preview()
	_panels.clear()
