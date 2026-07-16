# 资产目录与素材库底座

`GFAssetCatalog` 是项目素材库、编辑器资源面板和构建审计可以共享的资产索引。它管理稳定 `asset_id`、标题、说明、标签、分类、主资源路径、预览路径、关联 `GFResourceRegistry` 条目和项目自定义 metadata；它不规定项目目录布局、业务分类、授权规则、下载渠道或导出策略。

`GFResourceRegistry` 适合表达“稳定资源 ID -> 单个资源路径”。当项目需要把多个资源、备注、标签、预览和引用审计聚合为一个可管理资产时，再使用 `GFAssetCatalogEntry` 和 `GFAssetCatalog`。

## 核心类

- `GFAssetCatalogEntry`：单个资产记录，可引用主资源、预览资源和多个资源注册表条目。
- `GFAssetCatalog`：资产目录，支持按标签、分类、来源、类型、缓存键和关联资源条目查询，也支持文本搜索、分页摘要和序列化。
- `GFAssetCatalogSourceProvider`：资产来源 provider 基类，用于把项目目录、资源注册表、内容包、外部库或项目数据库转换为资产目录。
- `GFAssetCatalogSourceRegistry`：来源注册表，按优先级汇聚多个 provider，生成可重建的 catalog snapshot 和 JSON-safe 报告。
- `GFResourceRegistryAssetSourceProvider`：把现有 `GFResourceRegistry` 适配为资产目录来源。

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

## Source Provider

素材库不应该只扫描某个固定目录。更稳的做法是把不同来源都转换为 provider，再由 `GFAssetCatalogSourceRegistry` 汇聚：

- 项目目录扫描 provider。
- `GFResourceRegistry` provider。
- 内容包 manifest provider。
- 资产 metadata provider。
- 团队共享库或外部数据库 provider。

默认合并时，高优先级 provider 先写入，同 `asset_id` 的低优先级条目会被跳过。需要诊断重复 ID 时调用 `build_catalog_report()`，报告会返回 `sources`、`entry_count`、`catalog_data` 和 `issues`。

## 使用边界

- `GFAssetCatalog` 是索引，不是资源缓存；加载和生命周期仍交给 `GFAssetUtility`、`GFResourceResolverUtility` 或项目自己的加载流程。
- `asset_id` 应作为长期稳定 ID，不应直接等同资源路径。
- 标签、分类、备注和 metadata 只作为通用字段保存和索引；GF 不解释 `character`、`weapon`、`quest`、`license` 等项目语义。
- 引用审计、替换资源和未使用资源清理应先生成 dry-run 计划与报告，再由项目或编辑器工具决定是否执行。
- 预览图生成应通过编辑器侧 preview provider 或资源自身预览能力接入，不要让 catalog 直接解码大图或持有纹理缓存。
