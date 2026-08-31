# GFAssetBrowserModel

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/asset_browser/gf_asset_browser_model.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`11.0.0`

资产浏览器的无界面状态模型。 持有隔离的 GFAssetCatalog 快照、查询代际和稳定 ID 选择，供项目编辑器 页面自行决定布局、来源注入和资源物化策略。本模型不扫描目录、不下载、 不导入资源，也不拥有 provider 或缓存。 catalog、query、selection 与 preview 通知共用非重入 FIFO 队列。同步 listener 触发的嵌套 mutation 只会排到队尾；当前 signal 的全部 listener 返回后才按提交顺序继续发布冻结参数。dispose() 会丢弃尚未派发的队尾通知。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`catalog_changed`](#member-gfassetbrowsermodel-signals-catalog_changed) | `signal catalog_changed(catalog_revision: int, query_generation: int)` |
| 信号 | [`query_changed`](#member-gfassetbrowsermodel-signals-query_changed) | `signal query_changed(query_generation: int)` |
| 信号 | [`selection_changed`](#member-gfassetbrowsermodel-signals-selection_changed) | `signal selection_changed(asset_id: StringName)` |
| 信号 | [`preview_resolved`](#member-gfassetbrowsermodel-signals-preview_resolved) | `signal preview_resolved(report: Dictionary)` |
| 常量 | [`MAX_CATALOG_ENTRIES`](#member-gfassetbrowsermodel-constants-max_catalog_entries) | `const MAX_CATALOG_ENTRIES: int = 10_000` |
| 常量 | [`MAX_QUERY_LENGTH`](#member-gfassetbrowsermodel-constants-max_query_length) | `const MAX_QUERY_LENGTH: int = 512` |
| 常量 | [`MAX_PAGE_SIZE`](#member-gfassetbrowsermodel-constants-max_page_size) | `const MAX_PAGE_SIZE: int = 100` |
| 常量 | [`MAX_RESULT_COUNT`](#member-gfassetbrowsermodel-constants-max_result_count) | `const MAX_RESULT_COUNT: int = 10_000` |
| 方法 | [`replace_catalog`](#member-gfassetbrowsermodel-methods-replace_catalog) | `func replace_catalog(catalog: GFAssetCatalog) -> Dictionary:` |
| 方法 | [`select_asset`](#member-gfassetbrowsermodel-methods-select_asset) | `func select_asset(asset_id: StringName) -> bool:` |
| 方法 | [`set_query`](#member-gfassetbrowsermodel-methods-set_query) | `func set_query( query_text: String, asset_ids: PackedStringArray = PackedStringArray() ) -> Dictionary:` |
| 方法 | [`get_selected_asset_id`](#member-gfassetbrowsermodel-methods-get_selected_asset_id) | `func get_selected_asset_id() -> StringName:` |
| 方法 | [`get_catalog_revision`](#member-gfassetbrowsermodel-methods-get_catalog_revision) | `func get_catalog_revision() -> int:` |
| 方法 | [`get_query_generation`](#member-gfassetbrowsermodel-methods-get_query_generation) | `func get_query_generation() -> int:` |
| 方法 | [`request_preview`](#member-gfassetbrowsermodel-methods-request_preview) | `func request_preview( asset_id: StringName, renderer: GFThumbnailRenderer, request: GFThumbnailRenderRequest ) -> GFThumbnailRenderTask:` |
| 方法 | [`cancel_preview`](#member-gfassetbrowsermodel-methods-cancel_preview) | `func cancel_preview(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`get_preview_generation`](#member-gfassetbrowsermodel-methods-get_preview_generation) | `func get_preview_generation() -> int:` |
| 方法 | [`get_active_preview_task`](#member-gfassetbrowsermodel-methods-get_active_preview_task) | `func get_active_preview_task() -> GFThumbnailRenderTask:` |
| 方法 | [`dispose`](#member-gfassetbrowsermodel-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_page`](#member-gfassetbrowsermodel-methods-get_page) | `func get_page(page: int = 1, page_size: int = 50) -> Dictionary:` |

## 信号

<a id="member-gfassetbrowsermodel-signals-catalog_changed"></a>

### `catalog_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal catalog_changed(catalog_revision: int, query_generation: int)
```

隔离目录成功替换后发出。

参数：

| 名称 | 说明 |
|---|---|
| `catalog_revision` | 新目录 revision。 |
| `query_generation` | 新查询 generation。 |

<a id="member-gfassetbrowsermodel-signals-query_changed"></a>

### `query_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal query_changed(query_generation: int)
```

查询条件实际变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `query_generation` | 新查询 generation。 |

<a id="member-gfassetbrowsermodel-signals-selection_changed"></a>

### `selection_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal selection_changed(asset_id: StringName)
```

稳定资产选择实际变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 新选择；空 ID 表示没有选择。 |

<a id="member-gfassetbrowsermodel-signals-preview_resolved"></a>

### `preview_resolved`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal preview_resolved(report: Dictionary)
```

当前代际的预览任务进入终态后发出。 被目录、查询或新预览代际淘汰的旧任务不会发布结果。报告与预览计划的 Dictionary / Array 容器只读；Image / ImageTexture 等引擎对象句柄仍由 listener 按只读引用使用。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 预览终态报告。 |

结构：

- `report`: 闭合 Dictionary，精确包含 asset_id: StringName、preview_generation: int、catalog_revision: int、query_generation: int、state: StringName、result、error: String 和 cancel_reason: StringName。result 只能是 null、Image、ImageTexture，或精确包含 ok: true、generated_count: 非负 int、cancelled: bool、changes: Array 的 MeshLibrary plan；generated_count 必须等于 changes 数量且最多为 MAX_RESULT_COUNT，每个 change 精确包含非负 item_id: int、可空 old_preview: Texture2D 和非空 new_preview: Texture2D。所有 Dictionary / Array 容器只读；Image / Texture2D 是无法冻结的 Engine Object 句柄，listener 必须按只读引用使用。

## 常量

<a id="member-gfassetbrowsermodel-constants-max_catalog_entries"></a>

### `MAX_CATALOG_ENTRIES`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_CATALOG_ENTRIES: int = 10_000
```

单个模型快照允许的最大资产数。

<a id="member-gfassetbrowsermodel-constants-max_query_length"></a>

### `MAX_QUERY_LENGTH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_QUERY_LENGTH: int = 512
```

查询文本允许的最大字符数。

<a id="member-gfassetbrowsermodel-constants-max_page_size"></a>

### `MAX_PAGE_SIZE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_PAGE_SIZE: int = 100
```

单页允许返回的最大资产数。

<a id="member-gfassetbrowsermodel-constants-max_result_count"></a>

### `MAX_RESULT_COUNT`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const MAX_RESULT_COUNT: int = 10_000
```

一次查询允许保留的最大匹配资产数。

## 方法

<a id="member-gfassetbrowsermodel-methods-replace_catalog"></a>

### `replace_catalog`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func replace_catalog(catalog: GFAssetCatalog) -> Dictionary:
```

用隔离副本替换当前目录。 超过 MAX_CATALOG_ENTRIES 的目录会整体拒绝，不会静默截断。成功替换会 推进目录 revision 和查询 generation；已经不存在的选择会被清除。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 要复制的资产目录。 |

返回：替换报告。

结构：

- `return`: Dictionary with ok, changed, error, asset_count, catalog_revision, and query_generation.

<a id="member-gfassetbrowsermodel-methods-select_asset"></a>

### `select_asset`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func select_asset(asset_id: StringName) -> bool:
```

选择当前目录中的稳定资产 ID。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 要选择的资产 ID；空 ID 用于清除选择。 |

返回：选择请求有效时返回 true。

<a id="member-gfassetbrowsermodel-methods-set_query"></a>

### `set_query`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_query( query_text: String, asset_ids: PackedStringArray = PackedStringArray() ) -> Dictionary:
```

设置浏览查询和可选资产 ID 闭集。 资产 ID 会去重并排序。超长查询、超量过滤 ID 或超长 ID 会整体拒绝， 被拒绝的输入不会推进 generation。

参数：

| 名称 | 说明 |
|---|---|
| `query_text` | 交给 GFAssetCatalog 的文本查询。 |
| `asset_ids` | 可选查询闭集；为空时查询整个目录。 |

返回：查询更新报告。

结构：

- `return`: Dictionary with ok, changed, error, query_generation, query, and filter_count.

<a id="member-gfassetbrowsermodel-methods-get_selected_asset_id"></a>

### `get_selected_asset_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_selected_asset_id() -> StringName:
```

获取当前选择的稳定资产 ID。

返回：当前选择；没有选择时返回空 StringName。

<a id="member-gfassetbrowsermodel-methods-get_catalog_revision"></a>

### `get_catalog_revision`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_catalog_revision() -> int:
```

获取当前目录 revision。

返回：从 0 开始、成功替换后递增的 revision。

<a id="member-gfassetbrowsermodel-methods-get_query_generation"></a>

### `get_query_generation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_query_generation() -> int:
```

获取当前查询 generation。

返回：从 0 开始、目录或查询变化后递增的 generation。

<a id="member-gfassetbrowsermodel-methods-request_preview"></a>

### `request_preview`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func request_preview( asset_id: StringName, renderer: GFThumbnailRenderer, request: GFThumbnailRenderRequest ) -> GFThumbnailRenderTask:
```

提交与目录资产关联的缩略图请求。 调用方负责把资产物化为 GFThumbnailRenderRequest；模型只校验稳定 ID， 并通过 GFThumbnailRenderer 管理一个当前代际任务。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 当前目录中的稳定资产 ID。 |
| `renderer` | 执行请求的缩略图渲染器。 |
| `request` | 已由调用方构建的渲染请求。 |

返回：当前代际任务；输入无效时返回 null。

<a id="member-gfassetbrowsermodel-methods-cancel_preview"></a>

### `cancel_preview`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func cancel_preview(reason: StringName = &"cancelled") -> bool:
```

取消当前预览任务。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：本次调用是否发出新的取消请求。

<a id="member-gfassetbrowsermodel-methods-get_preview_generation"></a>

### `get_preview_generation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_preview_generation() -> int:
```

获取预览请求的当前代际。

返回：从 0 开始、新预览或主动失效时递增的 generation。

<a id="member-gfassetbrowsermodel-methods-get_active_preview_task"></a>

### `get_active_preview_task`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_active_preview_task() -> GFThumbnailRenderTask:
```

获取当前仍未完成的预览任务。

返回：当前任务；没有任务时返回 null。

<a id="member-gfassetbrowsermodel-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func dispose() -> void:
```

释放模型持有的预览任务。 dispose() 是终态操作；调用后目录、查询、选择和预览写入口均会拒绝新请求。

<a id="member-gfassetbrowsermodel-methods-get_page"></a>

### `get_page`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_page(page: int = 1, page_size: int = 50) -> Dictionary:
```

获取当前目录的分页摘要。

参数：

| 名称 | 说明 |
|---|---|
| `page` | 从 1 开始的页码。 |
| `page_size` | 每页数量。 |

返回：分页浏览报告。

结构：

- `return`: Dictionary with catalog_revision, query_generation, query, page, page_size, page_count, total_count, has_previous, has_next, asset_ids, and items.
