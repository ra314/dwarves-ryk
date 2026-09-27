class_name StatChip
extends HBoxContainer
## An icon followed by a value, e.g. [crystal] 14. The icon is a texture, a
## drawn IconGlyph kind, or any Control.


static func make(icon, text: String, tip: String, icon_side: float = 22.0) -> StatChip:
	var chip := StatChip.new()
	chip.add_theme_constant_override("separation", 3)
	chip.tooltip_text = tip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var node: Control
	if icon is Texture2D:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(icon_side, icon_side)
		node = tr
	elif icon is String:
		node = IconGlyph.new(icon, icon_side)
	else:
		node = icon
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(node)
	if text != "":
		var l := Label.new()
		l.text = text
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(l)
	return chip
