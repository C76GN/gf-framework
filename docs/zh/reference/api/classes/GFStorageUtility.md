# GFStorageUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

基于 `user://` 的轻量存档系统。 支持槽位存档、元数据分离读取、`Resource` 存取， 以及可配置 codec、完整性校验、版本迁移和简单混淆，适合通用本地持久化场景。 该混淆不提供安全加密能力，请勿用于保护敏感数据。 `Resource` 存取只面向项目生成或项目已确认来源与格式的本地文件；它不是未确认来源资源的沙盒化导入器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`data_integrity_failed`](#member-gfstorageutility-signals-data_integrity_failed) | `signal data_integrity_failed(file_name: String, error: String)` |
| 信号 | [`data_migrated`](#member-gfstorageutility-signals-data_migrated) | `signal data_migrated(file_name: String, from_version: int, to_version: int)` |
| 信号 | [`save_completed`](#member-gfstorageutility-signals-save_completed) | `signal save_completed(file_name: String, error: Error)` |
| 信号 | [`load_completed`](#member-gfstorageutility-signals-load_completed) | `signal load_completed(file_name: String, result: GFStorageReadResult)` |
| 常量 | [`DEFAULT_MAX_LIST_DEPTH`](#member-gfstorageutility-constants-default_max_list_depth) | `const DEFAULT_MAX_LIST_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_LISTED_FILES`](#member-gfstorageutility-constants-default_max_listed_files) | `const DEFAULT_MAX_LISTED_FILES: int = 10000` |
| 属性 | [`encrypt_key`](#member-gfstorageutility-properties-encrypt_key) | `var encrypt_key: int = 42` |
| 属性 | [`save_dir_name`](#member-gfstorageutility-properties-save_dir_name) | `var save_dir_name: String = "saves"` |
| 属性 | [`codec`](#member-gfstorageutility-properties-codec) | `var codec: GFStorageCodec = GFStorageCodec.new()` |
| 属性 | [`file_format`](#member-gfstorageutility-properties-file_format) | `var file_format: GFStorageCodec.Format = GFStorageCodec.Format.JSON` |
| 属性 | [`use_compression`](#member-gfstorageutility-properties-use_compression) | `var use_compression: bool = false` |
| 属性 | [`normalize_json_numbers`](#member-gfstorageutility-properties-normalize_json_numbers) | `var normalize_json_numbers: bool = false` |
| 属性 | [`use_integrity_checksum`](#member-gfstorageutility-properties-use_integrity_checksum) | `var use_integrity_checksum: bool = false` |
| 属性 | [`strict_integrity`](#member-gfstorageutility-properties-strict_integrity) | `var strict_integrity: bool = true` |
| 属性 | [`require_integrity_checksum`](#member-gfstorageutility-properties-require_integrity_checksum) | `var require_integrity_checksum: bool = true` |
| 属性 | [`include_storage_metadata`](#member-gfstorageutility-properties-include_storage_metadata) | `var include_storage_metadata: bool = false` |
| 属性 | [`allow_absolute_paths`](#member-gfstorageutility-properties-allow_absolute_paths) | `var allow_absolute_paths: bool = false` |
| 属性 | [`allow_resource_loads`](#member-gfstorageutility-properties-allow_resource_loads) | `var allow_resource_loads: bool = false` |
| 属性 | [`allowed_resource_load_extensions`](#member-gfstorageutility-properties-allowed_resource_load_extensions) | `var allowed_resource_load_extensions: PackedStringArray = PackedStringArray(["tres", "res"])` |
| 属性 | [`allowed_resource_load_type_hints`](#member-gfstorageutility-properties-allowed_resource_load_type_hints) | `var allowed_resource_load_type_hints: PackedStringArray = PackedStringArray()` |
| 属性 | [`require_resource_load_type_hint`](#member-gfstorageutility-properties-require_resource_load_type_hint) | `var require_resource_load_type_hint: bool = true` |
| 属性 | [`create_directories_for_nested_paths`](#member-gfstorageutility-properties-create_directories_for_nested_paths) | `var create_directories_for_nested_paths: bool = true` |
| 属性 | [`max_async_thread_count`](#member-gfstorageutility-properties-max_async_thread_count) | `var max_async_thread_count: int = 4:` |
| 属性 | [`save_version`](#member-gfstorageutility-properties-save_version) | `var save_version: int = 1:` |
| 属性 | [`strict_schema_migrations`](#member-gfstorageutility-properties-strict_schema_migrations) | `var strict_schema_migrations: bool = false` |
| 属性 | [`default_values_for_new_keys`](#member-gfstorageutility-properties-default_values_for_new_keys) | `var default_values_for_new_keys: Dictionary = {}` |
| 属性 | [`last_load_result`](#member-gfstorageutility-properties-last_load_result) | `var last_load_result: GFStorageReadResult` |
| 方法 | [`init`](#member-gfstorageutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfstorageutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfstorageutility-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`begin_activation`](#member-gfstorageutility-methods-begin_activation) | `func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`begin_quiesce`](#member-gfstorageutility-methods-begin_quiesce) | `func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`save_resource`](#member-gfstorageutility-methods-save_resource) | `func save_resource(file_name: String, resource: Resource) -> Error:` |
| 方法 | [`load_resource`](#member-gfstorageutility-methods-load_resource) | `func load_resource(file_name: String, type_hint: String = "") -> Resource:` |
| 方法 | [`ensure_directory`](#member-gfstorageutility-methods-ensure_directory) | `func ensure_directory(directory_name: String = "") -> Error:` |
| 方法 | [`get_storage_directory_path`](#member-gfstorageutility-methods-get_storage_directory_path) | `func get_storage_directory_path(directory_name: String = "") -> String:` |
| 方法 | [`list_files`](#member-gfstorageutility-methods-list_files) | `func list_files( directory_name: String = "", extension_filter: String = "", recursive: bool = false, options: Dictionary = {} ) -> PackedStringArray:` |
| 方法 | [`delete_file`](#member-gfstorageutility-methods-delete_file) | `func delete_file(file_name: String) -> Error:` |
| 方法 | [`save_data`](#member-gfstorageutility-methods-save_data) | `func save_data(file_name: String, data: Dictionary) -> Error:` |
| 方法 | [`save_data_group`](#member-gfstorageutility-methods-save_data_group) | `func save_data_group(files: Dictionary) -> Error:` |
| 方法 | [`load_data`](#member-gfstorageutility-methods-load_data) | `func load_data(file_name: String) -> GFStorageReadResult:` |
| 方法 | [`canonicalize_data_file_name`](#member-gfstorageutility-methods-canonicalize_data_file_name) | `func canonicalize_data_file_name(file_name: String) -> String:` |
| 方法 | [`save_data_async`](#member-gfstorageutility-methods-save_data_async) | `func save_data_async(file_name: String, data: Dictionary) -> Error:` |
| 方法 | [`save_data_request_async`](#member-gfstorageutility-methods-save_data_request_async) | `func save_data_request_async(file_name: String, data: Dictionary) -> GFStorageAsyncOperation:` |
| 方法 | [`save_payload_request_async`](#member-gfstorageutility-methods-save_payload_request_async) | `func save_payload_request_async( file_name: String, transfer: GFStoragePayloadTransfer ) -> GFStorageAsyncOperation:` |
| 方法 | [`load_data_async`](#member-gfstorageutility-methods-load_data_async) | `func load_data_async(file_name: String) -> Error:` |
| 方法 | [`load_data_request_async`](#member-gfstorageutility-methods-load_data_request_async) | `func load_data_request_async(file_name: String) -> GFStorageAsyncOperation:` |
| 方法 | [`wait_for_async_tasks`](#member-gfstorageutility-methods-wait_for_async_tasks) | `func wait_for_async_tasks() -> void:` |
| 方法 | [`migrate_data`](#member-gfstorageutility-methods-migrate_data) | `func migrate_data(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:` |
| 方法 | [`register_migration`](#member-gfstorageutility-methods-register_migration) | `func register_migration(from_version: int, to_version: int, callback: Callable) -> bool:` |
| 方法 | [`unregister_migration`](#member-gfstorageutility-methods-unregister_migration) | `func unregister_migration(from_version: int, to_version: int) -> void:` |
| 方法 | [`clear_migrations`](#member-gfstorageutility-methods-clear_migrations) | `func clear_migrations() -> void:` |
| 方法 | [`get_registered_migrations`](#member-gfstorageutility-methods-get_registered_migrations) | `func get_registered_migrations() -> Array[Dictionary]:` |

## 信号

<a id="member-gfstorageutility-signals-data_integrity_failed"></a>

### `data_integrity_failed`

- API：`public`

```gdscript
signal data_integrity_failed(file_name: String, error: String)
```

解码数据失败或发现完整性校验失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 文件名。 |
| `error` | 错误描述。 |

<a id="member-gfstorageutility-signals-data_migrated"></a>

### `data_migrated`

- API：`public`

```gdscript
signal data_migrated(file_name: String, from_version: int, to_version: int)
```

数据版本迁移后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 文件名。 |
| `from_version` | 原版本。 |
| `to_version` | 目标版本。 |

<a id="member-gfstorageutility-signals-save_completed"></a>

### `save_completed`

- API：`public`

```gdscript
signal save_completed(file_name: String, error: Error)
```

异步保存完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 文件名。 |
| `error` | Godot 的 Error 结果码。 |

<a id="member-gfstorageutility-signals-load_completed"></a>

### `load_completed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal load_completed(file_name: String, result: GFStorageReadResult)
```

异步读取完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 文件名。 |
| `result` | 强类型读取结果。 |

## 常量

<a id="member-gfstorageutility-constants-default_max_list_depth"></a>

### `DEFAULT_MAX_LIST_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_LIST_DEPTH: int = 32
```

递归枚举文件时默认允许进入的最大目录深度。

<a id="member-gfstorageutility-constants-default_max_listed_files"></a>

### `DEFAULT_MAX_LISTED_FILES`

- API：`public`

```gdscript
const DEFAULT_MAX_LISTED_FILES: int = 10000
```

单次文件枚举默认最多返回的文件数量。

## 属性

<a id="member-gfstorageutility-properties-encrypt_key"></a>

### `encrypt_key`

- API：`public`

```gdscript
var encrypt_key: int = 42
```

用于简单 XOR + Base64 混淆的密钥；为 `0` 时直接保存明文 JSON。该字段不是安全加密密钥。

<a id="member-gfstorageutility-properties-save_dir_name"></a>

### `save_dir_name`

- API：`public`

```gdscript
var save_dir_name: String = "saves"
```

保存子目录名；为空时直接写入 `user://`。

<a id="member-gfstorageutility-properties-codec"></a>

### `codec`

- API：`public`

```gdscript
var codec: GFStorageCodec = GFStorageCodec.new()
```

存档 codec。为 null 时会自动创建默认 GFStorageCodec。

<a id="member-gfstorageutility-properties-file_format"></a>

### `file_format`

- API：`public`

```gdscript
var file_format: GFStorageCodec.Format = GFStorageCodec.Format.JSON
```

数据序列化格式。

<a id="member-gfstorageutility-properties-use_compression"></a>

### `use_compression`

- API：`public`

```gdscript
var use_compression: bool = false
```

是否压缩存档载荷。

<a id="member-gfstorageutility-properties-normalize_json_numbers"></a>

### `normalize_json_numbers`

- API：`public`

```gdscript
var normalize_json_numbers: bool = false
```

JSON 读取时是否把接近整数的 float 归一为 int。Binary 格式不受影响。

<a id="member-gfstorageutility-properties-use_integrity_checksum"></a>

### `use_integrity_checksum`

- API：`public`

```gdscript
var use_integrity_checksum: bool = false
```

是否写入并校验 SHA-256 完整性校验。

<a id="member-gfstorageutility-properties-strict_integrity"></a>

### `strict_integrity`

- API：`public`

```gdscript
var strict_integrity: bool = true
```

完整性校验失败时是否拒绝读取。

<a id="member-gfstorageutility-properties-require_integrity_checksum"></a>

### `require_integrity_checksum`

- API：`public`

```gdscript
var require_integrity_checksum: bool = true
```

启用完整性校验时，是否要求载荷必须包含 `_meta.checksum`。

<a id="member-gfstorageutility-properties-include_storage_metadata"></a>

### `include_storage_metadata`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var include_storage_metadata: bool = false
```

是否写入时间戳、编码格式和压缩方式等诊断元数据。 数据版本始终写入独立文档 metadata，不受该选项影响。

<a id="member-gfstorageutility-properties-allow_absolute_paths"></a>

### `allow_absolute_paths`

- API：`public`
- 首次版本：`2.0.0`

```gdscript
var allow_absolute_paths: bool = false
```

是否允许传入绝对路径。关闭后绝对路径会被拒绝。

<a id="member-gfstorageutility-properties-allow_resource_loads"></a>

### `allow_resource_loads`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allow_resource_loads: bool = false
```

是否允许通过 `load_resource()` 调用 Godot `ResourceLoader`。默认关闭，避免未确认来源文件进入资源加载链路。

<a id="member-gfstorageutility-properties-allowed_resource_load_extensions"></a>

### `allowed_resource_load_extensions`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allowed_resource_load_extensions: PackedStringArray = PackedStringArray(["tres", "res"])
```

`load_resource()` 允许读取的文件扩展名。不包含点号；空列表表示不允许任何 Resource 读取。

<a id="member-gfstorageutility-properties-allowed_resource_load_type_hints"></a>

### `allowed_resource_load_type_hints`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allowed_resource_load_type_hints: PackedStringArray = PackedStringArray()
```

`load_resource()` 允许的类型提示。空列表表示不允许任何 Resource 读取；启用时 `type_hint` 必须精确匹配其中之一。

<a id="member-gfstorageutility-properties-require_resource_load_type_hint"></a>

### `require_resource_load_type_hint`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var require_resource_load_type_hint: bool = true
```

`load_resource()` 是否要求调用方传入非空 `type_hint`。

<a id="member-gfstorageutility-properties-create_directories_for_nested_paths"></a>

### `create_directories_for_nested_paths`

- API：`public`

```gdscript
var create_directories_for_nested_paths: bool = true
```

写入嵌套相对路径时是否自动创建目录。

<a id="member-gfstorageutility-properties-max_async_thread_count"></a>

### `max_async_thread_count`

- API：`public`

```gdscript
var max_async_thread_count: int = 4:
```

同时运行的异步存取线程数量。小于 1 时会被钳制为 1。

<a id="member-gfstorageutility-properties-save_version"></a>

### `save_version`

- API：`public`

```gdscript
var save_version: int = 1:
```

当前存档数据版本。小于 1 会被钳制为 1。

<a id="member-gfstorageutility-properties-strict_schema_migrations"></a>

### `strict_schema_migrations`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var strict_schema_migrations: bool = false
```

为 true 时，读取旧版本存档必须存在完整迁移链，不能仅更新数据版本。

<a id="member-gfstorageutility-properties-default_values_for_new_keys"></a>

### `default_values_for_new_keys`

- API：`public`

```gdscript
var default_values_for_new_keys: Dictionary = {}
```

读取旧版本数据时需要补齐的新字段默认值。

结构：

- `default_values_for_new_keys`: Dictionary，包含迁移旧存档时合并进去的新字段默认值。

<a id="member-gfstorageutility-properties-last_load_result"></a>

### `last_load_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var last_load_result: GFStorageReadResult
```

最近一次同步或异步读取结果；尚未读取或 dispose 后为 null。

## 方法

<a id="member-gfstorageutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化存储目录和内部帮助器。

<a id="member-gfstorageutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

等待并清理异步存取任务。

<a id="member-gfstorageutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

驱动异步存档任务完成检查。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |

<a id="member-gfstorageutility-methods-begin_activation"></a>

### `begin_activation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
```

激活 Storage 的同步与异步 I/O 准入。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Storage 激活阶段的取消作用域。 |

返回：已成功完成；正在 dispose 时返回失败终态。

<a id="member-gfstorageutility-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
```

关闭新 I/O 准入，并等待此前接纳的队列、线程和文件锁全部收敛。 已接纳任务继续由 lifecycle tick 推进；强制 dispose 仍会使用同步 join fallback。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 当前 Storage 静默阶段的取消作用域。 |

返回：队列、任务和锁全部终态后成功的一次性完成源。

<a id="member-gfstorageutility-methods-save_resource"></a>

### `save_resource`

- API：`public`

```gdscript
func save_resource(file_name: String, resource: Resource) -> Error:
```

保存一个 `Resource` 文件。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `resource` | 要保存的资源实例。 |

返回：Godot 的 `Error` 结果码。

<a id="member-gfstorageutility-methods-load_resource"></a>

### `load_resource`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func load_resource(file_name: String, type_hint: String = "") -> Resource:
```

读取一个 `Resource` 文件。 该方法会调用 Godot `ResourceLoader`，默认关闭。调用方必须先启用 `allow_resource_loads`，并通过类型提示 allowlist、扩展名 allowlist 与存储路径策略收窄加载边界。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `type_hint` | 可选类型提示。 |

返回：读取到的资源实例；不存在时返回 `null`。

<a id="member-gfstorageutility-methods-ensure_directory"></a>

### `ensure_directory`

- API：`public`

```gdscript
func ensure_directory(directory_name: String = "") -> Error:
```

确保存储相对目录存在。

参数：

| 名称 | 说明 |
|---|---|
| `directory_name` | 相对存储目录；为空时只确保根存储目录存在。 |

返回：Godot 的 `Error` 结果码。

<a id="member-gfstorageutility-methods-get_storage_directory_path"></a>

### `get_storage_directory_path`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_storage_directory_path(directory_name: String = "") -> String:
```

获取存储目录路径，不创建目录。

参数：

| 名称 | 说明 |
|---|---|
| `directory_name` | 相对存储目录；为空时返回根存储目录。 |

返回：按当前路径策略解析后的目录路径。

<a id="member-gfstorageutility-methods-list_files"></a>

### `list_files`

- API：`public`

```gdscript
func list_files( directory_name: String = "", extension_filter: String = "", recursive: bool = false, options: Dictionary = {} ) -> PackedStringArray:
```

枚举指定存储目录下的文件。

参数：

| 名称 | 说明 |
|---|---|
| `directory_name` | 相对存储目录；为空时枚举根存储目录。 |
| `extension_filter` | 可选扩展名过滤，允许传入 `"json"` 或 `".json"`。 |
| `recursive` | 是否递归枚举子目录。 |
| `options` | 可选参数，支持 `max_scan_depth` 与 `max_file_count`。 |

返回：存储相对文件路径数组；若传入允许的绝对目录，则返回绝对文件路径。

结构：

- `options`: Dictionary，包含 max_scan_depth: int 和 max_file_count: int。

<a id="member-gfstorageutility-methods-delete_file"></a>

### `delete_file`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func delete_file(file_name: String) -> Error:
```

删除一个存储文件。 同时清理同名事务临时文件、备份文件和事务标记，避免删除后被遗留事务恢复。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 存储相对文件路径。 |

返回：Godot 的 `Error` 结果码；文件不存在时返回 `ERR_FILE_NOT_FOUND`。

<a id="member-gfstorageutility-methods-save_data"></a>

### `save_data`

- API：`public`

```gdscript
func save_data(file_name: String, data: Dictionary) -> Error:
```

保存纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `data` | 要保存的字典。 |

返回：Godot 的 `Error` 结果码。

结构：

- `data`: Dictionary，要序列化并保存的数据载荷。

<a id="member-gfstorageutility-methods-save_data_group"></a>

### `save_data_group`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func save_data_group(files: Dictionary) -> Error:
```

以同一个事务保存多个纯字典文件。

参数：

| 名称 | 说明 |
|---|---|
| `files` | 文件名到字典载荷的映射。 |

返回：Godot 的 `Error` 结果码。

结构：

- `files`: Dictionary，键为存储相对文件名，值为要序列化并保存的 Dictionary 载荷。

<a id="member-gfstorageutility-methods-load_data"></a>

### `load_data`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func load_data(file_name: String) -> GFStorageReadResult:
```

严格读取纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |

返回：强类型读取结果；调用方必须先检查 ok，再读取 payload。

<a id="member-gfstorageutility-methods-canonicalize_data_file_name"></a>

### `canonicalize_data_file_name`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func canonicalize_data_file_name(file_name: String) -> String:
```

规范化并校验一个数据文件名。 返回值与异步队列的同文件锁使用相同路径规则，可用于建立稳定所有权键。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 待校验文件名。 |

返回：合法时返回规范化文件名；非法时返回空字符串。

<a id="member-gfstorageutility-methods-save_data_async"></a>

### `save_data_async`

- API：`public`

```gdscript
func save_data_async(file_name: String, data: Dictionary) -> Error:
```

在线程中异步保存纯字典数据。完成后从主线程发出 save_completed。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `data` | 要保存的字典。 |

返回：启动线程的 Error 结果码。

结构：

- `data`: Dictionary，要序列化并保存的数据载荷。

<a id="member-gfstorageutility-methods-save_data_request_async"></a>

### `save_data_request_async`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func save_data_request_async(file_name: String, data: Dictionary) -> GFStorageAsyncOperation:
```

在线程中异步保存纯字典数据，并返回请求专属句柄。 句柄终态不会与共享 Storage 上同文件的其他请求混淆。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `data` | 要保存的字典。 |

返回：已配置的请求句柄；输入无效或启动失败时句柄立即进入失败终态。

结构：

- `data`: Dictionary，要序列化并保存的数据载荷。

<a id="member-gfstorageutility-methods-save_payload_request_async"></a>

### `save_payload_request_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func save_payload_request_async( file_name: String, transfer: GFStoragePayloadTransfer ) -> GFStorageAsyncOperation:
```

在线程中保存由单所有者 transfer 移交的纯 Variant payload。 路径校验在 claim 前完成；非法路径不会消费 transfer。首次合法请求会冻结当前 Storage 实例、规范文件名与 codec options。同一 transfer 可在旧 attempt 尚未 完成时提交给相同绑定，用于 timeout retry；所有 attempt 只读同一逻辑快照。 调用方完成整个重试 generation 后必须显式调用 transfer.release()。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `transfer` | 已通过 take_ownership() 接收 payload 的 opaque transfer。 |

返回：已配置请求句柄；输入无效或启动失败时句柄立即进入失败终态。

<a id="member-gfstorageutility-methods-load_data_async"></a>

### `load_data_async`

- API：`public`

```gdscript
func load_data_async(file_name: String) -> Error:
```

在线程中异步读取纯字典数据。完成后从主线程发出 load_completed。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |

返回：启动线程的 Error 结果码。

<a id="member-gfstorageutility-methods-load_data_request_async"></a>

### `load_data_request_async`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func load_data_request_async(file_name: String) -> GFStorageAsyncOperation:
```

在线程中异步读取纯字典数据，并返回请求专属句柄。 读取终态通过句柄携带 `GFStorageReadResult`，调用方无需监听全局文件名信号。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |

返回：已配置的请求句柄；输入无效或启动失败时句柄立即进入失败终态。

<a id="member-gfstorageutility-methods-wait_for_async_tasks"></a>

### `wait_for_async_tasks`

- API：`public`

```gdscript
func wait_for_async_tasks() -> void:
```

等待已经入队和正在执行的异步纯数据任务全部完成。 需要在同一路径上混合同步与异步读写时，可先调用该方法收敛顺序。

<a id="member-gfstorageutility-methods-migrate_data"></a>

### `migrate_data`

- API：`public`
- 首次版本：`1.19.0`

```gdscript
func migrate_data(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
```

使用已注册步骤迁移存档数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 已读取的数据副本。 |
| `_from_version` | 原版本。 |
| `_to_version` | 目标版本。 |

返回：迁移后的数据。

结构：

- `data`: Dictionary，在存档 schema 版本之间迁移的数据载荷。
- `return`: Dictionary，应用已注册迁移和默认值后的数据载荷。

<a id="member-gfstorageutility-methods-register_migration"></a>

### `register_migration`

- API：`public`

```gdscript
func register_migration(from_version: int, to_version: int, callback: Callable) -> bool:
```

注册一个版本迁移步骤。

参数：

| 名称 | 说明 |
|---|---|
| `from_version` | 来源版本。 |
| `to_version` | 目标版本，必须大于来源版本。 |
| `callback` | 迁移回调，签名为 `func(data: Dictionary, from_version: int, to_version: int) -> Dictionary`。 |

返回：注册成功时返回 true。

<a id="member-gfstorageutility-methods-unregister_migration"></a>

### `unregister_migration`

- API：`public`

```gdscript
func unregister_migration(from_version: int, to_version: int) -> void:
```

注销一个版本迁移步骤。

参数：

| 名称 | 说明 |
|---|---|
| `from_version` | 来源版本。 |
| `to_version` | 目标版本。 |

<a id="member-gfstorageutility-methods-clear_migrations"></a>

### `clear_migrations`

- API：`public`

```gdscript
func clear_migrations() -> void:
```

清空所有注册的版本迁移步骤。

<a id="member-gfstorageutility-methods-get_registered_migrations"></a>

### `get_registered_migrations`

- API：`public`

```gdscript
func get_registered_migrations() -> Array[Dictionary]:
```

获取已注册迁移步骤。

返回：迁移步骤摘要数组。

结构：

- `return`: Array，包含 from_version: int 和 to_version: int 的 Dictionary 条目。
