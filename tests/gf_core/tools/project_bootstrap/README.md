# Project Bootstrap 验收

聚焦 GUT：`res://tests/gf_core/tools/project_bootstrap/test_gf_project_bootstrap.gd`。

从仓库根运行真实编辑器与生成结果验收：

```powershell
python tests/gf_core/tools/project_bootstrap/run_editor_smoke.py --keep-logs
```

runner 复用现有有界、固定身份文件读取与源库存复制，以及维护环境冻结和进程监督底座。它把完整 GF 与 fixture 复制到独立临时项目，给 Godot 配置私有 data/config/cache/user 目录，通过原生 API 验证这些路径，再串行执行导入、真实 EditorPlugin、生成脚本导入、已有项目运行、空项目运行五个阶段。每阶段最多 180 秒；所有子进程均须正常退出并证明进程边界静默。单独运行没有额外整体 deadline；维护套件的外层预算还应覆盖有界源捕获、内容复核与清理。

验收包括真实页面预览/创建按钮、上下文撤销与退树后的旧按钮拒绝写入、恢复报告保留与输入锁定、删除生成脚本后的类型名释放、主场景默认保留与显式替换、已有 Installer 顺序保留、空项目、create-only 冲突、预览过期、设置保存失败后的文件补偿，以及生成场景实际 `Gf.init → Installer → System → Model → Label` 链路。runtime 每个场景最多等待 10 秒，按计数按钮启用条件确认初始化完成；编辑器 fixture 等待原生文件系统扫描结束才退出。任何错误、警告、超时、截断输出、缺失日志或无效成功标记都会失败。

结束后同时比较调用方 GF/fixture 与隔离副本中原始文件的 SHA-256，防止把混合源码结果作为成功。日志与结构化结果写入本次唯一的 `ai_analysis/godot_logs/project-bootstrap-smoke-*`。默认成功后清理日志，`--keep-logs` 保留审查证据。不要在源捕获或验收期间修改这些文件；与同工作区维护命令串行运行，避免日志清理或输入指纹竞争。
