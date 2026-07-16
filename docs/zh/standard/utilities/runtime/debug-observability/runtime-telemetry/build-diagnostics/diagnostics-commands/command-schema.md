# 命令 Schema

需要把诊断命令暴露给编辑器面板、远程开发工具或项目自定义控制台时，可以为命令声明参数 schema，并按命令启停。

Schema 只做通用类型、必填、默认值、枚举值和数值范围校验，不负责业务权限；真正的入口权限仍由项目层决定。

```gdscript
diagnostics.register_command(
	self,
	&"runtime.limit",
	func(args: Dictionary) -> Dictionary:
		return { "limit": args["limit"] },
	"读取限制值。",
	GFDiagnosticsUtility.CommandTier.OBSERVE,
	{
		"parameters": [
			{
				"name": "limit",
				"type": "int",
				"default": 3,
				"min": 1,
				"max": 10,
			},
		],
	}
)

diagnostics.set_command_enabled(&"runtime.limit", false)
```

`execute_command_json_safe()` 会把命令结果通过 `GFVariantJsonCodec` 转成 JSON 友好结构，适合写入文件、支持报告或调试面板数据源。默认 `execute_command()` 仍返回原始 Variant，方便本地工具保留 `Vector3`、`Color`、`NodePath` 等 Godot 类型。
