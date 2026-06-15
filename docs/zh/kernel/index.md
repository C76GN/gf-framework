# Kernel 总览

Kernel 是 GF 的运行内核，负责全局入口、架构容器、生命周期、事件、命令、查询、场景桥接、依赖解析和编辑器基础设施。它只放框架启动与运行所必需的契约和机制，不依赖标准库或可选扩展的具体实现。

## 阅读入口

- [架构容器](architecture/index.md)：`Gf`、`GFArchitecture`、层级边界、装配诊断、五层分工、编辑器访问器和内核基础设施。
- [生命周期、装配与依赖](lifecycle/index.md)：Installer、三阶段初始化、动态注册、局部上下文、工厂、别名和 Controller 初始化。
- [消息、事件、命令与查询](messaging/index.md)：事件系统、命令、查询、规则和命令历史。
- [场景桥接、Controller 与数据绑定](scene-controller/index.md)：`GFController`、System 更新、绑定属性和局部响应式组合。

## 使用边界

需要被 Kernel 直接识别的能力应收敛为内核契约。纯算法和数据结构放入 Foundation；默认稳定服务放入 Standard Utilities；可选原子能力放入 Extensions；项目玩法、SDK 适配和跨扩展组合留给项目代码或独立插件。

## 通用内核工具

`GFPathTools` 提供纯字符串层面的路径规范化、根目录裁剪、路径集合去重、相对路径和排除路径匹配，不访问文件系统，也不解释资源业务语义。它用于让扩展发现、内容包、资源注册表、音频扫描和目录监听共享一致的路径边界判断。

`GFDependencyGraphTools` 提供字符串 ID 依赖图的依赖优先排序、缺失依赖记录和循环路径诊断。依赖 ID 输入会过滤空值、裁剪空白并去重。扩展 manifest、内容包和项目工具可以复用同一套轻量机制，但具体节点类型、启用策略和版本约束仍留在调用方。

`GFProjectSettingsTools` 提供 ProjectSettings 默认值、缺失键初始值和 Inspector 属性信息注册辅助。它只负责稳定声明设置键，不读取业务含义，也不自动保存 `project.godot`；插件、扩展或项目工具仍应自行决定何时保存设置。

## API Reference

完整类、方法和信号列表见 [Kernel API Reference](../reference/api/kernel.md)。
