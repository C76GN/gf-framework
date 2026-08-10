# 本地存档管理器

`GFStorageUtility` 是基于 Godot `user://` 的本地持久化工具。它负责把字典和 `Resource` 文件写入项目可写目录，并在读取时执行 codec 解码、完整性校验、事务恢复和版本迁移。字典读取统一返回 `GFStorageReadResult`，调用方必须检查 `ok`，不能再用空字典猜测“合法空载荷”还是“读取失败”。

底层 storage 不作为项目槽位门面。项目需要槽位工作流时，应由项目自有的 slot adapter 把槽位身份映射到可配置文件名，再通过 `GFStorageUtility.save_data_group()` 让数据与 metadata 同事务落盘；标准层不规定槽位编号、命名、预览字段或 UI 语义。

`GFStorageCodec` 提供 JSON/Binary 编码、可选压缩、SHA-256 完整性校验、轻量 XOR 混淆和框架存储元信息。物理文档只接受当前 schema 和精确字段集合，业务数据始终位于独立 `payload`，即使包含 `__gf_storage_document`、`payload`、`data` 或 `_meta` 等相似键也会完整往返。未知物理字段、错误格式、未来版本、缺失完整性摘要或摘要不匹配会产生明确失败结果，不会回退成另一种格式继续猜测。这里的混淆只用于降低误编辑概率，不能用于保护敏感数据。

同时原生支持 Godot 的 `Resource` 类型保存，例如 `.tres` 或 `.res`。读取 Resource 会进入 Godot `ResourceLoader`，因此默认关闭；项目必须先显式启用 `allow_resource_loads`，配置 `allowed_resource_load_type_hints` 与扩展名 allowlist，并用存储路径策略收窄加载边界。`load_resource()` 会在加载后再次确认实际资源实例匹配 `type_hint`，这个入口只面向项目生成或项目已确认来源与格式的本地文件，不是沙盒化的资源导入器；对用户下载、导入或可被篡改的资源，项目层应先做来源检查、格式转换，或改用纯 `Dictionary` / JSON 载荷。

`GFStorageCodec` 的 JSON 格式会自动通过 `GFVariantJsonCodec` 把 Vector、Color、PackedArray、AABB、Transform 和 `NaN` / `INF` / `-INF` 等值转换为 JSON 安全标记，再在读取时恢复为 Godot Variant；不会把非有限值直接交给 `JSON.stringify()` 后静默变成 `null`。若编码超过 Variant 遍历预算，codec 会把它视为编码失败，`GFStorageUtility` 的同步与异步事务都会拒绝提交并保留已有文件，不会把内部 `TraversalLimit` 标记当作业务存档落盘。需要保存 Resource 或 Node 引用时，仍应使用 `GFVariantReferenceCodec` 的显式引用标记，或由 SaveGraph 属性序列化器代为处理。

如果确实需要把受控 `Resource` 属性图编码成字典，再使用 `GFSafeResourceCodec` 与 `GFSafeResourceCodecPolicy`。默认策略不会实例化任何对象，项目必须显式允许类、脚本路径和外部资源路径：

```gdscript
var policy := GFSafeResourceCodecPolicy.new()
policy.allow_class("Resource")
policy.allow_resource_path("res://data/*.tres")

var encoded := GFSafeResourceCodec.encode(my_resource, policy)
var decoded := GFSafeResourceCodec.decode(encoded.data, policy)
```

安全 codec 只处理 allowlist 内的存储属性、集合、重复引用和可选外部资源路径。类型化 `Array` / `Dictionary` 会连同元素、键和值的类型约束一起往返；类型约束引用脚本时，该脚本路径及脚本的原生基类都必须分别进入 policy 的脚本与类 allowlist。解码还会拒绝非正数、非整数或重复的对象编号，并通过报告式属性写入返回类型不匹配，而不是把伪造值直接交给对象。`max_items` 同时是处理预算：Array 的元素、Dictionary 的键和值以及 Object 的属性值会在扫描或暂存完整容器形状前按直接子节点基数预检；嵌套节点仍在递归入口逐项消费预算。

它不注册 Godot ResourceFormatLoader/Saver，不执行表达式，也不把未知内容变成可直接使用的对象；面对用户下载内容或网络载荷时，应先在项目层完成格式收窄和风险处理。成功解码出的非 `RefCounted` 对象（例如 `Node`）由调用方负责持有和释放。allowlist 内脚本在附加时仍会按 Godot 语义执行初始化，因此只应允许项目已信任的脚本；失败清理会回滚 codec 已写属性并释放本次创建的对象，但不能撤销脚本初始化对外部系统产生的副作用。

## 项目级存档聚合

`GFStorageUtility` 只负责把项目给出的载荷可靠落盘，不提供全局 SaveSystem、业务模块注册表或固定存档目录规范。项目可以在自己的 System、Installer、slot adapter 或存档服务中收集多个 Model、Domain 容器、运行时快照和项目配置，再把聚合后的字典交给 `save_data()` 或 `save_data_group()`。

这种聚合结构应由项目定义，例如 schema 版本、玩家资料、世界状态、设置、统计和自定义预览字段。GF 侧只承诺通用机制：路径安全、事务恢复、codec、checksum、压缩、多文件事务、Resource 存取和 `register_migration()` 版本迁移。模块优先级、业务字段含义、奖励发放、云同步账号隔离、平台加密和冲突策略都应留在项目层或独立插件。

大型载荷推荐拆成两段：先用项目自己的分帧流程生成纯 `Dictionary`，或调用
`GFArchitecture.get_global_snapshot_async()` 并在 `ok == true` 后取出 `snapshot`，
再交给 Storage 后台预检、物化、编码和落盘。不要把 Architecture 的 Result 外壳或
失败结果当作存档载荷。`GFStorageUtility` 的 worker 只处理已经生成的纯 Variant 图，
不会遍历场景树、读取 `Resource` 或调用业务对象。

`save_data_async()` 与 `save_data_request_async()` 是安全的普通入口：它们会在请求入队
时深复制 `Dictionary`，调用方可以继续使用原值。已经通过分帧流程独占大型载荷，并且
希望避免再次主线程深复制时，才使用 `GFStoragePayloadTransfer` 与
`save_payload_request_async()`：

```gdscript
var payload: Dictionary = await _build_owned_payload_over_multiple_frames()
var transfer := GFStoragePayloadTransfer.take_ownership(payload)
# take_ownership() 成功后必须放弃 payload 及其全部嵌套 alias。
payload = {}

var operation := storage.save_payload_request_async("profile.json", transfer)
var result: GFStorageAsyncResult
if operation.is_completed():
	result = operation.get_result()
else:
	result = await operation.completed

if not result.is_successful():
	var retry_transfer := operation.reclaim_failed_payload()
	if retry_transfer != null:
		_schedule_bounded_retry(retry_transfer)
	else:
		transfer.release()
else:
	transfer.release()
```

这条入口采用逻辑 move，不做深复制，也没有公开 payload getter。调用成功后，生产者必须
永久放弃源 `Dictionary` 及全部嵌套 `Array` / `Dictionary` alias；GDScript 不会替框架
执行语言级 move，继续访问这些 alias 会破坏跨线程只读不变量。

首次合法请求会冻结 Storage 实例、规范文件名、canonical target file-family identity
和 codec options；Utility 的存储目录或 codec 配置发生变化后，旧 transfer 不会漂移到
新目标，也不能伪装成同一 retry binding。同一 transfer 可以让超时后仍在运行的
detached attempt 与有界重试分别取得只读 lease；重试复用同一个逻辑 Snapshot，不重新
遍历业务对象，也不重新复制完整载荷。失败句柄只允许通过
`reclaim_failed_payload()` 归还同一个 opaque transfer 一次；整个重试 generation
结束后，所有者必须调用 `release()`。如果仍有 attempt 活动，载荷会延迟到最后一个
lease 收敛后再清空。

worker 会在本次新写入的编码以及 temp、marker、final 事务提交副作用前检查图深度、
值数量、估算原始字节数、支持的 Variant 类型、typed container 约束、集合循环和非有限
数值，再物化隔离副本。当前硬上限为 128 层、1,000,000 个值与 64 MiB；Dictionary
使用逐条迭代，不会先物化完整 key snapshot。Packed Array 的每个元素都会计入值预算，
其固定宽度或字符串内容同时计入字节预算；需逐项检查有限性的 Packed
Float/Vector/Color 也必须先通过预算才能开始扫描。携带 Object、Resource 或 Script
类型元数据的空 typed Array/Dictionary 同样会被拒绝，不能借空容器把对象约束带入
worker。

启动前的既有事务 recovery 与目录初始化属于独立前置生命周期，不受这条“新写入尚未
提交”的保证覆盖。异步单文件写入与同步事务共用同一个 marker schema；单文件入口
发现经过交叉校验的多文件 marker 时，会先核对并恢复完整成员集合，再开始该成员的
异步 I/O。若进程在 committed marker 已落盘但 cleanup 尚未完成时退出，后续 recovery
会保留新 final，而不是把已提交代次误判为回滚。`dispose()` 会先关闭新的异步 admission，
再 drain 活动 attempt 并拒绝终态回调中的重入提交，所有 transfer lease 仍须在终态前收敛。
`GFStorageAsyncResult.get_write_failure_kind()` 区分请求、载荷、编码、线程、生命周期和
IO 故障；`get_write_validation_report()` 只暴露有界的结构索引、类型和预算计数，不
返回载荷 key/value，也不返回可离线关联 key 的 digest。调用方应根据这些类型化证据
决定是否重试，不能把不可持久化载荷当成临时 IO 故障。

## 基础用法

```gdscript
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility

# -- 字典与多文件事务 --
storage.save_data("profile.json", {"player_hp": 100})
storage.save_data_group({
	"slots/1/data.json": {"player_hp": 100},
	"slots/1/meta.json": {"display_name": "手动槽位 1"},
})

var read_result := storage.load_data("profile.json")
if not read_result.ok:
	push_error("Load failed: %s" % read_result.error)
	return
var profile: Dictionary = read_result.payload

# -- Resource 存档 --
var my_res := Resource.new()
storage.save_resource("my_custom_resource.tres", my_res)

# 仅加载项目自己写入或已确认来源与格式的资源文件。
storage.allow_resource_loads = true
storage.allowed_resource_load_extensions = PackedStringArray(["tres"])
storage.allowed_resource_load_type_hints = PackedStringArray(["Resource"])
var loaded_res := storage.load_resource("my_custom_resource.tres", "Resource")
```

## 异步请求身份

简单调用方可以继续使用 `save_data_async()` / `load_data_async()` 和全局完成信号。需要把
终态精确关联到一次请求的协调器、自动保存服务或并发调用方，应使用请求句柄：

```gdscript
var operation: GFStorageAsyncOperation = storage.load_data_request_async("profile.json")
var async_result: GFStorageAsyncResult
if operation.is_completed():
	async_result = operation.get_result()
else:
	async_result = await operation.completed

if not async_result.is_successful():
	var read_failure := async_result.get_read_result()
	match read_failure.failure_kind:
		GFStorageReadResult.FailureKind.NOT_FOUND:
			_initialize_new_profile()
		GFStorageReadResult.FailureKind.CORRUPT:
			_offer_recovery(read_failure)
		_:
			_report_storage_failure(read_failure)
```

每个 `GFStorageAsyncOperation` 都持有唯一 request ID、规范文件名、操作类型和 exactly-once
终态，`GFStorageAsyncResult` 是该请求身份与读写结果的不可变终态快照。不得用文件名或
`last_load_result` 猜测某个句柄是否完成；同一文件可以存在来自不同调用方的多个排队
请求。同步拒绝的非法请求也会返回已失败句柄，不会留下永不完成的等待。

`GFStorageReadResult` 分离 `payload`、框架 `metadata`、`integrity_status`、Godot `error_code`、物理文档版本、数据迁移前后版本和 `migrated`。`failure_kind` 进一步区分非法请求、不存在、普通 IO、损坏、未来格式、迁移失败和服务不可用；上层恢复政策应根据该分类决定，不能仅凭同一个 `Error` 码把未来格式或迁移失败当成损坏。异步读取完成信号同样传递这个结果；`last_load_result` 只用于诊断最近一次读取，不应替代当前调用返回值。

9.0 的物理存储文档是有意收紧的契约，不会把旧明文 JSON 或旧 envelope 当成当前格式。需要保留既有玩家数据的项目应在升级发布前使用独立、版本锁定的一次性导入器读取旧文件，验证后写成当前文档，再移除导入入口；不要在主读取路径长期保留格式猜测。

`save_data_group()` 会先把所有成员规范化成唯一 file-family 身份；`group/a.json` 与 `group//a.json` 这类别名会在写入前被拒绝。事务 journal 带版本、transaction id、精确文件集合和数量上限，恢复时磁盘 marker 只能引用本次调用已经授权的 canonical 文件，不能扩大到请求范围之外。提交失败会按同一 file-family 集合恢复备份。

## 文件管理

除槽位和字典读写外，`get_storage_directory_path()`、`ensure_directory()`、`list_files()` 与 `delete_file()` 可用于管理同一存储根目录下的通用文件，例如列出本地缩略图、缓存 manifest 或项目自定义资源文件。

`get_storage_directory_path()` 只解析路径，不创建目录；需要目录实际存在时再调用 `ensure_directory()`。这些 API 复用 `GFStorageUtility` 的路径安全策略：所有运行时入口只接受规范相对路径，并在词法上解析到当前 Storage root；绝对路径、`..` 跨目录路径和非法非空 `save_dir_name` 始终失败关闭，不会退化到 `user://` 根。纯字典读写和多文件事务 API 会直接拒绝空 `file_name` 或任意非法成员，而不是写入内部兜底文件名。需要读取任意本机路径的可信编辑器或离线迁移工具，应在自己的工具能力边界内直接使用 `FileAccess` / `DirAccess`，不能重新扩大运行时 Storage 的权限。

这是一条 GF API 的词法身份与所有权边界，不是宿主文件系统安全沙箱：同进程代码仍可直接调用 `FileAccess` / `DirAccess`，宿主预先建立的 symlink、junction、挂载点或等价重定向也不在该保证内。涉及不可信宿主环境时，应由平台沙箱和文件系统权限提供实际隔离。

递归枚举默认限制深度和返回数量，可通过 `list_files(..., { "max_scan_depth": 64, "max_file_count": 20000 })` 调整。枚举结果返回存储相对路径，适合交给 `load_data()`、显式启用后的 `load_resource()` 或项目自己的读取流程继续处理。

项目 slot adapter 枚举槽位时应使用自己的受控文件模板，不要把内部事务文件、备份文件或项目临时文件混入读档 UI。
