# 版本化与分帧快照

需要跨帧捕获时，先固定一个不会被后续写入改变的版本，再按预算读取。`GFVersionedDataStore` 是显式采用的分页记录序列：只有放入它的记录需要通过 `commit()` 写入，项目其他 Dictionary / Array 不受影响。首版提供记录替换、追加和清空，不提供任意位置插删、通用对象图或跨存储事务。

每条记录可以包含纯数据标量、嵌套 Array / Dictionary、类型化容器和 PackedArray，沿用 `GFDataSnapshot` 的类型与别名规则。输入中的共享子容器按值解释，不能依赖“改 a 会同时改 b”；循环、对象及对象类型容器明确拒绝。公开读取返回独立快照或副本，不返回内部可写引用。仅冻结最外层容器不足以保护嵌套内容。

```gdscript
var store: GFVersionedDataStore = GFVersionedDataStore.create()
var imported: Dictionary = store.commit({}, [{ "hp": 10 }, { "hp": 20 }])
if not imported.ok:
	return
var version: GFDataVersion = store.acquire_snapshot()
if version == null:
	return
var committed: Dictionary = store.commit({ 0: { "hp": 9 } }, [], 1)
if not committed.ok:
	version.release()
	return
var previous_record: GFDataSnapshot = version.read_record(0)
assert(previous_record.get_value(["hp"]) == 10)
version.release()
```

一次 `commit(replacements, appended, expected_revision)` 把所有修改作为一个事务发布。替换位置必须已经存在，追加顺序固定；非负 `expected_revision` 用于拒绝过期写入。任何一条记录非法或预算不足都不发布候选版本，也不推进版本号。记录位置仅属于这个序列版本，不是业务实体身份。

同一提交根内的数据是一致的；多个存储、适配器以及未纳入管理的游戏状态不会自动成为全局同一时刻的快照。需要共同一致的数据应放进同一个提交事务，或由项目已有机制协调后通过适配器提供固定版本。

`GFDataVersion` 是 `acquire_snapshot()` 返回的独占读取租约：只固定根和元信息，不扫描记录。`commit()` 的原始输入校验与隔离仍然是同步成本，大批首次导入应安排在加载期，或拆成业务允许的事务批次。分页只让已有版本后的局部更新避免复制整张表，不会使首次导入变成免费操作。

## 按共享帧预算生成普通快照

`GFDataSnapshotCapture.begin()` 接管一个固定源租约，完成后返回普通 `GFDataSnapshot`，可以交给现有只读、哈希或编码消费者。框架版本的记录已校验且不可变，捕获只构造根序列并保留源版本，不重复深拷贝每条记录。需要可修改树时仍显式调用 `copy_value()`。存储、租约、捕获与释放均须在同一线程串行进行；跨线程使用结果时，源线程必须保留最后一个结果引用直到后台工作结束，再在源线程释放，或先导出独立副本。该版本存储不提供跨线程同步。

```gdscript
var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
var frame_budget: GFExecutionBudget = GFExecutionBudget.new({
	"max_steps": 128,
	"max_elapsed_msec": 2,
})
# 每帧只由调度方重置一次；同一帧的其他任务继续使用剩余额度。
frame_budget.reset()
var state: String = capture.advance(frame_budget)
if state == "ready":
	var ready_snapshot: GFDataSnapshot = capture.get_snapshot()
	# 项目将 ready_snapshot 交给自己的只读消费者。
elif state in ["failed", "cancelled"]:
	var report: Dictionary = capture.get_report()
	# settled=false 时，后续使用新的、未取消的清理预算继续 advance。
```

每个 step 对应一条有界记录。帧步数或时间额度用完返回 `pending`，不会从头扫描；累计条目、载荷、深度、实际工作时间或生命期超限则失败。帧间等待只计入 `max_age_msec`，不计入 `max_work_msec`。会话不会重置调用者的预算，也不会占用共享深度栈。单条适配器调用、引擎分配和线程调度仍可能超过期望切片时间，时间限制是协作式预算，不能当作硬实时保证。

默认累计限制为 1,000,000 条记录、1,000,000 项、64 MiB 逻辑载荷、64 层深度、30 秒工作时间和 120 秒生命期；单条记录默认最多 4096 项和 64 KiB 载荷。可通过 `begin()` 的同名 `max_*` 选项调整。数据域与同步捕获相同，但根输出固定是记录 Array；记录内部的类型声明保留。

## 版本预算、失败与释放

存储默认最多 16 个存活版本、64 个外部读者、2,000,000 个页或记录节点、128 MiB 计费存储；这些限制独立于一次捕获的累计限制。计费覆盖唯一共享页、记录、原始写入暂存预留、捕获输出引用槽及等待回收的节点，同一存储块不会按版本重复收费。单条记录默认最多 4096 项、64 KiB 载荷、32 层深度和 100 毫秒同步捕获时间，可通过 `create()` 调整。

计费字节使用节点和载荷模型，不是 Godot 堆或进程 RSS。写入会保守预留一条记录的暂存上界；余量不足时可能拒绝仍有少量空闲空间的事务。调用方显式导出的独立副本不属于存储保留预算。`get_statistics()` 提供当前计费、峰值、版本、读者和待回收数量。

旧版本仍被读者持有时不能自动淘汰。新事务超预算会明确失败，保留已提交版本；项目可结束过时捕获、释放读者并回收后重试。捕获失败不交付半成品，也不回滚游戏后来已经提交的修改。失败清理需要继续推进到 `settled=true`；这表示会话已退还租约，不表示存储回收队列已经清空。

`release()` 幂等退还一个版本句柄；`close()` 停止存储的新写入与新读者，已有句柄仍能读取。之后保留存储对象，按帧调用 `collect_garbage(max_nodes)`，直到 `pending_nodes=0`。每个节点的回收成本受页宽与单条记录限制约束。直接丢弃最后一个存储、会话或普通快照引用仍会由 Godot 同步销毁，自动析构是资源兜底，不属于分帧释放承诺。

成功捕获将源租约交给结果快照，因此消费者保留结果时也会保留相关源版本。项目不得在 `begin()` 之后自行释放或复用交出的租约。公开接口保护嵌套别名；直接篡改脚本内部字段不属于安全隔离边界。

## 接入项目已有不可变版本

项目可以继承 `GFDataSnapshotSource`，为一次读取创建独占租约，重写 `_get_record_count()`、`_get_revision()`、`_read_record(index)` 和 `_release()`。获取数量和版本必须只读取固定元信息；每条读取必须有界，并返回独立、已就绪的 `GFDataSnapshot`。租约释放不能撤销此前返回的记录快照。

适配器负责源版本在整个读取期间不变，以及自己的外部保留内存和生命周期管理。GF 校验记录、累计预算与可观察的版本矛盾，但无法仅凭版本号证明底层没有原地修改。单次读取的输出会计入捕获载荷限制；适配器持有的外部原始结构不冒充 GF arena 的已核算内存。需要硬性限制这部分保留量时，应在项目的租约获取入口执行准入。

框架容器与项目适配器都通过相同的捕获会话交付结果，既有稳定版本无需迁移存储布局。适配器应将特殊数据结构转换为受支持的纯数据记录；首版不会直接遍历任意 Godot 对象。
