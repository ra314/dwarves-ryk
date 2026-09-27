class_name DiceView
extends Control
## A die drawn as if it has just been rolled onto the table: its own shape per
## type, a random tilt, a drop shadow and the rolled face on top. Click to select.

signal picked(on: bool)

const SIZE := 68.0
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

var die_type: String = "d6"
var value: int = 1
var used: bool = false
var selected: bool = false
var body: Color = Color.WHITE
var tilt: float = 0.0
var nudge: Vector2 = Vector2.ZERO

## A die in reserve: no rolled value, not clickable.
var blank: bool = false

var _rolling: float = 0.0   # 1 -> 0 while tumbling
var _shown: int = 1


func _init(side: float = SIZE) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP


## seed_key makes the tilt stable between redraws but different each round.
func setup(type: String, v: int, is_used: bool, is_selected: bool, colour: Color, seed_key: int) -> void:
	die_type = type
	value = v
	_shown = v
	used = is_used
	selected = is_selected
	body = colour
	var r := RandomNumberGenerator.new()
	r.seed = seed_key
	tilt = r.randf_range(-0.45, 0.45)
	nudge = Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3))
	tooltip_text = "%s showing %d%s" % [type, v, " (spent)" if used else ""]
	mouse_default_cursor_shape = Control.CURSOR_ARROW if used else Control.CURSOR_POINTING_HAND
	queue_redraw()


## A small face-less die for the reserve and next-round displays.
func setup_blank(type: String, colour: Color, seed_key: int) -> void:
	die_type = type
	blank = true
	body = colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := RandomNumberGenerator.new()
	r.seed = seed_key
	tilt = r.randf_range(-0.3, 0.3)
	queue_redraw()


## Tumble for a moment, flicking through faces, then land on the real value.
func roll_in(delay: float = 0.0) -> void:
	_rolling = 1.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_set_rolling, 1.0, 0.0, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_rolling(t: float) -> void:
	_rolling = t
	_shown = value if t < 0.08 else randi_range(1, GameData.die_sides(die_type))
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if used or blank:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		selected = not selected
		queue_redraw()
		picked.emit(selected)
		accept_event()


func _draw() -> void:
	var k := minf(size.x, size.y) / SIZE
	var lift := 4.0 * k if selected else 0.0
	var bounce := -sin(_rolling * PI) * 14.0 * k
	var c := size / 2 + nudge + Vector2(0, bounce - lift)
	var angle := tilt + _rolling * TAU * 1.25
	var side := minf(size.x, size.y)
	var r := side * 0.36
	var ink := _ink()
	var alpha := 0.38 if used else 1.0

	# Shadow on the table, flattened, further away when lifted or bouncing.
	var shadow_off := Vector2(4, 6) * k + Vector2(0, lift - bounce * 0.4)
	draw_set_transform(size / 2 + nudge + shadow_off, angle, Vector2(1.0, 0.8))
	draw_colored_polygon(_outline(r * 1.02), Color(0, 0, 0, 0.35 * alpha))

	draw_set_transform(c, angle, Vector2.ONE)
	if selected:
		draw_polyline(_closed(_outline(r + 6)), Color(1, 0.85, 0.3, 0.9), 3.0, true)
	var flank := body.darkened(0.35)
	var face := body.lightened(0.12)
	flank.a = alpha
	face.a = alpha
	var edge := body.darkened(0.6)
	edge.a = alpha
	draw_colored_polygon(_outline(r), flank)
	draw_colored_polygon(_face(r), face)
	draw_polyline(_closed(_outline(r)), edge, 1.5, true)
	draw_polyline(_closed(_face(r)), edge, 1.0, true)
	for f in _facets(r):
		draw_line(f[0], f[1], edge, 1.0, true)

	# The rolled value, kept upright-ish so it stays readable.
	ink.a = alpha
	if blank:
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	if die_type == "d6":
		for p in PIPS.get(_shown, []):
			draw_circle(p * r * 0.42, r * 0.12, ink)
	else:
		draw_set_transform(c + _face_centre(r).rotated(angle), angle * 0.5, Vector2.ONE)
		var font := get_theme_default_font()
		var fs := int((22 if _shown < 10 else 18) * k)
		var text := str(_shown)
		if _shown in [6, 9]:
			text += "."
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-w / 2, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if used:
		draw_string(get_theme_default_font(), Vector2(4, size.y - 4), die_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))


func _ink() -> Color:
	return Color("1a1a1a") if body.get_luminance() > 0.55 else Color("fbf6ea")


# --- Shapes (in die space, centred on 0,0) --------------------------------------

func _regular(n: int, r: float, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(start + TAU * i / n) * r)
	return pts


## Silhouette of the whole die.
func _outline(r: float) -> PackedVector2Array:
	match die_type:
		"d4": return _regular(3, r * 1.2, -PI / 2)
		"d6": return _regular(4, r * 1.12, PI / 4 + 0.08)
		"d8": return _regular(6, r * 1.08, -PI / 2)
		"d10": return PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 1.05, -r * 0.1), Vector2(0, r * 1.1), Vector2(-r * 1.05, -r * 0.1)])
		_: return _regular(10, r * 1.12, -PI / 2)


## The face pointing up, drawn lighter.
func _face(r: float) -> PackedVector2Array:
	match die_type:
		"d4": return _regular(3, r * 0.95, -PI / 2)
		"d6": return _regular(4, r * 0.98, PI / 4)
		"d8": return _regular(3, r * 1.08, -PI / 2)
		"d10": return PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 0.62, r * 0.05), Vector2(0, r * 0.45), Vector2(-r * 0.62, r * 0.05)])
		_: return _regular(5, r * 0.72, -PI / 2)


## Extra edges that make it read as a solid.
func _facets(r: float) -> Array:
	var out := []
	match die_type:
		"d8":
			var o := _outline(r)
			var f := _face(r)
			# Hexagon corners 1, 3, 5 sit between the face's corners.
			for i in 3:
				out.append([f[i], o[(i * 2 + 1) % 6]])
				out.append([o[(i * 2 + 1) % 6], f[(i + 1) % 3]])
		"d10":
			var o := _outline(r)
			var f := _face(r)
			out.append([f[1], o[1]])
			out.append([f[3], o[3]])
			out.append([f[2], o[2]])
		"d12":
			var o := _outline(r)
			var f := _face(r)
			for i in 5:
				out.append([f[i], o[i * 2]])
		"d4":
			var f := _face(r)
			var o := _outline(r)
			for i in 3:
				out.append([f[i], o[i]])
	return out


func _face_centre(r: float) -> Vector2:
	match die_type:
		"d4": return Vector2(0, r * 0.12)
		"d10": return Vector2(0, -r * 0.2)
	return Vector2.ZERO


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
