# 资源图、变体、原始 Artifact 与导入计划

资源加载前后的制作期工具经常需要回答几个问题：一个资源里嵌套了哪些子资源、同一资源键在不同上下文下应该解析到哪个版本、外部原始文件如何作为 Resource 保存并在需要时物化为临时文件，以及一批导入来源准备写到哪里。GF 把这些问题拆成独立通用能力，避免把语言、平台、皮肤、导入格式或项目目录写死到框架里。

## 资源变体

`GFResourceVariantProvider` 是 `GFResourceResolverUtility` 的 provider。项目先注册资源键的多个变体路径，再在解析时通过 `variant_keys` 指定回退顺序。

```gdscript
var resolver := GFResourceResolverUtility.new()
resolver.init()

var variants := GFResourceVariantProvider.new()
variants.register_variant(&"ui.panel", &"default", "res://ui/default_panel.tres", "Resource")
variants.register_variant(&"ui.panel", &"mobile", "res://ui/mobile_panel.tres", "Resource")
resolver.register_provider(variants, &"variant", 10)

var report := resolver.resolve(&"ui.panel", "Resource", {
	"check_exists": false,
	"variant_keys": PackedStringArray(["mobile", "default"]),
})
```

变体键只是一段稳定标识。它可以来自项目 profile、语言设置、画质档位或平台检测，但这些策略应留在项目侧；GF 只负责按顺序查找、回退和输出诊断 metadata。

## 资源图扫描

`GFResourceGraphScanner.scan(root)` 会递归读取 `Resource`、`Object`、`Array` 和 `Dictionary`，返回 `nodes`、`node_count`、`cycle_count`、`truncated` 和路径信息。它不修改对象，也不依赖 Inspector UI，适合编辑器工具、资源表校验、测试断言和诊断面板。

```gdscript
var report := GFResourceGraphScanner.scan(resource, {
	"max_depth": 16,
	"max_nodes": 2048,
})

for node in GFVariantData.get_option_array(report, "nodes"):
	print(GFVariantData.get_option_string(node, "path"))
```

默认扫描可存储或编辑器可见的属性，并跳过 `script`、`resource_path` 等 Godot 资源元字段。需要扫描场景节点时显式传入 `include_nodes = true`。

## 原始 Artifact

`GFRawResourceArtifact` 保存原始字节、源路径、类型提示和 metadata。它适合把外部工具输入、二进制配置、导入前源文件或第三方运行库需要的文件载荷封装成 Resource。

```gdscript
var artifact := GFRawResourceArtifact.new()
artifact.configure("source/runtime_patch.bin", bytes, "application/octet-stream")

var report := artifact.materialize_temp({
	"directory_path": "user://gf/artifacts",
	"file_name": "runtime_patch.bin",
})
```

物化默认只允许写入 `user://`。需要写入 `res://` 的编辑器或构建工具必须显式传 `allow_res_path = true`，这样路径副作用不会在普通运行时被隐式打开。

## 导入计划

`GFImportPlan` 只描述导入条目，不执行复制、转换或删除。每个条目包含 `source_path`、`target_path`、`operation`、`options` 和归一化后的来源 trace，适合编辑器导入器、资源整理工具、CI 预检或项目自己的批处理 UI 在真正写入文件前做审查。

```gdscript
var plan := GFImportPlan.new()
plan.add_entry(
	"user://incoming/items.csv",
	"res://data/items.csv",
	GFImportPlan.OPERATION_COPY,
	{ "source": "designer_drop" }
)

var report := plan.get_validation_report({
	"require_existing_source": false,
})
```

`get_validation_report()` 会检查来源、目标、操作类型和可选的源文件存在性；`get_repair_report()` 会输出可提示给工具 UI 的修复建议，例如跳过无效条目或补齐目标路径。项目如果需要真正复制、转换格式、重建 import remap 或写入数据库，应把计划交给自己的工具链执行，GF 不在这里规定项目目录或业务 schema。
