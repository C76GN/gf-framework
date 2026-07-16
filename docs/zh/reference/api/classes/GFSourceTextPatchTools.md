# GFSourceTextPatchTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/text/gf_source_text_patch_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

源码文本范围补丁工具。 用于把编辑器工具、生成器或迁移脚本产生的 line/character 范围 edit 应用到 单个文本字符串。范围形状可与 LSP text edit 相同，但 character 使用 Godot String 字符索引，不是 LSP UTF-16 code unit 坐标。该类只处理纯文本和结构化报告， 不写文件、不调用 LSP、不扫描项目，也不解释重命名、符号或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ERROR_INVALID_EDIT`](#member-gfsourcetextpatchtools-constants-error_invalid_edit) | `const ERROR_INVALID_EDIT: StringName = &"invalid_edit"` |
| 常量 | [`ERROR_RANGE_OUT_OF_BOUNDS`](#member-gfsourcetextpatchtools-constants-error_range_out_of_bounds) | `const ERROR_RANGE_OUT_OF_BOUNDS: StringName = &"range_out_of_bounds"` |
| 常量 | [`ERROR_INVALID_RANGE`](#member-gfsourcetextpatchtools-constants-error_invalid_range) | `const ERROR_INVALID_RANGE: StringName = &"invalid_range"` |
| 常量 | [`ERROR_OVERLAPPING_EDITS`](#member-gfsourcetextpatchtools-constants-error_overlapping_edits) | `const ERROR_OVERLAPPING_EDITS: StringName = &"overlapping_edits"` |
| 方法 | [`make_range`](#member-gfsourcetextpatchtools-methods-make_range) | `static func make_range( start_line: int, start_character: int, end_line: int, end_character: int ) -> Dictionary:` |
| 方法 | [`make_replacement_edit`](#member-gfsourcetextpatchtools-methods-make_replacement_edit) | `static func make_replacement_edit( start_line: int, start_character: int, end_line: int, end_character: int, text: String, metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`validate_text_edits`](#member-gfsourcetextpatchtools-methods-validate_text_edits) | `static func validate_text_edits(source_text: String, edits: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_text_edits`](#member-gfsourcetextpatchtools-methods-apply_text_edits) | `static func apply_text_edits(source_text: String, edits: Array, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfsourcetextpatchtools-constants-error_invalid_edit"></a>

### `ERROR_INVALID_EDIT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_INVALID_EDIT: StringName = &"invalid_edit"
```

edit 记录结构无效。

<a id="member-gfsourcetextpatchtools-constants-error_range_out_of_bounds"></a>

### `ERROR_RANGE_OUT_OF_BOUNDS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_RANGE_OUT_OF_BOUNDS: StringName = &"range_out_of_bounds"
```

edit 范围越过文本行或列边界。

<a id="member-gfsourcetextpatchtools-constants-error_invalid_range"></a>

### `ERROR_INVALID_RANGE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_INVALID_RANGE: StringName = &"invalid_range"
```

edit 起点在终点之后。

<a id="member-gfsourcetextpatchtools-constants-error_overlapping_edits"></a>

### `ERROR_OVERLAPPING_EDITS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ERROR_OVERLAPPING_EDITS: StringName = &"overlapping_edits"
```

edit 范围互相重叠或同一位置存在顺序不明确的插入。

## 方法

<a id="member-gfsourcetextpatchtools-methods-make_range"></a>

### `make_range`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_range( start_line: int, start_character: int, end_line: int, end_character: int ) -> Dictionary:
```

构建零基 line/character 范围字典。 character 按 Godot String 字符索引计算，不是 UTF-8 字节偏移，也不是 LSP UTF-16 code unit。

参数：

| 名称 | 说明 |
|---|---|
| `start_line` | 起始行，零基。 |
| `start_character` | 起始列，零基。 |
| `end_line` | 结束行，零基。 |
| `end_character` | 结束列，零基。 |

返回：范围字典。

结构：

- `return`: Dictionary，包含 start/end 位置字典。

<a id="member-gfsourcetextpatchtools-methods-make_replacement_edit"></a>

### `make_replacement_edit`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_replacement_edit( start_line: int, start_character: int, end_line: int, end_character: int, text: String, metadata: Dictionary = {} ) -> Dictionary:
```

构建替换 edit 字典。

参数：

| 名称 | 说明 |
|---|---|
| `start_line` | 起始行，零基。 |
| `start_character` | 起始列，零基。 |
| `end_line` | 结束行，零基。 |
| `end_character` | 结束列，零基。 |
| `text` | 替换文本；空字符串表示删除。 |
| `metadata` | 调用方元数据。 |

返回：edit 字典。

结构：

- `metadata`: Dictionary copied into the edit metadata field.
- `return`: Dictionary，包含 range、text 和 metadata。

<a id="member-gfsourcetextpatchtools-methods-validate_text_edits"></a>

### `validate_text_edits`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func validate_text_edits(source_text: String, edits: Array, options: Dictionary = {}) -> Dictionary:
```

校验文本 edit 集合。 支持 `range.start.line/character` + `range.end.line/character` 与扁平 `start_line/start_character/end_line/end_character` 两种范围写法。该范围是 LSP-shaped， 但 character 使用 Godot String 字符索引。替换文本可使用 `text`、`newText`、 `new_text` 或 `replacement` 字段。

参数：

| 名称 | 说明 |
|---|---|
| `source_text` | 原始文本。 |
| `edits` | edit 字典数组。 |
| `options` | 校验选项，支持 include_edits 和 metadata。 |

返回：校验报告。

结构：

- `edits`: Array of Dictionary text edits.
- `options`: Dictionary，可包含 include_edits 和 metadata。
- `return`: Dictionary，包含 ok、error、edit_count、valid_edit_count、line_count、issues、issue_count、source_sha256、metadata 和可选 edits。

<a id="member-gfsourcetextpatchtools-methods-apply_text_edits"></a>

### `apply_text_edits`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func apply_text_edits(source_text: String, edits: Array, options: Dictionary = {}) -> Dictionary:
```

应用文本 edit 集合。 edit 会先按原始文本范围校验并按 offset 倒序应用，因此调用方不需要预先排序。 范围字段可使用 LSP-shaped 字典，但 character 始终是 Godot String 字符索引。 如果存在越界、重叠或结构错误，返回 ok=false，text 保持为原始文本。

参数：

| 名称 | 说明 |
|---|---|
| `source_text` | 原始文本。 |
| `edits` | edit 字典数组。 |
| `options` | 应用选项，支持 include_edits 和 metadata。 |

返回：应用报告。

结构：

- `edits`: Array of Dictionary text edits.
- `options`: Dictionary，可包含 include_edits 和 metadata。
- `return`: Dictionary，包含 ok、error、text、changed、edit_count、applied_count、line_count、issues、issue_count、source_sha256、result_sha256、metadata 和可选 edits。
