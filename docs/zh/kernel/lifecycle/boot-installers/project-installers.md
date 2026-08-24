# 项目级 Installer

如果希望把启动装配从 boot 脚本中抽离，可以继承 `GFInstaller`。

## 基础装配

```gdscript
class_name GameInstaller
extends GFInstaller


func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	await architecture.register_model_instance(PlayerModel.new())
	if scope.is_cancel_requested():
		return
	await architecture.register_utility_instance(GFStorageUtility.new())
	await architecture.register_system_instance(BattleSystem.new())
```

从 `1.9.1` 起，也可以把绑定来源、别名和短生命周期工厂写到声明式装配入口。

```gdscript
func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	binder.bind_model(PlayerModel).as_singleton()
	binder.bind_utility(JSONConfigProvider).with_alias(GFConfigProvider).as_singleton()
	binder.bind_system(BattleSystem).as_singleton()
	binder.bind_factory(DealDamageCommand).from_factory(func() -> Object:
		return DealDamageCommand.new()
	).as_transient()
```

`from_instance()` 适合把项目已经持有的对象暴露为单例语义。如果工厂需要每次创建新对象，使用 `from_factory(...).as_transient()`。`from_instance().as_transient()` 会被拒绝，避免已有实例被误当成短生命周期对象。

多项绑定都属于启动硬要求时，使用 opt-in 的 `GFBinder.create_required_plan()` 统一执行、首失败诊断和 scope 结算；既有 `.as_singleton()` / `.as_transient()` 的 `bool` 返回与可选绑定语义保持不变，不会被框架自动转换为 required。Plan 的 pre-init-only、单次执行、结果字段、Callable 与 `from_instance()` ownership 边界见[声明式装配与工厂](../../architecture/assembly-diagnostics/binder-factories.md)。

## 路径与等待边界

然后在 `Project Settings > gf/project/installers` 中加入安装器脚本资源。编辑器可能保存 `res://`，也可能保存稳定 `uid://`；运行时会把可解析 UID 规范化为真实 `res://` 脚本路径。之后 `await Gf.init()` 会按数组顺序逐个执行 Installer：每个 Installer 先执行 `install(architecture, scope)`，再执行 `install_bindings(binder, scope)`。所有 Installer 完成后，架构冻结注册快照、编译依赖 DAG，再依次执行 `init()`、`async_init()`、`ready()`、`begin_activation()` 四阶段。

`begin_project_installers()`、`mark_project_installers_applied()` 与 `finish_project_installers()` 是 `Gf` 启动编排使用的状态边界，项目 Installer 不应直接调用。完成入口只接受已经进入 running 的事务；提前或重复调用不会把架构伪装成已执行 Installer，也不会唤醒等待方。

Installer 路径必须最终解析到 `res://` 下的 `.gd` 脚本。空路径、失效 UID、`user://`、绝对文件系统路径、错误元素类型和非脚本资源都会被视为配置错误；默认会中断初始化，迁移期才应临时关闭 `gf/project/fail_on_installer_error`。

`scope` 是本轮安装的协作取消边界。`GFAsyncScope` 继承自 `GFCancellationToken`，因此可以直接传给只需要读取取消状态的 helper。Installer 等待外部资源、网络、编辑器回调或多帧扫描时，应在每个 `await` 后检查 `scope.is_cancel_requested()`；需要释放临时连接、后台句柄或外部请求时，用 `scope.register_cleanup(callback)` 登记无参清理回调。初始化失败、架构释放、超时或局部上下文退出树时，框架会取消 scope 并按后进先出的顺序执行清理。

`install()` 和 `install_bindings()` 都可以在内部使用 `await`，但首个 `await` 之前仍运行在主线程。需要等待外部资源、网络或编辑器回调时，可以用 `gf/project/installer_timeout_seconds` 限制单步等待时间；长同步扫描或解析应拆成让帧步骤，避免超时检测被同步段阻塞。

Installer 是固定启动拓扑的最后注册边界。依赖 DAG 开始编译后，生命周期 Hook 内新增、替换或注销模块都会被拒绝；不要依赖初始化阶段的动态补注册或多轮 stage pass。架构 READY 后确实需要改变模块集合时，使用返回类型化成功值的热模块事务。

## 原子提交与 Gf facade 边界

`await Gf.set_architecture(candidate)` 会先把 `candidate` 作为未发布候选运行 Installer、依赖计划和四阶段生命周期。只有 `init()` 返回成功、candidate 已提交 READY 且 `is_accepting_runtime_work()` 为 true 时，assignment 才有资格继续；stage4 完成前，所有 `Gf` facade 入口都不会观察到 candidate。

因此，Installer 必须使用 `install(architecture, scope)` 收到的 `architecture` 参数或 `install_bindings(binder, scope)` 收到的 `binder` 注册候选模块。不要在 Installer 中用 `Gf.register_*()`、`Gf.create_binder()` 或 `Gf.get_*()` 隐式访问候选架构；这些入口在替换期间仍属于旧架构。

如果 pending assignment 被更新的 `set_architecture()`、尚无已提交架构时由 `Gf.create_architecture()` 创建的默认架构，或 Gf 退出场景树替代，框架会取消本轮 `scope`、执行已登记的 cleanup，并 dispose 尚未提交的候选架构。每个异步检查点都应检查 `scope.is_cancel_requested()`；即使 Installer 已返回，只要保留的公开 scope 在候选初始化期间被取消或提前 `complete()`，本轮 assignment 也会清除 pending 状态、拒绝提交并释放未提交候选。被替代的调用返回 `false` 后，不要复用该候选，重试时创建新的 `GFArchitecture`。

替换已有全局架构时，candidate 保持未发布，框架先 `await old_architecture.shutdown_async()`。旧架构一进入 quiescing 就不再是可接受运行时工作的 facade identity；新工作不会在旧架构 drain 与 candidate 提交之间钻入。只有 typed shutdown result `is_successful()` 时才发布 candidate。旧架构关闭失败、取消、超时或被强制释放时，candidate 会被拒绝并强制清理；旧终态 identity 只在 assignment serial 与 identity 仍匹配时清除，不会用失败 candidate 填补。

同一个候选已经处于 pending 时，再次调用 `set_architecture(candidate)` 会立即返回 `false`，但不会取消、dispose 或抢占原 assignment；原调用仍是唯一有权提交该候选的事务。不同候选的更新 assignment 会使旧事务失效。candidate activation、旧架构 shutdown 以及 identity listener 中的重入都遵守同一 serial/scope ownership 规则；每个 `await` 后都会重新验证，迟到 continuation 不能覆盖更新 assignment。成功提交会先清除 pending、解除 scope 跟踪并调用 `scope.complete()`，再发布全局 identity 通知。

这里的原子性只覆盖 facade identity、registry 可见性与事务所有权，不会自动回滚模块直接写入进程级 singleton、全局回调、网络监听等框架外副作用。`begin_activation()` 创建这类副作用时必须同步登记 cleanup，使失败或被替代的 candidate 可以完整撤销；架构替换还必须容忍 candidate activation 与旧架构 shutdown 完成前的短暂外部重叠。

`QUIESCING`、`DISPOSING` 或 `DISPOSED` Architecture 不能作为新 candidate，也不能重新 `init()`。这些状态下，`Gf.has_architecture()` 返回 false，`Gf.create_architecture()` 与依赖它的注册、替换、binder/factory helper 会分别返回 `null` 或 `false`，不会暴露关闭中的旧实例或创建瞬态默认架构。若项目在 assignment 之外直接关闭当前全局 identity，下一次合法创建会先清除 terminal identity；绝不会复活旧实例。

## 显式关闭

应用正常退出、切换主运行域或测试需要保留已接纳异步工作时，应直接等待架构：

```gdscript
var architecture: GFArchitecture = Gf.get_architecture()
var shutdown_result: GFArchitectureShutdownResult = (
	await architecture.shutdown_async()
)
if not shutdown_result.is_successful():
	push_warning(shutdown_result.get_error())
```

`shutdown_async()` 会关闭新工作准入、按依赖逆序 quiesce，再执行同步释放。`Gf` 自身退出 SceneTree 时无法可靠等待，仍使用同步 `dispose()` 强制兜底；这条路径不承诺 drain，不能替代项目可控的正常关闭。

## 启动失败诊断

不要在忽略初始化结果后继续查询模块：

```gdscript
if not await Gf.init():
	var architecture := Gf.get_architecture()
	push_error(architecture.last_initialization_error)
	return
```

如果 `Gf.get_utility(SomeUtility)` 返回 `null`，先打印实际设置：

```gdscript
print(ProjectSettings.get_setting("gf/project/installers", []))
```

值为 `[]` 表示当前运行进程没有读取到项目 Installer，不表示 Utility 的方法被删除。确认 Project Settings 已关闭并保存、`project.godot` 的 `[gf]` 分区包含 `project/installers=...`，且升级时只替换 `addons/gf`，不要用框架仓库自己的 `project.godot` 覆盖项目配置。
