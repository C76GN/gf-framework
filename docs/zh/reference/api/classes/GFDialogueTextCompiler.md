# GFDialogueTextCompiler

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/dialogue_text/gf_dialogue_text_compiler.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`9.0.0`

对话 JSON 文本编译器。 在制作期、编辑器期或 CI 中把严格、可审计的 JSON 文本编译为 GFDialogueResource。 compile_structure_* 只承诺结构通过；build_runner_* 另外验证内置 Runner 的完整身份准入。 strict 边界拒绝重复 member、宽松 JSON、非法 Unicode、int64 外整数、非有限、 溢出或规范化十进制指数不在 -307..308 的非零浮点，并以显式硬预算约束工作量。 编译器只解释对话资源已有字段，不定义角色、任务、本地化、UI 或项目状态语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SOURCE_FORMAT`](#member-gfdialoguetextcompiler-constants-source_format) | `const SOURCE_FORMAT: String = "gf.dialogue"` |
| 常量 | [`SOURCE_SCHEMA_VERSION`](#member-gfdialoguetextcompiler-constants-source_schema_version) | `const SOURCE_SCHEMA_VERSION: int = 1` |
| 方法 | [`compile_structure_text`](#member-gfdialoguetextcompiler-methods-compile_structure_text) | `func compile_structure_text(text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`compile_structure_source`](#member-gfdialoguetextcompiler-methods-compile_structure_source) | `func compile_structure_source(source_key: String, loader: GFSourceTextLoader, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_runner_text`](#member-gfdialoguetextcompiler-methods-build_runner_text) | `func build_runner_text(text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_runner_source`](#member-gfdialoguetextcompiler-methods-build_runner_source) | `func build_runner_source(source_key: String, loader: GFSourceTextLoader, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfdialoguetextcompiler-constants-source_format"></a>

### `SOURCE_FORMAT`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const SOURCE_FORMAT: String = "gf.dialogue"
```

对话文本格式标识。

<a id="member-gfdialoguetextcompiler-constants-source_schema_version"></a>

### `SOURCE_SCHEMA_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const SOURCE_SCHEMA_VERSION: int = 1
```

当前对话文本 schema 版本。

## 方法

<a id="member-gfdialoguetextcompiler-methods-compile_structure_text"></a>

### `compile_structure_text`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func compile_structure_text(text: String, options: Dictionary = {}) -> Dictionary:
```

只编译结构资源：验证 strict JSON、schema 和资源图，不承诺 Runner 身份准入。 成功只描述本次资源和所选合同，不执行项目条件或 mutation，不保证所有运行分支成功。 失败不返回部分资源；报告为有界 JSON-safe 投影并保留来源。

参数：

| 名称 | 说明 |
|---|---|
| `text` | strict JSON 文本；整数限 int64，非零浮点规范化十进制指数限 -307..308。 |
| `options` | 来源、报告 metadata 与输入预算；生产入口不能覆盖 Runner 身份预算。 |

返回：所选合同的结果。

结构：

- `options`: Dictionary，支持 source_path、subject、metadata 与 max_text_bytes、max_depth、max_nodes、max_string_bytes、max_lines、max_responses、max_diagnostics 严格正整数预算。
- `return`: Dictionary，包含 contract（structure 或 runner）、success、resource、report、source_path、content_hash、line_count；success 只表示所选合同通过，失败时 resource=null、line_count=0。

<a id="member-gfdialoguetextcompiler-methods-compile_structure_source"></a>

### `compile_structure_source`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func compile_structure_source(source_key: String, loader: GFSourceTextLoader, options: Dictionary = {}) -> Dictionary:
```

只编译结构资源：验证 strict JSON、schema 和资源图，不承诺 Runner 身份准入。 成功只描述本次资源和所选合同，不执行项目条件或 mutation，不保证所有运行分支成功。 失败不返回部分资源；报告为有界 JSON-safe 投影并保留来源。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 注册 key 或加载器根目录内相对路径。 |
| `loader` | 源码加载器；max_bytes 必须为正且不超过有效 max_text_bytes。 |
| `options` | 来源、报告 metadata 与输入预算；生产入口不能覆盖 Runner 身份预算。 |

返回：所选合同的结果。

结构：

- `options`: Dictionary，支持 source_path、subject、metadata 与 max_text_bytes、max_depth、max_nodes、max_string_bytes、max_lines、max_responses、max_diagnostics 严格正整数预算。
- `return`: Dictionary，包含 contract（structure 或 runner）、success、resource、report、source_path、content_hash、line_count；success 只表示所选合同通过，失败时 resource=null、line_count=0。

<a id="member-gfdialoguetextcompiler-methods-build_runner_text"></a>

### `build_runner_text`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func build_runner_text(text: String, options: Dictionary = {}) -> Dictionary:
```

构建内置 Runner 生产资源：结构校验后验证默认完整身份预算。 成功只描述本次资源和所选合同，不执行项目条件或 mutation，不保证所有运行分支成功。 失败不返回部分资源；报告为有界 JSON-safe 投影并保留来源。

参数：

| 名称 | 说明 |
|---|---|
| `text` | strict JSON 文本；整数限 int64，非零浮点规范化十进制指数限 -307..308。 |
| `options` | 来源、报告 metadata 与输入预算；生产入口不能覆盖 Runner 身份预算。 |

返回：所选合同的结果。

结构：

- `options`: Dictionary，支持 source_path、subject、metadata 与 max_text_bytes、max_depth、max_nodes、max_string_bytes、max_lines、max_responses、max_diagnostics 严格正整数预算。
- `return`: Dictionary，包含 contract（structure 或 runner）、success、resource、report、source_path、content_hash、line_count；success 只表示所选合同通过，失败时 resource=null、line_count=0。

<a id="member-gfdialoguetextcompiler-methods-build_runner_source"></a>

### `build_runner_source`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func build_runner_source(source_key: String, loader: GFSourceTextLoader, options: Dictionary = {}) -> Dictionary:
```

构建内置 Runner 生产资源：结构校验后验证默认完整身份预算。 成功只描述本次资源和所选合同，不执行项目条件或 mutation，不保证所有运行分支成功。 失败不返回部分资源；报告为有界 JSON-safe 投影并保留来源。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 注册 key 或加载器根目录内相对路径。 |
| `loader` | 源码加载器；max_bytes 必须为正且不超过有效 max_text_bytes。 |
| `options` | 来源、报告 metadata 与输入预算；生产入口不能覆盖 Runner 身份预算。 |

返回：所选合同的结果。

结构：

- `options`: Dictionary，支持 source_path、subject、metadata 与 max_text_bytes、max_depth、max_nodes、max_string_bytes、max_lines、max_responses、max_diagnostics 严格正整数预算。
- `return`: Dictionary，包含 contract（structure 或 runner）、success、resource、report、source_path、content_hash、line_count；success 只表示所选合同通过，失败时 resource=null、line_count=0。
