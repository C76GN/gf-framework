# GFDelimitedTextTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/text/gf_delimited_text_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

顶层分隔符扫描工具。 用于把函数参数、轻量命令或配置片段按分隔符拆分，同时忽略引号与括号内的分隔符。 该类只做纯文本扫描，不解释 SQL、表达式、对象方法或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DELIMITER_MODE_LITERAL`](#member-gfdelimitedtexttools-constants-delimiter_mode_literal) | `const DELIMITER_MODE_LITERAL: StringName = &"literal"` |
| 常量 | [`DELIMITER_MODE_WHITESPACE`](#member-gfdelimitedtexttools-constants-delimiter_mode_whitespace) | `const DELIMITER_MODE_WHITESPACE: StringName = &"whitespace"` |
| 常量 | [`ERROR_INVALID_DELIMITER`](#member-gfdelimitedtexttools-constants-error_invalid_delimiter) | `const ERROR_INVALID_DELIMITER: StringName = &"invalid_delimiter"` |
| 常量 | [`ERROR_UNMATCHED_CLOSING`](#member-gfdelimitedtexttools-constants-error_unmatched_closing) | `const ERROR_UNMATCHED_CLOSING: StringName = &"unmatched_closing"` |
| 常量 | [`ERROR_UNMATCHED_OPENING`](#member-gfdelimitedtexttools-constants-error_unmatched_opening) | `const ERROR_UNMATCHED_OPENING: StringName = &"unmatched_opening"` |
| 方法 | [`find_top_level_delimiters`](#member-gfdelimitedtexttools-methods-find_top_level_delimiters) | `static func find_top_level_delimiters(text: String, delimiter: String = _DEFAULT_DELIMITER, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`split_top_level`](#member-gfdelimitedtexttools-methods-split_top_level) | `static func split_top_level(text: String, delimiter: String = _DEFAULT_DELIMITER, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfdelimitedtexttools-constants-delimiter_mode_literal"></a>

### `DELIMITER_MODE_LITERAL`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DELIMITER_MODE_LITERAL: StringName = &"literal"
```

按字面量分隔符扫描。

<a id="member-gfdelimitedtexttools-constants-delimiter_mode_whitespace"></a>

### `DELIMITER_MODE_WHITESPACE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DELIMITER_MODE_WHITESPACE: StringName = &"whitespace"
```

按连续空白字符扫描分隔符；空白字符包括空格、制表、换行和回车。

<a id="member-gfdelimitedtexttools-constants-error_invalid_delimiter"></a>

### `ERROR_INVALID_DELIMITER`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_INVALID_DELIMITER: StringName = &"invalid_delimiter"
```

分隔符为空。

<a id="member-gfdelimitedtexttools-constants-error_unmatched_closing"></a>

### `ERROR_UNMATCHED_CLOSING`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_UNMATCHED_CLOSING: StringName = &"unmatched_closing"
```

遇到没有匹配开启符的关闭符。

<a id="member-gfdelimitedtexttools-constants-error_unmatched_opening"></a>

### `ERROR_UNMATCHED_OPENING`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_UNMATCHED_OPENING: StringName = &"unmatched_opening"
```

扫描结束时仍有未关闭的引号或括号。

## 方法

<a id="member-gfdelimitedtexttools-methods-find_top_level_delimiters"></a>

### `find_top_level_delimiters`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func find_top_level_delimiters(text: String, delimiter: String = _DEFAULT_DELIMITER, options: Dictionary = {}) -> Dictionary:
```

查找顶层分隔符位置。 分隔符只有在不处于 quote_chars 或 pairs 管理的嵌套区间内时才会被记录。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 要扫描的文本。 |
| `delimiter` | 字面量分隔符；delimiter_mode 为 whitespace 时会被忽略。 |
| `options` | 可选扫描配置。 |

返回：扫描报告。

结构：

- `options`: Dictionary，可包含 delimiter_mode、quote_chars、escape_char 和 pairs。
- `return`: Dictionary，包含 ok、error、delimiter_mode、delimiter、delimiter_spans、issues 和 issue_count。

<a id="member-gfdelimitedtexttools-methods-split_top_level"></a>

### `split_top_level`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func split_top_level(text: String, delimiter: String = _DEFAULT_DELIMITER, options: Dictionary = {}) -> Dictionary:
```

按顶层分隔符拆分文本。 分隔符出现在引号、圆括号、方括号或花括号内时不会触发拆分。调用方可通过 pairs 或 quote_chars 改写扫描规则。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 要拆分的文本。 |
| `delimiter` | 字面量分隔符；delimiter_mode 为 whitespace 时会被忽略。 |
| `options` | 可选拆分配置。 |

返回：拆分报告。

结构：

- `options`: Dictionary，可包含 delimiter_mode、trim_parts、allow_empty、quote_chars、escape_char 和 pairs。
- `return`: Dictionary，包含 ok、error、delimiter_mode、delimiter、parts、part_spans、delimiter_spans、issues 和 issue_count。
