# 资源服务域

`GFResourceServiceDomain` 是同一 Broker 及其关联消费者的稳定入口。模式在初始化时
选择，不能在运行中修改配置升级。多个 `GFAssetUtility` 可以绑定同一个域；
它们共享模式、入口和代次，不能各自决定切换策略。

| 模式 | 新请求 | 旧请求和资源所有权 | 当前可用后端 |
| --- | --- | --- | --- |
| 稳定绑定 `STABLE`（默认） | 始终使用原实例 | 生命周期结束时收尾 | 已初始化、尚未被使用的 Broker |
| 受控切换 `CONTROLLED` | 准备候选后暂停，暂停期间明确拒绝 | 全部收尾后统一换入口 | 原生 `GFResourceBroker`、`GFResourceSnapshotBroker` |
| 在途热切换 `IN_FLIGHT` | 候选准备完成后立即交给新代 | 原代继续推进，全部收尾才退出 | `GFResourceSnapshotBroker` |

不满足能力条件时返回明确失败，不回退成其他模式。服务域接管的 Broker 不能再单独
注册进 Architecture；即使架构尚未 init，已经注册的 Broker 也不能被服务域接管。
原始 Broker 已经被固定消费者绑定或直接提交过请求时，不能
事后接管；被域接管后，直接向它请求也会失败。原始引用不具备自动切换保证。
`GFSceneUtility` 和 `GFBackgroundWorkUtility` 当前只提供固定绑定，不能把域持有的
原始 Broker 注入它们来模拟自动切换。

## 原生加载器的限制

Godot threaded ResourceLoader 的查询和结果领取使用全局路径。创建两个 Broker
不能证明同路径两代请求彼此独立，因此原生后端拒绝在途热切换。受控切换在旧代收尾之前不会让
新实例发出资源请求；候选配置、初始化和所有权检查都先于暂停完成。

`GFResourceSnapshotBroker` 适合已预加载资源集、主题或资源版本映射。`configure()`
冻结逻辑路径与 `Resource` 的绑定，不调用 ResourceLoader，也不会在释放时修改
已交付资源。每代维护独立映射和请求队列，能力通过框架具体实现身份检查，不能由
未知子类声明一个布尔值来取得在途热切换资格。

映射键可以使用逻辑 `res://` 或语法有效的 `uid://` 路径，不要求对应磁盘文件存在。
尚未登记到 Godot UID 表的 UID 保留为逻辑键；已登记的 UID 按资源身份规则解析为路径。
配置与请求使用相同的规范化规则，规范化后重复的键会使整份配置失败。

“快照”只描述映射。它不保证任意 Resource 内容不可变，也不自动深复制资源；项目
可以有意跨代共享同一个 Resource，或提供不同实例。共享可变内容的规则仍由项目决定。
释放租约后自行保留 Resource，表示该引用已脱离服务所有权，Resource 的引用计数
保证其自身存活；服务域不再为它保留 Broker。

## 创建与绑定

```gdscript
var broker := GFResourceSnapshotBroker.new()
var configured := broker.configure({
	"res://theme/panel.tres": preload("res://themes/day/panel.tres"),
})
if configured != OK:
	push_error("资源快照配置失败：%s" % error_string(configured))
	return

var domain := GFResourceServiceDomain.new()
var domain_configured := domain.configure(broker, GFResourceServiceDomain.Mode.IN_FLIGHT)
if domain_configured != OK:
	push_error("资源服务域配置失败：%s" % error_string(domain_configured))
	return
var assets := GFAssetUtility.new()
var bound := assets.set_resource_service_domain(domain)
if bound != OK:
	push_error("Asset 绑定资源服务域失败：%s" % error_string(bound))
	return

await architecture.register_utility_instance(domain)
await architecture.register_utility_instance(assets)
await architecture.init()
```

独立使用时初始化 Asset 并由调用方持续调用 `assets.tick()` 和 `domain.pump()`。
在架构中域通过 Utility tick 推进全部存活代次。域入口本身不可在活动架构中单独
替换或注销；更换入口、模式或消费者绑定需要关闭并重建相应生命周期。

## 请求与资源句柄

直接调用 `domain.request()` 得到 `GFResourceLease`。`get_service_generation()` 是
请求接纳时冻结的代次；在 Broker 内排队的工作也属于原代。通过 Asset 提交时，
Asset 自己的 lane 队列同样在接纳时固定代次，不能等到真正加载时再查询当前入口。

成功、失败和取消后都应调用 `lease.release()`。成功租约仍持有资源时，Broker 的
`is_idle()` 只是释放条件之一，服务域还会等待租约归还。Asset 请求完成后归还内部租约；成功结果中的 `GFAssetHandle` 由请求 scope
继续保留原代，直到 scope 关闭、owner 退出或句柄明确释放。

Asset 缓存键包含代次，因此新请求不会命中旧代同路径缓存。旧结果仍按原请求
交付，迟到本身不是错误。取消旧代 Asset 请求直接使用原 operation：

```gdscript
var cancelled: bool = old_operation.cancel()
```

每个 operation 只取消自己的消费资格，不会触碰其他代次或其他消费者。`handle.get_service_generation()` 可以诊断句柄
所属代次。业务若只接受当前版本，应比较代次并主动释放不需要的句柄；框架不会
统一丢弃仍符合原合同的旧结果。

## 切换与失败

```gdscript
var candidate := GFResourceSnapshotBroker.new()
var candidate_configured := candidate.configure({
	"res://theme/panel.tres": preload("res://themes/night/panel.tres"),
})
if candidate_configured != OK:
	push_error("候选资源快照配置失败：%s" % error_string(candidate_configured))
	return
var switching := domain.begin_switch(candidate, 30000)
# 继续正常 tick / pump，并释放不再使用的旧句柄。
```

`switching` 在旧代安全退出后成功。在途热切换的新入口可能早已接单；`generation_changed`
表示新请求入口已经提交，不表示旧代已退出。最多两代同时存活；旧代尚存、已有
切换在等待、关闭期间或正在 pump 时，另一切换都明确失败。回调若已推进到前次
物理收尾完成，可以发起下一次切换；各调用仍返回自己的完成对象。每代请求、句柄
票据和租约合计最多 8192 个；超出预算的请求失败，不产生无界积压。

受控切换的暂停采用拒绝策略，Asset 回调收到 `null`，域直接请求得到 failed Lease。
候选验证失败不会暂停旧服务。排空超时后保持暂停，并丢弃尚未接单的候选；
调用方可在旧工作收尾后显式提交新的候选重试，不能把失败报告当成恢复营业。

在途热切换超时只表示原代未在期限内收尾。新入口继续工作、旧代继续 pump，后续切换仍然
受两代限制。之后实际收尾不会把此前的失败改写为成功。新代接单后没有自动倒回
或重放；项目要更换健康实例时，也必须经过同样的受控换代规则。

## 关闭

`begin_quiesce(scope)` 停止新接纳，继续完成所有已接纳的本地队列和两代请求，等待
所有租约和句柄归还。关闭前，项目消费者应在自己的静默阶段停止工作并释放持有的
资源句柄；长期保留句柄会如实阻止域退出。取消 scope 只结束等待，不假称底层加载
或资源引用已经释放。

架构退出超时或直接 `dispose()` 后，仍被租约和句柄持有的域不会提前销毁。存在
SceneTree 时，域为异常退出创建一个局部收尾节点，继续推进所有代次；全部收尾后
自动释放节点与域，不改变此前的超时结果。正常成功关闭不创建额外推进器。
树暂停不会暂停这项收尾；树本身退出时自动推进结束，未释放的租约仍保留域。

没有 SceneTree 时不会假称存在自动推进；调用方须保留域并显式 `pump()`。
不要把限时等待等同于强制终止加载器。`get_debug_snapshot()` 可读取当前代、旧代、
存活代数、暂停与关闭状态、各代尚存引用数，以及 `retirement_pump` 和未完成原因。
