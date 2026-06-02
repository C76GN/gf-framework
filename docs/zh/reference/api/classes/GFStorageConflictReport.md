# GFStorageConflictReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_conflict_report.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

存储同步冲突的通用报告数据。 该资源只描述冲突，不决定如何解决冲突。项目可以把它用于云同步、 多端合并、调试 UI 或自动化测试。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Resolution`](#member-gfstorageconflictreport-enums-resolution) | `enum Resolution` |
| 属性 | [`file_name`](#member-gfstorageconflictreport-properties-file_name) | `var file_name: String = ""` |
| 属性 | [`key`](#member-gfstorageconflictreport-properties-key) | `var key: String = ""` |
| 属性 | [`local_value`](#member-gfstorageconflictreport-properties-local_value) | `var local_value: Variant = null` |
| 属性 | [`remote_value`](#member-gfstorageconflictreport-properties-remote_value) | `var remote_value: Variant = null` |
| 属性 | [`resolved_value`](#member-gfstorageconflictreport-properties-resolved_value) | `var resolved_value: Variant = null` |
| 属性 | [`resolution`](#member-gfstorageconflictreport-properties-resolution) | `var resolution: Resolution = Resolution.UNRESOLVED` |
| 属性 | [`metadata`](#member-gfstorageconflictreport-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`apply_dict`](#member-gfstorageconflictreport-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`to_dict`](#member-gfstorageconflictreport-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_report`](#member-gfstorageconflictreport-methods-duplicate_report) | `func duplicate_report() -> GFStorageConflictReport:` |
| 方法 | [`is_resolved`](#member-gfstorageconflictreport-methods-is_resolved) | `func is_resolved() -> bool:` |
| 方法 | [`from_dict`](#member-gfstorageconflictreport-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFStorageConflictReport:` |

## 枚举

<a id="member-gfstorageconflictreport-enums-resolution"></a>

### `Resolution`

- API：`public`

```gdscript
enum Resolution { ## 尚未决定。 UNRESOLVED, ## 使用本地值。 USE_LOCAL, ## 使用远端值。 USE_REMOTE, ## 使用合并后的值。 MERGED, ## 跳过该冲突。 SKIPPED, }
```

冲突解决策略。

## 属性

<a id="member-gfstorageconflictreport-properties-file_name"></a>

### `file_name`

- API：`public`

```gdscript
var file_name: String = ""
```

冲突所属逻辑文件名。

<a id="member-gfstorageconflictreport-properties-key"></a>

### `key`

- API：`public`

```gdscript
var key: String = ""
```

冲突字段或业务 key。

<a id="member-gfstorageconflictreport-properties-local_value"></a>

### `local_value`

- API：`public`

```gdscript
var local_value: Variant = null
```

本地值。

结构：

- `local_value`: Variant，从本地记录复制的冲突 key 或载荷值。

<a id="member-gfstorageconflictreport-properties-remote_value"></a>

### `remote_value`

- API：`public`

```gdscript
var remote_value: Variant = null
```

远端值。

结构：

- `remote_value`: Variant，从远端记录复制的冲突 key 或载荷值。

<a id="member-gfstorageconflictreport-properties-resolved_value"></a>

### `resolved_value`

- API：`public`

```gdscript
var resolved_value: Variant = null
```

合并后的值。

结构：

- `resolved_value`: Variant，由解析器选择或合并出的值。

<a id="member-gfstorageconflictreport-properties-resolution"></a>

### `resolution`

- API：`public`

```gdscript
var resolution: Resolution = Resolution.UNRESOLVED
```

解决策略。

<a id="member-gfstorageconflictreport-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

扩展元数据。

结构：

- `metadata`: Dictionary，包含解析器特定诊断信息或后端元数据快照。

## 方法

<a id="member-gfstorageconflictreport-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

结构：

- `data`: Dictionary，包含 file_name、key、local_value、remote_value、resolved_value、resolution 和 metadata。

<a id="member-gfstorageconflictreport-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：字典副本。

结构：

- `return`: Dictionary，包含 file_name、key、local_value、remote_value、resolved_value、resolution 和 metadata。

<a id="member-gfstorageconflictreport-methods-duplicate_report"></a>

### `duplicate_report`

- API：`public`

```gdscript
func duplicate_report() -> GFStorageConflictReport:
```

复制冲突报告。

返回：新报告实例。

<a id="member-gfstorageconflictreport-methods-is_resolved"></a>

### `is_resolved`

- API：`public`

```gdscript
func is_resolved() -> bool:
```

是否已经解决。

返回：resolution 不是 UNRESOLVED 时返回 true。

<a id="member-gfstorageconflictreport-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFStorageConflictReport:
```

从字典创建冲突报告。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

返回：新报告实例。

结构：

- `data`: Dictionary，包含 file_name、key、local_value、remote_value、resolved_value、resolution 和 metadata。
