## GFSegmentVisibility2D: 按稳定端点身份计算有界整数闭线段之间的可见图层。
## 每份拓扑独立持有已校验的数据，单对查询与批量输出采用相同的接触规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSegmentVisibility2D
extends RefCounted


# --- 常量 ---

## 坐标绝对值上限。坐标差可由 Vector2i 表示，两个乘积的差可由有符号 64 位整数表示。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_COORDINATE: int = (1 << 30) - 1

## 每份拓扑的最大查询点数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_POINTS: int = 2048

## 每份拓扑的最大遮挡线段数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_SEGMENTS: int = 4096

## 一次批量查询允许的最大无序点对数，打包结果最多占 2 MiB。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_PAIRS: int = 262144

## 一次批量查询允许的最大点对数乘以线段数。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_SEGMENT_TESTS: int = 1048576

## 每条线段依次存储两端的 x、y 和两个允许接触的点行号。
## [br]
## @api private
const _SEGMENT_STRIDE: int = 6

## 小批次留在脚本中，避免固定的原生服务查找、协议校验和调用开销。
## [br]
## @api private
const _NATIVE_MIN_SEGMENT_TESTS: int = 8

## GF Native 的内部静态批处理入口，版本属于二进制协议。
## [br]
## @api private
const _NATIVE_CLASS: StringName = &"GfSegmentVisibilityBackend"

## 此版本在一次同步调用内借用拓扑并返回独立结果。
## [br]
## @api private
const _NATIVE_METHOD: StringName = &"compute_pair_masks_v2"


# --- 私有变量 ---

## 按完整有符号 64 位身份查找此拓扑中的点行号。
## [br]
## @api private
var _rows: Dictionary[int, int] = {}

## 按点输入顺序存储的独立交错整数坐标。
## [br]
## @api private
var _xy: PackedInt32Array = PackedInt32Array()

## 校验后的线段坐标及允许接触的行号，匿名端以 -1 表示。
## [br]
## @api private
var _segments: PackedInt32Array = PackedInt32Array()

## 与线段逐行对应的遮挡图层。
## [br]
## @api private
var _blocked: PackedInt64Array = PackedInt64Array()

## 合法掩码使用低 63 位，负值表示尚未创建有效拓扑。
## [br]
## @api private
var _valid_mask: int = -1


# --- 公共方法 ---

## 校验并复制一次拓扑。点 ID 各自唯一，同坐标的不同 ID 保持独立。命名端点必须匹配对应 ID 的坐标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param point_ids: 唯一的有符号 64 位点 ID，顺序决定批量布局。
## [br]
## @param points: 与 ID 一一对应的整数坐标，每个分量的绝对值不超过 MAX_COORDINATE。
## [br]
## @param barriers: 遮挡线段，允许零长度和重复线段。
## [br]
## @schema barriers: Array[Dictionary]。每条必填 from、to（Vector2i），可选 blocked_mask（int，默认 valid_mask）、from_id、to_id（int，缺省为匿名端）。其它字段非法。
## [br]
## @param valid_mask: 可用图层集合，范围 0 至 2^63-1。每条 blocked_mask 必须是其非负子集。
## [br]
## @return: 已准备的只读拓扑。输入无效、超过规模上限或存储分配失败时返回 null。
static func create(
	point_ids: PackedInt64Array,
	points: Array[Vector2i],
	barriers: Array[Dictionary],
	valid_mask: int
) -> GFSegmentVisibility2D:
	var count: int = points.size()
	if (
		valid_mask < 0
		or count != point_ids.size()
		or count > MAX_POINTS
		or barriers.size() > MAX_SEGMENTS
	):
		return null
	var topology: GFSegmentVisibility2D = GFSegmentVisibility2D.new()
	if (
		topology._xy.resize(count * 2) != OK
		or topology._segments.resize(barriers.size() * _SEGMENT_STRIDE) != OK
		or topology._blocked.resize(barriers.size()) != OK
	):
		return null
	for row: int in range(count):
		var point: Vector2i = points[row]
		var id: int = point_ids[row]
		if not _in_bounds(point) or topology._rows.has(id):
			return null
		topology._rows[id] = row
		topology._xy[2 * row] = point.x
		topology._xy[2 * row + 1] = point.y
	topology._valid_mask = valid_mask
	for index: int in range(barriers.size()):
		if not topology._store_barrier(
			index,
			barriers[index]
		):
			return null
	return topology


## 查询两个稳定 ID 之间可见的图层，交换 ID 得到相同结果。同一点或重合点按零长度查询处理。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param first_id: 查询一端的点 ID。
## [br]
## @param second_id: 查询另一端的点 ID。
## [br]
## @return: 从有效图层中扣除所有相交障碍的遮挡位。仅接触已命名的同一端点时放行，正长度共线重叠仍遮挡。未知 ID 返回 -1，完全遮挡返回 0。
func get_visible_mask(first_id: int, second_id: int) -> int:
	var first: int = _rows.get(first_id, -1)
	var second: int = _rows.get(second_id, -1)
	if first < 0 or second < 0:
		return -1
	return _visible_between(first, second)


## 返回无序点对在批量结果中的索引，项目可用稳定 ID 查询独立保留的掩码数组。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param first_id: 查询一端的点 ID。
## [br]
## @param second_id: 查询另一端的点 ID。
## [br]
## @return: 按输入行 i < j 的字典序打包的索引。未知 ID 或同一 ID 返回 -1。
func get_pair_index(first_id: int, second_id: int) -> int:
	var first: int = _rows.get(first_id, -1)
	var second: int = _rows.get(second_id, -1)
	if (
		first < 0
		or second < 0
		or first == second
	):
		return -1
	var i: int = mini(first, second)
	var j: int = maxi(first, second)
	return ((i * (2 * _rows.size() - i - 1)) >> 1) + j - i - 1


## 一次计算所有不同点行之间的可见图层。按保守上界在分配结果前准入，失败时返回空数组。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param max_pairs: 输出点对预算，范围 0 至 MAX_PAIRS。
## [br]
## @param max_segment_tests: 点对数乘以输入障碍数的预算，范围 0 至 MAX_SEGMENT_TESTS。
## [br]
## @return: 独立的批量结果。零或一个点合法，成功时数组为空。
## [br]
## @schema return: Dictionary，含 ok（bool）、error（StringName）、backend（StringName）和 masks（调用方持有的 PackedInt64Array）。backend 为实际执行的 gdscript 或 native，准入失败时为空。成功的 error 为空，失败原因为 unprepared、invalid_budget、pair_budget_exceeded、segment_budget_exceeded、allocation_failed 或 native_failed。
func compute_pair_masks(max_pairs: int = MAX_PAIRS, max_segment_tests: int = MAX_SEGMENT_TESTS) -> Dictionary:
	if _valid_mask < 0:
		return _failure(&"unprepared")
	if (
		max_pairs < 0
		or max_pairs > MAX_PAIRS
		or max_segment_tests < 0
		or max_segment_tests > MAX_SEGMENT_TESTS
	):
		return _failure(&"invalid_budget")
	var count: int = _rows.size()
	var pairs: int = (count * (count - 1)) >> 1
	if pairs > max_pairs:
		return _failure(&"pair_budget_exceeded")
	var segment_tests: int = pairs * _blocked.size()
	if segment_tests > max_segment_tests:
		return _failure(&"segment_budget_exceeded")
	var masks: PackedInt64Array = PackedInt64Array()
	var backend: StringName = &"gdscript"
	if (
		segment_tests >= _NATIVE_MIN_SEGMENT_TESTS
		and _valid_mask != 0
		and _has_native_batch()
	):
		backend = &"native"
		var value: Variant = ClassDB.class_call_static(
			_NATIVE_CLASS,
			_NATIVE_METHOD,
			_xy,
			_segments,
			_blocked,
			_valid_mask
		)
		if value is int and value == ERR_OUT_OF_MEMORY:
			return _failure(&"allocation_failed", backend)
		if not value is PackedInt64Array:
			return _failure(&"native_failed", backend)
		masks = value
		if masks.size() != pairs:
			return _failure(&"native_failed", backend)
	elif masks.resize(pairs) != OK:
		return _failure(&"allocation_failed", backend)
	elif _blocked.is_empty() or _valid_mask == 0:
		masks.fill(_valid_mask)
	else:
		var index: int = 0
		for first: int in range(count):
			for second: int in range(
				first + 1,
				count
			):
				masks[index] = _visible_between(first, second)
				index += 1
	return {
		"ok": true,
		"error": &"",
		"backend": backend,
		"masks": masks,
	}


# --- 私有/辅助方法 ---

## 通过 ClassDB 查询静态协议。工作线程加速仅在已验收的 Windows x64 启用。
## [br]
## @api private
static func _has_native_batch() -> bool:
	if not Thread.is_main_thread():
		if OS.get_name() != "Windows" or Engine.get_architecture_name() != "x86_64":
			return false
	return ClassDB.class_get_method_argument_count(
		_NATIVE_CLASS,
		_NATIVE_METHOD,
		true
	) == 4


## 先检查每个坐标，保证后续差向量与叉积全程精确。
## [br]
## @api private
static func _in_bounds(point: Vector2i) -> bool:
	return absi(point.x) <= MAX_COORDINATE and absi(point.y) <= MAX_COORDINATE


## 将合法线段写入拓扑的自有缓冲，在几何循环外完成字段和端点身份校验。
## [br]
## @api private
func _store_barrier(index: int, barrier: Dictionary) -> bool:
	if barrier.size() < 2 or barrier.size() > 5:
		return false
	for key: Variant in barrier:
		if key not in [
			"from",
			"to",
			"blocked_mask",
			"from_id",
			"to_id",
		]:
			return false
	var start_value: Variant = barrier.get("from")
	var end_value: Variant = barrier.get("to")
	var mask_value: Variant = barrier.get("blocked_mask", _valid_mask)
	if (
		not start_value is Vector2i
		or not end_value is Vector2i
		or not mask_value is int
	):
		return false
	var start: Vector2i = start_value
	var end: Vector2i = end_value
	var mask: int = mask_value
	if (
		not _in_bounds(start)
		or not _in_bounds(end)
		or mask < 0
		or (mask & _valid_mask) != mask
	):
		return false
	var start_row: int = _endpoint_row(
		barrier,
		&"from_id",
		start
	)
	var end_row: int = _endpoint_row(
		barrier,
		&"to_id",
		end
	)
	if start_row < -1 or end_row < -1:
		return false
	var base: int = index * _SEGMENT_STRIDE
	_segments[base] = start.x
	_segments[base + 1] = start.y
	_segments[base + 2] = end.x
	_segments[base + 3] = end.y
	_segments[base + 4] = start_row
	_segments[base + 5] = end_row
	_blocked[index] = mask
	return true


## 匿名端返回 -1，关联有效时返回点行号，关联非法时返回 -2。
## [br]
## @api private
func _endpoint_row(
	barrier: Dictionary,
	key: StringName,
	position: Vector2i
) -> int:
	if not barrier.has(key):
		return -1
	var value: Variant = barrier[key]
	if not value is int:
		return -2
	var id: int = value
	var row: int = _rows.get(id, -1)
	if (
		row < 0
		or _xy[2 * row] != position.x
		or _xy[2 * row + 1] != position.y
	):
		return -2
	return row


## 对有界差向量的整数分量做 64 位乘法，避免浮点舍入。
## [br]
## @api private
static func _cross(u: Vector2i, v: Vector2i) -> int:
	return u.x * v.y - u.y * v.x


## 比较叉积符号，避免两个合法的 64 位叉积相乘溢出。
## [br]
## @api private
static func _same_side(left: int, right: int) -> bool:
	return (
		(
			left > 0
			and right > 0
		)
		or (
			left < 0
			and right < 0
		)
	)


## 按闭线段相交消去遮挡位。坐标差已在准入时保证可由 Vector2i 表示。
## [br]
## @api private
func _visible_between(first: int, second: int) -> int:
	var a: Vector2i = Vector2i(
		_xy[2 * first],
		_xy[2 * first + 1]
	)
	var b: Vector2i = Vector2i(
		_xy[2 * second],
		_xy[2 * second + 1]
	)
	var low: Vector2i = a.min(b)
	var high: Vector2i = a.max(b)
	var ab: Vector2i = b - a
	var visible: int = _valid_mask
	for index: int in range(_blocked.size()):
		var mask: int = _blocked[index]
		if (visible & mask) == 0:
			continue
		var base: int = index * _SEGMENT_STRIDE
		var c: Vector2i = Vector2i(
			_segments[base],
			_segments[base + 1]
		)
		var d: Vector2i = Vector2i(
			_segments[base + 2],
			_segments[base + 3]
		)
		var near: Vector2i = low.max(c.min(d))
		var far: Vector2i = high.min(c.max(d))
		if near.x > far.x or near.y > far.y:
			continue
		var abc: int = _cross(
			ab,
			c - a
		)
		var abd: int = _cross(
			ab,
			d - a
		)
		if _same_side(abc, abd):
			continue
		var cd: Vector2i = d - c
		if _same_side(
			_cross(
				cd,
				a - c
			),
			_cross(
				cd,
				b - c
			)
		):
			continue
		# 两侧均未严格分离。只有共线且公共包围盒有长度时才是正长度重叠。
		if (
			abc != 0
			or abd != 0
			or near == far
		):
			var start_row: int = _segments[base + 4]
			var end_row: int = _segments[base + 5]
			if (
				first == start_row
				or first == end_row
				or second == start_row
				or second == end_row
			):
				continue
		visible &= ~mask
		if visible == 0:
			break
	return visible


## 所有失败采用同一结构，每次独立返回空的打包数组。
## [br]
## @api private
static func _failure(reason: StringName, backend: StringName = &"") -> Dictionary:
	return {
		"ok": false,
		"error": reason,
		"backend": backend,
		"masks": PackedInt64Array(),
	}
