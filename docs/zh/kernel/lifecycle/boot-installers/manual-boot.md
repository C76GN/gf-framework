# 手动启动注册

在游戏启动之初，通常在根节点的首个场景或 AutoLoad 执行，项目可以手动向 `GFArchitecture` 注册模块。按 Model、Utility、System 分组能提高可读性，但真正的生命周期顺序来自模块声明依赖 DAG，不由注册顺序隐式表达。

```gdscript
# boot.gd
func _ready():
	# 1. 注册核心数据
	await Gf.register_model(PlayerModel.new())
	await Gf.register_model(InventoryModel.new())

	# 2. 注册底层工具
	await Gf.register_utility(GFStorageUtility.new())
	await Gf.register_utility(GFAssetUtility.new())

	# 3. 注册业务逻辑系统
	await Gf.register_system(BattleSystem.new())
	await Gf.register_system(QuestSystem.new())

	# 全部注册完毕后，编译依赖 DAG 并完成四阶段激活。
	if not await Gf.init():
		return

	# init() 返回成功时，架构才已开放运行时准入。
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

手动 boot 适合小型项目、原型和希望显式控制装配入口的工程。模块仍应通过 `get_required_*()` 声明依赖；需要在 READY 提交前等待的 bootstrap 放进项目 System 的 `begin_activation()`。项目规模扩大后，可以把装配逻辑迁移到项目级 Installer。
