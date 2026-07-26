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

## 路径与等待边界

然后在 `Project Settings > gf/project/installers` 中加入安装器脚本资源。编辑器可能保存 `res://`，也可能保存稳定 `uid://`；运行时会把可解析 UID 规范化为真实 `res://` 脚本路径。之后 `await Gf.init()` 会按数组顺序逐个执行 Installer：每个 Installer 先执行 `install(architecture, scope)`，再执行 `install_bindings(binder, scope)`，所有 Installer 完成后才进入 `init()`、`async_init()`、`ready()` 三阶段。

Installer 路径必须最终解析到 `res://` 下的 `.gd` 脚本。空路径、失效 UID、`user://`、绝对文件系统路径、错误元素类型和非脚本资源都会被视为配置错误；默认会中断初始化，迁移期才应临时关闭 `gf/project/fail_on_installer_error`。

`scope` 是本轮安装的协作取消边界。`GFAsyncScope` 继承自 `GFCancellationToken`，因此可以直接传给只需要读取取消状态的 helper。Installer 等待外部资源、网络、编辑器回调或多帧扫描时，应在每个 `await` 后检查 `scope.is_cancel_requested()`；需要释放临时连接、后台句柄或外部请求时，用 `scope.register_cleanup(callback)` 登记无参清理回调。初始化失败、架构释放、超时或局部上下文退出树时，框架会取消 scope 并按后进先出的顺序执行清理。

`install()` 和 `install_bindings()` 都可以在内部使用 `await`，但首个 `await` 之前仍运行在主线程。需要等待外部资源、网络或编辑器回调时，可以用 `gf/project/installer_timeout_seconds` 限制单步等待时间；长同步扫描或解析应拆成让帧步骤，避免超时检测被同步段阻塞。

## 原子提交与 Gf facade 边界

`await Gf.set_architecture(candidate)` 会先把 `candidate` 作为未提交候选运行 Installer 和三阶段初始化，全部成功后才原子替换当前全局架构。在候选提交点之前，`Gf.has_architecture()`、`Gf.get_architecture()` 和其他 `Gf` facade 入口只观察先前已经提交的架构；若此前没有架构，则仍观察为空。提交点会先完成 assignment scope，再同步发布 identity 通知，最后让外层调用返回 `true`；identity listener 因而可以在外层返回前观察新架构，并把其中发起的 replacement 作为独立后续事务提交。

因此，Installer 必须使用 `install(architecture, scope)` 收到的 `architecture` 参数或 `install_bindings(binder, scope)` 收到的 `binder` 注册候选模块。不要在 Installer 中用 `Gf.register_*()`、`Gf.create_binder()` 或 `Gf.get_*()` 隐式访问候选架构；这些入口在替换期间仍属于旧架构。

如果 pending assignment 被更新的 `set_architecture()`、尚无已提交架构时由 `Gf.create_architecture()` 创建的默认架构，或 Gf 退出场景树替代，框架会取消本轮 `scope`、执行已登记的 cleanup，并 dispose 尚未提交的候选架构。每个异步检查点都应检查 `scope.is_cancel_requested()`；即使 Installer 已返回，只要保留的公开 scope 在候选初始化期间被取消或提前 `complete()`，本轮 assignment 也会清除 pending 状态、拒绝提交并释放未提交候选。被替代的调用返回 `false` 后，不要复用该候选，重试时创建新的 `GFArchitecture`。

同一个候选已经处于 pending 时，再次调用 `set_architecture(candidate)` 会立即返回 `false`，但不会取消、dispose 或抢占原 assignment；原调用仍是唯一有权提交该候选的事务。不同候选的更新 assignment 会使旧事务失效。旧架构 `dispose()` 或候选生命周期回调中的重入也遵守同一 serial 规则，只有最后一次有效 assignment 能提交。成功提交会先清除 pending、解除 scope 跟踪并调用 `scope.complete()`，再发布全局 identity 通知；因此 identity listener 发起的 replacement 是一笔独立后续事务，不会倒过来执行已成功 assignment 的取消 cleanup。

`DISPOSING` / `DISPOSED` Architecture 不能作为新 candidate，也不能重新 `init()`。旧架构同步释放回调期间，`Gf.create_architecture()` 与依赖它的注册、替换、binder/factory helper 会分别返回 `null` 或 `false`，不会暴露正在释放的旧实例或创建瞬态默认架构。Gf 退出树期间采用相同的 fail-closed 规则。若项目在事务之外直接 dispose 当前全局 identity，下一次 `create_architecture()` 会先发布该 terminal identity 被清除的通知，再创建全新的默认架构；绝不会复活旧实例。

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
