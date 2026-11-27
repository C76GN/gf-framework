@tool

## GFUIMotionEffect: 可由项目资源实现的界面动效。配置资源共享，所有播放状态由 bind_target 返回的实例持有。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFUIMotionEffect
extends Resource


# --- 公共方法 ---

## 声明从项目具名输入读取的类型，供播放器在替换旧会话前检查。
## [br]
## @api public
## [br]
## @return: 输入名到 Godot 类型的映射。
## [br]
## @schema return: Dictionary，StringName 输入名映射到 typeof 常量、原生类或项目 Script。
## [br]
## @since unreleased
func input_types() -> Dictionary:
	return {}


## 返回该效果在一个目标上写入的属性，用于定位冲突。空集合适合独占自绘子节点的效果。
## [br]
## @api public
## [br]
## @return: 相对目标的属性路径。
## [br]
## @since unreleased
func written_properties() -> Array[NodePath]:
	return []


## 检查目标和输入的额外约束，无副作用。
## [br]
## @api public
## [br]
## @param _target: 绑定目标。
## [br]
## @param _inputs: 调用方提供的输入。
## [br]
## @schema _inputs: Dictionary，以 StringName 映射到声明的运行时输入。
## [br]
## @return: 空串表示有效，其他值是诊断。
## [br]
## @since unreleased
func binding_error(_target: Object, _inputs: Dictionary) -> String:
	return ""


## 创建本次播放的操作。准备阶段只捕获基线，首次采样才向目标写入。
## [br]
## @api public
## [br]
## @param _target: 已验证的目标。
## [br]
## @param _inputs: 已验证的项目输入。
## [br]
## @schema _inputs: Dictionary，以 StringName 映射到运行时输入。
## [br]
## @return: 新建的绑定，null 表示无法准备。
## [br]
## @since unreleased
func bind_target(_target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
	return null
