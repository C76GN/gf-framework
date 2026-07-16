# 场景与流程切换

本组页面覆盖主场景切换、Loading 过渡、场景资源预加载、场景参数、场景历史和瞬态模块清理。GF 管理通用切换流程；目标场景初始化、关卡规则、存档恢复和 Loading UI 表现仍属于项目层。

## 阅读入口

- [切换与 Transition 配置](switching-transition.md)：`GFSceneUtility`、异步切换和 `GFSceneTransitionConfig`。
- [预加载缓存与图谱](preload-cache-map.md)：预加载缓存、后台加载、LRU / fixed 缓存和 `GFScenePreloadMap`。
- [参数、历史与安全帧](params-history-safe-frame.md)：切换参数、场景历史、安全切场和 headless 降级。
- [瞬态模块、Loading 与失败恢复](transient-loading-failure.md)：瞬态模块清理、暂停恢复、Loading scene 协议和失败处理。
- [场景根节点契约检查](scene-contract-checks.md)：`GFSceneContractTools`、目录扫描、根脚本继承和分组约束。

## 使用边界

`GFSceneUtility` 只管理场景资源生命周期、切换、进度信号、缓存和瞬态模块清理。场景内初始化、关卡解锁、出生点解释、存档恢复和 Loading 视觉由项目层负责。
