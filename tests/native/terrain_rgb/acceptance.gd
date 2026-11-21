extends RefCounted

# Exercise the same public decoder in portable, upgraded and exported projects.
static func check(expect_native: bool) -> Array[String]:
	var failures: Array[String] = []
	if Engine.has_singleton(&"GfTerrainRgbBackend") != expect_native:
		failures.append("Unexpected installed Terrain-RGB capability.")
		return failures
	for format: Image.Format in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8, Image.FORMAT_RGBF]:
		var image: Image = Image.create(5, 3, false, format)
		var expected: PackedFloat32Array = PackedFloat32Array()
		for y: int in range(3):
			for x: int in range(5):
				var i: int = y * 5 + x
				image.set_pixel(x, y, Color8(i * 17, 255 - i * 13, i * 7, i * 11))
				var _appended: bool = expected.append(GFHeightfield3D.decode_terrain_rgb_height(image.get_pixel(x, y)) * -1.25 + 17.0)
		if image.generate_mipmaps() != OK:
			failures.append("Failed to create Terrain-RGB mipmaps.")
			continue
		var options: Dictionary = {"height_scale": -1.25, "height_offset": 17.0}
		var decode: Callable = GFHeightfield3D.samples_from_terrain_rgb_image.bind(image, options)
		var report: Dictionary = decode.call()
		var worker: Thread = Thread.new()
		if worker.start(decode) != OK:
			failures.append("Failed to start Terrain-RGB worker.")
			continue
		var threaded: Variant = worker.wait_to_finish()
		if report != threaded or not report.get("ok", false) or report.get("samples") != expected:
			failures.append("Terrain-RGB main and worker reports must match the pixel oracle.")
		expected.sort()
		if report.get("min_height") != expected[0] or report.get("max_height") != expected[-1]:
			failures.append("Terrain-RGB stored extrema differ.")
	var extreme: Image = Image.create_from_data(2, 1, false, Image.FORMAT_RGB8, PackedByteArray([1, 134, 160, 255, 255, 255]))
	for entry: Array in [[1.0e35, "unrepresentable_height"], [1.0e308, "non_finite_height"]]:
		var invalid: Dictionary = GFHeightfield3D.samples_from_terrain_rgb_image(extreme, {"height_scale": entry[0]})
		var samples: PackedFloat32Array = invalid["samples"]
		var issues: Array = invalid["issues"]
		if invalid["ok"] or invalid["sample_count"] != 0 or not samples.is_empty() or issues.size() != 1 or issues[0]["kind"] != entry[1]:
			failures.append("Terrain-RGB overflow must preserve the public error and discard partial output.")
	if expect_native:
		var backend: Object = Engine.get_singleton(&"GfTerrainRgbBackend")
		if backend.call(&"protocol_version") != 1:
			failures.append("Unexpected Terrain-RGB protocol version.")
		var base: PackedByteArray = PackedByteArray([0, 0, 0, 93, 1, 134, 160, 255, 128, 21, 36, 44])
		var values: Variant = backend.call(&"decode", base, Vector2i(2, 1), 4, -0.5, 1.0)
		if values != [PackedFloat32Array([5001.0, 1.0]), 1.0, 5001.0]:
			failures.append("Terrain-RGB service must decode base pixels and return stored extrema.")
		var short_input: Variant = backend.call(&"decode", PackedByteArray([1]), Vector2i.ONE, 3, 1.0, 0.0)
		if short_input != []:
			failures.append("Terrain-RGB accepted truncated input.")
	return failures
