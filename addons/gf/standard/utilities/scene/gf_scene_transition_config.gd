## GFSceneTransitionConfig: 场景切换配置资源。
##
## 用资源描述一次场景切换所需的目标场景、loading scene、缓存策略、切换参数和扩展参数。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFSceneTransitionConfig
extends Resource


# --- 导出变量 ---

## 目标场景路径。
## [br]
## @api public
@export_file("*.tscn", "*.scn") var target_scene_path: String = ""

## 可选 loading scene 路径。
## [br]
## @api public
@export_file("*.tscn", "*.scn") var loading_scene_path: String = ""

## 切换前是否先发起预加载。
## [br]
## @api public
@export var preload_before_change: bool = false

## preload_before_change 为 true 时，是否把预加载结果写入固定缓存。
## [br]
## @api public
@export var preload_as_fixed_cache: bool = false

## 本次切换完成后是否允许写入 GFSceneUtility 缓存。
## [br]
## @api public
@export var cache_loaded_scene: bool = true

## 本次切换传递给目标场景或项目流程的参数。
## [br]
## @api public
## [br]
## @schema params: Dictionary[String, Variant]，复制到 GFSceneUtility 的场景切换参数。
@export var params: Dictionary = {}

## loading scene 最短保留秒数；为 0 时不额外等待。
## [br]
## @api public
@export_range(0.0, 30.0, 0.01, "or_greater") var minimum_duration_seconds: float = 0.0

## 项目自定义参数。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，复制到 to_dict() 的项目自定义元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return 配置字典。
## [br]
## @schema return: Dictionary，包含 target_scene_path、loading_scene_path、preload_before_change、preload_as_fixed_cache、cache_loaded_scene、params、minimum_duration_seconds 和 metadata。
func to_dict() -> Dictionary:
	return {
		"target_scene_path": target_scene_path,
		"loading_scene_path": loading_scene_path,
		"preload_before_change": preload_before_change,
		"preload_as_fixed_cache": preload_as_fixed_cache,
		"cache_loaded_scene": cache_loaded_scene,
		"params": params.duplicate(true),
		"minimum_duration_seconds": minimum_duration_seconds,
		"metadata": metadata.duplicate(true),
	}


## 应用字典配置。
## [br]
## @api public
## [br]
## @param data: 配置字典。
## [br]
## @schema data: Dictionary，由 to_dict() 生成。
func apply_dict(data: Dictionary) -> void:
	target_scene_path = GFVariantData.get_option_string(
		data,
		"target_scene_path",
		target_scene_path
	)
	loading_scene_path = GFVariantData.get_option_string(
		data,
		"loading_scene_path",
		loading_scene_path
	)
	preload_before_change = GFVariantData.get_option_bool(
		data,
		"preload_before_change",
		preload_before_change
	)
	preload_as_fixed_cache = GFVariantData.get_option_bool(
		data,
		"preload_as_fixed_cache",
		preload_as_fixed_cache
	)
	cache_loaded_scene = GFVariantData.get_option_bool(
		data,
		"cache_loaded_scene",
		cache_loaded_scene
	)
	params = GFVariantData.get_option_dictionary(
		data,
		"params",
		{}
	)
	minimum_duration_seconds = maxf(
		GFVariantData.get_option_float(
			data,
			"minimum_duration_seconds",
			minimum_duration_seconds
		),
		0.0
	)
	metadata = GFVariantData.get_option_dictionary(
		data,
		"metadata",
		{}
	)


## 从 Dictionary 创建配置。
## [br]
## @api public
## [br]
## @param data: 配置字典。
## [br]
## @schema data: Dictionary，由 to_dict() 生成。
## [br]
## @return 新配置。
static func from_dict(data: Dictionary) -> GFSceneTransitionConfig:
	var config: GFSceneTransitionConfig = GFSceneTransitionConfig.new()
	config.apply_dict(data)
	return config
