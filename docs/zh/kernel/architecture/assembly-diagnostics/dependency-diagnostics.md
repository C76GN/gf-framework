# 依赖诊断

`GFArchitecture.get_dependency_diagnostics()` 可读取已注册模块的声明依赖并生成统一报告。它适合大型项目、局部 `GFNodeContext` 或插件式装配在初始化前预检“模块声明需要什么、当前候选架构能否满足”。

诊断调用本身只读，不会自动注册缺失模块，也不会改变 `get_model()`、`get_system()`、`get_utility()` 和工厂创建的解析语义。依赖声明本身则是强生命周期契约：`GFArchitecture.init()` 会无条件校验，缺失、非法或歧义依赖会让初始化 fail closed，不提供降级为 warning 的运行时开关。

## 必需查询与可选查询

模块真正依赖某项能力时使用 `get_model()`、`get_system()` 或 `get_utility()`。开启 `strict_dependency_lookup` 后，这些入口只接受当前架构中的注册项，并会报告本地缺失；它们适合让错误装配尽早失败。

能力只是可选集成时使用 `find_model()`、`find_system()` 或 `find_utility()`。三者与普通查询共用类型、alias、ready 和父链解析规则，唯一差异是未找到时不报告 required miss：非严格模式仍可回退父架构，严格模式仍停止在当前架构，但静默返回 `null`。

```gdscript
var console_value: Variant = architecture.find_utility(GFConsoleUtility)
if console_value is GFConsoleUtility:
	var console: GFConsoleUtility = console_value
	# Console 存在时才绑定可选命令。
```

required/optional 是每个消费点的语义，不能固化到全局类型注册记录。同一个 Utility 可以被某个模块视为必需依赖，同时被另一个诊断或编辑器集成视为可选能力。

## 依赖声明

模块可按需实现这些 hook：

```gdscript
func get_required_models() -> Array[Script]:
	return [PlayerModel]

func get_required_utilities() -> Array[Script]:
	return [InventoryConfigUtility]

func get_required_systems() -> Array[Script]:
	return [BattleSystem]

func get_required_factories() -> Array[Script]:
	return [DealDamageCommand]
```

四个按类别返回 `Array[Script]` 的 Hook 是生命周期计划和依赖诊断的唯一事实源；不存在额外的聚合 Hook 或由诊断参数补充、删减声明类别的兼容路径。Model、System、Utility 声明会用于编译本地生命周期 DAG，并按 exact 注册键、alias、唯一 assignable 与允许的父架构解析；factory 依赖只校验 exact binding availability 与允许的父级，不实例化对象，也不成为 DAG 节点。

本地 stale alias 或多个 assignable 匹配都是解析失败屏障，不会继续回退父架构；只有完整的本地 miss 才能在非严格模式向上查找。父级依赖仅在对应父 Architecture 已提交 READY 时有效；Model、System、Utility 还必须已经 ACTIVE，factory 则要求父级存在 exact binding。父级命中的依赖只记为 external satisfaction，不进入当前架构的本地 DAG；`strict_dependency_lookup` 会禁止所有类别的父级满足。

计划编译成功后、执行计划内模块的初始化与 activation Hook 前，框架会为实际命中的父级 required module/factory 建立弱租约。外部模块租约阻止相关父级改变模块拓扑，所有外部依赖租约都会使父级正常 `shutdown_async()` 在改变状态前以 `ERR_BUSY` 失败，直到 child 初始化失败或先完成关闭。租约不让 parent 接管 child，也不会触发级联关闭；生命周期所有权必须继续与依赖方向一致：先启动父架构，再初始化子架构；先关闭子架构，再关闭父架构。

有效 DAG 决定四阶段的依赖优先顺序，并保存严格逆序的 quiesce/shutdown 顺序。`lifecycle_priority` 只用于多个 DAG-ready 节点的稳定破平，不能覆盖真实依赖边。以下情况会直接拒绝计划：

- 声明的依赖不存在，或 assignable 匹配不唯一。
- 任一 typed Hook 返回值不是约定的 `Array[Script]` 形状。
- 本地模块之间存在依赖循环，包括自环。
- 热注册、替换或注销后的候选拓扑不再满足任一声明。

生命周期计划只编译一次候选快照，再按计划推进；初始化期间不能靠 Hook 动态注册新模块，也不提供可配置的多轮补跑。热注册和热替换都只在 staged candidate 快照中求值，只有 stage4 成功后才原子发布 registry 与活动计划；候选诊断成功本身不会让新实例可见。固定模块应在 Installer 阶段注册，活动架构的有意变化使用热模块事务。

## 诊断调用

```gdscript
var report := architecture.get_dependency_diagnostics()
if not report["ok"]:
	for issue in report["issues"]:
		push_warning(issue["message"])
```

报告固定按四类 typed Hook 和架构本身的 `strict_dependency_lookup` 生成。调用方不能用 `include_parent_lookup` 或 `include_factories` 改变校验语义；初始化会执行同一份强契约，因此显式诊断主要用于编辑器、启动前报告和测试断言，不是绕过初始化失败的恢复入口。缺失依赖应在装配处修复；真正可选的集成不要写入 required Hook，而应在消费点使用 `find_model()`、`find_system()` 或 `find_utility()`。

## 绑定图诊断

`get_dependency_diagnostics()` 面向“模块声明的依赖是否满足”。如果需要排查当前架构实际注册了什么、别名是否指向有效目标、工厂是什么生命周期、scoped 架构会回退到哪些父级，可以读取 `get_binding_diagnostics()`：

```gdscript
var bindings := architecture.get_binding_diagnostics({
	"include_entries": true,
	"include_parent_chain": true,
})

for issue in bindings["issues"]:
	push_warning(issue["message"])
```

绑定图诊断同样只读，不会触发工厂实例化，也不会调用 `get_model()` / `get_utility()` 这类查询入口。它适合编辑器面板、调试命令、局部 `GFNodeContext` 自检和测试断言。

父级架构链会通过 visited guard 遍历。正常入口 `set_parent_architecture()` 会拒绝自引用和循环引用；如果内部状态被维护代码或测试辅助破坏，运行时父级查找会停止并输出错误，`get_binding_diagnostics()` 会返回 `parent_chain_cycle_detected=true` 和 `parent_chain_cycle` issue。`get_dependency_diagnostics()` 在解析声明式依赖时遇到同类腐坏链，会使用 `dependency_parent_chain_cycle`，避免把父链循环误读成普通缺失依赖。

## 使用边界

依赖声明应保持抽象和稳定，优先声明模块真正需要的接口脚本、基类或别名类型；不要把具体关卡、敌人、UI 页面或临时玩法条件写进通用模块 Hook。

需要按玩家进度、DLC、服务器配置或场景状态动态判断的内容，应留在项目自己的装配流程或诊断命令里。
