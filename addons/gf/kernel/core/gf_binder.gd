## GFBinder: 面向 Installer 的声明式装配入口。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFBinder
extends RefCounted


# --- 常量 ---

## 绑定构建器脚本缓存。
## [br]
## @api framework_internal
const GFBindBuilderBase = preload("res://addons/gf/kernel/core/gf_bind_builder.gd")
const _GF_BINDING_PLAN_SCRIPT = preload("res://addons/gf/kernel/core/gf_binding_plan.gd")


# --- 私有变量 ---

var _architecture: GFArchitecture = null


# --- Godot 生命周期方法 ---

func _init(architecture: GFArchitecture) -> void:
	_architecture = architecture


# --- 公共方法 ---

## 创建一个绑定到当前候选 Architecture 的 required binding plan。
## Plan 只接纳显式 require_*() entry，并在首个失败时停止后续绑定、冻结类型化
## 结果并使候选初始化失败。READY 架构继续使用既有热拓扑 API，不由 Plan 修改。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 绑定到当前 Architecture 的新 GFBindingPlan。
func create_required_plan() -> GFBindingPlan:
	return _GF_BINDING_PLAN_SCRIPT.new(_architecture)


## 声明一个 Model 绑定。
## [br]
## @api public
## [br]
## @param script_cls: Model 脚本类型。
## [br]
## @return 绑定构建器。
func bind_model(script_cls: Script) -> GFBindBuilder:
	return GFBindBuilderBase.new(_architecture, GFBindBuilderBase.TargetKind.MODEL, script_cls)


## 声明一个 System 绑定。
## [br]
## @api public
## [br]
## @param script_cls: System 脚本类型。
## [br]
## @return 绑定构建器。
func bind_system(script_cls: Script) -> GFBindBuilder:
	return GFBindBuilderBase.new(_architecture, GFBindBuilderBase.TargetKind.SYSTEM, script_cls)


## 声明一个 Utility 绑定。
## [br]
## @api public
## [br]
## @param script_cls: Utility 脚本类型。
## [br]
## @return 绑定构建器。
func bind_utility(script_cls: Script) -> GFBindBuilder:
	return GFBindBuilderBase.new(_architecture, GFBindBuilderBase.TargetKind.UTILITY, script_cls)


## 声明一个短生命周期对象工厂绑定。
## [br]
## @api public
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @return 绑定构建器。
func bind_factory(script_cls: Script) -> GFBindBuilder:
	return GFBindBuilderBase.new(_architecture, GFBindBuilderBase.TargetKind.FACTORY, script_cls)
