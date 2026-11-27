# 可独立运行的消费方样例，航线数据及绘制规则只属于该项目。
extends Node2D

const POINTS: Array[Vector2] = [
	Vector2(0.1, 0.65),
	Vector2(0.36, 0.28),
	Vector2(0.70, 0.6),
	Vector2(0.90, 0.22),
]

@export var recipe: GFUIMotionRecipe

var _scale_percent: int = 100

@onready var _playback: GFUIMotionPlayer = $Playback
@onready var _legend: Label = $Legend


func _ready() -> void:
	var graph: PackedFloat32Array = PackedFloat32Array([
		0, 2, -1, -1,
		2, 0, 3, 8,
		-1, 3, 0, 1,
		-1, 8, 1, 0,
	])
	var status: Error = _playback.play(
		recipe,
		{ &"incoming": self, &"legend": _legend },
		{ &"routes": graph, &"source": 0 }
	)
	if OS.get_cmdline_user_args().has("--verify-motion-export"):
		_verify_export(status)


func configure_ui_review(options: Dictionary) -> void:
	_scale_percent = options.get("scale", 100)


func prepare_ui_review(_options: Dictionary) -> void:
	get_window().content_scale_factor = _scale_percent / 100.0


func sample_ui_review(seconds: float) -> void:
	if _playback.is_active():
		var _positioned: bool = _playback.seek(
			clampf(seconds, 0.0, _playback.get_duration_seconds())
		)


func _verify_export(status: Error) -> void:
	var sampled: bool = status == OK and _playback.seek(0.8)
	var colors: PackedColorArray = get_meta(&"route_glow", PackedColorArray())
	if (
		sampled
		and colors.size() == POINTS.size()
		and colors[0].a > colors[2].a
		and _legend.modulate.a > 0.5
	):
		print("GF_EXTERNAL_MOTION_EXPORT PASS")
		get_tree().quit(0)
	else:
		push_error("Project route or secondary track failed in exported game")
		get_tree().quit(1)


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	var colors: PackedColorArray = get_meta(
		&"route_glow",
		PackedColorArray()
	)
	for edge: Vector2i in [
		Vector2i(0, 1),
		Vector2i(1, 2),
		Vector2i(1, 3),
		Vector2i(2, 3),
	]:
		draw_line(
			POINTS[edge.x] * view,
			POINTS[edge.y] * view,
			Color("#334a60"),
			3.0,
			true
		)
		if colors.size() == POINTS.size():
			draw_line(
				POINTS[edge.x] * view,
				POINTS[edge.x].lerp(
					POINTS[edge.y],
					colors[edge.y].a
				) * view,
				Color("#91e7cc"),
				3.0,
				true
			)
	for i: int in POINTS.size():
		draw_circle(
			POINTS[i] * view,
			7.0,
			colors[i] if colors.size() == POINTS.size() else Color.GRAY
		)
