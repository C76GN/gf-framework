@tool

## GFSourceBuilder: 编辑器代码生成用的轻量源码构建器。
##
## 用于集中处理生成脚本时的缩进、空行、section 与文档注释格式，
## 避免各个 generator 直接拼接 `PackedStringArray` 时出现格式漂移。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFSourceBuilder
extends RefCounted


# --- 私有变量 ---

var _lines: PackedStringArray = PackedStringArray()
var _indent_level: int = 0


# --- 公共方法 ---

## 添加一行源码。
## [br]
## @api public
## [br]
## @param text: 行内容；空字符串会生成空行且不添加缩进。
func line(text: String = "") -> void:
	if text.is_empty():
		var _push_back_result_34: Variant = _lines.push_back("")
	else:
		var _push_back_result_36: Variant = _lines.push_back("%s%s" % ["\t".repeat(_indent_level), text])


## 添加文档注释行。
## [br]
## @api public
## [br]
## @param text: 注释内容；空字符串会生成 `##`。
func doc(text: String = "") -> void:
	if text.is_empty():
		line("##")
		return
	var normalized_text: String = text.replace("\r\n", "\n").replace("\r", "\n")
	for comment_line: String in normalized_text.split("\n", true):
		if comment_line.is_empty():
			line("##")
		else:
			line("## %s" % comment_line)


## 添加规范 section 标题，并在其后添加一个空行。
## [br]
## @api public
## [br]
## @param title: section 标题。
func section(title: String) -> void:
	line("# --- %s ---" % title)
	blank()


## 添加空行。
## [br]
## @api public
## [br]
## @param count: 空行数量，小于等于 0 时不产生输出。
func blank(count: int = 1) -> void:
	for _index: int in range(maxi(count, 0)):
		var _push_back_result_68: Variant = _lines.push_back("")


## 增加后续行的缩进层级。
## [br]
## @api public
func indent() -> void:
	_indent_level += 1


## 减少后续行的缩进层级。
## [br]
## @api public
## [br]
## @param count: 要减少的层级数，小于等于 0 时不改变缩进。
func dedent(count: int = 1) -> void:
	_indent_level = maxi(_indent_level - maxi(count, 0), 0)


## 清空已构建内容并重置缩进。
## [br]
## @api public
func clear() -> void:
	_lines.clear()
	_indent_level = 0


## 生成最终源码字符串；非空源码末尾会包含换行。
## [br]
## @api public
## [br]
## @return 完整源码文本。
func build() -> String:
	if _lines.is_empty():
		return ""
	return "\n".join(_lines) + "\n"
