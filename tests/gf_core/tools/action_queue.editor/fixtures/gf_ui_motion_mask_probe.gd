# 使用渲染后端实际采样，验证任意方向与原生遮罩纹理可共用一个材质轨道。
extends SceneTree

const _STAGE = preload("res://addons/gf/extensions/action_queue/editor/preview/gf_ui_motion_preview_stage.gd")
const _REVEAL: ShaderMaterial = preload("res://tests/gf_core/extensions/action_queue/fixtures/reveal_material.tres")


func _initialize() -> void:
	call_deferred("_run")


func _frame(stage: _STAGE, seconds: float) -> Image:
	if not stage.player.seek(seconds):
		return null
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	root.size = Vector2i(480, 270)
	var stage: _STAGE = _STAGE.new()
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var effect: GFUIMaterialMotion = GFUIMaterialMotion.new()
	var material: ShaderMaterial = _REVEAL.duplicate() as ShaderMaterial
	effect.material = material
	effect.textures = { &"old_page": &"old_texture", &"new_page": &"new_texture" }
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.target = &"composite"
	track.effect = effect
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [track]
	var mask: GradientTexture2D = GradientTexture2D.new()
	mask.gradient = Gradient.new()
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.80, 0.12)
	mask.fill_to = Vector2(0.4, 0.12)
	material.set_shader_parameter(&"mask_texture", mask)
	var failures: int = 0
	for variant: int in 3:
		material.set_shader_parameter(
			&"direction",
			Vector2.RIGHT if variant == 0 else Vector2(-0.8, 1.35)
		)
		material.set_shader_parameter(
			&"use_mask_texture",
			variant == 2
		)
		if stage.present(recipe, true) != OK or stage.viewport_count() != 2:
			push_error(stage.player.get_diagnostic())
			failures += 1
			break
		var first: Image = await _frame(stage, 0.0)
		var middle: Image = await _frame(
			stage,
			recipe.enter_seconds * 0.5
		)
		var last: Image = await _frame(stage, recipe.enter_seconds)
		if (
			first == null
			or middle == null
			or last == null
		):
			failures += 1
			break
		# The third point distinguishes a radial texture from either straight wipe.
		var points: Array[Vector2] = [
			Vector2(0.8, 0.12),
			Vector2(0.16, 0.86),
			Vector2(0.10, 0.08),
		]
		var shown: Array = [
			[
				false,
				true,
				true,
			],
			[
				true,
				false,
				true,
			],
			[
				true,
				false,
				false,
			],
		][variant]
		for index: int in points.size():
			var pixel: Vector2i = Vector2i(points[index] * Vector2(middle.get_size()))
			var before: Color = first.get_pixelv(pixel)
			var after: Color = last.get_pixelv(pixel)
			if before == after or middle.get_pixelv(pixel) != (after if shown[index] else before):
				push_error(
					"Unexpected mask sample %d, point %d"
					% [variant, index]
				)
				failures += 1
		if variant == 0:
			var composite: CanvasItem = stage._targets[&"composite"]
			var midpoint: float = recipe.enter_seconds * 0.5
			composite.modulate.a = 0.5
			var translucent: Image = await _frame(stage, midpoint)
			var sample_point: Vector2i = Vector2i(points[0] * Vector2(middle.get_size()))
			var endpoints: Array[Color] = [middle.get_pixelv(sample_point), last.get_pixelv(sample_point)]
			if translucent == null or translucent.get_pixelv(sample_point) in endpoints:
				push_error("Half opacity did not blend the reveal with the destination page")
				failures += 1
			composite.modulate.a = 0.0
			var transparent: Image = await _frame(stage, midpoint)
			if transparent == null or transparent.get_data() != last.get_data():
				push_error("CanvasItem opacity did not expose the destination page")
				failures += 1
		stage.player.cancel()
	stage.queue_free()
	await process_frame
	if failures == 0:
		print(
			"GF_UI_MOTION_MASK PASS ",
			RenderingServer.get_current_rendering_method()
		)
	quit(0 if failures == 0 else 1)
