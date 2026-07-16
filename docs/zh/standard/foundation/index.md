# Foundation 基础能力

Standard Foundation 收纳纯算法、纯数据结构、轻量格式化和通用诊断对象。这里的类型不参与 `GFArchitecture` 生命周期，不持有场景树状态，也不解释项目玩法规则。

Foundation 适合被 `standard`、GF 内置扩展、外部扩展和项目代码共同复用。它的价值是稳定、低依赖、可测试，而不是提供运行时服务。

## 阅读入口

- [数值、成长与权重](scalars/index.md)：大数、定点数、数字格式化、成长曲线和权重表。
- [网格、路径与空间索引](grid-spatial/index.md)：2D 曲线与折线、弹簧平滑、规则网格、Hex、图搜索、3D 整数格、Pattern2D、Steering、TileMap 缓存和空间哈希。
- [数据流程与校验](data-validation/index.md)：标签、黑板、通用 Dictionary schema、预算、集合、公式、Variant、通用标识、校验报告和轻量结果字典。
- [平台运行时上下文](platform-runtime.md)：平台能力集合、生命周期事件、运行时上下文和桥接请求/结果，用于 Steam、Web、小游戏、主机或自建平台 adapter 的中立接入。
- `GFPlatformLocaleMap` 提供平台语言 key 到 Godot locale / fallback locale 的纯数据映射，适合 Steam、微信、主机平台或自建启动器 adapter 复用；具体平台映射表应由项目或外部 adapter 提供。

## 使用边界

- 适合放入 Foundation 的能力应当没有生命周期，不需要注册到 `GFArchitecture`。
- Foundation 类型不应持有场景节点、文件句柄、网络请求、线程任务或异步状态。
- 类型表达的应是稳定通用概念，例如数值、坐标、索引、查询条件、校验结果或纯数据转换。
- 需要 `tick()`、缓存、异步加载、ProjectSettings、文件系统或全局状态时，优先放到 [Utilities](../utilities/index.md)。
- 需要扩展启用状态、Installer、扩展资源或可选运行时系统时，放到对应 [Extensions](../../extensions/index.md) 或项目自己的插件。

## API Reference

完整类、方法和信号列表见 [Standard API Reference](../../reference/api/standard.md)。
