# 更新日志 (Changelog)

## [未发布]

**版本概述**：重做节点对象池的借还生命周期，解决物理碰撞回调中归还节点的引擎错误，以及弹幕复用时被提前回收的问题。调用方式统一为异步借用结果与一次性 Lease；不保留旧接口兼容层。新增场景组查询工具，可在编辑器中查找已保存的 Group 声明并定位来源节点。Flow 图编辑支持撤销与重做，Resource 表格支持只应用已编辑分量的多选属性编辑。本次为下一主版本的开发变更，尚未正式发布。

### 🚀 新增特性 (Added)

- [2D 空间画布](standard/input-flow/spatial-canvas-2d.md#已选条目的默认轮廓) 支持独立隐藏已选条目的默认矩形轮廓，便于项目使用自定义选中装饰，同时保留点选、框选、网格与放置预览。
- [本地 Storage 已提交版本](standard/utilities/io/storage-snapshot/committed-revisions.md) 支持显式 schema 2、离线升级、opaque revision 查询及同步/异步 JSON 和 Resource 实际读取配对；提交恢复、删除重建和 family reset 保持代次一致，显式创建中断后可安全重试空布局前缀或一致完整的 pending，布局检查和 pending 恢复包含隐藏文件证据，默认 schema 1 不自动升级。
- [Storage catalog 查询](standard/utilities/io/storage-snapshot/catalog-query.md) 支持区分成功空集合、查询失败和返回数量截断；完整性绑定本次逻辑查询范围，旧文件列表接口保持兼容。
- [配置字段校验](standard/utilities/io/config-remote-outbox/config-provider/validation-importer/validation-rules.md#数组逐元素校验) 支持为一维 Array 单独声明元素规则，复用范围、正则、白名单、资源路径和本地化 key 校验；错误保留原字段、元素下标和值，并共享本次验证的工作量与资源探测预算。
- [周期输入脉冲](standard/input-flow/input-assist/input-modifiers-triggers.md#周期脉冲的首次等待) 支持独立首次等待，可在按下立即响应后等待较长时间，再按较短间隔重复；动作和玩家保持独立计时。
- [配置化 Tween](extensions/action-queue/tween-config.md#自定义缓动曲线) 支持步骤级原生 `Curve`，可制作回弹与超调效果；运行时独立捕获曲线，Inspector 预览与时间定位使用同一配置快照。
- 新增 [方格视野查询](standard/foundation/grid-spatial/grid-2d-hex/grid-math.md)，通过显式阻挡回调计算有限半径内的可见格，返回稳定顺序与失败诊断；视野不接管地图节点、探索记忆或阵营规则。
- [Tween Inspector 预览](extensions/action-queue/tween-config.md#在-inspector-中预览) 支持时间滑条与秒数定位，可反复检查同一配置快照的中间姿态和动画终点；定位仅操作工具自有样机，并保持暂停。
- [模板列表](standard/utilities/runtime/settings-ui-scene/settings-display/list-repeat-binding.md#按稳定-id-更新模板列表) 支持调用方提供稳定 ID，按条目复用、更新、移动和释放节点，保留普通 Container 布局及未被项目回调重置的局部交互状态。
- 新增 [2D 多目标取景 Rig](extensions/camera/camera-2d.md#多目标共同入镜)，根据目标锚点、实际相机输出尺寸和像素留白计算中心与缩放，复用现有 Director 的优先级与混合，并报告缩放约束是否影响共同入镜。
- 新增 [Network 请求与回复关联](extensions/network-turnbased/network-transport/request-correlation.md)：独立的有界 Tracker、一次性 Handle 和隔离响应结果，支持同步回包、指定 peer 与会话隔离、超时及本地取消；协议编码与网络生命周期由项目显式接入，`gf.network` 的 `extension_version` 升为 `7.1.0`。
- 新增 `GFObjectPoolAcquireResult` 与 `GFObjectPoolLease`。成功借用取得独立使用权，归还立即失效，`wait_settled()` 可重复等待实际离树或淘汰完成。
- 节点根脚本可实现同步 `on_gf_pool_prepare(context) -> Error`，在每次入树前准备本次数据；空闲实例完全离树。
- 新增 `GFProjectileEmissionResult`，用单次 `await` 的返回值表达整批发射结果。
- 新增 [Scene Groups 场景组查询](editor/tools/scene-groups.md)。从已保存的 `.tscn` / `.scn` 查找持久化 Group 声明，支持搜索、分页和来源节点定位；扫描取消、读取失败或预算耗尽时明确报告结果不完整。
- 新增 [3D 场景摆放](editor/tools/scene-placement.md)：显式选择 PackedScene 与父 Node3D，在原生 3D 视口中进行平面或碰撞表面拾取，支持切向网格、法线、锚点、线框代理预览与单实例 Undo / Redo。
- [Flow 图编辑器](extensions/flow/editor-model.md) 的连线、删除节点与布局编辑接入 Godot 撤销/重做，删除节点时一并恢复关联连接与布局，一次拖动对应一次编辑动作。
- [Resource 表格](editor/resource-table-editor.md) 支持多行选择、属性混合值呈现和暂存编辑；应用时只修改实际编辑的分量，取消或切换选择会丢弃暂存输入。
- [配置跨表引用](standard/utilities/io/config-remote-outbox/config-provider/relations-builds/indexes-references.md#数组元素引用) 支持逐项校验一维 Array 中的标量键；错误保留原字段名、元素位置和值，导表继续附加可用的来源与单元格位置。
- [配置化 Tween](extensions/action-queue/tween-config.md#在-inspector-中预览) 新增 Inspector 预览，支持独立 2D、UI、3D 样机、初值调整、播放、暂停、停止和复位；复用现有配置与缓动，预览不修改当前场景或源资源。

### 🔄 机制更改 (Changed)

- [Storage 读取结果](standard/utilities/io/storage-snapshot/storage-utility.md) 减少隔离副本的中转深复制，迟到结算诊断只读取失败分类；保留结果归一化、来源授权及公开 getter 与信号的副本行为。
- [3D 场景摆放](editor/tools/scene-placement.md) 确认失败时显示具体原因与排查建议，并保留原始原因标识和错误码，便于区分父节点失效、实例创建失败及撤销记录被拒绝等情况。
- [调试指标序列](standard/utilities/runtime/debug-observability/debug-visual-inspection/debug-overlay.md) 的 sparkline 只归一化实际显示的最新采样，减少长窗口的绘图开销；统计与归一化范围仍使用全部保留采样。
- 补充 [2D 噪声场](standard/foundation/grid-spatial/noise-field-tools.md#分块采样与共享边缘) 的世界坐标分块与共享归一化范围示例，说明如何保持公共边缘一致，以及逐块归一化为何可能产生接缝。
- [缩略图渲染](editor/non-destructive-live-preview.md) 默认使用静态预览副本，避免复制项目脚本、持久化信号连接和场景组；需要脚本自绘的工具须显式选择可信动态预览，并负责预览脚本的副作用。
- 对象池统一在主线程安全点挂载、离树和清理。节点自己的 `_enter_tree()` / `_exit_tree()` 负责进入与退出生命周期，池不再递归改写节点处理、物理、可见性或 Controller 事件开关。
- 预热统一为 `await prewarm(scene, count, batch_size, cancellation_token)`，只分批实例化离树缓存，不触发入树生命周期，也不执行 prepare。
- 弹幕以整批借用完成后再绑定本次生命周期，使用 Lease 归还；`gf.combat` 的 `extension_version` 升为 `4.0.0`。
- 普通音效使用音频服务自己的播放器缓存，保留同步播放和现有音频 Handle 接口，不依赖异步节点对象池。
- Workspace 向需要编辑的贡献页面注入通用编辑器上下文，并在页面移除时撤销。独立创建的 Flow 面板须显式提供上下文后才能修改图资源；`gf.flow` 的 `extension_version` 升为 `4.0.0`。

### 🐛 Bug 修复 (Fixed)

- 修复 NodeContext 将正常跨帧关闭误判为失效的问题；强制销毁会终止旧关闭遍历，扩展设置保存失败会保留明确的失败提示。
- 修复状态机、任务组、输入序列、触控、拖放、平台初始化、UI、音频、行为树、Buff 与网络接管在同步回调重入后继续使用旧状态的问题；旧注册 token、句柄和绑定不能影响新一轮实例。
- 修复 Asset、HTTP、Job 和 Storage 通知中的取消与结果归属，以及日志批次确认、活跃日志保留、诊断 provider 和调试观察器的生命周期处理。
- Save 与 Dialogue 的可恢复数据使用明确的编解码完整性结果，预算耗尽、循环或不支持的值不会作为成功快照提交；Save 属性恢复先检查完整白名单，回滚保留采集时的引用根。
- Flow 的节点与 Context 在同步执行中共享当前运行态，交替写入、清空和恢复不会被旧快照覆盖；有向图连接拒绝方向反转的端口。Inventory 的全量添加失败保持原槽位，Feedback 的容量淘汰不会追逐回调中新建的播放。
- 修复循环单字段 schema、超大 Deque 请求、字幕空结束时间、标签恢复与层级计数、投影键和默认值，以及大额定点加减和显示精度边界。
- 修复四叉树无进展分裂、空间查询预算回退与闭边界候选、RegionMap 删除标记、单 tile WFC 邻接验证，以及浮力法线在剪切变换下的计算。
- 修复配置合并覆盖原键、验证预算丢失错误、Config Pipeline 跳过 warning、嵌套目录约束、LSP 编辑的读取预算和精确路径大小写、生成脚本符号冲突，以及工具报告来源和取消提示。
- 修复生成文档事务在中断时的回滚、无语言围栏解析、显式缺失样例目录和 schema 注释校验；验证输入检测捕获期间的文件漂移，库存枚举在收集时执行预算检查，文件门禁拒绝阻塞式特殊文件替换。AI Developer 的快照输出、计划读取及反馈提交重新核验对应边界。

- [Modal 聚焦回调](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/modal-protocol.md) 转交焦点后保留面板内的有效目标；同一面板关闭后重开会终止旧聚焦与打开通知。[焦点顺序](standard/utilities/runtime/settings-ui-scene/settings-display/control-focus-order.md) 的零步查询在当前控件失去资格时返回空，不再意外选中其他控件。
- [Modal 自动聚焦](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/modal-protocol.md) 跳过隐藏祖先、递归焦点禁用、禁用按钮和待释放目标；打开聚焦在面板显示后执行，返回值与实际焦点修正一致，并在聚焦回调关闭或替换面板时停止原目标遍历。
- 静态缩略图保留九宫格边距、3D 绘制标志、灯光参数及 Mesh 表面材质覆盖，读取节点名称时也不触发来源脚本；MeshLibrary 任一待生成条目失败时整项计划失败并保留条目原因，避免应用部分预览。
- 配置数组在类型转换前的元素准入也受共享预算约束，非法记录消耗已预留额度，超限时不扫描数组或批量生成逐元素诊断。
- 缩略图视口在 Compatibility 渲染器下不再请求引擎尚不支持的 2D MSAA，避免每次预览产生警告；其他渲染器保留现有抗锯齿设置。
- 开启类型转换后，声明了元素规则的数组会在记录深复制前拒绝嵌套或自引用元素并报告原始下标，避免提前触发脚本栈上限；自定义字段与元素规则的公开上下文集合保持相互隔离。
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

- `GFVariantJsonCodec` 新增 `variant_to_json_compatible_result()` 与 `json_compatible_to_variant_result()`，返回 `{ok, value, error}`；诊断投影入口继续表达不同的输出用途。`GFDialogueContext.deserialize_values()` 返回 `bool`，失败保持原值。
- `GFSpatialHash3D.can_query_aabb()` 提供不生成候选列表的查询准入检查，空间查询 facade 在哈希预算不足时使用线性查询。
- `GFPlatformAdapter` 首次注册后冻结身份和契约配置；自定义输入序列 runtime 必须提供单调的 action edge revision。`GFNetworkBackend` 新增 protected `_reset_transport_connection()` 供传输层先提交断开状态。
- Config Pipeline 的生成 manifest 升为格式 2，并绑定验证摘要；有 warning 的输出重新验证。Content 自动导出合并同一物理文件的资源引用，在 `metadata.references` 保留逻辑引用列表。

- `GFSpatialCanvas2D` 新增 `set_selected_item_outlines_visible()` 与 `are_selected_item_outlines_visible()`；默认开启，支持入树前配置，切换不改变选择状态或选择信号。
- 新增 `GFStorageUtility.query_catalog()` 与不可变 `GFStorageCatalogResult`，提供 Error、失败阶段、排序文件副本及范围内完整性；查询保留同步 drain 和全 root 恢复，不改变存储格式，也不提供 payload revision。
- `GFConfigTableColumn` 新增 `element_validation_rules`，仅用于 `ValueType.ARRAY`；原有 `validation_rules` 继续接收整个字段。`GFConfigTableSchema` 新增每次验证共享的元素数与元素规则调用预算，定义自检、复制、构建过滤及编辑器描述同步支持元素规则。
- `GFThumbnailRenderRequest` 新增 `PreviewMode`，Node3D / CanvasItem 请求和渲染便捷方法增加末尾可选模式参数，默认 `STATIC`；`TRUSTED_DYNAMIC` 用于工具自有的受控脚本预览。
- `GFInputPulseTrigger` 新增 `initial_delay_seconds`，默认 `-1` 沿用 `interval_seconds`，`0` 表示激活当次触发一次。激活时已发出脉冲才忽略当次 delta；每次更新最多返回一个脉冲，不补发跨过的多个周期，也不改变动作开始事件的状态转换语义。
- 新增 `GFGridVisibilityMath2D.compute_fov()`，显式接收网格范围、观察格、半径和遮挡规则；输入或查询失败时返回空的可见集合，保留既有两点视线查询合同。
- `GFRepeaterBinder` 的模板同步支持 `identity_callable`，新增 `sync_container()` 提供结构化同步结果；自动刷新失败通过 `synchronization_failed` 通知。稳定 ID 更新验证重复键、克隆所有权和同步重入，不把项目回调副作用作为可回滚事务。
- 新增 `GFCameraFramingRig2D`。2D Rig 的 `get_camera_pose()` 和 `get_camera_pose_data()` 增加可选 `Camera2D` 参数，Director 显式提供目标相机；自定义覆盖需要同步签名，`gf.camera` 的 `extension_version` 升为 `3.0.0`。
- `GFObjectPoolUtility.acquire(scene, parent, lifetime_owner, context = {})` 现在需要 `await`，返回 `GFObjectPoolAcquireResult`；必填的 `lifetime_owner` 通常传 `self`，与挂载父节点分离。成功后用 `get_lease()` 获取 Lease，再以 `get_node()` 访问节点。
- `pool.release(node, scene)` 改为 `lease.release()`。首次归还返回 `true`，此时 `get_node()` 已返回 `null`；等待离树请使用 `await lease.wait_settled()`。
- `prewarm()` 不再接收父节点，返回 `GFObjectPoolPrewarmResult`；结果包含最终状态、原因、请求数与实际创建数，取消不会回滚已缓存实例。
- 同名 `GFObjectPoolPrewarmResult` 的状态、原因与计数接口也有破坏性调整；`COMPLETED` 改为 `SUCCEEDED`，容量拒绝合并为 `PARTIAL`，池销毁合并为 `CANCELLED`。旧原因常量和细分计数不再保留，详见对象池指南的迁移表。
- 删除弹幕旧同步单发/多发入口与直接节点返回值，统一使用 `await emit_pattern()` 返回 `GFProjectileEmissionResult`。移除 `use_object_pool` 开关和 Emitter 预热包装；需要复用时设置 `object_pool_utility`，预热直接调用池。
- `dispose()` 立即拒绝新借用并撤销所有 Lease，清理在安全点执行；需要等待时调用 `await pool.wait_disposed()`。该等待包含已接纳请求与 Lease 的终态通知，不保证引擎已完成 `queue_free()`。注册到架构的池参与正常异步关停与替换的静默期等待。
- 保留已有接口的首次发布 `@since` 版本，不因本次签名或语义重做而改为 `unreleased`。
- Flow 面板与 Resource 表格新增 `set_editor_context()`。新增 `GFEditorMultiPropertyField`，通过暂存值生成属性批处理请求，提交仍复用既有命令与资源历史；不改变 Flow 图的持久化格式或运行时执行协议。
- `GFConfigTableReference` 新增 `SourceMode` 与 `source_mode`，默认 `FIELDS` 保持原有字段引用行为；`ARRAY_ELEMENTS` 校验单个数组字段到目标单字段键的引用。元素问题增加零基 `element_index`；`resolve_record_references()` 仍只解析 `FIELDS` 引用。
- `GFTweenActionStep` 新增可选 `easing_curve: Curve`；为空时保留既有预设缓动，设置后使用经校验的独立曲线覆盖 transition/ease。`duplicate_step()` / `duplicate_config()` 深复制有效曲线，无效曲线使复制返回 `null` 并警告。`gf.action_queue` 的 `extension_version` 升为 `2.5.0`，包含编辑器预览、指定时间定位与自定义曲线。

### 📘 升级指南 (Migration Guide)

1. 给节点借用与弹幕发射调用增加 `await`；节点借用的第三个参数必须传接收方 `lifetime_owner`（通常是 `self`），初始化数据移到第四个参数。检查结果成功后再使用节点或 Session。不要保留旧 Task 或监听已移除的预热 Operation 信号。
2. 每次借用保存对应 Lease，用 Lease 归还，不再用节点引用作为回收凭证。归还后立即停止访问此前保存的裸节点引用。
3. 将 `before_add` 和旧池启停钩子的每次初始化迁到根节点的 `on_gf_pool_prepare(context)`；进入/退出时的注册与清理由 Godot 生命周期负责。`_ready()` 默认只执行首次，不能当成每次借用的初始化。
4. 把旧预热调用改成 `await pool.prewarm(scene, count)`；预热阶段不再要求业务父节点。池需要保留到使用结束，独立使用时显式调用 `dispose()`，注册到架构后由正常异步关停流程清理。
5. 若节点有 Timer、Tween、异步任务或外部信号，项目脚本必须在退出时取消本轮任务或检查本轮 Lease，防止旧回调影响下一轮。离树不是任意外部工作的自动取消器。
6. 独立创建 Flow 面板的编辑器插件须调用 `set_editor_context(GFEditorToolContext.from_plugin(self))`；通过 Workspace 挂载的面板由工作区自动注入。没有有效撤销管理器时面板仅查看，不再直接修改资源。Resource 表格的新多选编辑入口同样需要上下文，原有显式 `commit_*` 调用方式保留。
7. 自定义 2D Rig 的 `get_camera_pose` / `get_camera_pose_data` 覆盖增加 `camera: Camera2D = null`，调用父类时转交该参数。多目标取景的独立调用也必须提供实际相机；不要用 Rig 所在视口尺寸代替相机输出尺寸。
8. 模板列表选项改为闭合字段及类型校验；移除传入 `options` 的业务附加字段。每次同步最多 4096 项；稳定 ID 模式要求 `clear_existing=true`。未提供 ID 时继续重建副本，大量长列表使用既有虚拟列表机制。
9. 检查已有缩略图调用：依赖 `_draw()` 或脚本初始化的预览专用节点须显式选择 `GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC`，并确保脚本只操作工具自有节点与资源。普通资源缩略图沿用默认静态模式，具体支持范围见[预览指南](editor/non-destructive-live-preview.md)。
10. 存档与会话恢复检查 codec 结果的 `ok`，不要用 `value == null` 判断失败；自定义 `GFDialogueContext.deserialize_values()` 覆盖同步返回 `bool`。Save 中已经移除的属性须由项目迁移清理，属性恢复不再忽略白名单之外的字段。
11. 自定义行为树节点覆盖 `reset()` 时调用 `super.reset()`，使旧 tick 失效。平台 adapter 改配置时创建新实例；自定义输入序列 runtime 按[序列协议](standard/input-flow/input-assist/input-modifiers-triggers.md)提供边沿 revision，不再用帧内布尔值模拟独立边沿。
12. Config Pipeline 的 v1 manifest 不走兼容读取。按[导出说明](editor/tools/config-pipeline.md)核对 profile、输出与 manifest 路径，仅移除对应生成 manifest 后重新导出。Content 导出中被合并的物理条目从 `metadata.references` 读取全部逻辑资源引用；未合并条目仍直接使用原有元数据字段。
13. `MultiplayerPeer` 替换若被断开回调中的另一次接管打断，返回 `ERR_BUSY`；调用方仍负责未被接管的 peer。可选 Network 字段的显式 null 也必须满足 `allow_null`，不能以 `required=false` 绕过。

详细示例见[对象池](standard/utilities/runtime/time-signal-pool/object-pool.md)与[弹幕](extensions/combat/projectiles.md)。已发布历史仍可从对应版本 tag 和 Release 查看。
