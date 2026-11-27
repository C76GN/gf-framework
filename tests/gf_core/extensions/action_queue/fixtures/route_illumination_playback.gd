@tool

# 消费项目的演出控制器。场景提供绘制目标、标题和配方，控制器负责数据与时间。
extends GFUIMotionPlayer


func start_routes(
	surface: Node2D,
	legend: Label,
	data: Resource,
	point_count: int
) -> void:
	if not data is GFUIMotionRecipe:
		push_error("The route scene requires a UI motion recipe")
		return
	var graph: PackedFloat32Array = PackedFloat32Array(
		[
			0,
			2,
			-1,
			-1,
			2,
			0,
			3,
			8,
			-1,
			3,
			0,
			1,
			-1,
			8,
			1,
			0,
		]
	)
	var recipe: GFUIMotionRecipe = data
	var status: Error = play(
		recipe,
		{ &"incoming": surface, &"legend": legend },
		{ &"routes": graph, &"source": 0 }
	)
	if OS.get_cmdline_user_args().has("--verify-motion-export"):
		var valid: bool = status == OK and seek(0.8)
		var colors: PackedColorArray = surface.get_meta(
			&"route_glow",
			PackedColorArray()
		)
		if (
			valid
			and colors.size() == point_count
			and colors[0].a > colors[2].a
			and legend.modulate.a > 0.5
		):
			print("GF_EXTERNAL_MOTION_EXPORT PASS")
			get_tree().quit(0)
		else:
			push_error("Project route or secondary track failed in exported game")
			get_tree().quit(1)


func sample_seconds(seconds: float) -> void:
	if is_active():
		var _positioned: bool = seek(
			clampf(
				seconds,
				0.0,
				get_duration_seconds()
			)
		)
