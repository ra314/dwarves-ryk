class_name IconGlyph
extends Control
## Small hand-drawn icons for things the game art has no image for.
## kind: "resource" (a gold ore crystal) or "moves" (a boot print).

var kind: String


func _init(icon_kind: String, side: float = 22.0) -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	match kind:
		"resource":
			_crystal(c, s * 0.46)
		"moves":
			_boot_print(c, s * 0.5)


func _crystal(c: Vector2, r: float) -> void:
	var gold := Color("e8b440")
	var pts := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.35), c + Vector2(r * 0.6, r * 0.8),
		c + Vector2(-r * 0.6, r * 0.8), c + Vector2(-r * 0.8, -r * 0.35)])
	draw_colored_polygon(pts, gold.darkened(0.3))
	# Lit facets.
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c + Vector2(0, r * 0.1), pts[4]]), gold.lightened(0.25))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.1), pts[1], pts[2]]), gold)
	var edge := Color("4a3208")
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, edge, 1.5, true)
	for p in [pts[1], pts[4], pts[2], pts[3]]:
		draw_line(c + Vector2(0, r * 0.1), p, edge, 1.0, true)
	draw_circle(c + Vector2(-r * 0.25, -r * 0.45), r * 0.1, Color(1, 1, 1, 0.8))


func _boot_print(c: Vector2, r: float) -> void:
	var col := Color("d9c7a3")
	# Sole and heel of a dwarf boot, tilted like a step.
	draw_set_transform(c, 0.35, Vector2.ONE)
	_ellipse(Vector2(0, -r * 0.3), Vector2(r * 0.42, r * 0.55), col)
	_ellipse(Vector2(0, r * 0.62), Vector2(r * 0.3, r * 0.3), col)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _ellipse(at: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
