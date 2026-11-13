# GFStorageConflictReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_conflict_report.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

冻结的记录冲突与显式解决候选。 载荷只能通过显式 getter 读取；to_dict() 不包含身份、revision 或业务数据。 revision 只能比较相等。报告不执行写入，也不证明解决候选已提交。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Resolution`](#member-gfstorageconflictreport-enums-resolution) | `enum Resolution` |
| 方法 | [`create`](#member-gfstorageconflictreport-methods-create) | `static func create( record_namespace: String, record_key: String, local_data: Dictionary, remote_data: Dictionary, options: Dictionary = {} ) -> GFStorageConflictReport:` |
| 方法 | [`with_resolution`](#member-gfstorageconflictreport-methods-with_resolution) | `func with_resolution(resolution: Resolution, data: Dictionary = {}) -> GFStorageConflictReport:` |
| 方法 | [`duplicate_report`](#member-gfstorageconflictreport-methods-duplicate_report) | `func duplicate_report() -> GFStorageConflictReport:` |
| 方法 | [`get_namespace`](#member-gfstorageconflictreport-methods-get_namespace) | `func get_namespace() -> String:` |
| 方法 | [`get_key`](#member-gfstorageconflictreport-methods-get_key) | `func get_key() -> String:` |
| 方法 | [`get_expected_revision`](#member-gfstorageconflictreport-methods-get_expected_revision) | `func get_expected_revision() -> String:` |
| 方法 | [`get_actual_revision`](#member-gfstorageconflictreport-methods-get_actual_revision) | `func get_actual_revision() -> String:` |
| 方法 | [`get_local_data`](#member-gfstorageconflictreport-methods-get_local_data) | `func get_local_data() -> Dictionary:` |
| 方法 | [`get_remote_data`](#member-gfstorageconflictreport-methods-get_remote_data) | `func get_remote_data() -> Dictionary:` |
| 方法 | [`get_resolved_data`](#member-gfstorageconflictreport-methods-get_resolved_data) | `func get_resolved_data() -> Dictionary:` |
| 方法 | [`remote_exists`](#member-gfstorageconflictreport-methods-remote_exists) | `func remote_exists() -> bool:` |
| 方法 | [`get_resolution`](#member-gfstorageconflictreport-methods-get_resolution) | `func get_resolution() -> Resolution:` |
| 方法 | [`is_resolved`](#member-gfstorageconflictreport-methods-is_resolved) | `func is_resolved() -> bool:` |
| 方法 | [`to_dict`](#member-gfstorageconflictreport-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstorageconflictreport-enums-resolution"></a>

### `Resolution`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Resolution {
	## 尚未决定。
	UNRESOLVED,
	## 选择本地候选。
	USE_LOCAL,
	## 选择远端候选。
	USE_REMOTE,
	## 使用项目合并候选。
	MERGED,
	## 跳过冲突。
	SKIPPED,
}
```

候选的解决方式，不代表持久化结果。

## 方法

<a id="member-gfstorageconflictreport-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( record_namespace: String, record_key: String, local_data: Dictionary, remote_data: Dictionary, options: Dictionary = {} ) -> GFStorageConflictReport:
```

创建冻结报告；无效身份、选项或载荷返回 null。

参数：

| 名称 | 说明 |
|---|---|
| `record_namespace` | 记录命名空间。 |
| `record_key` | 记录键。 |
| `local_data` | 本地完整候选。 |
| `remote_data` | 已观察的远端完整候选。 |
| `options` | revision 与存在性声明。 |

返回：隔离报告或 null；完整报告限深度64、300000节点、64MiB规范字节。

结构：

- `local_data`: Dictionary of finite native data; no objects or cycles.
- `remote_data`: Same native contract; empty when remote_exists=false.
- `options`: Closed Dictionary with expected_revision:String (default empty), actual_revision:String (default empty), remote_exists:bool (default true). Empty revisions are allowed for plain Backend transfers.

<a id="member-gfstorageconflictreport-methods-with_resolution"></a>

### `with_resolution`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func with_resolution(resolution: Resolution, data: Dictionary = {}) -> GFStorageConflictReport:
```

返回指定解决候选的新报告；原报告不变。

参数：

| 名称 | 说明 |
|---|---|
| `resolution` | 明确的解决方式。 |
| `data` | 解决候选；未解决或跳过时必须为空。 |

返回：隔离的新报告或 null。

结构：

- `data`: Dictionary of admitted finite native data.

<a id="member-gfstorageconflictreport-methods-duplicate_report"></a>

### `duplicate_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_report() -> GFStorageConflictReport:
```

复制完整报告；无效对象返回 null。

返回：独立报告副本。

<a id="member-gfstorageconflictreport-methods-get_namespace"></a>

### `get_namespace`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_namespace() -> String:
```

获取记录命名空间。

返回：稳定命名空间。

<a id="member-gfstorageconflictreport-methods-get_key"></a>

### `get_key`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_key() -> String:
```

获取记录键。

返回：稳定记录键。

<a id="member-gfstorageconflictreport-methods-get_expected_revision"></a>

### `get_expected_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_expected_revision() -> String:
```

获取本地已知 revision。

返回：不透明 revision。

<a id="member-gfstorageconflictreport-methods-get_actual_revision"></a>

### `get_actual_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_actual_revision() -> String:
```

获取远端观察 revision。

返回：不透明 revision。

<a id="member-gfstorageconflictreport-methods-get_local_data"></a>

### `get_local_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_local_data() -> Dictionary:
```

获取本地候选副本。

返回：完整候选副本。

结构：

- `return`: Dictionary of admitted native data.

<a id="member-gfstorageconflictreport-methods-get_remote_data"></a>

### `get_remote_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_remote_data() -> Dictionary:
```

获取远端候选副本。

返回：完整候选副本。

结构：

- `return`: Dictionary of admitted native data.

<a id="member-gfstorageconflictreport-methods-get_resolved_data"></a>

### `get_resolved_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resolved_data() -> Dictionary:
```

获取解决候选副本。

返回：尚未持久化的候选副本。

结构：

- `return`: Dictionary of admitted native data.

<a id="member-gfstorageconflictreport-methods-remote_exists"></a>

### `remote_exists`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func remote_exists() -> bool:
```

查询远端记录存在性。

返回：已观察远端存在时为 true。

<a id="member-gfstorageconflictreport-methods-get_resolution"></a>

### `get_resolution`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resolution() -> Resolution:
```

获取选择的解决方式。

返回：Resolution 枚举值。

<a id="member-gfstorageconflictreport-methods-is_resolved"></a>

### `is_resolved`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_resolved() -> bool:
```

检查是否已选择解决方式，不代表写入成功。

返回：已选择或跳过时为 true。

<a id="member-gfstorageconflictreport-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

导出不含载荷与身份的诊断摘要。

返回：诊断摘要。

结构：

- `return`: Dictionary with valid:bool,resolution:int,remote_exists:bool,revision_matches:bool.
