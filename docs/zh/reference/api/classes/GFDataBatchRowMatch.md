# GFDataBatchRowMatch

[API Reference](../index.md) / [Data Batch](../extensions-data-batch.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/data_batch/runtime/gf_data_batch_row_match.gd`
- 模块：`Data Batch`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

保存按当前行顺序匹配得到的旧行号。 每次匹配只读取两列的有效前缀，结果由调用者独立持有。可用于对齐快照或比较修订。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`error`](#member-gfdatabatchrowmatch-properties-error) | `var error: Error = OK` |
| 属性 | [`previous_rows`](#member-gfdatabatchrowmatch-properties-previous_rows) | `var previous_rows: PackedInt32Array = PackedInt32Array()` |
| 方法 | [`match_ids`](#member-gfdatabatchrowmatch-methods-match_ids) | `static func match_ids( previous_ids: PackedInt64Array, previous_count: int, current_ids: PackedInt64Array, current_count: int ) -> GFDataBatchRowMatch:` |

## 属性

<a id="member-gfdatabatchrowmatch-properties-error"></a>

### `error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var error: Error = OK
```

OK 表示匹配完成，含合法空结果。有效行数越界返回 ERR_INVALID_PARAMETER， 任一列内有重复 ID 返回 ERR_INVALID_DATA，输出分配失败返回 ERR_OUT_OF_MEMORY。 原生服务违反返回协议时为 FAILED。失败时行号数组为空。

<a id="member-gfdatabatchrowmatch-properties-previous_rows"></a>

### `previous_rows`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var previous_rows: PackedInt32Array = PackedInt32Array()
```

每个当前 ID 对应的旧行号。新出现的 ID 对应 -1，调用者可独立修改该数组。

## 方法

<a id="member-gfdatabatchrowmatch-methods-match_ids"></a>

### `match_ids`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func match_ids( previous_ids: PackedInt64Array, previous_count: int, current_ids: PackedInt64Array, current_count: int ) -> GFDataBatchRowMatch:
```

按精确的有符号 64 位 ID 同步匹配两列。两侧的有效 ID 各自唯一，允许任意行序和负 ID。 输入在调用期间只读。主线程可自动选用已安装的原生能力，其他情况使用 GDScript。

参数：

| 名称 | 说明 |
|---|---|
| `previous_ids` | 上一批的身份列。 |
| `previous_count` | 上一批的有效行数，范围为零至列长且可由有符号 32 位整数表示。 |
| `current_ids` | 当前批次的身份列，与上一批使用同一身份空间。 |
| `current_count` | 当前批次的有效行数，范围为零至列长且可由有符号 32 位整数表示。 |

返回：独立结果。成功时 previous_rows 长度为 current_count，失败时由 error 给出原因。
