@tool

# 保留源文本，在真实显示层根据局部进度确定字符，不使用全局随机状态。
extends Label


# --- 导出变量 ---

## 实际业务文本，采样时始终从该文本计算。
## [br]
## @api framework_internal
@export var source_text: String = "FLIGHT 204":
	set(value):
		source_text = value
		_refresh()

## 输入的局部进度。终点显示当下源文本。
## [br]
## @api framework_internal
@export var decode_progress: float = 1.0:
	set(value):
		decode_progress = clampf(
			value,
			0.0,
			1.0
		)
		_refresh()


# --- 私有/辅助方法 ---

## 源文本和轨道进度都通过此处计算显示结果。
## [br]
## @api private
func _refresh() -> void:
	var glyphs: String = "0123456789ABCDEF"
	var locked: int = floori(source_text.length() * decode_progress)
	var rendered: String = source_text.left(locked)
	for index: int in range(
		locked,
		source_text.length()
	):
		var original: String = source_text[index]
		if original == " ":
			rendered += original
		else:
			rendered += glyphs[(index * 7 + floori(decode_progress * 13) + source_text.unicode_at(index)) % glyphs.length()]
	text = rendered
