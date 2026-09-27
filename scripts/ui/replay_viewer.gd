class_name ReplayViewer
extends VBoxContainer
## Controls for watching a recorded game: first/back/play/forward/last, a scrub
## slider, and what the current step was. The main screen draws each frame.

const PLAY_DELAY := 0.8  # seconds between steps while playing

var main  # the main screen (untyped: main.gd has no class_name)
var frames: Array = []
var index: int = 0
var playing := false

var _label: Label
var _slider: HSlider
var _play: Button
var _busy := false


func _init(screen) -> void:
	main = screen
	var row := HBoxContainer.new()
	add_child(row)
	for b in [["⏮", func(): go_to(0)], ["◀", func(): go_to(index - 1)], ["▶", _toggle_play],
			["▶|", func(): go_to(index + 1, true)], ["⏭", func(): go_to(frames.size() - 1)]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(38, 0)
		btn.pressed.connect(b[1])
		row.add_child(btn)
		if b[0] == "▶":
			_play = btn
	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.step = 1
	# The default track is nearly invisible on the dark background.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("4a4238")
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(3)
	_slider.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate()
	filled.bg_color = Color("c9a45c")
	_slider.add_theme_stylebox_override("grabber_area", filled)
	_slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	_slider.value_changed.connect(func(v): if int(v) != index: go_to(int(v)))
	row.add_child(_slider)
	var exit := Button.new()
	exit.text = "Exit replay"
	exit.pressed.connect(func(): playing = false; main.exit_replay())
	row.add_child(exit)
	_label = Label.new()
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_label)


func open(replay_frames: Array) -> void:
	frames = replay_frames
	playing = false
	_play.text = "▶"
	_slider.max_value = frames.size() - 1
	index = -1
	go_to(0)


## Shows frame i. Stepping one forward replays that step's enemy turn, if any.
func go_to(i: int, animate: bool = false) -> void:
	i = clampi(i, 0, frames.size() - 1)
	if _busy or i == index:
		return
	_busy = true
	var step_forward := i == index + 1
	if animate and step_forward:
		await main.show_replay_step(frames[index], frames[i])
	index = i
	main.show_replay_frame(frames, i, step_forward)
	_slider.set_value_no_signal(i)
	var f: Dictionary = frames[i]
	_label.text = "Step %d of %d · Round %d · %s" % [i, frames.size() - 1, f["state"].round, f["label"]]
	_busy = false


func _toggle_play() -> void:
	playing = not playing
	_play.text = "⏸" if playing else "▶"
	if playing and index >= frames.size() - 1:
		go_to(0)
	while playing and index < frames.size() - 1:
		await go_to(index + 1, true)
		await main.get_tree().create_timer(PLAY_DELAY).timeout
	playing = false
	_play.text = "▶"
