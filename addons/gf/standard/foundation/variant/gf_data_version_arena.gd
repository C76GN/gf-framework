## GFDataVersionArena: 分页版本树的内部引用计数与有界回收。
##
## 页只保存整数节点 ID，引用归零时入队，避免释放根触发整树同步析构。
## 计费字节是保守逻辑模型，不是 Godot 分配器或进程 RSS。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @layer standard/foundation
class_name GFDataVersionArena
extends RefCounted


# --- 常量 ---

## 每页固定 32 个引用，单条替换仅复制树路径上的小页。
## [br]
## @api private
const _PAGE_WIDTH: int = 32

## 引用页计费包含引用槽和固定元信息，不表示真实堆大小。
## [br]
## @api private
const _PAGE_BYTES: int = 384


# --- 私有变量 ---

## 所有节点在回收前都强持有；不使用容器对象之间的递归引用。
## [br]
## @api private
var _nodes: Dictionary[int, _Entry] = {}

## 归零节点等待调用方显式推进回收，仍计入全部预算。
## [br]
## @api private
var _garbage: Array[int] = []

## 不复用节点编号，避免过期位置意外命中新节点。
## [br]
## @api private
var _next_id: int = 1

## 已分配页、记录及输出预留的总计费字节。
## [br]
## @api private
var _charged_bytes: int = 0

## 调用期间观察到的计费峰值。
## [br]
## @api private
var _peak_bytes: int = 0

## 创建时固定的总计费上限。
## [br]
## @api private
var _max_bytes: int = 0

## 页及记录节点总数上限。
## [br]
## @api private
var _max_nodes: int = 0

## 当前根与读取租约按版本计数；同一版本多个读者共享存储。
## [br]
## @api private
var _versions: Dictionary[int, int] = {}

## 允许同时存活的版本数。
## [br]
## @api private
var _max_versions: int = 0

## 允许同时存活的外部读取租约数。
## [br]
## @api private
var _max_readers: int = 0

## 当前租约数，不包含存储自己的当前根。
## [br]
## @api private
var _readers: int = 0


# --- 框架内部方法 ---

## 固定本存储的有限预算；仅在空 arena 上调用。
## [br]
## @api framework_internal
## [br]
## @param limits: 经过存储入口校验的限制。
## [br]
## @schema limits: Dictionary with max_owned_bytes, max_nodes, max_versions and max_readers: positive int.
func configure(limits: Dictionary) -> void:
	_max_bytes = limits["max_owned_bytes"]
	_max_nodes = limits["max_nodes"]
	_max_versions = limits["max_versions"]
	_max_readers = limits["max_readers"]


## 尝试增加版本根的持有；拒绝不改变引用或计数。
## [br]
## @api framework_internal
## [br]
## @param root: 已存在根；空序列使用零。
## [br]
## @param revision: 固定非负版本号。
## [br]
## @param reader: 是否占用外部读取租约额度。
## [br]
## @return: 预算允许且完成持有时为 true。
func acquire_version(
	root: int,
	revision: int,
	reader: bool
) -> bool:
	if reader and _readers >= _max_readers:
		return false
	if not _versions.has(revision) and _versions.size() >= _max_versions:
		return false
	_versions[revision] = _versions.get(revision, 0) + 1
	if reader:
		_readers += 1
	retain_node(root)
	return true


## 原子发布前检查替换当前版本后的版本数量。
## [br]
## @api framework_internal
## [br]
## @param revision: 即将由存储退还的当前版本。
## [br]
## @return: 新根可以发布时为 true。
func can_replace_version(revision: int) -> bool:
	var retiring: int = 1 if _versions.get(revision, 0) == 1 else 0
	return _versions.size() + 1 - retiring <= _max_versions


## 退还一个确定的根持有；物理回收由 collect 驱动。
## [br]
## @api framework_internal
## [br]
## @param root: 对应 acquire_version 的根。
## [br]
## @param revision: 对应固定版本。
## [br]
## @param reader: 必须与获取时一致。
func release_version(
	root: int,
	revision: int,
	reader: bool
) -> void:
	if not _versions.has(revision):
		return
	_versions[revision] -= 1
	if _versions[revision] == 0:
		var _erased: bool = _versions.erase(revision)
	if reader:
		_readers -= 1
	release_node(root)


## 临时根或新父页取得节点持有；零代表空引用。
## [br]
## @api framework_internal
## [br]
## @param node_id: 有效节点或零。
func retain_node(node_id: int) -> void:
	if node_id != 0:
		_nodes[node_id]._references += 1


## 临时根或父页退还节点，归零后延迟析构。
## [br]
## @api framework_internal
## [br]
## @param node_id: 正在持有的节点或零。
func release_node(node_id: int) -> void:
	if node_id == 0:
		return
	var entry: _Entry = _nodes[node_id]
	entry._references -= 1
	if entry._references == 0:
		_garbage.append(node_id)


## 纳入一个已经隔离的记录；返回值自带一个临时持有。
## [br]
## @api framework_internal
## [br]
## @param snapshot: 完整就绪的纯数据记录。
## [br]
## @return: 节点 ID；预算不足为零。
func add_record(snapshot: GFDataSnapshot) -> int:
	var stats: Dictionary = snapshot.get_statistics()
	var items: int = stats["items"]
	var payload: int = stats["payload_bytes"]
	if items > ((_max_bytes - mini(payload, _max_bytes)) >> 5):
		return 0
	var charge: int = payload + items * 32 + 128
	if not _can_allocate(charge):
		return 0
	var entry: _Entry = _Entry.new()
	entry._snapshot = snapshot
	entry._bytes = charge
	return _insert(entry)


## 通过路径复制替换或追加一条记录；原根保持不变。
## [br]
## @api framework_internal
## [br]
## @param root: 当前候选根或零。
## [br]
## @param level: 页层数，零表示叶页。
## [br]
## @param index: 已校验的位置。
## [br]
## @param record: 已纳入 arena 的记录节点。
## [br]
## @param writable: 本事务独占的页 ID 集合，提交后必须丢弃。
## [br]
## @schema writable: Dictionary[int, bool] containing only unpublished page IDs owned by the current transaction.
## [br]
## @return: 自带临时持有的新根；失败为零。
func replace_record(
	root: int,
	level: int,
	index: int,
	record: int,
	writable: Dictionary[int, bool]
) -> int:
	var result: int = root
	if root != 0 and writable.has(root):
		retain_node(root)
	else:
		var slots: Array[int] = []
		if root == 0:
			var resize_error: Error = slots.resize(_PAGE_WIDTH) as Error
			if resize_error != OK:
				return 0
			slots.fill(0)
		else:
			slots.assign(_nodes[root]._children)
		result = _add_page(slots)
		if result == 0:
			return 0
		writable[result] = true
	var offset: int = (index >> (level * 5)) & 31
	var old_child: int = _nodes[result]._children[offset]
	var child: int = record
	if level > 0:
		child = replace_record(
			old_child,
			level - 1,
			index,
			record,
			writable
		)
		if child == 0:
			release_node(result)
			return 0
	else:
		retain_node(record)
	_nodes[result]._children[offset] = child
	release_node(old_child)
	return result


## 根容量耗尽时增加一层，旧根放到首个槽。
## [br]
## @api framework_internal
## [br]
## @param root: 仍由调用方持有的旧根。
## [br]
## @return: 自带临时持有的新根；失败为零。
func grow_root(root: int) -> int:
	var slots: Array[int] = []
	var resize_error: Error = slots.resize(_PAGE_WIDTH) as Error
	if resize_error != OK:
		return 0
	slots.fill(0)
	slots[0] = root
	return _add_page(slots)


## 只读查找记录，代价取决于树高而非序列长度。
## [br]
## @api framework_internal
## [br]
## @param root: 有效版本根。
## [br]
## @param level: 版本固定的树高。
## [br]
## @param index: 已检查范围的记录位置。
## [br]
## @return: 内部只读记录，不得发布原始可变数据引用。
func get_record(
	root: int,
	level: int,
	index: int
) -> GFDataSnapshot:
	var cursor: int = root
	for depth: int in range(
		level,
		-1,
		-1
	):
		cursor = _nodes[cursor]._children[(index >> (depth * 5)) & 31]
	return _nodes[cursor]._snapshot


## 为捕获输出引用槽预留空间；已预留部分直到物理释放才退还。
## [br]
## @api framework_internal
## [br]
## @param amount: 非负计费字节数。
## [br]
## @return: 预留成功时为 true。
func reserve_bytes(amount: int) -> bool:
	if amount < 0 or amount > _max_bytes - _charged_bytes:
		return false
	_charged_bytes += amount
	_peak_bytes = maxi(_peak_bytes, _charged_bytes)
	return true


## 退还已实际释放的输出预留。
## [br]
## @api framework_internal
## [br]
## @param amount: 本次预留所有者持有的非负字节数。
func return_bytes(amount: int) -> void:
	_charged_bytes -= amount


## 至多回收指定节点数；每个引用页最多再入队 32 个节点。
## [br]
## @api framework_internal
## [br]
## @param max_nodes: 正数回收步数。
## [br]
## @return: 本次已物理回收节点数。
func collect(max_nodes: int) -> int:
	var collected: int = 0
	while not _garbage.is_empty() and collected < max_nodes:
		var node_id: int = _garbage.pop_back()
		var entry: _Entry = _nodes[node_id]
		for child: int in entry._children:
			release_node(child)
		_charged_bytes -= entry._bytes
		var _erased: bool = _nodes.erase(node_id)
		collected += 1
	return collected


## 返回计费、保留版本与待回收数量副本。
## [br]
## @api framework_internal
## [br]
## @return: 仅包含标量的当前统计。
## [br]
## @schema return: Dictionary with charged_bytes, peak_bytes, nodes, pending_nodes, versions and readers: int.
func get_statistics() -> Dictionary:
	return {
		"charged_bytes": _charged_bytes,
		"peak_bytes": _peak_bytes,
		"nodes": _nodes.size(),
		"pending_nodes": _garbage.size(),
		"versions": _versions.size(),
		"readers": _readers,
	}


# --- 私有/辅助方法 ---

## 同时检查节点与字节上限，避免仅 payload 有界而元数据无界。
## [br]
## @api private
func _can_allocate(amount: int) -> bool:
	return (
		_next_id < 9_223_372_036_854_775_807
		and _nodes.size() < _max_nodes
		and amount <= _max_bytes - _charged_bytes
	)


## 每个新页显式取得全部子节点持有。
## [br]
## @api private
func _add_page(slots: Array[int]) -> int:
	if not _can_allocate(_PAGE_BYTES):
		return 0
	var entry: _Entry = _Entry.new()
	entry._children = slots
	entry._bytes = _PAGE_BYTES
	for child: int in slots:
		retain_node(child)
	return _insert(entry)


## 新节点从一个临时根持有开始，父页连接后调用者应退还临时持有。
## [br]
## @api private
func _insert(entry: _Entry) -> int:
	var node_id: int = _next_id
	_next_id += 1
	_nodes[node_id] = entry
	_charged_bytes += entry._bytes
	_peak_bytes = maxi(_peak_bytes, _charged_bytes)
	return node_id


# --- 内部类 ---

## 页与记录共用的 arena 节点；子引用只用整数表示，避免递归析构。
## [br]
## @api private
class _Entry extends RefCounted:


	# --- 私有变量 ---

	## 页连接和根租约合计；零引用节点已进入回收队列。
	## [br]
	## @api private
	var _references: int = 1

	## 引用页固定槽位；记录节点为空。
	## [br]
	## @api private
	var _children: Array[int] = []

	## 记录节点持有已隔离快照；引用页为 null。
	## [br]
	## @api private
	var _snapshot: GFDataSnapshot = null

	## 本节点被物理回收时退还的计费值。
	## [br]
	## @api private
	var _bytes: int = 0
