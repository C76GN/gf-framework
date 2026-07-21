# GFUIRoutePreloadUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_route_preload_utility.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

从显式 UI 路由关系构建资源预加载计划。 该工具只做有界、确定性的可达性遍历，并把页面场景转换为 GFAssetPreloadPlan。 权限、导航守卫、动态业务分支和实际预加载时机仍由项目负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_DEPTH`](#member-gfuiroutepreloadutility-constants-default_max_depth) | `const DEFAULT_MAX_DEPTH: int = 1` |
| 常量 | [`DEFAULT_MAX_ROUTES`](#member-gfuiroutepreloadutility-constants-default_max_routes) | `const DEFAULT_MAX_ROUTES: int = 64` |
| 常量 | [`DEFAULT_MAX_EDGES`](#member-gfuiroutepreloadutility-constants-default_max_edges) | `const DEFAULT_MAX_EDGES: int = 512` |
| 常量 | [`DEFAULT_MAX_CATALOG_ROUTES`](#member-gfuiroutepreloadutility-constants-default_max_catalog_routes) | `const DEFAULT_MAX_CATALOG_ROUTES: int = 1024` |
| 常量 | [`DEFAULT_GROUP_ID`](#member-gfuiroutepreloadutility-constants-default_group_id) | `const DEFAULT_GROUP_ID: StringName = &"ui_route_preload"` |
| 方法 | [`build_plan`](#member-gfuiroutepreloadutility-methods-build_plan) | `static func build_plan( routes: Array[GFUIRoute], source_route_id: StringName, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfuiroutepreloadutility-constants-default_max_depth"></a>

### `DEFAULT_MAX_DEPTH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_DEPTH: int = 1
```

默认搜索深度，只包含直接相邻路由。

<a id="member-gfuiroutepreloadutility-constants-default_max_routes"></a>

### `DEFAULT_MAX_ROUTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_ROUTES: int = 64
```

默认单次计划最多包含的路由数量。

<a id="member-gfuiroutepreloadutility-constants-default_max_edges"></a>

### `DEFAULT_MAX_EDGES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_EDGES: int = 512
```

默认单次遍历最多检查的原始相邻关系数量。

<a id="member-gfuiroutepreloadutility-constants-default_max_catalog_routes"></a>

### `DEFAULT_MAX_CATALOG_ROUTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_CATALOG_ROUTES: int = 1024
```

默认单次规划最多检查的输入路由资源数量。

<a id="member-gfuiroutepreloadutility-constants-default_group_id"></a>

### `DEFAULT_GROUP_ID`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_GROUP_ID: StringName = &"ui_route_preload"
```

默认资产预加载分组标识。

## 方法

<a id="member-gfuiroutepreloadutility-methods-build_plan"></a>

### `build_plan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func build_plan( routes: Array[GFUIRoute], source_route_id: StringName, options: Dictionary = {} ) -> Dictionary:
```

从路由资源构建有界可达性报告和 GFAssetPreloadPlan。

参数：

| 名称 | 说明 |
|---|---|
| `routes` | 可参与分析的路由资源。 |
| `source_route_id` | 起始路由标识。 |
| `options` | 计划选项。 |

返回：路由预加载结果。

结构：

- `options`: Dictionary，可包含 max_depth、max_routes、max_edges、max_catalog_routes、include_source、fixed_route_ids、group_id、plan_id、pin_cache、lane_id、max_concurrent_loads、check_exists 和 metadata；fixed_route_ids 优先占用 max_routes 预算，max_catalog_routes 限制输入目录检查数量。
- `return`: Dictionary，包含 ok、healthy、reason、source_route_id、max_depth、max_routes、max_edges、max_catalog_routes、catalog_route_count、edge_count、truncated、catalog_budget_exhausted、route_budget_exhausted、edge_budget_exhausted、route_ids、fixed_route_ids、temporary_route_ids、scene_paths、missing_route_ids、routes_without_scene、missing_scene_paths、invalid_scene_type_paths、duplicate_route_ids、asset_plan 和 metadata；asset_plan 为 GFAssetPreloadPlan。
