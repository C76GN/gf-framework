# GFCodeQualityAnalyzer

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/code_quality/gf_code_quality_analyzer.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

项目代码规范的只读检查入口，供编辑器、制作工具与 CI 使用。 输入只作为文本分析；检查不会执行目标脚本、写入源码或自动启用项目规范。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_rule_ids`](#member-gfcodequalityanalyzer-methods-get_rule_ids) | `static func get_rule_ids() -> PackedStringArray:` |
| 方法 | [`load_project_config`](#member-gfcodequalityanalyzer-methods-load_project_config) | `static func load_project_config(root: String) -> Dictionary:` |
| 方法 | [`analyze_source`](#member-gfcodequalityanalyzer-methods-analyze_source) | `func analyze_source( path: String, source: String, config: Dictionary ) -> Dictionary:` |
| 方法 | [`analyze_project`](#member-gfcodequalityanalyzer-methods-analyze_project) | `func analyze_project( root: String, config: Dictionary = {}, cancel_probe: Callable = Callable() ) -> Dictionary:` |

## 方法

<a id="member-gfcodequalityanalyzer-methods-get_rule_ids"></a>

### `get_rule_ids`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_rule_ids() -> PackedStringArray:
```

返回可配置的规范规则，读取失败和语法分析失败不能通过规则配置关闭。

返回：按 ID 排序的规范规则集合。

<a id="member-gfcodequalityanalyzer-methods-load_project_config"></a>

### `load_project_config`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func load_project_config(root: String) -> Dictionary:
```

只读加载项目选择的规范；不存在配置时返回 unconfigured。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 本地绝对项目目录，或当前项目的 res:// 目录。 |

返回：配置准入结果，不会创建默认配置。

结构：

- `return`: Dictionary，ok: bool、status: configured/unconfigured/incomplete、config: Dictionary、error: String；成功 config 为 schema_version、preset、include、exclude、rules、layout 的规范值。

<a id="member-gfcodequalityanalyzer-methods-analyze_source"></a>

### `analyze_source`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_source( path: String, source: String, config: Dictionary ) -> Dictionary:
```

按显式项目配置分析一份源码快照；路径仅用于定位，不触发文件读取。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 诊断展示的源码路径。 |
| `source` | 调用方捕获的完整 GDScript 文本。 |
| `config` | 项目选择的规范配置，空配置返回 unconfigured。 |

返回：只读检查结果；警告不阻断 ok，未完成检查始终不通过。

结构：

- `config`: Dictionary，schema_version: 1，可选 preset: "gf-game@1"、rules: Dictionary[String, off/warning/error]、include/exclude: Array[String]、layout: Dictionary[String, int]。
- `return`: Dictionary，schema_version: 1、status: clean/violations/incomplete/unconfigured、complete/ok: bool、diagnostics: Array[Dictionary]、files_checked/files_failed: int、source_hashes: Dictionary[String, String]、coverage: Dictionary；诊断含 path、line/column（从 1 开始的字符坐标）、rule、severity、message、suggestion。

<a id="member-gfcodequalityanalyzer-methods-analyze_project"></a>

### `analyze_project`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func analyze_project( root: String, config: Dictionary = {}, cancel_probe: Callable = Callable() ) -> Dictionary:
```

检查配置范围内的独立 .gd 文件，结束前复核来源，支持文件间取消。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 被检查的本地项目目录；不会加载其 project.godot 或执行其脚本。 |
| `config` | 显式配置；为空时只读加载项目的 .gf/code_quality.json。 |
| `cancel_probe` | 可选无参回调，返回 true 时停止扫描；回调由调用者提供并须适合当前线程。 |

返回：项目源码检查报告；失败、取消和读取期变化都返回 incomplete。

结构：

- `config`: Dictionary，与 analyze_source 的 config 相同；空字典仅表示从项目加载配置。
- `return`: Dictionary，与 analyze_source 报告相同；coverage.source 为 disk，include/exclude 记录实际配置范围；source_hashes 保存已检查文件的文本 SHA-256。
