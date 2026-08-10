# GFDialogueTextCompiler

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/dialogue_text/gf_dialogue_text_compiler.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`9.0.0`

对话 JSON 文本编译器。 在制作期、编辑器期或 CI 中把严格、可审计的 JSON 文本编译为 GFDialogueResource。 strict 边界拒绝重复 member、宽松 JSON、非法 Unicode、int64 外整数、非有限、 溢出或规范化十进制指数不在 -307..308 的非零浮点，并以显式硬预算约束工作量。 编译器只解释对话资源已有字段，不定义角色、任务、本地化、UI 或项目状态语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SOURCE_FORMAT`](#member-gfdialoguetextcompiler-constants-source_format) | `const SOURCE_FORMAT: String = "gf.dialogue"` |
| 常量 | [`SOURCE_SCHEMA_VERSION`](#member-gfdialoguetextcompiler-constants-source_schema_version) | `const SOURCE_SCHEMA_VERSION: int = 1` |
| 方法 | [`compile_text`](#member-gfdialoguetextcompiler-methods-compile_text) | `func compile_text(text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`compile_source`](#member-gfdialoguetextcompiler-methods-compile_source) | `func compile_source( source_key: String, loader: GFSourceTextLoader, options: Dictionary = {} ) -> Dictionary:` |

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

<a id="member-gfdialoguetextcompiler-methods-compile_text"></a>

### `compile_text`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func compile_text(text: String, options: Dictionary = {}) -> Dictionary:
```

编译 JSON 文本。 未知结构字段会作为错误报告；项目扩展数据应放入 metadata 或 payload 字段。 所有语法、schema 和资源图错误都携带 URI fragment JSON Pointer 与 source span； report 是有界 JSON-safe 的本地制作期投影并保留显式 source_path。

参数：

| 名称 | 说明 |
|---|---|
| `text` | UTF-8 strict JSON 文本；object member 必须唯一，整数限 int64，非零浮点的规范化十进制指数限 -307..308。 |
| `options` | 编译选项，支持 source_path、subject、metadata，以及受框架硬上限约束的 max_text_bytes、max_depth、max_nodes、max_string_bytes、max_lines、max_responses 和 max_diagnostics 正整数预算。 |

返回：编译结果。

结构：

- `options`: Dictionary，可包含 source_path、subject、报告 metadata 与严格正整数预算；0、负数、错误类型或超过框架硬上限都会失败关闭。
- `return`: Dictionary，包含 success、resource、report、source_path、content_hash 和 line_count；失败时 resource 为 null 且 line_count 为 0，report 可安全传给 JSON.stringify()。

<a id="member-gfdialoguetextcompiler-methods-compile_source"></a>

### `compile_source`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func compile_source( source_key: String, loader: GFSourceTextLoader, options: Dictionary = {} ) -> Dictionary:
```

通过受根路径约束的源码加载器编译文本。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 注册文本 key 或加载器根目录内的相对路径。 |
| `loader` | 源码文本加载器。 |
| `options` | 编译选项；source_path 会默认使用加载结果路径，预算选项与 compile_text() 相同。loader.max_bytes 必须为正且不大于有效 max_text_bytes，确保读取阶段先受同一上界约束。 |

返回：编译结果。

结构：

- `options`: Dictionary，支持 compile_text() 的选项。
- `return`: Dictionary，包含 success、resource、report、source_path、content_hash 和 line_count；失败时 resource 为 null 且 line_count 为 0，report 可安全传给 JSON.stringify()。
