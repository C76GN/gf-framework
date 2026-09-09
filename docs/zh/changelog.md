# 更新日志 (Changelog)

## [未发布]

**版本概述**：重做节点对象池的借还生命周期，解决物理碰撞回调中归还节点的引擎错误，以及弹幕复用时被提前回收的问题。调用方式统一为异步借用结果与一次性 Lease；不保留旧接口兼容层。新增场景组查询工具，可在编辑器中查找已保存的 Group 声明并定位来源节点。Flow 图编辑支持撤销与重做，Resource 表格支持只应用已编辑分量的多选属性编辑。本次为下一主版本的开发变更，尚未正式发布。

### 🚀 新增特性 (Added)

- 新增 `GFObjectPoolAcquireResult` 与 `GFObjectPoolLease`。成功借用取得独立使用权，归还立即失效，`wait_settled()` 可重复等待实际离树或淘汰完成。
- 节点根脚本可实现同步 `on_gf_pool_prepare(context) -> Error`，在每次入树前准备本次数据；空闲实例完全离树。
- 新增 `GFProjectileEmissionResult`，用单次 `await` 的返回值表达整批发射结果。
- 新增 [Scene Groups 场景组查询](editor/tools/scene-groups.md)。从已保存的 `.tscn` / `.scn` 查找持久化 Group 声明，支持搜索、分页和来源节点定位；扫描取消、读取失败或预算耗尽时明确报告结果不完整。
- [Flow 图编辑器](extensions/flow/editor-model.md) 的连线、删除节点与布局编辑接入 Godot 撤销/重做，删除节点时一并恢复关联连接与布局，一次拖动对应一次编辑动作。
- [Resource 表格](editor/resource-table-editor.md) 支持多行选择、属性混合值呈现和暂存编辑；应用时只修改实际编辑的分量，取消或切换选择会丢弃暂存输入。
- [配置跨表引用](standard/utilities/io/config-remote-outbox/config-provider/relations-builds/indexes-references.md#数组元素引用) 支持逐项校验一维 Array 中的标量键；错误保留原字段名、元素位置和值，导表继续附加可用的来源与单元格位置。

### 🔄 机制更改 (Changed)

- 对象池统一在主线程安全点挂载、离树和清理。节点自己的 `_enter_tree()` / `_exit_tree()` 负责进入与退出生命周期，池不再递归改写节点处理、物理、可见性或 Controller 事件开关。
- 预热统一为 `await prewarm(scene, count, batch_size, cancellation_token)`，只分批实例化离树缓存，不触发入树生命周期，也不执行 prepare。
- 弹幕以整批借用完成后再绑定本次生命周期，使用 Lease 归还；`gf.combat` 的 `extension_version` 升为 `4.0.0`。
- 普通音效使用音频服务自己的播放器缓存，保留同步播放和现有音频 Handle 接口，不依赖异步节点对象池。
- Workspace 向需要编辑的贡献页面注入通用编辑器上下文，并在页面移除时撤销。独立创建的 Flow 面板须显式提供上下文后才能修改图资源；`gf.flow` 的 `extension_version` 升为 `4.0.0`。

### 🐛 Bug 修复 (Fixed)

- 修复通用数值输入在未声明范围时截断负数和大值的问题；多行 String 使用保留换行的文本框。Resource 表格重新绑定资源后，旧撤销/重做动作产生的自动保存失败仍会通知调用方，同时保留当前草稿。
- 修复深复制丢失 Array/Dictionary 类型约束，导致属性事务无法写入类型化节点或连接集合的问题；副本保留集合类型、循环结构和默认 Resource 引用身份。
- 场景组查询在扫描期间拒绝重复启动，保留已有进度和结果；翻页取消节点定位时同步清除等待提示。
- 修复在 `Area2D` / `Area3D` 碰撞回调中归还对象时同步改变场景树或物理节点状态的问题。
- 修复弹幕第二次使用池中实例时，旧绑定把正常重新挂载误判为实例丢失的问题。
- 修复批量弹幕中前一枚的通知回调破坏后一枚候选后，仍对失效候选发布启动通知的问题；每个用户回调边界重新检查整个批次。
- 陈旧 Lease、重复归还和归还完成回调不能撤销同一节点的新借用；父节点丢失、prepare 失败和池销毁会回收未交付候选。
- 修复架构关停或替换对象池时未等待安全点清理和全部终态通知的问题，包括通知回调重入关停的情况。
- 借用必须绑定接收方，修复临时调用方在等待期间销毁、但常驻父节点仍存在时留下无人接收节点的问题；交付后的 Lease 仍由业务明确归还或转交。
- 批量挂载前检查候选是否已被前一候选的生命周期回调重新挂载，避免重复 `add_child()`；调试快照不再把排队删除或已被挂载的空闲记录计入可用库存。
- 修复大量分批预热时后续批次反复插队，使已接纳的借用或归还长期等待的问题。
- 修复节点在意外离树回调中先归还 Lease 后被误判为正常归还并重新缓存的问题；补全借用结果的 `invalid_owner` 原因说明。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除同步节点借用、按裸节点归还、`before_add` 回调及池专用节点启停钩子。
- 移除 `GFObjectPoolPrewarmOperation` 及其 `progressed` / `completed` 信号和多套预热入口。独立公开的弹幕发射策略 Task 改为内部实现。

### 🔧 API 变动说明 (API Changes)

- `GFObjectPoolUtility.acquire(scene, parent, lifetime_owner, context = {})` 现在需要 `await`，返回 `GFObjectPoolAcquireResult`；必填的 `lifetime_owner` 通常传 `self`，与挂载父节点分离。成功后用 `get_lease()` 获取 Lease，再以 `get_node()` 访问节点。
- `pool.release(node, scene)` 改为 `lease.release()`。首次归还返回 `true`，此时 `get_node()` 已返回 `null`；等待离树请使用 `await lease.wait_settled()`。
- `prewarm()` 不再接收父节点，返回 `GFObjectPoolPrewarmResult`；结果包含最终状态、原因、请求数与实际创建数，取消不会回滚已缓存实例。
- 同名 `GFObjectPoolPrewarmResult` 的状态、原因与计数接口也有破坏性调整；`COMPLETED` 改为 `SUCCEEDED`，容量拒绝合并为 `PARTIAL`，池销毁合并为 `CANCELLED`。旧原因常量和细分计数不再保留，详见对象池指南的迁移表。
- 删除弹幕旧同步单发/多发入口与直接节点返回值，统一使用 `await emit_pattern()` 返回 `GFProjectileEmissionResult`。移除 `use_object_pool` 开关和 Emitter 预热包装；需要复用时设置 `object_pool_utility`，预热直接调用池。
- `dispose()` 立即拒绝新借用并撤销所有 Lease，清理在安全点执行；需要等待时调用 `await pool.wait_disposed()`。该等待包含已接纳请求与 Lease 的终态通知，不保证引擎已完成 `queue_free()`。注册到架构的池参与正常异步关停与替换的静默期等待。
- 保留已有接口的首次发布 `@since` 版本，不因本次签名或语义重做而改为 `unreleased`。
- Flow 面板与 Resource 表格新增 `set_editor_context()`。新增 `GFEditorMultiPropertyField`，通过暂存值生成属性批处理请求，提交仍复用既有命令与资源历史；不改变 Flow 图的持久化格式或运行时执行协议。
- `GFConfigTableReference` 新增 `SourceMode` 与 `source_mode`，默认 `FIELDS` 保持原有字段引用行为；`ARRAY_ELEMENTS` 校验单个数组字段到目标单字段键的引用。元素问题增加零基 `element_index`；`resolve_record_references()` 仍只解析 `FIELDS` 引用。

### 📘 升级指南 (Migration Guide)

1. 给节点借用与弹幕发射调用增加 `await`；节点借用的第三个参数必须传接收方 `lifetime_owner`（通常是 `self`），初始化数据移到第四个参数。检查结果成功后再使用节点或 Session。不要保留旧 Task 或监听已移除的预热 Operation 信号。
2. 每次借用保存对应 Lease，用 Lease 归还，不再用节点引用作为回收凭证。归还后立即停止访问此前保存的裸节点引用。
3. 将 `before_add` 和旧池启停钩子的每次初始化迁到根节点的 `on_gf_pool_prepare(context)`；进入/退出时的注册与清理由 Godot 生命周期负责。`_ready()` 默认只执行首次，不能当成每次借用的初始化。
4. 把旧预热调用改成 `await pool.prewarm(scene, count)`；预热阶段不再要求业务父节点。池需要保留到使用结束，独立使用时显式调用 `dispose()`，注册到架构后由正常异步关停流程清理。
5. 若节点有 Timer、Tween、异步任务或外部信号，项目脚本必须在退出时取消本轮任务或检查本轮 Lease，防止旧回调影响下一轮。离树不是任意外部工作的自动取消器。
6. 独立创建 Flow 面板的编辑器插件须调用 `set_editor_context(GFEditorToolContext.from_plugin(self))`；通过 Workspace 挂载的面板由工作区自动注入。没有有效撤销管理器时面板仅查看，不再直接修改资源。Resource 表格的新多选编辑入口同样需要上下文，原有显式 `commit_*` 调用方式保留。

详细示例见[对象池](standard/utilities/runtime/time-signal-pool/object-pool.md)与[弹幕](extensions/combat/projectiles.md)。已发布历史仍可从对应版本 tag 和 Release 查看。
