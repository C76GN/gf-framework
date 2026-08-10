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

`GFRuntimeTunableProperty` 可声明 bool、int、float、String、StringName、Vector2、Vector3、Color 或任意值，也可以设置范围、可选值、只读、显示分组和自定义 getter/setter/validator。回调是受信同步 hook；同一属性递归调用 `write_value()` 会失败关闭。Inspector 在回调返回后还会复核目标、属性和注册代际：回调若注销、替换或重新注册当前目标/属性，旧写操作返回 `false` 且不向新代际发 `property_changed`。

当前 custom setter 的签名返回 `void`。`GFRuntimeTunableProperty.write_value()` 的 `true` 只表示值已通过 schema/validator 且 setter 已被调用，无法证明项目外部存储真的接受了值，也不能回滚 setter 已产生的副作用。需要“接受/拒绝/规范化后实际值”回执时，应暂时在项目 setter/validator 中自行维护状态；是否升级为结构化 setter 结果属于后续公开契约决策。

`GFRuntimeInspectorUtility.allow_writes` 可整体关闭写入，`debug_build_writes_only` 默认让非 debug 构建不能通过该工具写值。

需要把调参快照放进调试覆盖层时，调用 `attach_to_debug_overlay()`；面向玩家的入口、远程运维工具或线上调试入口仍应由项目层做权限、白名单和脱敏。
