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


func test_track_crop_follows_texture_size() -> void:
	# Full-size art: the measured crop as is.
	assert_eq(TrackView.source_rect(Vector2(1016, 1961)), TrackView.CROP)
	# Imported at a 1024px size limit (530x1024): the crop shrinks with it.
	var r := TrackView.source_rect(Vector2(530.5, 1024))
	assert_almost_eq(r.size.y, TrackView.CROP.size.y * 1024.0 / 1961.0, 0.01)
	assert_almost_eq(r.position.x, TrackView.CROP.position.x * 530.5 / 1016.0, 0.01)


func test_imported_track_texture_is_mapped() -> void:
	var tex: Texture2D = load("res://assets/components/turn_track.jpg")
	var r := TrackView.source_rect(tex.get_size())
	assert_true(Rect2(Vector2.ZERO, tex.get_size()).encloses(r), "crop stays inside the real texture")
