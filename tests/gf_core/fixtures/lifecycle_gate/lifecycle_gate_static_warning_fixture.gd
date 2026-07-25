extends GutTest

const WARNING_CODE: String = "GF lifecycle static-init fixture warning"


static func _static_init() -> void:
	push_warning(WARNING_CODE)


func test_static_warning_fixture_body_passes() -> void:
	assert_true(true, "测试体通过时，static-init warning 仍必须由进程门禁拒绝。")
