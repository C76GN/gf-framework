## GFConfig: 数据驱动配置的抽象基类。
##
## 继承自 Resource，可在编辑器中配置并序列化为 .tres 文件。
## 用于承载关卡配置、难度配置、游戏模式定义等只读数据，
## 供 GFSystem 在初始化或运行期间读取，彻底分离"数据"与"逻辑"。
## 子类应将所有可配置数据声明为 @export 变量。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFConfig
extends Resource


# --- 公共方法 ---

## 校验此配置数据是否完整且合法。
## 子类应重写此方法以添加必要的校验逻辑（如非空检查、范围检查）。
## [br]
## @api public
## [br]
## @return 配置合法返回 true，否则返回 false。
func validate() -> bool:
	return true


## 将配置数据序列化为字典，便于存档或网络传输。
## 子类可重写此方法以控制序列化范围。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 包含配置数据的字典。
## [br]
## @schema return: {"type": "Dictionary", "additional_properties": true}
func to_dict() -> Dictionary:
	return {}
