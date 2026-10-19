# 信息流方向

GF 推荐让数据和调用保持单向、显式和可诊断。Controller 负责连接 Godot 场景树，System 负责业务流程，Model 保存状态，Utility 提供运行时服务，Foundation 提供纯算法和纯数据结构。

这些角色按职责出现，不是每个功能必须创建的文件清单。局部 UI 状态可以留在 Node 或项目会话中；只有出现共享状态、可复用规则或独立生命周期，才引入相应模块。需要集中装配后，再使用[最小启动与 Installer](../../../overview/quickstart/minimal-installer.md)。

Command、Flow 和 Action 保留不同的公开语义：Command 表达一次请求，Flow 表达流程图运行，Action 表达可组合的动作调度。项目按任务选择入口，不用一个通用执行器抹平完成、取消、错误传播和副作用约定。框架内部可以复用经过验证的计时、终态提交等机制，但必须保留每个入口自身的合同与回归测试。

```mermaid
graph TD
	Controller(("Controller
	(Godot Node)"))
	System["System
	(Logic)"]
	Model[("Model
	(Data)")]
	Foundation["Foundation
	(Pure Values/Algorithms)"]
	Utility["Utility
	(Tools/Helpers)"]

	Controller -- 发送事件/命令 --> System
	System -- 修改数据 --> Model
	Model -- 触发事件/绑定变化 --> Controller
	Controller -. 只读查询 .-> Model

	Model -. 使用 .-> Foundation
	System -. 使用 .-> Foundation
	Controller -. 使用 .-> Foundation
	Utility -. 使用 .-> Foundation
	System -. 调用 .-> Utility
	Controller -. 调用 .-> Utility
```

## 推荐方向

- Controller 可以发送事件或命令给 System，也可以只读查询 Model。
- System 可以修改 Model，并通过事件或绑定状态通知 Controller。
- Model 不主动调用 Controller 或 System。
- Utility 提供通用服务，不解释项目业务。
- Foundation 可以被所有层直接使用。

## 避免的方向

- System 直接引用场景节点或 Controller。
- Model 保存 UI、动画节点、临时场景对象或输入状态。
- Foundation 依赖架构容器、事件总线或 SceneTree。
- Utility 为具体玩法写死规则。

这些限制能让核心逻辑脱离场景树测试，也能让 UI、关卡节点和表现层在场景切换时安全销毁。
