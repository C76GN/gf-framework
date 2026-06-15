# 调试可视化、运行时检查与信号诊断

本组文档覆盖开发期可视化观察、运行时调参和信号诊断工具。这些能力用于定位问题，不承担业务状态保存、玩家 UI 或线上权限控制。

## 阅读入口

- [调试绘制命令缓冲](debug-draw.md)：`GFDebugDrawUtility` 的 2D/3D 绘制命令、频道和生命周期。
- [调试覆盖层](debug-overlay.md)：`GFDebugOverlayUtility` 的 watch、面板和诊断监控预设接入。
- [截图捕获与批量保存](screenshots.md)：`GFScreenshotUtility` 的 Viewport 捕获、Image 保存和尺寸/语言批量截图流程。
- [运行时调参注册表](runtime-inspector.md)：`GFRuntimeInspectorUtility` 和 `GFRuntimeTunableProperty`。
- [信号诊断与运行时信号探针](signal-diagnostics.md)：`GFSceneSignalAudit`、`GFSignalGraphDock` 和 `GFSignalRuntimeProbe`。

## 使用边界

这些工具可能反射显示字段、信号参数或项目注册的 watch 值。不要在生产构建、公开演示或包含账号/token/存档密钥等敏感字段的环境中默认注册或开启；远程调试、玩家可见工具或线上入口应由项目层限制范围、脱敏和权限。
