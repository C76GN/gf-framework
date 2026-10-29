# Data Batch 类型化数值批次

Data Batch 用固定布局的数值列在生产者与消费者之间发布一批数据。它适合已经按列组织数据、需要集中验证与稳定读取边界的场景，例如把模拟结果交给绘制或分析代码。每列使用 `PackedInt32Array` 或 `PackedInt64Array`，逐行读取使用预先绑定的列索引。

完整 GF Framework 已包含 `gf.data_batch`，扩展默认关闭。使用前在 `GF Workspace` 的 `GF Extensions` 页面本地启用。它由三个 `RefCounted` 类构成，没有 Installer 或自动注册的服务；项目自行持有发布者。它不依赖其他扩展，也不创建 ECS 或全局 World。

## 布局、发布者和快照

| 对象 | 负责的契约 |
| --- | --- |
| `GFDataBatchSchema` | 固定 Schema 标识、版本、列名、列类型和稳定索引。 |
| `GFDataBatchPublication` | 验证候选批次、执行预算检查、一次性替换当前快照并递增发布序号。 |
| `GFDataBatchSnapshot` | 保存本次发布的元数据和列，供消费者复制或按只读约定借用。 |

Schema 通过 `create()` 校验并复制输入定义，创建失败返回 `null`。布局版本必须为正数，列名非空且不重复，列数介于 1 和 `MAX_COLUMNS`（256）之间。`NumericType.INT32` 与 `INT64` 分别要求对应的 Packed 数组；边界不隐式转换数值。字段含义、单位、实体身份和版本迁移由项目定义。

消费者初始化时调用 `find_column()` 并检查 `get_column_type()`，随后保留索引。索引只对该 Schema 有效；布局变化时创建新 Schema，并重新绑定消费者。

## 从复制发布开始

以下例子用两列表示项目自己的编号与偏移量。每行载荷为 12 字节，发布者最多接受 8 行，192 字节的载荷预算可同时容纳两份容量为 8 的批次。

```gdscript
func make_publication() -> GFDataBatchPublication:
	var names: Array[StringName] = [&"item_id", &"offset"]
	var types := PackedInt32Array([
		GFDataBatchSchema.NumericType.INT64,
		GFDataBatchSchema.NumericType.INT32,
	])
	var schema := GFDataBatchSchema.create(&"item_offsets", 1, names, types)
	if schema == null:
		return null
	var publication := GFDataBatchPublication.create(schema, &"preview", 1, 8, 192)
	if publication == null:
		return null
	var columns: Dictionary = {
		&"item_id": PackedInt64Array([101, 102, 0]),
		&"offset": PackedInt32Array([4, 9, 0]),
	}
	var result: Error = publication.publish_copy(columns, 2, 3, 1, 1)
	if result != OK:
		publication.close()
		return null
	return publication
```

`count` 是有效前缀长度，`capacity` 是每列数组的完整长度。例子只有前两行有效，第三个元素只是容量尾部，不能当作业务数据。发布边界要求列字典恰好包含 Schema 声明的列名，键可为 `StringName` 或等值 `String`；所有列类型匹配、长度一致，且满足 `0 <= count <= capacity`。`count` 与 `capacity` 都为零时可发布空批次，但仍须提供全部声明的空列。

```gdscript
func sum_offsets(publication: GFDataBatchPublication) -> int:
	var snapshot: GFDataBatchSnapshot = publication.get_current()
	if snapshot == null:
		return 0
	var schema: GFDataBatchSchema = snapshot.get_schema()
	var offset_index: int = schema.find_column(&"offset")
	if schema.get_column_type(offset_index) != GFDataBatchSchema.NumericType.INT32:
		return 0
	var offsets: PackedInt32Array = snapshot.borrow_int32_column(offset_index)
	var total: int = 0
	for row: int in range(snapshot.get_count()):
		total += offsets[row]
	return total
```

此处为展示完整检查而在读取函数中绑定索引；持续运行的消费者应在绑定 Schema 时完成一次查找。需要修改列时，改用 `copy_int32_column()` 或 `copy_int64_column()`；它们复制完整容量，修改副本不会改变快照。索引或类型不匹配返回空数组，因此先验证绑定，不能用空数组判断批次是否有效。

## 三种发布路径

| 入口 | 输入与成功后的所有权 |
| --- | --- |
| `publish_copy()` | 复制各列的完整容量。生产者可以继续修改原输入。 |
| `publish_transfer()` | 接收列的合作所有权，并清空传入的可写字典。调用者必须停止使用全部 Packed 数组别名。 |
| `publish_gather_copy()` | 按行索引采集并复制选中的行，保留索引顺序；只为选中行分配输出列。 |

复制和转交都先验证整批形状、类型、版本与预算。拒绝不会消费转交输入，不会替换已有当前快照，也不会推进成功发布序号。转交不能接收只读字典。发布返回 `Error`；失败时用 `get_last_failure()` 读取结构化原因，例如列不匹配、版本无效或预算不足。预算通过后仍可能发生数组分配失败；框架检测到这类失败时返回 `ERR_OUT_OF_MEMORY`，结构化原因为 `ALLOCATION_FAILED`，保留原发布，不提交部分列。

`publish_transfer()` 是调用双方的所有权约定，Godot 不提供这里所需的原生 move 保证。清空字典不会让其他变量保存的 Packed 数组别名自动失效。只有能够保证所有别名退休时才能转交；做不到时使用复制发布。

`borrow_*_column()` 同样是合作只读入口。返回的 Packed 数组没有强制只读保护，修改它会破坏快照与其他消费者的约定。不要把借用结果交给可能写入的 API；无法控制消费者时给它独立副本。

采集发布的源列仍须完整匹配 Schema 与声明的源容量，`PackedInt32Array` 中的每个行索引必须落在源 `count` 的有效范围内。输出保留索引顺序及重复项，输出 `count` 和 `capacity` 都等于索引数量。行索引只在本次同步调用内解释，不能作为跨批次身份；选择哪些行、如何排序以及如何更新业务身份由项目负责。

## 身份、版本和保留历史

创建发布者时明确提供 `producer_id` 与正数 `generation`。项目重建同一生产者时应使用新代次。每次成功发布获得新的 `publication_sequence`；同一帧内多次发布也各有独立序号，发布身份不依赖帧号或 tick。

`structural_revision` 表示项目声明的行身份、顺序或布局变化，`value_revision` 表示数值变化。两者必须非负，后续发布都不能倒退，且每次至少推进其中一个；`count` 或 `capacity` 改变时必须推进结构版本。即使形状不变，行身份或顺序改变时项目也必须主动推进结构版本，GF 不扫描内容来推断这类业务变化。

消费者可用版本信息维护自己的缓存，并在接收延后完成的工作时用原发布者的 `is_current(snapshot)` 检查该快照是否仍是当前结果。此检查比较精确快照对象身份；两个独立发布者即使使用相同的标识、代次与序号，也不会被当作同一当前发布。

下一次发布不会修改上一份快照。消费者可以跨帧保留旧快照；调用 `close()` 后发布者不再接受新批次并释放当前引用，但外部持有的快照仍可读取。历史长度、淘汰时机和消费者的副本由项目控制。该接口不含自动历史、池或 Lease，也不提供线程同步；调用方应串行访问发布者，并自行安排跨线程交接。

## 预算的覆盖范围

`max_rows` 是 1 至 2147483647 的有限上限，约束源容量及采集输出行数；只选择少数行也不能绕过源容量上限。`max_owned_bytes` 是正数，限制当前批次与待发布候选同时存活时的 Packed 数组载荷。单批载荷为 `capacity * schema.get_bytes_per_row()`；发布新批次前必须为旧当前批次和新候选留出空间。复制路径不会先进行大数组复制再发现预算不足。

此预算不代表进程总内存限制。它不包含对象与容器头、调用者保留的源数组、已经退出当前位置的历史快照，以及消费者创建的副本。项目仍须限制这些外部引用的数量。采集复制按选中行数计算候选载荷，源数据由调用方持有。

`get_debug_snapshot()` 返回独立的小型诊断字典，包含当前载荷，以及最近成功发布的峰值、复制和转交字节。`last_required_payload_bytes` 记录最近进入字节预算检查的尝试所需载荷；形状、索引或版本等更早阶段的拒绝会保留前值，不能将它与本次拒绝原因直接配对。诊断不追踪外部历史引用，不能用这些数值替代进程内存测量。

## API Reference

完整方法、拒绝条件与返回值见 [Data Batch API Reference](../../reference/api/extensions-data-batch.md)。
