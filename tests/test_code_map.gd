extends GutTest
## CLAUDE.md's "Where things are" is the map future sessions use to find code.
## Every script, test and tool must have a line there.

const FOLDERS := ["res://scripts", "res://tests", "res://tools"]


func test_every_file_is_in_the_map() -> void:
	var map := FileAccess.get_file_as_string("res://CLAUDE.md")
	assert_ne(map, "", "CLAUDE.md should be readable")
	var missing := []
	for folder in FOLDERS:
		for path in _files(folder):
			if not map.contains("`%s`" % path.get_file()):
				missing.append(path.trim_prefix("res://"))
	assert_eq(missing, [], "Add these to \"Where things are\" in CLAUDE.md")


static func _files(folder: String) -> Array:
	var out := []
	var d := DirAccess.open(folder)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() in ["gd", "py", "txt"]:
			out.append("%s/%s" % [folder, f])
	for sub in d.get_directories():
		out += _files("%s/%s" % [folder, sub])
	return out
