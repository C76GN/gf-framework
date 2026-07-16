# 五层职责

GF 项目通常按 Foundation、Model、System、Controller 和 Utility 组织核心代码。每层应保持稳定职责，不要因为调用方便而互相穿透。

`GFConfig` 是承载只读、可编辑器序列化数据的 `Resource` 基类，不是第六种架构模块，也不参与 Model / System / Utility 生命周期。项目可以用它表达难度、模式或关卡等通用配置，再由明确的 System 或 Utility 读取；需要可执行策略时使用规则对象，不要把运行时副作用写进配置资源。

## 阅读入口

- [Foundation](foundation.md)：纯值对象、纯算法和纯格式化工具。
- [Model 与 System](model-system.md)：核心数据状态和纯代码业务流程中心。
- [Controller 与 Utility](controller-utility.md)：场景桥接和通用运行时服务。

## 使用边界

五层分工用于保持依赖方向清晰。信息流方向详见 [信息流方向](../information-flow.md)。
