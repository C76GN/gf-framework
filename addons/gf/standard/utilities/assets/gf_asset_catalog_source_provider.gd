## GFAssetCatalogSourceProvider: 资产目录来源 provider 基类。
##
## 项目、工具或扩展可以继承该类，把文件夹扫描、资源注册表、内容包、外部库
## 或自定义数据库转换为 `GFAssetCatalog`。Provider 只贡献可重建的索引数据，
## 不负责素材库 UI、下载、导出或项目业务解释。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
class_name GFAssetCatalogSourceProvider
extends RefCounted


# --- 公共变量 ---

## 来源稳定 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
var source_id: StringName = &""

## 来源优先级。数值越大越先合并；同 ID 条目默认被高优先级来源覆盖。
## [br]
## @api public
## [br]
## @since 8.0.0
var priority: int = 0


# --- 公共方法 ---

## 配置来源 provider 并返回自身。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_source_id: 来源稳定 ID。
## [br]
## @param options: 可选项，支持 priority。
## [br]
## @schema options: Dictionary with optional priority: int.
## [br]
## @return 当前 provider。
func configure(p_source_id: StringName, options: Dictionary = {}) -> GFAssetCatalogSourceProvider:
	source_id = p_source_id
	priority = GFVariantData.get_option_int(options, "priority", priority)
	return self


## 获取来源 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 来源稳定 ID。
func get_source_id() -> StringName:
	return source_id


## 获取来源优先级。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 来源优先级。
func get_priority() -> int:
	return priority


## 构建资产目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: provider 自定义选项；GF 不解释字段。
## [br]
## @schema options: Dictionary with provider-defined fields.
## [br]
## @return 来源导出的资产目录。
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
	var _unused_options: Dictionary = options
	return GFAssetCatalog.new()


## 获取来源诊断快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 来源诊断字典。
## [br]
## @schema return: Dictionary with source_id, priority, and provider_class.
func get_debug_snapshot() -> Dictionary:
	return {
		"source_id": String(get_source_id()),
		"priority": get_priority(),
		"provider_class": get_class(),
	}
