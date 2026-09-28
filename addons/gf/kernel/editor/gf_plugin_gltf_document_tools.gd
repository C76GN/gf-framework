@tool

# GF 插件 glTF 文档扩展管理辅助。
extends RefCounted


# --- 常量 ---

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

## 保留 setup() 成功注册的扩展实例，供 cleanup() 逐个注销。
## [br]
## @api private
var _document_extensions: Array[GLTFDocumentExtension] = []


# --- 公共方法 ---

## 注册当前启用扩展声明的 GLTFDocumentExtension。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func setup() -> void:
	cleanup()
	for extension_path: String in GFExtensionSettingsBase.get_enabled_gltf_document_extension_paths():
		_register_document_extension(extension_path)


## 注销已注册的 GLTFDocumentExtension。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func cleanup() -> void:
	for document_extension: GLTFDocumentExtension in _document_extensions:
		if document_extension != null:
			GLTFDocument.unregister_gltf_document_extension(document_extension)
	_document_extensions.clear()


# --- 私有/辅助方法 ---

## 加载并实例化指定路径的 GLTFDocumentExtension；失败时记录错误并跳过注册。
## 成功实例会注册到 GLTFDocument，并保存到本工具的实例列表中。
## [br]
## @api private
func _register_document_extension(script_path: String) -> void:
	var extension_script: Script = _load_script(script_path)
	if extension_script == null or not extension_script.can_instantiate():
		push_error("[GFPluginGltfDocumentTools][plugin_gltf_document_tools.extension_load_failed] Could not load the glTF document extension script: %s." % script_path)
		return

	var document_extension: GLTFDocumentExtension = _instantiate_document_extension(extension_script)
	if document_extension == null:
		push_error("[GFPluginGltfDocumentTools][plugin_gltf_document_tools.extension_instantiation_failed] Could not instantiate the glTF document extension: %s." % script_path)
		return

	GLTFDocument.register_gltf_document_extension(document_extension)
	_document_extensions.append(document_extension)


## 加载路径对应的资源，仅在结果是 Script 时返回脚本。
## [br]
## @api private
func _load_script(script_path: String) -> Script:
	var resource: Resource = load(script_path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


## 调用脚本的 new()，并仅返回 GLTFDocumentExtension 类型的实例。
## [br]
## @api private
func _instantiate_document_extension(script: Script) -> GLTFDocumentExtension:
	var instance: Variant = script.call("new")
	if instance is GLTFDocumentExtension:
		var document_extension: GLTFDocumentExtension = instance
		return document_extension
	return null
