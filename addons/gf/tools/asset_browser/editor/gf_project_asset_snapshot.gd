@tool

# 分帧来源使用的完整快照累积器；失败后丢弃全部候选，不发布截断目录。
extends RefCounted


# --- 私有变量 ---

var _catalog: GFAssetCatalog = GFAssetCatalog.new()
var _ids: Dictionary = {}
var _status: String = "complete"
var _count: int = 0


# --- 框架内部方法 ---

## 接纳一个独立条目；超限或身份重复会终结整个快照。
## [br]
## @api framework_internal
## [br]
## @param entry: 当前来源建立的条目。
## [br]
## @return 是否继续接受候选。
func append_entry(entry: GFAssetCatalogEntry) -> bool:
	if _status != "complete":
		return false
	if _count >= GFAssetBrowserModel.MAX_CATALOG_ENTRIES:
		_status = "capacity_exceeded"
	elif entry == null or entry.asset_id == &"":
		_status = "invalid_identity"
	elif _ids.has(entry.asset_id):
		_status = "duplicate_identity"
	if _status != "complete":
		_catalog = null
		_ids.clear()
		return false
	_ids[entry.asset_id] = true
	_catalog.entries.append(entry)
	_count += 1
	return true


## 取得累积结果；仅完整有效结果附带 catalog，失败不保留前缀目录。
## [br]
## @api framework_internal
## [br]
## @return 累积结果，调用方拥有结果目录且不再继续添加。
## [br]
## @schema return: Dictionary with ok, status, count and catalog.
func finish() -> Dictionary:
	var result: Dictionary = {"ok": _status == "complete", "status": _status, "count": _count, "catalog": _catalog}
	_catalog = null
	_ids.clear()
	_status = "finished"
	return result
