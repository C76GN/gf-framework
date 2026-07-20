# 资产目录与素材库底座

`GFAssetCatalog` 是项目素材库、编辑器资源面板和构建审计可以共享的资产索引。它管理稳定 `asset_id`、标题、说明、标签、分类、主资源路径、预览路径、关联 `GFResourceRegistry` 条目和项目自定义 metadata；它不规定项目目录布局、业务分类、授权规则、下载渠道或导出策略。

`GFResourceRegistry` 适合表达“稳定资源 ID -> 单个资源路径”。当项目需要把多个资源、备注、标签、预览和引用审计聚合为一个可管理资产时，再使用 `GFAssetCatalogEntry` 和 `GFAssetCatalog`。

## 核心类

- `GFAssetCatalogEntry`：单个资产记录，可引用主资源、预览资源和多个资源注册表条目。
- `GFAssetCatalog`：资产目录，支持按标签、分类、来源、类型、缓存键和关联资源条目查询，也支持文本搜索、分页摘要和序列化。
- `GFAssetCatalogSourceProvider`：资产来源 provider 基类，用于把项目目录、资源注册表、内容包、外部库或项目数据库转换为资产目录。
- `GFAssetCatalogSourceRegistry`：来源注册表，按优先级汇聚多个 provider，生成可重建的 catalog snapshot 和 JSON-safe 报告。
- `GFResourceRegistryAssetSourceProvider`：把现有 `GFResourceRegistry` 适配为资产目录来源。
- `GFAssetCollection`：只保存稳定、有序的 `asset_id` 集合以及展示信息和调用方 metadata，不持有资源实例。
- `GFAssetPreloadPlan`：稳定 ID 解析后的不可变加载计划；缺失 ID 会保留为无效计划项，而不是静默缩小请求集合。
- `GFAssetLoadSession` / `GFAssetLoadSessionResult`：把加载、提交和回滚组成一次明确终态的事务会话。

## 典型流程

已有资源注册表时，可以先把它作为素材库来源：

```gdscript
var resources := GFResourceRegistry.new()
resources.set_entry(
	GFResourceRegistryEntry.new().configure(
		&"ui.save_icon",
		"res://ui/icons/save.png",
		"Texture2D",
		{
			"display_name": "Save Icon",
			"tags": PackedStringArray(["ui", "icon"]),
			"category": "interface",
		}
	)
)

var source := GFResourceRegistryAssetSourceProvider.new()
source.configure_registry(resources, &"project_resources", {
	"priority": 100,
})

var sources := GFAssetCatalogSourceRegistry.new()
sources.register_source(source)

var catalog := sources.build_catalog()
var page := catalog.search_page("save icon", 1, 24)
```

项目也可以直接维护资产条目：

```gdscript
var catalog := GFAssetCatalog.new()
catalog.set_entry(
	GFAssetCatalogEntry.new().configure(&"character.hero.idle", "res://characters/hero_idle.png", {
		"title": "Hero Idle",
		"tags": PackedStringArray(["character", "sprite"]),
		"category": "characters",
		"preview_path": "res://characters/previews/hero_idle.png",
		"metadata": {
			"author": "internal",
		},
	})
)

var character_ids := catalog.query(GFAssetCatalog.GROUP_SOURCE_TAGS, "character")
var summaries := catalog.make_asset_summaries(character_ids)
```

## 有序资产集合

当关卡编辑器、音效试听器和 UI 图标选择器需要保存“这一次要展示哪些资产以及它们的顺序”时，可以使用 `GFAssetCollection`。集合不复制 Catalog 条目，也不把“角色”“关卡模块”等业务类别写进框架；它只保存稳定 ID，并在目录更新后重新解析。

```gdscript
var collection := GFAssetCollection.new().configure(
	&"chapter_2.preview_set",
	PackedStringArray(["scene.bridge", "scene.tower", "scene.gate"]),
	{"title": "Chapter 2 Preview Set"}
)

var integrity := collection.validate_against(catalog)
if not integrity.is_ok():
	push_warning(integrity.make_summary())

var ordered_entries := collection.resolve_entries(catalog)
```

完整性报告会区分空 ID、重复 ID 和 Catalog 缺失项，并在 `extra_fields` 中提供 `resolved_asset_ids`、`missing_asset_ids`、`duplicate_asset_ids` 与计数。`resolve_entries()` 保持集合顺序，但跳过无效、重复和缺失项；需要 fail closed 的加载流程应先检查报告，再把集合 ID 交给 `GFAssetCatalog.make_preload_plan()`。

## 从目录到事务加载

目录只负责把稳定 `asset_id` 映射成计划，`GFAssetUtility` 负责实际缓存与所有权。对场景切换、模式切换或成组素材替换，先创建计划，再使用加载会话；会话把路径装入唯一 staging group，全部成功后才提交目标 group。

```gdscript
var plan := catalog.make_preload_plan(
	PackedStringArray(["character.hero.idle", "ui.save_icon"]),
	&"gameplay.required",
	{"pin_cache": true}
)
var session := asset_utility.start_preload_session(plan)

if not session.is_completed():
	await session.completed
var result := session.get_result()
if result == null or not result.is_successful():
	push_error("Asset transaction failed")
```

计划校验或任一资源加载失败时，会话 fail closed 并撤销 staging group；手动 `rollback()` 在加载中会等待在途回调收敛。回滚只释放本会话的分组所有权，不调用 `remove_cache()` 破坏其他句柄或分组共享的资源。`completed` 只发出一次，调用方从 `GFAssetLoadSessionResult` 读取 committed / failed / rolled_back、失败路径和回滚原因。

## Source Provider

素材库不应该只扫描某个固定目录。更稳的做法是把不同来源都转换为 provider，再由 `GFAssetCatalogSourceRegistry` 汇聚：

- 项目目录扫描 provider。
- `GFResourceRegistry` provider。
- 内容包 manifest provider。
- 资产 metadata provider。
- 团队共享库或外部数据库 provider。

默认合并时，高优先级 provider 先写入，同 `asset_id` 的低优先级条目会被跳过。需要诊断重复 ID 时调用 `build_catalog_report()`，报告会返回 `sources`、`entry_count`、`catalog_data` 和 `issues`。

## 使用边界

- `GFAssetCatalog` 是索引，不是资源缓存；加载和生命周期仍交给 `GFAssetUtility`、`GFResourceResolverUtility` 或项目自己的加载流程。项目若已有业务资源目录，应把它适配成 catalog/provider，不要复制一套缓存所有权。
- `asset_id` 应作为长期稳定 ID，不应直接等同资源路径。
- `GFAssetCollection` 是有序引用集合，不是调色板 UI、收藏夹数据库或资源缓存；项目可以在它之上实现任意编辑器交互，但不能假设 GF 会解释集合用途。
- 标签、分类、备注和 metadata 只作为通用字段保存和索引；GF 不解释 `character`、`weapon`、`quest`、`license` 等项目语义。
- 引用审计、替换资源和未使用资源清理应先生成 dry-run 计划与报告，再由项目或编辑器工具决定是否执行。
- 预览图生成应通过编辑器侧 preview provider 或资源自身预览能力接入，不要让 catalog 直接解码大图或持有纹理缓存。
