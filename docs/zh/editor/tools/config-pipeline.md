# Config Pipeline 导表工具包

`gf.tool.config_pipeline` 是可选制作期工具包，用于把通用 CSV / JSON / ConfigFile / XLSX 表来源构建为 `GFConfigTableResource` 或 `GFConfigDatabaseResource`，再保存为 Godot 原生 `.tres/.res` 或通用 JSON 导出。它适合编辑器按钮、CI 校验或项目导表脚本复用同一套 GF 配置表 schema、报告和 Resource Provider。

## 定位

`GFConfigPipelineTableSource` 描述单张表的来源路径、格式、schema、解析选项、schema 推导选项和导出元数据。它只描述“这张表从哪里来、如何解析和校验”，不规定业务表名、字段语义、目录布局或发布流程。

`GFConfigPipelineProfile` 描述一批表来源、数据库标识、版本、输出路径、构建选项和保存选项。它也可以显式配置访问器脚本输出，让同一次导表顺带生成静态配置访问脚本。Profile 适合保存为 `.tres`，让项目导表命令、编辑器按钮或 CI 只读取一份批量构建声明。

`GFConfigPipeline` 是编排入口：它按 Reader、Layout、Validation、Target 和 Commit 的固定职责链执行编译，不再同时持有每种格式解析、语义校验、目标编码和文件回滚实现。构建结果继续返回表或数据库 Resource，同时通过 `ir` 暴露实际交给 Target 的版本化中间表示。

`GFConfigPipelineRunner` 从 Profile 资源路径加载 `.tres/.res`，再调用 Pipeline 构建或导出，并返回统一 Dictionary 报告。它适合作为 CI、编辑器按钮或项目脚本的 Godot 原生入口。

`GFConfigPipelineCommand` 是 Runner 之上的命令参数适配器。项目可以用 Godot headless 直接运行它，获得 exit code、JSON 报告和 dry-run 产物预检，而不需要在项目侧重复解析命令行参数。

`GFConfigPipelineArtifactManifest` 负责为 Profile 导出记录输入、输出和选项摘要。Runner 的 changed-only 模式会读取它判断产物是否仍然 fresh；项目侧也可以直接读取 manifest 报告做 CI 审查或编辑器提示。

## 分阶段编译与版本化 IR

内置 Pipeline 使用五个彼此独立的阶段：

- `GFConfigPipelineReaderStage` 只处理来源存在性、文件大小预算和原始载荷读取。它单次读取实际字节，并返回包含规范路径、精确字节数和 SHA-256 的 `source_receipt`；CSV、JSON、ConfigFile 从同一字节快照解码文本，XLSX 把收据随路径载荷交给下一阶段。
- `GFConfigPipelineLayoutStage` 只把载荷解码为记录、表头和 `row_locations`。CSV / JSON / ConfigFile 复用 `GFConfigTableImporter`；XLSX 在任何 entry 读取前先通过框架共享的有界 ZIP 预检，并以 Reader 收据复核 archive 身份，再把 ZIP / XML 预算与 sheet 布局解析收敛在该阶段。四个语义 XML entry 只有在正常 EOF、根元素完整闭合且没有截断尾部时才会提交解析结果。
- `GFConfigPipelineValidationStage` 负责记录规范化、类型化表头、schema 复制或推导、字段转换和语义校验。只有完整通过的结果才生成 `GFConfigPipelineTableIR`。
- `GFConfigPipelineTargetStage` 接受 IR 完成 Resource 物化，并将数据库 Resource 转换为 JSON-safe 数据及稳定 JSON 文本；缩进、键排序和变体编码都属于 Target 语义，它不会重新读取来源或推导 schema。JSON 转换始终限制递归深度、节点数和输出字节数，并拒绝 Array/Dictionary 循环；调用方只能在框架绝对上限内收紧或放宽默认预算。
- `GFConfigPipelineCommitStage` 把 ResourceSaver 等专用 writer 接到框架级 `GFArtifactWriteTransaction`，只负责多产物写入前快照、成功清理和失败逆序回滚，不复制事务实现、不解释产物内容，也不决定输出路径策略。

`export_profile()` 的顶层结果保留 Commit Stage 的完整 `transaction_result`，并镜像 `recovery_required` / `recovery_action` / `recovery_transaction`。只要回滚或快照清理尚未终结，导出就不会报告成功；调用方必须按稳定恢复动作修复介质或权限条件，并把 opaque 恢复句柄交给报告要求的 `rollback()` 或 `complete()`，不能重新执行整条导表流水线来覆盖未完成事务。批量导出会强制 database、access script 与 manifest constituent 使用 `scan_filesystem = false`，避免事务尚未终结时产生未纳入回滚的 `.gd.uid`；只有完整 `complete()` 成功后才按顶层 `scan_filesystem` 执行一次编辑器扫描。写入 manifest 的导出还会在事务完成前重新检查所有来源：任一当前文件与编译 `source_receipt` 不同，`source_validation_report.stable` 就为 `false`，整批 database、access script 与 manifest 会一起回滚。

`GFConfigPipelineTableIR` 与 `GFConfigPipelineIR` 都带稳定 `FORMAT` / `FORMAT_VERSION`。Table IR 创建时会深拷贝记录、schema、来源映射和元数据，读取接口始终返回可变载荷的副本；数据库 IR 对重复表名 fail closed，并且只有 `seal()` 成功后才能交给 Target，封存后继续注册表会失败。数据库 IR 返回的表数组容器也是副本，元素则是已封装可变载荷的 Table IR。这个所有权和生命周期边界保证自定义 Target、并行预览或后续缓存不会通过共享 `Dictionary` / `Resource` 引用反向污染编译结果。

项目或独立工具插件确实需要替换来源或目标时，可以继承对应 Stage，并通过 `configure_stages()` 注入。自定义阶段必须保持内置输入输出契约，只替换稳定机制；远程表服务、业务字段解释、分端裁剪、热更新签名和发布审批仍应留在项目流水线。`get_stage_descriptors()` 会按实际执行顺序返回阶段 ID、实现版本、实现路径、`implementation_dependencies` 和契约，可用于诊断、编译指纹与工具展示。具名脚本会自动提供 `implementation_path`；阶段依赖的 schema、列、Importer 或其他辅助实现必须显式列入 `implementation_dependencies`。运行时内部类或动态脚本若没有稳定资源路径，必须在描述器中显式声明可追踪的实现路径，否则产物新鲜度检查应 fail closed。

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

var compilation_ir_value: Variant = GFVariantData.get_option_value(result, "ir")
if compilation_ir_value is GFConfigPipelineIR:
	var compilation_ir: GFConfigPipelineIR = compilation_ir_value
	print(compilation_ir.describe())

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

JSON 导出包含稳定格式标识、数据库 ID、版本、元数据、表名、记录和可选 schema 摘要；默认不写入可由运行时重建的索引缓存，避免把导出文件变成冗余快照。`make_database_export()` 可在不写文件时返回同结构字典，供 CI 检查或项目侧打包器继续处理。`max_depth`、`max_nodes` 与 `max_output_bytes` 分别限制结构深度、转换节点和最终 UTF-8 文本；负数、零或过大的请求都不会关闭框架硬上限。

`save_database()` 和访问器生成结果会返回 `artifact_report`，记录本次产物是 `new`、`changed`、`unchanged`、`skipped` 还是 `failed`，以及 `written`、`changed`、`dry_run` 和错误码。需要在 CI、编辑器预览或提交前审查中只看差异而不落盘时，可以传入 `dry_run: true`；需要防止覆盖已有产物时，可以传入 `overwrite_existing: false`。

所有公开 Config Pipeline 写入口、Profile/Runner preflight、`dry_run` 与真实写入统一只接受 `res://` 或 `user://` 输出 URI。裸相对路径、主机绝对路径、未知或大小写错误的 URI scheme 会失败；成功结果和 artifact report 使用规范化后的 URI。`GFConfigPipeline` 的 database/access/manifest writer 以及 Profile/Runner 路由还会在任何产物 I/O 前闭合整批路径，并默认拒绝 `..` 父级片段；受信调用方可以对单个产物显式设置 `allow_parent_output_path: true`，但它只允许在既有 resource URI 域内折叠父级片段，不能越过 `res://` / `user://` 根，也不能授权主机文件系统路径。`allow_gf_source_output` 只放行默认受保护的 `res://addons/gf` 源码目录，`allow_unowned_overwrite` 只跳过既有产物的所有权确认；两者都不会扩大 URI 域。直接 `GFConfigAccessGenerator` 保留通用文本 writer 合同，不识别这些 Config Pipeline 路由授权选项。resource 格式的数据库输出还会在 ownership 与产物 I/O 前，以当前 `ResourceSaver` 为该数据库声明的扩展名列表校验目标；该规则对扩展名大小写不敏感，也同样作用于 `dry_run` 与真实保存。显式 JSON 格式不套用这项 ResourceSaver 策略。`dry_run` 证明确定性的路径、所有权与已声明格式策略已通过，不承诺自定义 saver 的额外路径识别、权限、磁盘状态或并发写入不会在真实提交时变化。Profile 里的普通构建选项只会保留导表自身识别的键；Runner 的 `dry_run`、`changed_only`、`manifest_path` 等执行期选项不会混入数据库构建配置。

需要做增量导表时，可以让 Runner 为导出结果写入 artifact manifest。manifest 会记录 Profile 语义摘要及其 Resource 依赖、编译时来源收据、输出文件、影响产物内容的导表选项、编译器指纹和本次运行摘要。Profile 依赖会递归覆盖外置 schema、列、索引、引用和自定义校验器脚本；编译器指纹则包含编译契约版本、GF/Godot 版本，以及每个实际阶段的稳定 ID、`implementation_version`、实现路径、实现文件摘要和声明的辅助实现摘要。这样 manifest 的来源摘要与生成数据库使用同一字节事实，且只修改 schema、列、Importer、校验器或 GF 导表实现时也不会错误命中旧产物。

manifest 输出会先经过 JSON-safe 转换，非有限浮点、PackedArray、Object、Resource 或循环结构不会直接进入 `JSON.stringify()`。下一次用同一 Profile 导出时，`changed_only` 会比对 Profile、语义依赖、来源、输出、关键选项和编译器指纹；全部未变化时才返回 `skipped: true`。当前 freshness 报告里的 `success` 与 `fresh` 同值，均表示“产物新鲜”，不是“评估过程已完成”；Runner 以 `fresh` 和 `scan_report` 作判断。内置阶段的描述直接源于各 Stage 的 `STAGE_ID` / `IMPLEMENTATION_VERSION`，自定义阶段使用其实际描述器；指纹同时纳入两个 IR 的格式版本并哈希对应实现文件与声明依赖，因此阶段组合、实现、辅助实现或 IR 契约变化不会错误命中旧产物。缺少新增指纹字段但摘要合法的旧 manifest 会被当作 stale 并在下一次成功导出时升级，不需要手工删除；字段不完整、所有权不匹配或摘要被篡改的 manifest 仍会 fail closed。所有依赖和阶段文件都计入既有 freshness 文件大小、累计字节数和条目数预算。

```gdscript
var runner: GFConfigPipelineRunner = GFConfigPipelineRunner.new()
var run_result: Dictionary = runner.export_profile_path("res://config/build/dev_profile.tres", {
	"changed_only": true,
	"manifest_path": "res://generated/config/main_config.tres.manifest.json",
})
```

未显式传 `manifest_path` 时，默认路径为 `output_path + ".manifest.json"`。`write_manifest: true` 可在不启用 changed-only 的情况下只写 manifest，适合首次建立 CI 基线。manifest 不表达热更新版本、远端发布、签名或业务环境；这些策略应由项目流水线读取报告后自行组合。

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

如果希望同一次导表同步生成静态访问器，给 Profile 配置 `access_output_path`。`access_options` 会传给 `GFConfigAccessGenerator`，因此可以选择是否生成 typed record 包装。非空的 Unicode 表名无法直接产生 ASCII 标识符时会使用稳定的 `table_<sha256-prefix>` 内部标识，但访问器仍保留原始表名；生成结果公开 `input_schema_count`、`emitted_schema_count`、`skipped_schema_count` 和 `issues`，只要有输入 schema 缺少表名就会在写文件前失败关闭：

```gdscript
profile.access_output_path = "res://generated/config/gf_config_access.gd"
profile.access_class_name = "GFConfigAccess"
profile.access_provider_accessor = "Gf.get_utility(GFConfigProvider) as GFConfigProvider"
profile.access_options = {
	"include_typed_records": true,
}

var export_result: Dictionary = pipeline.export_profile(profile)
var access_result: Dictionary = GFVariantData.get_option_dictionary(export_result, "access_result")
var artifact_report: Dictionary = GFVariantData.get_option_dictionary(access_result, "artifact_report")
```

没有配置 `access_output_path` 时，Profile 导出只构建并保存数据库，`access_result.skipped` 会为 `true`。访问器生成失败会让本次 `export_profile()` 返回失败，但已经构建出的数据库资源仍会留在结果字典中，便于 CI 或编辑器工具展示问题。

需要从资源路径执行时，使用 Runner：

```gdscript
var runner: GFConfigPipelineRunner = GFConfigPipelineRunner.new()
var run_result: Dictionary = runner.export_profile_path("res://config/build/dev_profile.tres")
```

需要在 CI 或本地批处理里直接执行同一份 Profile 时，可以使用工具包自带的 Godot 原生命令入口：

```powershell
godot --headless --path . -s res://addons/gf/tools/config_pipeline/gf_config_pipeline_cli.gd -- --profile res://config/build/dev_profile.tres --operation export --json --strict
```

常用参数包括：

- `--operation export|build|load`：默认 `export`，分别对应导出保存、仅构建数据库、仅加载 Profile。
- `--output <URI>`：以 `res://` 或 `user://` URI 覆盖 Profile 的 `output_path`。
- `--access-output <URI>`、`--class-name <name>`、`--provider-accessor <expr>`：以 resource URI 覆盖访问器输出，并覆盖生成配置。
- `--dry-run`：执行构建和产物预检，但不写入数据库或访问器文件。
- `--changed-only`：manifest fresh 时跳过导出；manifest 不存在或输入变化时正常导出。
- `--manifest <URI>`：以 `res://` 或 `user://` URI 覆盖 artifact manifest 输出和读取路径。
- `--write-manifest`：即使没有启用 `--changed-only`，成功导出后也写入 manifest。
- `--strict`：把校验 warning 也视为命令失败，适合 CI。
- `--json` / `--compact`：输出结构化 JSON 报告，便于外部流水线解析。

命令成功返回 `exit_code = 0`；Profile 加载、构建、保存或严格校验失败返回 `1`；参数错误返回 `2`。同一能力也可以在编辑器工具或项目脚本中直接调用：

```gdscript
var command: GFConfigPipelineCommand = GFConfigPipelineCommand.new()
var command_result: Dictionary = command.run(PackedStringArray([
	"--profile",
	"res://config/build/dev_profile.tres",
	"--dry-run",
	"--json",
]))
```

生成的 `GFConfigDatabaseResource` 只作为表资源聚合产物保存；运行时读取 Godot Resource 时使用 `GFResourceConfigProvider.from_database(database)` 接入 `GFConfigProvider` 的整表、按 ID 和命名索引查询入口。访问器脚本只是制作期生成的轻量 GDScript 封装，可以提交到项目版本库，也可以由项目 CI 生成后参与校验。JSON 导出是通用数据产物，适合交给项目侧热更新、签名、压缩或远端发布流水线继续处理。

运行时或工具侧需要对配置记录做临时筛选、排序、分页或字段路径读取时，可以用 `GFConfigTableQuery` 包装 `GFConfigTableResource` 或记录数组。它只提供通用记录查询，不替代 `GFConfigProvider` 的整表、按 ID 和命名索引入口，也不写入具体表的业务访问规则。

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

如果表格来源更适合把字段名和类型分成两行，可以同时开启 `typed_header_type_row`。第一行保留稳定字段名，第二行写类型声明；类型行只用于生成 schema，不会进入最终记录列表：

```gdscript
source.schema_options = {
	"typed_headers": true,
	"typed_header_type_row": true,
}
```

```csv
id,name,power
int!,string,float
1,Potion,2.5
```

类型化表头生成的是已有的 `GFConfigTableSchema` / `GFConfigTableColumn`，默认启用字段转换、默认不允许未声明字段。显式挂在 `source.schema` 上的 schema 优先级更高；类型化表头适合降低简单表的维护成本，不替代复杂表的索引、引用和业务校验资源。

## 使用边界

当前工具包只沉淀稳定通用机制：来源声明、版本化 IR、分阶段编译、Profile 路径执行、CSV / JSON / ConfigFile / XLSX 解析、schema 校验、跨表引用校验、记录转换、索引重建、`.tres/.res` 保存、JSON 目标和文件提交事务。

CSV 与 XLSX 会复用同一套表格预处理选项：`parse_options.comment_prefixes` 可过滤本地备注行和备注列，`comment_row_prefixes` / `comment_column_prefixes` 可分开控制；`condition_symbols` 配合 `enable_condition_directives` 可保留简单 `#if SYMBOL ...` / `#endif` 块内命中的数据行。`#if` 必须至少声明一个 symbol，裸指令会在对应物理行终止导入。这些选项只处理通用表格结构，不表达业务分端规则，复杂表达式或发布矩阵仍应放在项目流水线层。

XLSX 支持定位为通用表格输入适配：默认读取 workbook 中的第一个 sheet，也可以通过 `parse_options.sheet_name` 或 `parse_options.sheet_index` 选择工作表，通过 `parse_options.header_row` 指定表头行。解析结果按表头映射为记录字典，再复用现有 schema 校验和类型转换。解析器会限制 workbook entry 数量、行数、列数和单元格数量，避免把异常或过大的表格文件拖进编辑器或 CI；`sharedStrings.xml`、`workbook.xml`、关系表和 worksheet 任一 XML 非正常结束、根不完整或存在截断尾部都会整表失败。`max_xlsx_file_bytes` 的负值只关闭项目配置的文件预算；进入共享 ZIP 读取边界后仍会收敛到框架绝对 archive 与累计解压硬上限，不会产生真正无界的读取。公式计算、样式日期语义、合并单元格、多表业务拆分、策划提交流程和分端发布策略不属于这一层。

CSV / JSON / ConfigFile 的 Reader 默认用 `max_source_file_bytes = 64 MiB` 在读取前限制单文件，但 Layout 复用的直接 importer 尚无行、列、累计单元格或嵌套节点预算；文件预算不能证明解析峰值内存和主线程时间有同样上界。处理不受信来源时，项目应先收紧文件预算并在进入 Pipeline 前做来源级预检；不要通过传负值关闭限制后仍把该路径描述为有界导入。

`GFConfigPipelineProfile` 只表达导表任务 manifest。`GFConfigBuildProfile` 仍负责按 groups / tags 裁剪 schema 或记录，两者可以组合使用，但职责不同。

`GFConfigPipelineRunner` 不解释命令行参数，不创建编辑器 UI，也不调用外部进程；`GFConfigPipelineCommand` 只负责 Godot 原生命令参数到 Runner 的适配。复杂 Excel、多 sheet、远程拉取、策划提交流程、分端裁剪、热更新打包、加密压缩和导出菜单属于项目流水线或独立工具插件策略。项目可以在这些策略层调用 `GFConfigPipeline`、`GFConfigPipelineRunner` 或 `GFConfigPipelineCommand`，但不应把具体业务规则写回框架工具包。
