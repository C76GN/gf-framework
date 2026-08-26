# FAQ

## 按主题查找

- 框架定位、安装边界与文档入口：从 [GF 是游戏框架还是一组工具类？](#framework-boundaries) 开始。
- UI、场景与层级行为：从 [3D 场景怎样与 GF UI 组合？](#ui-and-scenes) 开始。
- 运行时服务、局部上下文与配置：从 [HTTPRequest 是否需要项目自己维护池？](#runtime-services) 开始。
- 项目启动、模块职责与业务数据边界：从 [初始化、菜单、主页、战斗和退出流程怎样组织？](#project-architecture) 开始。
- 支持请求与隐私：见 [提 Issue 时怎样收集场景树信息而不泄露本机路径？](#support-and-privacy)。

## GF 是游戏框架还是一组工具类？ { #framework-boundaries }

GF 是面向 Godot 项目的轻量架构框架。它提供启动装配、模块生命周期、事件、命令、查询、数据绑定、标准库工具和可选扩展，目标是让项目代码有稳定的分层和组合方式，而不是只提供零散 helper。

## GF 会替代 Godot 的节点和场景系统吗？

不会。GF 负责架构层、数据流和通用能力边界；Godot 的节点、场景、资源、信号、物理和渲染仍然是项目的主要运行环境。通常做法是让 GF 的 Model/System 保存状态和流程，让 Controller、节点脚本或场景资源负责具体表现。

## 什么时候使用 kernel、standard 或 extensions？

`kernel` 只承载框架启动、生命周期、注册、依赖、事件、命令、查询、绑定和扩展基础设施。`standard` 放稳定通用能力，例如 Foundation、输入、状态机、资源、存储、时间、日志、诊断和音频。`extensions` 放可选通用能力，例如 Capability、Save、Combat、Network、Flow、Domain、BehaviorTree、Camera 和 Dialogue。

## 我需要启用所有 GF 内置扩展吗？

不需要。GF 内置扩展按能力拆分，可以按项目需要启用。扩展之间保持原子化，不把其他扩展当作隐藏依赖；如果项目需要把多个扩展组合成完整玩法，应在项目 Installer 或项目自己的插件中完成组合。

## 怎样完整卸载 GF？

不要在插件仍启用时直接删除 `addons/gf`。先清理项目引用并禁用插件，让 GF 对称移除自己登记的 AutoLoad；再关闭编辑器、删除文件并重新验证项目。完整的状态保留、GF 10 遗留状态和失败恢复步骤见[卸载、清理与恢复](overview/quickstart/uninstall.md)。

## 项目代码应该放进 `addons/gf` 吗？

不应该。`addons/gf` 是框架源码目录，项目自己的 Model、System、Controller、资源、场景和扩展组合应放在项目目录或独立插件中。这样升级 GF 时不会混入项目业务代码，也能保持框架测试和发布边界清晰。

## 找具体类、属性、信号和方法签名时看哪里？

先读对应指南页理解职责边界和典型组合方式，再查 [API Reference](reference/api/index.md)。API Reference 由源码 API 注释生成，覆盖公开类、属性、信号、枚举、常量和方法签名。

## API Reference 是手写的吗？

不是。生成链路是 `addons/gf/**/*.gd` 源码 API 注释 -> `docs/api_catalog` XML Catalog -> `docs/zh/reference/api` Markdown 页面。正文指南负责解释概念和工作流，API Reference 负责提供可检索的 API 清单。

## GF 当前提供完整项目教程吗？

目前正式文档以职责边界、最小示例和 API Reference 为主，暂不承诺一套从零到完整项目的综合教程。遇到跨模块组合问题时，可以先按下面的边界选型，再进入对应专题页查看可独立复用的示例。

## 3D 场景怎样与 GF UI 组合？ { #ui-and-scenes }

GF 不替代 Godot 的 `Control` 和 `CanvasLayer`。`GFUIUtility` 会把 HUD、POPUP、TOP 层创建在 `SceneTree.root` 下，适合全局菜单、跨场景提示和只读取全局模块的 HUD；这些 Panel 不会随当前场景自动销毁，其中场景专属 Panel 应在离场时显式清理。

如果 HUD 必须读取某个局部战斗或房间的 Model / System，应把项目自己的 `CanvasLayer` 保留在对应 `GFNodeContext` 子树中，不要通过当前 UI 栈重挂。详见 [面板栈与层级](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/panel-stack.md) 和 [场景级局部上下文](kernel/lifecycle/node-contexts.md)。

## GFUIUtility 只有 HUD、POPUP、TOP 三层吗？

不是。它们是默认逻辑层，不是固定上限。项目可以注册 `GFUILayerDefinition`，把逻辑层 ID、`CanvasLayer.layer` 和默认 `hide_under` 策略分开。左右并行窗口应使用独立逻辑层；同栈的非全屏通知可设置 `hide_under = false`，全屏页面或 Modal 保持默认遮挡。详见 [面板栈与可扩展层级](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/panel-stack.md)。

## 自定义 UI Layer 的 ID 更大，为什么仍被 HUD 挡住，也没有自动清掉旧页面？

`layer_id` 只是路由和栈的稳定编号，不参与 Godot 绘制排序。GF 预置 HUD、POPUP、TOP 的 `CanvasLayer.layer` 分别是 50、60、70；自定义资源即使写 `layer_id = 3`，若 `canvas_layer = 3`，仍会画在 HUD=50 下方。需要位于全部预置层之上时可使用大于 70 的绘制值，具体值仍由项目统一规划。

旧 Auth 页面没有自动清理也是预期的层隔离语义。`hide_under` 只隐藏同一逻辑层的下方 Panel，`replace_route()` 也只替换目标 Route 所属的那一层。Login、Auth、GameHome 若是互斥全屏页面，应全部放在同一逻辑层并用 `replace_route()`；若项目有意把 GameHome 放到独立层，则在业务流程中先调用 `clear_layer(old_layer)`。框架不能在跨层打开时自动清 HUD，否则常驻血条、聊天侧栏、弹窗和背包等需要并行存在的 UI 也会被误删。

面板选项中，`mode` 使用 `GFUIUtility.PanelMode.NORMAL` / `MODAL`；`modal = true` 是未显式传 `mode` 时的布尔简写；`metadata` 只是项目自定义数据，框架会复制和透传，但不会用它排序、清层或执行玩法逻辑。详见 [面板栈与可扩展层级](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/panel-stack.md) 和 [UI 路由与导航历史](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-router.md)。

## `GFUIRouterUtility` 查询为 `null` 是接口被删除了吗？

不是。`register_routes()` 仍然存在；`Invalid call ... in base 'Nil'` 表示 Router 实例没有进入当前架构。检查 `gf/project/installers`、`await Gf.init()` 的布尔结果和 `last_initialization_error`，并确认 Installer 注册了 UI 与 Router。完整插件已经包含相关源码，但不会自动把 Utility 注册到项目架构。详见[UI 路由与导航历史](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-router.md)。

## HTTPRequest 是否需要项目自己维护池？ { #runtime-services }

低频请求可以直接用 `GFHttpRequestBuilder.execute()`；并发请求使用 `GFHttpClientUtility`，它提供活动数、等待队列、worker 复用、取消、父节点退出和诊断快照边界。鉴权、重试、分页和业务 DTO 仍由项目或平台 adapter 负责。详见 [HTTP 请求、客户端池与异步批处理](standard/utilities/io/config-remote-outbox/http-async-batch.md)。

## 什么时候应该使用 GFNodeContext？

GF 8 的正式类型名是 `GFNodeContext`，不存在另一个 `GFSceneContext` 类型。普通场景通常直接复用全局 Architecture；只有关卡、战斗房间、测试场景、调试面板或并行实例需要独立模块作用域，并希望随节点树分支统一创建和释放时，才使用 `GFNodeContext.ScopeMode.SCOPED`。

局部 `GFController` 会沿父节点查找最近的 `GFNodeContext`，本地未命中时再回退父级或全局架构。完整生命周期和父链规则见 [场景级局部上下文](kernel/lifecycle/node-contexts.md)。

## 配置表怎样接入 GFConfigProvider？

`GFConfigProvider` 是运行时查询协议，不是 CSV、JSON 或 XLSX 解析器。已有字典、生成表对象或缓存可用 `GFConfigProviderAdapter`；Godot `.tres/.res` 表资源可用 `GFResourceConfigProvider`；需要在制作期或 CI 中导入源表时，再使用可选的 Config Pipeline。

为了让调用方稳定地按抽象类型查询，Installer 中建议调用 `await architecture.register_utility_instance_as(provider, GFConfigProvider)`，并检查取消状态和注册结果。详见 [Provider 适配器](standard/utilities/io/config-remote-outbox/config-provider/provider-schema/provider-adapter.md) 和 [Config Pipeline 导表工具包](editor/tools/config-pipeline.md)。

## 初始化、菜单、主页、战斗和退出流程怎样组织？ { #project-architecture }

`initializing → menu → home → battle / other → exit` 这类流程属于项目策略，GF 不预设状态名、合法转换图或场景路由。需要脱离场景树的应用流程时，通常由长期存在的 `GFSystem` 持有 `GFStateMachine.new(self)`，集中校验切换并推进状态；`GFController` 接收输入和 Godot 回调，再根据状态、事件或绑定结果切换 UI 与场景。

如果状态必须直接操作动画、碰撞、输入节点或 UI 子树，则选择 `GFNodeStateMachine`。两者的选择见 [纯代码状态机与节点状态机总览](standard/input-flow/state-machines/index.md)。

## Model、System、Controller 和 Utility 怎样分工？

`GFModel` 保存核心状态并维护数据一致性；`GFSystem` 处理业务规则、命令、查询和跨模块流程；`GFController` 连接输入、场景节点、UI 和架构；`GFUtility` 提供与具体玩法无关的通用运行时服务。常见方向是 Controller 调用 System，System 修改 Model，Model 通过事件或绑定结果通知 Controller，System 和 Controller 按需调用 Utility。

Model 不应引用 System、Controller 或场景节点；System 不应持有具体 Controller 或节点；Controller 不应保存需要跨场景长期存在的核心状态；Utility 不应写死项目玩法规则。详见 [五层职责](kernel/architecture/module-roles-flow/module-roles/index.md) 和 [信息流方向](kernel/architecture/module-roles-flow/information-flow.md)。

## `boss_defeated`、`tutorial_seen`、`door_opened` 这类跨场景开关放哪里？

先看它是不是“游戏事实”。已经击败 Boss、看过教程、某扇永久门已开启，会影响之后场景和规则判断，应该由全局 Architecture 中的项目 `GFModel` 保存，再由 `GFSystem` 提供修改入口；需要跨重启时，把 Model 的稳定 DTO 交给项目存档聚合层和 `GFStorageUtility`，不要在运行时回写 `res://` 下的声明资源。

只影响当前界面的筛选条件、折叠状态或未提交草稿，可以放 `GFReactiveStateStore`；只在当前关卡有效、离开关卡就应丢弃的机关状态，可以放 scoped `GFNodeContext` 中的局部 Model。也就是说，同样叫“开关”，归属取决于生命周期和业务含义，不需要为它再做一个框架全局单例。参见 [响应式状态与控件绑定](standard/utilities/runtime/reactive-state.md) 和 [场景级局部上下文](kernel/lifecycle/node-contexts.md)。

## 项目有 `.enemy`、`.quest`、`.dialogue` 自定义文本，应该让 GF 在运行时直接解析吗？

通常不应该。更稳妥的流程是“制作期文本 → 项目侧导入器或构建步骤 → 校验后的 Resource/配置数据 → 运行时加载”。例如策划写一份敌人定义，项目的 `EditorImportPlugin` 读取 UTF-8 文本，词法/语法阶段为错误保留 `GFSourceSpan`，把缺字段、错误数字和未知命令汇总进 `GFValidationReport`，成功后生成项目自己的 `EnemyDefinition` Resource；运行时生成敌人时只读取这份已校验资源，不再重复解析原文。

表格型输入可以组合 [Config Pipeline](editor/tools/config-pipeline.md)，对话可以落到 `GFDialogueResource`，任务或敌人字段则继续使用项目自己的 Resource/schema。GF 提供报告、源码位置、配置和领域资源底座，但不会内置一套能理解所有游戏词汇的通用 DSL。项目解析器还应保证遇到坏 token 时能够前进或明确停止，避免导入坏文件时进入死循环；任何会加载脚本或实例化对象的字段都要经过显式 allowlist。

## GF 是否提供车辆控制器或车辆物理？

GF 不提供通用 `VehicleController`，因为街机赛车、履带车、船和写实汽车的动力学差异很大。实际项目中，`VehicleBody3D`、`CharacterBody2D` 或项目自己的物理宿主继续在 `_physics_process(delta)` 里处理连续的油门、刹车、转向、抓地和碰撞；子级 `GFController` 读取 `throttle`、`brake`、`steer` 输入并把意图交给宿主。所有按时间变化的加速度和转向平滑都应使用真实 `delta`，不要使用与 `delta` 无关的固定每帧步长。

`GFNodeStateMachine` 适合组织 `Parked / Driving / Airborne / Wrecked` 这类离散状态，不负责逐物理帧积分。摇杆幅度到输入响应可以使用 [`GFInputCurveModifier`](standard/input-flow/input-assist/input-modifiers-triggers.md)；车速到最大转角通常是车辆项目配置中的 `Curve`。单辆车的即时速度只需由车辆向自己的仪表盘发局部 signal；只有计时、回放、联网同步或存档等跨对象、跨场景流程确实需要稳定快照或领域事件时，才由项目 `GFSystem` 归纳事件，或由 `GFModel` 保存稳定状态，不要把每个物理帧的临时值直接提升为全局状态。参见 [原生物理节点桥接](kernel/lifecycle/controllers/native-physics-node.md) 和 [状态机选型](standard/input-flow/state-machines/index.md)。

## 提 Issue 时怎样收集场景树信息而不泄露本机路径？ { #support-and-privacy }

先限制采集范围，只保留能解释问题的深度和节点数量，并显式开启路径脱敏：

```gdscript
var scene_snapshot: Dictionary = diagnostics.collect_scene_tree_snapshot(null, {
	"max_depth": 4,
	"max_nodes": 256,
	"include_groups": true,
	"redact_paths": true,
})
```

GF Workspace 的 Diagnostics 页面使用本地调试 profile，“复制快照”会保留路径，适合自己排查，不应未经检查直接粘贴到公开 Issue。对外前应使用 `GFReportValueCodec` 的 support/public/privacy profile 导出，或至少像上面一样让场景树采集开启 `redact_paths`；随后仍要人工检查节点名、group、日志和项目自定义诊断字段，因为这些业务文本可能包含账号、关卡代号或用户内容。只附最小复现场景、GF/Godot 版本、错误日志和受限快照，通常比复制整棵场景树更容易定位。详见 [快照与场景树诊断](standard/utilities/runtime/debug-observability/runtime-telemetry/build-diagnostics/diagnostics-commands/snapshot-scene.md)。
