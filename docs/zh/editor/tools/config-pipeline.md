# Config Pipeline 导表工具包

`gf.tool.config_pipeline` 是可选制作期工具包，用于把通用 CSV / JSON / XLSX 表来源构建为 `GFConfigTableResource` 或 `GFConfigDatabaseResource`，再保存为 Godot 原生 `.tres/.res` 或通用 JSON 导出。它适合编辑器按钮、CI 校验或项目导表脚本复用同一套 GF 配置表 schema、报告和 Resource Provider。

## 定位

`GFConfigPipelineTableSource` 描述单张表的来源路径、格式、schema、解析选项、schema 推导选项和导出元数据。它只描述“这张表从哪里来、如何解析和校验”，不规定业务表名、字段语义、目录布局或发布流程。

`GFConfigPipelineProfile` 描述一批表来源、数据库标识、版本、输出路径、构建选项和保存选项。它也可以显式配置访问器脚本输出，让同一次导表顺带生成静态配置访问脚本。Profile 适合保存为 `.tres`，让项目导表命令、编辑器按钮或 CI 只读取一份批量构建声明。

`GFConfigPipeline` 执行构建流程：读取来源文件、按 CSV / JSON / XLSX 解析、把结果归一化为记录数组、按 schema 校验和转换字段、构建表资源、注册到数据库资源，并可保存为 Godot Resource 或 JSON 导出。

`GFConfigPipelineRunner` 从 Profile 资源路径加载 `.tres/.res`，再调用 Pipeline 构建或导出，并返回统一 Dictionary 报告。它适合作为 CI、编辑器按钮或项目脚本的 Godot 原生入口。

## 典型流程

```gdscript
var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
source.table_name = &"items"
source.source_path = "res://data/items.csv"
source.source_format = GFConfigPipelineTableSource.FORMAT_AUTO
source.schema = item_schema

var pipeline: GFConfigPipeline = GFConfigPipeline.new()
var result: Dictionary = pipeline.build_database([source], {
	"database_id": &"main",
	"version": "dev",
})

if GFVariantData.get_option_bool(result, "success"):
	var database_value: Variant = GFVariantData.get_option_value(result, "database")
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		pipeline.save_database(database, "res://generated/config/main_config.tres")
```

需要给外部流水线、差异审查或热更新打包前置流程使用时，可以把同一份数据库保存为 JSON：

```gdscript
pipeline.save_database(database, "res://generated/config/main_config.json", {
	"include_schema": true,
	"include_indexes": false,
})
```

JSON 导出包含稳定格式标识、数据库 ID、版本、元数据、表名、记录和可选 schema 摘要；默认不写入可由运行时重建的索引缓存，避免把导出文件变成冗余快照。`make_database_export()` 可在不写文件时返回同结构字典，供 CI 检查或项目侧打包器继续处理。

批量导表可以把来源和输出保存进 Profile：

```gdscript
var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
profile.profile_id = &"dev"
profile.database_id = &"main"
profile.version = "dev"
profile.output_path = "res://generated/config/main_config.tres"
profile.sources = [source]

var export_result: Dictionary = pipeline.export_profile(profile)
```

如果希望同一次导表同步生成静态访问器，给 Profile 配置 `access_output_path`。`access_options` 会传给 `GFConfigAccessGenerator`，因此可以选择是否生成 typed record 包装：

```gdscript
profile.access_output_path = "res://generated/config/gf_config_access.gd"
profile.access_class_name = "GFConfigAccess"
profile.access_provider_accessor = "Gf.get_utility(GFConfigProvider) as GFConfigProvider"
profile.access_options = {
	"include_typed_records": true,
}

var export_result: Dictionary = pipeline.export_profile(profile)
var access_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "access_result")
```

没有配置 `access_output_path` 时，Profile 导出只构建并保存数据库，`access_result.skipped` 会为 `true`。访问器生成失败会让本次 `export_profile()` 返回失败，但已经构建出的数据库资源仍会留在结果字典中，便于 CI 或编辑器工具展示问题。

需要从资源路径执行时，使用 Runner：

```gdscript
var runner: GFConfigPipelineRunner = GFConfigPipelineRunner.new()
var run_result: Dictionary = runner.export_profile_path("res://config/build/dev_profile.tres")
```

生成的 `GFConfigDatabaseResource` 只作为表资源聚合产物保存；运行时读取 Godot Resource 时使用 `GFResourceConfigProvider.from_database(database)` 接入 `GFConfigProvider` 的整表、按 ID 和命名索引查询入口。访问器脚本只是制作期生成的轻量 GDScript 封装，可以提交到项目版本库，也可以由项目 CI 生成后参与校验。JSON 导出是通用数据产物，适合交给项目侧热更新、签名、压缩或远端发布流水线继续处理。

## 表结构声明

项目可以继续显式提供 `GFConfigTableSchema` 资源；这是最稳定、最适合复杂校验和跨表引用的方式。对于轻量 CSV / XLSX 表，也可以在 `schema_options` 中开启类型化表头，让导表工具从表头生成通用 schema：

```gdscript
source.schema_options = {
	"typed_headers": true,
	"id_field": &"id",
	"require_unique_id": true,
}
```

启用后，表头可以写成 `id:int!`、`name:string`、`power:float`。冒号前是生成后的字段名，冒号后是通用值类型；`!` 表示必填且不允许 `null`，`?` 表示允许空值。支持的类型包括 `any`、`bool`、`int`、`float`、`string`、`string_name`、`vector2`、`vector2i`、`color`、`dictionary` 和 `array`。导入到资源中的记录字段会被清理为 `id`、`name`、`power` 这样的稳定字段名。

类型化表头生成的是已有的 `GFConfigTableSchema` / `GFConfigTableColumn`，默认启用字段转换、默认不允许未声明字段。显式挂在 `source.schema` 上的 schema 优先级更高；类型化表头适合降低简单表的维护成本，不替代复杂表的索引、引用和业务校验资源。

## 使用边界

当前工具包只沉淀稳定通用机制：来源声明、Profile 路径执行、CSV / JSON / XLSX 解析、schema 校验、跨表引用校验、记录转换、索引重建、`.tres/.res` 保存和 JSON 导出。

XLSX 支持定位为通用表格输入适配：默认读取 workbook 中的第一个 sheet，也可以通过 `parse_options.sheet_name` 或 `parse_options.sheet_index` 选择工作表，通过 `parse_options.header_row` 指定表头行。解析结果按表头映射为记录字典，再复用现有 schema 校验和类型转换。公式计算、样式日期语义、合并单元格、多表业务拆分、策划提交流程和分端发布策略不属于这一层。

`GFConfigPipelineProfile` 只表达导表任务 manifest。`GFConfigBuildProfile` 仍负责按 groups / tags 裁剪 schema 或记录，两者可以组合使用，但职责不同。

`GFConfigPipelineRunner` 不解释命令行参数，不创建编辑器 UI，也不调用外部进程。复杂 Excel、多 sheet、远程拉取、策划提交流程、分端裁剪、热更新打包、加密压缩和导出菜单属于项目流水线或独立工具插件策略。项目可以在这些策略层调用 `GFConfigPipeline` 或 `GFConfigPipelineRunner`，但不应把具体业务规则写回框架工具包。
