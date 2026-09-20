## GFPayload: 强类型数据载体的抽象基类。
##
## 继承自 RefCounted，用作事件传递、命令参数、系统间查询返回值的
## 标准化强类型数据包，替代容易在大型项目中引发类型错误和 null 访问的裸 Dictionary。
##
## 使用方式：为每个具体的数据场景定义一个子类，
## 将相关字段声明为强类型变量，并按需实现 to_dict() / from_dict()。
##
## 典型用途：
##   - 作为 GFCommand 的参数包（替代 Dictionary 参数）
##   - 作为类型事件系统中的事件数据载体
##   - 作为 GFQuery 的查询结果返回值
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFPayload
extends RefCounted


# --- 公共变量 ---

## 事件消费标记。高优先级回调可将此标记设为 true，
## 阻止后续低优先级回调继续接收该事件。
## 仅在 GFTypeEventSystem 的类型事件轨道中生效。
## [br]
## @api public
var is_consumed: bool = false


# --- 公共方法 ---

## 将此载体序列化为字典，便于存档、网络传输或日志记录。
## 子类应重写此方法以包含所有相关字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 包含字段数据的字典。
## [br]
## @schema return: {"type": "Dictionary", "additional_properties": true}
func to_dict() -> Dictionary:
	return {}


## 从字典反序列化并填充此载体的字段。
## 子类应重写此方法以恢复所有相关字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _data: 包含字段数据的字典（通常来自 to_dict() 的结果）。
## [br]
## @schema _data: {"type": "Dictionary", "additional_properties": true}
func from_dict(_data: Dictionary) -> void:
	pass


## 校验载体中的数据是否满足业务约束。
## 子类可重写此方法以添加非空、范围等校验逻辑。
## [br]
## @api public
## [br]
## @return 数据合法返回 true，否则返回 false。
func validate() -> bool:
	return true
