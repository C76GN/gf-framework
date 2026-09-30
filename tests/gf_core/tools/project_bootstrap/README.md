# 空项目初始化验收

聚焦 GUT：`res://tests/gf_core/tools/project_bootstrap/test_gf_project_bootstrap.gd`。

从仓库根运行真实编辑器与生成结果验收：

```powershell
python tests/gf_core/tools/project_bootstrap/run_editor_smoke.py --keep-logs
```

runner 复用现有有界、固定身份文件读取与源库存复制，以及维护环境冻结和进程监督底座。它把完整 GF 与 fixture 复制到独立临时项目，给 Godot 配置私有 data/config/cache/user 目录，通过原生 API 验证这些路径，再串行执行导入、真实 EditorPlugin、生成脚本导入、已有项目运行、空项目运行五个阶段。每阶段最多 180 秒；所有子进程均须正常退出并证明进程边界静默。单独运行没有额外整体 deadline；维护套件的外层预算还应覆盖有界源捕获、内容复核与清理。

GUT 验证默认四文件、不生成 Model/System 或全局类型、新项目拒绝覆盖已有入口、已有项目保留主场景与 Installer 顺序、严格选项、仅指引／README-only 计划、原始设置签名、canonical Gf 路径／UID、模板依赖和稳定包／任务标识。不存在旧计数器类名的临时登记机制。

EditorPlugin 验证真实页面默认一键初始化与已有项目接入、自动只读摘要、上下文撤销和退树后的旧按钮拒绝写入、恢复报告保留和输入锁定、旧示例文件保持不变、create-only 冲突、过期预览、设置保存失败后的文件补偿。仅指引必须不创建目录、无事务和设置保存；README-only 必须只写所选文件。文件系统扫描等待有 30 秒上限。

已有项目成功接入后保留实际成功报告，再从外部更改或清空当前主场景设置；通过真实“刷新变更摘要”按钮验证 Main 定位路径和 OpenMain 可用状态。即使已有 Installer 使新计划无法再次创建，也必须使用当前主场景，不能回退到旧成功报告；刷新不得保存这些外部内存设置。

保留产物的失败路径使用已有 `GFArtifactWriteTransaction` 私有故障注入：真实 staging 写入后报错，并使两次自有文件清理失败。测试确认磁盘实际保留暂存 sidecar、最终 Installer 尚未发布，再用原恢复句柄完成清理。在隔离的 headless 编辑器内临时关闭周期扫描，等待文件系统及其信号计数连续五帧稳定，然后点击真实创建按钮；必须观察到 `filesystem_changed`、新目录进入编辑器索引和扫描完成，同时保持原编辑场景。即时扫描状态另行记录，不要求极快完成或同步扫描仍保持 `is_scanning()` 为 true。测试结束恢复原编辑器设置，不手工调用扫描，也不声称暂存文件是已发布的完整脚手架。

两个 runtime 阶段均正常启动 Godot 项目，由隔离项目的观察 AutoLoad 验收实际 `application/run/main_scene`；不使用 `-s` 替换启动流程。已有项目仍从原主场景显式调用 `Gf.init()`，验证真实 Installer 顺序和空模块注册表。空项目从原始生成 Boot 启动，测试专用延迟 Installer 证明初始化完成前不进入 Main；之后验证 Main 进入时架构已 READY、Boot 正常退出不销毁全局架构，以及异步初始化期间销毁 Boot 后的迟到回调不会抢占后续场景。每个运行时等待至多 10 秒。

`runtime_empty` 还会临时将真实 `Gf` AutoLoad 从树中移除、保留其节点，让实际生成 Boot 调用真实 `Gf.init()` 并观察失败后留在 Boot；随后将节点交还场景树正常清理。该故障注入**只允许一条精确的产品错误**：`ERROR: [GFProjectBootstrap][project_bootstrap.init_failed] GF initialization did not complete; startup was stopped.`。它必须分别在 stderr 和独立 Godot 日志中恰好出现一次，stdout 不得出现诊断；报告保留各 channel 原始诊断。缺失、重复、额外错误、所有脚本错误和警告均失败，其他四阶段继续要求零错误／警告。成功标记还必须证明失败 Boot 实际执行、Main 进入次数未增加以及退役回调保护，不能仅凭进程退出码或预期错误判定成功。

所有阶段均拒绝超时、截断输出、缺失日志、stdout／日志不一致或重复成功标记。

结束后同时比较调用方 GF/fixture 与隔离副本中原始文件的 SHA-256，防止把混合源码结果作为成功。日志与结构化结果写入本次唯一的 `ai_analysis/godot_logs/project-bootstrap-smoke-*`。默认成功后清理日志，`--keep-logs` 保留审查证据。不要在源捕获或验收期间修改这些文件；与同工作区维护命令串行运行，避免日志清理或输入指纹竞争。
