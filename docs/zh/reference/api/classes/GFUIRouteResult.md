# GFUIRouteResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_route_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

UI 路由异步打开的不可变终态。 结果把路由校验、可选预加载、面板提交和生命周期中止统一为稳定状态， 并保留预加载事务结果，避免项目通过日志或时序猜测失败阶段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_OPENED`](#member-gfuirouteresult-constants-status_opened) | `const STATUS_OPENED: StringName = &"opened"` |
| 常量 | [`STATUS_MISSING_ROUTE`](#member-gfuirouteresult-constants-status_missing_route) | `const STATUS_MISSING_ROUTE: StringName = &"missing_route"` |
| 常量 | [`STATUS_INVALID_ROUTE`](#member-gfuirouteresult-constants-status_invalid_route) | `const STATUS_INVALID_ROUTE: StringName = &"invalid_route"` |
| 常量 | [`STATUS_MISSING_UI_UTILITY`](#member-gfuirouteresult-constants-status_missing_ui_utility) | `const STATUS_MISSING_UI_UTILITY: StringName = &"missing_ui_utility"` |
| 常量 | [`STATUS_MISSING_UI_LAYER`](#member-gfuirouteresult-constants-status_missing_ui_layer) | `const STATUS_MISSING_UI_LAYER: StringName = &"missing_ui_layer"` |
| 常量 | [`STATUS_ASYNC_CONFLICT`](#member-gfuirouteresult-constants-status_async_conflict) | `const STATUS_ASYNC_CONFLICT: StringName = &"async_conflict"` |
| 常量 | [`STATUS_INVALID_PRELOAD_POLICY`](#member-gfuirouteresult-constants-status_invalid_preload_policy) | `const STATUS_INVALID_PRELOAD_POLICY: StringName = &"invalid_preload_policy"` |
| 常量 | [`STATUS_MISSING_ASSET_UTILITY`](#member-gfuirouteresult-constants-status_missing_asset_utility) | `const STATUS_MISSING_ASSET_UTILITY: StringName = &"missing_asset_utility"` |
| 常量 | [`STATUS_PRELOAD_PLAN_FAILED`](#member-gfuirouteresult-constants-status_preload_plan_failed) | `const STATUS_PRELOAD_PLAN_FAILED: StringName = &"preload_plan_failed"` |
| 常量 | [`STATUS_PRELOAD_FAILED`](#member-gfuirouteresult-constants-status_preload_failed) | `const STATUS_PRELOAD_FAILED: StringName = &"preload_failed"` |
| 常量 | [`STATUS_PANEL_FAILED`](#member-gfuirouteresult-constants-status_panel_failed) | `const STATUS_PANEL_FAILED: StringName = &"panel_failed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfuirouteresult-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_DISPOSED`](#member-gfuirouteresult-constants-status_disposed) | `const STATUS_DISPOSED: StringName = &"disposed"` |
| 常量 | [`STATUS_OUTCOME_UNKNOWN`](#member-gfuirouteresult-constants-status_outcome_unknown) | `const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"` |
| 方法 | [`get_request_id`](#member-gfuirouteresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_route_id`](#member-gfuirouteresult-methods-get_route_id) | `func get_route_id() -> StringName:` |
| 方法 | [`get_operation`](#member-gfuirouteresult-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_status`](#member-gfuirouteresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`is_successful`](#member-gfuirouteresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_reason`](#member-gfuirouteresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_layer`](#member-gfuirouteresult-methods-get_layer) | `func get_layer() -> int:` |
| 方法 | [`get_panel`](#member-gfuirouteresult-methods-get_panel) | `func get_panel() -> Node:` |
| 方法 | [`get_preload_policy`](#member-gfuirouteresult-methods-get_preload_policy) | `func get_preload_policy() -> StringName:` |
| 方法 | [`was_preload_attempted`](#member-gfuirouteresult-methods-was_preload_attempted) | `func was_preload_attempted() -> bool:` |
| 方法 | [`was_preload_successful`](#member-gfuirouteresult-methods-was_preload_successful) | `func was_preload_successful() -> bool:` |
| 方法 | [`get_preload_plan_report`](#member-gfuirouteresult-methods-get_preload_plan_report) | `func get_preload_plan_report() -> Dictionary:` |
| 方法 | [`get_preload_result`](#member-gfuirouteresult-methods-get_preload_result) | `func get_preload_result() -> GFAssetLoadSessionResult:` |
| 方法 | [`get_started_at_msec`](#member-gfuirouteresult-methods-get_started_at_msec) | `func get_started_at_msec() -> int:` |
| 方法 | [`get_completed_at_msec`](#member-gfuirouteresult-methods-get_completed_at_msec) | `func get_completed_at_msec() -> int:` |
| 方法 | [`get_duration_msec`](#member-gfuirouteresult-methods-get_duration_msec) | `func get_duration_msec() -> int:` |
| 方法 | [`get_metadata`](#member-gfuirouteresult-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`duplicate_result`](#member-gfuirouteresult-methods-duplicate_result) | `func duplicate_result() -> GFUIRouteResult:` |
| 方法 | [`to_dict`](#member-gfuirouteresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfuirouteresult-constants-status_opened"></a>

### `STATUS_OPENED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_OPENED: StringName = &"opened"
```

面板已进入目标 UI 栈。

<a id="member-gfuirouteresult-constants-status_missing_route"></a>

### `STATUS_MISSING_ROUTE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_MISSING_ROUTE: StringName = &"missing_route"
```

路由不存在。

<a id="member-gfuirouteresult-constants-status_invalid_route"></a>

### `STATUS_INVALID_ROUTE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_INVALID_ROUTE: StringName = &"invalid_route"
```

路由资源无效。

<a id="member-gfuirouteresult-constants-status_missing_ui_utility"></a>

### `STATUS_MISSING_UI_UTILITY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_MISSING_UI_UTILITY: StringName = &"missing_ui_utility"
```

Router 无法获取 UI Utility。

<a id="member-gfuirouteresult-constants-status_missing_ui_layer"></a>

### `STATUS_MISSING_UI_LAYER`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_MISSING_UI_LAYER: StringName = &"missing_ui_layer"
```

路由目标逻辑层未注册。

<a id="member-gfuirouteresult-constants-status_async_conflict"></a>

### `STATUS_ASYNC_CONFLICT`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_ASYNC_CONFLICT: StringName = &"async_conflict"
```

同一路径、层级和操作已有不同路由请求。

<a id="member-gfuirouteresult-constants-status_invalid_preload_policy"></a>

### `STATUS_INVALID_PRELOAD_POLICY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_INVALID_PRELOAD_POLICY: StringName = &"invalid_preload_policy"
```

预加载策略不受支持。

<a id="member-gfuirouteresult-constants-status_missing_asset_utility"></a>

### `STATUS_MISSING_ASSET_UTILITY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_MISSING_ASSET_UTILITY: StringName = &"missing_asset_utility"
```

预加载策略需要 Asset Utility，但当前架构未提供。

<a id="member-gfuirouteresult-constants-status_preload_plan_failed"></a>

### `STATUS_PRELOAD_PLAN_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_PRELOAD_PLAN_FAILED: StringName = &"preload_plan_failed"
```

无法构建满足策略要求的预加载计划。

<a id="member-gfuirouteresult-constants-status_preload_failed"></a>

### `STATUS_PRELOAD_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_PRELOAD_FAILED: StringName = &"preload_failed"
```

资产预加载事务失败或回滚。

<a id="member-gfuirouteresult-constants-status_panel_failed"></a>

### `STATUS_PANEL_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_PANEL_FAILED: StringName = &"panel_failed"
```

面板资源加载、实例化或入栈失败。

<a id="member-gfuirouteresult-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

底层 UI 请求在完成前被取消。

<a id="member-gfuirouteresult-constants-status_disposed"></a>

### `STATUS_DISPOSED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_DISPOSED: StringName = &"disposed"
```

Router 在面板提交前释放，结果确定为未打开。

<a id="member-gfuirouteresult-constants-status_outcome_unknown"></a>

### `STATUS_OUTCOME_UNKNOWN`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"
```

Router 在面板提交后释放，无法再可靠观察底层终态。

## 方法

<a id="member-gfuirouteresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_request_id() -> int:
```

获取 Router 内唯一请求 ID。

返回：大于零的请求 ID。

<a id="member-gfuirouteresult-methods-get_route_id"></a>

### `get_route_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_route_id() -> StringName:
```

获取规范化路由 ID。

返回：本次请求的路由 ID。

<a id="member-gfuirouteresult-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_operation() -> StringName:
```

获取路由操作。

返回：`GFUIRouteOperation.OPERATION_*` 常量之一。

<a id="member-gfuirouteresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_status() -> StringName:
```

获取终态状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfuirouteresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_successful() -> bool:
```

检查路由是否成功打开。

返回：面板已进入目标 UI 栈时返回 true。

<a id="member-gfuirouteresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_reason() -> StringName:
```

获取稳定原因码。

返回：失败或尽力预加载降级原因；无原因时为空。

<a id="member-gfuirouteresult-methods-get_layer"></a>

### `get_layer`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_layer() -> int:
```

获取目标逻辑层。

返回：有效路由的目标层；路由解析前失败时为 -1。

<a id="member-gfuirouteresult-methods-get_panel"></a>

### `get_panel`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_panel() -> Node:
```

获取仍存活的面板实例。

返回：成功面板；失败或面板已释放时返回 null。

<a id="member-gfuirouteresult-methods-get_preload_policy"></a>

### `get_preload_policy`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_preload_policy() -> StringName:
```

获取本次请求的预加载策略。

返回：Router 接受或拒绝的策略标识。

<a id="member-gfuirouteresult-methods-was_preload_attempted"></a>

### `was_preload_attempted`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func was_preload_attempted() -> bool:
```

检查是否实际启动过资产预加载事务。

返回：已创建并启动预加载会话时返回 true。

<a id="member-gfuirouteresult-methods-was_preload_successful"></a>

### `was_preload_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func was_preload_successful() -> bool:
```

检查预加载事务是否成功提交。

返回：会话进入 committed 终态时返回 true。

<a id="member-gfuirouteresult-methods-get_preload_plan_report"></a>

### `get_preload_plan_report`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_preload_plan_report() -> Dictionary:
```

获取 JSON 安全的预加载规划报告副本。

返回：不包含 Resource 实例的规划摘要。

结构：

- `return`: Dictionary with bounded route preload diagnostics and optional asset_plan_description.

<a id="member-gfuirouteresult-methods-get_preload_result"></a>

### `get_preload_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_preload_result() -> GFAssetLoadSessionResult:
```

获取资产预加载事务结果副本。

返回：已完成会话的结果；未启动或尚未完成时返回 null。

<a id="member-gfuirouteresult-methods-get_started_at_msec"></a>

### `get_started_at_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_started_at_msec() -> int:
```

获取请求开始时间。

返回：单调时钟毫秒值。

<a id="member-gfuirouteresult-methods-get_completed_at_msec"></a>

### `get_completed_at_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_completed_at_msec() -> int:
```

获取请求完成时间。

返回：单调时钟毫秒值。

<a id="member-gfuirouteresult-methods-get_duration_msec"></a>

### `get_duration_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_duration_msec() -> int:
```

获取请求持续时间。

返回：非负毫秒数。

<a id="member-gfuirouteresult-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取调用方元数据副本。

返回：`async_options.metadata` 的隔离副本。

结构：

- `return`: Dictionary caller-defined route operation metadata.

<a id="member-gfuirouteresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_result() -> GFUIRouteResult:
```

创建隔离结果副本。

返回：新结果对象。

<a id="member-gfuirouteresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化诊断字典。

返回：请求身份、终态、预加载摘要和持续时间。

结构：

- `return`: Dictionary with request_id, route_id, operation, status, ok, reason, layer, panel_instance_id, preload_policy, preload_attempted, preload_successful, preload_plan_report, preload_result, started_at_msec, completed_at_msec, duration_msec, and metadata.
