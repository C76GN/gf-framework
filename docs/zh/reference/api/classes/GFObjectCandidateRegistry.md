# GFObjectCandidateRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_object_candidate_registry.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

通用 Object 候选注册表。 使用弱引用记录候选对象，并提供按 group、method、priority 和注册顺序筛选排序的 候选快照。变更通知只报告记录已变化，不解释最佳候选等业务语义，适合交互、命中、 选择或编辑器工具复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`candidates_changed`](#member-gfobjectcandidateregistry-signals-candidates_changed) | `signal candidates_changed(revision: int)` |
| 属性 | [`max_candidates`](#member-gfobjectcandidateregistry-properties-max_candidates) | `var max_candidates: int = 0:` |
| 属性 | [`metadata`](#member-gfobjectcandidateregistry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`clear`](#member-gfobjectcandidateregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`register_candidate`](#member-gfobjectcandidateregistry-methods-register_candidate) | `func register_candidate(candidate: Object, options: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_candidate`](#member-gfobjectcandidateregistry-methods-unregister_candidate) | `func unregister_candidate(candidate: Object) -> bool:` |
| 方法 | [`unregister_candidate_id`](#member-gfobjectcandidateregistry-methods-unregister_candidate_id) | `func unregister_candidate_id(candidate_id: int) -> bool:` |
| 方法 | [`unregister_owner`](#member-gfobjectcandidateregistry-methods-unregister_owner) | `func unregister_owner(owner: Variant) -> int:` |
| 方法 | [`prune_invalid`](#member-gfobjectcandidateregistry-methods-prune_invalid) | `func prune_invalid() -> int:` |
| 方法 | [`get_candidates`](#member-gfobjectcandidateregistry-methods-get_candidates) | `func get_candidates(options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`get_candidate_objects`](#member-gfobjectcandidateregistry-methods-get_candidate_objects) | `func get_candidate_objects(options: Dictionary = {}) -> Array[Object]:` |
| 方法 | [`get_revision`](#member-gfobjectcandidateregistry-methods-get_revision) | `func get_revision() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfobjectcandidateregistry-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfobjectcandidateregistry-signals-candidates_changed"></a>

### `candidates_changed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal candidates_changed(revision: int)
```

候选记录发生变化时发出。一次公开操作无论改变多少条记录都只发出一次；无变化时不发出。

参数：

| 名称 | 说明 |
|---|---|
| `revision` | 变更后的单调递增版本号。 |

## 属性

<a id="member-gfobjectcandidateregistry-properties-max_candidates"></a>

### `max_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_candidates: int = 0:
```

最大候选记录数量；小于等于 0 时不限制。降低上限会立即按注册顺序淘汰最旧记录； 一次容量收敛只推进一次 revision 并发出一次 candidates_changed。

<a id="member-gfobjectcandidateregistry-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

注册表自定义元数据。

结构：

- `metadata`: Dictionary copied into debug snapshots.

## 方法

<a id="member-gfobjectcandidateregistry-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear() -> void:
```

清空全部候选。

<a id="member-gfobjectcandidateregistry-methods-register_candidate"></a>

### `register_candidate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_candidate(candidate: Object, options: Dictionary = {}) -> bool:
```

注册或更新一个候选对象。

参数：

| 名称 | 说明 |
|---|---|
| `candidate` | 候选对象。 |
| `options` | 注册选项。 |

返回：候选有效且注册请求被接受时返回 true；记录未变化时不会推进 revision 或发出通知。

结构：

- `options`: Dictionary with optional priority:int, group:StringName, owner:Object|int|String|StringName, stable_key:Variant, and metadata:Dictionary.

<a id="member-gfobjectcandidateregistry-methods-unregister_candidate"></a>

### `unregister_candidate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_candidate(candidate: Object) -> bool:
```

移除一个候选对象。

参数：

| 名称 | 说明 |
|---|---|
| `candidate` | 候选对象。 |

返回：找到并移除时返回 true。

<a id="member-gfobjectcandidateregistry-methods-unregister_candidate_id"></a>

### `unregister_candidate_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_candidate_id(candidate_id: int) -> bool:
```

按实例 ID 移除候选。

参数：

| 名称 | 说明 |
|---|---|
| `candidate_id` | 候选对象实例 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfobjectcandidateregistry-methods-unregister_owner"></a>

### `unregister_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_owner(owner: Variant) -> int:
```

移除指定 owner 关联的候选。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | Object、实例 ID 或文本 owner key。 |

返回：移除数量。

结构：

- `owner`: Object, int, String, or StringName owner identity.

<a id="member-gfobjectcandidateregistry-methods-prune_invalid"></a>

### `prune_invalid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prune_invalid() -> int:
```

清理已释放对象的候选记录。

返回：清理数量。

<a id="member-gfobjectcandidateregistry-methods-get_candidates"></a>

### `get_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_candidates(options: Dictionary = {}) -> Array[Dictionary]:
```

获取候选记录快照。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 查询选项。 |

返回：候选记录数组，按 priority 降序、注册顺序升序排列。

结构：

- `options`: Dictionary with optional group:StringName, method_name:StringName, include_metadata:bool, max_count:int, and prune_invalid:bool.
- `return`: Array[Dictionary] with id, object, priority, group, owner_id, stable_key, metadata, and order.

<a id="member-gfobjectcandidateregistry-methods-get_candidate_objects"></a>

### `get_candidate_objects`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_candidate_objects(options: Dictionary = {}) -> Array[Object]:
```

获取候选对象列表。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 查询选项，语义同 get_candidates()。 |

返回：候选对象数组。

结构：

- `options`: Dictionary with optional group:StringName, method_name:StringName, and max_count:int.
- `return`: Array[Object] from valid candidate snapshots.

<a id="member-gfobjectcandidateregistry-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_revision() -> int:
```

获取候选记录的当前版本号。

返回：从 0 开始、只在候选记录实际变化时递增的版本号。

<a id="member-gfobjectcandidateregistry-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：JSON-safe 调试快照。

结构：

- `return`: Dictionary with revision, count, valid_count, max_candidates, candidates, and metadata.
