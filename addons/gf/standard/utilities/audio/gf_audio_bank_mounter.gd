## GFAudioBankMounter: 场景生命周期驱动的音频集合挂载节点。
##
## 进入树时把 `GFAudioBank` 注册到 `GFAudioUtility`，退出树时按需恢复或卸载，
## 让场景、UI 或模块可以拥有自己的音频事件集合而不写全局业务逻辑。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFAudioBankMounter
extends Node


# --- 信号 ---

## 音频集合挂载完成时发出。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
signal bank_mounted(bank_id: StringName)

## 音频集合卸载完成时发出。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
signal bank_unmounted(bank_id: StringName)


# --- 导出变量 ---

## 音频集合标识。
## [br]
## @api public
@export var bank_id: StringName = &""

## 音频集合资源。
## [br]
## @api public
@export var bank: GFAudioBank = null

## ready 后是否自动挂载。
## [br]
## @api public
@export var mount_on_ready: bool = true

## 退出树时是否自动卸载。
## [br]
## @api public
@export var unmount_on_exit: bool = true

## 卸载时是否恢复同 ID 的旧音频集合。
## [br]
## @api public
@export var restore_previous_bank: bool = true


# --- 公共变量 ---

## 可选音频工具实例；为空时从全局架构查询。
## [br]
## @api public
var audio_utility: GFAudioUtility = null


# --- 私有变量 ---

var _mounted: bool = false
var _mount_token: int = 0
var _mounted_bank_id: StringName = &""


# --- Godot 生命周期方法 ---

func _ready() -> void:
	if mount_on_ready:
		var _mount_result_78: Variant = mount()


func _exit_tree() -> void:
	if unmount_on_exit:
		var _unmount_result_83: Variant = unmount()


# --- 公共方法 ---

## 设置音频工具实例。
## [br]
## @api public
## [br]
## @param utility: 音频工具实例。
func set_audio_utility(utility: GFAudioUtility) -> void:
	audio_utility = utility


## 挂载音频集合。
## [br]
## @api public
## [br]
## @return: 挂载成功返回 true。
func mount() -> bool:
	if bank_id == &"" or bank == null:
		return false
	var utility: GFAudioUtility = _get_audio_utility()
	if utility == null:
		return false

	if not _mounted:
		_mount_token = utility.mount_audio_bank(bank_id, bank, restore_previous_bank)
		if _mount_token <= 0:
			return false
	else:
		var _unmount_audio_bank_result_115: Variant = utility.unmount_audio_bank(_mounted_bank_id, _mount_token)
		_mount_token = utility.mount_audio_bank(bank_id, bank, restore_previous_bank)
		if _mount_token <= 0:
			_mounted = false
			_mounted_bank_id = &""
			return false
	_mounted = true
	_mounted_bank_id = bank_id
	bank_mounted.emit(bank_id)
	return true


## 卸载音频集合。
## [br]
## @api public
## [br]
## @return: 卸载成功返回 true。
func unmount() -> bool:
	if not _mounted or _mounted_bank_id == &"":
		return false
	var utility: GFAudioUtility = _get_audio_utility()
	if utility == null:
		return false

	var mounted_bank_id: StringName = _mounted_bank_id
	if not utility.unmount_audio_bank(mounted_bank_id, _mount_token):
		return false
	_mounted = false
	_mount_token = 0
	_mounted_bank_id = &""
	bank_unmounted.emit(mounted_bank_id)
	return true


## 检查音频集合是否已挂载。
## [br]
## @api public
## [br]
## @return: 已挂载返回 true。
func is_mounted() -> bool:
	return _mounted


# --- 私有/辅助方法 ---

func _get_audio_utility() -> GFAudioUtility:
	if audio_utility != null:
		return audio_utility
	var architecture: GFArchitecture = GFAutoload.get_architecture_or_null()
	if architecture == null:
		return null
	return _variant_to_audio_utility(architecture.get_utility(GFAudioUtility))


func _variant_to_audio_utility(value: Variant) -> GFAudioUtility:
	if value is GFAudioUtility:
		var utility: GFAudioUtility = value
		return utility
	return null
