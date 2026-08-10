# Content Package 内容包

Content Package 扩展用于把项目或插件中的可选内容收束为稳定 manifest、依赖图和资源键映射。它适合 DLC、章节包、主题包、可选素材包、项目内测试内容集合，或任何需要“先声明内容，再由项目决定如何启用”的场景。

它只处理包 ID、版本、依赖、资源键、路径安全、诊断报告和资源解析器注册；不负责下载、工作坊、PCK 装载、启用策略、业务 schema、内容类型语义或玩法规则。

## 核心模型

- `GFContentPackageManifest` 描述一个内容包，读取 `gf_content_package.json`，并校验资源路径是否留在包根目录内。
- `GFContentPackageCatalog` 管理一组 manifest，报告重复包 ID、缺失依赖和循环依赖，并按依赖优先顺序注册资源键。
- `GFContentPackageQuery` 与 `GFContentPackageQueryResult` 提供严格 AND 条件、可选依赖闭包和类型化查询终态，不用空数组混淆“零匹配”与“目录无效”。
- `GFContentPackageUtility` 按稳定 owner 维护显式 source root，发现 root 或直接子目录中的 manifest，重建 catalog，并把资源映射同步到 `GFResourceResolverUtility`。
- `GFContentPackageAssetCatalogProvider` 把查询后的内容包资源快照适配为通用 `GFAssetCatalog`，不负责运行时挂载或内容启用。

## Manifest 形态

```json
{
  "schema_version": 1,
  "package_id": "author.chapter_one",
  "display_name": "Chapter One",
  "version": "1.0.0",
  "safety_kind": "data_only",
  "forbidden_resource_extensions": ["gd", "gdshader", "dll"],
  "content_types": ["scene", "audio"],
  "dependencies": ["author.base"],
  "resources": [
    {
      "key": "chapter_one.main_scene",
      "path": "scenes/main.tscn",
      "type_hint": "PackedScene",
      "priority": 0,
      "metadata": {
        "group": "chapter_one"
      }
    }
  ],
  "metadata": {}
}
```

`path` 可以是包根目录内的相对路径、`res://` 路径或 `user://` 路径。相对路径会归一化到 manifest 所在目录；显式路径必须留在内容包根目录内；`uid://`、绝对路径和越界 `..` 路径会进入错误报告。只要 manifest 声明资源，`root_path` 就必须是非空且受支持的包根；空根不会被解释为“允许任意路径”。Content Package 不接受 `uid://`，因为 manifest 校验必须能证明资源仍在包根目录内。

JSON 字段按稳定 schema 严格读取。字符串、数组、字典、资源条目和数值字段不会通过 `str()`、`int()` 或单值包装自动纠正；类型错误会以 `invalid_manifest_field_type` 或 `invalid_resource_field_type` 进入报告。兼容别名（如 `package_id/id`、`key/resource_key`）可以单独使用，但同时出现时必须表示相同的规范化值；冲突会以 `conflicting_alias_fields` fail closed。项目应在导入或迁移层先修正源数据，不要依赖运行时宽松转换。

## 来源根与安全分类

`GFContentPackageUtility.register_source_root_for_owner()` 支持 `res://` 与 `user://` 来源根。项目可以把内置内容放在 `res://content_packages`，把运行时下载、编辑器导入或用户生成内容放在 `user://content_packages`，再用同一套 `rebuild_catalog()` 和资源键注册流程处理。多个 owner 可以共同持有同一 root；只有最后一个 owner 释放后，该 root 才会从有效来源集合移除。

需要一次切换一组来源时，使用 `replace_owner_source_roots()`。它会先规范化并校验全部路径，任一无效路径都会拒绝整次替换，上一份 owner 快照保持不变。`register_source_root()`、`unregister_source_root()` 和 `clear_source_roots()` 仍可用于手工配置，但只操作公开常量 `DEFAULT_SOURCE_ROOT_OWNER_ID` 对应的 manual scope，不会清除其他模块持有的 root。

`GFContentPackageManifest.safety_kind` 默认是 `data_only`。该分类会拒绝脚本、动态库、shader、shell 脚本等可执行或代码形态扩展名；项目可以通过 `forbidden_resource_extensions` 追加拦截项。只有确实由开发者控制、并且项目侧已经决定如何加载和审计代码资源时，才应把分类改成 `trusted_developer`。

默认校验只检查 manifest 直接声明的路径。对不可信或外部导入的 `data_only` 内容，应启用 `{ "check_resource_dependencies": true }`；校验器会通过资源依赖图检查场景、资源等文件传递引用的脚本、shader 或动态库，并在扫描不完整时 fail closed。`dependency_options` 可继续传入扫描预算。这个预检不下载文件、不加载脚本，也不声明某个包可以被普通用户信任执行；完整性校验、解包、隔离和启用策略仍属于项目安装器或独立工具。

## 诊断报告

`GFContentPackageManifest.get_validation_report()`、`GFContentPackageCatalog.get_graph_report()`、`GFContentPackageCatalog.register_resources()` 和 `GFContentPackageUtility.rebuild_catalog()` 返回 `GFValidationReportDictionary` 形态的通用报告，包含 `ok`、`healthy`、`summary`、`issues`、`next_action`、计数字段和内容包上下文。

报告里的 `kind` 是稳定诊断键，例如 `invalid_resource_path`、`resource_path_outside_package`、`missing_dependency`、`dependency_cycle`、`invalid_manifest_file`。项目编辑器工具可以直接按这些键渲染问题列表，也可以追加自己的业务 schema 校验报告；GF 不把单个内容类型的字段解释写入 Content Package 扩展。

`GFContentPackageUtility.rebuild_catalog()` 发现坏 JSON 或无法读取的 manifest 文件时，会把该文件作为 `invalid_manifest_file` error 纳入同一份最终报告，并重新计算 `ok`、`error_count` 和 `issue_count`。调用方不需要单独扫描加载失败列表。

已成功解析、但缺少稳定 `package_id` 的 manifest 也不会从候选集合静默消失。Catalog 会保留拒绝输入的索引、来源路径和原因，`get_graph_report()` 通过 `rejected_manifest_count`、`rejected_manifest_inputs` 及具体 manifest issue 报告它们；Utility 仅在不存在任何拒绝或错误时提交候选，因此失败重建会保留上一份有效 catalog。

Catalog 对 manifest 采用深快照语义：`add_manifest()` 不保留调用方对象，`get_manifest()`、`get_catalog()` 和 `catalog_rebuilt` 也不暴露内部可变实例。注册、注销或清空 source root 会立即失效当前 catalog，调用方必须重新 `rebuild_catalog()` 后再同步资源。

## 查询与资产目录适配

`GFContentPackageQuery` 的所有非空条件采用严格 AND 语义。列表条件要求 manifest 包含全部指定值；`package_ids` 和 `allowed_safety_kinds` 是允许集合。`max_results` 只限制直接命中包，`include_dependencies` 会在限制之后补齐传递依赖，并按 dependency-first 顺序返回。查询开始前会验证完整 catalog，依赖图或 manifest 无效时返回 `STATUS_INVALID_CATALOG`，不会泄漏部分匹配。

```gdscript
var query := GFContentPackageQuery.new()
query.required_content_types = PackedStringArray(["theme"])
query.required_metadata = {"channel": "stable"}
query.include_dependencies = true

var result := packages.get_catalog().query_packages(query)
if result.is_successful():
	for manifest in result.get_manifests():
		print(manifest.package_id)
```

需要把内容包显示在素材浏览器或交给资产预加载计划时，使用 `GFContentPackageAssetCatalogProvider`。默认 `asset_id` 采用 `package_id/resource_key`，避免普通 ID 下不同包中的局部资源键互相覆盖；原始资源键保留在 `resource_entry_ids` 和 metadata 中，可继续交给 Resolver。在规范 ID 语法确定前，如果两个不同二元组生成同一复合 ID，Provider 会返回 `null` 并拒绝整份候选目录，不会覆盖后返回部分快照。Provider 只构建隔离快照，项目可以把结果交给 `GFAssetCatalogRuntime` 挂载，或直接用于离线工具。

需要把 manifest、query 或导出计划交给 JSON 日志、CI 或编辑器面板时，可以使用各自的 `to_report_dictionary()`。它会通过 `GFReportValueCodec` 输出 JSON-safe 结构，避免 Resource、对象引用、循环容器、非有限浮点或未脱敏路径直接进入公开报告；Provider 的 `get_debug_snapshot()` 已使用 query 的报告边界，而不是进程内状态字典。

## 典型流程

```gdscript
var packages: GFContentPackageUtility = Gf.get_utility(GFContentPackageUtility)
packages.register_source_root_for_owner(&"project.builtin_content", "res://content_packages")

var report: Dictionary = packages.rebuild_catalog({
	"check_resource_exists": true,
	"check_resource_dependencies": true,
})
if GFVariantData.get_option_bool(report, "ok"):
	var resolver: GFResourceResolverUtility = Gf.get_utility(GFResourceResolverUtility)
	packages.register_resources(resolver)
```

项目之后可以用资源键加载内容：

```gdscript
var scene: Resource = resolver.load(&"chapter_one.main_scene", "PackedScene")
```

`register_resources()` 会先构建 owner 的完整路径快照，再通过 `GFResourceResolverUtility.replace_owner_paths()` 原子提交。任一条目 schema 或资源身份无效时，上一份 Content Package 解析表保持不变；成功后才一次性替换该 owner 的全部记录。下一次重建或卸载内容包时，它不会删除项目手写注册或其他系统贡献的同 key 资源。项目需要固定覆盖内容包资源时，可以用更高优先级的 resolver 记录或 provider 显式表达覆盖策略。

## 导出计划

`GFContentPackageExportPlan` 可以从单个 manifest 或 catalog 构建可审计的导出条目列表。它只输出 `source_path`、`archive_path`、`role`、`resource_key`、`package_id`、`type_hint` 和诊断报告，不写 zip、不改 Godot remap，也不规定项目发布流程。

```gdscript
var plan := GFContentPackageExportPlan.from_manifest(manifest, {
	"archive_root": "packages/chapter_one",
	"include_resource_dependencies": true,
})

var report := plan.get_validation_report()
```

需要构建、安装或缓存预检查时，可以额外调用 `get_artifact_report()`。该报告会按导出条目读取本地源文件，输出 `size_bytes`、可选 `sha256`、总大小、缺失/不可读计数，并可校验条目 metadata 中的 `expected_sha256`、`expected_size` 或 `expected_size_bytes`。它仍然只生成报告，不联网、不下载、不签名，也不决定内容启用策略。

需要把导出计划、artifact 报告和目标环境要求合成一份预检结果时，可以调用 `get_preflight_report()`。调用方传入 `GFCompatibilityProfile`，再通过 `minimum_godot_version`、`minimum_framework_version`、`required_platforms` 或 `required_features` 声明显式约束；GF 只合并报告，不决定内容包是否应该下载、安装或启用。

项目可以把这份计划交给自己的构建脚本、编辑器面板或 CI 流程继续处理。需要下载、签名、平台上传或工作坊发布时，应在项目工具或独立插件中完成。

从 catalog 构建多包计划时，每个包的 archive path 会自动加上稳定 package ID 作用域，依赖条目也保留实际 owner package ID。这样两个包可以拥有相同相对路径而不会在归档中碰撞；单 manifest 计划仍按调用方传入的 `archive_root` 组织。

### 项目侧外部产物导出配方

项目需要生成预览图、截图、图集和映射文件，再交给外部目标时，可以在项目编辑器工具或独立插件中组合现有机制。这个配方不增加业务生成器，也不让 Content Package 承担写出或上传。

| 组件 | 负责 | 不负责 |
| --- | --- | --- |
| `GFThumbnailRenderer` | 把 `CanvasItem`、`Node3D` 或 `Mesh` 渲染为短生命周期 `Image`，并为批量预览提供可取消任务 | 保存文件、拼图、目标平台命名或上传 |
| `GFScreenshotUtility` | 捕获 Viewport，或把已有 `Image` 保存为 PNG、JPEG、WebP，并返回保存记录 | 解释素材业务类型或决定发布策略 |
| `GFRectPacking2D` | 在显式数量和容器预算内计算图集放置矩形 | 复制像素、创建纹理资源或写入文件 |
| `GFGeneratedArtifactReport` | 记录产物路径、状态、所有权和 dry-run 结果，并汇总批次 | 替代二进制写入器、内容校验或远端回执 |
| `GFContentPackageExportPlan` | 收集源路径与归档路径，并生成计划、完整性和兼容性预检报告 | 创建归档、签名、联网、写入目标或启用内容 |

推荐流程如下：

1. 项目工具先冻结一份导出请求：稳定 artifact ID、稳定输入顺序、最大图片数量、分辨率、图集尺寸、暂存根目录和取消 owner 都必须显式给出。
2. 资源预览通过 `GFThumbnailRenderer` 生成，Viewport 画面通过 `GFScreenshotUtility` 捕获；两类结果都先收束为 `Image`。空图像、已取消任务或超出预算应直接阻断本批次。
3. 项目按稳定 ID 排序尺寸，再调用 `GFRectPacking2D.pack_fixed()` 或 `pack_square()`。只要存在未放置项，就报告失败；像素复制、边距填充和 atlas `Image` 创建仍由项目 materializer 实现。
4. 二进制图像用 `GFScreenshotUtility.save_image()` 写入受控的 `res://` 或 `user://` 暂存根；映射 JSON 等文本用 `GFGeneratedArtifactReport.save_text()` 写入，并设置 `allowed_roots`。二进制保存记录可通过 `make_report()` 归一化，再用 `summarize_reports()` 汇总，避免未报告的部分产物进入后续步骤。
5. 从 manifest 或 catalog 建立 `GFContentPackageExportPlan`，再用 `add_entry()` 把已生成的 atlas 和映射文件加入计划。只有计划校验、artifact 完整性报告和项目要求的 preflight 全部通过，才把不可变暂存集合交给下一层。
6. 项目自有目标 Adapter 负责目标格式、认证、限流、幂等键、重试、上传或文件写出以及失败清理。Adapter 只消费已冻结的计划、报告和暂存产物；凭据、远端对象 ID 和业务发布状态不得写入通用产物报告。

至少覆盖 dry-run、取消、空图像、超量输入、无法放置、重复归档路径、写入失败、完整性不匹配、Adapter 部分失败和幂等重试。编辑器预览节点与渲染任务归属当前工具会话，暂存文件归属项目生成目录，远端回执则由项目持久化边界管理。

相关细节见[编辑器访问器与缩略图](../../kernel/architecture/editor-accessors.md)、[截图捕获与批量保存](../../standard/utilities/runtime/debug-observability/debug-visual-inspection/screenshots.md)、[2D 矩形打包](../../standard/foundation/grid-spatial/rect-packing-2d.md)和[编辑器命令、动作与工具协议](../../editor/tool-protocols.md)。

## 使用边界

- Content Package 不内置 `quest`、`item`、`biome`、`npc`、`skin` 等业务字段；这些字段应由项目 schema 或独立插件解释。
- 内容包之间只声明依赖顺序，不声明启用条件、版本约束求解、下载来源或平台服务账号。
- 查询只解释稳定 manifest 字段；复杂 OR、版本约束和业务 schema 查询应由项目组合多个查询结果或在独立规则层完成。
- 资源键冲突时，依赖包先注册，依赖方后注册；项目可以用 resolver priority、owner-scoped 注册或 provider 明确覆盖基础包资源。
- 需要多扩展组合时，在项目 Installer 或独立插件中组合 `GFContentPackageUtility`、`GFResourceResolverUtility` 和项目 schema，不把组合逻辑写回 GF 内置扩展。

## API Reference

完整类、方法和字段列表见 [Content Package API Reference](../../reference/api/extensions-content-package.md)。
