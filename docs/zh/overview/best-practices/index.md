# 项目实践建议

本组页面给出 GF 项目落地时最容易影响稳定性的规则。它不替代各模块文档；遇到具体 API 细节时，继续查对应指南和 API Reference。

## 阅读入口

- [模块边界](module-boundaries.md)：依赖读取、Model、System 和 Controller 的职责边界。
- [事件与生命周期](events-lifecycle.md)：事件使用条件、监听 owner、四阶段激活、依赖 DAG 和正常关闭。
- [放置、Godot 边界与测试](placement-godot-testing.md)：新增能力归属、Godot 引擎语义边界和测试优先级。

## 总原则

GF 负责组织代码边界、生命周期和模块协作，不替项目决定业务规则，也不接管 Godot 的场景树、输入、物理或渲染语义。
