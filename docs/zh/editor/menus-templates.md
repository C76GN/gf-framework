# 菜单与脚本模板

`工具 > GF` 菜单提供常用脚本模板和生成入口。

## 内置入口

- `System`、`Model`、`Utility`、`Command` 模板用于创建基础架构层脚本。
- Capability 相关模板由 Capability 扩展通过 `editor_action_paths` 注入，只在该扩展启用时可用。
- Node State 与 Node State Machine 模板由标准库编辑器贡献清单索引，用于标准库节点状态机；模板文本位于 `gf.standard.state_machine.editor` 所拥有的 `addons/gf/standard/state_machine/node/editor/templates/`，中央清单不接管其物理所有权。
- `生成强类型访问器` 会生成 `GFAccess`。
- `生成项目常量访问器` 会生成 `GFProjectAccess`。
- `刷新 GF 编辑器贡献` 会等待已有资源扫描结束，再启动本次扫描，并只在文件系统空闲后重建 GF 自身收集到的标准库编辑器贡献记录，例如菜单模板、工作区页面、Inspector、Debugger 插件和 ProjectSettings 记录。同一轮等待或扫描期间的连续请求会合并到最新 generation；若期间又收到请求，会重新扫描，只有最新 generation 成功应用后才打印完成。刷新在 120 秒后失败关闭，插件退出时取消待处理回调。它只读取 data-only 清单并检查目标资源是否存在，不负责热重载任意 Godot 插件或执行项目业务脚本。

`GFPluginActions` 只持有通用文件对话框、占位符替换和核心模板；标准库或扩展的模板应以记录形式注入，记录至少包含 `type`、`label`、`base_class` 和 `template`，其中 `base_class` 必须是合法的 GDScript 标识符。访问器生成、ProjectSettings 读取和启用扩展动作路径发现由内部 `GFPluginActionDependencies` provider 承接，菜单动作本身不直接依赖这些启动期全局入口。

菜单模板把生成脚本视为用户所有文件：只允许写入 `res://`，要求目标基线不存在，并通过统一产物报告校验完整写入；已有目标、并发冲突、短写或路径越界都不会打印成功或覆盖现有内容。写入前还会验证由文件名推导的 `class_name` 和记录提供的 `base_class`；非法标识符会以零输出失败，不能借占位符生成不可解析源码。模板生成出的源码遵循项目代码布局规则。修改模板后应重新生成样本并运行对应维护测试。
