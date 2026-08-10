# GFCacheDiagnostics

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_cache_diagnostics.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

通用缓存命中、写入和失效统计。 用于给各类缓存、索引或预热池提供一致的诊断快照。它不持有缓存内容， 也不规定缓存淘汰策略，只记录可观测事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`cache_id`](#member-gfcachediagnostics-properties-cache_id) | `var cache_id: StringName = &""` |
| 方法 | [`record_hit`](#member-gfcachediagnostics-methods-record_hit) | `func record_hit(key: Variant = null) -> void:` |
| 方法 | [`record_miss`](#member-gfcachediagnostics-methods-record_miss) | `func record_miss(key: Variant = null) -> void:` |
| 方法 | [`record_write`](#member-gfcachediagnostics-methods-record_write) | `func record_write(key: Variant = null) -> void:` |
| 方法 | [`record_eviction`](#member-gfcachediagnostics-methods-record_eviction) | `func record_eviction(reason: StringName = &"evicted", key: Variant = null) -> void:` |
| 方法 | [`record_invalidation`](#member-gfcachediagnostics-methods-record_invalidation) | `func record_invalidation(reason: StringName = &"invalidated", key: Variant = null, amount: int = 1) -> void:` |
| 方法 | [`reset`](#member-gfcachediagnostics-methods-reset) | `func reset() -> void:` |
| 方法 | [`get_hit_ratio`](#member-gfcachediagnostics-methods-get_hit_ratio) | `func get_hit_ratio() -> float:` |
| 方法 | [`get_debug_snapshot`](#member-gfcachediagnostics-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfcachediagnostics-properties-cache_id"></a>

### `cache_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var cache_id: StringName = &""
```

诊断对象标识。

## 方法

<a id="member-gfcachediagnostics-methods-record_hit"></a>

### `record_hit`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func record_hit(key: Variant = null) -> void:
```

记录缓存命中。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 可选缓存 key。 |

结构：

- `key`: 任意缓存键；诊断快照会以字符串形式记录。

<a id="member-gfcachediagnostics-methods-record_miss"></a>

### `record_miss`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func record_miss(key: Variant = null) -> void:
```

记录缓存未命中。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 可选缓存 key。 |

结构：

- `key`: 任意缓存键；诊断快照会以字符串形式记录。

<a id="member-gfcachediagnostics-methods-record_write"></a>

### `record_write`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func record_write(key: Variant = null) -> void:
```

记录缓存写入。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 可选缓存 key。 |

结构：

- `key`: 任意缓存键；诊断快照会以字符串形式记录。

<a id="member-gfcachediagnostics-methods-record_eviction"></a>

### `record_eviction`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func record_eviction(reason: StringName = &"evicted", key: Variant = null) -> void:
```

记录缓存淘汰。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 淘汰原因。 |
| `key` | 可选缓存 key。 |

结构：

- `key`: 任意缓存键；诊断快照会以字符串形式记录。

<a id="member-gfcachediagnostics-methods-record_invalidation"></a>

### `record_invalidation`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func record_invalidation(reason: StringName = &"invalidated", key: Variant = null, amount: int = 1) -> void:
```

记录缓存失效。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失效原因。 |
| `key` | 可选缓存 key。 |
| `amount` | 失效数量。 |

结构：

- `key`: 任意缓存键；诊断快照会以字符串形式记录。

<a id="member-gfcachediagnostics-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func reset() -> void:
```

清空统计。

<a id="member-gfcachediagnostics-methods-get_hit_ratio"></a>

### `get_hit_ratio`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_hit_ratio() -> float:
```

获取命中率。

返回：命中率；没有读请求时返回 0.0。

<a id="member-gfcachediagnostics-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取诊断快照。

返回：诊断快照。

结构：

- `return`: Dictionary with cache_id, hit_count, miss_count, write_count, eviction_count, invalidation_count, hit_ratio, counter_saturated, invalidation_reasons, and last_event.
