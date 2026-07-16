# 菜单与脚本模板

`工具 > GF` 菜单提供常用脚本模板和生成入口。

## 内置入口

- `System`、`Model`、`Utility`、`Command` 模板用于创建基础架构层脚本。
- Capability 相关模板由 Capability 扩展通过 `editor_action_paths` 注入，只在该扩展启用时可用。
- Node State 与 Node State Machine 模板由标准库编辑器贡献清单和模板文本注入，用于标准库节点状态机。
- `生成强类型访问器` 会生成 `GFAccess`。
- `生成项目常量访问器` 会生成 `GFProjectAccess`。
- `刷新 GF 编辑器贡献` 会重新扫描资源并重建 GF 自身收集到的标准库编辑器贡献记录，例如菜单模板、工作区页面、Inspector、Debugger 插件和 ProjectSettings 记录；它只读取 data-only 清单并检查目标资源是否存在，不负责热重载任意 Godot 插件或执行项目业务脚本。

`GFPluginActions` 只持有通用文件对话框、占位符替换和核心模板；标准库或扩展的模板应以记录形式注入，记录至少包含 `type`、`label`、`base_class` 和 `template`。访问器生成、ProjectSettings 读取和启用扩展动作路径发现由内部 `GFPluginActionDependencies` provider 承接，菜单动作本身不直接依赖这些启动期全局入口。

模板生成出的源码遵循项目代码布局规则。修改模板后应重新生成样本并运行对应维护测试。
