class_name HoverCard
extends RefCounted
## Content for hover tooltips: a card image at readable size with text under it,
## on an opaque panel sized to fit both.


static func build(texture: Texture2D, image_size: Vector2, text: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e1b18")
	style.border_color = Color("6b5a3e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	if texture != null:
		var big := TextureRect.new()
		big.texture = texture
		big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		big.custom_minimum_size = image_size
		box.add_child(big)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("f2ead8"))
	box.add_child(l)
	# The tooltip window sizes itself from this, before the label is in the tree.
	panel.custom_minimum_size = panel.get_combined_minimum_size()
	return panel
