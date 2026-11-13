# 等待反馈与 Loading lease

`GFUILoadingUtility` 聚合尚未结束的等待请求，只发布状态。项目选择遮罩、进度条、动画和输入策略。每次业务流程取得独立的 `GFUILoadingLease`，在业务终态释放；并发请求不会互相关闭等待反馈。

回调中的重入变化串行发布，同一轮中间状态合并为最新状态。单次调用最多发布256轮，超过预算的状态由下一次 tick 续发，避免反馈回调无限占用主线程。

## 贯穿业务流程的等待租约

```gdscript
var loading: GFUILoadingUtility = GFUILoadingUtility.new()
loading.configure(150, 250)
loading.state_changed.connect(update_loading_view)

var scope: GFAsyncScope = GFAsyncScope.new()
var lease: GFUILoadingLease = loading.acquire(self, scope)
if lease == null:
	return
var operation: GFUIRouteOperation = router.push_route_async(
	&"inventory", {}, {}, Callable(), {"owner": self, "scope": scope}
)
var result: GFUIRouteResult = await operation.wait_result_async()
lease.release()
# result 已是业务终态；显示层可以继续完成最短可见时间。
```

这里的 `self` 是已在场景树中的项目节点。请求从按钮动作开始取得 lease，贯穿预加载、页面建立以及可选的内容准备与语义定位；不要在每个阶段分别开关同一个全局布尔值。项目后续还有网络或动画等待时，同一个 lease 可以保持至整个流程结束。

## 显示状态与生命周期

`configure(display_delay_msec, minimum_visible_msec, clock)` 只能在首次使用前配置一次，两个显示时长均为 `0..60000` 毫秒。默认延迟 150 毫秒、最短可见 250 毫秒。快速结束的请求不会显示；最后一个请求释放后，`pending_count` 立即变成 0，而 `visible` 可以暂时保持 true。新请求在可见尾段到来时继续当前显示，不重新闪烁。服务释放会立即隐藏，不等待最短时长。

`state_changed` 与 `get_state()` 提供相同的隔离字典：

| 字段 | 含义 |
|---|---|
| `visible` | 项目提示层当前是否应显示 |
| `pending_count` | 尚未释放的请求数量 |
| `determinate_count` | 关联了有效进度值的请求数量 |
| `indeterminate_count` | 没有可用进度的请求数量 |
| `progress` | 已知进度的等权平均；没有已知进度时为 0 |

可以通过 `acquire(owner, scope, progress)` 关联已有 `GFAsyncProgress`。服务在 tick 采样，不依赖进度对象的信号节流政策。存在未知进度时，平均值不能表示整个流程已完成；进度达到 1 也不会释放 lease。需要按工作量加权时，项目先使用既有进度聚合器得到一个业务进度，再关联到该请求。

lease 的释放是幂等的，只影响自身身份，不取消业务。Node owner 离树、scope 取消会立即释放；普通 Object 销毁、scope 正常结束或销毁在下一次 tick 清理。owner/scope 使用弱引用。没有 owner/scope 时调用方必须显式释放，丢弃变量不会自动结束服务仍持有的等待。最多允许 4096 个活动 lease，超限返回 null。

把 Utility 交给架构或由宿主持续调用 `tick`；单独使用时同样需要驱动。计时使用 `GFClock` 的单调时间，测试可注入 `GFManualClock`。若游戏暂停时仍要刷新提示，设置继承的 `ignore_pause = true`，或由宿主持续驱动。服务不查询系统墙上时间，不读取业务消息文案来决定状态。

## 获取前诊断

`validate_acquire(owner, scope)` 只读检查当前服务与生命周期，返回独立的 `ok`、`error_kind`、`path` 报告。它不创建 lease、不消耗 ID、不预留容量、不连接信号、不读取时钟、不清理旧 lease，也不发布显示状态或保留 owner/scope。进度未知仍是合法等待，因此该入口不需要进度参数。

错误码包括 `service_disposed`、`lease_limit`、`identity_exhausted`、`owner_invalid`、`owner_outside_tree`、`scope_inactive`；位置为当前服务的空路径，或 `/leases`、`/lease_id`、`/owner`、`/scope`。容量错误含 `limit`、`observed`，其中 `lease_limit.observed` 表示申请本次 lease 后所需的总数。`acquire()` 每次使用同一验证路径重新检查，仍返回 lease 或 null；检查后 owner 离树、scope 结束或容量被其他调用占用，都会使正式申请被拒绝。
