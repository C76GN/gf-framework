## GFUIRoute: UI 路由资源描述。
##
## 只描述路由标识、面板场景、目标层级和默认打开选项，不规定页面业务、
## 动画实现或面板通信方式。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFUIRoute
extends Resource


# --- 导出变量 ---

## 路由稳定标识。
## [br]
## @api public
@export var route_id: StringName = &""

## 面板场景路径。
## [br]
## @api public
@export_file("*.tscn") var scene_path: String = ""

## 目标 UI 逻辑层 ID。默认使用 GFUIUtility.POPUP；自定义 ID 必须先注册到 GFUIUtility。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var layer: int = GFUIUtility.Layer.POPUP

## 默认面板选项，会传给 GFUIUtility。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema default_options: Dictionary，字段同 GFUIUtility 打开面板 options，例如 metadata、modal、hide_under、dismiss_on_cancel。
@export var default_options: Dictionary = {}

## 路由元数据。框架只透传，不解释字段含义。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，由项目定义的路由元数据；build_options() 会追加 route_id 和 route_params。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定路由标识。
## [br]
## @api public
## [br]
## @return 路由标识；未显式设置时尝试使用资源路径。
func get_route_id() -> StringName:
	if route_id != &"":
		return route_id
	if not resource_path.is_empty():
		return StringName(resource_path)
	return &""


## 检查路由是否具备可打开的基本信息。
## [br]
## @api public
## [br]
## @return 路由有效时返回 true。
func is_valid_route() -> bool:
	return get_route_id() != &"" and not scene_path.is_empty() and layer >= 0


## 合并默认选项、覆盖选项和路由参数。
## [br]
## @api public
## [br]
## @param params: 本次打开路由携带的参数。
## [br]
## @param option_overrides: 本次打开路由的选项覆盖。
## [br]
## @return 合并后的 GFUIUtility 选项。
## [br]
## @schema params: Dictionary，由项目定义的路由参数，会复制到 metadata.route_params。
## [br]
## @schema option_overrides: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖 default_options。
## [br]
## @schema return: Dictionary，合并后的面板打开 options，至少包含 metadata.route_id，可能包含 metadata.route_params。
func build_options(params: Dictionary = {}, option_overrides: Dictionary = {}) -> Dictionary:
	var options: Dictionary = default_options.duplicate(true)
	var _merge_dictionary_result_88: Variant = GFVariantData.merge_dictionary(options, option_overrides)

	var merged_metadata: Dictionary = GFVariantData.duplicate_metadata(metadata)
	var _merge_metadata_result_91: Variant = GFVariantData.merge_metadata(
		merged_metadata,
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	merged_metadata["route_id"] = get_route_id()
	if not params.is_empty():
		merged_metadata["route_params"] = params.duplicate(true)
	options["metadata"] = merged_metadata
	return options
