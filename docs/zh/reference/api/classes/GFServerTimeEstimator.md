# GFServerTimeEstimator

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_server_time_estimator.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

服务器样本与单调时钟组合的本地时间估计器。 请求票据只属于当前实例和进程；响应记录时测量整个往返，不读取系统墙上时钟。 估计并非可信服务器权威，网络不对称和服务器误差通过不确定度表达。新样本可以校正 时间向前或向后，项目必须自行持久化周期结算身份，不能凭时间变化重复发奖。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfservertimeestimator-methods-create) | `static func create(clock: GFClock = null, options: Dictionary = {}) -> GFServerTimeEstimator:` |
| 方法 | [`begin_sample`](#member-gfservertimeestimator-methods-begin_sample) | `func begin_sample() -> int:` |
| 方法 | [`accept_sample`](#member-gfservertimeestimator-methods-accept_sample) | `func accept_sample( ticket: int, server_unix_msec: int, server_uncertainty_msec: int = 0 ) -> bool:` |
| 方法 | [`cancel_sample`](#member-gfservertimeestimator-methods-cancel_sample) | `func cancel_sample(ticket: int) -> bool:` |
| 方法 | [`mark_resumed`](#member-gfservertimeestimator-methods-mark_resumed) | `func mark_resumed() -> void:` |
| 方法 | [`get_estimate`](#member-gfservertimeestimator-methods-get_estimate) | `func get_estimate() -> Dictionary:` |

## 方法

<a id="member-gfservertimeestimator-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create(clock: GFClock = null, options: Dictionary = {}) -> GFServerTimeEstimator:
```

创建估计器并冻结计时政策。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 单调时钟；null 使用 GFClock，永不读取其墙上时间。 |
| `options` | 样本政策。 |

返回：新估计器；非法政策返回 null。

结构：

- `options`: 封闭 Dictionary，可选 max_age_msec:int[1,86400000]（默认300000）、max_rtt_msec:int[0,300000]（默认10000）、drift_ppm:int[0,1000000]（默认50）。

<a id="member-gfservertimeestimator-methods-begin_sample"></a>

### `begin_sample`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_sample() -> int:
```

在发送时间请求前取得一次性票据，并捕获单调起点。

返回：正整数票据；时钟不可用、16个未过期请求占满或实例未初始化时为0。超时票据自动移除。

<a id="member-gfservertimeestimator-methods-accept_sample"></a>

### `accept_sample`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func accept_sample( ticket: int, server_unix_msec: int, server_uncertainty_msec: int = 0 ) -> bool:
```

接收服务器时间样本，消耗对应票据并验证往返和响应顺序。

参数：

| 名称 | 说明 |
|---|---|
| `ticket` | begin_sample 返回的当前实例票据。 |
| `server_unix_msec` | 服务器在该请求处理期间采样的 Unix 毫秒，范围 ±4×10^15。 |
| `server_uncertainty_msec` | 项目声明的服务器时间样本误差界，范围0..86400000。 |

返回：接受并替换当前样本时为 true；失败保留先前样本。票据只可提交一次，较早请求不能覆盖较新请求的已接受样本。

<a id="member-gfservertimeestimator-methods-cancel_sample"></a>

### `cancel_sample`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_sample(ticket: int) -> bool:
```

取消本地采样票据，不影响已接受样本或远端请求。

参数：

| 名称 | 说明 |
|---|---|
| `ticket` | 本地请求票据。 |

返回：移除了仍在等待的票据时为 true。

<a id="member-gfservertimeestimator-methods-mark_resumed"></a>

### `mark_resumed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func mark_resumed() -> void:
```

应用恢复或计时环境切换后立即调用；旧样本和旧请求全部失效。

<a id="member-gfservertimeestimator-methods-get_estimate"></a>

### `get_estimate`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_estimate() -> Dictionary:
```

读取估计和完整可用状态。

返回：当前估计记录；只有 available=true 时才能使用 Unix 值及上下界。

结构：

- `return`: 封闭九字段 Dictionary：status:String（available/unavailable/expired/resumed/clock_regressed）、available:bool、unix_time_msec:int、lower_bound_msec:int、upper_bound_msec:int、sample_age_msec:int、round_trip_msec:int、uncertainty_msec:int、sample_id:int。不可用时三个Unix值为0；无样本时年龄、RTT和不确定度为-1；过期样本保留年龄和RTT但不提供不确定度。区间只覆盖给定误差与漂移政策，不保证服务器真实性。
