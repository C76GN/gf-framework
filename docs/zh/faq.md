# FAQ

## GF 是游戏框架还是一组工具类？

GF 是面向 Godot 项目的轻量架构框架。它提供启动装配、模块生命周期、事件、命令、查询、数据绑定、标准库工具和可选扩展，目标是让项目代码有稳定的分层和组合方式，而不是只提供零散 helper。

## GF 会替代 Godot 的节点和场景系统吗？

不会。GF 负责架构层、数据流和通用能力边界；Godot 的节点、场景、资源、信号、物理和渲染仍然是项目的主要运行环境。通常做法是让 GF 的 Model/System 保存状态和流程，让 Controller、节点脚本或场景资源负责具体表现。

## 什么时候使用 kernel、standard 或 extensions？

`kernel` 只承载框架启动、生命周期、注册、依赖、事件、命令、查询、绑定和扩展基础设施。`standard` 放稳定通用能力，例如 Foundation、输入、状态机、资源、存储、时间、日志、诊断和音频。`extensions` 放可选通用能力，例如 Capability、Save、Combat、Network、Flow、Domain、BehaviorTree、Camera 和 Dialogue。

## 我需要启用所有 GF 内置扩展吗？

不需要。GF 内置扩展按能力拆分，可以按项目需要启用。扩展之间保持原子化，不把其他扩展当作隐藏依赖；如果项目需要把多个扩展组合成完整玩法，应在项目 Installer 或项目自己的插件中完成组合。

## 项目代码应该放进 `addons/gf` 吗？

不应该。`addons/gf` 是框架源码目录，项目自己的 Model、System、Controller、资源、场景和扩展组合应放在项目目录或独立插件中。这样升级 GF 时不会混入项目业务代码，也能保持框架测试和发布边界清晰。

## 找具体类、属性、信号和方法签名时看哪里？

先读对应指南页理解职责边界和典型组合方式，再查 [API Reference](reference/api/index.md)。API Reference 由源码 API 注释生成，覆盖公开类、属性、信号、枚举、常量和方法签名。

## API Reference 是手写的吗？

不是。生成链路是 `addons/gf/**/*.gd` 源码 API 注释 -> `docs/api_catalog` XML Catalog -> `docs/zh/reference/api` Markdown 页面。正文指南负责解释概念和工作流，API Reference 负责提供可检索的 API 清单。

## GF 当前提供完整项目教程吗？

目前正式文档以职责边界、最小示例和 API Reference 为主，暂不承诺一套从零到完整项目的综合教程。遇到跨模块组合问题时，可以先按下面的边界选型，再进入对应专题页查看可独立复用的示例。

## 3D 场景怎样与 GF UI 组合？

GF 不替代 Godot 的 `Control` 和 `CanvasLayer`。`GFUIUtility` 会把 HUD、POPUP、TOP 层创建在 `SceneTree.root` 下，适合全局菜单、跨场景提示和只读取全局模块的 HUD；这些 Panel 不会随当前场景自动销毁，其中场景专属 Panel 应在离场时显式清理。

如果 HUD 必须读取某个局部战斗或房间的 Model / System，应把项目自己的 `CanvasLayer` 保留在对应 `GFNodeContext` 子树中，不要通过当前 UI 栈重挂。详见 [面板栈与层级](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/panel-stack.md) 和 [场景级局部上下文](kernel/lifecycle/node-contexts.md)。

## 什么时候应该使用 GFNodeContext？

GF 8 的正式类型名是 `GFNodeContext`，不存在另一个 `GFSceneContext` 类型。普通场景通常直接复用全局 Architecture；只有关卡、战斗房间、测试场景、调试面板或并行实例需要独立模块作用域，并希望随节点树分支统一创建和释放时，才使用 `GFNodeContext.ScopeMode.SCOPED`。

局部 `GFController` 会沿父节点查找最近的 `GFNodeContext`，本地未命中时再回退父级或全局架构。完整生命周期和父链规则见 [场景级局部上下文](kernel/lifecycle/node-contexts.md)。

## 配置表怎样接入 GFConfigProvider？

`GFConfigProvider` 是运行时查询协议，不是 CSV、JSON 或 XLSX 解析器。已有字典、生成表对象或缓存可用 `GFConfigProviderAdapter`；Godot `.tres/.res` 表资源可用 `GFResourceConfigProvider`；需要在制作期或 CI 中导入源表时，再使用可选的 Config Pipeline。

为了让调用方稳定地按抽象类型查询，Installer 中建议调用 `await architecture.register_utility_instance_as(provider, GFConfigProvider)`，并检查取消状态和注册结果。详见 [Provider 适配器](standard/utilities/io/config-remote-outbox/config-provider/provider-schema/provider-adapter.md) 和 [Config Pipeline 导表工具包](editor/tools/config-pipeline.md)。

## 初始化、菜单、主页、战斗和退出流程怎样组织？

`initializing → menu → home → battle / other → exit` 这类流程属于项目策略，GF 不预设状态名、合法转换图或场景路由。需要脱离场景树的应用流程时，通常由长期存在的 `GFSystem` 持有 `GFStateMachine.new(self)`，集中校验切换并推进状态；`GFController` 接收输入和 Godot 回调，再根据状态、事件或绑定结果切换 UI 与场景。

如果状态必须直接操作动画、碰撞、输入节点或 UI 子树，则选择 `GFNodeStateMachine`。两者的选择见 [纯代码状态机与节点状态机总览](standard/input-flow/state-machines/index.md)。

## Model、System、Controller 和 Utility 怎样分工？

`GFModel` 保存核心状态并维护数据一致性；`GFSystem` 处理业务规则、命令、查询和跨模块流程；`GFController` 连接输入、场景节点、UI 和架构；`GFUtility` 提供与具体玩法无关的通用运行时服务。常见方向是 Controller 调用 System，System 修改 Model，Model 通过事件或绑定结果通知 Controller，System 和 Controller 按需调用 Utility。

Model 不应引用 System、Controller 或场景节点；System 不应持有具体 Controller 或节点；Controller 不应保存需要跨场景长期存在的核心状态；Utility 不应写死项目玩法规则。详见 [五层职责](kernel/architecture/module-roles-flow/module-roles/index.md) 和 [信息流方向](kernel/architecture/module-roles-flow/information-flow.md)。
