# GFRichTextFormatter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_rich_text_formatter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用 RichTextLabel BBCode 格式化辅助。 提供安全转义、Markdown 子集转 BBCode、变量占位符替换和可配置 token 替换。 该类不加载任何资源，不规定文本来源、语言、本地化、图标集或 UI 展示规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`MARKUP_BBCODE`](#member-gfrichtextformatter-constants-markup_bbcode) | `const MARKUP_BBCODE: StringName = &"bbcode"` |
| 常量 | [`MARKUP_PLAIN`](#member-gfrichtextformatter-constants-markup_plain) | `const MARKUP_PLAIN: StringName = &"plain"` |
| 常量 | [`MARKUP_MARKDOWN`](#member-gfrichtextformatter-constants-markup_markdown) | `const MARKUP_MARKDOWN: StringName = &"markdown"` |
| 方法 | [`to_bbcode`](#member-gfrichtextformatter-methods-to_bbcode) | `static func to_bbcode(text: String, options: Dictionary = {}) -> String:` |
| 方法 | [`markdown_to_bbcode`](#member-gfrichtextformatter-methods-markdown_to_bbcode) | `static func markdown_to_bbcode(text: String) -> String:` |
| 方法 | [`replace_variables`](#member-gfrichtextformatter-methods-replace_variables) | `static func replace_variables( text: String, variables: Dictionary = {}, resolver: Callable = Callable(), options: Dictionary = {} ) -> String:` |
| 方法 | [`replace_tokens`](#member-gfrichtextformatter-methods-replace_tokens) | `static func replace_tokens(text: String, resolver: Callable, options: Dictionary = {}) -> String:` |
| 方法 | [`escape_bbcode`](#member-gfrichtextformatter-methods-escape_bbcode) | `static func escape_bbcode(text: String) -> String:` |
| 方法 | [`strip_bbcode`](#member-gfrichtextformatter-methods-strip_bbcode) | `static func strip_bbcode(text: String) -> String:` |

## 常量

<a id="member-gfrichtextformatter-constants-markup_bbcode"></a>

### `MARKUP_BBCODE`

- API：`public`

```gdscript
const MARKUP_BBCODE: StringName = &"bbcode"
```

BBCode 输入模式。

<a id="member-gfrichtextformatter-constants-markup_plain"></a>

### `MARKUP_PLAIN`

- API：`public`

```gdscript
const MARKUP_PLAIN: StringName = &"plain"
```

普通文本输入模式，会先转义 BBCode 控制字符。

<a id="member-gfrichtextformatter-constants-markup_markdown"></a>

### `MARKUP_MARKDOWN`

- API：`public`

```gdscript
const MARKUP_MARKDOWN: StringName = &"markdown"
```

Markdown 子集输入模式，会转换为 RichTextLabel BBCode。

## 方法

<a id="member-gfrichtextformatter-methods-to_bbcode"></a>

### `to_bbcode`

- API：`public`

```gdscript
static func to_bbcode(text: String, options: Dictionary = {}) -> String:
```

格式化文本为 RichTextLabel 可用的 BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 原始文本。 |
| `options` | 可选设置，支持 markup、variables、variable_resolver、variable_prefix、variable_suffix、token_resolver、token_prefix、token_suffix。 |

返回：BBCode 文本。

结构：

- `options`: Dictionary，支持 markup、variables、variable_resolver、variable_prefix、variable_suffix、escape_variable_values、missing_variable_text、token_resolver、token_prefix、token_suffix、escape_token_values。

<a id="member-gfrichtextformatter-methods-markdown_to_bbcode"></a>

### `markdown_to_bbcode`

- API：`public`

```gdscript
static func markdown_to_bbcode(text: String) -> String:
```

把常见 Markdown 子集转换为 RichTextLabel BBCode。

参数：

| 名称 | 说明 |
|---|---|
| `text` | Markdown 文本。 |

返回：BBCode 文本。

<a id="member-gfrichtextformatter-methods-replace_variables"></a>

### `replace_variables`

- API：`public`

```gdscript
static func replace_variables( text: String, variables: Dictionary = {}, resolver: Callable = Callable(), options: Dictionary = {} ) -> String:
```

替换变量占位符。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 输入文本。 |
| `variables` | 变量字典。 |
| `resolver` | 可选变量解析回调，签名为 func(name: String) -> Variant。 |
| `options` | 可选设置，支持 variable_prefix、variable_suffix、escape_variable_values、missing_variable_text。 |

返回：替换后的文本。

结构：

- `variables`: Dictionary，key 为变量名 String，value 为会转成文本的任意值。
- `options`: Dictionary，支持 variable_prefix、variable_suffix、escape_variable_values、missing_variable_text。

<a id="member-gfrichtextformatter-methods-replace_tokens"></a>

### `replace_tokens`

- API：`public`

```gdscript
static func replace_tokens(text: String, resolver: Callable, options: Dictionary = {}) -> String:
```

替换可配置 token，例如 `:icon_id:`。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 输入文本。 |
| `resolver` | token 解析回调，签名为 func(token: String) -> String。 |
| `options` | 可选设置，支持 token_prefix、token_suffix、escape_token_values。 |

返回：替换后的文本。

结构：

- `options`: Dictionary，支持 token_prefix、token_suffix、escape_token_values。

<a id="member-gfrichtextformatter-methods-escape_bbcode"></a>

### `escape_bbcode`

- API：`public`

```gdscript
static func escape_bbcode(text: String) -> String:
```

转义 BBCode 控制字符。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 输入文本。 |

返回：可安全嵌入 BBCode 的文本。

<a id="member-gfrichtextformatter-methods-strip_bbcode"></a>

### `strip_bbcode`

- API：`public`

```gdscript
static func strip_bbcode(text: String) -> String:
```

移除 BBCode 标签。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 输入文本。 |

返回：去掉标签后的文本。
