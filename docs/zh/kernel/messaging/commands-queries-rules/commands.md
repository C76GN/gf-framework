# GFCommand 写操作

`GFCommand` 代表一次可执行的指令。它的意图是改变 Model 的数据状态或触发一系列副作用任务。

Command 应被设计成业务上的最小写操作单元。框架负责依赖注入和调用 `execute()`，但不提供数据库式事务、自动回滚、幂等保护或失败隔离；如果流程需要失败策略、顺序等待或可选回滚，应使用 `GFCommandSequence`、Flow 或项目层 System 编排。

## 创建命令

继承并重写 `execute()` 抽象方法：

```gdscript
## 一次伤害结算的写命令；通过架构发送以取得当前上下文依赖。
class_name TakeDamageCommand extends GFCommand

## 本次结算的目标标识，由发送方在执行前设置。
var target_id: String

## 本次输入伤害，不与其他命令实例共享执行参数。
var raw_damage: int

## 在注入的架构中查找目标并写入生命值；不提供自动回滚。
func execute() -> Variant:
	# 实例代理使用注入的架构；局部命令不应绕过它查询全局模块。
	var battle_model := get_model(BattleModel) as BattleModel

	var ent := battle_model.get_entity(target_id)
	if ent:
		var final_dmg = raw_damage - ent.defense
		ent.health -= max(1, final_dmg)
	return null
```

## 执行命令

只要获得了命令定义，在控制器或系统内部都可以通过架构发送：

```gdscript
# 在 UI 层按下攻击键后
var c = TakeDamageCommand.new()
c.target_id = "monster_99"
c.raw_damage = 999
Gf.send_command(c)
```

`Gf.send_command()` 会先向命令注入当前 `GFArchitecture`，再调用 `execute()`。只有当命令完全不依赖 `get_model()`、`get_system()`、`get_utility()` 这类框架访问时，才建议直接调用 `c.execute()`。

在存在 `GFNodeContext` 局部上下文的项目里，依赖框架对象的 Command 不应直接 `new().execute()`；未注入的命令会回退到全局架构，可能拿错局部场景的数据。
