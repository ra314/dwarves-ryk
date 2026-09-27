class_name TrackView
extends Control
## The printed turn track, cropped to its grid of cells, with a glowing marker on
## the current cell. Cells snake four per row, left-to-right then right-to-left,
## matching spawn_per_cell in game_data.json.

## Grid area of components/turn_track.jpg (1016x1961), and its cell centres.
const CROP := Rect2(190, 520, 636, 1262)
const COL_X := [271.0, 428.0, 585.0, 742.0]
const ROW_Y := [600.0, 757.0, 914.0, 1071.0, 1228.0, 1385.0, 1542.0, 1699.0]
const CELL := 124.0

var texture: Texture2D
var index: int = 0
var spawn_text: String = ""
var _glow: float = 0.0


func _init(tex: Texture2D, width: float) -> void:
	texture = tex
	custom_minimum_size = Vector2(width, width * CROP.size.y / CROP.size.x)
	var tw := create_tween().set_loops()
	tw.tween_method(func(v: float): _glow = v; queue_redraw(), 0.0, 1.0, 0.9)
	tw.tween_method(func(v: float): _glow = v; queue_redraw(), 1.0, 0.0, 0.9)


func show_index(i: int, spawn) -> void:
	index = i
	spawn_text = "Next spawn: %s per spawn point" % spawn if spawn != null else "The enemy has won"
	tooltip_text = "Turn track, cell %d of %d. %s" % [i + 1, ROW_Y.size() * 4, spawn_text]
	queue_redraw()


static func cell_centre(i: int) -> Vector2:
	var row := i / 4
	var col := i % 4 if row % 2 == 0 else 3 - i % 4
	return Vector2(COL_X[col], ROW_Y[row])


func _draw() -> void:
	var dest := Rect2(Vector2.ZERO, size)
	var k := size.x / CROP.size.x
	if texture != null:
		draw_texture_rect_region(texture, dest, CROP)
	else:
		draw_rect(dest, Color("5d7f95"))
	var c := (cell_centre(index) - CROP.position) * k
	var half := Vector2(CELL, CELL) * k * 0.5
	var box := Rect2(c - half, half * 2).grow(3)
	var glow := Color(1.0, 0.25, 0.15, 0.25 + 0.3 * _glow)
	draw_rect(box.grow(3 + 3 * _glow), glow, false, 4)
	draw_rect(box, Color(0.85, 0.1, 0.05, 0.35))
	draw_rect(box, Color(1, 0.3, 0.2), false, 3)
