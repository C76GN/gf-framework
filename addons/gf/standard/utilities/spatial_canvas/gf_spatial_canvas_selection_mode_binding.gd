## GFSpatialCanvasSelectionModeBinding: 空间画布选择修饰键绑定。
##
## 只描述修饰键掩码到 [code]GFSpatialCanvas2D.SelectionMode[/code] 的映射，
## 不读取设备状态，也不拥有输入生命周期。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFSpatialCanvasSelectionModeBinding
extends Resource


# --- 导出变量 ---

## 需要精确匹配的 [code]GFSpatialCanvasInputPolicy.ModifierMask[/code] 掩码。
## [br]
## @api public
## [br]
## @since unreleased
@export_flags("Shift:1", "Ctrl:2", "Alt:4", "Meta:8") var modifier_mask: int = 0

## 匹配时使用的 [code]GFSpatialCanvas2D.SelectionMode[/code] 值。
## [br]
## @api public
## [br]
## @since unreleased
@export var selection_mode: GFSpatialCanvas2D.SelectionMode = (
	GFSpatialCanvas2D.SelectionMode.REPLACE
)


# --- 公共方法 ---

## 创建隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新绑定。
func duplicate_binding() -> GFSpatialCanvasSelectionModeBinding:
	var binding: GFSpatialCanvasSelectionModeBinding = GFSpatialCanvasSelectionModeBinding.new()
	binding.modifier_mask = modifier_mask
	binding.selection_mode = selection_mode
	return binding
