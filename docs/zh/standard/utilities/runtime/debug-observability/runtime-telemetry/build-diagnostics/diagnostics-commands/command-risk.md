# 风险等级与认证

诊断命令可设置风险等级与认证要求。默认只允许观察类命令；如果项目要把控制类命令桥接到远程调试或编辑器工具，应显式提高 `max_command_tier` 并按需要启用 token。

`DANGER` 等级即使在等级范围内，也需要额外设置 `allow_danger_commands = true` 才会执行。

```gdscript
diagnostics.set_auth_token("dev-token")
diagnostics.max_command_tier = GFDiagnosticsUtility.CommandTier.CONTROL
diagnostics.register_command(
	self,
	&"runtime.pause",
	Callable(self, "_diagnostics_pause"),
	"暂停运行时。",
	GFDiagnosticsUtility.CommandTier.CONTROL
)
```

控制类命令应默认只在本地开发或受控编辑器工具中开启。远程入口需要项目自己处理身份认证、参数白名单、审计日志、速率限制和敏感字段过滤。
