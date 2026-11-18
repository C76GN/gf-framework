# GFDataVersion

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_data_version.gd`
- 模块：`Standard`
- 继承：`GFDataSnapshotSource`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`12.0.0`

框架记录序列的固定版本读取句柄。 公开读取返回独立记录快照；释放只退还本句柄，其他版本和读者继续有效。 记录位置属于本版本，不是业务实体 ID。直接 new 的句柄不可读取。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_get_record_count`](#member-gfdataversion-methods-_get_record_count) | `func _get_record_count() -> int:` |
| 方法 | [`_get_revision`](#member-gfdataversion-methods-_get_revision) | `func _get_revision() -> int:` |
| 方法 | [`_read_record`](#member-gfdataversion-methods-_read_record) | `func _read_record(index: int) -> GFDataSnapshot:` |
| 方法 | [`_release`](#member-gfdataversion-methods-_release) | `func _release() -> void:` |

## 方法

<a id="member-gfdataversion-methods-_get_record_count"></a>

### `_get_record_count`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _get_record_count() -> int:
```

返回已固定数量，不遍历版本树。

返回：固定记录数；未配置为 -1。

<a id="member-gfdataversion-methods-_get_revision"></a>

### `_get_revision`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _get_revision() -> int:
```

返回已固定版本，存储后续提交不修改它。

返回：固定版本号；未配置为 -1。

<a id="member-gfdataversion-methods-_read_record"></a>

### `_read_record`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _read_record(index: int) -> GFDataSnapshot:
```

导出独立记录，避免外部持有绕过 arena 的历史计费。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 已通过范围检查的位置。 |

返回：独立就绪记录；复制失败为 null。

<a id="member-gfdataversion-methods-_release"></a>

### `_release`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _release() -> void:
```

退还本句柄的根和输出预留；节点随后由存储显式回收。
