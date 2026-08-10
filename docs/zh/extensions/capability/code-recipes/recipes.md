# 能力组合 Recipe

当项目希望把一组能力作为可复用配置应用到不同 receiver，可以使用 `GFCapabilityRecipe`。Recipe 只描述能力条目、默认启停和分组，不规定实体类型、属性字段或玩法规则。

```gdscript
var recipe := GFCapabilityRecipe.new()
recipe.recipe_id = &"interactable_target"
recipe.groups = [&"targets"]

var entry := GFCapabilityRecipeEntry.new()
entry.capability_type = InteractableCapability
entry.active = true
recipe.entries = [entry]

var result := capabilities.apply_recipe(enemy, recipe)
if not result["ok"]:
	push_warning(result["failed"])
```

`GFCapabilityRecipeEntry` 可以通过 `capability_type` 创建普通能力，也可以通过 `scene` 挂载节点能力场景；如果两者都提供，运行时会实例化场景并按 `capability_type` 注册，但场景根节点的实际脚本必须继承或等于该 `capability_type`。声明类型不匹配的场景能力会被拒绝，不会进入 receiver 的能力索引。Inspector 的 Recipe 应用也读取实例化后的实际根脚本执行同一校验，并使用实际脚本做去重、命名和报告，不能用合法声明类型替无关场景根“冒充”能力。

应用前可先调用 `validate_recipe_report()` 获取 `GFValidationReport`，或调用 `validate_recipe()` 获取序列化后的 Dictionary。报告会用 `entries[0]`、`groups[1]` 这类稳定 path 定位空条目、无效条目、重复条目、空分组和重复分组。空分组和重复分组只作为 warning；无效条目会作为 error，避免运行时留下不完整组合。

`apply_recipe()` 默认会在应用后调用依赖校验，并把新增、复用、失败条目和分组写入报告。默认 `transactional = true`，任一条目失败或依赖校验失败时，会移除本次新增能力、回滚本次新增分组，并恢复被复用能力的原 active 状态，避免留下半应用的实体预设。

确实需要“尽力应用”的工具流程，可在 options 中显式传 `{ "transactional": false }`。当前 `remove_recipe()` 按 Recipe 描述的当前类型和分组执行移除；它不是某次 `apply_recipe()` 的 receipt，也不会区分条目是该次新增、此前复用还是后来由其他系统取得所有权。需要“只撤销这一笔应用贡献”的项目在框架确定 receipt/lease 契约前，应自行保存明确所有权记录，不要把 `remove_recipe()` 当成精确逆操作。

复杂实体预设应保持为项目资源，不应把具体敌人、卡牌、任务或 UI 规则写进 GF 能力基类。
