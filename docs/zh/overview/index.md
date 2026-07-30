# 入门总览

本组页面帮助你把 GF 放进 Godot 项目、启用 `Gf` AutoLoad、完成最小模块注册，并建立后续阅读路线。

## 阅读入口

- [快速开始总览](quickstart/index.md)：安装、AutoLoad、最小启动和 Installer 的完整路径。
- [安装与 AutoLoad](quickstart/install-autoload.md)：插件放置、启用方式和 `Gf` 全局入口。
- [最小启动与 Installer](quickstart/minimal-installer.md)：手动注册、`Gf.init()` 和项目 Installer。
- [项目实践建议](best-practices/index.md)：项目落地时的模块边界、生命周期、放置规则和测试建议。

## 下一步

- 想理解容器和分层边界：读 [Kernel 架构容器](../kernel/index.md)。
- 想理解 Installer、依赖 DAG、四阶段激活、异步关闭和局部架构：读 [生命周期、装配与依赖](../kernel/lifecycle/index.md)。
- 想写事件、命令和查询：读 [消息、事件、命令与查询](../kernel/messaging/index.md)。
- 想把场景节点、UI 和输入接入 GF：读 [场景桥接、Controller 与数据绑定](../kernel/scene-controller/index.md)。
- 想查具体类、属性、信号和方法签名：读 [API Reference](../reference/api/index.md)。

## 上手原则

- 纯算法和纯数据优先放在 `standard/foundation` 或扩展内 `foundation`。
- 需要生命周期、缓存、异步、事件或跨模块复用的能力放入 `GFUtility`。
- 具体玩法规则放在项目的 Model / System / Controller 中。
- 可复用但不是所有项目都需要的通用能力，优先作为扩展维护。
