## 测试 GFScriptTypeInspector 的脚本继承链判断。
extends GutTest


# --- 常量 ---

const GFScriptTypeInspectorBase = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")


# --- 辅助类 ---

class BaseScriptForTest extends RefCounted:
	pass


class ChildScriptForTest extends BaseScriptForTest:
	pass


class OtherScriptForTest extends RefCounted:
	pass


# --- 测试方法 ---

## 验证脚本继承判断包含自身和父脚本。
func test_script_extends_or_equals_checks_inheritance_chain() -> void:
	assert_true(
		GFScriptTypeInspectorBase.script_extends_or_equals(ChildScriptForTest, BaseScriptForTest),
		"子脚本应匹配父脚本。"
	)
	assert_true(
		GFScriptTypeInspectorBase.script_extends_or_equals(BaseScriptForTest, BaseScriptForTest),
		"脚本应匹配自身。"
	)
	assert_false(
		GFScriptTypeInspectorBase.script_extends_or_equals(BaseScriptForTest, ChildScriptForTest),
		"父脚本不应匹配子脚本。"
	)
	assert_false(
		GFScriptTypeInspectorBase.script_extends_or_equals(null, BaseScriptForTest),
		"空脚本不应匹配。"
	)


## 验证脚本列表匹配和继承链读取。
func test_script_extends_any_and_inheritance_chain() -> void:
	assert_true(
		GFScriptTypeInspectorBase.script_extends_any(
			ChildScriptForTest,
			[
				null,
				OtherScriptForTest,
				BaseScriptForTest,
			]
		),
		"任一父脚本命中时应返回 true，并忽略非脚本值。"
	)

	var chain: Array[Script] = GFScriptTypeInspectorBase.get_inheritance_chain(ChildScriptForTest)
	assert_eq(
		chain[0],
		ChildScriptForTest,
		"继承链第一项应是输入脚本。"
	)
	assert_true(
		chain.has(BaseScriptForTest),
		"继承链应包含父脚本。"
	)
