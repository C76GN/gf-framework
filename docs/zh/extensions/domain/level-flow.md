# 关卡流程

Domain 扩展中的 `GFLevelUtility` 面向有固定关卡概念的项目，用于统一处理开始、重开、胜利、失败，并在重开时执行项目显式注册的运行时清理回调。

## 基础流程

```gdscript
var level := Gf.get_utility(GFLevelUtility) as GFLevelUtility

# 默认读取 GFConfigProvider 的 "levels" 表，也可以切换表名
level.configure(&"levels")

level.level_started.connect(func(level_id: Variant, data: Dictionary) -> void:
	print("Start level: ", level_id, data)
)

level.start_level(1)
level.restart_level()
level.win_current_level()
```

它只处理通用关卡流程边界，不负责生成地图、刷怪或胜负条件判断；这些具体玩法规则仍应放在项目自己的 `System` 中。

重开关卡时，它会重新读取配置或启动时传入的 override 数据副本，并执行 `register_runtime_cleanup()` 注册的清理回调。Domain 扩展不会主动探测命令历史、ActionQueue 或其他可选扩展；项目需要清理哪些运行时残留，就显式注册哪些回调：

```gdscript
var actions := Gf.get_system(GFActionQueueSystem) as GFActionQueueSystem
level.register_runtime_cleanup(&"action_queue", func() -> void:
	actions.clear_queue(true)
	actions.clear_all_named_queues(true)
}, 100)
```

清理回调由 `GFRuntimeCleanupScope` 按 `priority` 从高到低执行。同一个 `cleanup_id` 重新注册会替换旧回调，`unregister_runtime_cleanup()` 返回是否实际移除了对应项。项目如果使用命令历史，也应像其他系统一样注册自己的清理回调，而不是依赖 Domain 默认认识某个具体工具。

## 关卡目录

如果项目更适合用资源描述关卡列表，可以把 `GFLevelCatalog` 交给 `GFLevelUtility`。目录条目由 `GFLevelEntry` 描述，只保存稳定 ID、扩展 ID、场景路径、排序、元数据和完成后声明式解锁列表，不绑定具体玩法内容：

```gdscript
var catalog := GFLevelCatalog.new()
var level_entry := GFLevelEntry.new()
level_entry.level_id = &"level_1"
level_entry.scene_path = "res://levels/level_1.tscn"
catalog.add_entry(level_entry)

level.set_catalog(catalog)
level.start_level(&"level_1")
level.complete_current_level({ "stars": 3 })
level.start_next_level()
```

注册 `GFLevelProgressModel` 后，`complete_current_level()` 会写入完成状态、保存项目层结果字典，并按目录顺序或条目声明解锁后续关卡。进度模型可直接进入 `GFArchitecture` 的模型快照流程。

未注册 `GFLevelProgressModel` 时，`is_level_unlocked()` 会返回 `true`，方便没有关卡锁的项目继续使用流程信号。

`start_level(level_id, override)` 会优先使用传入的 override 数据；`restart_level()` 会重新复制这份 override 或重新读取配置表，避免运行时修改污染下一次重开。`level_started` / `level_restarted` 信号会发出关卡数据副本，监听者修改参数字典不会污染 `current_level_data`。

默认找不到关卡数据时仍允许以空字典启动，便于原型流程；正式项目可设置 `fail_on_missing_level_data = true`，缺失数据时拒绝更新当前关卡并输出错误。
