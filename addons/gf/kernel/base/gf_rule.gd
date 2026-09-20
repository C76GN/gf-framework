## GFRule: 数据驱动规则的抽象基类。
##
## 继承自 Resource，可在编辑器中配置并序列化为 .tres 文件。
## GFSystem 作为规则的执行者，通过调用 execute() 驱动规则逻辑，
## 从而避免在 System 内硬编码业务分支，实现策略模式。
## 子类必须重写 execute() 以实现具体规则。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFRule
extends Resource


# --- 公共方法 ---

## 执行规则逻辑。子类必须重写此方法。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _context: 传递给规则的上下文数据，通常是一个 GFPayload 子类实例。
## [br]
## @return 规则执行结果，同步返回 Variant，异步返回一个 Signal 供 await。
## [br]
## @schema return: {"type": "Variant", "description": "规则执行结果；异步规则可返回 Signal 供 await。"}
func execute(_context: Object = null) -> Variant:
	return null


## 校验规则的配置数据是否合法。
## 子类可重写此方法以添加配置校验逻辑。
## [br]
## @api public
## [br]
## @return 配置合法返回 true，否则返回 false。
func validate() -> bool:
	return true
