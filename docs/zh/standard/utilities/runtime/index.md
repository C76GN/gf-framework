# 运行时服务与调试

本组文档覆盖标准库中需要生命周期、运行时状态、场景协作或开发期观测的 Utility。它们通常注册进 `GFArchitecture`，并由架构统一初始化、tick 或释放。

## 阅读入口

- [时间、信号与对象池](time-signal-pool/index.md)：逻辑计时、时间缩放、信号连接、节点对象池。
- [设置、UI、场景与表面查询](settings-ui-scene/index.md)：设置应用、UI 栈、场景切换、节点树操作、表面查询和 Shader 参数 profile 总览。
- [设置与显示应用](settings-ui-scene/settings-display/index.md)：设置定义、持久化、显示应用和表单控件绑定。
- [UI 栈、路由、视口与文本辅助总览](settings-ui-scene/ui-stack-routing/index.md)：UI 栈、路由、分屏视口、文本适配、富文本和节点树操作的分层边界。
- [UI 面板栈与 Modal 协议](settings-ui-scene/ui-stack-routing/ui-stack-modal/index.md)：面板层级、异步加载、dismiss、焦点辅助和 Modal 结果协议。
- [UI 路由与导航历史](settings-ui-scene/ui-stack-routing/ui-router.md)：route id 到面板场景的映射、路由参数和轻量返回历史。
- [视口、文本与节点树工具](settings-ui-scene/ui-stack-routing/viewport-text-node-tools/index.md)：分屏视口、文本适配、富文本格式化和节点树操作。
- [场景与流程切换](settings-ui-scene/scene-flow/index.md)：场景切换、Loading 过渡、预加载缓存、场景参数和瞬态模块清理。
- [3D 表面材质查询](settings-ui-scene/surface-query.md)：碰撞 face 到 Mesh surface 或材质的查询。
- [Shader 参数 Profile](settings-ui-scene/shader-parameter-profile.md)：ShaderMaterial uniform 接口快照、参数契约、合并、插值、批量写入和场景绑定。
- [音频管理](audio/index.md)：背景音乐、音效、环境音、音频片段、音频 Bank 和可插拔后端。
- [调试、日志、诊断与控制台](debug-observability/index.md)：开发期观测、运行时日志、诊断、支持报告、通知和控制台总览。
- [调试可视化、运行时检查与信号诊断](debug-observability/debug-visual-inspection/index.md)：DebugDraw、Overlay、运行时调参和信号探针。
- [随机种子、日志、构建信息与诊断总览](debug-observability/runtime-telemetry/index.md)：随机流复现、结构化日志、构建信息和诊断快照的分层边界。
- [随机种子与可复现随机流](debug-observability/runtime-telemetry/seed-utility.md)：全局种子、主 RNG 状态和按标签派生的分支随机流。
- [响应式状态与控件绑定](reactive-state.md)：状态树、路径订阅、dirty queue、控件双向绑定和自动解绑。
- [Runtime Agent Environment](agent-environment.md)：默认关闭的 endpoint/session 协议、严格 Schema、短期凭据、限流、防重放、策略检查与无载荷审计。
- [结构化日志与日志 Sink](debug-observability/runtime-telemetry/log-utility/index.md)：分级日志、本地文件、内存缓存、JSONL sink 和批量 sink。
- [构建信息与诊断快照](debug-observability/runtime-telemetry/build-diagnostics/index.md)：构建信息、诊断命令、信号图、监控预设和工具快照。
- [支持报告与通知队列](debug-observability/support-notifications/index.md)：支持报告数据聚合和通用通知队列。
- [运行时开发者控制台](debug-observability/developer-console/index.md)：运行时调试命令、日志输出和控制台窗口。

## 使用边界

- 纯算法和纯数据结构应放在 [Foundation 基础能力](../../foundation/index.md)。
- 文件、资源、存储和远程请求见 [资源、存储与 IO](../io/index.md)。
- 输入、状态机、序列和流程控制见 [输入、流程与玩法支撑](../../input-flow/index.md)。
