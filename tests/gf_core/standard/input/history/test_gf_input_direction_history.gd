## 测试 GFInputDirectionHistory 的最后方向优先规则。
extends GutTest


func test_last_pressed_direction_wins_until_release() -> void:
	var history: GFInputDirectionHistory = GFInputDirectionHistory.new()

	history.press_direction(Vector2i.LEFT)
	history.press_direction(Vector2i.UP)
	assert_eq(
		history.get_current_direction(),
		Vector2i.UP
	)

	history.release_direction(Vector2i.UP)
	assert_eq(
		history.get_current_direction(),
		Vector2i.LEFT
	)


func test_update_action_tracks_action_order() -> void:
	var history: GFInputDirectionHistory = GFInputDirectionHistory.new()

	history.update_action(
		&"move_left",
		Vector2i.LEFT,
		true
	)
	history.update_action(
		&"move_up",
		Vector2i.UP,
		true
	)
	assert_eq(
		history.get_current_action(),
		&"move_up"
	)
	assert_eq(
		history.get_history(),
		[&"move_left", &"move_up"]
	)

	history.update_action(
		&"move_up",
		Vector2i.UP,
		false
	)
	assert_eq(
		history.get_current_action(),
		&"move_left"
	)


func test_clear_resets_state() -> void:
	var history: GFInputDirectionHistory = GFInputDirectionHistory.new()
	history.press_direction(Vector2i.RIGHT)
	history.clear()

	assert_eq(
		history.get_current_direction(),
		Vector2i.ZERO
	)
	assert_eq(
		history.get_history(),
		[]
	)
