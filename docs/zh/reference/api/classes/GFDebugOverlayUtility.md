# GFDebugOverlayUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_debug_overlay_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

开发期运行时观察覆盖层。 提供 watch / panel 注册、轻量运行时快照和可选调试 GUI。默认只在 debug 构建中创建 GUI。 发布构建如确实需要显示，必须显式关闭 debug_only 并自行确认可见性与数据脱敏策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`toggle_key`](#member-gfdebugoverlayutility-properties-toggle_key) | `var toggle_key: Key = KEY_QUOTELEFT` |
| 属性 | [`refresh_interval_seconds`](#member-gfdebugoverlayutility-properties-refresh_interval_seconds) | `var refresh_interval_seconds: float = 0.25` |
| 属性 | [`include_diagnostics_monitors`](#member-gfdebugoverlayutility-properties-include_diagnostics_monitors) | `var include_diagnostics_monitors: bool = true` |
| 属性 | [`diagnostics_monitor_preset`](#member-gfdebugoverlayutility-properties-diagnostics_monitor_preset) | `var diagnostics_monitor_preset: StringName = &"overlay"` |
| 属性 | [`include_recent_logs`](#member-gfdebugoverlayutility-properties-include_recent_logs) | `var include_recent_logs: bool = true` |
| 属性 | [`recent_log_count`](#member-gfdebugoverlayutility-properties-recent_log_count) | `var recent_log_count: int = 12` |
| 属性 | [`include_metric_series_panel`](#member-gfdebugoverlayutility-properties-include_metric_series_panel) | `var include_metric_series_panel: bool = true` |
| 属性 | [`metric_series_width`](#member-gfdebugoverlayutility-properties-metric_series_width) | `var metric_series_width: int = 32` |
| 属性 | [`max_metric_series`](#member-gfdebugoverlayutility-properties-max_metric_series) | `var max_metric_series: int = 256:` |
| 属性 | [`max_value_collection_items`](#member-gfdebugoverlayutility-properties-max_value_collection_items) | `var max_value_collection_items: int = 32:` |
| 属性 | [`max_value_snapshot_nodes`](#member-gfdebugoverlayutility-properties-max_value_snapshot_nodes) | `var max_value_snapshot_nodes: int = 256:` |
| 属性 | [`max_panel_content_chars`](#member-gfdebugoverlayutility-properties-max_panel_content_chars) | `var max_panel_content_chars: int = 8192:` |
| 属性 | [`debug_only`](#member-gfdebugoverlayutility-properties-debug_only) | `var debug_only: bool = true` |
| 方法 | [`init`](#member-gfdebugoverlayutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfdebugoverlayutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`set_toggle_key`](#member-gfdebugoverlayutility-methods-set_toggle_key) | `func set_toggle_key(key: Key) -> void:` |
| 方法 | [`set_refresh_interval`](#member-gfdebugoverlayutility-methods-set_refresh_interval) | `func set_refresh_interval(seconds: float) -> void:` |
| 方法 | [`set_diagnostics_monitor_preset`](#member-gfdebugoverlayutility-methods-set_diagnostics_monitor_preset) | `func set_diagnostics_monitor_preset(preset_id: StringName) -> void:` |
| 方法 | [`set_overlay_visible`](#member-gfdebugoverlayutility-methods-set_overlay_visible) | `func set_overlay_visible(visible: bool) -> void:` |
| 方法 | [`is_overlay_visible`](#member-gfdebugoverlayutility-methods-is_overlay_visible) | `func is_overlay_visible() -> bool:` |
| 方法 | [`refresh_overlay`](#member-gfdebugoverlayutility-methods-refresh_overlay) | `func refresh_overlay() -> void:` |
| 方法 | [`push_watch_value`](#member-gfdebugoverlayutility-methods-push_watch_value) | `func push_watch_value(id: StringName, value: Variant, options: Dictionary = {}) -> bool:` |
| 方法 | [`remove_watch`](#member-gfdebugoverlayutility-methods-remove_watch) | `func remove_watch(id: StringName) -> void:` |
| 方法 | [`clear_watches`](#member-gfdebugoverlayutility-methods-clear_watches) | `func clear_watches() -> void:` |
| 方法 | [`has_watch`](#member-gfdebugoverlayutility-methods-has_watch) | `func has_watch(id: StringName) -> bool:` |
| 方法 | [`get_watch_snapshot`](#member-gfdebugoverlayutility-methods-get_watch_snapshot) | `func get_watch_snapshot(include_hidden: bool = false) -> Array[Dictionary]:` |
| 方法 | [`push_panel_content`](#member-gfdebugoverlayutility-methods-push_panel_content) | `func push_panel_content(panel_id: StringName, content: Variant, options: Dictionary = {}) -> bool:` |
| 方法 | [`push_panel_text`](#member-gfdebugoverlayutility-methods-push_panel_text) | `func push_panel_text(panel_id: StringName, content: String, options: Dictionary = {}) -> bool:` |
| 方法 | [`remove_panel`](#member-gfdebugoverlayutility-methods-remove_panel) | `func remove_panel(panel_id: StringName) -> void:` |
| 方法 | [`clear_panels`](#member-gfdebugoverlayutility-methods-clear_panels) | `func clear_panels() -> void:` |
| 方法 | [`has_panel`](#member-gfdebugoverlayutility-methods-has_panel) | `func has_panel(panel_id: StringName) -> bool:` |
| 方法 | [`get_panel_snapshot`](#member-gfdebugoverlayutility-methods-get_panel_snapshot) | `func get_panel_snapshot(include_hidden: bool = false) -> Array[Dictionary]:` |
| 方法 | [`record_metric_sample`](#member-gfdebugoverlayutility-methods-record_metric_sample) | `func record_metric_sample(metric_id: StringName, value: float, options: Dictionary = {}) -> bool:` |
| 方法 | [`get_or_create_metric_series`](#member-gfdebugoverlayutility-methods-get_or_create_metric_series) | `func get_or_create_metric_series(metric_id: StringName, options: Dictionary = {}) -> GFMetricSeries:` |
| 方法 | [`register_metric_series`](#member-gfdebugoverlayutility-methods-register_metric_series) | `func register_metric_series(series: GFMetricSeries) -> bool:` |
| 方法 | [`remove_metric_series`](#member-gfdebugoverlayutility-methods-remove_metric_series) | `func remove_metric_series(metric_id: StringName) -> void:` |
| 方法 | [`clear_metric_series`](#member-gfdebugoverlayutility-methods-clear_metric_series) | `func clear_metric_series() -> void:` |
| 方法 | [`has_metric_series`](#member-gfdebugoverlayutility-methods-has_metric_series) | `func has_metric_series(metric_id: StringName) -> bool:` |
| 方法 | [`get_metric_series_snapshot`](#member-gfdebugoverlayutility-methods-get_metric_series_snapshot) | `func get_metric_series_snapshot(include_hidden: bool = false) -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfdebugoverlayutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfdebugoverlayutility-properties-toggle_key"></a>

### `toggle_key`

- API：`public`

```gdscript
var toggle_key: Key = KEY_QUOTELEFT
```

呼出/隐藏面板的快捷键。默认为 KEY_QUOTELEFT (`~` 键)。

<a id="member-gfdebugoverlayutility-properties-refresh_interval_seconds"></a>

### `refresh_interval_seconds`

- API：`public`

```gdscript
var refresh_interval_seconds: float = 0.25
```

可见时刷新模型反射数据的间隔（秒）。设为 0 时每帧刷新。

<a id="member-gfdebugoverlayutility-properties-include_diagnostics_monitors"></a>

### `include_diagnostics_monitors`

- API：`public`

```gdscript
var include_diagnostics_monitors: bool = true
```

是否把 GFDiagnosticsUtility 的监控预设合并显示到 Watch 区。

<a id="member-gfdebugoverlayutility-properties-diagnostics_monitor_preset"></a>

### `diagnostics_monitor_preset`

- API：`public`

```gdscript
var diagnostics_monitor_preset: StringName = &"overlay"
```

Overlay 默认读取的诊断监控预设。

<a id="member-gfdebugoverlayutility-properties-include_recent_logs"></a>

### `include_recent_logs`

- API：`public`

```gdscript
var include_recent_logs: bool = true
```

是否在 Overlay 中附加最近日志面板。

<a id="member-gfdebugoverlayutility-properties-recent_log_count"></a>

### `recent_log_count`

- API：`public`

```gdscript
var recent_log_count: int = 12
```

最近日志面板读取的日志数量。

<a id="member-gfdebugoverlayutility-properties-include_metric_series_panel"></a>

### `include_metric_series_panel`

- API：`public`

```gdscript
var include_metric_series_panel: bool = true
```

是否在 Overlay 中附加短期指标趋势面板。

<a id="member-gfdebugoverlayutility-properties-metric_series_width"></a>

### `metric_series_width`

- API：`public`

```gdscript
var metric_series_width: int = 32
```

指标趋势 sparkline 输出宽度。

<a id="member-gfdebugoverlayutility-properties-max_metric_series"></a>

### `max_metric_series`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var max_metric_series: int = 256:
```

Overlay 最多维护的指标序列数量。设为 0 表示不限制。

<a id="member-gfdebugoverlayutility-properties-max_value_collection_items"></a>

### `max_value_collection_items`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_value_collection_items: int = 32:
```

单个推送值输出容器最多保留的元素数量。

<a id="member-gfdebugoverlayutility-properties-max_value_snapshot_nodes"></a>

### `max_value_snapshot_nodes`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_value_snapshot_nodes: int = 256:
```

单个推送值最多编码的值节点数量。

<a id="member-gfdebugoverlayutility-properties-max_panel_content_chars"></a>

### `max_panel_content_chars`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_panel_content_chars: int = 8192:
```

单个面板最终文本的最大字符数量。

<a id="member-gfdebugoverlayutility-properties-debug_only"></a>

### `debug_only`

- API：`public`

```gdscript
var debug_only: bool = true
```

是否只在 debug 构建中创建 Overlay GUI。发布构建需要显式关闭此项才会创建 GUI。

## 方法

<a id="member-gfdebugoverlayutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化调试覆盖层 GUI。

<a id="member-gfdebugoverlayutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放调试覆盖层 GUI 和所有 watch / panel 注册。

<a id="member-gfdebugoverlayutility-methods-set_toggle_key"></a>

### `set_toggle_key`

- API：`public`

```gdscript
func set_toggle_key(key: Key) -> void:
```

更新快捷键绑定

参数：

| 名称 | 说明 |
|---|---|
| `key` | 新的触发按键 |

<a id="member-gfdebugoverlayutility-methods-set_refresh_interval"></a>

### `set_refresh_interval`

- API：`public`

```gdscript
func set_refresh_interval(seconds: float) -> void:
```

设置可见时的刷新间隔。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 刷新间隔；小于等于 0 时每帧刷新。 |

<a id="member-gfdebugoverlayutility-methods-set_diagnostics_monitor_preset"></a>

### `set_diagnostics_monitor_preset`

- API：`public`

```gdscript
func set_diagnostics_monitor_preset(preset_id: StringName) -> void:
```

设置 Overlay 使用的诊断监控预设。

参数：

| 名称 | 说明 |
|---|---|
| `preset_id` | 诊断监控预设标识；为空时采集全部可见监控项。 |

<a id="member-gfdebugoverlayutility-methods-set_overlay_visible"></a>

### `set_overlay_visible`

- API：`public`

```gdscript
func set_overlay_visible(visible: bool) -> void:
```

设置 Overlay GUI 可见性。

参数：

| 名称 | 说明 |
|---|---|
| `visible` | 为 true 时显示 Overlay GUI。 |

<a id="member-gfdebugoverlayutility-methods-is_overlay_visible"></a>

### `is_overlay_visible`

- API：`public`

```gdscript
func is_overlay_visible() -> bool:
```

检查 Overlay GUI 是否可见。

返回：可见时返回 true。

<a id="member-gfdebugoverlayutility-methods-refresh_overlay"></a>

### `refresh_overlay`

- API：`public`

```gdscript
func refresh_overlay() -> void:
```

立即刷新 Overlay GUI 文本。

<a id="member-gfdebugoverlayutility-methods-push_watch_value"></a>

### `push_watch_value`

- API：`public`

```gdscript
func push_watch_value(id: StringName, value: Variant, options: Dictionary = {}) -> bool:
```

推送一个由调用方主动更新的运行时观察值。

参数：

| 名称 | 说明 |
|---|---|
| `id` | 观察值唯一标识。 |
| `value` | 要显示的当前值。 |
| `options` | 可选显示参数，支持 label、group、visible。 |

返回：注册成功返回 true；id 为空时返回 false。

结构：

- `value`: Variant，可为任意可显示值。
- `options`: Dictionary，支持 label、group 和 visible。

<a id="member-gfdebugoverlayutility-methods-remove_watch"></a>

### `remove_watch`

- API：`public`

```gdscript
func remove_watch(id: StringName) -> void:
```

移除一个运行时观察值。

参数：

| 名称 | 说明 |
|---|---|
| `id` | 要移除的观察值标识。 |

<a id="member-gfdebugoverlayutility-methods-clear_watches"></a>

### `clear_watches`

- API：`public`

```gdscript
func clear_watches() -> void:
```

清空所有运行时观察值。

<a id="member-gfdebugoverlayutility-methods-has_watch"></a>

### `has_watch`

- API：`public`

```gdscript
func has_watch(id: StringName) -> bool:
```

检查运行时观察值是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `id` | 要检查的观察值标识。 |

返回：已注册时返回 true。

<a id="member-gfdebugoverlayutility-methods-get_watch_snapshot"></a>

### `get_watch_snapshot`

- API：`public`

```gdscript
func get_watch_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
```

读取当前运行时观察值快照。

参数：

| 名称 | 说明 |
|---|---|
| `include_hidden` | 为 true 时同时返回 visible=false 的观察值。 |

返回：按注册顺序排列的观察值字典数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 id、label、group、value 和 valid。

<a id="member-gfdebugoverlayutility-methods-push_panel_content"></a>

### `push_panel_content`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func push_panel_content(panel_id: StringName, content: Variant, options: Dictionary = {}) -> bool:
```

推送一个由调用方主动更新的 Overlay 面板值。

参数：

| 名称 | 说明 |
|---|---|
| `panel_id` | 面板唯一标识。 |
| `content` | 面板内容；Dictionary 和 Array 会按报告边界编码后格式化。 |
| `options` | 可选显示参数，支持 label、group、visible。 |

返回：注册成功返回 true。

结构：

- `content`: 任意 Variant 报告值；写入前由 GFReportValueCodec 编码并受 Overlay 集合、节点、深度和文本长度预算约束。
- `options`: Dictionary，支持 label、group 和 visible。

<a id="member-gfdebugoverlayutility-methods-push_panel_text"></a>

### `push_panel_text`

- API：`public`

```gdscript
func push_panel_text(panel_id: StringName, content: String, options: Dictionary = {}) -> bool:
```

推送一个静态 Overlay 面板文本。

参数：

| 名称 | 说明 |
|---|---|
| `panel_id` | 面板唯一标识。 |
| `content` | 面板内容。 |
| `options` | 可选显示参数，支持 label、group、visible。 |

返回：注册成功返回 true。

结构：

- `options`: Dictionary，支持 label、group 和 visible。

<a id="member-gfdebugoverlayutility-methods-remove_panel"></a>

### `remove_panel`

- API：`public`

```gdscript
func remove_panel(panel_id: StringName) -> void:
```

移除一个 Overlay 面板。

参数：

| 名称 | 说明 |
|---|---|
| `panel_id` | 面板唯一标识。 |

<a id="member-gfdebugoverlayutility-methods-clear_panels"></a>

### `clear_panels`

- API：`public`

```gdscript
func clear_panels() -> void:
```

清空 Overlay 面板注册表。

<a id="member-gfdebugoverlayutility-methods-has_panel"></a>

### `has_panel`

- API：`public`

```gdscript
func has_panel(panel_id: StringName) -> bool:
```

检查 Overlay 面板是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `panel_id` | 面板唯一标识。 |

返回：已注册时返回 true。

<a id="member-gfdebugoverlayutility-methods-get_panel_snapshot"></a>

### `get_panel_snapshot`

- API：`public`

```gdscript
func get_panel_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
```

读取当前 Overlay 面板快照。

参数：

| 名称 | 说明 |
|---|---|
| `include_hidden` | 为 true 时同时返回 visible=false 的面板。 |

返回：面板快照数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 id、label、group、content 和 valid。

<a id="member-gfdebugoverlayutility-methods-record_metric_sample"></a>

### `record_metric_sample`

- API：`public`

```gdscript
func record_metric_sample(metric_id: StringName, value: float, options: Dictionary = {}) -> bool:
```

追加一个短期指标采样。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标唯一标识。 |
| `value` | 采样值。 |
| `options` | 可选配置，支持 label、group、visible、max_samples、timestamp_seconds、metadata 和 sample_metadata。 |

返回：采样成功返回 true。

结构：

- `options`: Dictionary，支持 label、group、visible、max_samples、timestamp_seconds、metadata 和 sample_metadata。

<a id="member-gfdebugoverlayutility-methods-get_or_create_metric_series"></a>

### `get_or_create_metric_series`

- API：`public`

```gdscript
func get_or_create_metric_series(metric_id: StringName, options: Dictionary = {}) -> GFMetricSeries:
```

获取或创建短期指标序列。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标唯一标识。 |
| `options` | 可选配置，支持 label、group、visible、max_samples 和 metadata。 |

返回：指标序列；metric_id 为空时返回 null。

结构：

- `options`: Dictionary，支持 label、group、visible、max_samples 和 metadata。

<a id="member-gfdebugoverlayutility-methods-register_metric_series"></a>

### `register_metric_series`

- API：`public`

```gdscript
func register_metric_series(series: GFMetricSeries) -> bool:
```

注册一个外部维护的指标序列。

参数：

| 名称 | 说明 |
|---|---|
| `series` | 指标序列。 |

返回：注册成功返回 true。

<a id="member-gfdebugoverlayutility-methods-remove_metric_series"></a>

### `remove_metric_series`

- API：`public`

```gdscript
func remove_metric_series(metric_id: StringName) -> void:
```

移除一个指标序列。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标唯一标识。 |

<a id="member-gfdebugoverlayutility-methods-clear_metric_series"></a>

### `clear_metric_series`

- API：`public`

```gdscript
func clear_metric_series() -> void:
```

清空全部指标序列。

<a id="member-gfdebugoverlayutility-methods-has_metric_series"></a>

### `has_metric_series`

- API：`public`

```gdscript
func has_metric_series(metric_id: StringName) -> bool:
```

检查指标序列是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标唯一标识。 |

返回：已注册时返回 true。

<a id="member-gfdebugoverlayutility-methods-get_metric_series_snapshot"></a>

### `get_metric_series_snapshot`

- API：`public`

```gdscript
func get_metric_series_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
```

读取当前指标序列快照。

参数：

| 名称 | 说明 |
|---|---|
| `include_hidden` | 为 true 时同时返回 visible=false 的指标序列。 |

返回：指标序列快照数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 id、label、group、visible、sample_count、latest_value、min_value、max_value、average_value、sparkline 和 metadata。

<a id="member-gfdebugoverlayutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 Overlay 运行时调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 debug_only、watch_count、panel_count、metric_series_count、include_diagnostics_monitors、include_recent_logs、include_metric_series_panel、recent_log_count、metric_series_width、diagnostics_monitor_preset 和 gui 分区。
