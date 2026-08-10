# 编辑器模板与结构校验

编辑器菜单提供 `工具 > GF > 生成 NodeState` 与 `工具 > GF > 生成 NodeStateMachine` 模板，适合快速建立节点状态脚本。

两份模板由 `gf.standard.state_machine.editor` 包物理拥有，中央标准库编辑器贡献清单只负责索引。菜单会从目标文件名推导 `class_name`，并在任何写入前同时验证该名称与模板 `base_class` 都是合法 GDScript 标识符；非法文件名或基类会以零输出失败，已有文件也不会被覆盖。

选中 `GFNodeStateMachine` 时，Inspector 会从直接子状态中提供初始状态选择，减少手填状态名带来的拼写错误。

该列表读取状态节点导出的 `state_name`，为空时退回节点名，不要求状态脚本声明 `@tool`。

Inspector 也提供结构验证入口，底层使用 `GFNodeStateMachineValidator` 返回 `GFValidationReport`。它会检查空状态机、重复状态组、同组重复状态名、缺失或无效初始状态，以及 `enter_conditions`、`exit_conditions`、`behaviors` 中空槽位或缺少约定方法的资源。

`GFNodeStateMachine` 与 `GFNodeStateGroup` 会在编辑器 Inspector 的配置警告中复用同一份校验结果。添加或移除直接子状态、状态组，或修改初始状态等关键属性后，编辑器会刷新警告；这些提示只读取结构和导出属性，不会在编辑器中创建运行时内部状态组，也不会启动状态。

编辑器校验只读取 `state_name`、`group_name`、`initial_state` 和资源数组这类导出属性，不调用项目状态脚本的 `get_state_name()` 或状态组脚本的 `get_group_name()`；运行时动态覆盖这些方法仍只影响运行时行为。

GF 工作区中的 `GFNodeStateMachineDock` 会扫描当前场景里的状态机，集中展示校验摘要和问题列表，适合在大型场景中快速切换检查对象。

它仍然只复用标准结构校验，不推断项目自己的状态跳转表、动画命名或输入语义。

```gdscript
var report := GFNodeStateMachineValidator.validate_machine($StateMachine)
if not report.is_ok():
	print(report.make_summary("Player StateMachine"))
```

该校验器只检查框架结构是否自洽，不要求项目把状态转移表写进资源，也不会推断“巡逻”“攻击”“死亡”等业务状态是否可达。

项目可以在编辑器工具、CI 或自定义诊断命令中复用它；需要更严格规则时，可读取报告中的 `issues` 后叠加项目自己的检查。
