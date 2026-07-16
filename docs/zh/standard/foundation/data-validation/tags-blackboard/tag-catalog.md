# 标签目录与重定向

`GFTagCatalog` 是可选的标签定义资源。它适合项目需要统一标签命名、记录说明、迁移旧标签或在导入/配置/调试阶段检查目录外标签时使用。

目录不会改变 `GFTagSet` 和 `GFTagQuery` 的自由标签模型；项目仍可以直接使用任意 `StringName` 标签。只有调用方显式传入目录时，才会执行定义校验或重定向规范化。

```gdscript
var catalog := GFTagCatalog.new()
catalog.allow_undefined_tags = false
catalog.add_tag(&"state.burning", {
	"description": "Burning state.",
})
catalog.add_redirect(&"state.fire", &"state.burning")

var normalized := catalog.normalize_tag_source({
	"tag_counts": {
		&"state.fire": 2,
		&"rank.elite": 1,
	}
})

var report := catalog.validate_tag_source(normalized)
```

也可以用 `configure(catalog_id, definitions, options)` 一次性配置目录。`allow_undefined_tags` 和 `metadata` 属于目录本身，即使 definitions 为空也会生效，适合先创建 strict 空目录，再由工具或项目流程逐步填充定义。

`normalize_tag_source()` 会读取任何 `GFTagSourceAdapter` 支持的来源，解析重定向并合并层数。默认不会丢弃目录外标签；需要把输出严格限制在目录内时，传入 `{ "drop_undefined": true }`。

`validate_tag_source()` 返回 `GFValidationReport`。当 `allow_undefined_tags` 为 `false` 时，目录外标签会以 `undefined_tag` 报错；被重定向的标签会以 `redirected_tag` 记录为 info，方便迁移工具或调试面板提示调用方。

`validate_definition()` 用于检查目录自身，能报告空标签、重复标签、重定向循环和缺失的重定向目标。它不扫描项目文件，也不生成代码；这些属于项目工具或编辑器插件策略。
