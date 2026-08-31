# GFSaveProfileMutationRequest

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_mutation_request.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

mutate-and-persist 的一次性所有权请求。 请求在创建时原子接管每个 `GFSaveSectionMutation`，随后只允许协调器 claim 一次。调用方必须放弃传入的 Dictionary、Array 及其全部嵌套 alias；请求 不公开任何候选 payload getter，也不接受 Callable 或可执行 patch。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`take_ownership`](#member-gfsaveprofilemutationrequest-methods-take_ownership) | `static func take_ownership( mutations: Array[GFSaveSectionMutation], document_metadata: Dictionary = {}, context: Dictionary = {}, result_metadata: Dictionary = {} ) -> GFSaveProfileMutationRequest:` |
| 方法 | [`is_available`](#member-gfsaveprofilemutationrequest-methods-is_available) | `func is_available() -> bool:` |
| 方法 | [`is_claimed`](#member-gfsaveprofilemutationrequest-methods-is_claimed) | `func is_claimed() -> bool:` |
| 方法 | [`get_mutation_count`](#member-gfsaveprofilemutationrequest-methods-get_mutation_count) | `func get_mutation_count() -> int:` |
| 方法 | [`get_section_ids`](#member-gfsaveprofilemutationrequest-methods-get_section_ids) | `func get_section_ids() -> PackedStringArray:` |

## 方法

<a id="member-gfsaveprofilemutationrequest-methods-take_ownership"></a>

### `take_ownership`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
static func take_ownership( mutations: Array[GFSaveSectionMutation], document_metadata: Dictionary = {}, context: Dictionary = {}, result_metadata: Dictionary = {} ) -> GFSaveProfileMutationRequest:
```

创建请求并接管全部候选 section 与元数据。 Mutation 必须非空、可用且 section ID 唯一。方法会先完成全部预检，再按输入 顺序 claim，因而校验失败不会部分消费 Mutation。输入顺序只用于所有权收集； 协调器始终按已注册 Profile 的 Provider 顺序 capture/apply。成功返回后，调用方必须永久 放弃 mutations 数组、三个 Dictionary 及其全部嵌套 alias。

参数：

| 名称 | 说明 |
|---|---|
| `mutations` | 待接管的完整候选 sections；输入顺序不定义应用顺序。 |
| `document_metadata` | 写入候选文档的持久化元数据。 |
| `context` | Provider 操作使用的临时纯数据上下文。 |
| `result_metadata` | 只写入当前事务结果的调用方纯数据元数据。 |

返回：可用请求；输入无效时返回 null，且不消费任何 Mutation。

结构：

- `document_metadata`: Dictionary accepted by the Save persisted-value contract whose source aliases are abandoned after success.
- `context`: Bounded Dictionary without Callable, Signal, RID, Object, or circular references whose source aliases are abandoned after success.
- `result_metadata`: Bounded Dictionary without Callable, Signal, RID, Object, or circular references whose source aliases are abandoned after success.

<a id="member-gfsaveprofilemutationrequest-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_available() -> bool:
```

检查请求是否仍可由协调器接管。

返回：尚未 claim 时返回 true。

<a id="member-gfsaveprofilemutationrequest-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_claimed() -> bool:
```

检查请求是否已经被协调器接管。

返回：已成功 claim 时返回 true。

<a id="member-gfsaveprofilemutationrequest-methods-get_mutation_count"></a>

### `get_mutation_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_mutation_count() -> int:
```

获取候选 section 数量。

返回：尚未 claim 时返回候选数；claim 后为 0。

<a id="member-gfsaveprofilemutationrequest-methods-get_section_ids"></a>

### `get_section_ids`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_section_ids() -> PackedStringArray:
```

获取候选 section ID 的隔离快照。

返回：按请求收集顺序排列的 section ID；不包含候选载荷。
