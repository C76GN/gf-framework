## GFDataVersion: 框架记录序列的固定版本读取句柄。
##
## 公开读取返回独立记录快照；释放只退还本句柄，其他版本和读者继续有效。
## 记录位置属于本版本，不是业务实体 ID。直接 new 的句柄不可读取。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 12.0.0
class_name GFDataVersion
extends GFDataSnapshotSource


# --- 私有变量 ---

## 持有 arena 直到本版本释放，存储关闭不会撤销该引用。
## [br]
## @api private
var _arena: GFDataVersionArena = null

## 固定根、树高、记录数与版本号，配置后不变。
## [br]
## @api private
var _identity: PackedInt64Array = PackedInt64Array()

## 捕获输出持有的引用槽预留，与版本一起结算。
## [br]
## @api private
var _output_bytes: int = 0


# --- Godot 生命周期方法 ---

## 析构时直接结算外部 arena；引用归零阶段不能再次调用自身脚本方法。
## [br]
## @api private
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _arena != null:
		_arena.return_bytes(_output_bytes)
		_arena.release_version(
			_identity[0],
			_identity[3],
			true
		)
		_arena = null


# --- 可重写钩子 / 虚方法 ---

## 返回已固定数量，不遍历版本树。
## [br]
## @api protected
## [br]
## @since 12.0.0
## [br]
## @return: 固定记录数；未配置为 -1。
func _get_record_count() -> int:
	return -1 if _arena == null else _identity[2]


## 返回已固定版本，存储后续提交不修改它。
## [br]
## @api protected
## [br]
## @since 12.0.0
## [br]
## @return: 固定版本号；未配置为 -1。
func _get_revision() -> int:
	return -1 if _arena == null else _identity[3]


## 导出独立记录，避免外部持有绕过 arena 的历史计费。
## [br]
## @api protected
## [br]
## @since 12.0.0
## [br]
## @param index: 已通过范围检查的位置。
## [br]
## @return: 独立就绪记录；复制失败为 null。
func _read_record(index: int) -> GFDataSnapshot:
	var record: GFDataSnapshot = borrow_record_for_framework(index)
	if record == null:
		return null
	return record.duplicate_for_framework()


## 退还本句柄的根和输出预留；节点随后由存储显式回收。
## [br]
## @api protected
## [br]
## @since 12.0.0
func _release() -> void:
	if _arena == null:
		return
	_arena.return_bytes(_output_bytes)
	_arena.release_version(
		_identity[0],
		_identity[3],
		true
	)
	_output_bytes = 0
	_arena = null
	_identity.clear()


# --- 框架内部方法 ---

## 绑定已经由存储取得的根租约；本方法只允许构造期间调用一次。
## [br]
## @api framework_internal
## [br]
## @param arena: 已取得 reader 持有的 arena。
## [br]
## @param identity: 根、树高、记录数、版本号四项元信息。
func configure(arena: GFDataVersionArena, identity: PackedInt64Array) -> void:
	_arena = arena
	_identity = identity.duplicate()


## 捕获会话借出不可变记录；必须保留本租约直到输出释放。
## [br]
## @api framework_internal
## [br]
## @param index: 固定版本中的位置。
## [br]
## @return: 内部记录；不可用或越界为 null。
func borrow_record_for_framework(index: int) -> GFDataSnapshot:
	if not is_available() or _arena == null:
		return null
	if index < 0 or index >= _identity[2]:
		return null
	return _arena.get_record(
		_identity[0],
		_identity[1],
		index
	)


## 将捕获输出引用槽计入同一存储预算，失败不增加预留。
## [br]
## @api framework_internal
## [br]
## @param amount: 本次新增非负字节数。
## [br]
## @return: 预留完成时为 true。
func reserve_output_for_framework(amount: int) -> bool:
	if not is_available() or _arena == null:
		return false
	if not _arena.reserve_bytes(amount):
		return false
	_output_bytes += amount
	return true
