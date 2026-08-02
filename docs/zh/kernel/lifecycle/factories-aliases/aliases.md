# 别名注册与抽象获取

当项目有多个具体实现，但调用方只应依赖抽象基类或协议类型时，可以用 alias 把抽象类型映射到具体注册类型。

## 直接按别名注册

```gdscript
class_name JSONConfigProvider
extends GFConfigProvider
```

```gdscript
func _ready() -> void:
	await Gf.register_utility_as(JSONConfigProvider.new(), GFConfigProvider)

	var configs := Gf.get_utility(GFConfigProvider) as GFConfigProvider
```

## 注册后登记别名

```gdscript
func _ready() -> void:
	await Gf.register_utility(JSONConfigProvider.new())
	Gf.register_utility_alias(GFConfigProvider, JSONConfigProvider)
```

当未命中精确类型或 alias 时，框架会尝试寻找唯一的继承匹配。如果多个实例都继承同一个基类，会返回 `null` 并给出警告。此时应使用显式 alias 消除歧义。

## 使用边界

`Model`、`System` 与 `Utility` 的注册表遵循同一套规则：重复注册会被忽略并提示使用 `replace_*()`；同一实例不能用多个脚本键重复注册；`unregister_*()` 只注销直接注册键，删除 alias 应使用 `unregister_*_alias()`，且不会释放目标实例；注册表变化后继承匹配缓存会失效。

显式 alias 会校验 `target_cls` 必须继承或等于 `alias_cls`。无关类型会被拒绝，避免 `get_utility(AbstractType)` 返回无法强转的实例。

本地解析只有在精确键、alias 和可赋值实例都完全未命中时，非严格架构才可以继续查询父架构。以下两种结果都是父级 fallback barrier：

- alias 已存在但目标注册项缺失；该 stale alias 会报告错误，且不会改找本地可赋值实例或父级实例。
- 本地存在多个可赋值实例；该歧义会返回 `null`，且不会由父级同类型实例掩盖。

普通 `get_*()`、可选 `find_*()` 查询与声明式依赖计划遵循同一屏障语义。项目层应保持注册键、alias 和实际实例类型一致，并用显式 alias 消除合法的多实现歧义。
