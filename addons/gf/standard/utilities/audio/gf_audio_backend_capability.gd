## GFAudioBackendCapability: 音频后端能力声明。
##
## 用布尔能力与元数据描述一个后端能处理哪些通用音频请求。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFAudioBackendCapability
extends Resource


# --- 导出变量 ---

## 是否支持 BGM。
## [br]
## @api public
@export var supports_bgm: bool = false

## 是否支持 SFX。
## [br]
## @api public
@export var supports_sfx: bool = false

## 是否支持环境音。
## [br]
## @api public
@export var supports_ambient: bool = false

## 是否支持空间音效。
## [br]
## @api public
@export var supports_spatial_sfx: bool = false

## 是否支持资源化事件。
## [br]
## @api public
@export var supports_events: bool = false

## 是否支持参数写入。
## [br]
## @api public
@export var supports_parameters: bool = false

## 是否支持状态写入。
## [br]
## @api public
@export var supports_states: bool = false

## 是否支持开关写入。
## [br]
## @api public
@export var supports_switches: bool = false

## 是否支持监听器。
## [br]
## @api public
@export var supports_listeners: bool = false

## 是否支持异步加载或卸载。
## [br]
## @api public
@export var supports_async_loading: bool = false

## 是否支持逐请求的类型化播放区间能力协商。
## 该标记只表示后端实现了协商契约；具体片段、通道和循环模式仍须通过
## `GFAudioBackend.evaluate_playback_region()` 判断。
## [br]
## @api public
## [br]
## @since unreleased
@export var supports_playback_region_contract: bool = false

## 可选元数据，供项目层或调试面板展示。
## [br]
## @api public
## [br]
## @schema metadata: 后端能力元数据 Dictionary；键和值由具体后端或项目工具约定。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查能力是否存在。
## [br]
## @api public
## [br]
## @param capability_id: 能力标识。
## [br]
## @return: 支持返回 true。
func has_capability(capability_id: StringName) -> bool:
	match capability_id:
		&"bgm":
			return supports_bgm
		&"sfx":
			return supports_sfx
		&"ambient":
			return supports_ambient
		&"spatial_sfx":
			return supports_spatial_sfx
		&"events":
			return supports_events
		&"parameters":
			return supports_parameters
		&"states":
			return supports_states
		&"switches":
			return supports_switches
		&"listeners":
			return supports_listeners
		&"async_loading":
			return supports_async_loading
		&"playback_region_contract":
			return supports_playback_region_contract
		_:
			return false


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return: 新能力声明。
func duplicate_capability() -> GFAudioBackendCapability:
	var capability: GFAudioBackendCapability = GFAudioBackendCapability.new()
	capability.supports_bgm = supports_bgm
	capability.supports_sfx = supports_sfx
	capability.supports_ambient = supports_ambient
	capability.supports_spatial_sfx = supports_spatial_sfx
	capability.supports_events = supports_events
	capability.supports_parameters = supports_parameters
	capability.supports_states = supports_states
	capability.supports_switches = supports_switches
	capability.supports_listeners = supports_listeners
	capability.supports_async_loading = supports_async_loading
	capability.supports_playback_region_contract = supports_playback_region_contract
	capability.metadata = metadata.duplicate(true)
	return capability


## 转换为字典。
## [br]
## @api public
## [br]
## @since 3.2.0
## [br]
## @return: 能力字典。
## [br]
## @schema return: 能力 Dictionary，包含 bgm、sfx、ambient、spatial_sfx、events、parameters、states、switches、listeners、async_loading、playback_region_contract 和 metadata 字段。
func to_dictionary() -> Dictionary:
	return {
		"bgm": supports_bgm,
		"sfx": supports_sfx,
		"ambient": supports_ambient,
		"spatial_sfx": supports_spatial_sfx,
		"events": supports_events,
		"parameters": supports_parameters,
		"states": supports_states,
		"switches": supports_switches,
		"listeners": supports_listeners,
		"async_loading": supports_async_loading,
		"playback_region_contract": supports_playback_region_contract,
		"metadata": metadata.duplicate(true),
	}
