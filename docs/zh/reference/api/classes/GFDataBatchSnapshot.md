# GFDataBatchSnapshot

[API Reference](../index.md) / [Data Batch](../extensions-data-batch.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/data_batch/runtime/gf_data_batch_snapshot.gd`
- 模块：`Data Batch`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

固定元数据和数值列的独立发布快照。 发布者替换或关闭后仍可读取。copy 方法提供修改隔离；borrow 方法返回共享 PackedArray，只能按合作约定读取。Godot 不提供此类数组的强制只读或 move 保证。 count 是有效前缀长度，capacity 是列数组长度，容量尾部不属于有效数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_schema`](#member-gfdatabatchsnapshot-methods-get_schema) | `func get_schema() -> GFDataBatchSchema:` |
| 方法 | [`get_producer_id`](#member-gfdatabatchsnapshot-methods-get_producer_id) | `func get_producer_id() -> StringName:` |
| 方法 | [`get_producer_generation`](#member-gfdatabatchsnapshot-methods-get_producer_generation) | `func get_producer_generation() -> int:` |
| 方法 | [`get_publication_sequence`](#member-gfdatabatchsnapshot-methods-get_publication_sequence) | `func get_publication_sequence() -> int:` |
| 方法 | [`get_structural_revision`](#member-gfdatabatchsnapshot-methods-get_structural_revision) | `func get_structural_revision() -> int:` |
| 方法 | [`get_value_revision`](#member-gfdatabatchsnapshot-methods-get_value_revision) | `func get_value_revision() -> int:` |
| 方法 | [`get_count`](#member-gfdatabatchsnapshot-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`get_capacity`](#member-gfdatabatchsnapshot-methods-get_capacity) | `func get_capacity() -> int:` |
| 方法 | [`get_payload_bytes`](#member-gfdatabatchsnapshot-methods-get_payload_bytes) | `func get_payload_bytes() -> int:` |
| 方法 | [`copy_int32_column`](#member-gfdatabatchsnapshot-methods-copy_int32_column) | `func copy_int32_column(column_index: int) -> PackedInt32Array:` |
| 方法 | [`copy_int64_column`](#member-gfdatabatchsnapshot-methods-copy_int64_column) | `func copy_int64_column(column_index: int) -> PackedInt64Array:` |
| 方法 | [`borrow_int32_column`](#member-gfdatabatchsnapshot-methods-borrow_int32_column) | `func borrow_int32_column(column_index: int) -> PackedInt32Array:` |
| 方法 | [`borrow_int64_column`](#member-gfdatabatchsnapshot-methods-borrow_int64_column) | `func borrow_int64_column(column_index: int) -> PackedInt64Array:` |

## 方法

<a id="member-gfdatabatchsnapshot-methods-get_schema"></a>

### `get_schema`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_schema() -> GFDataBatchSchema:
```

返回构造此批次时使用的固定 schema。

返回：schema；直接 new 的未发布对象为 null。

<a id="member-gfdatabatchsnapshot-methods-get_producer_id"></a>

### `get_producer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_producer_id() -> StringName:
```

返回项目生产者标识。

返回：固定的生产者标识。

<a id="member-gfdatabatchsnapshot-methods-get_producer_generation"></a>

### `get_producer_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_producer_generation() -> int:
```

返回生产者生命期代次。

返回：固定的正代次。

<a id="member-gfdatabatchsnapshot-methods-get_publication_sequence"></a>

### `get_publication_sequence`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_publication_sequence() -> int:
```

返回此发布者内单调递增的成功发布序号。

返回：正发布序号；不代表此快照仍是当前发布。

<a id="member-gfdatabatchsnapshot-methods-get_structural_revision"></a>

### `get_structural_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_structural_revision() -> int:
```

返回项目声明的结构版本。

返回：行身份、顺序和布局的版本。

<a id="member-gfdatabatchsnapshot-methods-get_value_revision"></a>

### `get_value_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_value_revision() -> int:
```

返回项目声明的数值版本。

返回：数值版本，不依赖帧或 tick。

<a id="member-gfdatabatchsnapshot-methods-get_count"></a>

### `get_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_count() -> int:
```

返回有效数据前缀行数。

返回：不超过 capacity 的行数。

<a id="member-gfdatabatchsnapshot-methods-get_capacity"></a>

### `get_capacity`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_capacity() -> int:
```

返回每列数组的长度，可能大于有效行数。

返回：列容量。

<a id="member-gfdatabatchsnapshot-methods-get_payload_bytes"></a>

### `get_payload_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_payload_bytes() -> int:
```

返回本批列 payload 字节；不包含元数据、容器头和外部副本。

返回：capacity 乘以 schema 每行字节数。

<a id="member-gfdatabatchsnapshot-methods-copy_int32_column"></a>

### `copy_int32_column`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func copy_int32_column(column_index: int) -> PackedInt32Array:
```

复制指定 Int32 列的完整容量，调用者修改副本不会改变快照。

参数：

| 名称 | 说明 |
|---|---|
| `column_index` | 初始化时绑定的 Int32 列索引。 |

返回：独立 PackedInt32Array；索引或类型不匹配返回空数组。

<a id="member-gfdatabatchsnapshot-methods-copy_int64_column"></a>

### `copy_int64_column`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func copy_int64_column(column_index: int) -> PackedInt64Array:
```

复制指定 Int64 列的完整容量，调用者修改副本不会改变快照。

参数：

| 名称 | 说明 |
|---|---|
| `column_index` | 初始化时绑定的 Int64 列索引。 |

返回：独立 PackedInt64Array；索引或类型不匹配返回空数组。

<a id="member-gfdatabatchsnapshot-methods-borrow_int32_column"></a>

### `borrow_int32_column`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func borrow_int32_column(column_index: int) -> PackedInt32Array:
```

借用 Int32 列，调用者必须保持只读；修改会破坏所有共享者的快照契约。

参数：

| 名称 | 说明 |
|---|---|
| `column_index` | 初始化时绑定的 Int32 列索引。 |

返回：共享 PackedInt32Array；索引或类型不匹配返回空数组。

<a id="member-gfdatabatchsnapshot-methods-borrow_int64_column"></a>

### `borrow_int64_column`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func borrow_int64_column(column_index: int) -> PackedInt64Array:
```

借用 Int64 列，调用者必须保持只读；修改会破坏所有共享者的快照契约。

参数：

| 名称 | 说明 |
|---|---|
| `column_index` | 初始化时绑定的 Int64 列索引。 |

返回：共享 PackedInt64Array；索引或类型不匹配返回空数组。
