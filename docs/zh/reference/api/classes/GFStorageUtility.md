# GFStorageUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

基于 `user://` 的轻量存档系统。 支持槽位存档、元数据分离读取、`Resource` 存取， 以及可配置 codec、完整性校验、版本迁移和简单混淆，适合通用本地持久化场景。 所有公开文件与目录入口只接受当前 Storage root 内的规范相对路径；运行时不提供 任意绝对路径能力，需要访问外部路径的可信编辑器工具应直接使用其自有 FileAccess 边界。 这是 GF API 的词法路径与所有权边界，不是抵御同进程 FileAccess、宿主链接或挂载点的文件系统沙箱。 该混淆不提供安全加密能力，请勿用于保护敏感数据。 `Resource` 存取只面向项目生成或项目已确认来源与格式的本地文件；它不是未确认来源资源的沙盒化导入器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`data_integrity_failed`](#member-gfstorageutility-signals-data_integrity_failed) | `signal data_integrity_failed(file_name: String, error: String)` |
| 信号 | [`data_migrated`](#member-gfstorageutility-signals-data_migrated) | `signal data_migrated(file_name: String, from_version: int, to_version: int)` |
| 信号 | [`save_completed`](#member-gfstorageutility-signals-save_completed) | `signal save_completed(file_name: String, error: Error)` |
| 信号 | [`load_completed`](#member-gfstorageutility-signals-load_completed) | `signal load_completed(file_name: String, result: GFStorageReadResult)` |
| 枚举 | [`AsyncExecutionMode`](#member-gfstorageutility-enums-asyncexecutionmode) | `enum AsyncExecutionMode` |
| 常量 | [`DEFAULT_MAX_LIST_DEPTH`](#member-gfstorageutility-constants-default_max_list_depth) | `const DEFAULT_MAX_LIST_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_LISTED_FILES`](#member-gfstorageutility-constants-default_max_listed_files) | `const DEFAULT_MAX_LISTED_FILES: int = 10000` |
| 属性 | [`encrypt_key`](#member-gfstorageutility-properties-encrypt_key) | `var encrypt_key: int = 42` |
| 属性 | [`save_dir_name`](#member-gfstorageutility-properties-save_dir_name) | `var save_dir_name: String = "saves":` |
| 属性 | [`codec`](#member-gfstorageutility-properties-codec) | `var codec: GFStorageCodec = GFStorageCodec.new()` |
| 属性 | [`file_format`](#member-gfstorageutility-properties-file_format) | `var file_format: GFStorageCodec.Format = GFStorageCodec.Format.JSON` |
| 属性 | [`use_compression`](#member-gfstorageutility-properties-use_compression) | `var use_compression: bool = false` |
| 属性 | [`normalize_json_numbers`](#member-gfstorageutility-properties-normalize_json_numbers) | `var normalize_json_numbers: bool = false` |
| 属性 | [`use_integrity_checksum`](#member-gfstorageutility-properties-use_integrity_checksum) | `var use_integrity_checksum: bool = false` |
| 属性 | [`strict_integrity`](#member-gfstorageutility-properties-strict_integrity) | `var strict_integrity: bool = true` |
| 属性 | [`require_integrity_checksum`](#member-gfstorageutility-properties-require_integrity_checksum) | `var require_integrity_checksum: bool = true` |
| 属性 | [`include_storage_metadata`](#member-gfstorageutility-properties-include_storage_metadata) | `var include_storage_metadata: bool = false` |
| 属性 | [`allow_resource_loads`](#member-gfstorageutility-properties-allow_resource_loads) | `var allow_resource_loads: bool = false` |
| 属性 | [`allowed_resource_load_extensions`](#member-gfstorageutility-properties-allowed_resource_load_extensions) | `var allowed_resource_load_extensions: PackedStringArray = PackedStringArray(["tres", "res"])` |
| 属性 | [`allowed_resource_load_type_hints`](#member-gfstorageutility-properties-allowed_resource_load_type_hints) | `var allowed_resource_load_type_hints: PackedStringArray = PackedStringArray()` |
| 属性 | [`require_resource_load_type_hint`](#member-gfstorageutility-properties-require_resource_load_type_hint) | `var require_resource_load_type_hint: bool = true` |
| 属性 | [`async_execution_mode`](#member-gfstorageutility-properties-async_execution_mode) | `var async_execution_mode: AsyncExecutionMode = AsyncExecutionMode.AUTOMATIC:` |
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
| 方法 | [`list_files`](#member-gfstorageutility-methods-list_files) | `func list_files( directory_name: String = "", extension_filter: String = "", recursive: bool = false, options: Dictionary = {} ) -> PackedStringArray:` |
| 方法 | [`has_file`](#member-gfstorageutility-methods-has_file) | `func has_file(file_name: String) -> bool:` |
| 方法 | [`delete_file`](#member-gfstorageutility-methods-delete_file) | `func delete_file(file_name: String) -> Error:` |
| 方法 | [`delete_file_request_async`](#member-gfstorageutility-methods-delete_file_request_async) | `func delete_file_request_async( file_name: String, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:` |
| 方法 | [`create_family_reset_authorization`](#member-gfstorageutility-methods-create_family_reset_authorization) | `func create_family_reset_authorization( file_name: String, observed_result: GFStorageReadResult ) -> GFStorageFamilyResetAuthorization:` |
| 方法 | [`reset_file_family`](#member-gfstorageutility-methods-reset_file_family) | `func reset_file_family( file_name: String, authorization: GFStorageFamilyResetAuthorization ) -> GFStorageFamilyResetResult:` |
| 方法 | [`reset_file_family_request_async`](#member-gfstorageutility-methods-reset_file_family_request_async) | `func reset_file_family_request_async( file_name: String, authorization: GFStorageFamilyResetAuthorization, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:` |
| 方法 | [`save_data`](#member-gfstorageutility-methods-save_data) | `func save_data(file_name: String, data: Dictionary) -> Error:` |
| 方法 | [`save_data_group`](#member-gfstorageutility-methods-save_data_group) | `func save_data_group(files: Dictionary) -> Error:` |
| 方法 | [`load_data`](#member-gfstorageutility-methods-load_data) | `func load_data(file_name: String) -> GFStorageReadResult:` |
| 方法 | [`canonicalize_data_file_name`](#member-gfstorageutility-methods-canonicalize_data_file_name) | `func canonicalize_data_file_name(file_name: String) -> String:` |
| 方法 | [`save_data_async`](#member-gfstorageutility-methods-save_data_async) | `func save_data_async(file_name: String, data: Dictionary) -> Error:` |
| 方法 | [`save_data_request_async`](#member-gfstorageutility-methods-save_data_request_async) | `func save_data_request_async( file_name: String, data: Dictionary, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:` |
| 方法 | [`save_payload_request_async`](#member-gfstorageutility-methods-save_payload_request_async) | `func save_payload_request_async( file_name: String, transfer: GFStoragePayloadTransfer, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:` |
| 方法 | [`load_data_async`](#member-gfstorageutility-methods-load_data_async) | `func load_data_async(file_name: String) -> Error:` |
| 方法 | [`load_data_request_async`](#member-gfstorageutility-methods-load_data_request_async) | `func load_data_request_async( file_name: String, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:` |
| 方法 | [`get_late_settlement_diagnostics`](#member-gfstorageutility-methods-get_late_settlement_diagnostics) | `func get_late_settlement_diagnostics() -> Array[Dictionary]:` |
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

## 枚举

<a id="member-gfstorageutility-enums-asyncexecutionmode"></a>

### `AsyncExecutionMode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum AsyncExecutionMode {
	## 自动选择；无线程能力的构建使用 cooperative，否则使用线程。
	AUTOMATIC = 0,
	## 强制使用线程；无线程能力时 activation 确定性失败。
	THREADED = 1,
	## 由 lifecycle tick 在主线程逐项推进，不创建 Thread。
	COOPERATIVE = 2,
}
```

异步 Storage 请求的执行模式。

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
- 首次版本：`3.17.0`

```gdscript
var save_dir_name: String = "saves":
```

Storage root 的 portable logical 目录名；为空时使用 `user://`。 首次 activation、显式 `init()` 或合法 I/O 尝试后冻结；非法配置失败关闭。

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

<a id="member-gfstorageutility-properties-async_execution_mode"></a>

### `async_execution_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var async_execution_mode: AsyncExecutionMode = AsyncExecutionMode.AUTOMATIC:
```

异步 Storage 请求的执行模式。首个合法异步请求入队后冻结。

<a id="member-gfstorageutility-properties-max_async_thread_count"></a>

### `max_async_thread_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_async_thread_count: int = 4:
```

线程模式同时运行的异步存取线程数量，小于 1 时会被钳制为 1。 cooperative 模式固定每个 lifecycle tick 最多执行一个任务。

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
- 首次版本：`3.17.0`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

驱动异步存档任务完成检查；cooperative 模式还会在主线程执行至多一个完整 I/O。

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

激活 Storage 的同步与异步 I/O 准入。 强制线程模式缺少 `threads` 能力时，失败 metadata.error_code 为 ERR_CANT_CREATE。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Storage 激活阶段的取消作用域。 |

返回：成功打开 I/O 准入；否则返回失败终态。

<a id="member-gfstorageutility-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
```

关闭新 I/O 准入，并等待此前接纳的队列、执行任务和文件锁全部收敛。 已接纳任务继续由 lifecycle tick 推进；强制 dispose 仍会使用同步 join fallback。

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

<a id="member-gfstorageutility-methods-list_files"></a>

### `list_files`

- API：`public`
- 首次版本：`2.3.0`

```gdscript
func list_files( directory_name: String = "", extension_filter: String = "", recursive: bool = false, options: Dictionary = {} ) -> PackedStringArray:
```

枚举指定存储目录下的文件。

参数：

| 名称 | 说明 |
|---|---|
| `directory_name` | 相对存储目录；为空时枚举根存储目录。 |
| `extension_filter` | 可选 canonical lowercase 扩展名过滤，不包含点号。 |
| `recursive` | 是否递归枚举子目录。 |
| `options` | 可选参数，支持 \`max_scan_depth\` 与 \`max_file_count\`。 |

返回：从已校验 catalog 投影的 committed portable logical file identity 数组。

结构：

- `options`: Dictionary，包含 max_scan_depth: int 和 max_file_count: int。

<a id="member-gfstorageutility-methods-has_file"></a>

### `has_file`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_file(file_name: String) -> bool:
```

判断一个 logical file 是否存在 committed payload。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | portable logical file identity。 |

返回：catalog、owner 与 payload 均有效时返回 true。

<a id="member-gfstorageutility-methods-delete_file"></a>

### `delete_file`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func delete_file(file_name: String) -> Error:
```

删除一个精确 logical family 的全部可变成员。 该方法不会扫描或收养 Storage root 下的旧版可见文件；immutable catalog/owner claim 会保留。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | portable logical file identity。 |

返回：Godot 的 `Error` 结果码；family 未 claim 或没有可变成员时返回 `ERR_FILE_NOT_FOUND`。

<a id="member-gfstorageutility-methods-delete_file_request_async"></a>

### `delete_file_request_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func delete_file_request_async( file_name: String, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:
```

通过当前 Storage executor 删除一个精确 logical family，并返回请求专属句柄。 请求只删除冻结 family 的八个可变物理成员；catalog 与 owner identity 保留。 删除不会隐式恢复事务，也不会扫描或收养 sibling family。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | portable logical file identity。 |
| `options` | 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。 |

返回：已配置的 typed 请求句柄；路径或生命周期校验失败时立即进入失败终态。

<a id="member-gfstorageutility-methods-create_family_reset_authorization"></a>

### `create_family_reset_authorization`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func create_family_reset_authorization( file_name: String, observed_result: GFStorageReadResult ) -> GFStorageFamilyResetAuthorization:
```

为一次显式的破坏性 family reset 创建绑定授权。 只有当前 GFStorageUtility 对同一 logical identity 返回的 CORRUPT 读取结果才可 创建授权。授权冻结 Utility、Storage root、canonical logical identity 与当前 family 观察， 且只能消费一次；签发前或后发生的较新同 family 写入/修复会使旧观察失效。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | portable logical file identity。 |
| `observed_result` | 调用方已经检查并决定破坏性恢复的 CORRUPT 读取结果。 |

返回：可用的一次性授权；输入或读取分类不匹配时返回 stale 授权。

<a id="member-gfstorageutility-methods-reset_file_family"></a>

### `reset_file_family`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func reset_file_family( file_name: String, authorization: GFStorageFamilyResetAuthorization ) -> GFStorageFamilyResetResult:
```

同步 retire 并重新 claim 一个显式授权的 logical family。 该入口与同 family 的异步 save/load/delete/reset 串行。missing target 与 future layout 都在零写入前失败；同执行栈仍有该 family 工作时以 ERR_BUSY / UNAVAILABLE 拒绝。 结果不暴露任何 private path 或 retirement staging 名称。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 必须与 authorization 绑定完全一致的 portable logical identity。 |
| `authorization` | 由 create_family_reset_authorization() 创建的一次性授权。 |

返回：reset/recreate 的不可变 typed 终态。

<a id="member-gfstorageutility-methods-reset_file_family_request_async"></a>

### `reset_file_family_request_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func reset_file_family_request_async( file_name: String, authorization: GFStorageFamilyResetAuthorization, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:
```

通过当前 Storage executor 异步 retire 并重新 claim 一个显式授权的 logical family。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 必须与 authorization 绑定完全一致的 portable logical identity。 |
| `authorization` | 由 create_family_reset_authorization() 创建的一次性授权。 |
| `options` | 可选 caller owner、取消 token 与单调 deadline。 |

返回：请求专属句柄；终态通过 GFStorageAsyncResult.get_reset_result() 读取。

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

- `files`: Dictionary，键必须是未经改写的 String portable logical identity，值为要序列化并保存的 Dictionary 载荷。

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

校验一个已经 canonical 的 portable logical 数据文件名。 返回值与异步队列的同文件锁使用相同路径规则，可用于建立稳定所有权键。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 待校验文件名。 |

返回：输入本身满足 portable-ascii-v1 时原样返回；不会改写别名，非法时返回空字符串。

<a id="member-gfstorageutility-methods-save_data_async"></a>

### `save_data_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func save_data_async(file_name: String, data: Dictionary) -> Error:
```

通过当前 Storage executor 异步保存纯字典数据。完成后从主线程发出 save_completed。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `data` | 要保存的字典。 |

返回：请求接纳结果码；成功入队时返回 OK。

结构：

- `data`: Dictionary，要序列化并保存的数据载荷。

<a id="member-gfstorageutility-methods-save_data_request_async"></a>

### `save_data_request_async`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func save_data_request_async( file_name: String, data: Dictionary, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:
```

通过当前 Storage executor 异步保存纯字典数据，并返回请求专属句柄。 句柄终态不会与共享 Storage 上同文件的其他请求混淆。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `data` | 要保存的字典。 |
| `options` | 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。 |

返回：已配置的请求句柄；输入无效或启动失败时句柄立即进入失败终态。

结构：

- `data`: Dictionary，要序列化并保存的数据载荷。

<a id="member-gfstorageutility-methods-save_payload_request_async"></a>

### `save_payload_request_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func save_payload_request_async( file_name: String, transfer: GFStoragePayloadTransfer, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:
```

通过当前 Storage executor 保存由单所有者 transfer 移交的纯 Variant payload。 路径校验在 claim 前完成；非法路径不会消费 transfer。首次合法请求会冻结当前 Storage 实例、规范文件名与 codec options。同一 transfer 可在旧 attempt 尚未 完成时提交给相同绑定，用于 timeout retry；所有 attempt 只读同一逻辑快照。 调用方完成整个重试 generation 后必须显式调用 transfer.release()。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `transfer` | 已通过 take_ownership() 接收 payload 的 opaque transfer。 |
| `options` | 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。 |

返回：已配置请求句柄；输入无效或启动失败时句柄立即进入失败终态。

<a id="member-gfstorageutility-methods-load_data_async"></a>

### `load_data_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func load_data_async(file_name: String) -> Error:
```

通过当前 Storage executor 异步读取纯字典数据。完成后从主线程发出 load_completed。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |

返回：请求接纳结果码；成功入队时返回 OK。

<a id="member-gfstorageutility-methods-load_data_request_async"></a>

### `load_data_request_async`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func load_data_request_async( file_name: String, options: GFStorageAsyncRequestOptions = null ) -> GFStorageAsyncOperation:
```

通过当前 Storage executor 异步读取纯字典数据，并返回请求专属句柄。 读取终态通过句柄携带 `GFStorageReadResult`，调用方无需监听全局文件名信号。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `options` | 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。 |

返回：已配置的请求句柄；输入无效或启动失败时句柄立即进入失败终态。

<a id="member-gfstorageutility-methods-get_late_settlement_diagnostics"></a>

### `get_late_settlement_diagnostics`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_late_settlement_diagnostics() -> Array[Dictionary]:
```

获取最近的 late physical settlement 脱敏诊断。 诊断按物理终态到达顺序保留最近 64 条；不包含读载荷、写 payload、绝对路径或 family 私有身份。返回值为深复制，调用方修改不会影响 Utility 内部 ring。

返回：最旧到最新排列的有界 late settlement 诊断副本。

结构：

- `return`: Array of exact Dictionary entries with consumer_id, request_id, operation, file_name, caller_status, caller_end_kind, caller_reason, caller_completed_msec, worker_accepted, physical_cancel_requested, settlement_kind, physical_ok, physical_error_code, physical_completed_msec, late_duration_msec, read_failure_kind, write_failure_kind, delete_failure_kind, delete_existing_member_count, delete_removed_member_count, delete_remaining_member_count, delete_failed_member, reset_failure_kind, reset_source_kind, reset_failed_phase, reset_retired_member_count, reset_recreated_member_count, reset_remaining_evidence_count, and reset_failed_member fields.

<a id="member-gfstorageutility-methods-wait_for_async_tasks"></a>

### `wait_for_async_tasks`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func wait_for_async_tasks() -> void:
```

等待已经入队和正在执行的异步 save/load/delete/reset 任务全部完成。 需要在同一路径上混合同步与异步操作时，可先调用该方法收敛顺序。 Storage executor 的同步执行栈内会拒绝重入等待，避免等待当前调用栈自身完成。

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
| `callback` | 迁移回调，签名为 \`func(data: Dictionary, from_version: int, to_version: int) -> Dictionary\`。 |

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
