# GF 扩展总览与扩展规范

GF 内置扩展是随框架分发的可选原子能力。它们提供可以独立启用的通用模块；项目组合、第三方 SDK、业务适配和跨扩展编排应放在项目代码或 `addons/gf` 外的独立 Godot 插件中。

扩展层位于 `kernel <- standard <- extensions` 的最外侧。扩展可以依赖 `kernel`，也可以按需依赖稳定的 `standard` 能力；`kernel` 和 `standard` 不能反向识别、探测或弱绑定具体扩展。

## 阅读入口

- [扩展目录结构](extension-layout.md)：扩展根目录、扩展内部槽位和目录命名原则。
- [Manifest 规范](manifest/index.md)：`gf_extension.json` 字段、版本、依赖、路径贡献和 manifest 校验。
- [安装与装配](installation.md)：扩展启用状态、Installer、项目设置和运行时装配顺序。
- [编辑器扩展管理器](editor-manager.md)：GF Workspace 扩展面板、编辑器贡献、引用审计和导出排除。
- [放置规则](placement-rules.md)：新增能力进入 `kernel`、`standard`、内置扩展、项目代码或独立插件的判断方式。

## 使用边界

- GF 内置扩展彼此不互相依赖，不声明隐式协作关系，也不通过路径、扩展 ID、`class_name` 或动态加载探测其他内置扩展。
- 内置扩展 manifest 的 `dependencies` 只允许声明 `gf.kernel` 与 `gf.standard`。
- 需要多个扩展协作时，在项目 Installer、项目 System 或独立插件中组合，不把组合逻辑写回任一内置扩展。
- 标准库工具需要扩展数据时，由扩展侧通过标准库提供的通用注册入口主动贡献；标准库不写扩展路径、扩展 ID 或扩展内类型名。

## 扩展清单

- [Capability](capability/index.md)：对象能力、动态属性、能力 Recipe、节点能力和访问器生成。
- [Interaction](interaction/index.md)：交互上下文、传感器、接收器和交互流程。
- [Feedback](feedback/index.md)：震动、闪烁、通知、拖放和指针反馈。
- [Camera](camera/index.md)：2D/3D Rig、Director、Blend 和相机候选选择。
- [Dialogue](dialogue/index.md)：对话资源、运行器、上下文和响应选择。
- [Combat](combat/index.md)：战斗属性、技能、Buff、命中盒、投射物和统一命中结果。
- [ActionQueue](action-queue/index.md)：可排队视觉动作、Tween 动作、拦截器和动作工厂。
- [Asset Metadata](asset-metadata/index.md)：资产 metadata 读写、收集、导入扩展和报告。
- [Network 与 TurnBased](network-turnbased/index.md)：网络消息、快照、后端协议、回合阶段和行动流。
- [Flow](flow/index.md)：资源化流程图、节点、端口、运行器和编辑器模型。
- [BehaviorTree](behavior-tree/index.md)：纯代码行为树节点、Runner、黑板和调试快照。
- [Decision](decision/index.md)：黑板、上下文、效用评分、候选集合和非 LLM 决策服务。
- [Content Package](content-package/index.md)：内容包 manifest、依赖图诊断和资源键注册。
- [Domain](domain/index.md)：关卡、任务、背包、装备和通用领域模型。
- [Physics](physics/index.md)：Projectile、重力场、表面查询和运动策略。
- [Save 场景存档图](save-graph/index.md)：Scope、Source、Pipeline、Slot 和存档图应用流程。

## API Reference

各扩展入口页链接对应生成式 API Reference；总索引见 [API Reference](../reference/api/index.md)。
