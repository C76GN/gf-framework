# GFUILoadingUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_loading_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

并发等待请求的显示状态聚合器。 主线程服务；不创建界面，不阻塞业务完成。延迟与最短可见时间使用注入的单调时钟， tick 同时检查弱 owner/scope 与当前进度。最多持有 4096 个活动 lease。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_changed`](#member-gfuiloadingutility-signals-state_changed) | `signal state_changed(state: Dictionary)` |
| 方法 | [`tick`](#member-gfuiloadingutility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfuiloadingutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfuiloadingutility-methods-configure) | `func configure( display_delay_msec: int = 150, minimum_visible_msec: int = 250, clock: GFClock = null ) -> bool:` |
| 方法 | [`acquire`](#member-gfuiloadingutility-methods-acquire) | `func acquire( owner: Object = null, scope: GFAsyncScope = null, progress: GFAsyncProgress = null ) -> GFUILoadingLease:` |
| 方法 | [`validate_acquire`](#member-gfuiloadingutility-methods-validate_acquire) | `func validate_acquire(owner: Object = null, scope: GFAsyncScope = null) -> Dictionary:` |
| 方法 | [`get_state`](#member-gfuiloadingutility-methods-get_state) | `func get_state() -> Dictionary:` |

## 信号

<a id="member-gfuiloadingutility-signals-state_changed"></a>

### `state_changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal state_changed(state: Dictionary)
```

展示状态或活动请求聚合发生变化时发出，监听方不获得内部可写状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前聚合状态副本。 |

结构：

- `state`: Dictionary with visible:bool, pending_count:int, determinate_count:int, indeterminate_count:int, progress:float。progress 为已知进度的等权平均；无已知进度时为 0。

## 方法

<a id="member-gfuiloadingutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float) -> void:
```

清理过期请求并刷新显示与进度，不依赖 delta 计时。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 架构帧间隔；本服务读取单调时钟。 |

<a id="member-gfuiloadingutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

立即撤销全部 lease 并隐藏反馈，不等待显示政策。

<a id="member-gfuiloadingutility-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( display_delay_msec: int = 150, minimum_visible_msec: int = 250, clock: GFClock = null ) -> bool:
```

在第一次 acquire 前冻结显示政策和时钟。

参数：

| 名称 | 说明 |
|---|---|
| `display_delay_msec` | 0 到 60000 毫秒。 |
| `minimum_visible_msec` | 0 到 60000 毫秒；不延长业务等待。 |
| `clock` | 可选单调时钟。 |

返回：首次有效配置时为 true。

<a id="member-gfuiloadingutility-methods-acquire"></a>

### `acquire`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func acquire( owner: Object = null, scope: GFAsyncScope = null, progress: GFAsyncProgress = null ) -> GFUILoadingLease:
```

为一次业务等待取得独立句柄。 无 owner/scope 时必须显式释放；Node owner 必须在树中，离树立即释放。 普通 Object 销毁、scope.complete 或 scope 销毁在下一次 tick 释放。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 可选生命周期拥有者，服务不持有强引用。 |
| `scope` | 可选活动请求作用域。 |
| `progress` | 可选既有进度句柄；达到 1 不自动释放。 |

返回：新 lease；参数失效、超限或服务释放时为 null。

<a id="member-gfuiloadingutility-methods-validate_acquire"></a>

### `validate_acquire`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_acquire(owner: Object = null, scope: GFAsyncScope = null) -> Dictionary:
```

只读检查 acquire 的生命周期和剩余容量，不取得 lease、消耗 ID 或刷新显示。 进度未知或暂时无效仍是合法等待，故此入口不采样进度。报告不预留容量； acquire 在执行时重新检查。检查不会连接信号、保留 owner/scope 或触发业务回调。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 与 acquire 相同的可选生命周期 owner。 |
| `scope` | 与 acquire 相同的可选活动作用域。 |

返回：当前服务与参数的独立校验报告；不输出错误日志。

结构：

- `return`: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。 lease_limit 的 observed 是申请本次 lease 后所需总数。

<a id="member-gfuiloadingutility-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_state() -> Dictionary:
```

获取最近发布的显示状态；进度与过期生命周期在 tick 时采样。

返回：隔离状态副本。

结构：

- `return`: Dictionary with visible:bool, pending_count:int, determinate_count:int, indeterminate_count:int, progress:float，与 state_changed 一致。
