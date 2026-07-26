# 派发语义与诊断

事件系统同步调用监听回调，并在注册、派发、嵌套派发和诊断追踪上保持确定规则。

## 签名校验

类型事件回调必须至少接收一个事件实例参数；简单事件回调也必须至少接收一个 `payload` 参数。

框架会对对象方法形式的回调做运行时反射校验。参数不足、额外必填参数未通过默认值或 `bind()` 满足，或 `bind()` 后会传入超过目标方法可接收参数数量的实参时，都会输出错误并跳过注册。

## 同步派发

监听器默认同步执行。事件系统只调用回调，不会等待回调返回的 `Signal`。需要串行等待、失败处理、超时控制或可取消流程时，请使用 `GFCommandSequence`、Flow、ActionQueue 或项目层 System 调度。

exact 与 assignable 不自动去重。同一个 callable 如果同时注册到精确类型监听和 assignable 监听，可能在同一次派发中被调用两次。需要避免重复处理时，只注册其中一种，或在业务侧自行去重。

## 嵌套派发

事件回调中再次发送事件时，遍历中新增或移除的监听器会延迟到最外层派发结束后统一合并，避免内层事件提前改变外层监听器列表。

同一轮派发里先注册再注销的监听器不会在 flush 后残留，即使注册和注销的是另一个事件类型或简单事件 ID。

## 深度保护与 Trace

从 `2.0.0` 起，`GFTypeEventSystem.max_dispatch_depth` 默认使用 `GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH`，也就是 `64` 层，避免递归事件链无限嵌套。类型事件和 Simple Event 共享同一个全局 dispatch depth，因此交替递归也不能绕过上限。确实需要不受限制的项目可显式设为 `0`。

`trace_enabled` 默认关闭，开启后可通过 `Gf.get_event_dispatch_trace()` 读取最近派发条目，包括单调递增的 sequence、轨道、事件标识、监听数量、深度和时间戳；裁剪 trace 或调用 clear 不会复用旧 sequence，也不会破坏累计派发统计。生产环境只建议在诊断面板或临时排查中开启。

```gdscript
Gf.configure_event_debugging(8, true, 32)

Gf.send_simple_event(&"ui_opened", { "panel": "inventory" })
print(Gf.get_event_dispatch_trace())
```

## 监听器诊断

需要排查 owner 生命周期或监听器泄漏时，可以读取事件系统统计和监听器明细：

```gdscript
print(Gf.get_event_debug_stats())
print(Gf.get_event_listener_diagnostics({ "include_entries": true }))
```

诊断会统计总监听器数量、已释放 owner 数量、pending 变更、dispatch cache 大小和每条轨道的监听器数量。`include_entries` 会列出事件 key、owner 状态、Callable 状态、优先级和注册顺序，只建议在工具面板或临时排查中开启。

如果诊断发现 owner 已释放但监听器还没等到下一次派发自动清理，可以调用：

```gdscript
var removed := Gf.compact_event_listeners()
```

派发期间调用 compact 时，清理会进入 pending 队列，并在最外层派发结束后合并。
