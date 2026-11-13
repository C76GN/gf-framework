# GFStorageSyncRequest

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_request.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

与命名空间、记录和操作身份绑定的冻结同步请求。 revision 是不透明文本，空文本只表示预期记录不存在。operation_id 必须由调用方 唯一分配；恢复同一次提交时沿用原 ID，不得用它提交不同载荷。请求不包含账号凭证。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfstoragesyncrequest-methods-create) | `static func create( record_namespace: String, record_key: String, operation_id: String, data: Dictionary = {}, options: Dictionary = {} ) -> GFStorageSyncRequest:` |
| 方法 | [`get_limits`](#member-gfstoragesyncrequest-methods-get_limits) | `static func get_limits() -> Dictionary:` |
| 方法 | [`validate_input`](#member-gfstoragesyncrequest-methods-validate_input) | `static func validate_input( record_namespace: String, record_key: String, operation_id: String, data: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`from_record`](#member-gfstoragesyncrequest-methods-from_record) | `static func from_record(record: Dictionary) -> GFStorageSyncRequest:` |
| 方法 | [`is_valid`](#member-gfstoragesyncrequest-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_namespace`](#member-gfstoragesyncrequest-methods-get_namespace) | `func get_namespace() -> String:` |
| 方法 | [`get_key`](#member-gfstoragesyncrequest-methods-get_key) | `func get_key() -> String:` |
| 方法 | [`get_operation_id`](#member-gfstoragesyncrequest-methods-get_operation_id) | `func get_operation_id() -> String:` |
| 方法 | [`get_mode`](#member-gfstoragesyncrequest-methods-get_mode) | `func get_mode() -> StringName:` |
| 方法 | [`get_resolution`](#member-gfstoragesyncrequest-methods-get_resolution) | `func get_resolution() -> StringName:` |
| 方法 | [`get_expected_revision`](#member-gfstoragesyncrequest-methods-get_expected_revision) | `func get_expected_revision() -> String:` |
| 方法 | [`get_local_generation`](#member-gfstoragesyncrequest-methods-get_local_generation) | `func get_local_generation() -> int:` |
| 方法 | [`get_timeout_msec`](#member-gfstoragesyncrequest-methods-get_timeout_msec) | `func get_timeout_msec() -> int:` |
| 方法 | [`get_data`](#member-gfstoragesyncrequest-methods-get_data) | `func get_data() -> Dictionary:` |
| 方法 | [`to_record`](#member-gfstoragesyncrequest-methods-to_record) | `func to_record() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfstoragesyncrequest-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfstoragesyncrequest-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( record_namespace: String, record_key: String, operation_id: String, data: Dictionary = {}, options: Dictionary = {} ) -> GFStorageSyncRequest:
```

创建冻结请求；只接受明确选项和有界原生数据，任何失败均返回 null。

参数：

| 名称 | 说明 |
|---|---|
| `record_namespace` | 调用方的稳定命名空间，不代表远端授权。 |
| `record_key` | 命名空间内的稳定记录键。 |
| `operation_id` | 本次提交的唯一操作 ID，恢复时保持不变。 |
| `data` | 本次上传的完整候选；pull/preview 可为空。 |
| `options` | 同步模式、冲突选择、已知 revision 和本地代际。 |

返回：有效请求或 null。

结构：

- `data`: Dictionary of finite native Variant values, without Object, Callable, Signal, RID or cycles; complete request limited to depth64,100000 nodes,16MiB canonical bytes.
- `options`: Closed Dictionary with optional mode: StringName/String (push, pull, preview, probe; default push), resolution: StringName/String (report, local, remote; default report), expected_revision: String (default empty), local_generation: int>=0 (default0), timeout_msec: int in1..300000 (default30000).

<a id="member-gfstoragesyncrequest-methods-get_limits"></a>

### `get_limits`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_limits() -> Dictionary:
```

获取完整请求的规范编码硬预算；修改返回字典不会改变准入规则。

返回：请求封套及其载荷共同使用的预算，不是压缩后的文件大小。

结构：

- `return`: Dictionary with max_depth:int,max_items:int,max_output_bytes:int,max_string_length:int.

<a id="member-gfstoragesyncrequest-methods-validate_input"></a>

### `validate_input`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func validate_input( record_namespace: String, record_key: String, operation_id: String, data: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

只读验证工厂输入，不创建请求、不复制载荷，也不发起 IO。 与 create() 使用同一准入路径；报告不授权之后被修改的数据。计量失败时 observed 只包含已遍历部分，不提供完整输入大小；报告不含业务值或记录身份。

参数：

| 名称 | 说明 |
|---|---|
| `record_namespace` | 稳定命名空间。 |
| `record_key` | 稳定记录键。 |
| `operation_id` | 唯一操作身份。 |
| `data` | 保持不变的候选载荷。 |
| `options` | 与 create() 相同的闭合选项。 |

返回：不含载荷的准入诊断。

结构：

- `data`: 与 create() 相同的有限原生数据；非法值在复制前拒绝。
- `options`: Closed Dictionary with mode,resolution,expected_revision,local_generation,timeout_msec.
- `return`: Dictionary with ok:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary; observed is empty or a measure_canonical() report.

<a id="member-gfstoragesyncrequest-methods-from_record"></a>

### `from_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_record(record: Dictionary) -> GFStorageSyncRequest:
```

从持久化意图恢复同一请求，严格拒绝缺失或额外字段。

参数：

| 名称 | 说明 |
|---|---|
| `record` | to_record() 产生的完整记录。 |

返回：已重新验证的冻结请求或 null。

结构：

- `record`: Closed Dictionary containing namespace,key,operation_id,data,mode,resolution,expected_revision,local_generation,timeout_msec.

<a id="member-gfstoragesyncrequest-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

检查请求是否由成功的工厂调用创建。

返回：有效时返回 true。

<a id="member-gfstoragesyncrequest-methods-get_namespace"></a>

### `get_namespace`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_namespace() -> String:
```

获取命名空间。

返回：稳定命名空间。

<a id="member-gfstoragesyncrequest-methods-get_key"></a>

### `get_key`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_key() -> String:
```

获取记录键。

返回：稳定记录键。

<a id="member-gfstoragesyncrequest-methods-get_operation_id"></a>

### `get_operation_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_operation_id() -> String:
```

获取操作 ID。

返回：唯一提交身份。

<a id="member-gfstoragesyncrequest-methods-get_mode"></a>

### `get_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_mode() -> StringName:
```

获取请求模式。

返回：push、pull、preview 或 probe。

<a id="member-gfstoragesyncrequest-methods-get_resolution"></a>

### `get_resolution`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resolution() -> StringName:
```

获取明确的冲突选择。

返回：report、local 或 remote。

<a id="member-gfstoragesyncrequest-methods-get_expected_revision"></a>

### `get_expected_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_expected_revision() -> String:
```

获取预期 revision；只能比较相等。

返回：不透明 revision，空文本表示预期不存在。

<a id="member-gfstoragesyncrequest-methods-get_local_generation"></a>

### `get_local_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_local_generation() -> int:
```

获取本次冻结的本地代际。

返回：非负本地代际，不用于与远端 revision 排序比较。

<a id="member-gfstoragesyncrequest-methods-get_timeout_msec"></a>

### `get_timeout_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_timeout_msec() -> int:
```

获取每个协议阶段的单调时间等待上限。

返回：正整数毫秒。

<a id="member-gfstoragesyncrequest-methods-get_data"></a>

### `get_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_data() -> Dictionary:
```

显式获取候选载荷的独立副本。

返回：候选数据副本。

结构：

- `return`: Dictionary of admitted native data.

<a id="member-gfstoragesyncrequest-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

显式导出可持久化意图；包含业务载荷，不能用作日志或诊断。

返回：完整独立记录。

结构：

- `return`: Closed Dictionary accepted by from_record().

<a id="member-gfstoragesyncrequest-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含命名空间、载荷、revision 或操作 ID 的诊断摘要。

返回：请求模式和代际摘要。

结构：

- `return`: Dictionary with valid,mode,resolution,local_generation,timeout_msec.
