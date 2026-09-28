## GFGraphLayoutUtility: 通用图布局辅助。
##
## 根据节点标识和连接关系生成编辑器坐标。它只产出布局建议，
## 不依赖 GraphEdit、Resource 或具体业务图类型。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGraphLayoutUtility
extends RefCounted


# --- 公共方法 ---

## 生成分层布局。
## [br]
## @api public
## [br]
## @param node_ids: 节点标识列表。
## [br]
## @param connections: 连接列表，默认读取 from_node_id 与 to_node_id。
## [br]
## @schema connections: Array of Dictionary records containing source and target node ids.
## [br]
## @param options: 选项，支持 x_spacing、y_spacing、origin、from_key 与 to_key。
## [br]
## @schema options: Dictionary layout options including x_spacing, y_spacing, origin, from_key, and to_key.
## [br]
## @return node_id 字符串到 Vector2 的映射。
## [br]
## @schema return: Dictionary mapping node id strings to Vector2 positions.
static func make_layered_layout(
	node_ids: PackedStringArray,
	connections: Array[Dictionary],
	options: Dictionary = {}
) -> Dictionary:
	var from_key: String = GFVariantData.get_option_string(options, "from_key", "from_node_id")
	var to_key: String = GFVariantData.get_option_string(options, "to_key", "to_node_id")
	var origin: Vector2 = _get_option_vector2(options, "origin", Vector2.ZERO)
	var x_spacing: float = GFVariantData.get_option_float(options, "x_spacing", 280.0)
	var y_spacing: float = GFVariantData.get_option_float(options, "y_spacing", 160.0)
	var adjacency: Dictionary = _build_adjacency(node_ids, connections, from_key, to_key)
	var indegree: Dictionary = _build_indegree(node_ids, connections, from_key, to_key)
	var layers: Array[PackedStringArray] = _assign_layers(node_ids, adjacency, indegree)
	return _place_layers(layers, origin, x_spacing, y_spacing)


## 生成简单网格布局。
## [br]
## @api public
## [br]
## @param node_ids: 节点标识列表。
## [br]
## @param options: 选项，支持 columns、x_spacing、y_spacing 与 origin。
## [br]
## @schema options: Dictionary layout options including columns, x_spacing, y_spacing, and origin.
## [br]
## @return node_id 字符串到 Vector2 的映射。
## [br]
## @schema return: Dictionary mapping node id strings to Vector2 positions.
static func make_grid_layout(node_ids: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var columns: int = maxi(1, GFVariantData.get_option_int(options, "columns", 4))
	var origin: Vector2 = _get_option_vector2(options, "origin", Vector2.ZERO)
	var x_spacing: float = GFVariantData.get_option_float(options, "x_spacing", 260.0)
	var y_spacing: float = GFVariantData.get_option_float(options, "y_spacing", 150.0)
	var result: Dictionary = {}
	for index: int in range(node_ids.size()):
		var column: int = index % columns
		var row: int = floori(float(index) / float(columns))
		result[node_ids[index]] = origin + Vector2(column * x_spacing, row * y_spacing)
	return result


# --- 私有/辅助方法 ---

## 为输入节点初始化邻接表，并按连接顺序加入有效且未重复的目标节点。
## [br]
## @api private
static func _build_adjacency(
	node_ids: PackedStringArray,
	connections: Array[Dictionary],
	from_key: String,
	to_key: String
) -> Dictionary:
	var result: Dictionary = {}
	for node_id: String in node_ids:
		result[node_id] = PackedStringArray()

	for connection: Dictionary in connections:
		var from_id: String = GFVariantData.get_option_string(connection, from_key, "")
		var to_id: String = GFVariantData.get_option_string(connection, to_key, "")
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not result.has(from_id) or not result.has(to_id):
			continue
		var targets: PackedStringArray = GFVariantData.get_option_packed_string_array(result, from_id)
		if not targets.has(to_id):
			var _target_appended: bool = targets.append(to_id)
		result[from_id] = targets
	return result


## 按有效连接记录计入度，重复边会重复计数；与去重的邻接表不同，调用方要避免把多重边当作简单图输入。
## [br]
## @api private
static func _build_indegree(
	node_ids: PackedStringArray,
	connections: Array[Dictionary],
	from_key: String,
	to_key: String
) -> Dictionary:
	var result: Dictionary = {}
	for node_id: String in node_ids:
		result[node_id] = 0

	for connection: Dictionary in connections:
		var from_id: String = GFVariantData.get_option_string(connection, from_key, "")
		var to_id: String = GFVariantData.get_option_string(connection, to_key, "")
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not result.has(from_id) or not result.has(to_id):
			continue
		result[to_id] = GFVariantData.get_option_int(result, to_id, 0) + 1
	return result


## 从零入度节点逐层分配并对层内排序；没有起点时以第一个输入节点启动，剩余未排入节点统一放在最后一层。
## 这是布局回退，不是环检测或完整拓扑排序；不修改传入的入度表。
## [br]
## @api private
static func _assign_layers(node_ids: PackedStringArray, adjacency: Dictionary, indegree: Dictionary) -> Array[PackedStringArray]:
	var remaining_indegree: Dictionary = indegree.duplicate(true)
	var queued: Dictionary = {}
	var current: PackedStringArray = PackedStringArray()
	for node_id: String in node_ids:
		if GFVariantData.get_option_int(remaining_indegree, node_id, 0) == 0:
			var _current_appended: bool = current.append(node_id)
			queued[node_id] = true

	if current.is_empty() and not node_ids.is_empty():
		var _fallback_appended: bool = current.append(node_ids[0])
		queued[node_ids[0]] = true

	var layers: Array[PackedStringArray] = []
	while not current.is_empty():
		current.sort()
		layers.append(current)
		var next_layer: PackedStringArray = PackedStringArray()
		for node_id: String in current:
			for target_id: String in GFVariantData.get_option_packed_string_array(adjacency, node_id):
				remaining_indegree[target_id] = maxi(0, GFVariantData.get_option_int(remaining_indegree, target_id, 0) - 1)
				if GFVariantData.get_option_int(remaining_indegree, target_id, 0) == 0 and not queued.has(target_id):
					var _next_appended: bool = next_layer.append(target_id)
					queued[target_id] = true
		current = next_layer

	var leftovers: PackedStringArray = PackedStringArray()
	for node_id: String in node_ids:
		if not queued.has(node_id):
			var _leftover_appended: bool = leftovers.append(node_id)
	if not leftovers.is_empty():
		leftovers.sort()
		layers.append(leftovers)
	return layers


## 按层索引和层内行索引将节点映射到 origin 加间距偏移的位置。
## [br]
## @api private
static func _place_layers(
	layers: Array[PackedStringArray],
	origin: Vector2,
	x_spacing: float,
	y_spacing: float
) -> Dictionary:
	var result: Dictionary = {}
	for layer_index: int in range(layers.size()):
		var layer: PackedStringArray = layers[layer_index]
		for row_index: int in range(layer.size()):
			result[layer[row_index]] = origin + Vector2(layer_index * x_spacing, row_index * y_spacing)
	return result


## 读取指定选项，仅在值为 Vector2 时采用，否则返回传入默认值。
## [br]
## @api private
static func _get_option_vector2(options: Dictionary, key: String, default_value: Vector2) -> Vector2:
	var value: Variant = GFVariantData.get_option_value(options, key, default_value)
	if value is Vector2:
		return value
	return default_value
