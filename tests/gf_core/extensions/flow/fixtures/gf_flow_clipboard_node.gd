@tool
extends GFFlowNode


# --- 导出变量 ---

@export var payload: Dictionary = {"label": "Template", "weights": [1, 2]}


# --- 私有变量 ---

var query_count: int = 0


# --- 可重写钩子 / 虚方法 ---

func get_display_name() -> String:
	query_count += 1
	return "Business display query must not run while copying"
