# 报告对象

通用校验基础件用于统一表达“某个数据、资源或节点结构有什么问题”。推荐把 `kind` 设计成稳定、抽象的 snake_case 标识，把具体修复策略放在调用方传入的 `next_actions` 映射中。这样框架层只负责报告结构和统计，不把项目业务规则写死进基础件。

```gdscript
var report := GFValidationReport.new("Item table")
report.add_warning(&"missing_optional", "Optional field is missing.", "row_1")
report.add_error(&"invalid_value", "Value is invalid.", "row_2")

var data := report.to_dict({}, {
	"next_actions": {
		"invalid_value": "Fix the invalid value before importing.",
	},
})

print(data["ok"])
print(data["summary"])
```

需要把报告交给 JSON 文件、命令行、CI 或外部工具时，使用 `to_json_compatible_dict()`。它会通过 `GFReportValueCodec` 把 metadata、issue key 和附加字段中的 Godot 值转换成 JSON-safe 结构，并脱敏运行时对象：

```gdscript
var json_safe := report.to_json_compatible_dict()
var text := JSON.stringify(json_safe, "\t")
```

`to_dict()` 仍适合 Godot 内部传递和测试断言；`to_json_compatible_dict()` 是跨进程、日志和文件边界的默认选择。

需要在不同输出场景复用同一份报告时，可以把 `redaction_profile` 传给 `GFReportValueCodec`。常用 profile 包括开发调试用的 `debug`、默认支持诊断用的 `support`、公开页面或用户可见输出用的 `public`，以及更严格的 `privacy`。profile 只决定路径、对象摘要和敏感字段的导出强度，不改变原始报告对象；项目仍应在业务层决定哪些字段可以采集。

## Source Span

需要把问题定位到源码、配置表、导入文本或资源片段时，可以使用 `GFSourceSpan`。行列约定为 1-based，`0` 表示未知；`source` 字典字段会作为 `source_path` 的兼容别名读取，方便旧字典报告逐步迁移。

```gdscript
var span := GFSourceSpan.make("res://data/items.csv", 8, 4, 3)
var report := GFValidationReport.new("Item table")
report.add_source_error(&"invalid_value", "Value is invalid.", span)

var issue_data := report.to_dict()["issues"][0]
print(issue_data["source_path"])
print(issue_data["line"])
print(issue_data["source_span"]["column"])
```

## Drift Report

需要比较两个来源是否一致时，可以使用 `GFDriftReport`。它只接受调用方提供的稳定 key 或 key -> entry 字典，并输出 `matched`、`missing`、`extra` 和 `stale`，不关心这些 key 来自资源注册表、配置表、package lockfile 还是编辑器缓存。

```gdscript
var report := GFDriftReport.compare_entries(
	{
		"item_sword": { "version": 1 },
		"item_potion": { "version": 1 },
	},
	{
		"item_sword": { "version": 2 },
		"item_scroll": { "version": 1 },
	},
	{
		"subject": "Item catalog drift",
		"expected_label": "catalog",
		"actual_label": "generated",
	}
)

print(report["missing"])
print(report["extra"])
print(report["stale"])
```

默认情况下，缺失项是 error，多余项和 stale 项是 warning；需要把 stale 当成硬失败的导入器或 CI 工具，可以传入 `stale_severity: "error"`。值比较复用 `GFVariantData.values_equal()`，因此需要浮点容差或 String / StringName 宽松匹配时，可以传入 `numeric_epsilon` 或 `match_string_names`。

## Bridge Contract Report

需要审查外部 SDK、GDExtension、编辑器工具或项目回调是否覆盖了框架期望的桥接点时，可以使用 `GFBridgeContractReport`。它把“期望契约”和“实际适配器”都当作纯字典数据，不注册适配器、不调用 handler，也不把具体平台或业务路由写进框架层。

```gdscript
var report := GFBridgeContractReport.from_entries(
	[
		{
			"contract_id": &"config.resolve",
			"signature": "Dictionary(request) -> Variant",
		},
	],
	[
		{
			"adapter_id": &"project.config_resolver",
			"contract_id": &"config.resolve",
			"signature": "Dictionary(request) -> Variant",
		},
	]
)

print(report["covered"])
print(report["compatible"])
```

契约可声明 `required`、`allow_multiple`、`signature`、`version` 和 `capabilities`。报告会区分 covered 与 compatible：只要有启用适配器就算 covered；签名、版本和能力也满足时才算 compatible。这样编辑器预检、导入器、包构建器或外部桥接层可以在真正执行之前发现缺失、孤儿、重复或过期适配器。

如果实际适配器是 Godot `Object` 或 `Engine` singleton，可先用 `make_object_adapter_entry()` 或 `make_engine_singleton_adapter_entry()` 生成适配器条目。它们只检查目标是否存在、必需方法和必需信号是否齐全，并把 `missing_methods`、`missing_signals`、`object_class`、`platform` 等信息写入 metadata；不会调用对象方法，也不会替项目注册平台服务。

请求 handler 覆盖报告仍可通过 `GFBridgeContractReport.report_request_handlers()` 直接生成。更底层的 request-handler 专用条目构建由 `GFRequestHandlerRegistry.make_bridge_contract_entries()` 提供，便于请求模块自己维护 handler adapter 元数据，而通用 bridge 报告继续只负责比较 contract 与 adapter 字典。
