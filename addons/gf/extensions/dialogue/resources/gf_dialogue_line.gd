## GFDialogueLine: 通用对话流程行。
##
## 行可以表示可展示文本、跳转、mutation 请求或结束点。它不规定剧本语法、
## 对话框 UI、角色表或项目状态字段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFDialogueLine
extends Resource


# --- 枚举 ---

## 对话行类型。
## [br]
## @api public
enum LineKind {
	## 可展示文本行。
	TEXT,
	## 请求执行上下文 mutation 后继续。
	MUTATION,
	## 直接跳转到另一行。
	JUMP,
	## 结束当前对话。
	END,
}


# --- 导出变量 ---

## 行 ID。
## [br]
## @api public
@export var line_id: StringName = &""

## 行类型。
## [br]
## @api public
@export var kind: LineKind = LineKind.TEXT

## 说话者 ID 或项目自定义主体键。
## [br]
## @api public
@export var speaker_id: StringName = &""

## 文本或项目自定义文本键。
## [br]
## @api public
@export_multiline var text: String = ""

## 默认后继行 ID。
## [br]
## @api public
@export var next_line_id: StringName = &""

## 跳转行 ID。`kind == JUMP` 时优先使用。
## [br]
## @api public
@export var jump_line_id: StringName = &""

## 条件 ID。为空表示不需要条件判断。
## [br]
## @api public
@export var condition_id: StringName = &""

## 条件载荷。框架只透传给上下文处理器。
## [br]
## @api public
## [br]
## @schema condition_payload: 条件处理器接收的任意项目载荷；框架只透传，不解释其中结构。
@export var condition_payload: Variant = null

## 条件不通过时的后继行 ID。为空时由 Runner 按策略跳过或结束。
## [br]
## @api public
@export var fallback_line_id: StringName = &""

## mutation ID。`kind == MUTATION` 时由 Runner 请求上下文处理。
## [br]
## @api public
@export var mutation_id: StringName = &""

## mutation 载荷。框架只透传给上下文处理器。
## [br]
## @api public
## [br]
## @schema mutation_payload: mutation 处理器接收的任意项目载荷；框架只透传，不解释其中结构。
@export var mutation_payload: Variant = null

## 响应选项。
## [br]
## @api public
@export var responses: Array[GFDialogueResponse] = []

## 语义标签。框架不解释标签含义。
## [br]
## @api public
@export var tags: PackedStringArray = PackedStringArray()

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查行是否有响应。
## [br]
## @api public
## [br]
## @return: 存在响应时返回 true。
func has_responses() -> bool:
	for response: GFDialogueResponse in responses:
		if response != null:
			return true
	return false


## 获取可用响应。
## [br]
## @api public
## [br]
## @param context: 对话上下文。
## [br]
## @return: 可用响应列表。
func get_available_responses(context: GFDialogueContext = null) -> Array[GFDialogueResponse]:
	var result: Array[GFDialogueResponse] = []
	for response: GFDialogueResponse in responses:
		if response != null and response.is_available(context):
			result.append(response)
	return result


## 按 ID 获取响应。
## [br]
## @api public
## [br]
## @param response_id: 响应 ID。
## [br]
## @return: 响应；不存在时返回 null。
func get_response(response_id: StringName) -> GFDialogueResponse:
	for response: GFDialogueResponse in responses:
		if response != null and response.response_id == response_id:
			return response
	return null


## 检查行是否可进入。
## [br]
## @api public
## [br]
## @param context: 对话上下文。
## [br]
## @return: 可进入时返回 true。
func can_enter(context: GFDialogueContext) -> bool:
	if condition_id == &"":
		return true
	if context == null:
		return false
	return GFVariantData.get_option_bool(context.check_condition(condition_id, condition_payload, self), "ok", false)


## 获取默认后继行 ID。
## [br]
## @api public
## [br]
## @return: 后继行 ID。
func get_default_next_line_id() -> StringName:
	if kind == LineKind.JUMP and jump_line_id != &"":
		return jump_line_id
	return next_line_id


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return: 行副本。
func duplicate_line() -> GFDialogueLine:
	var line: GFDialogueLine = _get_dialogue_line_value(duplicate(true))
	return line if line != null else GFDialogueLine.new()


## 转换为字典。
## [br]
## @api public
## [br]
## @return: 行快照。
## [br]
## @schema return: 包含 line_id、kind、speaker_id、text、next_line_id、jump_line_id、condition_id、condition_payload、fallback_line_id、mutation_id、mutation_payload、responses、tags 和 metadata 字段的 Dictionary。
func to_dictionary() -> Dictionary:
	var response_data: Array[Dictionary] = []
	for response: GFDialogueResponse in responses:
		if response != null:
			response_data.append(response.to_dictionary())

	return {
		"line_id": line_id,
		"kind": kind,
		"speaker_id": speaker_id,
		"text": text,
		"next_line_id": next_line_id,
		"jump_line_id": jump_line_id,
		"condition_id": condition_id,
		"condition_payload": _duplicate_snapshot_value(condition_payload),
		"fallback_line_id": fallback_line_id,
		"mutation_id": mutation_id,
		"mutation_payload": _duplicate_snapshot_value(mutation_payload),
		"responses": response_data,
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _get_dialogue_line_value(value: Variant) -> GFDialogueLine:
	if value is GFDialogueLine:
		var line: GFDialogueLine = value
		return line
	return null


func _duplicate_snapshot_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	if value is Array:
		var array: Array = value
		return array.duplicate(true)
	if value is PackedStringArray:
		var string_array: PackedStringArray = value
		return string_array.duplicate()
	if value is PackedByteArray:
		var byte_array: PackedByteArray = value
		return byte_array.duplicate()
	if value is PackedInt32Array:
		var int32_array: PackedInt32Array = value
		return int32_array.duplicate()
	if value is PackedInt64Array:
		var int64_array: PackedInt64Array = value
		return int64_array.duplicate()
	if value is PackedFloat32Array:
		var float32_array: PackedFloat32Array = value
		return float32_array.duplicate()
	if value is PackedFloat64Array:
		var float64_array: PackedFloat64Array = value
		return float64_array.duplicate()
	if value is PackedVector2Array:
		var vector2_array: PackedVector2Array = value
		return vector2_array.duplicate()
	if value is PackedVector3Array:
		var vector3_array: PackedVector3Array = value
		return vector3_array.duplicate()
	if value is PackedColorArray:
		var color_array: PackedColorArray = value
		return color_array.duplicate()
	return value
