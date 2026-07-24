extends "res://tests/gf_core/support/gf_gut_post_run_hook.gd"

const WARNING_CODE: String = "GF lifecycle terminal fixture warning"
const DELAY_FRAME_COUNT: int = 4


func run() -> void:
	var _post_snapshot_result: Variant = await super.run()
	if not gut is GutMain:
		return
	var gut_main: GutMain = gut
	for _frame_index: int in range(DELAY_FRAME_COUNT):
		await gut_main.get_tree().process_frame
	push_warning(WARNING_CODE)
