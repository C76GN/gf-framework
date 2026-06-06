# Content Package 内容包

Content Package 扩展用于把项目或插件中的可选内容收束为稳定 manifest、依赖图和资源键映射。它适合 DLC、章节包、主题包、可选素材包、项目内测试内容集合，或任何需要“先声明内容，再由项目决定如何启用”的场景。

它只处理包 ID、版本、依赖、资源键、路径安全、诊断报告和资源解析器注册；不负责下载、工作坊、PCK 装载、启用策略、业务 schema、内容类型语义或玩法规则。

## 核心模型

- `GFContentPackageManifest` 描述一个内容包，读取 `gf_content_package.json`，并校验资源路径是否留在包根目录内。
- `GFContentPackageCatalog` 管理一组 manifest，报告重复包 ID、缺失依赖和循环依赖，并按依赖优先顺序注册资源键。
- `GFContentPackageUtility` 维护显式 source root，发现 root 或直接子目录中的 manifest，重建 catalog，并把资源映射同步到 `GFResourceResolverUtility`。

## Manifest 形态

```json
{
  "package_id": "author.chapter_one",
  "display_name": "Chapter One",
  "version": "1.0.0",
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

`path` 可以是包根目录内的相对路径或 `res://` 路径。相对路径会归一化到 manifest 所在目录；`res://` 路径必须留在内容包根目录内；`uid://`、`user://`、绝对路径和越界 `..` 路径会进入错误报告。Content Package 不接受 `uid://`，因为 manifest 校验必须能证明资源仍在包根目录内。

## 诊断报告

`GFContentPackageManifest.get_validation_report()`、`GFContentPackageCatalog.get_graph_report()`、`GFContentPackageCatalog.register_resources()` 和 `GFContentPackageUtility.rebuild_catalog()` 返回 `GFValidationReportDictionary` 形态的通用报告，包含 `ok`、`healthy`、`summary`、`issues`、`next_action`、计数字段和内容包上下文。

报告里的 `kind` 是稳定诊断键，例如 `invalid_resource_path`、`resource_path_outside_package`、`missing_dependency`、`dependency_cycle`、`invalid_manifest_file`。项目编辑器工具可以直接按这些键渲染问题列表，也可以追加自己的业务 schema 校验报告；GF 不把单个内容类型的字段解释写入 Content Package 扩展。

`GFContentPackageUtility.rebuild_catalog()` 发现坏 JSON 或无法读取的 manifest 文件时，会把该文件作为 `invalid_manifest_file` error 纳入同一份最终报告，并重新计算 `ok`、`error_count` 和 `issue_count`。调用方不需要单独扫描加载失败列表。

## 典型流程

```gdscript
var packages: GFContentPackageUtility = Gf.get_utility(GFContentPackageUtility)
packages.register_source_root("res://content_packages")

var report: Dictionary = packages.rebuild_catalog({ "check_resource_exists": true })
if GFVariantData.get_option_bool(report, "ok"):
	var resolver: GFResourceResolverUtility = Gf.get_utility(GFResourceResolverUtility)
	packages.register_resources(resolver)
```

项目之后可以用资源键加载内容：

```gdscript
var scene: Resource = resolver.load(&"chapter_one.main_scene", "PackedScene")
```

## 使用边界

- Content Package 不内置 `quest`、`item`、`biome`、`npc`、`skin` 等业务字段；这些字段应由项目 schema 或独立插件解释。
- 内容包之间只声明依赖顺序，不声明启用条件、版本约束求解、下载来源或平台服务账号。
- 资源键冲突时，依赖包先注册，依赖方后注册；项目可以用该顺序覆盖基础包资源。
- 需要多扩展组合时，在项目 Installer 或独立插件中组合 `GFContentPackageUtility`、`GFResourceResolverUtility` 和项目 schema，不把组合逻辑写回 GF 内置扩展。

## API Reference

完整类、方法和字段列表见 [Content Package API Reference](../../reference/api/extensions-content-package.md)。
