# 热模块拓扑事务

架构提交 READY 后，Model、System、Utility 的注册、替换和注销属于显式的热模块拓扑事务。它们不是初始化阶段的动态补注册机制：Installer 必须在 `init()` 前完成基础装配；生命周期计划冻结后，`init()`、`async_init()`、`ready()`、`begin_activation()`、`begin_quiesce()` 和 `dispose()` Hook 内的注册表重入都会被拒绝。

Factory 和 alias 属于依赖解析拓扑，首次 activation 后保持不可变。需要改变这些绑定时创建并原子替换新的 `GFArchitecture`，不要在活动架构上维护第二套可变解析图。

## 注册

```gdscript
var architecture: GFArchitecture = Gf.get_architecture()
var registered: bool = await architecture.register_system_instance(
	RuntimeFeatureSystem.new()
)
```

热注册会用候选模块重新编译完整依赖 DAG，再让候选依次完成 `init()`、`async_init()`、`ready()` 和 `begin_activation()`。新实例始终保留在 staged candidate 中；只有 stage4 成功且原事务仍拥有当前 lifecycle generation 时，框架才原子发布 registry 与活动计划。提交前，普通 `get_*()` / `find_*()` 查询看不到候选；失败候选会被清理，不能视为已归属架构。

事务执行期间普通命令、查询和事件派发被关闭，避免外部运行时观察半提交拓扑。候选 activation 需要 tick-driven 依赖时，框架只临时驱动候选的本地依赖闭包。

原子发布只保证框架管理的 registry 与活动计划不可见，不隔离模块直接写入全局回调、进程级 singleton、网络监听等外部副作用。候选模块必须在 activation scope 中登记对应 cleanup，确保准备失败、事务失效或关闭接管时可以完整撤销；替换模块还应容忍候选 activation 与旧实例 quiesce 之间的短暂外部重叠。

若活动 child 的生命周期计划命中了本架构提供的 required module，child 持有的外部依赖租约会使本架构的模块注册、替换和注销在创建候选前失败。租约只冻结维持已提交 child 计划所需的模块拓扑；仅命中父级 required factory 时不会额外冻结模块拓扑，但仍会阻止父级在 child 之前正常关闭。先关闭相关 child，再重试父级拓扑事务。

## 替换

```gdscript
var replaced: bool = await architecture.replace_utility(
	RuntimeConfigUtility,
	replacement
)
```

替换同样先把新实例留在 staged candidate 中，在候选注册快照上编译 DAG，并私下完成四阶段准备。stage4 成功后，框架才按旧计划 quiesce 旧实例并原子发布 registry 与活动计划。准备失败会保留旧实例；旧实例无法 quiesce 时，框架会强制 dispose 整个架构，避免留下“旧服务仍工作、候选却部分可见”的不一致状态。

同 key 重入、lifecycle generation 漂移、并发拓扑事务或 dispose 会使旧事务失效。迟到 continuation 只能清理自己的未提交候选，不能覆盖更新事务的结果。

## 注销

```gdscript
var removed: bool = await architecture.unregister_system(RuntimeFeatureSystem)
```

注销先编译“移除目标后”的候选 DAG。仍有本地模块声明依赖目标时，候选计划无效，注销在触碰活动 registry 前失败。计划有效时，框架先 quiesce 目标，再提交新计划并执行同步 dispose/release；quiesce 失败同样使整个架构进入强制释放终态。

传入 alias 会被拒绝，必须使用对应 alias API；但 activation 后 alias 拓扑本身不可变。返回 `false` 时，调用方不得假定变更已提交，也不得复用已经交给失败事务并被清理的候选实例。

`Gf.unregister_model()`、`Gf.unregister_system()` 与 `Gf.unregister_utility()` 是同一异步事务的 Autoload facade，也必须 `await` 并检查返回的 `bool`。它们不再是可忽略终态的同步通知入口。

## 关闭接管

`shutdown_async()` 会先关闭准入，再等待已经接纳的拓扑事务稳定。等待达到 deadline 或被取消时，关闭流程按固定顺序接管：先夺取事务写权，再取消事务 scope，最后 claim 未提交候选的恰好一次清理；迟到 continuation 只能观察终态并 no-op，不能发布 registry 或活动计划。

清理所有权随当前事务描述符收敛，框架不会为已释放实例保留无界、长期存在的 tombstone。关闭结果中的 `unfinished_modules` 同时包含 quiesce 失败、取消或超时的当前模块，以及因此未开始 quiesce 的后续模块。

## 适用边界

长期跨场景服务应由 Installer 在启动图中注册。热模块事务适合真正需要在活动架构中装卸的可选运行时能力；关卡普通表现节点、临时数据和项目流程更适合 `GFNodeContext`、Controller 或项目自己的状态机。不要仅为规避明确启动依赖而把固定模块改成热注册。
