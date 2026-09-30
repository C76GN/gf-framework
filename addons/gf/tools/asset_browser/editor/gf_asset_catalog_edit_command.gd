@tool

# 共享目录编辑沿用属性事务，并在历史重放后使目录索引与视图同步失效。
extends GFEditorPropertyBatchCommand


# --- 私有变量 ---

var _catalog: GFAssetCatalog = null


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


## 属性提交成功后通知同一目录的消费者；历史重放不保存磁盘。
## [br]
## @api framework_internal
## [br]
## @return 属性事务结果。
func _do_it() -> Error:
	var error: Error = super._do_it()
	if error == OK and _catalog != null:
		_catalog.mark_index_dirty()
		_catalog.emit_changed()
	return error


## 撤销成功后使目录索引和界面与恢复后的 entries 一致。
## [br]
## @api framework_internal
## [br]
## @return 属性事务结果。
func _undo_it() -> Error:
	var error: Error = super._undo_it()
	if error == OK and _catalog != null:
		_catalog.mark_index_dirty()
		_catalog.emit_changed()
	return error
