# 时钟与动态时间缩放

GF 把“现在几点”和“游戏跑多快”分成两个契约：`GFClock` 提供时间来源，`GFTimeProvider` / `GFTimeUtility` 负责 tick 缩放、暂停和物理子步。超时、耗时与排序必须使用单调时间；持久化时间戳和跨进程交换必须使用 Unix 时间，不能互换。

## 时钟域

- `GFClock.get_monotonic_usec()` / `get_monotonic_msec()`：只用于进程内耗时、deadline 和顺序，不可写入存档。
- `GFClock.get_unix_time_msec()` / `get_unix_time_seconds()`：可持久化和跨进程，但可能因系统校时跳变，不能计算可靠耗时。
- `GFManualClock`：测试和模拟用确定性时钟；单调时间只能向前，Unix 时间可独立调整。

```gdscript
var clock := GFManualClock.new(0, 1_700_000_000_000)
var time := GFTimeUtility.new()
time.set_clock(clock)

clock.advance_msec(250)
assert(time.get_monotonic_msec() == 250)
assert(time.get_unix_time_msec() == 1_700_000_000_250)
```

架构中注册一个 `GFTimeProvider` 后，平台运行时和 SaveGraph 等支持时钟注入的服务会采用同一底层时钟。单个服务显式调用 `set_clock()` 后保留该选择，便于独立测试或模拟。不要通过修改 Unix 时间模拟暂停，也不要让游戏时间缩放影响网络、超时或持久化时间戳。

需要把可控时间映射为周期环境视觉时，见 [Shader 参数 Profile 的周期环境表现组合配方](../settings-ui-scene/shader-parameter-profile.md)。时间来源和下面的周期窗口可作为输入；天气、天文与表现映射由项目负责。

## 服务器时间估计

`GFServerTimeEstimator` 用服务器样本和注入的 `GFClock` 单调时间推算当前 Unix 毫秒。它不读取本机墙上时钟，不是服务器权威，也不验证服务器真实性。项目适配器负责认证、请求和响应字段解释。

```gdscript
var estimator: GFServerTimeEstimator = GFServerTimeEstimator.create(
	clock, {"max_age_msec": 300000, "max_rtt_msec": 10000, "drift_ppm": 50}
)
var ticket: int = estimator.begin_sample()
# 发送请求，并在响应到达主线程后提交处理期间采集的服务器时间：
var accepted: bool = estimator.accept_sample(ticket, server_unix_msec, server_error_msec)
var estimate: Dictionary = estimator.get_estimate()
```

票据只属于当前实例和进程，不持久化、不跨实例使用。最多16个未过期请求；`begin_sample()` 返回0表示未受理。`accept_sample()` 消耗一次票据，拒绝超出 RTT 政策、非法时间值和较旧请求的迟到结果；失败不覆盖先前有效样本。`cancel_sample()` 只释放本地票据。

估计以接收时刻的 `server_time + floor(RTT/2)` 为起点。不确定度为服务器声明的误差、向上取整的半 RTT 和样本年龄对应的漂移误差之和。上下界依赖这些假设，不能作为防作弊或奖励授权依据。新样本允许把估计向前或向后校正，不用假装单调的墙上时间掩盖校正。

`get_estimate()` 明确返回 available、unavailable、expired、resumed 或 clock_regressed。只有 `available=true` 才能使用 Unix 值和区间；到达最大年龄边界即过期。不可用时 Unix 值为0，不应解释为1970年；年龄、RTT和不确定度提供单独的诊断状态。应用恢复时调用 `mark_resumed()`，旧样本和在途票据同时失效，重新取样后才恢复可用。宿主需接线恢复通知，框架不会推测应用是否经历了系统挂起。

## 周期窗口

`GFPeriodSchedule` 是冻结政策，`get_window(unix_msec)` 返回 `GFTimeWindow`，包含 `start_msec`、`end_msec` 与 `period_id`。边界统一为 `[start, end)`，一个边界时刻只属于新周期；负 Unix 时间和锚点之前的窗口同样确定。

```gdscript
# 固定 UTC+8，每天当地04:00重置；这里不包含地区时区或 DST。
var schedule: GFPeriodSchedule = GFPeriodSchedule.create(
	&"daily_tasks", 3, {"offset_minutes": 480, "reset_second": 14400}
)
var window: GFTimeWindow = schedule.get_window(server_unix_msec)
var period_id: String = window.get_period_id()
```

政策可选择 daily、weekly 或 fixed。weekly 的 weekday 使用周日0至周六6，默认周一1；fixed 必须明确指定 Unix 毫秒 anchor_msec 和正整数 interval_msec，不接受日历偏移字段。偏移固定在±14小时内。查询时间范围为±4×10^15毫秒，窗口计算使用整数余数，避免大整数浮点除法在边界处选错周期。

周期身份包含计划 ID、版本、生效政策及窗口起点。项目应把它当作不透明字符串，与“已处理”状态一起持久化；政策变更应递增版本，框架也防止相同版本下不同政策复用身份。返回窗口不表示奖励已结算，不自动执行补签、离线收益、重置任务或本地与服务器对账。

UTC／固定偏移是本层的完整范围。地区时区、DST 和闰秒应由独立日历适配器或服务端给定窗口处理。Godot 的系统时间可能被用户或系统调整，日期换算也不自动处理时区和 DST；精确耗时应使用单调 ticks，见 [Godot Time 文档](https://docs.godotengine.org/en/stable/classes/class_time.html)。

## 动态缩放

`GFTimeUtility` 用于实现子弹时间、暂停特定组内的系统、在受击时定帧。

## 基础用法

```gdscript
var time_scale_util := Gf.get_utility(GFTimeUtility) as GFTimeUtility

# 全局逻辑时间放慢 10 倍
time_scale_util.time_scale = 0.1

# 或暂停某个自定义组，并在系统内主动获取该组 delta
time_scale_util.set_group_paused(&"CombatSystems", true)
```

`max_scaled_delta` 可限制单帧传入普通 `tick()` 的最大缩放步长，避免掉帧或极端加速造成逻辑跳变。

物理逻辑可通过 `physics_substep_max_delta` 和 `max_physics_substeps` 把一次 `physics_tick` 拆成多个子步。

`time_scale`、`max_scaled_delta` 和 `physics_substep_max_delta` 只接受有限值；写入 `NaN` 或无穷时保留上一个有效配置。外部 tick 输入为非有限值，或有限输入与缩放相乘后溢出时，本轮逻辑 delta 归零。极端但仍有限的物理 delta 会把子步数钳制到 `max_physics_substeps`，不会把无限值或超范围整数传播给系统。

全局暂停会让未标记 `ignore_pause` 的系统收到 `0.0`，分组暂停则需要系统或项目代码使用 `get_group_scaled_delta()` 主动读取对应组的 delta。
