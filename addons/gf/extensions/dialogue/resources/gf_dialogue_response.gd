## GFDialogueResponse: 通用对话响应选项。
##
## 响应只描述玩家或系统可选择的一条后继路径，不决定 UI 样式、
## 输入方式、角色关系或业务副作用。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFDialogueResponse
extends Resource


# --- 常量 ---

const _SNAPSHOT_COPY = preload("res://addons/gf/extensions/dialogue/resources/gf_dialogue_snapshot_copy.gd")


# --- 导出变量 ---

## 响应 ID。
## [br]
## @api public
@export var response_id: StringName = &""

## 响应文本或项目自定义文本键。
## [br]
## @api public
@export_multiline var text: String = ""

## 选择后跳转到的行 ID。为空时使用当前行的默认后继。
## [br]
## @api public
@export var next_line_id: StringName = &""

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

## 选择该响应时请求执行的通用 mutation ID。为空表示无副作用请求。
## [br]
## @api public
@export var mutation_id: StringName = &""

## mutation 载荷。框架只透传给上下文处理器。
## [br]
## @api public
## [br]
## @schema mutation_payload: mutation 处理器接收的任意项目载荷；框架只透传，不解释其中结构。
@export var mutation_payload: Variant = null

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

## 检查响应是否可用。
## [br]
## @api public
## [br]
## @param context: 对话上下文。
## [br]
## @return: 可用时返回 true。
func is_available(context: GFDialogueContext) -> bool:
	if condition_id == &"":
		return true
	if context == null:
		return false
	return GFVariantData.get_option_bool(context.check_condition(condition_id, condition_payload, self), "ok", false)


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return: 响应副本。
func duplicate_response() -> GFDialogueResponse:
	var response: GFDialogueResponse = _get_dialogue_response_value(duplicate(true))
	return response if response != null else GFDialogueResponse.new()


## 转换为字典。
## [br]
## @api public
## [br]
## @return: 响应快照。
## [br]
## @schema return: 包含 response_id、text、next_line_id、condition_id、condition_payload、mutation_id、mutation_payload、tags 和 metadata 字段的 Dictionary。
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
## @return: 包含响应全部身份字段的原始结构。
## [br]
## @schema return: 包含 response_id、text、next_line_id、condition_id、condition_payload、mutation_id、mutation_payload、tags 和 metadata 字段的 Dictionary。
func create_serialization_source() -> Dictionary:
	return {
		"response_id": response_id,
		"text": text,
		"next_line_id": next_line_id,
		"condition_id": condition_id,
		"condition_payload": condition_payload,
		"mutation_id": mutation_id,
		"mutation_payload": mutation_payload,
		"tags": tags,
		"metadata": metadata,
	}


# --- 私有/辅助方法 ---

func _get_dialogue_response_value(value: Variant) -> GFDialogueResponse:
	if value is GFDialogueResponse:
		var response: GFDialogueResponse = value
		return response
	return null
