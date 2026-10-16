## GFAudioEvent: 通用资源化音频事件。
##
## 描述一个可以交给 `GFAudioUtility` 或音频后端处理的事件请求。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 3.17.0
class_name GFAudioEvent
extends Resource


# --- 导出变量 ---

## 事件稳定标识。
## [br]
## @api public
@export var event_id: StringName = &""

## 事件通道，例如 bgm、sfx、ambient。
## [br]
## @api public
@export var channel: StringName = &"sfx"

## 可选音频集合标识。
## [br]
## @api public
@export var bank_id: StringName = &""

## 可选资源路径或后端事件路径。
## [br]
## @api public
@export var path: String = ""

## 可选音频片段。
## [br]
## @api public
@export var clip: GFAudioClip = null

## 可选环境音通道。
## [br]
## @api public
@export var ambient_channel: StringName = &"default"

## 可选元数据。
## [br]
## @api public
## [br]
## @schema metadata: 音频事件元数据 Dictionary；键和值由后端或项目逻辑约定。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查事件是否有可请求内容。
## [br]
## @api public
## [br]
## @return: 有事件 ID、路径或片段时返回 true。
func has_request() -> bool:
	return (
		event_id != &""
		or not path.is_empty()
		or clip != null
	)


## 转换为请求选项。
## [br]
## @api public
## [br]
## @param extra_options: 额外选项。
## [br]
## @schema extra_options: 额外请求选项 Dictionary；键和值由后端或调用方约定，同名键会覆盖 metadata 中的值。
## [br]
## @return: 请求选项字典。
## [br]
## @schema return: 请求选项 Dictionary，包含 metadata 与 extra_options 合并后的字段，并追加 event_id、channel、bank_id、path 和 ambient_channel 字段。
func to_request_options(extra_options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = metadata.duplicate(true)
	for key: Variant in extra_options.keys():
		result[key] = extra_options[key]
	result["event_id"] = event_id
	result["channel"] = channel
	result["bank_id"] = bank_id
	result["path"] = path
	result["ambient_channel"] = ambient_channel
	return result
