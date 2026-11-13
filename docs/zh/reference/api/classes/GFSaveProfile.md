# GFSaveProfile

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

多 section 存档的项目级声明。 Profile 从 provider 列表派生唯一文档 schema，避免项目同时维护重复的 section 版本清单。运行时数据仍由 provider 持有，Profile 不解释业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`profile_id`](#member-gfsaveprofile-properties-profile_id) | `var profile_id: StringName = &""` |
| 属性 | [`schema_id`](#member-gfsaveprofile-properties-schema_id) | `var schema_id: StringName = &""` |
| 属性 | [`file_name`](#member-gfsaveprofile-properties-file_name) | `var file_name: String = ""` |
| 属性 | [`schema_version`](#member-gfsaveprofile-properties-schema_version) | `var schema_version: int = 1` |
| 属性 | [`providers`](#member-gfsaveprofile-properties-providers) | `var providers: Array[GFSaveSectionProvider] = []` |
| 属性 | [`recovery_policy`](#member-gfsaveprofile-properties-recovery_policy) | `var recovery_policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()` |
| 属性 | [`save_enabled`](#member-gfsaveprofile-properties-save_enabled) | `var save_enabled: bool = true` |
| 属性 | [`load_enabled`](#member-gfsaveprofile-properties-load_enabled) | `var load_enabled: bool = true` |
| 属性 | [`preserved_sections`](#member-gfsaveprofile-properties-preserved_sections) | `var preserved_sections: PackedStringArray = PackedStringArray()` |
| 方法 | [`validate_profile`](#member-gfsaveprofile-methods-validate_profile) | `func validate_profile() -> Dictionary:` |
| 方法 | [`build_schema`](#member-gfsaveprofile-methods-build_schema) | `func build_schema() -> GFSaveDocumentSchema:` |
| 方法 | [`get_effective_schema_id`](#member-gfsaveprofile-methods-get_effective_schema_id) | `func get_effective_schema_id() -> StringName:` |
| 方法 | [`get_provider`](#member-gfsaveprofile-methods-get_provider) | `func get_provider(section_id: StringName) -> GFSaveSectionProvider:` |
| 方法 | [`get_providers`](#member-gfsaveprofile-methods-get_providers) | `func get_providers() -> Array[GFSaveSectionProvider]:` |

## 属性

<a id="member-gfsaveprofile-properties-profile_id"></a>

### `profile_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var profile_id: StringName = &""
```

稳定运行时 Profile ID。

<a id="member-gfsaveprofile-properties-schema_id"></a>

### `schema_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var schema_id: StringName = &""
```

稳定文档 schema ID；为空时使用 `profile_id`。 将它与运行时 ID 分离后，同一文档定义可用于多个槽位或存储目标。

<a id="member-gfsaveprofile-properties-file_name"></a>

### `file_name`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var file_name: String = ""
```

`GFStorageUtility` 管理的相对文件名。

<a id="member-gfsaveprofile-properties-schema_version"></a>

### `schema_version`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export_range(1, 2_147_483_647, 1)
var schema_version: int = 1
```

当前文档 schema 版本。

<a id="member-gfsaveprofile-properties-providers"></a>

### `providers`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var providers: Array[GFSaveSectionProvider] = []
```

拥有各 section 的 provider，顺序决定采集与应用顺序。

<a id="member-gfsaveprofile-properties-recovery_policy"></a>

### `recovery_policy`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var recovery_policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
```

缺失、损坏和临时 IO 失败的显式政策。

<a id="member-gfsaveprofile-properties-save_enabled"></a>

### `save_enabled`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var save_enabled: bool = true
```

Profile 是否接受保存和 flush 请求。

<a id="member-gfsaveprofile-properties-load_enabled"></a>

### `load_enabled`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
@export
var load_enabled: bool = true
```

Profile 是否接受读取请求。

<a id="member-gfsaveprofile-properties-preserved_sections"></a>

### `preserved_sections`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var preserved_sections: PackedStringArray = PackedStringArray()
```

允许保留但不进入运行状态的分区 ID 清单。 默认拒绝所有未知分区；清单在注册时冻结。永久删除分区应由显式文档迁移执行。

## 方法

<a id="member-gfsaveprofile-methods-validate_profile"></a>

### `validate_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_profile() -> Dictionary:
```

校验 profile、恢复政策和全部 provider。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsaveprofile-methods-build_schema"></a>

### `build_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func build_schema() -> GFSaveDocumentSchema:
```

从当前 provider 清单派生文档 schema。

返回：当前文档 schema；profile 无效时仍返回可诊断对象。

<a id="member-gfsaveprofile-methods-get_effective_schema_id"></a>

### `get_effective_schema_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_effective_schema_id() -> StringName:
```

获取写入文档使用的 schema ID。

返回：`schema_id` 非空时返回它，否则返回 `profile_id`。

<a id="member-gfsaveprofile-methods-get_provider"></a>

### `get_provider`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_provider(section_id: StringName) -> GFSaveSectionProvider:
```

获取指定 section 的唯一 provider。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 目标 section ID。 |

返回：匹配 provider；不存在时返回 null。

<a id="member-gfsaveprofile-methods-get_providers"></a>

### `get_providers`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_providers() -> Array[GFSaveSectionProvider]:
```

获取 provider 引用的隔离数组。

返回：按声明顺序排列的 provider。
