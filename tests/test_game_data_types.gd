extends GutTest
## game_data.json numbers must come through as ints, not floats ("1" not "1.0").


func test_spawn_values_are_ints() -> void:
	var cells := GameData.load_default().spawn_per_cell()
	for v in cells.slice(0, cells.size() - 1):
		assert_typeof(v, TYPE_INT)
	assert_eq(str(cells[0]), "1")
	assert_null(cells.back())


func test_action_numbers_are_ints() -> void:
	var a := GameData.load_default().find_action("mine", true, false, "dig_big")
	assert_typeof(a["min"], TYPE_INT)
	assert_typeof(a["value"], TYPE_INT)


func test_track_tooltip_has_no_decimal() -> void:
	var tv := TrackView.new(null, 100)
	add_child_autofree(tv)
	tv.show_index(0, GameData.load_default().spawn_per_cell()[0])
	assert_string_contains(tv.tooltip_text, "Next spawn: 1 per spawn point")
