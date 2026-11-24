# 连续整数线段、端点身份及对称批量布局的公开契约。
extends GutTest


func test_named_contacts_solid_twins_and_positive_length_overlap() -> void:
	var ids: PackedInt64Array = PackedInt64Array(
		[
			0,
			1,
			2,
			3,
			4,
		]
	)
	var points: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(0, 3),
		Vector2i(2, 0),
		Vector2i(-2, 0),
		Vector2i(0, 1),
	]
	var wall: Dictionary = {
		"from": points[0],
		"to": points[1],
		"from_id": 0,
		"to_id": 1,
		"blocked_mask": 6,
	}
	var barriers: Array[Dictionary] = [wall]
	var topology: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		barriers,
		7
	)
	assert_not_null(topology)
	if topology == null:
		return
	assert_eq(
		topology.get_visible_mask(0, 2),
		7
	)
	assert_eq(
		topology.get_visible_mask(2, 3),
		1
	)
	assert_eq(
		topology.get_visible_mask(4, 0),
		1
	)
	assert_eq(
		topology.get_visible_mask(0, 1),
		1
	)
	assert_eq(
		topology.get_visible_mask(4, 4),
		1
	)
	assert_eq(
		topology.get_visible_mask(0, 0),
		7
	)
	barriers.append({ "from": points[0], "to": points[1] })
	var solid: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		barriers,
		7
	)
	assert_eq(
		solid.get_visible_mask(0, 2),
		0
	)


func test_identity_point_barriers_sparse_layers_and_input_ownership() -> void:
	const HIGH: int = 1 << 62
	const FIRST: int = -9223372036854775807 - 1
	const LAST: int = 9223372036854775807
	var ids: PackedInt64Array = PackedInt64Array(
		[
			FIRST,
			-1,
			LAST,
		]
	)
	var points: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i.ZERO,
		Vector2i(3, 0),
	]
	var barriers: Array[Dictionary] = [
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ZERO,
			"from_id": FIRST,
			"blocked_mask": HIGH,
		},
	]
	var topology: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		barriers,
		HIGH | 1
	)
	var first_result: Dictionary = topology.compute_pair_masks()
	assert_eq(
		_successful_masks(first_result),
		PackedInt64Array(
			[
				HIGH | 1,
				HIGH | 1,
				1,
			]
		)
	)
	assert_eq(
		topology.get_visible_mask(-1, -1),
		1
	)
	assert_eq(
		topology.get_visible_mask(FIRST, -1),
		HIGH | 1
	)
	assert_eq(
		topology.get_visible_mask(LAST, 23),
		-1
	)
	assert_eq(
		topology.get_pair_index(FIRST, FIRST),
		-1
	)
	assert_eq(
		topology.get_pair_index(LAST, 23),
		-1
	)
	assert_eq(
		topology.get_pair_index(LAST, FIRST),
		1
	)
	assert_eq(
		topology.get_pair_index(LAST, -1),
		2
	)
	ids[0] = 17
	points[0] = Vector2i.ONE
	barriers[0].clear()
	var owned: PackedInt64Array = first_result.masks
	owned.fill(0)
	assert_eq(
		_successful_masks(topology.compute_pair_masks()),
		PackedInt64Array(
			[
				HIGH | 1,
				HIGH | 1,
				1,
			]
		)
	)


func test_input_admission_validates_masks_coordinates_ids_and_named_endpoints() -> void:
	const B: int = GFSegmentVisibility2D.MAX_COORDINATE
	var ids: PackedInt64Array = PackedInt64Array([7, 8])
	var points: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ONE]
	for invalid: Dictionary in [
		{},
		{ "from": Vector2i.ZERO },
		{ "from": Vector2.ZERO, "to": Vector2i.ONE },
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"from_id": 8,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"to_id": 10,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"from_id": null,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"from_id": 7.0,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"blocked_mask": -1,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"blocked_mask": 8,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"blocked_mask": true,
		},
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"block_mask": 1,
		},
		{
			"from": Vector2i(
				B + 1,
				0
			),
			"to": Vector2i.ONE,
		},
	]:
		var barriers: Array[Dictionary] = [invalid]
		assert_null(
			GFSegmentVisibility2D.create(
				ids,
				points,
				barriers,
				7
			)
		)
	assert_null(
		GFSegmentVisibility2D.create(
			ids,
			points,
			[],
			-1
		)
	)
	assert_null(
		GFSegmentVisibility2D.create(
			PackedInt64Array([7, 7]),
			points,
			[],
			7
		)
	)
	assert_null(
		GFSegmentVisibility2D.create(
			PackedInt64Array(),
			points,
			[],
			7
		)
	)
	points[0] = Vector2i(
		0,
		-B - 1
	)
	assert_null(
		GFSegmentVisibility2D.create(
			ids,
			points,
			[],
			7
		)
	)
	var huge_points: Array[Vector2i] = []
	var huge_ids: PackedInt64Array = PackedInt64Array()
	var size: int = GFSegmentVisibility2D.MAX_POINTS + 1
	assert_eq(
		huge_points.resize(size),
		OK
	)
	assert_eq(
		huge_ids.resize(size),
		OK
	)
	assert_null(
		GFSegmentVisibility2D.create(
			huge_ids,
			huge_points,
			[],
			1
		)
	)
	var huge_walls: Array[Dictionary] = []
	assert_eq(
		huge_walls.resize(GFSegmentVisibility2D.MAX_SEGMENTS + 1),
		OK
	)
	assert_null(
		GFSegmentVisibility2D.create(
			PackedInt64Array(),
			[],
			huge_walls,
			1
		)
	)


func test_batch_bounds_are_checked_before_work_and_empty_is_success() -> void:
	var points: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i.ONE,
		Vector2i(4, 0),
	]
	var ids: PackedInt64Array = PackedInt64Array(
		[
			9,
			4,
			3,
		]
	)
	var walls: Array[Dictionary] = [
		{
			"from": Vector2i.ZERO,
			"to": Vector2i.ONE,
			"blocked_mask": 0,
		},
	]
	var topology: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		walls,
		7
	)
	assert_eq(
		_successful_masks(topology.compute_pair_masks(3, 3)),
		PackedInt64Array(
			[
				7,
				7,
				7,
			]
		)
	)
	_assert_failure(
		topology.compute_pair_masks(2, 3),
		&"pair_budget_exceeded"
	)
	_assert_failure(
		topology.compute_pair_masks(3, 2),
		&"segment_budget_exceeded"
	)
	_assert_failure(
		topology.compute_pair_masks(-1, 3),
		&"invalid_budget"
	)
	_assert_failure(
		topology.compute_pair_masks(
			3,
			GFSegmentVisibility2D.MAX_SEGMENT_TESTS + 1
		),
		&"invalid_budget"
	)
	_assert_failure(
		topology.compute_pair_masks(
			GFSegmentVisibility2D.MAX_PAIRS + 1,
			3
		),
		&"invalid_budget"
	)
	_assert_failure(
		GFSegmentVisibility2D.new().compute_pair_masks(),
		&"unprepared"
	)
	var empty: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		PackedInt64Array(),
		[],
		[],
		7
	)
	assert_eq(
		empty.compute_pair_masks(0, 0),
		{
			"ok": true,
			"error": &"",
			"masks": PackedInt64Array(),
		}
	)
	var single: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		PackedInt64Array([-1]),
		[Vector2i.ZERO],
		[],
		7
	)
	assert_eq(
		single.get_visible_mask(-1, -1),
		7
	)
	assert_eq(
		_successful_masks(single.compute_pair_masks(0, 0)),
		PackedInt64Array()
	)
	var zero: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		walls,
		0
	)
	assert_eq(
		_successful_masks(zero.compute_pair_masks()),
		PackedInt64Array(
			[
				0,
				0,
				0,
			]
		)
	)


func test_large_exact_coordinates_preserve_unit_determinants_and_crossings() -> void:
	const B: int = GFSegmentVisibility2D.MAX_COORDINATE
	var ids: PackedInt64Array = PackedInt64Array(
		[
			0,
			1,
			2,
			3,
		]
	)
	var points: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(
			B,
			B - 1
		),
		Vector2i(-B, -B),
		Vector2i(B, B),
	]
	var almost: Vector2i = Vector2i(
		B - 1,
		B - 2
	)
	var walls: Array[Dictionary] = [
		{ "from": almost, "to": almost },
	]
	var near_line: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		walls,
		1
	)
	assert_eq(
		near_line.get_visible_mask(0, 1),
		1
	)
	walls = [
		{ "from": Vector2i(-B, B), "to": Vector2i(B, -B) },
	]
	var diagonal: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		walls,
		1
	)
	assert_eq(
		diagonal.get_visible_mask(2, 3),
		0
	)
	assert_eq(
		diagonal.get_visible_mask(3, 2),
		0
	)
	walls = [
		{ "from": Vector2i(3, 3), "to": Vector2i(6, 6) },
	]
	var disjoint: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
		ids,
		points,
		walls,
		1
	)
	assert_eq(
		disjoint.get_visible_mask(2, 0),
		1
	)


func test_all_small_lattice_segments_against_parametric_reference() -> void:
	var points: Array[Vector2i] = []
	var ids: PackedInt64Array = PackedInt64Array()
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var _id_added: bool = ids.append(37 - points.size() * 17)
			points.append(Vector2i(x, y))
	for c: Vector2i in points:
		for d: Vector2i in points:
			var walls: Array[Dictionary] = [
				{ "from": c, "to": d },
			]
			var topology: GFSegmentVisibility2D = GFSegmentVisibility2D.create(
				ids,
				points,
				walls,
				3
			)
			var batch: Dictionary = topology.compute_pair_masks()
			var masks: PackedInt64Array = batch.masks
			assert_eq(
				masks.size(),
				36
			)
			var slot: int = 0
			for i: int in range(points.size()):
				for j: int in range(
					i,
					points.size()
				):
					var expected: int = 0 if _oracle_hits(
						points[i],
						points[j],
						c,
						d
					) else 3
					if topology.get_visible_mask(
						ids[j],
						ids[i]
					) != expected:
						fail_test("Integer segment query differs from the parametric reference.")
						return
					if i != j:
						if masks[slot] != expected or topology.get_pair_index(
							ids[j],
							ids[i]
						) != slot:
							fail_test("Packed value or unordered-pair index differs from its reference.")
							return
						slot += 1


func _successful_masks(report: Dictionary) -> PackedInt64Array:
	var masks: Variant = report.get("masks")
	assert_true(masks is PackedInt64Array)
	assert_eq(
		report,
		{
			"ok": true,
			"error": &"",
			"masks": masks,
		}
	)
	if masks is PackedInt64Array:
		return masks
	return PackedInt64Array()


func _assert_failure(report: Dictionary, reason: StringName) -> void:
	assert_eq(
		report,
		{
			"ok": false,
			"error": reason,
			"masks": PackedInt64Array(),
		}
	)


# Independent small-coordinate reference: solve for two segment parameters, then clip their ranges.
func _oracle_hits(
	a: Vector2i,
	b: Vector2i,
	c: Vector2i,
	d: Vector2i
) -> bool:
	var r: Vector2i = b - a
	var s: Vector2i = d - c
	var h: Vector2i = c - a
	if r == Vector2i.ZERO:
		if s == Vector2i.ZERO:
			return a == c
		return _oracle_hits(
			c,
			d,
			a,
			a
		)
	var determinant: int = r.x * s.y - r.y * s.x
	if determinant != 0:
		var t: int = (h.x * s.y - h.y * s.x) * signi(determinant)
		var u: int = (h.x * r.y - h.y * r.x) * signi(determinant)
		return (
			t >= 0
			and t <= absi(determinant)
			and u >= 0
			and u <= absi(determinant)
		)
	if h.x * r.y != h.y * r.x:
		return false
	var t0: int = h.x * r.x + h.y * r.y
	var t1: int = (d.x - a.x) * r.x + (d.y - a.y) * r.y
	var length_squared: int = r.x * r.x + r.y * r.y
	return maxi(
		0,
		mini(t0, t1)
	) <= mini(
		length_squared,
		maxi(t0, t1)
	)
