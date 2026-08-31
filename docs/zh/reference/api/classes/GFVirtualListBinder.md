# GFVirtualListBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_virtual_list_binder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

owner-bound 虚拟列表 Control 物化与回收协调器。 连接项目提供的 `ScrollContainer`、绝对布局 content root、`GFVirtualListModel` 与行回调，只物化真实视口及 overscan 范围。项目继续拥有条目数据、稳定 ID、 行视觉、选择、激活、输入和无障碍语义；Binder 拥有 factory 成功交付的 Control， 并在 unbind、任一绑定节点退出或 dispose 时确定性解除回调和节点引用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`sync_completed`](#member-gfvirtuallistbinder-signals-sync_completed) | `signal sync_completed(result: GFVirtualListSyncResult)` |
| 枚举 | [`LayoutAxis`](#member-gfvirtuallistbinder-enums-layoutaxis) | `enum LayoutAxis` |
| 枚举 | [`ScrollAlignment`](#member-gfvirtuallistbinder-enums-scrollalignment) | `enum ScrollAlignment` |
| 常量 | [`DEFAULT_MAX_MATERIALIZED_ITEMS`](#member-gfvirtuallistbinder-constants-default_max_materialized_items) | `const DEFAULT_MAX_MATERIALIZED_ITEMS: int = 512` |
| 常量 | [`DEFAULT_MAX_POOLED_ITEMS`](#member-gfvirtuallistbinder-constants-default_max_pooled_items) | `const DEFAULT_MAX_POOLED_ITEMS: int = 64` |
| 常量 | [`ABSOLUTE_MAX_MATERIALIZED_ITEMS`](#member-gfvirtuallistbinder-constants-absolute_max_materialized_items) | `const ABSOLUTE_MAX_MATERIALIZED_ITEMS: int = 4096` |
| 常量 | [`ABSOLUTE_MAX_POOLED_ITEMS`](#member-gfvirtuallistbinder-constants-absolute_max_pooled_items) | `const ABSOLUTE_MAX_POOLED_ITEMS: int = 1024` |
| 常量 | [`ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH`](#member-gfvirtuallistbinder-constants-absolute_max_identity_token_length) | `const ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH: int = 1024` |
| 属性 | [`layout_axis`](#member-gfvirtuallistbinder-properties-layout_axis) | `var layout_axis: LayoutAxis = LayoutAxis.VERTICAL:` |
| 属性 | [`max_materialized_items`](#member-gfvirtuallistbinder-properties-max_materialized_items) | `var max_materialized_items: int = DEFAULT_MAX_MATERIALIZED_ITEMS:` |
| 属性 | [`max_pooled_items`](#member-gfvirtuallistbinder-properties-max_pooled_items) | `var max_pooled_items: int = DEFAULT_MAX_POOLED_ITEMS:` |
| 属性 | [`auto_measure`](#member-gfvirtuallistbinder-properties-auto_measure) | `var auto_measure: bool = true` |
| 属性 | [`auto_reveal_focus`](#member-gfvirtuallistbinder-properties-auto_reveal_focus) | `var auto_reveal_focus: bool = true` |
| 属性 | [`fill_cross_axis`](#member-gfvirtuallistbinder-properties-fill_cross_axis) | `var fill_cross_axis: bool = true` |
| 方法 | [`bind`](#member-gfvirtuallistbinder-methods-bind) | `func bind( owner: Node, scroll_container: ScrollContainer, content_root: Control, layout_model: GFVirtualListModel, item_factory: Callable, bind_callback: Callable, unbind_callback: Callable, identity_callback: Callable, focus_model: GFVirtualListFocusModel = null, measure_callback: Callable = Callable(), focus_target_callback: Callable = Callable() ) -> bool:` |
| 方法 | [`request_sync`](#member-gfvirtuallistbinder-methods-request_sync) | `func request_sync() -> bool:` |
| 方法 | [`sync_now`](#member-gfvirtuallistbinder-methods-sync_now) | `func sync_now() -> GFVirtualListSyncResult:` |
| 方法 | [`invalidate_items`](#member-gfvirtuallistbinder-methods-invalidate_items) | `func invalidate_items() -> bool:` |
| 方法 | [`request_measurement`](#member-gfvirtuallistbinder-methods-request_measurement) | `func request_measurement() -> bool:` |
| 方法 | [`scroll_to_item`](#member-gfvirtuallistbinder-methods-scroll_to_item) | `func scroll_to_item( item_index: int, alignment: ScrollAlignment = ScrollAlignment.NEAREST ) -> bool:` |
| 方法 | [`get_materialized_control`](#member-gfvirtuallistbinder-methods-get_materialized_control) | `func get_materialized_control(item_index: int) -> Control:` |
| 方法 | [`get_materialized_control_by_id`](#member-gfvirtuallistbinder-methods-get_materialized_control_by_id) | `func get_materialized_control_by_id(item_id: Variant) -> Control:` |
| 方法 | [`get_last_sync_result`](#member-gfvirtuallistbinder-methods-get_last_sync_result) | `func get_last_sync_result() -> GFVirtualListSyncResult:` |
| 方法 | [`get_debug_snapshot`](#member-gfvirtuallistbinder-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`is_bound`](#member-gfvirtuallistbinder-methods-is_bound) | `func is_bound() -> bool:` |
| 方法 | [`is_disposed`](#member-gfvirtuallistbinder-methods-is_disposed) | `func is_disposed() -> bool:` |
| 方法 | [`unbind`](#member-gfvirtuallistbinder-methods-unbind) | `func unbind() -> void:` |
| 方法 | [`dispose`](#member-gfvirtuallistbinder-methods-dispose) | `func dispose() -> void:` |

## 信号

<a id="member-gfvirtuallistbinder-signals-sync_completed"></a>

### `sync_completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal sync_completed(result: GFVirtualListSyncResult)
```

一轮同步完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 不含项目条目载荷的 typed 同步结果。 |

## 枚举

<a id="member-gfvirtuallistbinder-enums-layoutaxis"></a>

### `LayoutAxis`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum LayoutAxis {
	## 以 Y 轴和垂直滚动条组织条目。
	VERTICAL,
	## 以 X 轴和水平滚动条组织条目。
	HORIZONTAL,
}
```

列表滚动和尺寸测量使用的主轴。

<a id="member-gfvirtuallistbinder-enums-scrollalignment"></a>

### `ScrollAlignment`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum ScrollAlignment {
	## 已可见时不滚动，否则移动到最近边界。
	NEAREST,
	## 条目起点对齐视口起点。
	START,
	## 条目中心对齐视口中心。
	CENTER,
	## 条目终点对齐视口终点。
	END,
}
```

把条目滚入视口时使用的对齐方式。

## 常量

<a id="member-gfvirtuallistbinder-constants-default_max_materialized_items"></a>

### `DEFAULT_MAX_MATERIALIZED_ITEMS`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const DEFAULT_MAX_MATERIALIZED_ITEMS: int = 512
```

默认活动 Control 硬上限。

<a id="member-gfvirtuallistbinder-constants-default_max_pooled_items"></a>

### `DEFAULT_MAX_POOLED_ITEMS`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const DEFAULT_MAX_POOLED_ITEMS: int = 64
```

默认 parentless pool Control 上限。

<a id="member-gfvirtuallistbinder-constants-absolute_max_materialized_items"></a>

### `ABSOLUTE_MAX_MATERIALIZED_ITEMS`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const ABSOLUTE_MAX_MATERIALIZED_ITEMS: int = 4096
```

活动物化 Control 的框架级绝对硬上限。

<a id="member-gfvirtuallistbinder-constants-absolute_max_pooled_items"></a>

### `ABSOLUTE_MAX_POOLED_ITEMS`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const ABSOLUTE_MAX_POOLED_ITEMS: int = 1024
```

parentless pool 的框架级绝对硬上限。

<a id="member-gfvirtuallistbinder-constants-absolute_max_identity_token_length"></a>

### `ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH: int = 1024
```

稳定 identity token 允许的最大 UTF-8 字节数。

## 属性

<a id="member-gfvirtuallistbinder-properties-layout_axis"></a>

### `layout_axis`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var layout_axis: LayoutAxis = LayoutAxis.VERTICAL:
```

布局主轴。只接受 VERTICAL/HORIZONTAL；绑定期间修改后调用 request_sync() 使其生效。 同步 callback 内修改时，当前轮继续使用入口快照，下一轮才采用新值。

<a id="member-gfvirtuallistbinder-properties-max_materialized_items"></a>

### `max_materialized_items`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var max_materialized_items: int = DEFAULT_MAX_MATERIALIZED_ITEMS:
```

活动物化 Control 硬上限；运行时按至少 1 处理。

<a id="member-gfvirtuallistbinder-properties-max_pooled_items"></a>

### `max_pooled_items`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var max_pooled_items: int = DEFAULT_MAX_POOLED_ITEMS:
```

parentless pool 最多保留的 Control 数量；小于 0 时按 0 处理。 同步事务内收紧预算时，会在候选提交或回滚完成后统一裁剪。

<a id="member-gfvirtuallistbinder-properties-auto_measure"></a>

### `auto_measure`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var auto_measure: bool = true
```

是否在新绑定或数据失效后自动测量活动行；不影响显式 request_measurement()。

<a id="member-gfvirtuallistbinder-properties-auto_reveal_focus"></a>

### `auto_reveal_focus`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var auto_reveal_focus: bool = true
```

虚拟焦点变化后是否按最近边界自动滚入视口。

<a id="member-gfvirtuallistbinder-properties-fill_cross_axis"></a>

### `fill_cross_axis`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var fill_cross_axis: bool = true
```

是否让行 Control 填满 content root 的交叉轴。 同步 callback 内修改时，当前轮继续使用入口快照，下一轮才采用新值。

## 方法

<a id="member-gfvirtuallistbinder-methods-bind"></a>

### `bind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func bind( owner: Node, scroll_container: ScrollContainer, content_root: Control, layout_model: GFVirtualListModel, item_factory: Callable, bind_callback: Callable, unbind_callback: Callable, identity_callback: Callable, focus_model: GFVirtualListFocusModel = null, measure_callback: Callable = Callable(), focus_target_callback: Callable = Callable() ) -> bool:
```

建立一个 owner-bound 虚拟列表绑定。 `content_root` 必须是 ScrollContainer 的直接子 Control，且不能是会接管子节点位置的 Container。factory 返回的 Control 必须 parentless；返回后其所有权转交 Binder。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 生命周期 owner；退出 SceneTree 后 Binder 自动 dispose。 |
| `scroll_container` | 项目持有的滚动容器；退出 SceneTree 后 Binder 自动 dispose。 |
| `content_root` | Binder 写入主轴最小尺寸并承载活动行；退出 SceneTree 后自动 dispose。 |
| `layout_model` | 条目 count、extent、offset 和范围模型。 |
| `item_factory` | Callable() -> Control。 |
| `bind_callback` | Callable(control: Control, item_index: int, item_id: Variant) -> bool。 |
| `unbind_callback` | Callable(control: Control, item_index: int, item_id: Variant) -> void。 |
| `identity_callback` | Callable(item_index: int) -> Variant；返回值必须是稳定 key。 |
| `focus_model` | 可选虚拟焦点模型。 |
| `measure_callback` | 可选 Callable(control, item_index, item_id) -> float。 |
| `focus_target_callback` | 可选 Callable(control, item_index, item_id) -> Control。 |

返回：全部边界合法并建立连接时返回 true。

结构：

- `item_factory`: Callable() -> Control.
- `bind_callback`: Callable(Control, int, Variant) -> bool.
- `unbind_callback`: Callable(Control, int, Variant) -> void.
- `identity_callback`: Callable(int) -> stable Variant key.
- `measure_callback`: Optional Callable(Control, int, Variant) -> finite positive float.
- `focus_target_callback`: Optional Callable(Control, int, Variant) -> Control descendant.

<a id="member-gfvirtuallistbinder-methods-request_sync"></a>

### `request_sync`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func request_sync() -> bool:
```

请求一次合并到 deferred 队列的同步。

返回：当前处于有效绑定生命周期时返回 true。

<a id="member-gfvirtuallistbinder-methods-sync_now"></a>

### `sync_now`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func sync_now() -> GFVirtualListSyncResult:
```

立即执行一轮同步；callback 内的再次请求会合并为下一轮。

返回：typed 同步结果。

<a id="member-gfvirtuallistbinder-methods-invalidate_items"></a>

### `invalidate_items`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func invalidate_items() -> bool:
```

标记项目条目内容或 identity 已变化，并请求重新绑定当前物化范围。

返回：当前已绑定时返回 true。

<a id="member-gfvirtuallistbinder-methods-request_measurement"></a>

### `request_measurement`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func request_measurement() -> bool:
```

请求下一轮重新测量当前活动行；即使 auto_measure 为 false 也会执行。

返回：当前已绑定时返回 true。

<a id="member-gfvirtuallistbinder-methods-scroll_to_item"></a>

### `scroll_to_item`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func scroll_to_item( item_index: int, alignment: ScrollAlignment = ScrollAlignment.NEAREST ) -> bool:
```

把指定条目滚入视口。 同步 callback 内不允许直接改变当前轮滚动；先保存项目意图并请求下一轮。 模型、视口、主轴与 Control 所有权快照保持有效并接受最终整数偏移时返回 true； 否则请求下一轮同步并返回 false。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |
| `alignment` | \`ScrollAlignment\` 值。 |

返回：索引和绑定有效、当前不在同步 callback 内，且滚动操作期间 data generation、

<a id="member-gfvirtuallistbinder-methods-get_materialized_control"></a>

### `get_materialized_control`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_materialized_control(item_index: int) -> Control:
```

获取指定索引当前物化的 Control。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |

返回：未物化时为 null。

<a id="member-gfvirtuallistbinder-methods-get_materialized_control_by_id"></a>

### `get_materialized_control_by_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_materialized_control_by_id(item_id: Variant) -> Control:
```

按稳定 identity 获取当前物化的 Control。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | identity callback 使用的稳定 ID。 |

返回：ID 无效或未物化时为 null。

结构：

- `item_id`: Stable Variant key accepted by GFVariantKeyCodec.

<a id="member-gfvirtuallistbinder-methods-get_last_sync_result"></a>

### `get_last_sync_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_last_sync_result() -> GFVirtualListSyncResult:
```

获取最近同步结果的隔离副本。

返回：尚未同步时返回当前生命周期终态结果。

<a id="member-gfvirtuallistbinder-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含项目条目载荷的调试快照。

返回：生命周期、范围和计数摘要。

结构：

- `return`: Dictionary with state, bound, disposed, lifecycle_generation, data_revision, pending_sync, active_count, pooled_count, and last_result.

<a id="member-gfvirtuallistbinder-methods-is_bound"></a>

### `is_bound`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_bound() -> bool:
```

检查是否处于有效绑定生命周期。

返回：已绑定且未进入 teardown 时返回 true。

<a id="member-gfvirtuallistbinder-methods-is_disposed"></a>

### `is_disposed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_disposed() -> bool:
```

检查是否进入不可复用终态。

返回：dispose 已完成时返回 true。

<a id="member-gfvirtuallistbinder-methods-unbind"></a>

### `unbind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func unbind() -> void:
```

解除当前绑定并释放全部 Binder-owned Control；实例仍可重新 bind。

<a id="member-gfvirtuallistbinder-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func dispose() -> void:
```

进入终态并释放行、pool、连接和 callback。
