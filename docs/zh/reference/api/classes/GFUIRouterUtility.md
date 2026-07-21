# GFUIRouterUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_router_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

基于路由 ID 的 UI 导航工具。 作为 GFUIUtility 之上的轻量路由层，负责把稳定 route_id 映射到面板场景、 打开参数、层级和历史记录，不接管具体页面业务或动画表现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`route_open_requested`](#member-gfuirouterutility-signals-route_open_requested) | `signal route_open_requested(route_id: StringName, operation: Operation, params: Dictionary)` |
| 信号 | [`route_opened`](#member-gfuirouterutility-signals-route_opened) | `signal route_opened(route_id: StringName, panel: Node, operation: Operation)` |
| 信号 | [`route_open_failed`](#member-gfuirouterutility-signals-route_open_failed) | `signal route_open_failed(route_id: StringName, reason: String)` |
| 信号 | [`route_operation_completed`](#member-gfuirouterutility-signals-route_operation_completed) | `signal route_operation_completed(result: GFUIRouteResult)` |
| 信号 | [`route_back_completed`](#member-gfuirouterutility-signals-route_back_completed) | `signal route_back_completed(route_id: StringName, layer: int)` |
| 枚举 | [`Operation`](#member-gfuirouterutility-enums-operation) | `enum Operation` |
| 常量 | [`PRELOAD_NONE`](#member-gfuirouterutility-constants-preload_none) | `const PRELOAD_NONE: StringName = &"none"` |
| 常量 | [`PRELOAD_BEST_EFFORT`](#member-gfuirouterutility-constants-preload_best_effort) | `const PRELOAD_BEST_EFFORT: StringName = &"best_effort"` |
| 常量 | [`PRELOAD_REQUIRED`](#member-gfuirouterutility-constants-preload_required) | `const PRELOAD_REQUIRED: StringName = &"required"` |
| 属性 | [`max_history`](#member-gfuirouterutility-properties-max_history) | `var max_history: int = 64` |
| 方法 | [`init`](#member-gfuirouterutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfuirouterutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfuirouterutility-methods-configure) | `func configure(routes: Array[GFUIRoute] = [], ui_utility: GFUIUtility = null) -> void:` |
| 方法 | [`set_ui_utility`](#member-gfuirouterutility-methods-set_ui_utility) | `func set_ui_utility(ui_utility: GFUIUtility) -> void:` |
| 方法 | [`register_route`](#member-gfuirouterutility-methods-register_route) | `func register_route(route: GFUIRoute) -> bool:` |
| 方法 | [`register_routes`](#member-gfuirouterutility-methods-register_routes) | `func register_routes(routes: Array[GFUIRoute]) -> void:` |
| 方法 | [`unregister_route`](#member-gfuirouterutility-methods-unregister_route) | `func unregister_route(route_id: StringName) -> void:` |
| 方法 | [`clear_routes`](#member-gfuirouterutility-methods-clear_routes) | `func clear_routes() -> void:` |
| 方法 | [`get_route`](#member-gfuirouterutility-methods-get_route) | `func get_route(route_id: StringName) -> GFUIRoute:` |
| 方法 | [`has_route`](#member-gfuirouterutility-methods-has_route) | `func has_route(route_id: StringName) -> bool:` |
| 方法 | [`get_route_ids`](#member-gfuirouterutility-methods-get_route_ids) | `func get_route_ids() -> PackedStringArray:` |
| 方法 | [`build_preload_plan`](#member-gfuirouterutility-methods-build_preload_plan) | `func build_preload_plan(source_route_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`push_route`](#member-gfuirouterutility-methods-push_route) | `func push_route( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:` |
| 方法 | [`replace_route`](#member-gfuirouterutility-methods-replace_route) | `func replace_route( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:` |
| 方法 | [`push_route_async`](#member-gfuirouterutility-methods-push_route_async) | `func push_route_async( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable(), async_options: Dictionary = {} ) -> GFUIRouteOperation:` |
| 方法 | [`replace_route_async`](#member-gfuirouterutility-methods-replace_route_async) | `func replace_route_async( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable(), async_options: Dictionary = {} ) -> GFUIRouteOperation:` |
| 方法 | [`back`](#member-gfuirouterutility-methods-back) | `func back(layer: int = -1, do_free: bool = true) -> bool:` |
| 方法 | [`get_current_route_id`](#member-gfuirouterutility-methods-get_current_route_id) | `func get_current_route_id(layer: int = -1) -> StringName:` |
| 方法 | [`get_route_history`](#member-gfuirouterutility-methods-get_route_history) | `func get_route_history() -> Array[Dictionary]:` |
| 方法 | [`clear_history`](#member-gfuirouterutility-methods-clear_history) | `func clear_history() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfuirouterutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfuirouterutility-signals-route_open_requested"></a>

### `route_open_requested`

- API：`public`

```gdscript
signal route_open_requested(route_id: StringName, operation: Operation, params: Dictionary)
```

路由打开请求发出时触发。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `operation` | 打开操作。 |
| `params` | 路由参数。 |

结构：

- `params`: Dictionary，本次打开路由携带的项目自定义参数。

<a id="member-gfuirouterutility-signals-route_opened"></a>

### `route_opened`

- API：`public`

```gdscript
signal route_opened(route_id: StringName, panel: Node, operation: Operation)
```

路由面板成功打开后触发。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `panel` | 面板实例。 |
| `operation` | 打开操作。 |

<a id="member-gfuirouterutility-signals-route_open_failed"></a>

### `route_open_failed`

- API：`public`

```gdscript
signal route_open_failed(route_id: StringName, reason: String)
```

路由打开失败时触发。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `reason` | 失败原因。 |

<a id="member-gfuirouterutility-signals-route_operation_completed"></a>

### `route_operation_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal route_operation_completed(result: GFUIRouteResult)
```

异步路由请求进入终态时触发。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 隔离的类型化终态结果。 |

<a id="member-gfuirouterutility-signals-route_back_completed"></a>

### `route_back_completed`

- API：`public`

```gdscript
signal route_back_completed(route_id: StringName, layer: int)
```

路由返回完成时触发。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 被弹出的路由标识。 |
| `layer` | 所在层级。 |

## 枚举

<a id="member-gfuirouterutility-enums-operation"></a>

### `Operation`

- API：`public`

```gdscript
enum Operation {
	## 压入当前层级栈顶。
	PUSH,
	## 替换当前层级栈。
	REPLACE,
}
```

路由打开操作。

## 常量

<a id="member-gfuirouterutility-constants-preload_none"></a>

### `PRELOAD_NONE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const PRELOAD_NONE: StringName = &"none"
```

不执行路由预加载，直接提交异步面板请求。

<a id="member-gfuirouterutility-constants-preload_best_effort"></a>

### `PRELOAD_BEST_EFFORT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const PRELOAD_BEST_EFFORT: StringName = &"best_effort"
```

尽力执行路由预加载；规划或加载失败时仍继续打开面板。

<a id="member-gfuirouterutility-constants-preload_required"></a>

### `PRELOAD_REQUIRED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const PRELOAD_REQUIRED: StringName = &"required"
```

要求路由预加载完整成功；否则不提交面板请求。

## 属性

<a id="member-gfuirouterutility-properties-max_history"></a>

### `max_history`

- API：`public`

```gdscript
var max_history: int = 64
```

路由历史最大保留数量。小于等于 0 表示不保留历史。

## 方法

<a id="member-gfuirouterutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化路由表、UI 工具引用和历史记录。

<a id="member-gfuirouterutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放路由表、UI 工具引用和历史记录。

<a id="member-gfuirouterutility-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(routes: Array[GFUIRoute] = [], ui_utility: GFUIUtility = null) -> void:
```

配置路由表和可选 UI 工具实例。

参数：

| 名称 | 说明 |
|---|---|
| `routes` | 路由资源列表。 |
| `ui_utility` | 可选 GFUIUtility；为空时从当前架构查找。 |

<a id="member-gfuirouterutility-methods-set_ui_utility"></a>

### `set_ui_utility`

- API：`public`

```gdscript
func set_ui_utility(ui_utility: GFUIUtility) -> void:
```

设置路由使用的 UI 栈工具。

参数：

| 名称 | 说明 |
|---|---|
| `ui_utility` | UI 栈工具实例。 |

<a id="member-gfuirouterutility-methods-register_route"></a>

### `register_route`

- API：`public`

```gdscript
func register_route(route: GFUIRoute) -> bool:
```

注册一个路由。

参数：

| 名称 | 说明 |
|---|---|
| `route` | 路由资源。 |

返回：注册成功返回 true。

<a id="member-gfuirouterutility-methods-register_routes"></a>

### `register_routes`

- API：`public`

```gdscript
func register_routes(routes: Array[GFUIRoute]) -> void:
```

批量注册路由。

参数：

| 名称 | 说明 |
|---|---|
| `routes` | 路由资源列表。 |

<a id="member-gfuirouterutility-methods-unregister_route"></a>

### `unregister_route`

- API：`public`

```gdscript
func unregister_route(route_id: StringName) -> void:
```

注销路由。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |

<a id="member-gfuirouterutility-methods-clear_routes"></a>

### `clear_routes`

- API：`public`

```gdscript
func clear_routes() -> void:
```

清空路由表。

<a id="member-gfuirouterutility-methods-get_route"></a>

### `get_route`

- API：`public`

```gdscript
func get_route(route_id: StringName) -> GFUIRoute:
```

获取路由资源。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |

返回：路由资源；不存在时返回 null。

<a id="member-gfuirouterutility-methods-has_route"></a>

### `has_route`

- API：`public`

```gdscript
func has_route(route_id: StringName) -> bool:
```

检查路由是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |

返回：已注册返回 true。

<a id="member-gfuirouterutility-methods-get_route_ids"></a>

### `get_route_ids`

- API：`public`

```gdscript
func get_route_ids() -> PackedStringArray:
```

获取所有路由标识。

返回：路由标识列表。

<a id="member-gfuirouterutility-methods-build_preload_plan"></a>

### `build_preload_plan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func build_preload_plan(source_route_id: StringName, options: Dictionary = {}) -> Dictionary:
```

从已注册路由构建有界的页面资源预加载计划。 结果中的 asset_plan 可直接交给 GFAssetUtility.preload_plan_async()。

参数：

| 名称 | 说明 |
|---|---|
| `source_route_id` | 起始路由标识。 |
| `options` | 传给 GFUIRoutePreloadUtility.build_plan() 的选项。 |

返回：路由预加载结果。

结构：

- `options`: Dictionary，可包含 max_depth、max_catalog_routes、max_routes、max_edges、include_source、fixed_route_ids、group_id、plan_id、pin_cache、lane_id、max_concurrent_loads、check_exists 和 metadata。
- `return`: Dictionary，结构同 GFUIRoutePreloadUtility.build_plan()，其中 asset_plan 为 GFAssetPreloadPlan。

<a id="member-gfuirouterutility-methods-push_route"></a>

### `push_route`

- API：`public`

```gdscript
func push_route( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:
```

压入一个路由面板。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `params` | 路由参数。 |
| `option_overrides` | 面板选项覆盖。 |
| `config_callback` | 面板实例化后、入栈前的额外配置回调。 |

返回：成功时返回面板实例。

结构：

- `params`: Dictionary，本次打开路由携带的项目自定义参数。
- `option_overrides`: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。

<a id="member-gfuirouterutility-methods-replace_route"></a>

### `replace_route`

- API：`public`

```gdscript
func replace_route( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:
```

替换路由所在层级。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `params` | 路由参数。 |
| `option_overrides` | 面板选项覆盖。 |
| `config_callback` | 面板实例化后、入栈前的额外配置回调。 |

返回：成功时返回面板实例。

结构：

- `params`: Dictionary，本次打开路由携带的项目自定义参数。
- `option_overrides`: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。

<a id="member-gfuirouterutility-methods-push_route_async"></a>

### `push_route_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func push_route_async( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable(), async_options: Dictionary = {} ) -> GFUIRouteOperation:
```

异步压入一个路由面板。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `params` | 路由参数。 |
| `option_overrides` | 面板选项覆盖。 |
| `config_callback` | 面板实例化后、入栈前的额外配置回调。 |
| `async_options` | 异步协调选项。 |

返回：可观察的异步路由句柄；相同 pending 请求返回同一句柄。

结构：

- `params`: Dictionary，本次打开路由携带的项目自定义参数。
- `option_overrides`: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。
- `async_options`: Dictionary，可包含 preload_policy、preload_plan_options 和 metadata；preload_policy 使用 PRELOAD_* 常量，自动预加载始终包含当前路由，未指定 max_depth 时只加载当前页面。

<a id="member-gfuirouterutility-methods-replace_route_async"></a>

### `replace_route_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func replace_route_async( route_id: StringName, params: Dictionary = {}, option_overrides: Dictionary = {}, config_callback: Callable = Callable(), async_options: Dictionary = {} ) -> GFUIRouteOperation:
```

异步替换路由所在层级。

参数：

| 名称 | 说明 |
|---|---|
| `route_id` | 路由标识。 |
| `params` | 路由参数。 |
| `option_overrides` | 面板选项覆盖。 |
| `config_callback` | 面板实例化后、入栈前的额外配置回调。 |
| `async_options` | 异步协调选项。 |

返回：可观察的异步路由句柄；相同 pending 请求返回同一句柄。

结构：

- `params`: Dictionary，本次打开路由携带的项目自定义参数。
- `option_overrides`: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。
- `async_options`: Dictionary，可包含 preload_policy、preload_plan_options 和 metadata；preload_policy 使用 PRELOAD_* 常量，自动预加载始终包含当前路由，未指定 max_depth 时只加载当前页面。

<a id="member-gfuirouterutility-methods-back"></a>

### `back`

- API：`public`

```gdscript
func back(layer: int = -1, do_free: bool = true) -> bool:
```

返回上一层路由。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时使用最近的历史记录。 |
| `do_free` | 是否释放被弹出的面板。 |

返回：成功返回 true。

<a id="member-gfuirouterutility-methods-get_current_route_id"></a>

### `get_current_route_id`

- API：`public`

```gdscript
func get_current_route_id(layer: int = -1) -> StringName:
```

获取当前路由标识。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时返回最近路由。 |

返回：当前路由标识；没有时返回空 StringName。

<a id="member-gfuirouterutility-methods-get_route_history"></a>

### `get_route_history`

- API：`public`

```gdscript
func get_route_history() -> Array[Dictionary]:
```

获取路由历史副本。

返回：从旧到新的历史条目。

结构：

- `return`: Array，元素为 Dictionary，包含 route_id、layer、panel、params 和 metadata。

<a id="member-gfuirouterutility-methods-clear_history"></a>

### `clear_history`

- API：`public`

```gdscript
func clear_history() -> void:
```

清空路由历史，不影响已打开面板。

<a id="member-gfuirouterutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取路由诊断快照。

返回：诊断快照。

结构：

- `return`: Dictionary，包含 route_count、history_count、pending_async_route_count、pending_async_routes、current_route_id、has_ui_utility 和 disposed。
