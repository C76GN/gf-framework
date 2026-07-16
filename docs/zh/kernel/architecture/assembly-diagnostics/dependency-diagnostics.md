# 依赖诊断

`GFArchitecture.get_dependency_diagnostics()` 可读取已注册模块的可选依赖声明，并生成统一报告。它适合大型项目、局部 `GFNodeContext` 或插件式装配在初始化前后检查“模块声明需要什么、当前架构是否已经注册”。

诊断只读，不会自动注册缺失模块，也不会改变 `get_model()`、`get_system()`、`get_utility()` 和工厂创建的现有语义。

## 依赖声明

模块可按需实现这些 hook：

```gdscript
func get_required_models() -> Array[Script]:
	return [PlayerModel]

func get_required_utilities() -> Array[Script]:
	return [InventoryConfigUtility]

func get_required_dependencies() -> Dictionary:
	return {
		"systems": [BattleSystem],
		"factories": [DealDamageCommand],
	}
```

## 诊断调用

```gdscript
var report := architecture.get_dependency_diagnostics({
	"include_parent_lookup": true,
	"include_factories": true,
})
if not report["ok"]:
	for issue in report["issues"]:
		push_warning(issue["message"])
```

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

依赖声明应保持抽象和稳定，优先声明模块真正需要的接口脚本、基类或别名类型；不要把具体关卡、敌人、UI 页面或临时玩法条件写进通用模块 hook。

需要按玩家进度、DLC、服务器配置或场景状态动态判断的内容，应留在项目自己的装配流程或诊断命令里。
