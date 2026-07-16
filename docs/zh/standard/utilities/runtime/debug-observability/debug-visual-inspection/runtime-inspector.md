# 运行时调参注册表

`GFRuntimeInspectorUtility` 提供显式 schema 驱动的运行时检查和调参入口。

项目必须主动注册目标对象和 `GFRuntimeTunableProperty`，框架只负责读取、归一化、写入门禁、快照和可选 Overlay 面板，不会自动扫描所有节点、Model 或项目字段。

```gdscript
var inspector := Gf.get_utility(GFRuntimeInspectorUtility) as GFRuntimeInspectorUtility

var move_speed := GFRuntimeTunableProperty.new(
	&"move_speed",
	^"move_speed",
	GFRuntimeTunableProperty.ValueKind.FLOAT
)
if not move_speed.configure_range(0.0, 1200.0, 10.0):
	return

inspector.register_target(&"player", player_stats, [move_speed], {
	"label": "Player Stats",
	"group": "Combat",
})

inspector.set_property_value(&"player", &"move_speed", 480.0)
print(inspector.get_target_snapshot())
```

`GFRuntimeTunableProperty` 可声明 bool、int、float、String、StringName、Vector2、Vector3、Color 或任意值，也可以设置范围、可选值、只读、显示分组和自定义 getter/setter/validator。

`GFRuntimeInspectorUtility.allow_writes` 可整体关闭写入，`debug_build_writes_only` 默认让非 debug 构建不能通过该工具写值。

需要把调参快照放进调试覆盖层时，调用 `attach_to_debug_overlay()`；面向玩家的入口、远程运维工具或线上调试入口仍应由项目层做权限、白名单和脱敏。
