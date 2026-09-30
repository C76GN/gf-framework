# Scene Placement 编辑器烟测

在仓库根目录运行；脚本使用仓库维护工具解析 Godot，并创建独立临时工程与私有编辑器数据目录，不修改源工程的 `project.godot`。

```powershell
python tools/gf_maintenance.py check --check scene_placement_editor_smoke --failed-only
python tests/gf_core/tools/scene_placement/run_editor_smoke.py --rendered --keep-logs
```

`--rendered` 使用真实渲染器并保存 3D 视口截图，需要可用的图形环境；省略该参数可运行 headless 行为烟测。`--keep-logs` 保留成功运行的日志；失败或渲染运行始终保留证据，路径由最终 JSON 的 `log_directory` 给出。

烟测由真实 `EditorPlugin` 生命周期触发，验证注册的 3D 编辑器 GUI 输入转发、平面与真实碰撞表面拾取、锚点和非单位父变换、确认与取消、场景切换、原生撤销重做、保存重读、插件卸载后的历史重放，以及 Launcher 清空上下文、销毁、同帧替换和仍开启子插件时退出编辑器的生命周期。用户独立启用或重新启用插件时，测试还要求页面构建、清理和“打开”动作保留该实例，只有显式“关闭”才停用它。GUI 输入证据经编辑器已注册的输入信号处理器进入，不等同于操作系统鼠标事件。私有插件直接复制 `fixtures/gf_scene_placement_editor_smoke_plugin.cfg` 和对应脚本作为唯一入口描述。

连续摆放用例保留默认单次行为，验证显式启用后两次确认产生独立的原生 Undo / Redo 动作，实例身份、父节点、owner 和世界变换在历史重放中保持一致。每次确认后必须重新命中，重复 Enter 不会复用旧预览；Esc 只结束当前预览，保留已确认实例。配置变化、父节点失效、场景切换和插件卸载均覆盖活动连续会话。同步创建取消及真实 Inspector 对象切换回调还验证旧确认不会复活已取消会话、覆盖替代会话或改写已提交历史。运行器要求这些观察项出现在结构化成功证据中。

资源衔接用例在同一隔离工程中打开资源工作台，读取真实 EditorFileSystem，选择素材，创建并保存标准共享 Catalog 标签，再通过已有 Resource 表格修改和保存一个独立源材质。Godot 原生文件载荷进入摆放接收方法后只设置来源，不开始摆放或实例化场景。该用例验证载荷与接收合同，不把程序化调用等同于操作系统跨窗口鼠标拖拽证据。

资源夹具还验证刷新和隐藏期间的 Catalog Undo 不会复活旧快照，上下文撤销后不再保存或接受晚到文件选择，Catalog 使用源 Resource 的原生历史。原生缩略图回调隔离仅在 `--rendered` 模式强制验收；headless 明确记录未执行此项。

独立的 `gf_workspace_integration_smoke.gd` 夹具随后安装真实 Workspace 宿主，读取 Standard 与根工具贡献目录的纯数据记录，注入当前 `EditorPlugin` 和原生撤销管理器。它验证任务查询不创建窗口或工具页面、首页任务按钮打开资源页、原生资源菜单将 PackedScene 交给摆放工具但不创建节点或写入 Undo、材质选择的禁用原因，以及窗口隐藏重开、贡献刷新后的旧上下文撤销和弱引用清理。仅在隔离工程内显式启用 Action Queue；Tween 创建任务只打开原生对话框，取消前不写项目资源。

同一宿主还要求配置工作台和最小项目向导的任务能打开真实页面及其首个操作入口，单纯打开页面不保存项目设置、不创建默认项目文件。各工具的独立原生验收继续覆盖实际导出、创建和失败恢复。

渲染模式另存真实 Workspace Window 的 `workspace_home.png` 与 `workspace_assets.png`，检查窗口归属、可见控件结构和字体主题；不使用叠加容器替代宿主截图。任务按钮和菜单入口通过真实控件信号驱动，这些证据不等同于操作系统鼠标或键盘事件。运行器要求全部 Workspace 观察项与有界 PNG 都存在后才报告成功。

入口监督所有 Godot 子进程，要求进程边界静默、独立日志和结构化断言结果一致，并拒绝错误、警告、输出截断与源文件摘要变化。无界面入口以 `scene_placement_editor_smoke` 登记到 `framework-integration`，随 Ready/main 的 Full 等价检查与 release 检查执行；Draft、纯静态检查和 GUT 分片不启动此原生编辑器测试。带渲染的截图检查仍按需运行。普通 GUT 不直接实例化编辑器拥有的插件。

源码捕获使用维护工具的 pinned 文件读取；每个清单最多 20,000 个目录项、16,000 个文件、32 层子目录、单文件 32 MiB、总计 256 MiB，日志和截图各限 4 MiB。超出预算或遇到链接与特殊文件时失败，不跳过条目后继续给出成功结论。
