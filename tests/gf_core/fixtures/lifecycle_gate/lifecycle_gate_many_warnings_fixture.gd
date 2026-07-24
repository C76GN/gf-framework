extends GutTest

const WARNING_COUNT: int = 25


static func _static_init() -> void:
	var long_warning_suffix: String = "界".repeat(600)
	for warning_index: int in range(WARNING_COUNT):
		push_warning(
			"GF lifecycle bounded warning %02d: %s"
			% [warning_index, long_warning_suffix]
		)


func test_many_warnings_fixture_body_passes() -> void:
	assert_true(true, "超量 warning 的测试体可以通过，但门禁证据必须失败并截断。")
