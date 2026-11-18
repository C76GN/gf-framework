extends SceneTree


func _initialize() -> void:
	var expected_native: bool = OS.get_cmdline_user_args().has("--native")
	var schema: GFDataBatchSchema = GFDataBatchSchema.create(
		&"selection",
		1,
		[&"value"],
		PackedInt32Array([GFDataBatchSchema.NumericType.INT32])
	)
	var publication: GFDataBatchPublication = GFDataBatchPublication.create(
		schema,
		&"probe",
		1,
		4,
		128
	)
	if publication == null or publication.get_debug_snapshot().get("backend_selected") != expected_native:
		push_error("Automatic backend selection disagrees with the installed package.")
		quit(1)
		return
	var result: Error = publication.publish_gather_copy(
		{ &"value": PackedInt32Array([11, 32]) },
		2,
		2,
		PackedInt32Array([1, 0, 1]),
		1,
		1
	)
	if result != OK or publication.get_current().copy_int32_column(0) != PackedInt32Array([32, 11, 32]):
		push_error("Gather through the default publication returned the wrong rows.")
		quit(1)
		return
	publication.close()
	print("GF_NATIVE_SELECTION=native" if expected_native else "GF_NATIVE_SELECTION=script")
	quit()
