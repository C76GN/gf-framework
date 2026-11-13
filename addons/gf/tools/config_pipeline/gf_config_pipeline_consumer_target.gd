@tool

## GFConfigPipelineConsumerTarget: 项目声明的配置消费目标。
##
## 根表与每表可见顶层字段均显式列出。字段是完整值单元，包含其结构化类型；
## 不按行内容推测依赖，不通过引用自动授权其他字段。未声明表或字段默认不可见。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFConfigPipelineConsumerTarget
extends Resource


# --- 导出变量 ---

## 项目定义的唯一消费目标名称。
## [br]
## @api public
## [br]
## @since unreleased
@export var target_id: StringName = &""

## 必须纳入该目标的根表；引用闭包从这些表出发。
## [br]
## @api public
## [br]
## @since unreleased
@export var root_tables: PackedStringArray = []

## 各表获准导出的完整顶层字段。引用目标同样必须声明字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema visible_fields: Dictionary[String, PackedStringArray/Array[String]]，每表非空、无重复字段名；最多4096表、每表4096字段、总计65536字段。名称非空、无控制字符、无首尾空白且最多256字符；不支持通配符或嵌套字段路径。
@export var visible_fields: Dictionary = {}

## 该目标数据库的输出 URI；选中目标后替代 Profile 的默认路径。
## [br]
## @api public
## [br]
## @since unreleased
@export var output_path: String = ""

## 该目标的可选访问器输出 URI；空值表示不生成访问器。
## [br]
## @api public
## [br]
## @since unreleased
@export var access_output_path: String = ""


# --- 公共方法 ---

## 验证声明并捕获隔离的纯数据，不读取表或文件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 声明快照或失败原因；输出 URI 由既有输出路径策略在导出前校验。
## [br]
## @schema return: 封闭 Dictionary，success:bool、target:Dictionary、error:String。成功 target 含 target_id:String、root_tables:PackedStringArray（排序）、visible_fields:Dictionary[String,PackedStringArray]（字段排序）、output_path:String、access_output_path:String；失败 target 为空。
func capture() -> Dictionary:
	if (
		not _valid_name(String(target_id))
		or root_tables.is_empty()
		or root_tables.size() > 4096
	):
		return _failure("消费目标需要合法 ID 及1至4096个根表。")
	if visible_fields.is_empty() or visible_fields.size() > 4096:
		return _failure("消费目标需要1至4096个表的字段授权。")
	var roots: PackedStringArray = []
	for table: String in root_tables:
		if (
			not _valid_name(table)
			or table in roots
			or not visible_fields.has(table)
		):
			return _failure("根表重复、名称无效或未声明字段：%s。" % table)
		var _appended: bool = roots.append(table)
	roots.sort()
	var fields: Dictionary = {}
	var field_count: int = 0
	for key: Variant in visible_fields:
		if not key is String:
			return _failure("字段授权必须使用 String 表名。")
		var table_name: String = key
		if not _valid_name(table_name):
			return _failure("字段授权表名无效。")
		var names: PackedStringArray = []
		var raw: Variant = visible_fields[key]
		if raw is PackedStringArray:
			names = raw
		elif raw is Array:
			var values: Array = raw
			if values.size() > 4096:
				return _failure("每表字段数超过4096。")
			for value: Variant in values:
				if not value is String:
					return _failure("字段名必须是 String。")
				var captured_field_name: String = value
				var _appended: bool = names.append(captured_field_name)
		else:
			return _failure("字段授权必须是 PackedStringArray 或 String 数组。")
		if names.is_empty() or names.size() > 4096:
			return _failure("每表必须声明1至4096个字段。")
		var unique: Dictionary = {}
		for field_name: String in names:
			if not _valid_name(field_name) or unique.has(field_name):
				return _failure("字段名无效或重复：%s。" % field_name)
			unique[field_name] = true
		field_count += names.size()
		if field_count > 65536:
			return _failure("消费目标字段总数超过65536。")
		var ordered: PackedStringArray = names.duplicate()
		ordered.sort()
		fields[key] = ordered
	return {
		"success": true,
		"target": {
			"target_id": String(target_id),
			"root_tables": roots,
			"visible_fields": fields,
			"output_path": output_path,
			"access_output_path": access_output_path,
		},
		"error": "",
	}


## 创建独立的作者声明副本，不改变或自动修复无效声明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与当前声明隔离的副本；循环或超出复制预算时返回null。
func duplicate_target() -> GFConfigPipelineConsumerTarget:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new()
	if not budget.admit_value(visible_fields, "consumer.copy"):
		return null
	var result: GFConfigPipelineConsumerTarget = GFConfigPipelineConsumerTarget.new()
	result.target_id = target_id
	result.root_tables = root_tables.duplicate()
	result.visible_fields = visible_fields.duplicate(true)
	result.output_path = output_path
	result.access_output_path = access_output_path
	return result


# --- 私有/辅助方法 ---

## 名称只作精确键，不解释路径或表达式。
## [br]
## @api private
static func _valid_name(value: String) -> bool:
	if (
		value.is_empty()
		or value.length() > 256
		or value != value.strip_edges()
	):
		return false
	for index: int in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true


## 返回无部分声明的失败结果。
## [br]
## @api private
static func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"target": {},
		"error": message,
	}
