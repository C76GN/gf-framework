# GFSaveSlotSyncBridge

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/slots/gf_save_slot_sync_bridge.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

槽位文件与通用存储同步的桥接器。 根据 GFSaveSlotStorageAdapter 的文件模板解析槽位数据和元数据文件名， 再交给 GFStorageSyncUtility 同步。该类不定义存档字段、冲突策略或远端协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`slot_sync_completed`](#member-gfsaveslotsyncbridge-signals-slot_sync_completed) | `signal slot_sync_completed(slot_index: int, result: Dictionary)` |
| 信号 | [`slot_sync_failed`](#member-gfsaveslotsyncbridge-signals-slot_sync_failed) | `signal slot_sync_failed(slot_index: int, result: Dictionary)` |
| 属性 | [`sync_utility`](#member-gfsaveslotsyncbridge-properties-sync_utility) | `var sync_utility: GFStorageSyncUtility = null` |
| 方法 | [`setup`](#member-gfsaveslotsyncbridge-methods-setup) | `func setup(utility: GFStorageSyncUtility) -> GFSaveSlotSyncBridge:` |
| 方法 | [`sync_slot`](#member-gfsaveslotsyncbridge-methods-sync_slot) | `func sync_slot( slot_index: int, adapter: GFSaveSlotStorageAdapter, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`sync_slots`](#member-gfsaveslotsyncbridge-methods-sync_slots) | `func sync_slots( slot_indices: PackedInt32Array, adapter: GFSaveSlotStorageAdapter, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:` |

## 信号

<a id="member-gfsaveslotsyncbridge-signals-slot_sync_completed"></a>

### `slot_sync_completed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal slot_sync_completed(slot_index: int, result: Dictionary)
```

单个槽位同步完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `result` | 同步结果。 |

结构：

- `result`: Dictionary，sync_slot() 返回结构。

<a id="member-gfsaveslotsyncbridge-signals-slot_sync_failed"></a>

### `slot_sync_failed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal slot_sync_failed(slot_index: int, result: Dictionary)
```

单个槽位同步失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `result` | 同步结果。 |

结构：

- `result`: Dictionary，sync_slot() 返回结构。

## 属性

<a id="member-gfsaveslotsyncbridge-properties-sync_utility"></a>

### `sync_utility`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var sync_utility: GFStorageSyncUtility = null
```

底层同步工具。为空时 sync_slot() 会按需创建。

## 方法

<a id="member-gfsaveslotsyncbridge-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func setup(utility: GFStorageSyncUtility) -> GFSaveSlotSyncBridge:
```

设置底层同步工具。

参数：

| 名称 | 说明 |
|---|---|
| `utility` | 存储同步工具。 |

返回：当前桥接器。

<a id="member-gfsaveslotsyncbridge-methods-sync_slot"></a>

### `sync_slot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func sync_slot( slot_index: int, adapter: GFSaveSlotStorageAdapter, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:
```

同步一个槽位的数据文件和元数据文件。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引；必须大于等于 0。 |
| `adapter` | 槽位存储适配器。 |
| `local_backend` | 本地或主后端。 |
| `remote_backend` | 远端或副后端。 |
| `options` | 同步选项，除 GFStorageSyncUtility.sync_data() 选项外，还支持 sync_data_file、sync_metadata_file。 |

返回：槽位同步结果。

结构：

- `options`: Dictionary，包含 GFStorageSyncUtility.sync_data() 选项，以及 sync_data_file、sync_metadata_file。
- `return`: Dictionary，包含 ok、slot_index、file_names、sync_result、error。

<a id="member-gfsaveslotsyncbridge-methods-sync_slots"></a>

### `sync_slots`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func sync_slots( slot_indices: PackedInt32Array, adapter: GFSaveSlotStorageAdapter, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:
```

批量同步多个槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot_indices` | 槽位索引列表。 |
| `adapter` | 槽位存储适配器。 |
| `local_backend` | 本地或主后端。 |
| `remote_backend` | 远端或副后端。 |
| `options` | 传给 sync_slot() 的选项。 |

返回：批量同步结果。

结构：

- `options`: Dictionary，包含 sync_slot() 支持的选项。
- `return`: Dictionary，包含 ok、slot_count、results、failed_count。
