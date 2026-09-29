# Config Pipeline 工作台验证

聚焦数据、草稿和 UI 控件测试：

```powershell
godot --headless --path . --script res://tests/gf_core/support/gf_gut_cli.gd -gtest=res://tests/gf_core/tools/config_pipeline/test_gf_config_workbench.gd -gexit
```

真实编辑器生命周期验收：

```powershell
python tests/gf_core/tools/config_pipeline/run_editor_smoke.py
```

运行器复制当前框架和 fixture 到隔离临时工程，首次导入时禁用插件，然后通过真实 `EditorPlugin` 启动贡献注册表和 Workspace。覆盖可见入口、确认创建 CSV 样例、XLSX 新建向导的保存并导出、后台预检、数据库与 manifest、Provider 读取、脏草稿关闭时的取消/放弃及卸载。它不模拟 Excel，也不声明视觉截图验收；仅在已验证进程退出、日志没有错误/警告、成功标记完整且来源未变时通过。日志保留在 `ai_analysis/godot_logs/config-workbench-smoke-*`，不要与同工作树的日志清理同时运行。

原生验收还撤销并重新绑定页面上下文，验证预检、保存对话框、样例确认和默认设置等迟到操作零写入，旧字段、复制 Schema 与预设确认不能修改保留的草稿。它分别覆盖 worker 读取后文件变化以及成功展示后文件变化，要求独立预览状态过期，并在退出前等待编辑器资源扫描结束。

工作台上限是 1–16 个来源、每个文件 2 MiB、总计 8 MiB、布局后累计 4,000 个单元格。GUT 覆盖后台取消、旧结果隔离、超预算、预检后文件增长、同源 CLI、显式保存、typed ID 转换后唯一性、XLSX 缓存公式/Sheet/物理位置、跨表引用表单保存回读、strict 写后失败报告与 create-only 示例。上限限制支持的工作量，不保证自定义规则或文件提交的固定耗时。
