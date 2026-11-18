## GFDataSnapshotSource: 一个已经固定版本的记录序列读取租约。
##
## 每个实例独占一次读取租约；交给捕获会话后由会话或成功快照释放。
## 项目适配器负责保持版本稳定，逐条返回已就绪的 GFDataSnapshot。
## 单条读取必须有界；本协议不提供线程同步，也不验证项目底层存储的不可变性。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFDataSnapshotSource
extends RefCounted


# --- 私有变量 ---

## 释放只能结算一次，释放后不再进入项目读取钩子。
## [br]
## @api private
var _released: bool = false


# --- 公共方法 ---

## 返回租约是否仍可读取。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已释放时为 false。
func is_available() -> bool:
	return not _released


## 返回固定版本的记录数量；不允许遍历或复制整个源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 非负数量；不可用或未实现时为 -1。
func get_record_count() -> int:
	return -1 if _released else _get_record_count()


## 返回本租约固定的版本号，不是跨存储的一致性凭证。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 非负版本号；不可用或未实现时为 -1。
func get_revision() -> int:
	return -1 if _released else _get_revision()


## 取得一条独立只读快照。返回后源释放不能使该快照失效。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param index: 零起始记录位置，必须小于固定记录数。
## [br]
## @return: 已就绪记录快照；失败为 null。
func read_record(index: int) -> GFDataSnapshot:
	if _released or index < 0:
		return null
	if index >= _get_record_count():
		return null
	return _read_record(index)


## 幂等释放此租约，不得撤销其他读者的版本。
## [br]
## @api public
## [br]
## @since unreleased
func release() -> void:
	if _released:
		return
	_released = true
	_release()


# --- 可重写钩子 / 虚方法 ---

## 以常数元信息查询返回稳定记录数，不得读取可变 live 数据。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return: 非负记录数；默认未实现为 -1。
func _get_record_count() -> int:
	return -1


## 返回租约创建时固定的版本号，读取期间不得改变。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return: 非负版本号；默认未实现为 -1。
func _get_revision() -> int:
	return -1


## 在有界成本内读取固定版本记录；不得产生业务写入或重入捕获。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _index: 已由公共入口检查的非负位置。
## [br]
## @return: 独立就绪快照；失败返回 null。
func _read_record(_index: int) -> GFDataSnapshot:
	return null


## 结算项目版本持有；不得使已经返回的独立记录快照失效。
## [br]
## @api protected
## [br]
## @since unreleased
func _release() -> void:
	pass
