# Scene Placement 编辑器烟测

在仓库根目录运行；脚本使用仓库维护工具解析 Godot，并创建独立临时工程与私有编辑器数据目录，不修改源工程的 `project.godot`。

```powershell
python tools/gf_maintenance.py check --check scene_placement_editor_smoke --failed-only
python tests/gf_core/tools/scene_placement/run_editor_smoke.py --rendered --keep-logs
```

`--rendered` 使用真实渲染器并保存 3D 视口截图，需要可用的图形环境；省略该参数可运行 headless 行为烟测。`--keep-logs` 保留成功运行的日志；失败或渲染运行始终保留证据，路径由最终 JSON 的 `log_directory` 给出。

烟测由真实 `EditorPlugin` 生命周期触发，验证注册的 3D 编辑器 GUI 输入转发、平面与真实碰撞表面拾取、锚点和非单位父变换、确认与取消、场景切换、原生撤销重做、保存重读、插件卸载后的历史重放，以及 Launcher 清空上下文、销毁、同帧替换和仍开启子插件时退出编辑器的生命周期。用户独立启用或重新启用插件时，测试还要求页面构建、清理和“打开”动作保留该实例，只有显式“关闭”才停用它。GUI 输入证据经编辑器已注册的输入信号处理器进入，不等同于操作系统鼠标事件。私有插件直接复制 `fixtures/gf_scene_placement_editor_smoke_plugin.cfg` 和对应脚本作为唯一入口描述。

入口监督所有 Godot 子进程，要求进程边界静默、独立日志和结构化断言结果一致，并拒绝错误、警告、输出截断与源文件摘要变化。无界面入口以 `scene_placement_editor_smoke` 登记到 `framework-integration`，随 Ready/main 的 Full 等价检查与 release 检查执行；Draft、纯静态检查和 GUT 分片不启动此原生编辑器测试。带渲染的截图检查仍按需运行。普通 GUT 不直接实例化编辑器拥有的插件。

源码捕获使用维护工具的 pinned 文件读取；每个清单最多 20,000 个目录项、16,000 个文件、32 层子目录、单文件 32 MiB、总计 256 MiB，日志和截图各限 4 MiB。超出预算或遇到链接与特殊文件时失败，不跳过条目后继续给出成功结论。
