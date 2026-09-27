class_name TileView
extends Control
## Draws one grid space: tile image (or a labelled box when assets are missing),
## enemy/warrior counts and Nobles. Emits clicked(pos).

signal clicked(pos: Vector2i)

const TILE_COLOURS := {
	"ruins": Color("4a4038"), "hearth": Color("b5562e"), "mine": Color("6b5a3e"),
	"living_quarters": Color("7a6a4a"), "barracks": Color("6e3b3b"), "city_gate": Color("5a5a70"),
	"tunnel": Color("2b2b2b"), "empty_halls": Color("50585a"), "watchtower": Color("4f6b4f"),
	"blacksmith": Color("5c4a5e"), "encampment": Color("7a3030"), "throne_room": Color("8a7430"),
	"aviary": Color("3f6680"),
}
const NOBLE_COLOURS := {
	"Green": Color("3fae49"), "Red": Color("d63b3b"), "Purple": Color("8e44ad"),
	"Blue": Color("3b7dd6"), "Yellow": Color("e6c229"), "White": Color("f2f2f2"),
}

var pos: Vector2i
var tile: TileState
var nobles: Array = []   # colours of Nobles here
var label: String = ""
var texture: Texture2D
var enemy_icon: Texture2D
var warrior_icon: Texture2D
var highlight: Color = Color(0, 0, 0, 0)
var flash: float = 0.0


func _init(p: Vector2i) -> void:
	pos = p
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_state(t: TileState, tile_name: String, tex: Texture2D, noble_colours: Array) -> void:
	tile = t
	label = tile_name
	texture = tex
	nobles = noble_colours
	queue_redraw()


func pulse() -> void:
	create_tween().tween_method(func(v: float): flash = v; queue_redraw(), 1.0, 0.0, 0.6)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(pos)
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-2)
	if tile == null:
		return
	if texture != null:
		draw_texture_rect(texture, r, false)
	else:
		draw_rect(r, TILE_COLOURS.get(tile.visible_id(), Color.DIM_GRAY))
	var font := get_theme_default_font()
	var fs := 14
	# Name banner, only when there's no card art (the art has the name printed on it).
	if texture == null:
		draw_rect(Rect2(r.position, Vector2(r.size.x, 22)), Color(0, 0, 0, 0.55))
		draw_string(font, r.position + Vector2(6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, fs, Color.WHITE)
	draw_string(font, r.position + Vector2(r.size.x - 30, r.size.y - 6), "%s%d" % [char(65 + pos.x), pos.y + 1],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
	# Tokens.
	var y := r.position.y + 48
	if tile.enemies > 0:
		_token(Vector2(r.position.x + 30, y), Color("b02020"), "E", tile.enemies, enemy_icon)
	if tile.warriors > 0:
		_token(Vector2(r.position.x + 84, y), Color("2060b0"), "W", tile.warriors, warrior_icon)
	# Nobles along the bottom.
	var step := minf(26.0, (r.size.x - 50) / maxf(1, nobles.size() - 1))
	var rad := minf(12.0, step / 2 + 1)
	var x := r.position.x + 16
	for c in nobles:
		draw_circle(Vector2(x, r.end.y - 22), rad, Color.BLACK)
		draw_circle(Vector2(x, r.end.y - 22), rad - 2, NOBLE_COLOURS.get(c, Color.WHITE))
		x += step
	if highlight.a > 0:
		draw_rect(r, highlight, false, 4)
	if flash > 0:
		draw_rect(r, Color(1, 1, 0.6, flash * 0.5))


func _token(c: Vector2, col: Color, letter: String, n: int, icon: Texture2D) -> void:
	var font := get_theme_default_font()
	if icon != null:
		draw_circle(c + Vector2(2, 3), 21, Color(0, 0, 0, 0.4))
		draw_texture_rect(icon, Rect2(c - Vector2(21, 21), Vector2(42, 42)), false)
		# Count badge.
		var b := c + Vector2(16, 14)
		draw_circle(b, 10, Color.BLACK)
		draw_circle(b, 9, col)
		var s := str(n)
		var bw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, b + Vector2(-bw / 2, 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		return
	draw_circle(c, 18, Color.BLACK)
	draw_circle(c, 16, col)
	var text := "%s%d" % [letter, n]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, c + Vector2(-w / 2, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
