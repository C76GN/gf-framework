# GFStorageBackend

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_backend.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存储后端扩展接口。 该类只定义通用后端协议，不绑定本地、云、平台 SDK 或同步策略。 默认实现返回不可用结果；项目可继承它并由自定义 Utility 或派生的 GFStorageUtility 组合使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`initialize`](#member-gfstoragebackend-methods-initialize) | `func initialize(config: Dictionary = {}) -> Error:` |
| 方法 | [`shutdown`](#member-gfstoragebackend-methods-shutdown) | `func shutdown() -> void:` |
| 方法 | [`save_data`](#member-gfstoragebackend-methods-save_data) | `func save_data(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> Error:` |
| 方法 | [`load_data`](#member-gfstoragebackend-methods-load_data) | `func load_data(file_name: String) -> Dictionary:` |
| 方法 | [`delete_data`](#member-gfstoragebackend-methods-delete_data) | `func delete_data(file_name: String) -> Error:` |
| 方法 | [`has_data`](#member-gfstoragebackend-methods-has_data) | `func has_data(file_name: String) -> bool:` |
| 方法 | [`list_data`](#member-gfstoragebackend-methods-list_data) | `func list_data() -> Array[Dictionary]:` |
| 方法 | [`get_capabilities`](#member-gfstoragebackend-methods-get_capabilities) | `func get_capabilities() -> Dictionary:` |
| 方法 | [`get_capability_report`](#member-gfstoragebackend-methods-get_capability_report) | `func get_capability_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`_initialize`](#member-gfstoragebackend-methods-_initialize) | `func _initialize(_config: Dictionary) -> Error:` |
| 方法 | [`_shutdown`](#member-gfstoragebackend-methods-_shutdown) | `func _shutdown() -> void:` |
| 方法 | [`_save_data`](#member-gfstoragebackend-methods-_save_data) | `func _save_data(_file_name: String, _data: Dictionary, _metadata: Dictionary) -> Error:` |
| 方法 | [`_load_data`](#member-gfstoragebackend-methods-_load_data) | `func _load_data(_file_name: String) -> Dictionary:` |
| 方法 | [`_delete_data`](#member-gfstoragebackend-methods-_delete_data) | `func _delete_data(_file_name: String) -> Error:` |
| 方法 | [`_has_data`](#member-gfstoragebackend-methods-_has_data) | `func _has_data(_file_name: String) -> bool:` |
| 方法 | [`_list_data`](#member-gfstoragebackend-methods-_list_data) | `func _list_data() -> Array[Dictionary]:` |
| 方法 | [`_get_capabilities`](#member-gfstoragebackend-methods-_get_capabilities) | `func _get_capabilities() -> Dictionary:` |

## 方法

<a id="member-gfstoragebackend-methods-initialize"></a>

### `initialize`

- API：`public`

```gdscript
func initialize(config: Dictionary = {}) -> Error:
```

初始化后端。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 后端配置字典。 |

返回：Godot Error 结果码。

结构：

- `config`: Dictionary，包含后端特定的初始化选项。

<a id="member-gfstoragebackend-methods-shutdown"></a>

### `shutdown`

- API：`public`

```gdscript
func shutdown() -> void:
```

关闭后端并释放资源。

<a id="member-gfstoragebackend-methods-save_data"></a>

### `save_data`

- API：`public`

```gdscript
func save_data(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> Error:
```

保存纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `data` | 要保存的数据。 |
| `metadata` | 可选元数据。 |

返回：Godot Error 结果码。

结构：

- `data`: Dictionary，存储后端持有的数据载荷。
- `metadata`: Dictionary，包含时间戳或修订号等后端特定元数据。

<a id="member-gfstoragebackend-methods-load_data"></a>

### `load_data`

- API：`public`

```gdscript
func load_data(file_name: String) -> Dictionary:
```

读取纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：结果字典，包含 ok、data、metadata、error。

结构：

- `return`: Dictionary，包含 ok: bool、data: Dictionary、metadata: Dictionary 和 error: String。

<a id="member-gfstoragebackend-methods-delete_data"></a>

### `delete_data`

- API：`public`

```gdscript
func delete_data(file_name: String) -> Error:
```

删除纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：Godot Error 结果码。

<a id="member-gfstoragebackend-methods-has_data"></a>

### `has_data`

- API：`public`

```gdscript
func has_data(file_name: String) -> bool:
```

判断逻辑文件是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：存在时返回 true。

<a id="member-gfstoragebackend-methods-list_data"></a>

### `list_data`

- API：`public`

```gdscript
func list_data() -> Array[Dictionary]:
```

枚举后端中的逻辑文件。

返回：文件摘要数组。

结构：

- `return`: Array，包含 file_name: String 和可选 metadata: Dictionary 的 Dictionary 条目。

<a id="member-gfstoragebackend-methods-get_capabilities"></a>

### `get_capabilities`

- API：`public`

```gdscript
func get_capabilities() -> Dictionary:
```

获取后端能力描述。

返回：能力字典副本。

结构：

- `return`: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。

<a id="member-gfstoragebackend-methods-get_capability_report"></a>

### `get_capability_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_capability_report(options: Dictionary = {}) -> Dictionary:
```

获取后端能力报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 报告选项，支持 label、metadata、include_data_count、include_data_names。 |

返回：能力报告字典。

结构：

- `options`: Dictionary，包含 label、metadata、include_data_count 和 include_data_names。
- `return`: Dictionary，包含 ok、backend_class、label、capabilities、data_count、data_names 和 metadata。

<a id="member-gfstoragebackend-methods-_initialize"></a>

### `_initialize`

- API：`protected`

```gdscript
func _initialize(_config: Dictionary) -> Error:
```

初始化具体后端。

参数：

| 名称 | 说明 |
|---|---|
| `_config` | 后端配置字典。 |

返回：Godot Error 结果码。

结构：

- `_config`: Dictionary，包含后端特定的初始化选项。

<a id="member-gfstoragebackend-methods-_shutdown"></a>

### `_shutdown`

- API：`protected`

```gdscript
func _shutdown() -> void:
```

释放具体后端持有的资源。

<a id="member-gfstoragebackend-methods-_save_data"></a>

### `_save_data`

- API：`protected`

```gdscript
func _save_data(_file_name: String, _data: Dictionary, _metadata: Dictionary) -> Error:
```

保存纯字典数据到具体后端。

参数：

| 名称 | 说明 |
|---|---|
| `_file_name` | 逻辑文件名。 |
| `_data` | 要保存的数据副本。 |
| `_metadata` | 可选元数据副本。 |

返回：Godot Error 结果码。

结构：

- `_data`: Dictionary，存储后端持有的数据载荷。
- `_metadata`: Dictionary，包含时间戳或修订号等后端特定元数据。

<a id="member-gfstoragebackend-methods-_load_data"></a>

### `_load_data`

- API：`protected`

```gdscript
func _load_data(_file_name: String) -> Dictionary:
```

从具体后端读取纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `_file_name` | 逻辑文件名。 |

返回：结果字典，包含 ok、data、metadata、error。

结构：

- `return`: Dictionary，包含 ok: bool、data: Dictionary、metadata: Dictionary 和 error: String。

<a id="member-gfstoragebackend-methods-_delete_data"></a>

### `_delete_data`

- API：`protected`

```gdscript
func _delete_data(_file_name: String) -> Error:
```

从具体后端删除纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `_file_name` | 逻辑文件名。 |

返回：Godot Error 结果码。

<a id="member-gfstoragebackend-methods-_has_data"></a>

### `_has_data`

- API：`protected`

```gdscript
func _has_data(_file_name: String) -> bool:
```

判断具体后端是否存在逻辑文件。

参数：

| 名称 | 说明 |
|---|---|
| `_file_name` | 逻辑文件名。 |

返回：存在时返回 true。

<a id="member-gfstoragebackend-methods-_list_data"></a>

### `_list_data`

- API：`protected`

```gdscript
func _list_data() -> Array[Dictionary]:
```

枚举具体后端中的逻辑文件。

返回：文件摘要数组。

结构：

- `return`: Array，包含 file_name: String 和可选 metadata: Dictionary 的 Dictionary 条目。

<a id="member-gfstoragebackend-methods-_get_capabilities"></a>

### `_get_capabilities`

- API：`protected`

```gdscript
func _get_capabilities() -> Dictionary:
```

获取具体后端能力描述。

返回：能力字典。

结构：

- `return`: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。
