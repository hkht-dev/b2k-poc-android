## The Song, played: four strings across the lower half of the screen.
##
## GDD §16a "Challenge and mastery": "a touch rhythm-and-pitch system (hold,
## slide, release along a string) ... Accuracy is shown in the world, never
## as a number." GDD §7 Investigate step 4: Sarang teaches the first bar.
## GDD §11: nothing on screen counts, scores or times anything the player
## can see. The bar plays once — a guide dot travels and the string it is
## played from glows — then the player plays: press a string for its pitch,
## slide up or down to bend it, let go to end the note. Keys one to four and
## Up/Down, a gamepad's face buttons or d-pad and left stick do the same,
## read as raw events so project.godot gains no actions. When the turn ends
## the opener's callback gets the quality (0–1) and the screen says one of
## Sarang's lines by band (data/song.json), then closes. The only text on it
## is his.
##
## PLACEHOLDER look: lines and dots; the painted Veena of GDD §10 replaces
## them. PLACEHOLDER sound: Song's sine-and-triangle plucks.
extends Control

## The turn is over: the quality of what was played, 0–1. Never shown.
signal finished(quality: float)
## The answer has been said and the screen is going; the opener lets go.
signal closed

enum Phase { LISTEN, PLAY, ANSWER, DONE }

const CONTROLS_HINT := preload("res://scripts/ui/controls_hint.gd")
## After the bar's last note, how long the demonstration lingers.
const LISTEN_TAIL := 0.8
## The turn ends this long after the last release once as many notes as the
## bar has were played ...
const END_AFTER_LAST := 0.7
## ... or once the player has had twice the bar's length and this much more.
const GRACE_FACTOR := 2.0
const GRACE_TAIL := 2.0
const ANSWER_SECONDS := 2.8
## advance() steps the clock in slices no longer than this.
const MAX_STEP := 1.0 / 30.0
## Voice ids: touch pointers are their index; the mouse, keys and pads are
## offset so one hand on each works at once; the demonstration is far above.
const SOURCE_MOUSE := 90
const SOURCE_KEYS := 100
const SOURCE_PAD := 200
const DEMO_VOICE := 1000
## A held Up/Down, or the left stick, bends by this many semitones.
const KEY_BEND := 2.0
const STICK_DEADZONE := 0.25
const STRING_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
const BEND_KEYS := {KEY_UP: 1.0, KEY_DOWN: -1.0}
## Face buttons bottom, left, right, top, and the d-pad the same way: the
## strings from low to high.
const PAD_FACE: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y]
const PAD_DPAD: Array[JoyButton] = [
	JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP
]
const DONE_PAD: Array[JoyButton] = [JOY_BUTTON_BACK, JOY_BUTTON_START]
## Layout as fractions of the screen: the strings across the lower half,
## the highest at the top; a tap above them ends the turn.
const STRING_TOP := 0.6
const STRING_BOTTOM := 0.9
const MARGIN_X := 0.07
const DONE_ABOVE := 0.5
## How far past the outer strings a slide may bend, in semitones.
const BEND_LIMIT := 2.5
## GDD §10 Hollow Vale: cream, dust, warm amber. No peacock blue, no magenta.
const DIM := Color(0.09, 0.07, 0.05, 0.84)
const STRING_COLOUR := Color(0.93, 0.87, 0.74, 0.9)
const GLOW_COLOUR := Color(1.0, 0.78, 0.46, 0.3)
const DOT_COLOUR := Color(1.0, 0.95, 0.85, 1.0)
const GHOST_COLOUR := Color(1.0, 0.95, 0.85, 0.4)
const PLUCK_COLOUR := Color(1.0, 0.86, 0.6, 0.55)

var _song := Song.new()
var _bar_id := ""
var _notes: Array = []
var _bar_length := 0.0
var _phase := Phase.LISTEN
var _clock := 0.0
var _demo_start := -1.0
var _demo_next := 0
var _demo_ends: Dictionary = {}
var _first_press := -1.0
var _last_release := -1.0
## source -> {pitch, string, x, time, pitch_sum, held, record}
var _active: Dictionary = {}
var _played: Array = []
var _bend: Dictionary = {}
var _on_finished := Callable()
var _quality := 0.0
var _answer_left := 0.0
var _speaker_id := ""
var _header_id := ""
var _mouse_is_touch := true
var _audio: AudioStreamPlayer = null

@onready var _speaker: Label = %Speaker
@onready var _line: Label = %Line
@onready var _hint: Label = %Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mouse_is_touch = bool(
		ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)
	)
	if _notes.is_empty():
		var first := Song.lesson()
		set_bar(_bar_id if not _bar_id.is_empty() else (first[0] if not first.is_empty() else ""))
	_audio = AudioStreamPlayer.new()
	_audio.stream = _song.make_stream()
	add_child(_audio)
	_audio.play()
	_song.bind(_audio.get_stream_playback())
	_refresh_header()
	_start_demo()


func _process(delta: float) -> void:
	_step(delta)
	_song.render()
	queue_redraw()


# -- what the opener sets -----------------------------------------------------


## Which bar of data/song.json this lesson is.
func set_bar(bar_id: String) -> void:
	_bar_id = bar_id
	_notes = Song.notes(bar_id)
	_bar_length = Song.bar_length(bar_id)


## The teacher's words over the demonstration: a speaker id and a string id,
## as the dialogue line that opened the screen carries them.
func set_header(speaker: String, text_id: String) -> void:
	_speaker_id = speaker
	_header_id = text_id
	if is_node_ready():
		_refresh_header()


## Called once with the quality when the turn ends; the world answers there.
func set_on_finished(callable: Callable) -> void:
	_on_finished = callable


func bar_id() -> String:
	return _bar_id


func phase() -> Phase:
	return _phase


func quality() -> float:
	return _quality


func line_text() -> String:
	return _line.text


func played_notes() -> Array:
	return _played.duplicate(true)


## How long the demonstration takes before it is the player's turn.
func listen_seconds() -> float:
	return _bar_length + LISTEN_TAIL


## Moves the lesson on by [param seconds] without waiting for frames: the
## tree is paused under this screen, and tests drive it this way.
func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and _phase != Phase.DONE:
		var step := minf(left, MAX_STEP)
		_step(step)
		left -= step
	queue_redraw()


# -- playing ------------------------------------------------------------------


## Plays string [param index] (lowest first) from a key or pad; [param source]
## names the finger so a release finds it again.
func press_string(index: int, source: int = -1) -> void:
	var strings := Song.tuning()
	var which := clampi(index, 0, strings.size() - 1)
	var id := source if source >= 0 else SOURCE_KEYS + which
	_start_voice(id, strings[which] + float(_bend.get(id, 0.0)), which, size.x * 0.5)


## Bends whatever [param source] is holding, and what it presses next, by
## [param semitones] from the string's open pitch.
func set_bend(source: int, semitones: float) -> void:
	_bend[source] = semitones
	if _active.has(source):
		_set_voice_pitch(source, Song.tuning()[_active[source]["string"]] + semitones)


func release(source: int) -> void:
	_end_voice(source)


## A finger or the mouse lands at [param position]: on the strings it plays
## the pitch there; above them, in the player's turn, it means "done".
func press_at(pointer: int, position: Vector2) -> void:
	if position.y < size.y * DONE_ABOVE:
		finish_turn()
		return
	var pitch := pitch_at(position)
	_start_voice(pointer, pitch, Song.string_for(pitch), position.x)


func drag_to(pointer: int, position: Vector2) -> void:
	if _active.has(pointer):
		_active[pointer]["x"] = position.x
		_set_voice_pitch(pointer, pitch_at(position))


## Ends the player's turn with what has been played so far.
func finish_turn() -> void:
	if _phase == Phase.PLAY:
		_end_turn()


## The pitch under a point: on a string its open pitch, between strings a
## bend toward the next, a little past the outer strings a bend beyond.
func pitch_at(position: Vector2) -> float:
	var strings := Song.tuning()
	var top := strings.size() - 1
	if top < 1 or size.y <= 0.0:
		return strings[0]
	var segment := clampi(_segment_at(position.y), 0, top - 1)
	var y_low := _string_y(segment)
	var y_high := _string_y(segment + 1)
	var along := (y_low - position.y) / (y_low - y_high)
	var pitch := lerpf(strings[segment], strings[segment + 1], along)
	return clampf(pitch, strings[0] - BEND_LIMIT, strings[top] + BEND_LIMIT)


## Where a pitch sits: the point a finger would press for it.
func position_for(pitch: float, x_fraction: float = 0.5) -> Vector2:
	return Vector2(lerpf(_x0(), _x1(), x_fraction), _pitch_y(pitch))


# -- the lesson's clock -------------------------------------------------------


func _step(delta: float) -> void:
	_clock += delta
	for source in _active:
		var voice: Dictionary = _active[source]
		voice["held"] += delta
		voice["pitch_sum"] += voice["pitch"] * delta
	_tick_demo()
	match _phase:
		Phase.LISTEN:
			if _clock - _demo_start >= listen_seconds():
				_begin_turn()
		Phase.PLAY:
			_check_turn_over()
		Phase.ANSWER:
			_answer_left -= delta
			if _answer_left <= 0.0:
				_close()


func _start_demo() -> void:
	_demo_start = _clock
	_demo_next = 0
	_demo_ends.clear()


## Sounds the bar's notes from the data as the demonstration's clock passes
## them.
func _tick_demo() -> void:
	if _demo_start < 0.0:
		return
	var t := _clock - _demo_start
	while _demo_next < _notes.size() and _notes[_demo_next]["time"] <= t:
		var note: Dictionary = _notes[_demo_next]
		_song.note_on(DEMO_VOICE + _demo_next, note["pitch"])
		_demo_ends[_demo_next] = note["time"] + note["hold"]
		_demo_next += 1
	for index in _demo_ends.keys():
		if _demo_ends[index] <= t:
			_song.note_off(DEMO_VOICE + index)
			_demo_ends.erase(index)


func _begin_turn() -> void:
	_phase = Phase.PLAY
	_demo_start = -1.0
	_song.all_off()
	_first_press = -1.0
	_played.clear()
	_refresh_header()


func _check_turn_over() -> void:
	if _first_press < 0.0:
		return
	var complete := _active.is_empty() and _played.size() >= _notes.size()
	if complete and _clock - _last_release >= END_AFTER_LAST:
		_end_turn()
	elif _clock - _first_press >= _bar_length * GRACE_FACTOR + GRACE_TAIL:
		_end_turn()


func _end_turn() -> void:
	for source in _active.keys():
		_end_voice(source)
	_quality = _song.score(_bar_id, _played)
	_phase = Phase.ANSWER
	var band := Song.answer(_quality)
	_answer_left = ANSWER_SECONDS
	if band["top"]:
		# The fullest answer the screen has: he plays it back with you.
		_start_demo()
		_answer_left = maxf(ANSWER_SECONDS, _bar_length + 1.2)
	_refresh_header(band["text_id"])
	finished.emit(_quality)
	if _on_finished.is_valid():
		_on_finished.call(_quality)


func _close() -> void:
	_phase = Phase.DONE
	_song.all_off()
	closed.emit()
	queue_free()


# -- voices -------------------------------------------------------------------


func _start_voice(source: int, pitch: float, string: int, x: float) -> void:
	if _active.has(source):
		_end_voice(source)
	var record := _phase == Phase.PLAY
	if record and _first_press < 0.0:
		_first_press = _clock
	_active[source] = {
		"pitch": pitch,
		"string": string,
		"x": x,
		"time": _clock - _first_press if record else 0.0,
		"pitch_sum": 0.0,
		"held": 0.0,
		"record": record,
	}
	_song.note_on(source, pitch)


func _set_voice_pitch(source: int, pitch: float) -> void:
	if not _active.has(source):
		return
	_active[source]["pitch"] = pitch
	_song.set_pitch(source, pitch)


## Ends a note. One started in the player's turn is recorded with the pitch
## it held on average, so a slide counts for where it went.
func _end_voice(source: int) -> void:
	if not _active.has(source):
		return
	var voice: Dictionary = _active[source]
	_active.erase(source)
	_song.note_off(source)
	if not voice["record"]:
		return
	var held: float = voice["held"]
	var mean: float = voice["pitch_sum"] / held if held > 0.0 else voice["pitch"]
	_played.append({"time": voice["time"], "pitch": mean, "hold": held})
	_last_release = _clock


func _voice_on(string: int) -> Dictionary:
	for source in _active:
		if _active[source]["string"] == string:
			return _active[source]
	return {}


# -- input --------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			press_at(event.index, event.position)
		else:
			release(event.index)
		accept_event()
		return
	if event is InputEventScreenDrag:
		drag_to(event.index, event.position)
		accept_event()
		return
	if _mouse_is_touch:
		# The project turns mouse clicks into touches as well; one note each.
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_at(SOURCE_MOUSE, event.position)
		else:
			release(SOURCE_MOUSE)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_to(SOURCE_MOUSE, event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	if _phase == Phase.DONE:
		return
	var handled := false
	if event is InputEventKey and not event.echo:
		handled = _on_key(event as InputEventKey)
	elif event is InputEventJoypadButton:
		handled = _on_pad_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		var motion := event as InputEventJoypadMotion
		var bend := (
			0.0 if absf(motion.axis_value) < STICK_DEADZONE else -motion.axis_value * KEY_BEND
		)
		for index in Song.tuning().size():
			set_bend(SOURCE_PAD + index, bend)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _on_key(event: InputEventKey) -> bool:
	var index := STRING_KEYS.find(event.keycode)
	if index < 0:
		index = STRING_KEYS.find(event.physical_keycode)
	if index >= 0:
		if event.pressed:
			press_string(index, SOURCE_KEYS + index)
		else:
			release(SOURCE_KEYS + index)
		return true
	if BEND_KEYS.has(event.keycode):
		var bend: float = BEND_KEYS[event.keycode] * KEY_BEND if event.pressed else 0.0
		for string in Song.tuning().size():
			set_bend(SOURCE_KEYS + string, bend)
		return true
	if event.keycode == KEY_ESCAPE and event.pressed:
		finish_turn()
		return true
	return false


func _on_pad_button(event: InputEventJoypadButton) -> bool:
	var index := PAD_FACE.find(event.button_index)
	if index < 0:
		index = PAD_DPAD.find(event.button_index)
	if index >= 0:
		if event.pressed:
			press_string(index, SOURCE_PAD + index)
		else:
			release(SOURCE_PAD + index)
		return true
	if DONE_PAD.has(event.button_index) and event.pressed:
		finish_turn()
		return true
	return false


# -- the picture --------------------------------------------------------------


func _refresh_header(answer_id: String = "") -> void:
	_speaker.text = Strings.t("speaker." + _speaker_id) if not _speaker_id.is_empty() else ""
	_speaker.visible = not _speaker.text.is_empty()
	match _phase:
		Phase.LISTEN:
			_line.text = Strings.t(_header_id) if not _header_id.is_empty() else ""
			_hint.text = Strings.t("song.hint.watch")
		Phase.PLAY:
			_line.text = Strings.t("song.your_turn")
			_hint.text = Strings.t("song.hint.play." + CONTROLS_HINT.detect_scheme())
		_:
			_line.text = Strings.t(answer_id) if not answer_id.is_empty() else ""
			_hint.text = ""
	_line.visible = not _line.text.is_empty()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var strings := Song.tuning()
	var guide := _guide()
	var glowing := Song.string_for(guide["pitch"]) if not guide.is_empty() else -1
	for index in strings.size():
		var y := _string_y(index)
		var a := Vector2(_x0(), y)
		var b := Vector2(_x1(), y)
		if index == glowing:
			draw_line(a, b, GLOW_COLOUR, 22.0)
		var voice := _voice_on(index)
		if voice.is_empty():
			draw_line(a, b, STRING_COLOUR, 2.0, true)
		else:
			var at := Vector2(
				clampf(voice["x"], _x0() + 1.0, _x1() - 1.0), _pitch_y(voice["pitch"])
			)
			draw_polyline(PackedVector2Array([a, at, b]), STRING_COLOUR, 3.0, true)
			draw_circle(at, 18.0, PLUCK_COLOUR)
		draw_circle(a, 5.0, STRING_COLOUR)
		draw_circle(b, 5.0, STRING_COLOUR)
	if not guide.is_empty():
		var dot := Vector2(guide["x"], _pitch_y(guide["pitch"]))
		draw_circle(dot, 16.0, GLOW_COLOUR)
		draw_circle(dot, 9.0, GHOST_COLOUR if guide["ghost"] else DOT_COLOUR)


## The dot that shows where the bar is: during the demonstration and, as a
## ghost, through the player's turn once it has begun.
func _guide() -> Dictionary:
	var t := -1.0
	var ghost := false
	if _demo_start >= 0.0:
		t = _clock - _demo_start
	elif _phase == Phase.PLAY and _first_press >= 0.0:
		t = _clock - _first_press
		ghost = true
	if t < 0.0 or t > _bar_length or _bar_length <= 0.0 or _notes.is_empty():
		return {}
	return {"pitch": _target_pitch_at(t), "x": lerpf(_x0(), _x1(), t / _bar_length), "ghost": ghost}


## The pitch the bar wants at [param t]: the note sounding, or the next one.
func _target_pitch_at(t: float) -> float:
	for note in _notes:
		if t < note["time"] + note["hold"]:
			return float(note["pitch"])
	return float(_notes[-1]["pitch"])


func _string_y(index: int) -> float:
	var count := Song.tuning().size()
	var along := float(index) / float(count - 1) if count > 1 else 0.0
	return size.y * lerpf(STRING_BOTTOM, STRING_TOP, along)


## The segment between strings a height falls in (the lower string's index);
## -1 below the lowest, the top index above the highest.
func _segment_at(y: float) -> int:
	var segment := -1
	for index in Song.tuning().size():
		if y <= _string_y(index):
			segment = index
	return segment


func _pitch_y(pitch: float) -> float:
	var strings := Song.tuning()
	var top := strings.size() - 1
	if top < 1:
		return _string_y(0)
	var segment := 0
	for index in top:
		if pitch >= strings[index]:
			segment = index
	var span := strings[segment + 1] - strings[segment]
	var along := (pitch - strings[segment]) / span if span > 0.0 else 0.0
	var y := lerpf(_string_y(segment), _string_y(segment + 1), along)
	return clampf(y, size.y * (STRING_TOP - 0.08), size.y * (STRING_BOTTOM + 0.07))


func _x0() -> float:
	return size.x * MARGIN_X


func _x1() -> float:
	return size.x * (1.0 - MARGIN_X)
