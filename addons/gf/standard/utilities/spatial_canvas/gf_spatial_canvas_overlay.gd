extends Control


# --- 私有变量 ---

var _canvas_ref: WeakRef = null


# --- Godot 回调方法 ---

func _draw() -> void:
	if _canvas_ref == null:
		return
	var canvas: Object = _canvas_ref.get_ref()
	if canvas == null or not canvas.has_method("draw_overlay"):
		return
	canvas.call("draw_overlay", self)


# --- 框架内部方法 ---

## 配置拥有绘制状态的 Spatial Canvas。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param canvas: 拥有该内部 overlay 的 Control。
func configure(canvas: Control) -> void:
	_canvas_ref = weakref(canvas)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
