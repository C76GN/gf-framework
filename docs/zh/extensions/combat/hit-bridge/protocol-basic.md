# 命中协议与基础接入

`GFHitBox2D` / `GFHitBox3D` 和 `GFHurtBox2D` / `GFHurtBox3D` 是可选的场景树桥接节点。它们只负责把 2D/3D 区域、射线或项目自己的检测结果转换为 `GFCombatHitContext` 并交给具备 `receive_hit()` 的接收器。

`GFCombatHitContext` 包含 `source`、`target`、`hit_id`、`payload`、`magnitude`、`tags`、2D/3D 位置和 `metadata`。这些字段都保持通用。

`GFHitScan2D` / `GFHitScan3D` 是同一套命中协议的射线桥接节点。它们继承 Godot 的 `RayCast2D` / `RayCast3D`，扫描到对象后构建 `GFCombatHitContext` 并调用目标的 `receive_hit(context)`；没有碰撞、目标为空或目标不支持接收时会返回统一失败报告。

框架仍然不定义穿透、射程衰减、命中特效、伤害或阵营规则，这些都应在项目自己的接收器、状态机或技能系统里表达。

## 基础发送与接收

```gdscript
var hit_box := GFHitBox2D.new()
hit_box.hit_id = &"impact"
hit_box.payload = {
	"amount": 10,
}

var hurt_box := GFHurtBox2D.new()
hurt_box.accepted_hit_ids = [&"impact"]
hurt_box.hit_received.connect(func(context: GFCombatHitContext, _report: Dictionary) -> void:
	# 项目层自行决定如何解释 context.payload。
	print(context.hit_id, context.payload)
)

var report := hit_box.send_to(hurt_box)
print(report["ok"])
```

命中报告用于日志、诊断和 UI 展示，`receiver` 字段是 JSON-safe 摘要，不携带 live `Object`。运行时要操作接收对象时，使用 `hit_sent` / `hit_accepted` / `hit_rejected` 信号的 `receiver` 参数，或读取 `GFCombatHitContext.target`。

## 2D 接入示例

```gdscript
@onready var hit_box: GFHitBox2D = $HitBox

func _ready() -> void:
	hit_box.area_entered.connect(_on_hit_box_area_entered)


func _on_hit_box_area_entered(area: Area2D) -> void:
	var hurt_box := area as GFHurtBox2D
	if hurt_box == null:
		return

	hit_box.send_to(hurt_box, {
		"damage": 10,
	})
```

`area_entered` 传入的是 Godot 的 `Area2D`；`send_to()` 的目标必须是 `GFHurtBox2D`，或自行实现了 `receive_hit(context)` 的对象。

被击中方监听 `hit_received`，读取 `context.payload` 后自行处理扣血、击退或特效；框架不会解释 `"damage"` 字段。若 HurtBox 配了 `accepted_hit_ids`，记得给 HitBox 设置对应的 `hit_id`。

3D 版本用法相同：`GFHitBox3D` 发送给 `GFHurtBox3D`，传入目标仍需要能处理 `receive_hit(context)`。
