# GFSaveSectionSnapshot

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_section_snapshot.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单个 Save section 的一次性所有权快照。 Snapshot 只保存纯 Variant 数据，并在框架接管后立即清空自身引用。调用 `take_ownership()` 后，调用方必须放弃原 payload、metadata 及其全部嵌套别名； GDScript 不提供语言级 move 语义，因此该约束属于显式所有权协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATE_AVAILABLE`](#member-gfsavesectionsnapshot-constants-state_available) | `const STATE_AVAILABLE: StringName = &"available"` |
| 常量 | [`STATE_CLAIMED`](#member-gfsavesectionsnapshot-constants-state_claimed) | `const STATE_CLAIMED: StringName = &"claimed"` |
| 常量 | [`STATE_DISCARDED`](#member-gfsavesectionsnapshot-constants-state_discarded) | `const STATE_DISCARDED: StringName = &"discarded"` |
| 方法 | [`take_ownership`](#member-gfsavesectionsnapshot-methods-take_ownership) | `static func take_ownership( section_id: StringName, schema_version: int, payload: Variant, metadata: Dictionary = {} ) -> GFSaveSectionSnapshot:` |
| 方法 | [`get_section_id`](#member-gfsavesectionsnapshot-methods-get_section_id) | `func get_section_id() -> StringName:` |
| 方法 | [`get_schema_version`](#member-gfsavesectionsnapshot-methods-get_schema_version) | `func get_schema_version() -> int:` |
| 方法 | [`get_state`](#member-gfsavesectionsnapshot-methods-get_state) | `func get_state() -> StringName:` |
| 方法 | [`is_available`](#member-gfsavesectionsnapshot-methods-is_available) | `func is_available() -> bool:` |

## 常量

<a id="member-gfsavesectionsnapshot-constants-state_available"></a>

### `STATE_AVAILABLE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_AVAILABLE: StringName = &"available"
```

Snapshot 尚未被框架接管。

<a id="member-gfsavesectionsnapshot-constants-state_claimed"></a>

### `STATE_CLAIMED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_CLAIMED: StringName = &"claimed"
```

Snapshot 已被框架接管，载荷不再可用。

<a id="member-gfsavesectionsnapshot-constants-state_discarded"></a>

### `STATE_DISCARDED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_DISCARDED: StringName = &"discarded"
```

Snapshot 已被取消并释放载荷。

## 方法

<a id="member-gfsavesectionsnapshot-methods-take_ownership"></a>

### `take_ownership`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func take_ownership( section_id: StringName, schema_version: int, payload: Variant, metadata: Dictionary = {} ) -> GFSaveSectionSnapshot:
```

接管一个 section 的纯数据所有权。 该方法不会深复制 payload 或 metadata。成功返回后，调用方不得继续读取、修改 或向其它线程提交原 Dictionary、Array 及其嵌套别名。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 稳定 section ID。 |
| `schema_version` | 当前 section schema 版本。 |
| `payload` | 调用方移交的纯 Variant 载荷。 |
| `metadata` | 调用方移交的纯 Variant 元数据。 |

返回：可用 Snapshot；身份无效时返回 null。

结构：

- `payload`: Variant accepted by the Save persisted-value contract.
- `metadata`: Dictionary with provider-defined persisted metadata.

<a id="member-gfsavesectionsnapshot-methods-get_section_id"></a>

### `get_section_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_section_id() -> StringName:
```

获取稳定 section ID。

返回：section ID。

<a id="member-gfsavesectionsnapshot-methods-get_schema_version"></a>

### `get_schema_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_schema_version() -> int:
```

获取 section schema 版本。

返回：正整数 schema 版本。

<a id="member-gfsavesectionsnapshot-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_state() -> StringName:
```

获取当前所有权状态。

返回：`STATE_*` 常量之一。

<a id="member-gfsavesectionsnapshot-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_available() -> bool:
```

检查 Snapshot 是否仍可由框架接管。

返回：尚未接管或释放时返回 true。
