## GFSaveSyncProjection: 项目显式声明上传字段和下载合并边界的协议。
##
## 输入不包含框架 checkpoint。项目负责排除本地专用、凭证及服务端权威字段，
## 并将下载数据与本地专用状态合成为完整候选。默认实现拒绝，避免默认上传整份文档。
## 不在回调中修改运行状态或执行 IO；返回值由同步组合器再次验证并冻结。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFSaveSyncProjection
extends RefCounted


# --- 公共方法 ---

## 从已持久化本地文档构造明确允许上传的完整文档封套。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param document: 不含框架 checkpoint 的隔离本地文档。
## [br]
## @return 项目投影候选；拒绝时为 null。
func project_upload(document: GFSaveDocument) -> GFSaveDocument:
	return _project_upload(document.duplicate_document()) if document != null else null


## 将远端投影与本地专用状态合成为完整本地候选。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param remote: 已验证封套的远端投影，不含框架 checkpoint。
## [br]
## @param current: 当前已确认本地文档，不含框架 checkpoint。
## [br]
## @return 可由 Profile 验证和事务应用的完整文档；拒绝时为 null。
func prepare_download(remote: GFSaveDocument, current: GFSaveDocument) -> GFSaveDocument:
	if remote == null or current == null:
		return null
	return _prepare_download(
		remote.duplicate_document(),
		current.duplicate_document()
	)


# --- 可重写钩子 / 虚方法 ---

## 由项目选择上传的分区、字段和项目元数据，默认拒绝。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _document: 独立本地文档。
## [br]
## @return 明确的上传投影或 null。
func _project_upload(_document: GFSaveDocument) -> GFSaveDocument:
	return null


## 由项目处理字段所有权，默认拒绝下载应用。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _remote: 独立远端投影。
## [br]
## @param _current: 独立当前本地文档。
## [br]
## @return 完整本地候选或 null。
func _prepare_download(_remote: GFSaveDocument, _current: GFSaveDocument) -> GFSaveDocument:
	return null
