## GFWaveFunctionCollapse2D: 二维格子 Wave Function Collapse 约束求解工具。
##
## 该工具实现简单 tiled WFC 的纯数据核心：调用方声明 tile id、权重、四向邻接规则、
## 固定格和 seed，工具输出格子到 tile id 的结果、剩余 domain 和诊断报告。它不创建
## TileMap、图片、场景节点、资源文件或项目业务对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFWaveFunctionCollapse2D
extends RefCounted


# --- 枚举 ---

## 选择下一个待坍缩格子的启发式。
## [br]
## @api public
## [br]
## @since 8.0.0
enum Heuristic {
	## 使用加权 Shannon entropy，优先处理信息量最低的未决格。
	ENTROPY,
	## 使用 minimum remaining values，优先处理候选 tile 数量最少的未决格。
	MRV,
	## 使用稳定的 y/x 行优先顺序，便于调试规则。
	SCANLINE,
}


# --- 常量 ---

## 有效完成状态。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATUS_COMPLETE: StringName = &"complete"

## 规则或固定格导致 domain 为空的状态。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATUS_CONTRADICTION: StringName = &"contradiction"

## 达到 `max_steps` 但仍有未决格的状态。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATUS_STEP_LIMIT: StringName = &"step_limit"

## 输入无效状态。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATUS_INVALID_INPUT: StringName = &"invalid_input"

## 默认最大格子数，避免误把超大 WFC 任务交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_CELLS: int = 4096

## 默认最大 tile 数。简单 tiled WFC 的传播成本随 tile 数增长。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_TILES: int = 128

const _ALGORITHM: StringName = &"wave_function_collapse_2d"
const _INVALID_CELL: Vector2i = Vector2i(-2147483648, -2147483648)
const _INVALID_DIRECTION: Vector2i = Vector2i(2147483647, 2147483647)
const _DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]
const _OPPOSITE_DIRECTIONS: Dictionary = {
	Vector2i.RIGHT: Vector2i.LEFT,
	Vector2i.LEFT: Vector2i.RIGHT,
	Vector2i.DOWN: Vector2i.UP,
	Vector2i.UP: Vector2i.DOWN,
}


# --- 公共方法 ---

## 求解二维格子的简单 tiled Wave Function Collapse。
## [br]
## 空 `adjacency_rules` 表示邻接不受限制；一旦声明任意规则，未声明的方向和组合视为禁止。
## 文字 tile id 会归一为 `StringName`，整数 tile id 会保留为 `int`。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param tiles: tile 声明数组。
## [br]
## @schema tiles: Array，每项可以是 int/String/StringName tile id，或包含 id 与可选 weight 的 Dictionary。weight 必须是有限正数。
## [br]
## @param adjacency_rules: 四向邻接规则数组。
## [br]
## @schema adjacency_rules: Array[Dictionary]，每项包含 from、to、direction，可选 bidirectional。direction 支持 Vector2i.RIGHT/LEFT/DOWN/UP 或 right/east/left/west/down/south/up/north。
## [br]
## @param options: 求解选项。
## [br]
## @schema options: Dictionary 支持 seed: int、heuristic: Heuristic|StringName、periodic: bool、fixed_cells: Dictionary[Vector2i, tile id]、bidirectional_rules: bool、max_cells: int、max_tiles: int、max_steps: int。
## [br]
## @return 求解报告。
## [br]
## @schema return: Dictionary，包含 ok、error、status、algorithm、grid_size、seed、heuristic、periodic、cell_count、max_cells、tile_count、max_tiles、max_steps、step_count、collapsed_count、undecided_count、contradiction_cell、grid 和 domains。
static func solve_grid(
	grid_size: Vector2i,
	tiles: Array,
	adjacency_rules: Array[Dictionary],
	options: Dictionary = {}
) -> Dictionary:
	var seed_value: int = GFVariantData.get_option_int(options, "seed", 0)
	var heuristic: StringName = _normalize_heuristic(GFVariantData.get_option_value(options, "heuristic", Heuristic.ENTROPY))
	var periodic: bool = GFVariantData.get_option_bool(options, "periodic", false)
	var max_cells: int = maxi(GFVariantData.get_option_int(options, "max_cells", DEFAULT_MAX_CELLS), 1)
	var max_tiles: int = maxi(GFVariantData.get_option_int(options, "max_tiles", DEFAULT_MAX_TILES), 1)
	var cell_count: int = grid_size.x * grid_size.y
	var max_steps: int = _get_max_steps(options, maxi(cell_count, 0))
	if grid_size.x <= 0 or grid_size.y <= 0:
		return _make_report(
			false,
			STATUS_INVALID_INPUT,
			"grid_size must be positive.",
			grid_size,
			seed_value,
			heuristic,
			periodic,
			maxi(cell_count, 0),
			max_cells,
			[],
			max_tiles,
			max_steps,
			0,
			{},
			_INVALID_CELL
		)
	if cell_count > max_cells:
		return _make_report(
			false,
			STATUS_INVALID_INPUT,
			"cell_count exceeds max_cells.",
			grid_size,
			seed_value,
			heuristic,
			periodic,
			cell_count,
			max_cells,
			[],
			max_tiles,
			max_steps,
			0,
			{},
			_INVALID_CELL
		)

	var tile_report: Dictionary = _parse_tiles(tiles, max_tiles)
	if not GFVariantData.get_option_bool(tile_report, "ok", false):
		return _make_report(
			false,
			STATUS_INVALID_INPUT,
			GFVariantData.get_option_string(tile_report, "error"),
			grid_size,
			seed_value,
			heuristic,
			periodic,
			cell_count,
			max_cells,
			[],
			max_tiles,
			max_steps,
			0,
			{},
			_INVALID_CELL
		)

	var tile_ids: Array = GFVariantData.get_option_array(tile_report, "tile_ids")
	var tile_weights: Dictionary = GFVariantData.get_option_dictionary(tile_report, "weights")
	var tile_set: Dictionary = GFVariantData.get_option_dictionary(tile_report, "tile_set")
	var rule_report: Dictionary = _build_adjacency(tile_ids, tile_set, adjacency_rules, GFVariantData.get_option_bool(options, "bidirectional_rules", true))
	if not GFVariantData.get_option_bool(rule_report, "ok", false):
		return _make_report(
			false,
			STATUS_INVALID_INPUT,
			GFVariantData.get_option_string(rule_report, "error"),
			grid_size,
			seed_value,
			heuristic,
			periodic,
			cell_count,
			max_cells,
			tile_ids,
			max_tiles,
			max_steps,
			0,
			{},
			_INVALID_CELL
		)

	var domains: Dictionary = _make_initial_domains(grid_size, tile_ids)
	var fixed_report: Dictionary = _apply_fixed_cells(domains, grid_size, tile_set, options)
	if not GFVariantData.get_option_bool(fixed_report, "ok", false):
		return _make_report(
			false,
			STATUS_INVALID_INPUT,
			GFVariantData.get_option_string(fixed_report, "error"),
			grid_size,
			seed_value,
			heuristic,
			periodic,
			cell_count,
			max_cells,
			tile_ids,
			max_tiles,
			max_steps,
			0,
			domains,
			_INVALID_CELL
		)

	var allowed_by_direction: Dictionary = GFVariantData.get_option_dictionary(rule_report, "allowed_by_direction")
	var initial_queue: Array[Vector2i] = _get_vector2i_array(fixed_report, "queue")
	var initial_propagation: Dictionary = _propagate(domains, grid_size, allowed_by_direction, periodic, initial_queue)
	if not GFVariantData.get_option_bool(initial_propagation, "ok", false):
		return _make_report(
			false,
			STATUS_CONTRADICTION,
			GFVariantData.get_option_string(initial_propagation, "error"),
			grid_size,
			seed_value,
			heuristic,
			periodic,
			cell_count,
			max_cells,
			tile_ids,
			max_tiles,
			max_steps,
			0,
			domains,
			_get_report_cell(initial_propagation, "cell", _INVALID_CELL)
		)

	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(seed_value)
	var step_count: int = 0
	while true:
		var next_cell: Vector2i = _select_next_cell(domains, grid_size, heuristic, tile_weights, rng)
		if next_cell == _INVALID_CELL:
			return _make_report(
				true,
				STATUS_COMPLETE,
				"",
				grid_size,
				seed_value,
				heuristic,
				periodic,
				cell_count,
				max_cells,
				tile_ids,
				max_tiles,
				max_steps,
				step_count,
				domains,
				_INVALID_CELL
			)
		if step_count >= max_steps:
			return _make_report(
				false,
				STATUS_STEP_LIMIT,
				"max_steps reached before all cells collapsed.",
				grid_size,
				seed_value,
				heuristic,
				periodic,
				cell_count,
				max_cells,
				tile_ids,
				max_tiles,
				max_steps,
				step_count,
				domains,
				_INVALID_CELL
			)

		var selected_tile: Variant = _choose_weighted_tile(_get_domain(domains, next_cell), tile_ids, tile_weights, rng)
		domains[next_cell] = { selected_tile: true }
		step_count += 1
		var propagation: Dictionary = _propagate(domains, grid_size, allowed_by_direction, periodic, [next_cell])
		if not GFVariantData.get_option_bool(propagation, "ok", false):
			return _make_report(
				false,
				STATUS_CONTRADICTION,
				GFVariantData.get_option_string(propagation, "error"),
				grid_size,
				seed_value,
				heuristic,
				periodic,
				cell_count,
				max_cells,
				tile_ids,
				max_tiles,
				max_steps,
				step_count,
				domains,
				_get_report_cell(propagation, "cell", next_cell)
			)

	return _make_report(
		false,
		STATUS_STEP_LIMIT,
		"solver stopped unexpectedly.",
		grid_size,
		seed_value,
		heuristic,
		periodic,
		cell_count,
		max_cells,
		tile_ids,
		max_tiles,
		max_steps,
		step_count,
		domains,
		_INVALID_CELL
	)


## 将 WFC 求解报告转换为 JSON.stringify() 安全的结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: solve_grid() 返回的报告。
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return: JSON 兼容报告。
## [br]
## @schema report: GFWaveFunctionCollapse2D 返回的求解或规则展开报告。
## [br]
## @schema options: GFReportValueCodec 编码选项字典。
## [br]
## @schema return: 可安全交给 JSON.stringify() 的 Dictionary。
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	var codec_options: Dictionary = options.duplicate(true)
	if not codec_options.has("encode_dictionary_keys"):
		codec_options["encode_dictionary_keys"] = true
	return GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(report, codec_options))


## 按 2D 网格变换和 tile id 重映射展开邻接规则。
## [br]
## 用于把少量方向性规则扩展为旋转、镜像或对角翻转后的规则集合。该方法只处理
## `from`、`to`、`direction` 与可选 `bidirectional` 字段，不创建 tile 变体、不读取资源，
## 也不假设 tile 的业务含义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param adjacency_rules: 基础四向邻接规则数组。
## [br]
## @schema adjacency_rules: Array[Dictionary]，每项包含 from、to、direction，可选 bidirectional。tile id 归一规则与 solve_grid() 一致。
## [br]
## @param transform_specs: 规则变换声明数组。
## [br]
## @schema transform_specs: Array[Dictionary]，每项包含 transform: GFGridTransform2D.Transform，可选 tile_remaps: Dictionary[原 tile id, 变换后 tile id]。空数组表示只做 identity 归一化与去重。
## [br]
## @param options: 展开选项。
## [br]
## @schema options: Dictionary 支持 preserve_unknown_remaps: bool，默认为 true；为 false 时缺少 tile_remaps 的规则会被跳过。
## [br]
## @return 展开报告。
## [br]
## @schema return: Dictionary，包含 ok、error、rules、input_rule_count、transform_count、expanded_count、duplicate_count 和 skipped_count。
static func expand_transformed_adjacency_rules(
	adjacency_rules: Array[Dictionary],
	transform_specs: Array[Dictionary],
	options: Dictionary = {}
) -> Dictionary:
	var preserve_unknown_remaps: bool = GFVariantData.get_option_bool(options, "preserve_unknown_remaps", true)
	var spec_report: Dictionary = _normalize_rule_transform_specs(transform_specs)
	if not GFVariantData.get_option_bool(spec_report, "ok", false):
		return _make_adjacency_expansion_failure(GFVariantData.get_option_string(spec_report, "error"))

	var normalized_specs: Array[Dictionary] = _get_dictionary_array(spec_report, "transform_specs")
	var expanded_rules: Array[Dictionary] = []
	var seen_keys: Dictionary = {}
	var duplicate_count: int = 0
	var skipped_count: int = 0
	for rule: Dictionary in adjacency_rules:
		var rule_report: Dictionary = _normalize_adjacency_rule_for_expansion(rule)
		if not GFVariantData.get_option_bool(rule_report, "ok", false):
			return _make_adjacency_expansion_failure(GFVariantData.get_option_string(rule_report, "error"))

		var normalized_rule: Dictionary = GFVariantData.get_option_dictionary(rule_report, "rule")
		for transform_spec: Dictionary in normalized_specs:
			var transform_report: Dictionary = _transform_adjacency_rule(
				normalized_rule,
				transform_spec,
				preserve_unknown_remaps
			)
			if not GFVariantData.get_option_bool(transform_report, "ok", false):
				return _make_adjacency_expansion_failure(GFVariantData.get_option_string(transform_report, "error"))
			if GFVariantData.get_option_bool(transform_report, "skipped", false):
				skipped_count += 1
				continue

			var transformed_rule: Dictionary = GFVariantData.get_option_dictionary(transform_report, "rule")
			var rule_key: String = _make_adjacency_rule_key(transformed_rule)
			if seen_keys.has(rule_key):
				duplicate_count += 1
				continue

			seen_keys[rule_key] = true
			expanded_rules.append(transformed_rule)

	return {
		"ok": true,
		"error": "",
		"rules": expanded_rules,
		"input_rule_count": adjacency_rules.size(),
		"transform_count": normalized_specs.size(),
		"expanded_count": expanded_rules.size(),
		"duplicate_count": duplicate_count,
		"skipped_count": skipped_count,
	}


# --- 私有/辅助方法 ---

static func _get_max_steps(options: Dictionary, cell_count: int) -> int:
	var requested: int = GFVariantData.get_option_int(options, "max_steps", cell_count)
	return maxi(requested, 1)


static func _normalize_heuristic(value: Variant) -> StringName:
	if value is int:
		var heuristic_index: int = value
		match heuristic_index:
			Heuristic.MRV:
				return &"mrv"
			Heuristic.SCANLINE:
				return &"scanline"
			_:
				return &"entropy"

	var heuristic_name: StringName = GFVariantData.to_string_name(value, &"entropy")
	match heuristic_name:
		&"mrv", &"minimum_remaining_values":
			return &"mrv"
		&"scanline", &"row_major":
			return &"scanline"
		_:
			return &"entropy"


static func _parse_tiles(tiles: Array, max_tiles: int) -> Dictionary:
	if tiles.is_empty():
		return _make_failure("tiles must not be empty.")
	if tiles.size() > max_tiles:
		return _make_failure("tile count exceeds max_tiles.")

	var tile_ids: Array = []
	var weights: Dictionary = {}
	var tile_set: Dictionary = {}
	for raw_entry: Variant in tiles:
		var raw_tile_id: Variant = raw_entry
		var weight: float = 1.0
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			raw_tile_id = GFVariantData.get_option_value(entry, "id")
			weight = GFVariantData.get_option_float(entry, "weight", 1.0)

		var tile_report: Dictionary = _normalize_tile_id(raw_tile_id)
		if not GFVariantData.get_option_bool(tile_report, "ok", false):
			return _make_failure(GFVariantData.get_option_string(tile_report, "error"))

		var tile_id: Variant = GFVariantData.get_option_value(tile_report, "id")
		if tile_set.has(tile_id):
			return _make_failure("duplicate tile id.")
		if weight <= 0.0 or is_nan(weight) or is_inf(weight):
			return _make_failure("tile weight must be a finite positive number.")

		tile_ids.append(tile_id)
		weights[tile_id] = weight
		tile_set[tile_id] = true

	return {
		"ok": true,
		"error": "",
		"tile_ids": tile_ids,
		"weights": weights,
		"tile_set": tile_set,
	}


static func _normalize_tile_id(value: Variant) -> Dictionary:
	if value is int:
		var int_id: int = value
		return {
			"ok": true,
			"error": "",
			"id": int_id,
		}
	if value is StringName:
		var string_name_id: StringName = value
		if string_name_id == &"":
			return _make_failure("tile id must not be empty.")
		return {
			"ok": true,
			"error": "",
			"id": string_name_id,
		}
	if value is String:
		var text_id: String = value
		var trimmed_id: String = text_id.strip_edges()
		if trimmed_id.is_empty():
			return _make_failure("tile id must not be empty.")
		return {
			"ok": true,
			"error": "",
			"id": StringName(trimmed_id),
		}

	return _make_failure("tile id must be int, String, or StringName.")


static func _normalize_adjacency_rule_for_expansion(rule: Dictionary) -> Dictionary:
	var from_report: Dictionary = _normalize_tile_id(GFVariantData.get_option_value(rule, "from"))
	var to_report: Dictionary = _normalize_tile_id(GFVariantData.get_option_value(rule, "to"))
	if not GFVariantData.get_option_bool(from_report, "ok", false):
		return _make_failure("rule.from " + GFVariantData.get_option_string(from_report, "error"))
	if not GFVariantData.get_option_bool(to_report, "ok", false):
		return _make_failure("rule.to " + GFVariantData.get_option_string(to_report, "error"))

	var direction: Vector2i = _normalize_direction(GFVariantData.get_option_value(rule, "direction"))
	if direction == _INVALID_DIRECTION:
		return _make_failure("rule.direction must be one of the four orthogonal directions.")

	var normalized_rule: Dictionary = {
		"from": GFVariantData.get_option_value(from_report, "id"),
		"to": GFVariantData.get_option_value(to_report, "id"),
		"direction": direction,
	}
	if rule.has("bidirectional"):
		normalized_rule["bidirectional"] = GFVariantData.get_option_bool(rule, "bidirectional", true)
	return {
		"ok": true,
		"error": "",
		"rule": normalized_rule,
	}


static func _normalize_rule_transform_specs(transform_specs: Array[Dictionary]) -> Dictionary:
	var normalized_specs: Array[Dictionary] = []
	if transform_specs.is_empty():
		normalized_specs.append({
			"transform": GFGridTransform2D.Transform.IDENTITY,
			"tile_remaps": {},
		})
		return {
			"ok": true,
			"error": "",
			"transform_specs": normalized_specs,
		}

	for transform_spec: Dictionary in transform_specs:
		var transform_value: int = _normalize_grid_transform(
			GFVariantData.get_option_value(
				transform_spec,
				"transform",
				GFGridTransform2D.Transform.IDENTITY
			)
		)
		if not GFGridTransform2D.is_transform_valid(transform_value):
			return _make_failure("transform_specs.transform must be a GFGridTransform2D.Transform value.")

		var tile_remap_report: Dictionary = _normalize_tile_remaps(
			GFVariantData.get_option_dictionary(transform_spec, "tile_remaps")
		)
		if not GFVariantData.get_option_bool(tile_remap_report, "ok", false):
			return _make_failure(GFVariantData.get_option_string(tile_remap_report, "error"))

		normalized_specs.append({
			"transform": transform_value,
			"tile_remaps": GFVariantData.get_option_dictionary(tile_remap_report, "tile_remaps"),
		})

	return {
		"ok": true,
		"error": "",
		"transform_specs": normalized_specs,
	}


static func _normalize_grid_transform(value: Variant) -> int:
	if value is int:
		var transform_value: int = value
		return transform_value

	var transform_name: StringName = GFVariantData.to_string_name(value, &"")
	match transform_name:
		&"identity":
			return GFGridTransform2D.Transform.IDENTITY
		&"rotate_90", &"rotation_90", &"r90":
			return GFGridTransform2D.Transform.ROTATE_90
		&"rotate_180", &"rotation_180", &"r180":
			return GFGridTransform2D.Transform.ROTATE_180
		&"rotate_270", &"rotation_270", &"r270":
			return GFGridTransform2D.Transform.ROTATE_270
		&"mirror_x", &"flip_x":
			return GFGridTransform2D.Transform.MIRROR_X
		&"mirror_y", &"flip_y":
			return GFGridTransform2D.Transform.MIRROR_Y
		&"diagonal_main", &"transpose":
			return GFGridTransform2D.Transform.DIAGONAL_MAIN
		&"diagonal_anti":
			return GFGridTransform2D.Transform.DIAGONAL_ANTI
		_:
			return GFGridTransform2D.INVALID_TRANSFORM


static func _normalize_tile_remaps(tile_remaps: Dictionary) -> Dictionary:
	var normalized_remaps: Dictionary = {}
	for raw_source_id: Variant in tile_remaps.keys():
		var source_report: Dictionary = _normalize_tile_id(raw_source_id)
		var target_report: Dictionary = _normalize_tile_id(GFVariantData.get_option_value(tile_remaps, raw_source_id))
		if not GFVariantData.get_option_bool(source_report, "ok", false):
			return _make_failure("tile_remaps key " + GFVariantData.get_option_string(source_report, "error"))
		if not GFVariantData.get_option_bool(target_report, "ok", false):
			return _make_failure("tile_remaps value " + GFVariantData.get_option_string(target_report, "error"))

		normalized_remaps[GFVariantData.get_option_value(source_report, "id")] = GFVariantData.get_option_value(target_report, "id")

	return {
		"ok": true,
		"error": "",
		"tile_remaps": normalized_remaps,
	}


static func _transform_adjacency_rule(
	rule: Dictionary,
	transform_spec: Dictionary,
	preserve_unknown_remaps: bool
) -> Dictionary:
	var tile_remaps: Dictionary = GFVariantData.get_option_dictionary(transform_spec, "tile_remaps")
	var from_report: Dictionary = _resolve_remapped_tile_id(
		GFVariantData.get_option_value(rule, "from"),
		tile_remaps,
		preserve_unknown_remaps
	)
	var to_report: Dictionary = _resolve_remapped_tile_id(
		GFVariantData.get_option_value(rule, "to"),
		tile_remaps,
		preserve_unknown_remaps
	)
	if GFVariantData.get_option_bool(from_report, "skipped", false) or GFVariantData.get_option_bool(to_report, "skipped", false):
		return {
			"ok": true,
			"error": "",
			"skipped": true,
			"rule": {},
		}

	var transform_value: int = GFVariantData.get_option_int(
		transform_spec,
		"transform",
		GFGridTransform2D.Transform.IDENTITY
	)
	var direction: Vector2i = _get_report_cell(rule, "direction", _INVALID_DIRECTION)
	var transformed_direction: Vector2i = GFGridTransform2D.transform_cardinal_direction(direction, transform_value)
	if transformed_direction == Vector2i.ZERO:
		return _make_failure("rule.direction cannot be transformed.")

	var transformed_rule: Dictionary = {
		"from": GFVariantData.get_option_value(from_report, "id"),
		"to": GFVariantData.get_option_value(to_report, "id"),
		"direction": transformed_direction,
	}
	if rule.has("bidirectional"):
		transformed_rule["bidirectional"] = GFVariantData.get_option_bool(rule, "bidirectional", true)
	return {
		"ok": true,
		"error": "",
		"skipped": false,
		"rule": transformed_rule,
	}


static func _resolve_remapped_tile_id(
	tile_id: Variant,
	tile_remaps: Dictionary,
	preserve_unknown_remaps: bool
) -> Dictionary:
	if tile_remaps.has(tile_id):
		return {
			"ok": true,
			"error": "",
			"skipped": false,
			"id": GFVariantData.get_option_value(tile_remaps, tile_id),
		}
	if preserve_unknown_remaps:
		return {
			"ok": true,
			"error": "",
			"skipped": false,
			"id": tile_id,
		}
	return {
		"ok": true,
		"error": "",
		"skipped": true,
		"id": null,
	}


static func _make_adjacency_rule_key(rule: Dictionary) -> String:
	var direction: Vector2i = _get_report_cell(rule, "direction", _INVALID_DIRECTION)
	var has_bidirectional: bool = rule.has("bidirectional")
	var bidirectional: bool = GFVariantData.get_option_bool(rule, "bidirectional", true)
	return "%s|%s|%d,%d|%s|%s" % [
		_make_tile_key(GFVariantData.get_option_value(rule, "from")),
		_make_tile_key(GFVariantData.get_option_value(rule, "to")),
		direction.x,
		direction.y,
		str(has_bidirectional),
		str(bidirectional),
	]


static func _make_tile_key(tile_id: Variant) -> String:
	if tile_id is int:
		var int_id: int = tile_id
		return "int:" + str(int_id)
	if tile_id is StringName:
		var string_name_id: StringName = tile_id
		return "name:" + String(string_name_id)
	return "other:" + str(tile_id)


static func _build_adjacency(
	tile_ids: Array,
	tile_set: Dictionary,
	adjacency_rules: Array[Dictionary],
	default_bidirectional: bool
) -> Dictionary:
	if adjacency_rules.is_empty():
		return {
			"ok": true,
			"error": "",
			"allowed_by_direction": _make_unrestricted_allowed(tile_ids),
		}

	var allowed_by_direction: Dictionary = _make_empty_allowed(tile_ids)
	for rule: Dictionary in adjacency_rules:
		var from_report: Dictionary = _normalize_tile_id(GFVariantData.get_option_value(rule, "from"))
		var to_report: Dictionary = _normalize_tile_id(GFVariantData.get_option_value(rule, "to"))
		if not GFVariantData.get_option_bool(from_report, "ok", false):
			return _make_failure("rule.from " + GFVariantData.get_option_string(from_report, "error"))
		if not GFVariantData.get_option_bool(to_report, "ok", false):
			return _make_failure("rule.to " + GFVariantData.get_option_string(to_report, "error"))

		var from_tile: Variant = GFVariantData.get_option_value(from_report, "id")
		var to_tile: Variant = GFVariantData.get_option_value(to_report, "id")
		if not tile_set.has(from_tile) or not tile_set.has(to_tile):
			return _make_failure("rule references unknown tile id.")

		var direction: Vector2i = _normalize_direction(GFVariantData.get_option_value(rule, "direction"))
		if direction == _INVALID_DIRECTION:
			return _make_failure("rule.direction must be one of the four orthogonal directions.")

		_add_allowed_edge(allowed_by_direction, direction, from_tile, to_tile)
		if GFVariantData.get_option_bool(rule, "bidirectional", default_bidirectional):
			_add_allowed_edge(allowed_by_direction, direction, to_tile, from_tile)

	return {
		"ok": true,
		"error": "",
		"allowed_by_direction": allowed_by_direction,
	}


static func _normalize_direction(value: Variant) -> Vector2i:
	if value is Vector2i:
		var vector_direction: Vector2i = value
		if _DIRECTIONS.has(vector_direction):
			return vector_direction
		return _INVALID_DIRECTION

	var direction_name: StringName = GFVariantData.to_string_name(value, &"")
	match direction_name:
		&"right", &"east", &"e":
			return Vector2i.RIGHT
		&"left", &"west", &"w":
			return Vector2i.LEFT
		&"down", &"south", &"s":
			return Vector2i.DOWN
		&"up", &"north", &"n":
			return Vector2i.UP
		_:
			return _INVALID_DIRECTION


static func _make_unrestricted_allowed(tile_ids: Array) -> Dictionary:
	var allowed_by_direction: Dictionary = {}
	for direction: Vector2i in _DIRECTIONS:
		var direction_rules: Dictionary = {}
		for from_tile: Variant in tile_ids:
			var targets: Dictionary = {}
			for to_tile: Variant in tile_ids:
				targets[to_tile] = true
			direction_rules[from_tile] = targets
		allowed_by_direction[direction] = direction_rules
	return allowed_by_direction


static func _make_empty_allowed(tile_ids: Array) -> Dictionary:
	var allowed_by_direction: Dictionary = {}
	for direction: Vector2i in _DIRECTIONS:
		var direction_rules: Dictionary = {}
		for tile_id: Variant in tile_ids:
			direction_rules[tile_id] = {}
		allowed_by_direction[direction] = direction_rules
	return allowed_by_direction


static func _add_allowed_pair(
	allowed_by_direction: Dictionary,
	direction: Vector2i,
	from_tile: Variant,
	to_tile: Variant
) -> void:
	var direction_rules: Dictionary = _get_dictionary_value(allowed_by_direction, direction)
	var targets: Dictionary = _get_dictionary_value(direction_rules, from_tile)
	targets[to_tile] = true
	direction_rules[from_tile] = targets
	allowed_by_direction[direction] = direction_rules


static func _add_allowed_edge(
	allowed_by_direction: Dictionary,
	direction: Vector2i,
	from_tile: Variant,
	to_tile: Variant
) -> void:
	_add_allowed_pair(allowed_by_direction, direction, from_tile, to_tile)
	_add_allowed_pair(allowed_by_direction, _opposite_direction(direction), to_tile, from_tile)


static func _opposite_direction(direction: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(_OPPOSITE_DIRECTIONS, direction, _INVALID_DIRECTION)
	if value is Vector2i:
		var opposite: Vector2i = value
		return opposite
	return _INVALID_DIRECTION


static func _make_initial_domains(grid_size: Vector2i, tile_ids: Array) -> Dictionary:
	var domains: Dictionary = {}
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			domains[cell] = _make_full_domain(tile_ids)
	return domains


static func _make_full_domain(tile_ids: Array) -> Dictionary:
	var domain: Dictionary = {}
	for tile_id: Variant in tile_ids:
		domain[tile_id] = true
	return domain


static func _apply_fixed_cells(
	domains: Dictionary,
	grid_size: Vector2i,
	tile_set: Dictionary,
	options: Dictionary
) -> Dictionary:
	var fixed_cells: Dictionary = GFVariantData.get_option_dictionary(options, "fixed_cells")
	var queue: Array[Vector2i] = []
	for raw_cell: Variant in fixed_cells.keys():
		if not raw_cell is Vector2i:
			return _make_failure("fixed_cells keys must be Vector2i.")
		var cell: Vector2i = raw_cell
		if not _is_in_bounds(cell, grid_size):
			return _make_failure("fixed cell is outside grid_size.")

		var tile_report: Dictionary = _normalize_tile_id(GFVariantData.get_option_value(fixed_cells, cell))
		if not GFVariantData.get_option_bool(tile_report, "ok", false):
			return _make_failure("fixed cell " + GFVariantData.get_option_string(tile_report, "error"))

		var tile_id: Variant = GFVariantData.get_option_value(tile_report, "id")
		if not tile_set.has(tile_id):
			return _make_failure("fixed cell references unknown tile id.")

		domains[cell] = { tile_id: true }
		queue.append(cell)

	return {
		"ok": true,
		"error": "",
		"queue": queue,
	}


static func _propagate(
	domains: Dictionary,
	grid_size: Vector2i,
	allowed_by_direction: Dictionary,
	periodic: bool,
	initial_queue: Array[Vector2i]
) -> Dictionary:
	var queue: Array[Vector2i] = []
	queue.append_array(initial_queue)
	var queue_index: int = 0
	while queue_index < queue.size():
		var cell: Vector2i = queue[queue_index]
		queue_index += 1
		var domain: Dictionary = _get_domain(domains, cell)
		if domain.is_empty():
			return _make_contradiction(cell, "domain is empty.")

		for direction: Vector2i in _DIRECTIONS:
			var neighbor: Vector2i = _resolve_neighbor(cell, direction, grid_size, periodic)
			if neighbor == _INVALID_CELL:
				continue

			var allowed_targets: Dictionary = _make_allowed_targets(domain, direction, allowed_by_direction)
			var neighbor_domain: Dictionary = _get_domain(domains, neighbor)
			var changed: bool = false
			for tile_id: Variant in neighbor_domain.keys():
				if allowed_targets.has(tile_id):
					continue

				var _erased: bool = neighbor_domain.erase(tile_id)
				changed = true

			if neighbor_domain.is_empty():
				return _make_contradiction(neighbor, "neighbor domain became empty.")
			if changed:
				domains[neighbor] = neighbor_domain
				queue.append(neighbor)

	return {
		"ok": true,
		"error": "",
		"cell": _INVALID_CELL,
	}


static func _make_allowed_targets(
	domain: Dictionary,
	direction: Vector2i,
	allowed_by_direction: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	var direction_rules: Dictionary = _get_dictionary_value(allowed_by_direction, direction)
	for source_tile: Variant in domain.keys():
		var targets: Dictionary = _get_dictionary_value(direction_rules, source_tile)
		for target_tile: Variant in targets.keys():
			result[target_tile] = true
	return result


static func _resolve_neighbor(
	cell: Vector2i,
	direction: Vector2i,
	grid_size: Vector2i,
	periodic: bool
) -> Vector2i:
	var neighbor: Vector2i = cell + direction
	if _is_in_bounds(neighbor, grid_size):
		return neighbor
	if not periodic:
		return _INVALID_CELL

	return Vector2i(
		posmod(neighbor.x, grid_size.x),
		posmod(neighbor.y, grid_size.y)
	)


static func _select_next_cell(
	domains: Dictionary,
	grid_size: Vector2i,
	heuristic: StringName,
	weights: Dictionary,
	rng: GFDeterministicRandom
) -> Vector2i:
	var best_cell: Vector2i = _INVALID_CELL
	var best_score: float = INF
	var best_tie: float = INF
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var domain: Dictionary = _get_domain(domains, cell)
			if domain.size() <= 1:
				continue
			if heuristic == &"scanline":
				return cell

			var score: float = float(domain.size())
			if heuristic == &"entropy":
				score = _calculate_entropy(domain, weights)
			var tie: float = rng.next_float_unit()
			if score < best_score or (is_equal_approx(score, best_score) and tie < best_tie):
				best_cell = cell
				best_score = score
				best_tie = tie
	return best_cell


static func _calculate_entropy(domain: Dictionary, weights: Dictionary) -> float:
	var weight_sum: float = 0.0
	var weighted_log_sum: float = 0.0
	for tile_id: Variant in domain.keys():
		var weight: float = GFVariantData.get_option_float(weights, tile_id, 1.0)
		weight_sum += weight
		weighted_log_sum += weight * log(weight)
	if weight_sum <= 0.0:
		return INF
	return log(weight_sum) - weighted_log_sum / weight_sum


static func _choose_weighted_tile(
	domain: Dictionary,
	tile_ids: Array,
	weights: Dictionary,
	rng: GFDeterministicRandom
) -> Variant:
	var total_weight: float = 0.0
	for tile_id: Variant in tile_ids:
		if domain.has(tile_id):
			total_weight += GFVariantData.get_option_float(weights, tile_id, 1.0)

	var threshold: float = rng.next_float_unit() * total_weight
	var cumulative: float = 0.0
	var fallback: Variant = null
	for tile_id: Variant in tile_ids:
		if not domain.has(tile_id):
			continue
		if fallback == null:
			fallback = tile_id
		cumulative += GFVariantData.get_option_float(weights, tile_id, 1.0)
		if threshold <= cumulative:
			return tile_id
	return fallback


static func _make_report(
	ok: bool,
	status: StringName,
	error: String,
	grid_size: Vector2i,
	seed_value: int,
	heuristic: StringName,
	periodic: bool,
	cell_count: int,
	max_cells: int,
	tile_ids: Array,
	max_tiles: int,
	max_steps: int,
	step_count: int,
	domains: Dictionary,
	contradiction_cell: Vector2i
) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"status": status,
		"algorithm": _ALGORITHM,
		"grid_size": grid_size,
		"seed": seed_value,
		"heuristic": heuristic,
		"periodic": periodic,
		"cell_count": cell_count,
		"max_cells": max_cells,
		"tile_count": tile_ids.size(),
		"max_tiles": max_tiles,
		"max_steps": max_steps,
		"step_count": step_count,
		"collapsed_count": _count_collapsed_domains(domains),
		"undecided_count": _count_undecided_domains(domains),
		"contradiction_cell": contradiction_cell,
		"grid": _make_collapsed_grid(domains, grid_size),
		"domains": _make_domain_snapshot(domains, grid_size, tile_ids),
	}


static func _make_collapsed_grid(domains: Dictionary, grid_size: Vector2i) -> Dictionary:
	var grid: Dictionary = {}
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var domain: Dictionary = _get_domain(domains, cell)
			if domain.size() == 1:
				grid[cell] = _first_domain_tile(domain)
	return grid


static func _make_domain_snapshot(domains: Dictionary, grid_size: Vector2i, tile_ids: Array) -> Dictionary:
	var snapshot: Dictionary = {}
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var domain: Dictionary = _get_domain(domains, cell)
			var candidates: Array = []
			for tile_id: Variant in tile_ids:
				if domain.has(tile_id):
					candidates.append(tile_id)
			snapshot[cell] = candidates
	return snapshot


static func _count_collapsed_domains(domains: Dictionary) -> int:
	var count: int = 0
	for domain_value: Variant in domains.values():
		if domain_value is Dictionary:
			var domain: Dictionary = domain_value
			if domain.size() == 1:
				count += 1
	return count


static func _count_undecided_domains(domains: Dictionary) -> int:
	var count: int = 0
	for domain_value: Variant in domains.values():
		if domain_value is Dictionary:
			var domain: Dictionary = domain_value
			if domain.size() > 1:
				count += 1
	return count


static func _first_domain_tile(domain: Dictionary) -> Variant:
	for tile_id: Variant in domain.keys():
		return tile_id
	return null


static func _is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


static func _get_domain(domains: Dictionary, cell: Vector2i) -> Dictionary:
	return _get_dictionary_value(domains, cell)


static func _get_dictionary_value(dictionary: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(dictionary, key)
	if value is Dictionary:
		var result: Dictionary = value
		return result
	return {}


static func _get_vector2i_array(report: Dictionary, key: String) -> Array[Vector2i]:
	var values: Array = GFVariantData.get_option_array(report, key)
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if value is Vector2i:
			var cell: Vector2i = value
			result.append(cell)
	return result


static func _get_dictionary_array(report: Dictionary, key: String) -> Array[Dictionary]:
	var values: Array = GFVariantData.get_option_array(report, key)
	var result: Array[Dictionary] = []
	for value: Variant in values:
		if value is Dictionary:
			var entry: Dictionary = value
			result.append(entry)
	return result


static func _get_report_cell(report: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(report, key, fallback)
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return fallback


static func _make_failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
	}


static func _make_adjacency_expansion_failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"rules": [],
		"input_rule_count": 0,
		"transform_count": 0,
		"expanded_count": 0,
		"duplicate_count": 0,
		"skipped_count": 0,
	}


static func _make_contradiction(cell: Vector2i, error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"cell": cell,
	}
