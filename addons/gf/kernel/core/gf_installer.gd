## GFInstaller: 项目启动装配脚本基类。
##
## 继承后重写 install()，并在 Project Settings 的 gf/project/installers 中登记脚本路径，
## Gf.init() 与 Gf.set_architecture() 会在架构初始化前自动执行这些安装器。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFInstaller
extends RefCounted


# --- 公共方法 ---

## 将项目模块注册到架构。
## install() 可使用 await，但首个 await 前仍运行在主线程；不要在其中执行长同步工作。
## 需要耗时处理时应拆分为检查点，并在每个 await 或外部回调后检查 _scope。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _architecture: 当前即将初始化的架构实例。
## [br]
## @param _scope: 当前 Installer 步骤的可取消异步作用域。
func install(_architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	pass


## 使用声明式装配器注册项目模块。
## install_bindings() 与 install() 共享同一异步契约：首个 await 前不应执行长同步工作。
## 需要注册外部任务清理时应使用 _scope.register_cleanup()。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _binder: 绑定到当前架构的装配器。
## [br]
## @schema _binder {
##   "type": "Variant",
##   "description": "当前架构创建的装配器实例，实际类型为 GFBindBuilder。"
## }
## [br]
## @param _scope: 当前 Installer 步骤的可取消异步作用域。
func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
	pass
