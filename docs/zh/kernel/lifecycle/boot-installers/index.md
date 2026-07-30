# Kernel 启动注册与 Installer

这一组文档说明全局架构的启动装配流程。项目可以在 boot 脚本中显式注册模块，也可以通过项目 Installer 和扩展 Installer 完成固定拓扑装配；模块依赖由 lifecycle Hook 声明并编译为 DAG。

## 阅读入口

- [手动启动注册](manual-boot.md)：在 boot 脚本中按数据、工具、系统顺序注册模块。
- [项目级 Installer](project-installers.md)：继承 `GFInstaller`，使用声明式绑定，并接入项目设置。
- [扩展 Installer](extension-installers.md)：通过扩展 manifest 自动装配扩展级服务。
- [失败状态与超时](failure-timeout.md)：Installer 加载失败、重试初始化、超时和迟到写入保护。

## 使用边界

Installer 只负责注册模块，不应该直接启动玩法流程。必须阻止架构过早开放的异步 bootstrap 放在声明依赖的项目 System `begin_activation()` 中；架构 READY 后的场景与玩法流程仍由引导场景或项目状态机负责。
