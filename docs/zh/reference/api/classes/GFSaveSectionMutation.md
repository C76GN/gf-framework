# GFSaveSectionMutation

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_section_mutation.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

单个 Save section 的一次性候选替换句柄。 Mutation 只描述完整候选 section，不接受可执行 Callable 或增量 patch。 `take_ownership()` 成功后，调用方必须永久放弃 payload、metadata 及其全部 嵌套集合 alias；框架 claim 后句柄会立即清空载荷。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATE_AVAILABLE`](#member-gfsavesectionmutation-constants-state_available) | `const STATE_AVAILABLE: StringName = &"available"` |
| 常量 | [`STATE_CLAIMED`](#member-gfsavesectionmutation-constants-state_claimed) | `const STATE_CLAIMED: StringName = &"claimed"` |
| 常量 | [`STATE_DISCARDED`](#member-gfsavesectionmutation-constants-state_discarded) | `const STATE_DISCARDED: StringName = &"discarded"` |
| 方法 | [`take_ownership`](#member-gfsavesectionmutation-methods-take_ownership) | `static func take_ownership( section_id: StringName, schema_version: int, payload: Variant, metadata: Dictionary = {} ) -> GFSaveSectionMutation:` |
| 方法 | [`get_section_id`](#member-gfsavesectionmutation-methods-get_section_id) | `func get_section_id() -> StringName:` |
| 方法 | [`get_schema_version`](#member-gfsavesectionmutation-methods-get_schema_version) | `func get_schema_version() -> int:` |
| 方法 | [`get_state`](#member-gfsavesectionmutation-methods-get_state) | `func get_state() -> StringName:` |
| 方法 | [`is_available`](#member-gfsavesectionmutation-methods-is_available) | `func is_available() -> bool:` |

## 常量

<a id="member-gfsavesectionmutation-constants-state_available"></a>

### `STATE_AVAILABLE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_AVAILABLE: StringName = &"available"
```

Mutation 尚未被框架接管。

<a id="member-gfsavesectionmutation-constants-state_claimed"></a>

### `STATE_CLAIMED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_CLAIMED: StringName = &"claimed"
```

Mutation 已被框架接管，候选载荷不再可用。

<a id="member-gfsavesectionmutation-constants-state_discarded"></a>

### `STATE_DISCARDED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_DISCARDED: StringName = &"discarded"
```

Mutation 已被框架丢弃，候选载荷不再可用。

## 方法

<a id="member-gfsavesectionmutation-methods-take_ownership"></a>

### `take_ownership`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
static func take_ownership( section_id: StringName, schema_version: int, payload: Variant, metadata: Dictionary = {} ) -> GFSaveSectionMutation:
```

接管一个完整候选 section 的逻辑唯一所有权。 该方法不会深复制 payload 或 metadata。成功返回后，调用方不得继续读取、 修改或复用原集合及其嵌套 alias。输入必须满足 Save persisted-value 契约； Callable、Object、Signal、RID、循环集合和非有限数会被拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 稳定 section ID。 |
| `schema_version` | 候选 section 的正整数 schema 版本。 |
| `payload` | 完整候选 section 载荷，不是 patch 或回调。 |
| `metadata` | 候选 section 持久化元数据。 |

返回：可用 Mutation；身份或候选数据无效时返回 null。

结构：

- `payload`: Variant accepted by the Save persisted-value contract.
- `metadata`: Dictionary accepted by the Save persisted-value contract.

<a id="member-gfsavesectionmutation-methods-get_section_id"></a>

### `get_section_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_section_id() -> StringName:
```

获取稳定 section ID。

返回：section ID。

<a id="member-gfsavesectionmutation-methods-get_schema_version"></a>

### `get_schema_version`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_schema_version() -> int:
```

获取候选 section schema 版本。

返回：正整数 schema 版本；无效句柄为 0。

<a id="member-gfsavesectionmutation-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_state() -> StringName:
```

获取当前所有权状态。

返回：`STATE_*` 常量之一。

<a id="member-gfsavesectionmutation-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_available() -> bool:
```

检查 Mutation 是否仍可被请求或框架接管。

返回：尚未 claim 或 discard 时返回 true。
