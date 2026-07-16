# 命令注册与参数解析

项目可以注册自定义指令。命令回调签名固定为 `func(args: PackedStringArray) -> void`。

## 直接注册

```gdscript
var console := Gf.get_utility(GFConsoleUtility) as GFConsoleUtility

var _tp_command: GFLifetimeSubscription = console.register_command(
	self,
	"tp",
	Callable(self, "_console_tp"),
	"传送玩家到指定坐标。用法: tp <x> <y>"
)
```

## 资源化注册

也可以用 `GFConsoleCommandDefinition` 资源化命令名、别名、描述和元数据，再通过 `register_command_definition()` 绑定执行回调。

```gdscript
var definition := GFConsoleCommandDefinition.new()
definition.command_name = "reload"
definition.aliases = PackedStringArray(["rl"])
definition.description = "重新加载当前调试数据。"
var _reload_command: GFLifetimeSubscription = console.register_command_definition(self, definition, func(_args: PackedStringArray) -> void:
	reload_debug_data()
)
```

## 生命周期与执行

注册句柄绑定命令与 owner 的生命周期。Node owner 退出场景树时会自动取消；需要提前注销时保留句柄并调用 `cancel()`。

常用操作：

```gdscript
_tp_command.cancel()
console.execute_command("help")
console.execute_command("scene.tree 3 80")
console.execute_command("scene.node Player")
```

参数解析支持引号和反斜杠转义。例如 `give_item "red potion" 3` 会把 `"red potion"` 作为一个参数。
