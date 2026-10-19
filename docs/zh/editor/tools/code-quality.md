# GDScript 代码检查

`gf.tool.code_quality` 提供 Godot 原生的只读源码检查。编辑器、命令行和 `GFCodeQualityAnalyzer` 使用同一分析入口，不要求安装 Python，检查过程不运行被检查的项目脚本。

工具随完整 GF 插件提供。在 `GF Workspace` 打开“代码检查”页面后，主动选择“检查当前脚本”或“检查已保存项目”。打开页面不会扫描整个项目，也不会创建配置、修改排版或补写注释。

## 主动采用项目规范

项目先创建 `.gf/code_quality.json`，明确选择预设或启用的规则。没有配置时，工具报告 `unconfigured`；这表示尚未采用检查策略，不能视为检查通过。

以下示例采用可选的 `gf-game@1` 预设。请把 `include` 和 `exclude` 修改为项目实际使用的源码目录：

```json
{
  "schema_version": 1,
  "preset": "gf-game@1",
  "include": ["res://scripts"],
  "exclude": ["res://scripts/generated"]
}
```

`include` 和 `exclude` 使用项目内的 `res://` 路径，目录项表示整个目录范围，不支持通配表达式。不要把第三方插件和生成目录加入手写业务代码的检查范围。配置属于项目，可以提交版本控制；GF 升级不会自动改写它。

省略范围时，`include` 默认为 `["res://"]`，`exclude` 默认为 `["res://addons"]`。显式提供数组会替换对应默认值，不是追加；`.git` 和 `.godot` 始终跳过。目录不存在、读取失败或路径穿过链接时，不会跳过后继续报告通过。

`gf-game@1` 以代码结构决定换行：两个简单项允许同行，三个及以上按结构展开；章节和定义前保留两行空行，不以字符串或标识符长度触发折行。声明使用简短文档说明职责，私有成员也应说明用途；不要求游戏代码使用 GF 自身的 `@api`、`@since`、`@layer` 或 `@category` 标签。

检查能判断已启用规则的结构要求和文档是否存在，不能判断业务注释是否准确解释了所有权、生命周期或设计原因。注释应描述当前约定，函数体中的原因说明仍按实际需要编写。

项目可以用 `rules` 覆盖预设中某项规则的级别，或不选择预设、只启用明确列出的规则。级别为 `error`、`warning` 或 `off`；未知规则和未知配置字段会拒绝检查，不会静默忽略。`doc_public_summary` / `doc_private_summary` 检查成员职责说明；`doc_parameters` / `doc_return` 检查对外入口的完整参数、返回说明，以及私有成员按需写出的标签；`doc_tags` 检查已写出的标签契约；`section_order` 检查已有章节的顺序，不要求每个游戏文件增加空章节。完整规则 ID 使用下述命令查询。

`layout` 可以显式设置 `max_inline_items`、`section_blank_lines_before` 和 `definition_blank_lines`。未覆盖时分别为 `2`、`2`、`2`，没有列宽配置。预设与规则只决定此次检查，不修改项目原有源码。

`gf-game@1` 的规则集合固定，工具以后新增规则不会自动扩大这份预设；采用新规范由项目主动调整配置。

## 编辑器使用

- **检查当前脚本**：按项目规则检查明确选中的 GDScript 编辑缓冲，包含未保存文本；不应用项目扫描的 `include` / `exclude` 范围。结果发布前如果缓冲已修改或关闭，页面要求重新检查。
- **检查已保存项目**：扫描配置范围内的磁盘文件，不会强制保存当前编辑；未保存的缓冲不属于这份报告。
- **取消**：停止后续项目扫描并撤销本次结果的发布资格。单文件分析遵守文本预算，取消不会保留一份看似完整的结果。
- **配置示例**：只展示文本，项目自行决定是否采用；页面不保存配置。
- **定位源码**：选择诊断后点击，或双击诊断行，由 Godot 编辑器正常打开对应脚本和行。详情显示规则、说明和建议。

项目检查在后台执行，页面按需呈现诊断。检查期间配置内容改变、被删除或变为无效时，本次结果失效，需要重新发起检查；工具不会自动采用新配置继续本轮任务。隐藏页面、关闭工作区或卸载插件会取消在途请求；工具不会在每次输入时全量扫描。报告是该次读取的快照，修改或保存源码后应重新检查。

## 命令行与 CI

在安装 GF 的项目目录中运行：

```powershell
godot --headless --path . --script res://addons/gf/tools/code_quality/cli/gf_code_quality_cli.gd -- --json
```

`--` 之后是工具参数。默认检查宿主项目；检查另一份项目源码时使用 `--root <本地绝对目录>`，该目录的配置仍为 `.gf/code_quality.json`。命令使用独立的 `MainLoop`，不会启动宿主项目的 AutoLoad，也不会加载待检查的 GDScript 资源或运行它的 `@tool` 静态初始化。

```powershell
godot --headless --path . --script res://addons/gf/tools/code_quality/cli/gf_code_quality_cli.gd -- --list-rules --json
godot --headless --path . --script res://addons/gf/tools/code_quality/cli/gf_code_quality_cli.gd -- --help
```

`--json` 输出一行 `GF_CODE_QUALITY_REPORT=<JSON>`，调用方按行首提取其后的 JSON；Godot 自身的启动与诊断输出不能当作检查报告。不要添加 Godot 的 `--quiet`，该参数也会屏蔽脚本报告输出。正常检查返回前述分析报告，`--list-rules` 返回 `schema_version` 和 `rules`，不扫描项目源码。

| 退出码 | 含义 |
| --- | --- |
| `0` | 检查完整且没有 `error` 级规则问题；可以含 `warning`。查询规则或帮助成功也返回 0。 |
| `1` | 检查完整，存在 `error` 级规则问题。 |
| `2` | 未配置、检查不完整或参数无效。 |

CI 应同时检查进程退出码和报告完整性。命令不提供自动修复、源码写回或配置生成选项。

## 通过代码调用

```gdscript
const CODE_QUALITY_SCRIPT = preload("res://addons/gf/tools/code_quality/gf_code_quality_analyzer.gd")

var analyzer: GFCodeQualityAnalyzer = CODE_QUALITY_SCRIPT.new()
var report: Dictionary = analyzer.analyze_project("res://")
```

项目分析默认读取根目录的 `.gf/code_quality.json`。调用方也可以提供显式配置。`analyze_source` 直接检查传入文本，不应用 `include` / `exclude`；路径仅用于诊断定位，不读取目标脚本，也不会加载它的资源或执行它：

```gdscript
var report: Dictionary = analyzer.analyze_source(
    "res://scripts/player.gd",
    source_text,
    {
        "schema_version": 1,
        "preset": "gf-game@1",
        "include": ["res://scripts"]
    }
)
```

`load_project_config(root)` 返回 `ok`、`status`、`config` 和 `error`，供调用方读取与项目扫描相同的配置。不要根据缺省配置替项目选择预设。

## 结果与边界

报告包含 `schema_version`、`status`、`complete`、`ok`、`diagnostics`、`files_checked` 和 `files_failed`。每条诊断包含 `path`、从 1 开始的 `line` / `column`、`rule`、`severity`、`message` 和 `suggestion`。

| 状态 | 含义 |
| --- | --- |
| `clean` | 检查范围完整，未发现已启用规则的问题。 |
| `violations` | 检查范围完整，发现规则问题；结合严重性判断是否阻断。 |
| `incomplete` | 配置、读取、语法结构、取消或资源预算使检查不完整，不能用零条诊断证明源码干净。 |
| `unconfigured` | 项目没有主动采用预设或规则。 |

有效范围可能没有 `.gd` 文件，此时 `files_checked` 为 `0`，`clean` 只表示该范围没有需要检查的源码。若项目应包含游戏脚本，请先核对 `include` / `exclude`；零匹配不能证明其他目录的代码符合规范。

单文件最多读取 4 MiB，项目源码合计最多 64 MiB，文件与目录枚举最多 40,000 项，诊断最多 10,000 条。配置文件最多 64 KiB，`include` / `exclude` 各最多 64 项。词法分析也限制 token、行数和嵌套深度；输入过大、结构无法完整识别或取消时都报告 `incomplete`，不把部分扫描的零问题作为通过结果。

工具是制作期能力，不添加运行时 AutoLoad；GF 编辑器插件启用时，其导出过滤器只排除 `addons/gf/tools/code_quality/` 自身路径。游戏运行时代码不应引用这些工具类型。源码检查不替代 Godot 编译、类型诊断和项目行为测试。
