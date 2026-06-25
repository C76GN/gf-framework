## GFAudioClip: 可资源化的音频播放配置。
##
## 支持直接引用 `AudioStream`，也支持提供资源路径交给 `GFAudioUtility`
## 按需加载。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFAudioClip
extends Resource


# --- 导出变量 ---

## 音频资源路径。`stream` 为空时使用该路径加载。
## [br]
## @api public
@export_file("*.wav", "*.ogg", "*.mp3", "*.opus") var path: String = ""

## 音频流资源。
## [br]
## @api public
@export var stream: AudioStream

## 音频总线。为空时由播放方法使用默认 BGM/SFX 总线。
## [br]
## @api public
@export var bus_name: String = ""

## 播放音量，单位 dB。
## [br]
## @api public
@export_range(-80.0, 24.0, 0.1) var volume_db: float = 0.0

## 播放音高。
## [br]
## @api public
@export_range(0.01, 4.0, 0.01) var pitch_scale: float = 1.0

## 在同一片段 ID 存在多个候选时的抽取权重；小于等于 0 表示不参与随机抽取。
## [br]
## @api public
@export_range(0.0, 1000.0, 0.01) var weight: float = 1.0

## 播放音高随机下限，会乘到 pitch_scale 上。
## [br]
## @api public
@export_range(0.01, 4.0, 0.01) var pitch_random_min: float = 1.0

## 播放音高随机上限，会乘到 pitch_scale 上。
## [br]
## @api public
@export_range(0.01, 4.0, 0.01) var pitch_random_max: float = 1.0

## 可选空间播放设置。为空时空间 SFX 使用 GF 默认空间参数，并保留区域掩码 layer 1。
## [br]
## @api public
## [br]
## @since 3.19.0
## [br]
## @schema spatial_settings: GFAudioSpatialSettings or compatible Resource with apply_to_2d/apply_to_3d methods.
@export var spatial_settings: Resource = null

## 可选音频元数据，供导入器、编辑器或项目层扩展使用。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @schema metadata: Dictionary，保存项目或工具附加到片段的通用元数据；GF 不解释具体键。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查该配置是否有可播放来源。
## [br]
## @api public
## [br]
## @return: 有 stream 或 path 时返回 true。
func has_source() -> bool:
	return stream != null or not path.is_empty()


## 解析实际总线名称。
## [br]
## @api public
## [br]
## @param default_bus: 默认总线。
## [br]
## @return: 实际总线名称。
func resolve_bus(default_bus: String) -> String:
	if bus_name.is_empty():
		return default_bus
	return bus_name


## 解析本次播放使用的实际音高。
## [br]
## @api public
## [br]
## @param rng: 可选随机数生成器；为空时使用确定性的 pitch_scale。
## [br]
## @return: 实际播放音高。
func resolve_pitch(rng: RandomNumberGenerator = null) -> float:
	var min_pitch: float = clampf(pitch_random_min, 0.01, 4.0)
	var max_pitch: float = clampf(pitch_random_max, 0.01, 4.0)
	if min_pitch > max_pitch:
		var swapped: float = min_pitch
		min_pitch = max_pitch
		max_pitch = swapped
	if rng == null:
		return clampf(pitch_scale, 0.01, 16.0)
	var random_scale: float = 1.0
	if not is_equal_approx(min_pitch, max_pitch):
		random_scale = rng.randf_range(min_pitch, max_pitch)
	else:
		random_scale = min_pitch
	return clampf(pitch_scale * random_scale, 0.01, 16.0)


## 检查指定元数据键是否存在。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @param key: 元数据键。
## [br]
## @schema key: Variant，推荐使用 String 或 StringName。
## [br]
## @return 存在返回 true。
func has_metadata_value(key: Variant) -> bool:
	return metadata.has(key)


## 设置元数据项。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @param key: 元数据键。
## [br]
## @schema key: Variant，推荐使用 String 或 StringName。
## [br]
## @param value: 元数据值。
## [br]
## @schema value: Variant，推荐使用可序列化的标量、Array、Dictionary 或 Resource 引用。
func set_metadata_value(key: Variant, value: Variant) -> void:
	metadata[key] = GFVariantData.duplicate_variant(value)


## 获取元数据项。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @param key: 元数据键。
## [br]
## @schema key: Variant，推荐使用 String 或 StringName。
## [br]
## @param default_value: 缺少键时返回的默认值。
## [br]
## @schema default_value: Variant 默认值。
## [br]
## @return 元数据值或默认值。
## [br]
## @schema return: Variant 元数据值。
func get_metadata_value(key: Variant, default_value: Variant = null) -> Variant:
	if metadata.has(key):
		return metadata[key]
	return default_value


## 创建元数据深拷贝。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @return 元数据副本。
## [br]
## @schema return: Dictionary 元数据副本。
func duplicate_metadata() -> Dictionary:
	return GFVariantData.duplicate_metadata(metadata)
