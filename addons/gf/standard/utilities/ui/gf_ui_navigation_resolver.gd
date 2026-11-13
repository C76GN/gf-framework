## GFUINavigationResolver: 项目内容就绪与语义定位的异步协议。
##
## 回调及完成源必须在主线程运行。Router 为每次导航分配独立 scope；项目在异步返回后、
## 写入界面前必须检查 scope.is_active。完成源成功表示该阶段已完成，业务数据不进入结果。
## 默认实现拒绝，不能把页面入栈或资源已加载冒充内容已经可用。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFUINavigationResolver
extends RefCounted


# --- 公共方法 ---

## 开始等待页面内容可用；成功之后 Router 才允许目标定位。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param panel: 已入栈页面，异步代码不能假定其一直有效。
## [br]
## @param target: 冻结的语义请求。
## [br]
## @param scope: 本次导航独有的作用域，不能由项目正常完成。
## [br]
## @return 阶段完成源；成功为内容就绪，失败或取消不回滚已提交页面。
func prepare_content(
	panel: Node,
	target: GFUINavigationTarget,
	scope: GFAsyncScope
) -> GFAsyncCompletion:
	return _prepare_content(
		panel,
		target,
		scope
	)


## 在内容就绪后定位语义目标，例如选择页签、滚动到条目。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param panel: 已入栈且完成内容准备的页面。
## [br]
## @param target: 冻结的非空语义目标。
## [br]
## @param scope: 同一次导航的活动作用域。
## [br]
## @return 成功表示目标已定位；失败映射为 target_unavailable，保留页面。
func resolve_target(
	panel: Node,
	target: GFUINavigationTarget,
	scope: GFAsyncScope
) -> GFAsyncCompletion:
	return _resolve_target(
		panel,
		target,
		scope
	)


# --- 可重写钩子 / 虚方法 ---

## 项目实现内容准备协议；无需等待时可以返回已成功的完成源。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _panel: 已提交页面。
## [br]
## @param _target: 冻结请求。
## [br]
## @param _scope: 异步写回资格。
## [br]
## @return 默认返回 content_unavailable 失败。
func _prepare_content(
	_panel: Node,
	_target: GFUINavigationTarget,
	_scope: GFAsyncScope
) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail("content_unavailable")
	return completion


## 项目在内容准备之后实现具体定位；目标消失必须失败。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _panel: 当前可用页面。
## [br]
## @param _target: 冻结语义目标。
## [br]
## @param _scope: 写入页面前必须仍活动。
## [br]
## @return 默认返回 target_unavailable 失败。
func _resolve_target(
	_panel: Node,
	_target: GFUINavigationTarget,
	_scope: GFAsyncScope
) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail("target_unavailable")
	return completion
