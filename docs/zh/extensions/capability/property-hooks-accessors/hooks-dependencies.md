# 能力 Hook 与依赖

能力实例可选择实现以下方法：

```gdscript
## 注册已提交、依赖已补齐后调用；此时可通过 receiver 查询同对象上的能力。
func on_gf_capability_added(receiver: Object) -> void:
	pass

## 注册记录摘除后释放项目接线；能力仍有效且声明 receiver 字段时，框架随后清空该字段。
func on_gf_capability_removed(receiver: Object) -> void:
	pass

## 接收已提交的启停状态，用于同步项目局部表现或行为。
func on_gf_capability_active_changed(receiver: Object, active: bool) -> void:
	pass

## 默认回收仅由当前能力自动补齐、且已无其他使用者的依赖。
func get_dependency_removal_policy() -> int:
	return GFCapabilityUtility.DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES

## 从所属架构注入项目协作对象；能力之间的依赖仍使用 required_capabilities。
func inject_dependencies(architecture: GFArchitecture) -> void:
	pass
```

依赖声明不是 Hook，优先写入 `required_capabilities`。基类的 `get_required_capabilities()` 默认会返回这个数组。

只有确实需要运行时动态依赖时，才建议重写 `get_required_capabilities()`；编辑器 Inspector 不会调用该方法。

继承 `GFCapability`、`GFNodeCapability`、`GFNode2DCapability`、`GFNode3DCapability` 或 `GFControlCapability` 时这些方法已有默认实现。

自定义 Node 能力不强制继承特定基类，只要实现需要的 Hook 也能被运行时识别；但需要编辑器添加与统一补全时，推荐继承最匹配的 GF 能力基类。
