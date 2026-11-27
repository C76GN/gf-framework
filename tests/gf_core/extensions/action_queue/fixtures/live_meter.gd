@tool

# 业务值与入场演出各自可变。两者之一变化均能刷新当前显示。
extends ProgressBar


# --- 导出变量 ---

## 实际读数，可由项目在任何时刻更新。
## [br]
## @api framework_internal
@export var target_value: float = 82.0:
	set(next):
		target_value = next
		value = lerpf(
			min_value,
			target_value,
			reveal_progress
		)

## 轨道控制的显示比例，抵达终点后持续显示最新读数。
## [br]
## @api framework_internal
@export_range(0, 1, 0.001) var reveal_progress: float = 1.0:
	set(next):
		reveal_progress = clampf(
			next,
			0.0,
			1.0
		)
		value = lerpf(
			min_value,
			target_value,
			reveal_progress
		)
