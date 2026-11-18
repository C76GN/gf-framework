# GFDataBatchBackend

[API Reference](../index.md) / [Data Batch](../extensions-data-batch.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/data_batch/runtime/gf_data_batch_backend.gd`
- 模块：`Data Batch`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

可选同步 PackedArray gather 协议。 后端只计算列，不拥有 GF 的 schema、版本或发布权。输入在调用期间只读且不得保留； 输出必须独立拥有，类型、顺序和整数值精确保持。返回空数组表示失败，不允许部分结果。 这是同进程可信代码边界，不是 native sandbox；首版仅在主线程调用，不启动后台任务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_protocol_version`](#member-gfdatabatchbackend-methods-get_protocol_version) | `func get_protocol_version() -> int:` |
| 方法 | [`supports_type`](#member-gfdatabatchbackend-methods-supports_type) | `func supports_type(_numeric_type: int) -> bool:` |
| 方法 | [`get_scratch_bytes`](#member-gfdatabatchbackend-methods-get_scratch_bytes) | `func get_scratch_bytes(_output_bytes: int) -> int:` |
| 方法 | [`gather`](#member-gfdatabatchbackend-methods-gather) | `func gather( _columns: Array, _indices: PackedInt32Array, _source_count: int ) -> Array:` |

## 方法

<a id="member-gfdatabatchbackend-methods-get_protocol_version"></a>

### `get_protocol_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_protocol_version() -> int:
```

返回协议版本；发布者只接受版本 1，构造后不再切换后端。

返回：已实现协议版本；默认零表示不可用。

<a id="member-gfdatabatchbackend-methods-supports_type"></a>

### `supports_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func supports_type(_numeric_type: int) -> bool:
```

判断固定数值类型是否支持，禁止隐式数值转换。

参数：

| 名称 | 说明 |
|---|---|
| `_numeric_type` | GFDataBatchSchema.NumericType 值。 |

返回：能精确执行 gather 时为 true。

<a id="member-gfdatabatchbackend-methods-get_scratch_bytes"></a>

### `get_scratch_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_scratch_bytes(_output_bytes: int) -> int:
```

提供额外临时 payload 的保守上界，GF 在调用前计入峰值预算。

参数：

| 名称 | 说明 |
|---|---|
| `_output_bytes` | 已由 GF 计算的全部输出列 payload。 |

返回：非负额外字节数；负值表示拒绝。零表示没有额外 payload 缓冲。

<a id="member-gfdatabatchbackend-methods-gather"></a>

### `gather`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func gather( _columns: Array, _indices: PackedInt32Array, _source_count: int ) -> Array:
```

批量选择记录，禁止更改输入、回调项目或重入发布；失败不得返回部分列。

参数：

| 名称 | 说明 |
|---|---|
| `_columns` | GF 已验证的有序只读列，后端仍负责原生内存访问边界。 |
| `_indices` | 已验证的零起始选择位置，保留顺序和重复项。 |
| `_source_count` | 有效前缀长度，不能使用 capacity 尾部。 |

返回：完整独立输出列，长度均等于 indices.size；失败为空。

结构：

- `_columns`: Array containing only PackedInt32Array or PackedInt64Array, ordered by the publication schema.
- `return`: Array of PackedInt32Array or PackedInt64Array matching input types and column order, or empty on failure. Caller takes exclusive ownership; backend retains no output aliases.
