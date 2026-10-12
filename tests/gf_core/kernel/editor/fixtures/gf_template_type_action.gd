@tool

# 启用动作的模板声明夹具：非法 type 与合法记录共享同一加载路径。
extends RefCounted


# --- 公共方法 ---

func get_template_records() -> Array[Dictionary]:
	return [
		{
			"source_id": "gf.test.editor:template.type_missing",
			"label": "缺少类型模板",
		},
		{
			"source_id": "gf.test.editor:template.type_empty",
			"type": "",
			"label": "空类型模板",
		},
		{
			"source_id": "gf.test.editor:template.type_whitespace",
			"type": " \t\n ",
			"label": "空白类型模板",
		},
		{
			"source_id": "gf.test.editor:template.type_valid",
			"type": "System",
			"label": "合法扩展模板",
		},
	]
