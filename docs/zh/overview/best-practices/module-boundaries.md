# 模块边界

GF 项目中，依赖读取、Model、System 和 Controller 的职责应保持明确。缺失依赖要在调用点显式处理，核心状态不要落到场景节点或 Controller 上。

## 机制与策略

GF 更适合承载稳定机制，例如生命周期、依赖读取、数据容器、校验、编码、迁移、查询和通用调度；项目策略应留在项目层，例如任务奖励、物品含义、关卡编排、对话语义、AI 行动执行、UI 文案和存档 schema。

如果项目或多个扩展反复绕开同一个 GF 能力，先把它当作边界审查信号，而不是自动把代码上移到框架层。需要区分重复的是稳定机制、扩展点不足、API 使用成本、文档缺口，还是项目自己的业务策略。稳定机制可以收敛到 Standard 或专门扩展；业务策略应继续留在项目层，或者从 GF 中拆薄。

## 依赖读取

从架构读取模块后立即做类型断言，并显式处理缺失依赖：

```gdscript
var inventory := Gf.get_model(InventoryModel) as InventoryModel
if inventory == null:
	push_error("InventoryModel is not registered.")
	return
```

不要把依赖缺失隐藏到后续属性访问错误里。查询可能失败，就在调用点处理 `null`。

## Model

`GFModel` 不应只剩字段。它至少应封装状态修改入口、快照恢复和必要的校验边界。

```gdscript
class_name WalletModel
extends GFModel


var coins: int = 0


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount


func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	return true
```

复杂规则仍应放在 `GFSystem`。Model 负责维护数据一致性，System 负责协调规则、事件和跨模块流程。

## System

`GFSystem` 处理业务流程、事件、命令、查询和逐帧逻辑。System 可以读取和修改 Model，也可以调用 Utility，但不应直接持有具体 Controller 或场景节点引用。

如果 System 需要驱动表现，发送事件或写入可绑定状态，由 Controller 监听后更新 UI、动画或场景对象。

## Controller

`GFController` 是场景树和架构之间的桥。它可以读取 Model、调用 System、监听事件和绑定变化，但应能随场景销毁而安全释放。

Controller 不应保存核心业务状态。场景切换、UI 关闭或节点释放后仍必须存在的数据，应放在 Model 或项目自己的存档结构中。

使用宿主节点时优先依赖 `host_node_path`、`get_host()`、`get_host_as()` 或默认父节点宿主，不要在多个 Controller 中重复写脆弱的节点路径查找。
