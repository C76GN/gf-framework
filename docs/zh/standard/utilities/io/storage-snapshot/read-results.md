# 读取结果与副本隔离

`GFStorageReadResult` 分离 `payload`、框架 `metadata`、`integrity_status`、Godot `error_code`、物理文档版本、数据迁移前后版本和 `migrated`。

`failure_kind` 区分非法请求、不存在、普通 IO、损坏、未来格式、迁移失败、预算超限和服务不可用。上层恢复政策应根据该分类决定，不能仅凭同一个 `Error` 码把未来格式、迁移失败或 `LIMIT_EXCEEDED` 当成损坏。异步读取完成信号同样传递这个结果；`last_load_result` 只用于诊断最近一次读取，不应替代当前调用返回值。

## 读写预算与失败恢复

字典读取默认采用两级有限字节预算：`storage.max_read_bytes` 在分配文件读取 buffer 前检查物理文件长度，`storage.codec.max_decode_bytes` 限制解混淆、解压后交给 JSON/Binary 解析器的明文。两者默认都是 64 MiB，只接受正整数；配置属性的无效赋值会报告错误并保留原值，`decode()` 的无效预算选项会返回 `INVALID_REQUEST`，没有 `0` 表示无限的旁路。物理预算包含 Base64 混淆开销，所以两个字节数可能不同。同步、普通异步和 owned 异步读取共用这些门禁；异步请求入队时捕获预算，随后调整设置不会改变已提交请求。

需要读写更大的受控文件时，明确调整两级预算，例如 `storage.max_read_bytes = 128 * 1024 * 1024` 和 `storage.codec.max_decode_bytes = 128 * 1024 * 1024`。原 `max_decompressed_bytes` 配置已移除，统一改用 `max_decode_bytes`；旧的同名 codec 选项被拒绝，不保留别名。压缩输出也直接受这个统一明文预算限制。`deserialize_dictionary()` 同样使用 codec 的明文预算，失败仍按它的既有返回约定得到空字典。

字典保存同样遵守本次请求的两级预算：完整文档明文包含 envelope、metadata 和 checksum，在压缩前检查；最终文件字节包含混淆及 Base64 膨胀。`GFStorageCodec.encode_result()` 返回闭合的 `{ok, error, bytes}`，失败不交付部分 bytes；`encode()` 仍返回 bytes，失败为空。同步 Utility 保存调用 `encode_result()`；自定义 codec 原先若仅覆盖 `encode()`，须迁移到结构化入口并遵守完整明文预算和失败空 bytes 契约。Utility 检查最终文件长度，超限使用 `ERR_OUT_OF_MEMORY`，异步保存终态为 `GFStorageAsyncResult.WriteFailureKind.LIMIT_EXCEEDED`。异步入队的 `OK` 只表示接纳请求，必须检查物理完成结果。

同步保存和组保存先准备本次全部字节，再开始新保存事务；任一成员超限不会替换本次组的旧值。自定义 codec 编码期间若重入提交了目标文件的异步请求，同步保存重新检查占用并返回 `ERR_BUSY`。异步使用入队配置快照，在 worker 中编码并检查后才创建本次新保存记录；既有已授权事务的恢复仍可能先完成。准入后的同一份 bytes 直接进入写入，避免重新编码产生时间戳或 checksum 差异。保存成功只说明本次文件符合捕获的字节预算，之后调低预算、改变 codec 设置或业务迁移仍可导致读取失败。组保存保留准备字节，单文件预算不表示组总堆内存上限。

JSON 恢复还使用 `GFVariantJsonCodec` 的默认遍历预算：深度 64、节点 16,384、累计集合元素 65,536，超限拒绝整个文档。字节或遍历预算失败返回 `GFStorageReadResult.FailureKind.LIMIT_EXCEEDED`，没有部分 payload，也不发出 `data_integrity_failed` 或提供 family reset 授权。Godot 的解压接口不能区分损坏流与输出预算耗尽，因此解压失败也保守归入这一分类；调用方可以提示调整预算或检查文件，但不能据此认定损坏并清除文件。明确的格式、类型标记或完整性错误仍返回 `CORRUPT`。

这些预算限制读取与解析输入，不保证已解码 Variant 的堆内存峰值、解析耗时或迁移回调成本。JSON parser 和 `bytes_to_var()` 仍整体分配；ResourceLoader 与内部 ownership、revision、事务记录使用各自边界，不属于业务 payload 字节预算。owned 交付的纯值类型和累计数据预算也继续独立生效，调大明文上限不会扩大其交付资格。

## 保留一次结果副本

读取结果的 `duplicate_result()`、字典导出/导入，以及普通 `GFStorageAsyncOperation` 的结果 getter 都保持副本隔离。修改取得的嵌套 payload 或 metadata 容器，不会改写句柄保存的终态。

需要反复访问大型读取结果时，先保存一次 `get_read_result()` 的返回值，再读取其中各字段，避免反复取得整份副本。以下代码在操作已物理完成后执行（`operation.is_completed()` 为 `true`）；caller 超时或取消不代表物理完成：

```gdscript
var physical_result := operation.get_result()
var read_result := physical_result.get_read_result()
if read_result != null and read_result.ok:
	_apply_payload(read_result.payload)
	_show_metadata(read_result.metadata)
```

## 完成信号的参数

同一次完成信号的参数会广播给该次所有监听者。需要自行修改 legacy `load_completed` 参数的监听者，应先取得自己的 `duplicate_result()`；框架没有为同一次信号的每个监听者分别复制完整载荷。

## 大型结果的一次性领取

大型纯字典读取只有一个消费者时，可显式使用 `load_data_owned_request_async()`。它返回 `GFStorageOwnedRead`，与普通读取共用文件队列、事务恢复、执行器、迁移和等待期取消机制。迁移后先校验纯数据边界并保留一次交付隔离；之后的小型通知、状态查询与领取不再深复制载荷。它不更新 `last_load_result`，也不发出旧 `load_completed`，项目应订阅当前句柄。

```gdscript
var ticket: GFStorageOwnedRead = storage.load_data_owned_request_async("world.json")
var receipt: GFStorageOwnedReadReceipt
if ticket.is_completed():
	receipt = ticket.get_result()
else:
	receipt = await ticket.completed
if not receipt.is_ok():
	_show_load_error(receipt.get_error_code())
	return
var claimed: GFStorageOwnedReadTakeResult = ticket.take()
if claimed.is_ok():
	var read_result: GFStorageReadResult = claimed.get_read_result()
	_apply_payload(read_result.payload)
```

即时失败也有可查询的终态，所以先检查 `is_completed()` 再等待。成功的空字典仍得到 `SUCCESS`；等待中、已领取、已释放、失败、未绑定以及非主线程领取分别返回明确的 `GFStorageOwnedReadTakeResult.Status`。领取在主线程完成，可以直接放在 `completed` 回调内。

`take()` 只成功一次，返回包含完整 `GFStorageReadResult` 的领取结果，保留 metadata、归一化字段及[实际读取的 committed revision](committed-revisions.md)。领取结果的 `get_read_result()` 返回同一个对象；需要多个互相隔离的业务副本时，由消费者明确调用 `duplicate_result()`。分享句柄引用就是分享领取权，多名持有者中只有一名能成功领取。手动构造的未绑定句柄不能领取数据。

## 持有与释放

| 状态 | 可进行的操作 | 载荷归属 |
| --- | --- | --- |
| `WAITING` | 取消观察，或 `release()` 放弃接收 | 物理任务仍由执行器管理 |
| `READY` | `take()` 或 `release()` | 句柄持有隔离后的结果 |
| `TAKEN` | 查询小型诊断 | 已交给领取结果，句柄不再持有 |
| `RELEASED` | 查询完成后的诊断 | 已释放，晚到结果直接丢弃 |
| `FAILED` / `INVALID` | 查询失败或无效状态 | 没有可领取结果 |

`release()` 幂等，不会撤销已经领取的结果；等待时释放只放弃交付，不代表执行器已经取消。Utility 只弱引用独占句柄，不会用全局缓存延长已完成结果的寿命。释放最后一个句柄引用会结束它尚未交出的结果持有；项目应避免自己的信号回调或容器形成引用环。

owner、token、deadline 只约束 `WAITING` 阶段。成功先完成后，owner 销毁、晚到取消或 Utility dispose 都不会撤回 `READY` 结果；此时由句柄负责领取或释放。取消先完成则不会再交付载荷，已接纳的线程仍需退出并由 Utility 收尾，文件锁不会提前释放。排队取消的 receipt 保留 `PHYSICAL_SETTLED` 与具体取消 `end_kind`；执行中停止观察的 receipt 为 `CANCELLED`。

`GFStorageOwnedReadReceipt` 只暴露请求身份、逻辑文件名、状态、失败分类、版本、完整性和不透明 revision，不含业务 payload、任意 metadata 或来源授权。仍适用的 `data_migrated` / `data_integrity_failed` 小型事件在句柄结算之后发出。

尚未读到文档版本时，receipt 的 source/target version 为 `0`；未捕获 revision 时，getter 返回 `null`，`to_dict()` 中为 `{}`。成功读取 schema 1 所捕获的 `UNSUPPORTED` revision 仍会保留，schema 2 保留实际 token；迁移失败也会保留此前已经读取的文档版本。

## 适用边界

独占交付只支持可安全隔离的纯 Variant 图。迁移回调即使保留旧 Dictionary、Array 或 PackedArray 引用，也不能修改最终领取的隔离结果。Object、Resource、Callable、循环集合及超出既有纯数据预算（深度 128、累计 1,000,000 个值、估算 64 MiB）的结果会以 `UNSUPPORTED_PAYLOAD` 拒绝交付；这不是存档损坏，也不会偷偷改走普通广播路径。Resource 读取继续使用现有入口。

纯值校验支持所有分量有限的 `Projection` 与 `Array[Projection]`，并计入全部 16 个浮点分量的预算。默认值只按实际进入合并结果的分支校验；已有字段遮蔽的默认值，以及自定义迁移未使用的默认值，不影响领取资格。

向强类型字典补入默认值时，键和值会在原生赋值前检查；不兼容类型和非法颜色文本会返回 `UNSUPPORTED_PAYLOAD`。整次合并共享转换前的预检预算，共享数组不会因多次作为默认值使用而反复获得完整预算。

此接口减少交付阶段的副本，不保证端到端零复制或自动分帧。解码、迁移、纯数据校验和必要隔离仍有成本；尤其是包含大量细粒度 Dictionary / Array 的图，额外校验可能让总读取时间高于普通入口。只有需要单一领取权且实测取舍合适时才选择它；分别测量读取完成与结果领取，不要用领取变快推断整体变快。返回[本地存档管理器](storage-utility.md)查看同步、异步和迁移入口。
