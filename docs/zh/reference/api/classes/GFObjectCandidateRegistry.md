# GFObjectCandidateRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_object_candidate_registry.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

通用 Object 候选注册表。 使用弱引用记录候选对象，并提供按 group、method、priority 和注册顺序筛选排序的 候选快照。它不解释候选对象的业务语义，适合交互、命中、选择或编辑器工具复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
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
| 方法 | [`get_debug_snapshot`](#member-gfobjectcandidateregistry-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfobjectcandidateregistry-properties-max_candidates"></a>

### `max_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_candidates: int = 0:
```

最大候选记录数量；小于等于 0 时不限制。

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

返回：候选有效并成功写入时返回 true。

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

- `return`: Dictionary with count, valid_count, max_candidates, candidates, and metadata.
