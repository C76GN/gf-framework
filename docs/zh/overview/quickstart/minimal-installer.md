# 最小启动与 Installer

最小启动只需要注册实际使用的服务、初始化架构，再取回服务。下面先完成一个不需要 Model、System 或 Command 的小任务，再介绍集中装配。

## 从状态到保存、读回与退出

先运行[计数、保存、读回与退出](counter-save-exit.md)中的完整场景脚本：它只注册 Storage，用原生控件演示修改状态、保存、读回和受控退出，不需要先创建 Model、System 或 Command。

## 何时迁移到项目模块与局部 Context

只有计数需要跨场景共享或规则需要独立测试时，再把它移到项目会话或 `GFModel`，把修改规则放到项目自己的模块。Storage 应由项目 Installer 统一注册并复用，Boot 只初始化一次；普通场景离开不关闭全局 Architecture，应用退出才由长期存在的启动/退出入口关闭它。

战斗房间或并行实例确实需要独立模块生命周期时，再使用 scoped `GFNodeContext`。局部 `GFUIUtility` 在注册前调用 `configure_host(context)`；跨树显示时传入 `mount_parent`，不要靠显示父链推断业务来源。离场顺序为：停止新业务操作 → 等待保存的确定结果 → `await context.close_async()` → 核对目标仍属于本次离场请求 → 分别检查 `is_closed()` 与 `is_drained()` → 移除节点。`is_closed() == false` 时应先处理外部依赖再重试；已关闭但未排空不能被当成保存成功。完整的来源绑定、关闭和失败处理见[节点上下文](../../kernel/lifecycle/node-contexts.md#正常关闭与离树兜底)与[局部 UI](../../standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/panel-stack.md#节点父链与场景生命周期)。

## 按需添加 Model 与 System

没有共享业务状态或独立规则时，局部状态可以继续留在 Node 或项目会话中。下例说明需要 Model、System 后的装配方式；`PlayerModel` 和 `BattleSystem` 是项目自行定义的类型。

```gdscript
# 装配流程片段：由尚未初始化 GF 的启动入口执行，项目类型需自行定义。
extends Node


## 任一注册或初始化失败都停止；仅在架构开放运行时准入后查询业务模块。
func _ready() -> void:
	if not await Gf.register_model(PlayerModel.new()):
		return
	if not await Gf.register_utility(GFStorageUtility.new()):
		return
	if not await Gf.register_system(BattleSystem.new()):
		return

	if not await Gf.init():
		return

	var player_model := Gf.get_model(PlayerModel) as PlayerModel
	var battle_system := Gf.get_system(BattleSystem) as BattleSystem
	if player_model == null or battle_system == null:
		push_error("GF 模块查询失败。")
		return
	battle_system.start_encounter(player_model)
```

这个例子表达的是最小流程：

1. 注册 `GFModel`、`GFUtility` 和 `GFSystem`。
2. 调用 `await Gf.init()` 编译声明依赖 DAG，并完成 `init()`、`async_init()`、`ready()`、`begin_activation()` 四阶段。
3. 只在返回成功、架构开放运行时准入后取回模块；使用 `as Type` 保留补全和显式失败处理。

真实项目通常不会把所有注册写在某个场景 `_ready()` 里，而是使用 Installer。

## 使用 Installer

如果项目需要统一装配，可以创建 `GFInstaller`：

```gdscript
## 项目装配入口：只注册模块，玩法启动由初始化成功后的引导流程负责。
class_name GameInstaller
extends GFInstaller


## 每次等待后先响应本轮安装取消，再决定是否继续注册或报告初始化失败。
func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var model_registered: bool = await architecture.register_model_instance(PlayerModel.new())
	if scope.is_cancel_requested():
		return
	if not model_registered:
		architecture.fail_initialization("PlayerModel 注册失败。")
		return

	var utility_registered: bool = await architecture.register_utility_instance(GFStorageUtility.new())
	if scope.is_cancel_requested():
		return
	if not utility_registered:
		architecture.fail_initialization("GFStorageUtility 注册失败。")
		return

	var system_registered: bool = await architecture.register_system_instance(BattleSystem.new())
	if scope.is_cancel_requested():
		return
	if not system_registered:
		architecture.fail_initialization("BattleSystem 注册失败。")
		return
```

然后把安装器脚本加入 `Project Settings > gf/project/installers`。编辑器可保存 `res://` 或稳定 `uid://` 引用；GF 会在启动时解析并严格校验。调用 `await Gf.init()` 时，GF 会先运行启用扩展的 Installer，再运行项目 Installer，随后冻结拓扑、编译依赖 DAG 并完成四阶段生命周期。初始化返回 `false` 时必须停止后续查询，并读取 `Gf.get_architecture().last_initialization_error`。

Installer 只负责注册模块，不应该直接启动关卡、打开 UI 或执行玩法流程。必须在 READY 前完成的异步 bootstrap 放在声明依赖的项目 `GFSystem.begin_activation()`；架构 READY 后的关卡、UI 与玩法流程更适合由引导场景或项目状态机驱动。
