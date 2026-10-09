@tool

# 分帧来源使用的完整快照累积器；失败后丢弃全部候选，不发布截断目录。
extends RefCounted


# --- 私有变量 ---

## 尚未发布的累积目录，直接保留已接纳的条目引用；首次失败时丢弃，finish 时把目录引用交给结果并清空本地持有。
## [br]
## @api private
var _catalog: GFAssetCatalog = GFAssetCatalog.new()

## 当前候选目录已接纳的 asset_id 集合，用于拒绝重复身份；失败或 finish 后清空。
## [br]
## @api private
var _ids: Dictionary = {}

## complete 表示仍可接纳候选；首次错误阻止后续追加，finish 后改为 finished，不能复用此累积器。
## [br]
## @api private
var _status: String = "complete"

## 已成功接纳条目的累计数量，用于容量检查和结束报告；失败丢弃目录时仍保留此前接纳数量。
## [br]
## @api private
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
