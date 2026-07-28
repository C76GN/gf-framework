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

## Feature 重映射计划

`GFResourceFeatureRemapTools` 根据调用方提供的 feature 集合与 remap 声明生成纯数据计划。它只回答“当前 feature 应把哪个 source 解析到哪个 target”以及“哪些 unused target 可以由外层工具跳过”，不读取 ProjectSettings、不注册导出插件、不写文件，也不决定移动端、Web、语言包或 DLC 的项目策略。

```gdscript
var plan := GFResourceFeatureRemapTools.build_remap_plan({
	"res://ui/panel.tres": [
		["mobile", "res://ui/panel_mobile.tres"],
		["web", "res://ui/panel_web.tres"],
	],
}, PackedStringArray(["mobile"]))

for record in GFVariantData.get_option_array(plan, "resolved"):
	print(record["source_path"], " -> ", record["target_path"])
```

entry 的声明顺序就是优先级；多个 active feature 同时命中时选择最靠前的 entry。`skip_paths` 只是一份候选诊断，项目自己的导出器、包构建器或安装器需要结合实际导出列表、受保护路径和资源写入策略再执行。

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

## 脚本结构检查

`GFScriptStructureTools` 用 Godot 的 `Script` 反射结果生成纯数据描述，并可按调用方声明检查常量、方法、属性、信号和继承关系。它不会创建脚本实例，也不假设组件架构、资源数据库、导入器或项目业务层类型，适合编辑器工具、导入预检、测试断言和生成器自检复用。

```gdscript
var script: Script = load("res://tools/importers/item_importer.gd")
var report := GFScriptStructureTools.check_script_structure(script, {
	"base_class": "RefCounted",
	"required_methods": [
		{ "name": "import_rows", "min_argument_count": 1 },
	],
	"required_signals": PackedStringArray(["import_finished"]),
})

if not GFVariantData.get_option_bool(report, "ok"):
	print(GFVariantData.get_option_array(report, "issues"))
```

路径扫描通过 `GFResourceRegistryTools.scan_resource_paths()` 执行，并默认只收集 `.gd`。结果按目录深度优先排序，便于需要先处理父目录脚本、再处理子目录脚本的工具链稳定复现。

需要给编辑器工具或代码生成器准备函数文本时，可把 Godot 方法元数据交给 `format_method_signature()` 或 `format_method_stub()`。它们只返回报告和文本片段，不会插入、保存或修改脚本文件。

```gdscript
var methods := script.get_script_method_list()
if not methods.is_empty():
	var method := GFVariantData.as_dictionary(methods[0])
	var stub := GFScriptStructureTools.format_method_stub(method, {
		"body_lines": PackedStringArray(["pass"]),
	})
	print(GFVariantData.get_option_string(stub, "stub"))
```

## 资源属性 Patch

`GFResourcePropertyPatch` 用一组属性定义和覆盖值描述资源差异。它默认只写入 `definitions` 声明过的属性，并要求目标对象真实暴露该属性；需要生成变体资源时，`build()` 会先复制 base Resource，再把覆盖值应用到副本。

```gdscript
var patch := GFResourcePropertyPatch.new()
patch.definitions = [
	GFResourcePropertyPatch.make_definition(&"bg_color", TYPE_COLOR),
	GFResourcePropertyPatch.make_definition(&"corner_radius_top_left", TYPE_INT),
]
patch.set_patch_value(&"bg_color", Color("#3f7cff"))

var report := patch.build(base_stylebox)
var result_stylebox := GFVariantData.get_option_value(report, "resource") as StyleBoxFlat
```

需要给自定义 Inspector 暴露补丁字段时，可以用 `make_property_list()` 生成 Godot `_get_property_list()` 可返回的条目。属性定义只描述路径、类型、hint、分组和默认值；具体视觉 token、资源目录、皮肤层级和回退策略仍应留在项目侧。

需要把多层覆盖拆开时，可以用 `GFResourceOverlay` 或 `GFResourcePropertyPatch.apply_patch_chain()` 按顺序应用多份补丁。靠后的补丁覆盖同一属性，报告会保留每个 patch 的应用结果，方便编辑器工具显示“哪一层改了什么”：

```gdscript
var overlay := GFResourceOverlay.new()
overlay.base_resource = base_stylebox
overlay.patches = [base_patch, platform_patch, user_patch]

var report := overlay.resolve({
	"include_patch_reports": true,
})
var stylebox := GFVariantData.get_option_value(report, "resource") as StyleBoxFlat
```

覆盖链仍然只处理声明过的属性和对象写入，不负责选择平台、语言、主题层级或用户配置来源。项目侧可以把这些策略转换成 patch 顺序，再交给 GF 输出稳定报告。

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

物化默认只允许写入 `user://`。需要写入 `res://` 的编辑器或构建工具必须显式传 `allow_res_path = true`，这样路径副作用不会在普通运行时被隐式打开。`materialize_temp()` 的 `file_name` 是严格 ASCII portable leaf；空名、`.`、`..`、路径分隔符、控制字符、Windows 保留字符或设备名会在 `path_join` 前以 `invalid_file_name` 失败，不会被静默改写成另一个文件名。写入复用有界产物事务；若报告中的 `recovery_required = true`，调用方必须保留 `recovery_transaction`，并原样交给 `GFArtifactWriteTransaction.rollback()` 或 `complete()` 终结事务，不能把它当作普通 `write_failed` 丢弃。

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
	"check_source_exists": false,
})
```

`get_validation_report()` 会检查来源、目标、操作类型、可选的源文件存在性和默认启用的重复目标路径；`get_operation_summary()` 会按操作、来源格式、目标格式和重复目标输出纯数据摘要，便于批处理 UI 或 CI 在执行前展示影响范围。`get_repair_report()` 会输出可提示给工具 UI 的修复建议，例如跳过无效条目或补齐目标路径。项目如果需要真正复制、转换格式、重建 import remap 或写入数据库，应把计划交给自己的工具链执行，GF 不在这里规定项目目录或业务 schema。

`GFTextureSetClassifier` 可把常见 PBR 贴图后缀归并成纹理集，并在真正生成材质前检查同角色冲突和项目要求的必需角色。例如角色、载具或场景模型的资产包同时带有 `normalgl` 与 `normaldx` 时，两张图都会被识别为 normal，但分类器不会根据输入顺序任选一张：

```gdscript
var classification := GFTextureSetClassifier.classify_files(texture_paths, {
	"required_roles": [
		GFTextureSetClassifier.ROLE_ALBEDO,
		GFTextureSetClassifier.ROLE_NORMAL,
		GFTextureSetClassifier.ROLE_ORM,
	],
})

if not GFVariantData.get_option_bool(classification, "ok"):
	show_import_issues(GFVariantData.get_option_array(classification, "issues"))
```

每个集合的 `duplicate_roles` 会列出冲突角色及全部稳定排序的路径，`missing_roles` 会列出缺少的 `required_roles`；顶层报告同时提供有效/无效集合和两类问题的计数。没有配置 `required_roles` 时允许部分纹理集，但重复角色始终使该集合无效，歧义角色也不会写入单值 `textures` 字典。

确认分类策略后，可以把通过完整性校验且无歧义的集合转换为 `GFImportPlan` 条目：

```gdscript
var plan := GFTextureSetClassifier.build_material_import_plan(
	PackedStringArray([
		"res://textures/stone_albedo.png",
		"res://textures/stone_normal.png",
		"res://textures/stone_roughness.png",
		"res://textures/stone_orm.png",
	]),
	"res://generated/materials"
)
```

导入计划会跳过重复或缺少必需角色的集合，并在 metadata 中保留 `valid_texture_set_count`、`invalid_texture_set_count`、问题计数和 `texture_set_issues`，供批处理 UI 或 CI 阻止不完整资产进入后续写入。分类器只输出角色字典、source trace 和诊断，不创建 `StandardMaterial3D`，也不假设目标项目的材质目录、压缩策略、导入 preset 或 shader 参数。默认角色覆盖 albedo、normal、roughness、metallic、packed ORM、AO、height 和 emission；项目导入器可以读取计划中的 metadata，再决定实际材质类型和写入流程。
