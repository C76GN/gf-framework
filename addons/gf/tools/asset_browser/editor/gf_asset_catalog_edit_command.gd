@tool

# 共享目录编辑沿用属性事务，并在历史重放后使目录索引与视图同步失效。
extends GFEditorPropertyBatchCommand


# --- 私有变量 ---

## 保留本次命令配置的共享目录引用，在执行或撤销成功后使其索引失效并通知消费者；历史重放不自动保存磁盘。
## [br]
## @api private
var _catalog: GFAssetCatalog = null


# --- 可重写钩子 / 虚方法 ---

## 沿用父类属性事务提交 entries；仅在父事务返回 OK 且目录存在时使索引失效并发出 changed。
## 首次执行与历史重做共用此路径，通知消费者重新读取内存状态，不自动保存目录文件。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return: 原样返回父类属性事务错误码；失败时不额外触发本覆写的索引失效或 changed 通知。
func _do_it() -> Error:
	var error: Error = super._do_it()
	if error == OK and _catalog != null:
		_catalog.mark_index_dirty()
		_catalog.emit_changed()
	return error


## 沿用父类撤销或恢复首次执行失败残余状态的协议，成功后通知目录消费者重新读取 entries。
## 仅在父操作返回 OK 且目录存在时使索引失效并发出 changed；历史重放不自动保存磁盘。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return: 原样返回父类撤销或恢复的错误码，保留其忙碌、快照及待恢复状态的拒绝语义。
func _undo_it() -> Error:
	var error: Error = super._undo_it()
	if error == OK and _catalog != null:
		_catalog.mark_index_dirty()
		_catalog.emit_changed()
	return error


# --- 框架内部方法 ---

## 为同一个共享目录配置一批条目替换，保留单一资源的原生 Undo history。
## [br]
## @api framework_internal
## [br]
## @param catalog: 用户显式选择的共享目录。
## [br]
## @param entries: 完整的新条目数组。
func configure_catalog(catalog: GFAssetCatalog, entries: Array[GFAssetCatalogEntry]) -> void:
	_catalog = catalog
	var _configured: GFEditorPropertyBatchCommand = configure([
		{"target": catalog, "property_name": &"entries", "new_value": entries},
	], {"command_name": "Edit Shared Asset Catalog"})
