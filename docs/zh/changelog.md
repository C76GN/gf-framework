# 更新日志 (Changelog)

## [未发布]

**版本概述**：重做节点对象池的借还生命周期，解决物理碰撞回调中归还节点的引擎错误，以及弹幕复用时被提前回收的问题。调用方式统一为异步借用结果与一次性 Lease；不保留旧接口兼容层。本次为下一主版本的开发变更，尚未正式发布。

### 🚀 新增特性 (Added)

- 新增 `GFObjectPoolAcquireResult` 与 `GFObjectPoolLease`。成功借用取得独立使用权，归还立即失效，`wait_settled()` 可重复等待实际离树或淘汰完成。
- 节点根脚本可实现同步 `on_gf_pool_prepare(context) -> Error`，在每次入树前准备本次数据；空闲实例完全离树。
- 新增 `GFProjectileEmissionResult`，用单次 `await` 的返回值表达整批发射结果。

### 🔄 机制更改 (Changed)

- 对象池统一在主线程安全点挂载、离树和清理。节点自己的 `_enter_tree()` / `_exit_tree()` 负责进入与退出生命周期，池不再递归改写节点处理、物理、可见性或 Controller 事件开关。
- 预热统一为 `await prewarm(scene, count, batch_size, cancellation_token)`，只分批实例化离树缓存，不触发入树生命周期，也不执行 prepare。
- 弹幕以整批借用完成后再绑定本次生命周期，使用 Lease 归还；`gf.combat` 的 `extension_version` 升为 `4.0.0`。
- 普通音效使用音频服务自己的播放器缓存，保留同步播放和现有音频 Handle 接口，不依赖异步节点对象池。

### 🐛 Bug 修复 (Fixed)

- 修复在 `Area2D` / `Area3D` 碰撞回调中归还对象时同步改变场景树或物理节点状态的问题。
- 修复弹幕第二次使用池中实例时，旧绑定把正常重新挂载误判为实例丢失的问题。
- 修复批量弹幕中前一枚的通知回调破坏后一枚候选后，仍对失效候选发布启动通知的问题；每个用户回调边界重新检查整个批次。
- 陈旧 Lease、重复归还和归还完成回调不能撤销同一节点的新借用；父节点丢失、prepare 失败和池销毁会回收未交付候选。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除同步节点借用、按裸节点归还、`before_add` 回调及池专用节点启停钩子。
- 移除 `GFObjectPoolPrewarmOperation` 及其 `progressed` / `completed` 信号和多套预热入口。独立公开的弹幕发射策略 Task 改为内部实现。

### 🔧 API 变动说明 (API Changes)

- `GFObjectPoolUtility.acquire(scene, parent, context = {})` 现在需要 `await`，返回 `GFObjectPoolAcquireResult`；成功后用 `get_lease()` 获取 Lease，再以 `get_node()` 访问节点。
- `pool.release(node, scene)` 改为 `lease.release()`。首次归还返回 `true`，此时 `get_node()` 已返回 `null`；等待离树请使用 `await lease.wait_settled()`。
- `prewarm()` 不再接收父节点，返回 `GFObjectPoolPrewarmResult`；结果包含最终状态、原因、请求数与实际创建数，取消不会回滚已缓存实例。
- 同名 `GFObjectPoolPrewarmResult` 的状态、原因与计数接口也有破坏性调整；`COMPLETED` 改为 `SUCCEEDED`，容量拒绝合并为 `PARTIAL`，池销毁合并为 `CANCELLED`。旧原因常量和细分计数不再保留，详见对象池指南的迁移表。
- 删除弹幕旧同步单发/多发入口与直接节点返回值，统一使用 `await emit_pattern()` 返回 `GFProjectileEmissionResult`。移除 `use_object_pool` 开关和 Emitter 预热包装；需要复用时设置 `object_pool_utility`，预热直接调用池。
- `dispose()` 立即拒绝新借用并撤销所有 Lease，清理在安全点执行；需要等待时调用 `await pool.wait_disposed()`。该等待表示已经离树或提交删除，不保证引擎已完成 `queue_free()`。

### 📘 升级指南 (Migration Guide)

1. 给节点借用与弹幕发射调用增加 `await`，检查结果成功后再使用节点或 Session。不要保留旧 Task 或监听已移除的预热 Operation 信号。
2. 每次借用保存对应 Lease，用 Lease 归还，不再用节点引用作为回收凭证。归还后立即停止访问此前保存的裸节点引用。
3. 将 `before_add` 和旧池启停钩子的每次初始化迁到根节点的 `on_gf_pool_prepare(context)`；进入/退出时的注册与清理由 Godot 生命周期负责。`_ready()` 默认只执行首次，不能当成每次借用的初始化。
4. 把旧预热调用改成 `await pool.prewarm(scene, count)`；预热阶段不再要求业务父节点。池需要保留到使用结束，并显式调用 `dispose()`。
5. 若节点有 Timer、Tween、异步任务或外部信号，项目脚本必须在退出时取消本轮任务或检查本轮 Lease，防止旧回调影响下一轮。离树不是任意外部工作的自动取消器。

详细示例见[对象池](standard/utilities/runtime/time-signal-pool/object-pool.md)与[弹幕](extensions/combat/projectiles.md)。已发布历史仍可从对应版本 tag 和 Release 查看。
