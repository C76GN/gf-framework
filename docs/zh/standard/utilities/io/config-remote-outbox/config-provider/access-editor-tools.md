# 访问器生成与编辑器工具

配置表 schema 可以用于生成静态访问器，也可以驱动编辑器里的资源表格和通用输入控件。生成和编辑工具都不改变 `GFConfigProvider` 协议。

## 静态访问器生成

如果项目希望减少散落的表名字符串，可以用 `GFConfigAccessGenerator` 根据 schema 生成静态访问器。生成结果只是对 provider 的 `get_record()` 和 `get_table()` 的轻量访问封装，不把具体表结构写入框架：

```gdscript
var generator := GFConfigAccessGenerator.new()
generator.generate(
	[items_schema, levels_schema],
	"res://generated/gf_config_access.gd",
	true,
	"GFConfigAccess",
	"Gf.get_utility(GFConfigProvider) as GFConfigProvider"
)

# 生成后项目代码可以通过 IDE 补全调用：
var item := GFConfigAccess.get_items_record(1001)
var levels := GFConfigAccess.get_levels_table()
```

生成器属于制作期 `gf.tool.config_pipeline` package，不进入 Kernel 或运行时配置闭包，也不会默认硬引用标准库的 `GFConfigProvider`。如果希望生成的访问器能在不显式传 provider 时工作，需要像上面这样传入项目自己的 `provider_accessor`。也可以在调用点显式传入 provider：`GFConfigAccess.get_items_record(1001, provider)`。

访问器适合稳定表名、团队协作和重构检查；原始 `GFConfigProvider` 仍适合动态表名、热更新表包或项目自定义导表运行时。

生成器只读取 schema 的 `table_name` 或 `table_key` 属性，不调用项目自定义取表名方法，适合在编辑器批量生成时避开非 `@tool` 脚本副作用。生成器只输出 GDScript，可用 `method_name_style`、`constant_prefix`、`record_method_pattern`、`table_method_pattern` 和 `include_schema_comments` 微调命名与注释，不生成其他语言代码。

如果项目希望在策划表字段上获得更强的 IDE 补全，可以显式开启 `include_typed_records`。该模式会根据 schema 的 `columns` 额外生成记录包装类和 `get_xxx_typed_record()` 方法：

```gdscript
var source := GFConfigAccessGenerator.new().build_source(
	[items_schema],
	"GFConfigAccess",
	"Gf.get_utility(GFConfigProvider) as GFConfigProvider",
	{
		"include_typed_records": true,
		"typed_record_class_suffix": "Record",
	}
)
```

生成的包装类只包裹 provider 返回的 `Dictionary`，字段 getter 也只做通用类型收窄，不把业务枚举、默认值策略或表间规则写入框架。`columns` 可以来自 `GFConfigTableColumn` 资源，也可以是 `{ "field_name": "id", "value_type": "int" }` 这类外部工具字典；不符合字段声明的数据仍应由导入校验或项目运行时策略处理。

使用 `gf.tool.config_pipeline` 时，也可以在 `GFConfigPipelineProfile.access_output_path` 中配置访问器输出路径，让一次导表同时保存配置数据库并生成访问器脚本。该串联仍是制作期动作，运行时只依赖生成后的脚本和项目实际安装的 provider。

需要在保存前预览访问器产物时，可以使用 `generate_with_report()` 或 `save_source_with_report()`。报告会说明产物状态、是否写入、是否 dry-run 和错误码，适合编辑器按钮、CI 检查或提交前差异审查复用。

## 编辑器工具

开发期如果需要做 Resource 批量检查或表格式编辑，可以复用 `GFResourceTableEditor` 和 `GFEditorValueField`。

`GFConfigTableEditorTools` 可以把 `GFConfigTableSchema` 转成通用列描述，也可以生成字段编辑描述和跨表引用候选记录。它属于可选的 `gf.standard.config.editor` 包，运行时读取配置只需要安装 `gf.standard.config`。字段编辑描述会保留列名、标签、默认值、可编辑状态和 metadata，并额外输出 `editor_kind`、Godot `property_info`、字段约束、校验规则摘要、引用描述和可选引用候选；这些信息来自 `GFConfigTableColumn`、字段校验规则、`GFConfigTableReference` 和调用方显式写入的 metadata。

它只返回 `Dictionary` / `Array` 描述数据，不创建 Control，也不解释字段业务含义；项目工具可以把这些描述映射到自己的表格控件、Inspector 或校验面板。需要强制指定项目侧控件语义时，优先通过字段 metadata 覆盖 `editor_kind`、`property_type`、`property_hint`、`property_hint_string`、`resource_type` 或 `resource_extensions`，而不是在框架里写死表名、字段名或资源分类。

`GFResourceTableEditor` 负责扫描 `.tres` / `.res`、从 Resource export 推导列、提交单元格值并广播变更。`scan_resource_paths()` 默认限制递归深度和收集数量，项目工具可按需要传入 `max_scan_depth` / `max_resource_paths`。默认只修改内存中的 Resource，不接管完整 UndoRedo 工作流；如果资源已有 `resource_path` 且项目希望提交后立即写盘，可以开启 `auto_save_committed_resources` 并监听 `resource_save_failed`。

`GFEditorValueField` 负责按 Godot 属性类型创建基础输入控件。Array/Dictionary JSON 输入解析失败或容器类型不匹配时会发出 `value_parse_failed` 并保留旧值，不会把错误输入静默提交成空容器或错误容器。

这些编辑器工具是通用控件，不保存业务表结构，也不替项目决定资源分类、校验规则或提交工作流。
