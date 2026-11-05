# 序列化与恢复

自 `1.1.0` 起，`GFCommandHistoryUtility` 支持将整个撤销/重做栈序列化为纯数据，以便存入玩家存档文件。

```gdscript
var history := Gf.get_utility(GFCommandHistoryUtility) as GFCommandHistoryUtility
var saved_data_array: Array = history.serialize_history()
# 将 saved_data_array 使用 GFStorageUtility 等方式写入你的存档文件
```

若要定制序列化结构，`GFUndoableCommand` 子类应覆盖 `serialize() -> Dictionary`。如果未提供，框架默认只提取其 `get_snapshot()` 作为数据。

`set_snapshot()` 会对 `Dictionary` 和 `Array` 做深拷贝，但其中包含的 `Object`、`Resource`、`Node` 或自定义引用仍可能共享同一实例。复杂对象快照应由业务层转换为标量、字典或自定义序列化数据。

反序列化历史记录时，框架层不感知具体 Command 类型，需要外部传入构建器实现控制反转。

```gdscript
var history := Gf.get_utility(GFCommandHistoryUtility) as GFCommandHistoryUtility

# 仅重建项目认可的命令类型及其快照，不在恢复构建器中再次执行业务操作。
var command_builder = func(data: Dictionary) -> GFUndoableCommand:
	var cmd_type = data.get("type", "")
	if cmd_type == "TakeDamage":
		var c = TakeDamageCommand.new()
		c.set_snapshot(data.get("snapshot", null))
		return c
	return null

history.deserialize_history(saved_data_array, command_builder)
```

`GFCommandHistoryUtility.max_history_size` 默认为 `1024`。当历史数量超过限制时，最早的操作会被移除以释放内存。
