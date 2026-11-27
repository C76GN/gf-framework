# 可独立运行的消费方样例，航线数据及绘制规则只属于该项目。
extends Node2D

const POINTS: Array[Vector2] = [
	Vector2(0.1, 0.65),
	Vector2(0.36, 0.28),
	Vector2(0.70, 0.6),
	Vector2(0.90, 0.22),
]
const _PLAYBACK = preload("res://tests/gf_core/extensions/action_queue/fixtures/route_illumination_playback.gd")
@export var recipe: Resource
var _playback: _PLAYBACK
var _scale_percent: int = 100


func _ready() -> void:
	_playback = _PLAYBACK.new()
	add_child(_playback)
	var legend: Label = $Legend
	_playback.start_routes(
		self,
		legend,
		recipe,
		POINTS.size()
	)


func configure_ui_review(options: Dictionary) -> void:
	_scale_percent = options.get("scale", 100)


func prepare_ui_review(_options: Dictionary) -> void:
	get_window().content_scale_factor = _scale_percent / 100.0


func sample_ui_review(seconds: float) -> void:
	_playback.sample_seconds(seconds)


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
