# Ready 与上下文等待

表现层 Controller 依附于 Godot 原生场景树，继承自 `Node`。它们的初始化仍由 Godot `_ready()` 触发，不属于 `GFModel`、`GFSystem`、`GFUtility` 的四阶段生命周期。

## 初始化与绑定

Controller 的 `_ready()` 中通常执行以下操作：

1. 获取场景节点引用。
2. 等待架构上下文 ready。
3. 从架构获取需要的 Model 或 System。
4. 绑定关注的数据属性。
5. 更新初始显示状态。

```gdscript
## 在上下文就绪后将玩家生命值投影到场景内的进度条。
class_name HUDController extends GFController

## 由 HUD 场景拥有的显示节点，不属于架构生命周期模块。
@onready var hp_bar: ProgressBar = $HealthBar

## 失败等待直接停止初始化，避免从未激活的上下文读取模型。
func _ready() -> void:
	var architecture: GFArchitecture = await wait_for_context_ready()
	if architecture == null:
		return
	var user_model := architecture.get_model(UserModel) as UserModel

	user_model.health.value_changed.connect(_on_health_changed)
	_on_health_changed(null, user_model.health.get_value())

## 只刷新表现层；绑定后的首次调用用于显示当前值。
func _on_health_changed(_old_value: Variant, new_val: Variant) -> void:
	hp_bar.value = new_val
```

如果 Controller 依赖局部架构，等待上下文 ready 能避免节点 `_ready()` 早于架构完成第四阶段时读取到未激活模块。`GFNodeContext.context_ready` 只在 Architecture 已提交 READY 后发出；第三阶段模块 ready 不会提前唤醒 Controller。
