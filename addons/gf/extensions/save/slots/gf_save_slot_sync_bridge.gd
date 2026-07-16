## GFSaveSlotSyncBridge: 槽位文件与通用存储同步的桥接器。
##
## 根据 GFSaveSlotStorageAdapter 的文件模板解析槽位数据和元数据文件名，
## 再交给 GFStorageSyncUtility 同步。该类不定义存档字段、冲突策略或远端协议。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFSaveSlotSyncBridge
extends RefCounted


# --- 信号 ---

## 单个槽位同步完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param result: 同步结果。
## [br]
## @schema result: Dictionary，sync_slot() 返回结构。
signal slot_sync_completed(slot_index: int, result: Dictionary)

## 单个槽位同步失败后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param result: 同步结果。
## [br]
## @schema result: Dictionary，sync_slot() 返回结构。
signal slot_sync_failed(slot_index: int, result: Dictionary)


# --- 公共变量 ---

## 底层同步工具。为空时 sync_slot() 会按需创建。
## [br]
## @api public
## [br]
## @since 8.0.0
var sync_utility: GFStorageSyncUtility = null


# --- Godot 生命周期方法 ---

func _init(p_sync_utility: GFStorageSyncUtility = null) -> void:
	sync_utility = p_sync_utility


# --- 公共方法 ---

## 设置底层同步工具。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param utility: 存储同步工具。
## [br]
## @return 当前桥接器。
func setup(utility: GFStorageSyncUtility) -> GFSaveSlotSyncBridge:
	sync_utility = utility
	return self


## 同步一个槽位的数据文件和元数据文件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引；必须大于等于 0。
## [br]
## @param adapter: 槽位存储适配器。
## [br]
## @param local_backend: 本地或主后端。
## [br]
## @param remote_backend: 远端或副后端。
## [br]
## @param options: 同步选项，除 GFStorageSyncUtility.sync_data() 选项外，还支持 sync_data_file、sync_metadata_file。
## [br]
## @return 槽位同步结果。
## [br]
## @schema options: Dictionary，包含 GFStorageSyncUtility.sync_data() 选项，以及 sync_data_file、sync_metadata_file。
## [br]
## @schema return: Dictionary，包含 ok、slot_index、file_names、sync_result、error。
func sync_slot(
	slot_index: int,
	adapter: GFSaveSlotStorageAdapter,
	local_backend: GFStorageBackend,
	remote_backend: GFStorageBackend,
	options: Dictionary = {}
) -> Dictionary:
	var validation_error: String = _validate_sync_inputs(slot_index, adapter, local_backend, remote_backend)
	if not validation_error.is_empty():
		var failed_result: Dictionary = _make_slot_result(false, slot_index, PackedStringArray(), {}, validation_error)
		slot_sync_failed.emit(slot_index, failed_result)
		return failed_result

	var file_names: PackedStringArray = _get_slot_file_names(slot_index, adapter, options)
	if file_names.is_empty():
		var empty_result: Dictionary = _make_slot_result(false, slot_index, file_names, {}, "no slot files selected")
		slot_sync_failed.emit(slot_index, empty_result)
		return empty_result

	var sync_result: Dictionary = _get_sync_utility().sync_many(file_names, local_backend, remote_backend, options)
	var ok: bool = GFVariantData.get_option_bool(sync_result, "ok")
	var result: Dictionary = _make_slot_result(ok, slot_index, file_names, sync_result, "")
	if ok:
		slot_sync_completed.emit(slot_index, result)
	else:
		slot_sync_failed.emit(slot_index, result)
	return result


## 批量同步多个槽位。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_indices: 槽位索引列表。
## [br]
## @param adapter: 槽位存储适配器。
## [br]
## @param local_backend: 本地或主后端。
## [br]
## @param remote_backend: 远端或副后端。
## [br]
## @param options: 传给 sync_slot() 的选项。
## [br]
## @return 批量同步结果。
## [br]
## @schema options: Dictionary，包含 sync_slot() 支持的选项。
## [br]
## @schema return: Dictionary，包含 ok、slot_count、results、failed_count。
func sync_slots(
	slot_indices: PackedInt32Array,
	adapter: GFSaveSlotStorageAdapter,
	local_backend: GFStorageBackend,
	remote_backend: GFStorageBackend,
	options: Dictionary = {}
) -> Dictionary:
	var results: Array[Dictionary] = []
	var failed_count: int = 0
	for slot_index: int in slot_indices:
		var result: Dictionary = sync_slot(slot_index, adapter, local_backend, remote_backend, options)
		results.append(result)
		if not GFVariantData.get_option_bool(result, "ok"):
			failed_count += 1
	return {
		"ok": failed_count == 0,
		"slot_count": slot_indices.size(),
		"results": results,
		"failed_count": failed_count,
	}


# --- 私有/辅助方法 ---

func _get_sync_utility() -> GFStorageSyncUtility:
	if sync_utility == null:
		sync_utility = GFStorageSyncUtility.new()
	return sync_utility


func _validate_sync_inputs(
	slot_index: int,
	adapter: GFSaveSlotStorageAdapter,
	local_backend: GFStorageBackend,
	remote_backend: GFStorageBackend
) -> String:
	if slot_index < 0:
		return "slot_index must be greater than or equal to 0"
	if adapter == null:
		return "adapter is null"
	if local_backend == null or remote_backend == null:
		return "storage backend is null"
	return ""


func _get_slot_file_names(
	slot_index: int,
	adapter: GFSaveSlotStorageAdapter,
	options: Dictionary
) -> PackedStringArray:
	var file_names: PackedStringArray = PackedStringArray()
	if GFVariantData.get_option_bool(options, "sync_data_file", true):
		var _data_append: bool = file_names.append(adapter.get_data_file_name(slot_index))
	if GFVariantData.get_option_bool(options, "sync_metadata_file", true):
		var _metadata_append: bool = file_names.append(adapter.get_metadata_file_name(slot_index))
	return file_names


func _make_slot_result(
	ok: bool,
	slot_index: int,
	file_names: PackedStringArray,
	sync_result: Dictionary,
	error: String
) -> Dictionary:
	return {
		"ok": ok,
		"slot_index": slot_index,
		"file_names": file_names,
		"sync_result": sync_result.duplicate(true),
		"error": error,
	}
