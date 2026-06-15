# GF Framework

**Godot 4 轻量级架构框架：关注点分离、生命周期管理、事件驱动、标准库与可选原子扩展生态。**

GF Framework 用一套清晰的运行时架构，把游戏项目中的数据、规则、表现、服务和纯算法拆开管理。它不替代 Godot 场景树，而是让场景树继续负责输入、显示、节点和引擎能力，让核心逻辑拥有可测试、可诊断、可组合的生命周期。

## 核心理念

- **逻辑与表现分离**：核心规则放在 `GFSystem`，状态放在 `GFModel`，Godot 节点和 UI 通过 `GFController` 桥接。
- **生命周期可控**：`GFArchitecture` 统一推进 `init()`、`async_init()`、`ready()` 和 `dispose()`，并支持 Installer、局部架构和依赖诊断。
- **通信边界明确**：强类型事件、simple 事件、命令、查询和规则对象分别服务不同粒度的模块协作。
- **工具层稳定**：需要生命周期、缓存、异步或运行时状态的能力放入 `GFUtility`；纯算法、纯数据和纯格式化留在 `standard/foundation`。
- **扩展能力可选**：Capability、Save、Combat、Network、Flow、ActionQueue 等通用能力以 GF 内置原子扩展形式随框架发布；跨扩展组合留给项目代码或独立插件。

## 文档入口

- [入门总览](overview/index.md)：快速开始、项目实践建议和下一步阅读路线。
- [快速开始](overview/quickstart/index.md)：安装、`Gf` AutoLoad、最小示例和 Installer。
- [Kernel 架构容器](kernel/index.md)：`GFArchitecture`、模块注册、依赖查询、事件、工厂和调试快照。
- [Standard 标准库总览](standard/index.md)：基础算法、输入流程、资源存储、运行时服务和调试工具。
- [GF 内置扩展总览与扩展规范](extensions/index.md)：manifest、启用状态、扩展 Installer、导出排除和内置扩展清单。
- [编辑器工具、访问器与项目常量](editor/index.md)：GF 插件、扩展管理器、Inspector、工作区页面、导出插件和代码生成。
- [项目实践建议](overview/best-practices/index.md)：项目落地时的分层、依赖、生命周期和测试建议。
- [FAQ](faq.md)：安装、使用边界、文档生成和扩展协作的常见问题。
- [参考资料](reference/index.md)：API Reference、版本变更和查阅型资料入口。
- [API Reference](reference/api/index.md)：从源码 API 注释生成的类、属性、信号和方法签名。
- [更新日志](changelog.md)：当前发布版本的变更摘要、API 变化和迁移提示。

## 源码结构

```text
addons/gf/
  kernel/              # 运行内核、基础契约、架构容器、事件、绑定、扩展基础设施、核心编辑器装配
  standard/            # 稳定标准库：foundation、input、utilities、state_machine、sequence 等
  extensions/          # 随 GF 发布的可选原子通用扩展
```

判断归属时遵循三条规则：

- 支撑 GF 启动与基础契约的内容进入 `kernel`。
- 足够稳定、通用、默认随框架理解的能力进入 `standard`。
- 通用但不是所有项目都需要的能力进入 `extensions`；项目组合和第三方扩展放在项目代码或 `addons/gf` 外的独立插件中。
- 如果多个扩展需要同一份稳定机制，优先抽到 `standard`；如果只是具体玩法、内容、流程或跨扩展编排，应留在项目层或独立插件中。

## 能力地图

Kernel：

- [生命周期、装配与依赖](kernel/lifecycle/index.md)
- [消息、事件、命令与查询](kernel/messaging/index.md)
- [场景桥接、Controller 与数据绑定](kernel/scene-controller/index.md)

Standard：

- [Foundation 基础能力](standard/foundation/index.md)
- [资源、存储与 IO](standard/utilities/io/index.md)
- [运行时服务与调试](standard/utilities/runtime/index.md)
- [输入、流程与玩法支撑](standard/input-flow/index.md)

Extensions：

- [Capability](extensions/capability/index.md)
- [Interaction](extensions/interaction/index.md)
- [Feedback](extensions/feedback/index.md)
- [Combat](extensions/combat/index.md)
- [ActionQueue](extensions/action-queue/index.md)
- [Network 与 TurnBased](extensions/network-turnbased/index.md)
- [Flow](extensions/flow/index.md)
- [Decision](extensions/decision/index.md)
- [Domain](extensions/domain/index.md)
- [Physics](extensions/physics/index.md)
- [Save 场景存档图](extensions/save-graph/index.md)
- [BehaviorTree](extensions/behavior-tree/index.md)

## 常用入口

- `Gf`：全局 AutoLoad 入口，默认路径为 `res://addons/gf/kernel/core/gf.gd`。
- `GFArchitecture`：运行时容器，负责模块注册、依赖查询、事件派发、工厂和生命周期。
- `GFInstaller`：项目或扩展的集中装配入口。
- `GFNodeContext`：场景树中的局部架构上下文。
- `GFAccessGenerator`：强类型访问器生成器。
- `GF Workspace`：独立编辑器工作区，固定提供扩展管理、输入映射、信号诊断和诊断快照等基础页面；SaveGraph、Flow 等页面由对应可选扩展启用后贡献。
