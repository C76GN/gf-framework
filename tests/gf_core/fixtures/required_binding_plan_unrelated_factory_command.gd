## Required binding plan identity 测试使用的不相关 factory command。
extends GFCommand


# --- 公共变量 ---

var dispose_count: int = 0


# --- 公共方法 ---

func dispose() -> void:
	dispose_count += 1
