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


# --- 常量 ---

const _SNAPSHOT_COPY = preload("res://addons/gf/extensions/dialogue/resources/gf_dialogue_snapshot_copy.gd")


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
	return _SNAPSHOT_COPY.copy_snapshot_dictionary(create_serialization_source())


## 创建对话序列化操作的原始结构。
##
## 返回值只供资源级复制器在同一次共享预算操作中消费；调用方不得将其视为隔离快照。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @return: 包含行及响应全部身份字段的原始结构。
## [br]
## @schema return: 包含 line_id、kind、speaker_id、text、next_line_id、jump_line_id、condition_id、condition_payload、fallback_line_id、mutation_id、mutation_payload、responses、tags 和 metadata 字段的 Dictionary。
func create_serialization_source() -> Dictionary:
	var response_data: Array = []
	for response: GFDialogueResponse in responses:
		if response != null:
			response_data.append(response.create_serialization_source())
		else:
			response_data.append(null)

	return {
		"line_id": line_id,
		"kind": kind,
		"speaker_id": speaker_id,
		"text": text,
		"next_line_id": next_line_id,
		"jump_line_id": jump_line_id,
		"condition_id": condition_id,
		"condition_payload": condition_payload,
		"fallback_line_id": fallback_line_id,
		"mutation_id": mutation_id,
		"mutation_payload": mutation_payload,
		"responses": response_data,
		"tags": tags,
		"metadata": metadata,
	}


# --- 私有/辅助方法 ---

func _get_dialogue_line_value(value: Variant) -> GFDialogueLine:
	if value is GFDialogueLine:
		var line: GFDialogueLine = value
		return line
	return null
