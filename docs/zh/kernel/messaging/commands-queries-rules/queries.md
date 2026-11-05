# GFQuery 读操作

`GFQuery` 封装跨模块读取和派生数据。它适合把表现层不应该知道的组合逻辑从 Controller 或 UI 中移走。

当某个读取结果需要组合多个底层模型时，例如属性面板同时读取 `PlayerModel`、`BuffModel` 和 `EquipmentModel`，可以把这类派生读取封装成 `GFQuery`。

## 创建查询

Query 代表读操作。它的返回值应当是安全的，不应在 `execute()` 内部修改状态或数据。框架不会强制只读隔离；是否修改 Model、发送事件或调用 System，仍由项目代码规范保证。

```gdscript
## 汇总多个模型的攻击力，只派生读取结果，不修改来源状态。
class_name GetPlayerTotalAttackPowerQuery extends GFQuery

## 返回基础、装备和增益共同决定的攻击力；所需模型由调用架构提供。
func execute() -> Variant:
	var raw_atk = (get_model(PlayerModel) as PlayerModel).base_atk
	var wpn_atk = (get_model(EquipmentModel) as EquipmentModel).get_equipped_weapon_atk()
	var buff_atk_pct = (get_model(BuffModel) as BuffModel).get_global_atk_buff()

	return (raw_atk + wpn_atk) * (1.0 + buff_atk_pct)
```

## 执行查询

通常控制器表现层会发出查询获取数据再做展示：

```gdscript
## 此写法明确读取全局架构；局部 Controller 应改用自身的 send_query 代理。
func update_attack_power_ui() -> void:
	var final_atk = Gf.send_query(GetPlayerTotalAttackPowerQuery.new()) as float
	$UI/AttackLabel.text = str(final_atk)
```

简单数值可以直接返回；复杂查询建议返回专门的结果对象或 `GFPayload` 子类，避免调用方长期依赖裸 `Dictionary` 或不明确的 `Variant` 结构。

`send_query()` 可以出现在 `tick()`、状态机 `update()` 或 UI 刷新路径里，但它不是“必须经过”的读取方式。Query 适合封装跨多个 Model/System 的派生读取、权限检查或表现层不应该知道的组合逻辑。

如果每帧只读同一个 Model 上的简单字段，建议在 `ready()`、`enter()` 或状态初始化时缓存对应 Model/Utility 引用，再直接读取字段或调用轻量方法。不要在热路径里反复 `new()` 查询对象；可复用的无状态 Query 可以预先创建，或直接把读取逻辑下沉到 Model/System 的稳定接口中。

在 `GFController`、`GFCommand`、`GFState` 这类已经拥有架构上下文的对象里，优先使用自身的 `send_query()` / `send_command()` 代理，而不是全局 `Gf.send_query()` / `Gf.send_command()`。这样在 `GFNodeContext` 局部架构下，查询会命中当前上下文的模块；全局 `Gf` 只适合明确访问全局架构的代码。
