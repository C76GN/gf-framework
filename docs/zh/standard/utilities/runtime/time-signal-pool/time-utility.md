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

需要把可控时间映射为周期环境视觉时，见 [Shader 参数 Profile 的周期环境表现组合配方](../settings-ui-scene/shader-parameter-profile.md)。时间服务只提供时钟域，周期、天气、天文与表现映射仍由项目负责。

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

全局暂停会让未标记 `ignore_pause` 的系统收到 `0.0`，分组暂停则需要系统或项目代码使用 `get_group_scaled_delta()` 主动读取对应组的 delta。
