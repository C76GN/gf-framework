# 注册与基础日志

`GFLogUtility` 是标准库通用工具，不会自动注册到架构。项目需要日志时，应在项目 Installer 中显式装配；如果同一项目可能由不同 Installer 组合装配，先用 `get_local_utility()` 做保护，避免重复注册 warning。

```gdscript
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture.get_local_utility(GFLogUtility) == null:
		await architecture.register_utility_instance(GFLogUtility.new())
```

## 基础日志

```gdscript
var log_util := Gf.get_utility(GFLogUtility) as GFLogUtility
if log_util == null:
	return

# 第一个参数是标签，推荐使用类名或模块名；第二个参数是消息内容。
log_util.debug("System", "系统初始化完毕。")
log_util.info("Network", "接通服务器。")
log_util.warn("Memory", "内存占用略高。")
log_util.error("Math", "除以了零。")

log_util.info("Scene", "场景加载完成。", {
	"path": "res://levels/test.tscn",
	"elapsed_ms": 18,
})
```

标签用于过滤、诊断和阅读，不应承载复杂业务结构。需要可查询上下文时，把结构化字段放入第三个参数的 Dictionary。
