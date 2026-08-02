# 最小启动与 Installer

最小启动只需要注册模块、初始化架构，再从架构取回需要的模块。

```gdscript
extends Node


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
class_name GameInstaller
extends GFInstaller


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
