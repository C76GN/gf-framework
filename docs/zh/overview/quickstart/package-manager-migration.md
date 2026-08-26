# 从 GF 10 模块化安装迁移

GF 11 已移除用户侧 Package Manager、包管理命令行、在线 registry、离线 bundle 和逐模块发布包。GF 11 不会生成或更新 `.gf/packages.lock.json`；框架改为通过完整的 `gf-framework-<version>.zip` 安装和升级。

本页只用于把曾经由 GF 10 模块化安装器管理的项目迁移到完整插件。普通完整安装项目不需要执行这些步骤。

## 迁移步骤

1. 保持项目仍使用原来的 GF 10 版本，不要先复制 GF 11 文件。
2. 停止其他安装或更新操作，使用该 GF 10 版本原有的工具先执行 `recover`，再执行 `verify`。任一步报告失败、活动事务或需要恢复时都先停止迁移并解决原问题。
3. 提交当前项目，或制作包含 `addons/gf`、`project.godot` 和 `.gf` 状态的完整备份。单独记录项目对 GF 源文件做过的本地修改。
4. 关闭 Godot 编辑器和运行中的项目进程。
5. 移除旧的 `addons/gf` 目录，再复制 GF 11 完整发布包中的 `addons/gf`。不要把完整包叠加到旧模块化目录，也不要混用多个版本的文件。
6. 重新启用或刷新 `GF Framework` 插件，确认 `Gf` AutoLoad、脚本解析、项目测试和导出均正常。

## 遗留状态

迁移过程不会自动删除以下 GF 10 状态：

- `.gf/packages.lock.json`
- `.gf/package_cache`、`.gf/package_workspace` 与更旧版本留下的 `.gf/package_temp`
- `.gf/package_transactions` 中的事务与恢复记录

这些文件可能是回滚、确认本地改动和解释旧安装来源所需的证据。迁移验证完成、确认不再回退 GF 10 后，再把它们归档到项目外的备份位置或显式清理；不要把删除动作写进无条件升级脚本。

AI Developer 在过渡期仍会只读校验遗留 lockfile：无效文件会失败关闭，不会伪装成可信安装状态。把旧 lockfile 归档后，GF 11 项目会以当前完整插件目录作为框架状态来源。

## 与扩展和内容包的关系

完整发布包已经包含内置可选扩展。`GF Workspace` 的 `GF Extensions` 页面只负责启用或禁用项目中已经存在的扩展、运行对应 Installer 和控制导出过滤，不负责下载或更新文件。

`extensions/content_package` 处理游戏内容 manifest、内容依赖和资源目录，不是框架安装器，也不受 Package Manager 退役影响。
