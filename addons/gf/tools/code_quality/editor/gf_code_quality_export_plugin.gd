@tool

# 代码检查工具只服务编辑器和制作期命令；导出游戏时排除自己的源码与预设。
extends EditorExportPlugin


# --- 常量 ---

## 只匹配本工具目录，避免改变其他工具或项目文件的导出策略。
## [br]
## @api private
const _TOOL_ROOT: String = "res://addons/gf/tools/code_quality/"


# --- Godot 回调方法 ---

## 为本工具的导出过滤器提供稳定身份。
## [br]
## @api private
func _get_name() -> String:
	return "GFCodeQualityExportPlugin"


## 排除本工具自有文件；不读取、分析或重写待导出的项目内容。
## [br]
## @api private
func _export_file(
	path: String,
	_type: String,
	_features: PackedStringArray
) -> void:
	if path.begins_with(_TOOL_ROOT):
		skip()
