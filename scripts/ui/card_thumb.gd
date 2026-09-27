class_name CardThumb
extends TextureRect
## A small card image that shows the full card when hovered.

const BIG := Vector2(300, 419)

var border: Color = Color(0, 0, 0, 0)
var caption: String = ""


static func make(tex: Texture2D, width: float, tip: String) -> CardThumb:
	var t := CardThumb.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var aspect := 1.4 if tex == null else float(tex.get_height()) / tex.get_width()
	t.custom_minimum_size = Vector2(width, width * aspect)
	t.tooltip_text = tip  # non-empty so the custom tooltip shows
	return t


func _make_custom_tooltip(for_text: String) -> Object:
	return HoverCard.build(texture, BIG, for_text)


func _draw() -> void:
	if border.a > 0:
		draw_rect(Rect2(Vector2.ZERO, size).grow(1), border, false, 3)
	if caption != "":
		var font := get_theme_default_font()
		var fs := 12
		var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_rect(Rect2(Vector2(0, size.y - 18), Vector2(size.x, 18)), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2((size.x - w) / 2, size.y - 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, border if border.a > 0 else Color.WHITE)
