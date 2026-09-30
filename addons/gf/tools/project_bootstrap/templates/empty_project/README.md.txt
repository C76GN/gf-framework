# GF 项目接入

输出目录：__ROOT__

__MODE_GUIDANCE__

__INSTALLER_GUIDANCE__

通过工作区预览并明确创建这些文件；已有文件不会被覆盖。生成后它们属于项目，不会随框架升级自动改写。

Gf AutoLoad 由 GF 插件登记并持有应用运行域。项目启动入口等待 Gf.init()，无需再次创建 Architecture。普通场景切换和启动页退出都不应销毁全局架构。

Gf 离开 SceneTree 时执行同步清理兜底，不承诺业务保存或后台任务排空。需要可等待的正常退出时，由项目唯一退出入口等待 architecture.shutdown_async() 并检查结果，再退出应用。
