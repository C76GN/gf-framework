# Shares generator output I/O while each suite owns hook registration, reset and assertions.
extends RefCounted


# --- 框架内部方法 ---

static func overwrite_committed_output(test_case: GutTest, output_path: String) -> void:
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	test_case.assert_not_null(file, "post-commit fixture 必须能改写已提交目标。")
	if file == null:
		return
	var _store_string_result: Variant = file.store_string("external-post-commit-change")
	file.close()


static func remove_generated_file(test_case: GutTest, path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	test_case.assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path)),
		OK,
		"测试必须清理生成器输出。"
	)
