# GFDeferredMutationQueue

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_deferred_mutation_queue.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

确定性延迟变更队列。 用于把运行时或工具流程中收集到的状态变更延迟到显式 playback 点执行。 队列只保存 Callable、排序信息和诊断 metadata，不解释调用方的实体、组件、 节点或资源语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_PHASE`](#member-gfdeferredmutationqueue-constants-default_phase) | `const DEFAULT_PHASE: StringName = &"default"` |
| 属性 | [`max_mutations_per_playback`](#member-gfdeferredmutationqueue-properties-max_mutations_per_playback) | `var max_mutations_per_playback: int = 0:` |
| 属性 | [`max_seconds_per_playback`](#member-gfdeferredmutationqueue-properties-max_seconds_per_playback) | `var max_seconds_per_playback: float = 0.0:` |
| 方法 | [`init`](#member-gfdeferredmutationqueue-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfdeferredmutationqueue-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`record`](#member-gfdeferredmutationqueue-methods-record) | `func record(mutation: Callable, options: Dictionary = {}) -> int:` |
| 方法 | [`record_owned`](#member-gfdeferredmutationqueue-methods-record_owned) | `func record_owned(owner: Object, mutation: Callable, options: Dictionary = {}) -> int:` |
| 方法 | [`playback`](#member-gfdeferredmutationqueue-methods-playback) | `func playback(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`preview`](#member-gfdeferredmutationqueue-methods-preview) | `func preview(options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`cancel`](#member-gfdeferredmutationqueue-methods-cancel) | `func cancel(handle: int) -> bool:` |
| 方法 | [`cancel_owner`](#member-gfdeferredmutationqueue-methods-cancel_owner) | `func cancel_owner(owner: Object) -> int:` |
| 方法 | [`clear`](#member-gfdeferredmutationqueue-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_pending_count`](#member-gfdeferredmutationqueue-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`is_empty`](#member-gfdeferredmutationqueue-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfdeferredmutationqueue-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfdeferredmutationqueue-constants-default_phase"></a>

### `DEFAULT_PHASE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_PHASE: StringName = &"default"
```

默认变更阶段。

## 属性

<a id="member-gfdeferredmutationqueue-properties-max_mutations_per_playback"></a>

### `max_mutations_per_playback`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_mutations_per_playback: int = 0:
```

playback() 默认每次最多应用多少条变更；小于等于 0 时不限制数量。

<a id="member-gfdeferredmutationqueue-properties-max_seconds_per_playback"></a>

### `max_seconds_per_playback`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_seconds_per_playback: float = 0.0:
```

playback() 默认最多占用多少秒；小于等于 0 时不启用时间预算。

## 方法

<a id="member-gfdeferredmutationqueue-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func init() -> void:
```

初始化队列并清空统计。

<a id="member-gfdeferredmutationqueue-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

清空队列。

<a id="member-gfdeferredmutationqueue-methods-record"></a>

### `record`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record(mutation: Callable, options: Dictionary = {}) -> int:
```

记录一条延迟变更。

参数：

| 名称 | 说明 |
|---|---|
| `mutation` | playback() 时执行的回调。 |
| `options` | 记录选项，支持 phase、sort_key、order、label、metadata 和 owner。 |

返回：变更句柄；mutation 无效时返回 0。

结构：

- `options`: Dictionary，可包含 phase: StringName、sort_key: int、order: int、label: String、metadata: Dictionary、owner: Object。

<a id="member-gfdeferredmutationqueue-methods-record_owned"></a>

### `record_owned`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_owned(owner: Object, mutation: Callable, options: Dictionary = {}) -> int:
```

记录一条绑定 owner 的延迟变更。owner 释放后变更会在 playback() 时跳过。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 变更拥有者。 |
| `mutation` | playback() 时执行的回调。 |
| `options` | 记录选项，支持 phase、sort_key、order、label 和 metadata。 |

返回：变更句柄；参数无效时返回 0。

结构：

- `options`: Dictionary，可包含 phase: StringName、sort_key: int、order: int、label: String、metadata: Dictionary。

<a id="member-gfdeferredmutationqueue-methods-playback"></a>

### `playback`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func playback(options: Dictionary = {}) -> Dictionary:
```

按 phase、sort_key、order 和记录句柄的稳定顺序应用延迟变更。

参数：

| 名称 | 说明 |
|---|---|
| `options` | playback 选项，支持 phase、max_count、max_seconds 和 include_records。 |

返回：应用报告。

结构：

- `options`: Dictionary，可包含 phase: StringName、max_count: int、max_seconds: float、include_records: bool。
- `return`: Dictionary，包含 applied_count、failed_count、skipped_owner_count、pending_count、budget_exhausted、phase 和可选 records。

<a id="member-gfdeferredmutationqueue-methods-preview"></a>

### `preview`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func preview(options: Dictionary = {}) -> Array[Dictionary]:
```

预览待应用变更，不执行回调。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 预览选项，支持 phase 和 limit。 |

返回：待应用变更快照数组。

结构：

- `options`: Dictionary，可包含 phase: StringName 和 limit: int。
- `return`: Array[Dictionary]，每个元素包含 handle、phase、sort_key、order、owner_id、label、metadata 和 recorded_msec。

<a id="member-gfdeferredmutationqueue-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(handle: int) -> bool:
```

取消一条尚未应用的变更。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | record() 返回的变更句柄。 |

返回：找到并取消时返回 true。

<a id="member-gfdeferredmutationqueue-methods-cancel_owner"></a>

### `cancel_owner`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel_owner(owner: Object) -> int:
```

取消指定 owner 绑定的全部待应用变更。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 变更拥有者。 |

返回：取消数量。

<a id="member-gfdeferredmutationqueue-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部待应用变更和统计。

<a id="member-gfdeferredmutationqueue-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_pending_count() -> int:
```

获取待应用变更数量。

返回：队列长度。

<a id="member-gfdeferredmutationqueue-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_empty() -> bool:
```

检查队列是否为空。

返回：队列为空时返回 true。

<a id="member-gfdeferredmutationqueue-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取队列调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 pending_count、phase_counts、recorded_count、applied_count、cancelled_count、failed_count 和 skipped_owner_count。
