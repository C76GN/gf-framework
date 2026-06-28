## GFInputAction: 资源化输入动作描述。
##
## 只描述“项目想要读取的抽象动作”，不绑定具体按键、设备或玩法逻辑。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputAction
extends Resource


# --- 枚举 ---

## 动作输出值类型。
## [br]
## @api public
enum ValueType {
	## 开关型动作，例如确认、跳跃、攻击。
	BOOL,
	## 一维轴动作，例如水平移动或缩放。
	AXIS_1D,
	## 二维轴动作，例如移动方向、瞄准方向。
	AXIS_2D,
	## 三维轴动作，例如飞行移动、自由相机或六自由度控制。
	AXIS_3D,
}


# --- 导出变量 ---

## 动作稳定标识。建议使用不会随本地化变化的 snake_case 名称。
## [br]
## @api public
@export var action_id: StringName = &""

## 显示名称，供设置界面或输入提示使用。
## [br]
## @api public
@export var display_name: String = ""

## 显示分类，供设置界面分组使用。
## [br]
## @api public
@export var display_category: String = ""

## 动作输出值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.BOOL

## 是否允许玩家在项目层重绑定。
## [br]
## @api public
@export var remappable: bool = true

## 同一输入事件命中多个动作时，较高优先级动作是否阻止低优先级动作。
## [br]
## @api public
@export var block_lower_priority_actions: bool = true

## 判断轴动作是否活跃的阈值。
## [br]
## @api public
@export_range(0.0, 1.0, 0.01) var activation_threshold: float = 0.5


# --- 公共方法 ---

## 获取可显示名称。
## [br]
## @api public
## [br]
## @return 显示名称；为空时回退到动作标识或资源文件名。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if action_id != &"":
		return String(action_id)
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename().capitalize()
	return "Input Action"


## 获取稳定动作标识。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 显式动作标识；未设置时返回空标识。
func get_action_id() -> StringName:
	return action_id
