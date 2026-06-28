@tool

## GFEditorSceneMetadataPatch: 可撤销的场景节点 metadata 修改命令。
##
## 用于把编辑器工具对场景根节点或普通节点 metadata 的读写收敛成 GFEditorCommand。
## 该命令只处理 Object metadata，不规定具体工具面板、场景分组或业务含义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 7.0.0
## [br]
## @layer kernel/editor
class_name GFEditorSceneMetadataPatch
extends GFEditorCommand


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 要修改的节点。
## [br]
## @api public
## [br]
## @since 7.0.0
var target_node: Node = null

## 要修改的 metadata key。
## [br]
## @api public
## [br]
## @since 7.0.0
var metadata_key: StringName = &""

## 执行时写入的新值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema value: Variant copied when configured and written.
var value: Variant = null

## 执行时是否移除 metadata key，而不是写入 value。
## [br]
## @api public
## [br]
## @since 7.0.0
var remove_on_execute: bool = false


# --- 私有变量 ---

var _previous_exists: bool = false
var _previous_value: Variant = null
var _has_previous_snapshot: bool = false


# --- 公共方法 ---

## 配置 metadata 修改命令。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param node: 要修改的节点。
## [br]
## @param key: metadata key。
## [br]
## @param new_value: 写入值。
## [br]
## @param options: 配置选项。
## [br]
## @return 当前命令实例。
## [br]
## @schema new_value: Variant copied into value.
## [br]
## @schema options: Dictionary，支持 command_name、remove_on_execute、metadata 和 duplicate_resources。
func configure(
	node: Node,
	key: StringName,
	new_value: Variant = null,
	options: Dictionary = {}
) -> GFEditorCommand:
	target_node = node
	metadata_key = key
	remove_on_execute = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "remove_on_execute", false)
	value = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(
		new_value,
		true,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "duplicate_resources", false)
	)
	command_name = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "command_name", "Edit Scene Metadata")
	metadata = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
	_clear_previous_snapshot()
	return self


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing command fields and previous metadata snapshot state.
func get_metadata_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = get_debug_snapshot()
	snapshot["target_node"] = target_node
	snapshot["metadata_key"] = metadata_key
	snapshot["remove_on_execute"] = remove_on_execute
	snapshot["has_previous_snapshot"] = _has_previous_snapshot
	snapshot["previous_exists"] = _previous_exists
	return snapshot


# --- 可重写钩子 / 虚方法 ---

## 命令当前是否允许执行。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 允许执行时返回 true。
func can_execute() -> bool:
	return is_instance_valid(target_node) and metadata_key != &""


## 执行 metadata 修改。
## [br]
## @api protected
## [br]
## @since 7.0.0
## [br]
## @return Godot 错误码。
func _do_it() -> Error:
	if not is_instance_valid(target_node) or metadata_key == &"":
		return ERR_INVALID_PARAMETER
	_capture_previous_if_needed()
	if remove_on_execute:
		if target_node.has_meta(metadata_key):
			target_node.remove_meta(metadata_key)
		return OK

	target_node.set_meta(metadata_key, _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(value))
	return OK


## 撤销 metadata 修改。
## [br]
## @api protected
## [br]
## @since 7.0.0
## [br]
## @return Godot 错误码。
func _undo_it() -> Error:
	if not is_instance_valid(target_node) or metadata_key == &"":
		return ERR_INVALID_PARAMETER
	if not _has_previous_snapshot:
		return ERR_UNAVAILABLE
	if _previous_exists:
		target_node.set_meta(metadata_key, _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(_previous_value))
	elif target_node.has_meta(metadata_key):
		target_node.remove_meta(metadata_key)
	return OK


# --- 私有/辅助方法 ---

func _capture_previous_if_needed() -> void:
	if _has_previous_snapshot or not is_instance_valid(target_node):
		return
	_previous_exists = target_node.has_meta(metadata_key)
	_previous_value = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(target_node.get_meta(metadata_key)) if _previous_exists else null
	_has_previous_snapshot = true


func _clear_previous_snapshot() -> void:
	_previous_exists = false
	_previous_value = null
	_has_previous_snapshot = false
