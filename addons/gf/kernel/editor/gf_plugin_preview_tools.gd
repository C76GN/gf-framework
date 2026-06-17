@tool

# GF 插件 Resource 预览生成器管理辅助。
extends RefCounted


# --- 常量 ---

## GF 通用 Resource 预览生成器脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const RESOURCE_PREVIEW_GENERATOR_PATH: String = "res://addons/gf/kernel/editor/gf_resource_preview_generator.gd"


# --- 私有变量 ---

var _preview_generators: Array[EditorResourcePreviewGenerator] = []


# --- 公共方法 ---

## 注册 GF 通用 Resource 预览生成器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func setup(plugin: EditorPlugin) -> void:
	if plugin == null:
		return

	_add_preview_generator(RESOURCE_PREVIEW_GENERATOR_PATH, "Resource 预览生成器")


## 注销已注册的 Resource 预览生成器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func cleanup(plugin: EditorPlugin) -> void:
	if plugin == null:
		return

	var previewer: EditorResourcePreview = EditorInterface.get_resource_previewer()
	for preview_generator: EditorResourcePreviewGenerator in _preview_generators:
		if preview_generator != null:
			previewer.remove_preview_generator(preview_generator)
	_preview_generators.clear()


# --- 私有/辅助方法 ---

func _add_preview_generator(script_path: String, label: String) -> void:
	var preview_generator: EditorResourcePreviewGenerator = _load_preview_generator(script_path, label)
	if preview_generator == null:
		return

	var previewer: EditorResourcePreview = EditorInterface.get_resource_previewer()
	previewer.add_preview_generator(preview_generator)
	_preview_generators.append(preview_generator)


func _load_preview_generator(script_path: String, label: String) -> EditorResourcePreviewGenerator:
	var preview_script: Script = _load_script(script_path)
	if preview_script == null or not preview_script.can_instantiate():
		push_error("[GF Framework] %s 脚本加载失败。" % label)
		return null

	var preview_generator: EditorResourcePreviewGenerator = _instantiate_preview_generator(preview_script)
	if preview_generator == null:
		push_error("[GF Framework] %s 实例化失败。" % label)
		return null

	return preview_generator


func _load_script(script_path: String) -> Script:
	var resource: Resource = load(script_path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _instantiate_preview_generator(script: Script) -> EditorResourcePreviewGenerator:
	var instance: Variant = script.call("new")
	if instance is EditorResourcePreviewGenerator:
		var preview_generator: EditorResourcePreviewGenerator = instance
		return preview_generator
	return null
