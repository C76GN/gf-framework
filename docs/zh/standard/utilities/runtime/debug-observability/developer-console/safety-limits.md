# 安全等级与输出限制

控制台默认 `debug_only = true`，发布构建不会创建 GUI。

如果项目确实需要在非 debug 构建中使用，必须显式关闭该选项，并自行确认命令白名单、输入入口和玩家可见性。

```gdscript
console.debug_only = true
```

命令元数据可设置 `tier` 为 `GFConsoleUtility.CommandTier`，控制台会用 `max_command_tier` 拦截超出等级的命令。

`DANGER` 命令默认还需要传入 `--confirm`，确认参数不会转交业务回调。

```gdscript
console.max_command_tier = GFConsoleUtility.CommandTier.DANGER
var _wipe_save_command: GFLifetimeSubscription = console.register_command(self, "wipe_save", Callable(self, "_wipe_save"), "删除测试存档。", {
	"tier": GFConsoleUtility.CommandTier.DANGER,
})
console.execute_command("wipe_save --confirm")
```

控制台内部会批量刷新输出，并通过 `max_output_lines` 限制保留行数、通过 `max_history_size` 限制历史命令数量，避免高频日志或长时间运行造成无限增长。

日志 tag、message、命令回显和帮助文本会在写入 RichTextLabel 前转义 BBCode，避免日志内容污染控制台 UI。
