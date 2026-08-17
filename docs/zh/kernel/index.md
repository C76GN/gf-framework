# Kernel 总览

Kernel 是 GF 的运行内核，负责全局入口、架构容器、生命周期、事件、命令、查询、场景桥接、依赖解析和编辑器基础设施。它只放框架启动与运行所必需的契约和机制，不依赖标准库或可选扩展的具体实现。

## 阅读入口

- [架构容器](architecture/index.md)：`Gf`、`GFArchitecture`、层级边界、装配诊断、五层分工、编辑器访问器和内核基础设施。
- [生命周期、装配与依赖](lifecycle/index.md)：Installer、依赖 DAG、四阶段激活、异步关闭、热模块事务、局部上下文和 Controller 初始化。
- [消息、事件、命令与查询](messaging/index.md)：事件系统、命令、查询、规则和命令历史。
- [场景桥接、Controller 与数据绑定](scene-controller/index.md)：`GFController`、System 更新、绑定属性和局部响应式组合。

## 使用边界

需要被 Kernel 直接识别的能力应收敛为内核契约。纯算法和数据结构放入 Foundation；默认稳定服务放入 Standard Utilities；可选原子能力放入 Extensions；项目玩法、SDK 适配和跨扩展组合留给项目代码或独立插件。

## 通用内核工具

`GFPathTools` 提供纯字符串层面的路径规范化、根目录裁剪、路径集合去重、相对路径和排除路径匹配，不访问文件系统，也不解释资源业务语义。它用于让扩展发现、内容包、资源注册表、音频扫描和目录监听共享一致的路径边界判断。

`GFBoundedJsonObjectReader` 为项目运行时、编辑器和 headless 工具提供 provider-neutral 的 JSON object 准入边界。`parse_object()` 接收文本，`read_object()` 接收 `FileAccess` 可读取的路径并先规范化路径；两个入口都只接受 object 根节点，在调用 `JSON.parse()` 前检查 UTF-8 字节数和对象/数组的词法嵌套深度。文件入口最多读取生效字节预算加一字节，并用同一份原始 bytes 完成大小、UTF-8、深度和解析校验。

```gdscript
var report: Dictionary = GFBoundedJsonObjectReader.read_object(
	"res://data/runtime_config.json",
	256 * 1024,
	32
)
if not report["ok"]:
	push_error("%s: %s" % [report["error_kind"], report["error"]])
	return

var config: Dictionary = report["data"]
```

默认值和框架绝对上限都是 1 MiB、64 层：正数参数只能进一步收紧，非正值恢复默认值，超过绝对上限的值会被钳制，不能借此关闭保护。返回报告始终是 JSON-safe 的 8 字段 Dictionary：`ok`、`data`、`source_path`、`size_bytes`、`error_kind`、`error`、`max_bytes` 和 `max_depth`；后两个字段记录实际生效预算。成功时 `error_kind` 和 `error` 为空；失败类型稳定为 `open_failed`、`read_failed`、`payload_too_large`、`nesting_too_deep`、`parse_failed` 或 `invalid_root_type`，且 `data` 为空。文本入口的 `source_path` 为空；文件入口返回规范化路径。

读取器会在调用 Godot JSON 解析器前拒绝原始 NUL、解码为 U+0000 的字符串转义，以及会触发数值转换溢出或非有限结果的数字文本；这类输入以及解析后仍出现非有限数字的输入统一报告为 `parse_failed`，不会静默截断输入，也不会把 `INF` 或 `NaN` 暴露到 JSON-safe 报告中。数字预检保持线性扫描，不会因长指数产生二次方复制成本。

该读取器只负责 JSON object 的解析前准入，不恢复 GF Variant typed marker，也不替代业务 schema 校验。需要恢复 marker 时，先确认报告成功，再把 `data` 交给 `GFVariantJsonCodec.json_compatible_to_variant()`，并继续为后续 Variant 遍历设置独立预算。

`GFDependencyGraphTools` 提供字符串 ID 依赖图的依赖优先排序、缺失依赖记录和循环路径诊断。依赖 ID 输入会过滤空值、裁剪空白并去重。扩展 manifest、内容包和项目工具可以复用同一套轻量机制，但具体节点类型、启用策略和版本约束仍留在调用方。

`GFProjectSettingsTools` 提供 ProjectSettings 默认值、缺失键初始值和 Inspector 属性信息注册辅助。它只负责稳定声明设置键，不读取业务含义，也不自动保存 `project.godot`；插件、扩展或项目工具仍应自行决定何时保存设置。

## API Reference

完整类、方法和信号列表见 [Kernel API Reference](../reference/api/kernel.md)。
