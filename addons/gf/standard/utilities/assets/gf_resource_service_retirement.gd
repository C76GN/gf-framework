## 异常生命周期退出后的局部收尾所有者；正常运行与正常成功关闭不会创建。
## [br]
## @api framework_internal
class_name GFResourceServiceRetirement
extends Node


# --- 私有变量 ---

## 树持有推进器，推进器持有域；域仅弱引用推进器，不形成所有权环。
## [br]
## @api private
var _domain: GFResourceServiceDomain = null


# --- Godot 生命周期方法 ---

func _process(_delta: float) -> void:
	if _domain == null:
		queue_free()
		return
	_domain.pump()
	if not _domain.has_live_generations_for_framework():
		_domain = null
		queue_free()


func _exit_tree() -> void:
	_domain = null


# --- 框架内部方法 ---

## 识别同一域的唯一收尾推进器，不暴露可变所有权字段。
## [br]
## @api framework_internal
## [br]
## @param domain: 待核对域。
## [br]
## @return 本节点持有指定域时为 true。
func owns_domain(domain: GFResourceServiceDomain) -> bool:
	return _domain == domain


## 绑定单个退出中的域；树暂停不暂停物理收尾。
## [br]
## @api framework_internal
## [br]
## @param domain: 需要继续推进的服务域。
func bind(domain: GFResourceServiceDomain) -> void:
	_domain = domain
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "GFResourceServiceRetirement"
