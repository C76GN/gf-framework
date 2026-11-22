# GFQuery 读操作

`GFQuery` 封装跨模块读取和派生数据。它适合把表现层不应该知道的组合逻辑从 Controller 或 UI 中移走。

当某个读取结果需要组合多个底层模型时，例如属性面板同时读取 `PlayerModel`、`BuffModel` 和 `EquipmentModel`，可以把这类派生读取封装成 `GFQuery`。

## 创建查询

Query 表达读取意图。`get_model()` 取得实际的 Model，查询代码应只调用读取入口。给 UI 返回数值、独立的显示数据或只读视图，把修改操作留给拥有状态的模块。集合结果也要避免携带可修改原始状态的共享对象。

```gdscript
## 汇总多个模型的攻击力，只派生读取结果，不修改来源状态。
class_name GetPlayerTotalAttackPowerQuery extends GFQuery

## 返回基础、装备和增益共同决定的攻击力；所需模型由调用架构提供。
func execute() -> Variant:
	var player := get_model(PlayerModel) as PlayerModel
	var equipment := get_model(EquipmentModel) as EquipmentModel
	var buffs := get_model(BuffModel) as BuffModel
	if player == null or equipment == null or buffs == null:
		return null

	var attack: float = player.get_base_attack() + equipment.get_equipped_weapon_atk()
	return attack * (1.0 + buffs.get_global_atk_buff())
```

## 执行查询

通常控制器表现层会发出查询获取数据再做展示：

```gdscript
## 此写法明确读取全局架构；局部 Controller 应改用自身的 send_query 代理。
func update_attack_power_ui() -> void:
	var result: Variant = Gf.send_query(GetPlayerTotalAttackPowerQuery.new())
	$UI/AttackLabel.text = str(result) if result is float else "—"
```

每次发送都创建新的查询实例。已经执行的实例再次发送时会返回 `null` 并报告 `query.already_executed`，即使它没有成员变量。简单数值可以直接返回，多个字段可组成专门的只读结果。

`send_query()` 可以出现在 `tick()`、状态机 `update()` 或 UI 刷新路径里，但它不是“必须经过”的读取方式。Query 适合封装跨多个 Model/System 的派生读取、权限检查或表现层不应该知道的组合逻辑。

频繁刷新一个值时，可以在页面或状态进入时取得只读接口，或订阅所属 Model 发布的数值。页面退出时释放引用和订阅，重新进入时从当前架构获取。比如[钱包示例](../../../overview/best-practices/module-boundaries.md#model)的余额标签只需要一个整数，余额变化时再刷新即可。

在 `GFController`、`GFCommand`、`GFState` 这类已经拥有架构上下文的对象里，优先使用自身的 `send_query()` / `send_command()` 代理，而不是全局 `Gf.send_query()` / `Gf.send_command()`。这样在 `GFNodeContext` 局部架构下，查询会命中当前上下文的模块；全局 `Gf` 只适合明确访问全局架构的代码。
