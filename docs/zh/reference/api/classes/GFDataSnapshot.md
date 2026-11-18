# GFDataSnapshot

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_data_snapshot.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`12.0.0`

隔离纯数据后发布的只读快照。 捕获期间源数据必须稳定。共享子容器按值展开，循环、对象和对象类型容器被拒绝。 读取返回独立副本，后台任务可保留快照直到物理执行结束。 分帧捕获结果还持有源租约；源线程须保留最后引用，直到后台结束后在源线程释放。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`capture`](#member-gfdatasnapshot-methods-capture) | `static func capture(value: Variant, limits: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_ready`](#member-gfdatasnapshot-methods-is_ready) | `func is_ready() -> bool:` |
| 方法 | [`get_statistics`](#member-gfdatasnapshot-methods-get_statistics) | `func get_statistics() -> Dictionary:` |
| 方法 | [`copy_value`](#member-gfdatasnapshot-methods-copy_value) | `func copy_value(limits: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_value`](#member-gfdatasnapshot-methods-get_value) | `func get_value(path: Array = []) -> Variant:` |

## 方法

<a id="member-gfdatasnapshot-methods-capture"></a>

### `capture`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
static func capture(value: Variant, limits: Dictionary = {}) -> Dictionary:
```

完整捕获成功后发布快照，失败保留结构化诊断。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 调用期间保持稳定的纯数据。 |
| `limits` | 有限数据预算。 |

返回：快照或捕获失败的计量。

结构：

- `value`: Built-in Variant values and typed containers without objects, executable values, RID or cycles.
- `limits`: Dictionary with positive max_items (1000000), max_depth (64, at most 256), max_string_length (1048576), max_payload_bytes (67108864), max_elapsed_msec (30000), and optional cancel_token: GFCancellationToken. Payload counts logical scalar widths, UTF-8 strings and packed storage; nodes have a separate item budget.
- `return`: Dictionary with ok, snapshot: GFDataSnapshot or null, error_kind, error_path, limit_kind, limit, observed, counts_complete, items, packed_items, payload_bytes and maximum_depth. Failed counts describe only processed input.

<a id="member-gfdatasnapshot-methods-is_ready"></a>

### `is_ready`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func is_ready() -> bool:
```

返回快照是否已完成捕获。

返回：可以用于读取及任务提交时为 true。

<a id="member-gfdatasnapshot-methods-get_statistics"></a>

### `get_statistics`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_statistics() -> Dictionary:
```

返回成功捕获的计量副本。

返回：仅包含标量的捕获计量。

结构：

- `return`: Dictionary containing capture counters and status, without a mutable payload.

<a id="member-gfdatasnapshot-methods-copy_value"></a>

### `copy_value`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func copy_value(limits: Dictionary = {}) -> Dictionary:
```

显式导出可修改的工作树；各次导出彼此隔离。

参数：

| 名称 | 说明 |
|---|---|
| `limits` | 覆盖原捕获数值预算，可额外提供取消令牌。 |

返回：可变副本与结构化计量。

结构：

- `limits`: Dictionary with the same limits as capture.
- `return`: Dictionary with capture fields and value: Variant; on failure value is null.

<a id="member-gfdatasnapshot-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_value(path: Array = []) -> Variant:
```

读取指定字典键或数组索引路径，结果与快照隔离。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 根路径为空；数组项使用非负 int，字典项使用存在的键。 |

返回：指定值的副本，路径不存在或快照无效时返回 null。

结构：

- `path`: Array of Dictionary keys or nonnegative Array indices.
- `return`: Detached Variant value or null.
