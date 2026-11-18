# GFDataSnapshotSource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_data_snapshot_source.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`12.0.0`

一个已经固定版本的记录序列读取租约。 每个实例独占一次读取租约；交给捕获会话后由会话或成功快照释放。 项目适配器负责保持版本稳定，逐条返回已就绪的 GFDataSnapshot。 单条读取必须有界；本协议不提供线程同步，也不验证项目底层存储的不可变性。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_available`](#member-gfdatasnapshotsource-methods-is_available) | `func is_available() -> bool:` |
| 方法 | [`get_record_count`](#member-gfdatasnapshotsource-methods-get_record_count) | `func get_record_count() -> int:` |
| 方法 | [`get_revision`](#member-gfdatasnapshotsource-methods-get_revision) | `func get_revision() -> int:` |
| 方法 | [`read_record`](#member-gfdatasnapshotsource-methods-read_record) | `func read_record(index: int) -> GFDataSnapshot:` |
| 方法 | [`release`](#member-gfdatasnapshotsource-methods-release) | `func release() -> void:` |
| 方法 | [`_get_record_count`](#member-gfdatasnapshotsource-methods-_get_record_count) | `func _get_record_count() -> int:` |
| 方法 | [`_get_revision`](#member-gfdatasnapshotsource-methods-_get_revision) | `func _get_revision() -> int:` |
| 方法 | [`_read_record`](#member-gfdatasnapshotsource-methods-_read_record) | `func _read_record(_index: int) -> GFDataSnapshot:` |
| 方法 | [`_release`](#member-gfdatasnapshotsource-methods-_release) | `func _release() -> void:` |

## 方法

<a id="member-gfdatasnapshotsource-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func is_available() -> bool:
```

返回租约是否仍可读取。

返回：已释放时为 false。

<a id="member-gfdatasnapshotsource-methods-get_record_count"></a>

### `get_record_count`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_record_count() -> int:
```

返回固定版本的记录数量；不允许遍历或复制整个源。

返回：非负数量；不可用或未实现时为 -1。

<a id="member-gfdatasnapshotsource-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_revision() -> int:
```

返回本租约固定的版本号，不是跨存储的一致性凭证。

返回：非负版本号；不可用或未实现时为 -1。

<a id="member-gfdatasnapshotsource-methods-read_record"></a>

### `read_record`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func read_record(index: int) -> GFDataSnapshot:
```

取得一条独立只读快照。返回后源释放不能使该快照失效。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 零起始记录位置，必须小于固定记录数。 |

返回：已就绪记录快照；失败为 null。

<a id="member-gfdatasnapshotsource-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func release() -> void:
```

幂等释放此租约，不得撤销其他读者的版本。

<a id="member-gfdatasnapshotsource-methods-_get_record_count"></a>

### `_get_record_count`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _get_record_count() -> int:
```

以常数元信息查询返回稳定记录数，不得读取可变 live 数据。

返回：非负记录数；默认未实现为 -1。

<a id="member-gfdatasnapshotsource-methods-_get_revision"></a>

### `_get_revision`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _get_revision() -> int:
```

返回租约创建时固定的版本号，读取期间不得改变。

返回：非负版本号；默认未实现为 -1。

<a id="member-gfdatasnapshotsource-methods-_read_record"></a>

### `_read_record`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _read_record(_index: int) -> GFDataSnapshot:
```

在有界成本内读取固定版本记录；不得产生业务写入或重入捕获。

参数：

| 名称 | 说明 |
|---|---|
| `_index` | 已由公共入口检查的非负位置。 |

返回：独立就绪快照；失败返回 null。

<a id="member-gfdatasnapshotsource-methods-_release"></a>

### `_release`

- API：`protected`
- 首次版本：`12.0.0`

```gdscript
func _release() -> void:
```

结算项目版本持有；不得使已经返回的独立记录快照失效。
