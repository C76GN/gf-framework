# 对实际安装的双页材质做像素回归。参数为消费项目中的材质资源路径。
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _page(first: Color, last: Color) -> GradientTexture2D:
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([first, last])
	texture.fill_to = Vector2(0.85, 0.20)
	return texture


func _pixels() -> PackedByteArray:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_data()


func _run() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Pass installed ShaderMaterial paths after -- and use a graphical renderer.")
		quit(2)
		return
	root.size = Vector2i(240, 144)
	var background: TextureRect = TextureRect.new()
	root.add_child(background)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var composite: ColorRect = ColorRect.new()
	root.add_child(composite)
	composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	composite.hide()
	var player: GFUIMotionPlayer = GFUIMotionPlayer.new()
	root.add_child(player)
	var old_page: Texture2D = _page(Color.CORAL, Color.DARK_BLUE)
	var new_page: Texture2D = _page(Color.DARK_CYAN, Color.WHEAT)
	background.texture = old_page
	var first: PackedByteArray = await _pixels()
	background.texture = new_page
	var last: PackedByteArray = await _pixels()
	var failed: bool = false
	for path: String in paths:
		var effect: GFUIMaterialMotion = GFUIMaterialMotion.new()
		effect.material = load(path) as ShaderMaterial
		effect.textures = { &"old_page": &"old", &"new_page": &"new" }
		var track: GFUIMotionTrack = GFUIMotionTrack.new()
		track.target = &"surface"
		track.effect = effect
		var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
		recipe.tracks = [track]
		if player.play(
			recipe,
			{ &"surface": composite },
			{ &"old": old_page, &"new": new_page },
			true
		) != OK:
			push_error(
				"%s: %s"
				% [path, player.get_diagnostic()]
			)
			failed = true
			continue
		var start: PackedByteArray = await _pixels()
		var end_ok: bool = player.seek(recipe.enter_seconds)
		var end: PackedByteArray = await _pixels()
		var mid_ok: bool = player.seek(recipe.enter_seconds * 0.42)
		var middle: PackedByteArray = await _pixels()
		composite.modulate.a = 0.0
		var transparent: PackedByteArray = await _pixels()
		composite.modulate.a = 1.0
		player.cancel()
		if (
			not end_ok
			or not mid_ok
			or start != first
			or end != last
			or middle == first
			or middle == last
			or transparent != last
			or composite.material != null
			or composite.visible
		):
			push_error("Pixel or cancellation mismatch: " + path)
			failed = true
	if not failed:
		print(
			"GF_UI_MOTION_ASSETS PASS ",
			RenderingServer.get_current_rendering_method(),
			" ",
			paths.size()
		)
	quit(1 if failed else 0)
