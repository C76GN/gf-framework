# 编辑器工具、访问器与项目常量

GF 编辑器插件提供 AutoLoad 注册、ProjectSettings、脚本模板、扩展管理、菜单、工作区页面、Inspector、导出插件、访问器生成和项目常量生成。

GF 的编辑器层只负责装配和生成，不承载可选扩展的运行时逻辑。核心插件位于 `addons/gf/plugin.gd`，实际职责拆到 `addons/gf/kernel/editor` 下的辅助脚本。

## 核心组件

- `GFPluginAutoload`：确保 `Gf -> res://addons/gf/kernel/core/gf.gd` AutoLoad 存在。
- `GFPluginProjectSettings`：注册 GF 项目设置默认值和编辑器属性提示。
- `GFPluginActions`：注册 GF 菜单动作、脚本模板和访问器生成入口。
- `GFPluginMenu`：把声明式菜单项挂到 Godot 编辑器菜单。
- `GFPluginInspectorTools`：装载 Inspector 与导出插件。
- `GFPluginDockTools`：装载 GF 独立工作区窗口。

## 文档结构

- [ProjectSettings](project-settings.md)：GF 插件注册的项目设置和读取边界。
- [GF Workspace](workspace.md)：独立工作区窗口、内置页面和 Extensions 页面。
- [菜单与脚本模板](menus-templates.md)：`工具 > GF` 菜单、脚本模板和生成入口。
- [编辑器命令、动作与工具协议](tool-protocols.md)：`GFEditorCommand`、Action、Tool、Context、Option 和 Pick Operation。
- [访问器生成](access-generator.md)：`GFAccessGenerator` 和扩展生成钩子。
- [Inspector、工作区页面与导出插件](editor-extensions.md)：标准库和扩展贡献编辑器入口的方式。
- [通用 Resource 表格控件](resource-table-editor.md)：`GFResourceTableEditor` 的扫描、显示和编辑能力。
- [工具包](tools/index.md)：制作期、编辑器期、导入期、构建期或 CI 期工具包的边界与入口。
