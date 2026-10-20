## Tests the Song as a skill and Sarang (GDD §16a "Challenge and mastery",
## §4 Sarang, §7 Investigate step 4, §10 Tulu's three notes).
##
## The lesson screen pauses the tree while it is open, so these tests drive
## it with advance() and never await until it has closed.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SONG_SCREEN := preload("res://scenes/ui/SongScreen.tscn")
const SCRATCH := "user://test_song_journey.json"
## A step in front of Sarang's crate (tools/street_parts/sarang.py).
const BESIDE_SARANG := Vector3(18.8, 0.0, -8.4)
const ALLOWED_PITCHES: Array[float] = [0.0, 2.0, 5.0, 7.0, 9.0, 12.0]
const SCREEN_SIZE := Vector2(1080, 1920)

var _real_path := ""
var _digit := RegEx.new()
var _answered: Array[float] = []


func before_all() -> void:
	_digit.compile("\\d")


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()
	_answered.clear()


func after_each() -> void:
	get_tree().paused = false
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _put(street: Node3D, where: Vector3) -> void:
	street.get_node("%Player").global_position = where
	await wait_frames(8)


func _press(street: Node3D) -> void:
	_button(street).pressed.emit()
	await wait_frames(2)


func _screen() -> Control:
	var screen: Control = add_child_autofree(SONG_SCREEN.instantiate())
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = SCREEN_SIZE
	screen.set_on_finished(func(quality: float) -> void: _answered.append(quality))
	return screen


func _assert_no_digits(screen: Control, when: String) -> void:
	for label: Node in screen.find_children("*", "Label", true, false):
		assert_null(
			_digit.search((label as Label).text),
			"no label shows a digit (%s): '%s'" % [when, (label as Label).text]
		)


## Plays the screen's bar exactly as the data has it, from the keys.
func _play_perfectly(screen: Control) -> void:
	screen.advance(screen.listen_seconds() + 0.05)
	assert_eq(screen.phase(), screen.Phase.PLAY, "after the demonstration it is the player's turn")
	var clock := 0.0
	for note: Dictionary in Song.notes(screen.bar_id()):
		screen.advance(note["time"] - clock)
		clock = note["time"]
		var string: int = Song.string_for(note["pitch"])
		var source: int = screen.SOURCE_KEYS + string
		screen.set_bend(source, note["pitch"] - Song.tuning()[string])
		screen.press_string(string, source)
		screen.advance(note["hold"])
		clock += note["hold"]
		screen.release(source)
	screen.advance(screen.END_AFTER_LAST + 0.1)


# -- the data -------------------------------------------------------------------


func test_the_song_data_loads_and_tulus_three_notes_begin_it() -> void:
	assert_false(Song.data().is_empty(), "data/song.json loads")
	assert_eq(Song.lesson()[0], "bar_one", "the lesson begins with bar one")
	assert_false(Song.bar("bar_two").is_empty(), "there is a second bar")
	var notes := Song.notes("bar_one")
	assert_gte(notes.size(), 3)
	assert_eq(
		[notes[0]["pitch"], notes[1]["pitch"], notes[2]["pitch"]],
		[0.0, 2.0, 5.0],
		"G4 A4 C5: Tulu's three notes are the first three (GDD §10)"
	)
	for bar_id in Song.lesson():
		var last := -1.0
		for note: Dictionary in Song.notes(bar_id):
			assert_true(ALLOWED_PITCHES.has(note["pitch"]), "%s pitch %s" % [bar_id, note["pitch"]])
			assert_gt(note["time"], last, "notes are in time order")
			assert_gt(note["hold"], 0.0)
			last = note["time"]
		assert_false(str(Song.bar(bar_id).get("taught_flag", "")).is_empty(), "a flag to set")
		assert_true(
			Strings.has_id(str(Song.bar(bar_id).get("journey_line_id", ""))), "a journey line"
		)
	assert_eq(Song.tuning().size(), 4, "four strings")
	assert_almost_eq(Song.hz(0.0), 392.0, 0.01, "the root is G4")
	assert_almost_eq(Song.hz(12.0), 784.0, 0.01, "an octave up is twice")
	assert_eq(Song.string_for(2.0), 0, "A4 is a bend up from the G4 string")
	assert_eq(Song.string_for(12.0), 3)
	for quality in [0.0, 0.5, 1.0]:
		assert_true(Strings.has_id(Song.answer(quality)["text_id"]), "every band has a line")
	assert_true(Song.answer(1.0)["top"])
	assert_false(Song.answer(0.0)["top"])


func test_the_scorer_gives_one_for_exact_input_and_less_for_late_or_wrong_pitch() -> void:
	var song := Song.new()
	var exact := Song.notes("bar_one")
	assert_almost_eq(song.score("bar_one", exact), 1.0, 0.001, "exact input is whole")
	assert_almost_eq(song.quality(), 1.0, 0.001, "and remembered")
	var late: Array = []
	var later: Array = []
	var wrong: Array = []
	for note: Dictionary in exact:
		var shifted := note.duplicate()
		shifted["time"] = note["time"] + (0.35 if late.size() > 0 else 0.0)
		late.append(shifted)
		var more := note.duplicate()
		more["time"] = note["time"] + (0.6 if later.size() > 0 else 0.0)
		later.append(more)
		var off := note.duplicate()
		off["pitch"] = note["pitch"] + 2.0
		wrong.append(off)
	var late_quality := song.score("bar_one", late)
	assert_lt(late_quality, 1.0, "late notes score less")
	assert_gt(late_quality, 0.0)
	assert_lt(song.score("bar_one", later), late_quality, "later still scores less again")
	var wrong_quality := song.score("bar_one", wrong)
	assert_lt(wrong_quality, 1.0, "wrong pitches score less")
	assert_gt(wrong_quality, 0.0)
	assert_eq(song.score("bar_one", []), 0.0, "silence is nothing")
	var crowded := exact.duplicate(true)
	crowded.append({"time": 0.35, "pitch": 7.0, "hold": 0.2})
	assert_lt(song.score("bar_one", crowded), 1.0, "an extra note costs a little")
	var shifted_whole: Array = []
	for note: Dictionary in exact:
		var moved := note.duplicate()
		moved["time"] = note["time"] + 3.0
		shifted_whole.append(moved)
	assert_almost_eq(
		song.score("bar_one", shifted_whole), 1.0, 0.001, "when the player begins is not judged"
	)


# -- the screen on its own ------------------------------------------------------


func test_the_screen_plays_the_bar_first_then_hands_over_and_answers_by_band() -> void:
	var screen := _screen()
	screen.set_bar("bar_one")
	watch_signals(screen)
	assert_eq(screen.phase(), screen.Phase.LISTEN)
	_assert_no_digits(screen, "listening")
	screen.advance(0.1)
	assert_eq(screen.phase(), screen.Phase.LISTEN, "the demonstration is still playing")
	screen.advance(screen.listen_seconds())
	assert_eq(screen.phase(), screen.Phase.PLAY)
	assert_eq(screen.line_text(), Strings.t("song.your_turn"))
	_assert_no_digits(screen, "playing")
	# One wrong note, then done: the quiet answer, still an answer.
	screen.press_string(3)
	screen.advance(0.3)
	screen.release(screen.SOURCE_KEYS + 3)
	assert_eq(screen.played_notes().size(), 1)
	screen.finish_turn()
	assert_eq(screen.phase(), screen.Phase.ANSWER)
	assert_lt(screen.quality(), 0.45)
	assert_eq(screen.line_text(), Strings.t("song.answer.quiet"))
	assert_signal_emitted(screen, "finished")
	assert_eq(_answered.size(), 1, "the opener's callback was called once")
	assert_almost_eq(_answered[0], screen.quality(), 0.0001)
	_assert_no_digits(screen, "answering")
	screen.advance(screen.ANSWER_SECONDS + 0.1)
	assert_signal_emitted(screen, "closed")
	assert_eq(screen.phase(), screen.Phase.DONE)


func test_a_whole_run_from_the_keys_is_full() -> void:
	var screen := _screen()
	screen.set_bar("bar_two")
	_play_perfectly(screen)
	assert_eq(screen.phase(), screen.Phase.ANSWER)
	assert_almost_eq(screen.quality(), 1.0, 0.02)
	assert_eq(screen.line_text(), Strings.t("song.answer.full"))
	_assert_no_digits(screen, "full answer")


func test_a_finger_plays_the_pitch_under_it_and_a_slide_bends_it() -> void:
	var screen := _screen()
	screen.set_bar("bar_one")
	for pitch in ALLOWED_PITCHES:
		assert_almost_eq(
			screen.pitch_at(screen.position_for(pitch)), pitch, 0.01, "pitch %s round-trips" % pitch
		)
	assert_lt(screen.position_for(12.0).y, screen.position_for(0.0).y, "higher pitches sit higher")
	assert_gt(screen.position_for(0.0).y, SCREEN_SIZE.y * 0.5, "the strings are in the lower half")
	screen.advance(screen.listen_seconds() + 0.05)
	screen.press_at(0, screen.position_for(5.0))
	screen.advance(0.4)
	screen.release(0)
	var played: Array = screen.played_notes()
	assert_eq(played.size(), 1)
	assert_almost_eq(played[0]["pitch"], 5.0, 0.01, "the C string, pressed, is C")
	assert_almost_eq(played[0]["hold"], 0.4, 0.01)
	screen.press_at(1, screen.position_for(0.0))
	screen.advance(0.2)
	screen.drag_to(1, screen.position_for(2.0))
	screen.advance(0.2)
	screen.release(1)
	played = screen.played_notes()
	assert_eq(played.size(), 2)
	assert_gt(played[1]["pitch"], 0.5, "the slide bent the note up")
	assert_lt(played[1]["pitch"], 2.0)
	screen.press_at(2, Vector2(SCREEN_SIZE.x * 0.5, SCREEN_SIZE.y * 0.2))
	assert_eq(screen.phase(), screen.Phase.ANSWER, "a tap above the strings ends the turn")


# -- Sarang -------------------------------------------------------------------


func test_sarang_sits_in_his_corner_with_the_broken_instrument_and_a_sign() -> void:
	var street := _street()
	var sarang: Node3D = street.get_node("%Sarang")
	assert_lt(sarang.global_position.distance_to(Vector3(20, 0, -8)), 2.0, "near (20, 0, -8)")
	var corner: Node3D = street.get_node("SarangCorner")
	assert_not_null(corner.get_node_or_null("Stool"), "a crate to sit on")
	assert_not_null(corner.get_node_or_null("InstrumentBody"), "his instrument")
	var strings := 0
	for child: Node in corner.get_children():
		if child.name.begins_with("String") and (child as Node3D).visible:
			strings += 1
	assert_eq(strings, 3, "three strings showing and a gap where the fourth was")
	var sign: Label3D = corner.get_node("SarangSign")
	assert_eq(sign.get("text_id"), "sign.sarang_corner")
	await wait_frames(1)
	assert_eq(sign.text, Strings.t("sign.sarang_corner"), "the sign reads from the string table")
	assert_null(_digit.search(sign.text))
	var rig: CharacterRig = sarang.get_node("%Figure")
	assert_eq(rig.idle_animation, "Sitting_Idle", "he sits")


func test_without_tulu_or_the_shrine_he_only_tunes_what_is_left() -> void:
	var street := _street()
	var sarang: Node3D = street.get_node("%Sarang")
	await _put(street, BESIDE_SARANG)
	assert_eq(_button(street).current_verb(), "verb.talk", "next to him the button says Talk")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_greet")
	for card: Dictionary in Content.dialogue.get_line("sarang_greet")["cards"]:
		assert_false(sarang.lessons.has(card["next"]), "no card leads to a lesson yet")
	Content.dialogue.choose(0)
	assert_eq(Content.dialogue.current_line_id(), "sarang_broken", "he tells you what happened")
	Content.dialogue.dismiss()
	assert_null(sarang.song_screen())
	assert_false(get_tree().paused)
	await wait_frames(1)


func test_the_shrine_alone_also_earns_the_lesson() -> void:
	var street := _street()
	GameState.set_flag("saw_shrine")
	await _put(street, BESIDE_SARANG)
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_greet_shrine")
	var line := Content.dialogue.get_line("sarang_greet_shrine")
	assert_eq(line["cards"][0]["text_id"], "card.sarang_greet.teach")
	assert_eq(line["cards"][0]["next"], "sarang_lesson")
	Content.dialogue.choose(1)
	Content.dialogue.dismiss()
	await wait_frames(1)


func test_teach_me_the_first_bar_opens_the_screen_and_a_whole_run_teaches_it() -> void:
	var street := _street()
	var sarang: Node3D = street.get_node("%Sarang")
	watch_signals(sarang)
	GameState.set_flag("heard_tulu")
	await _put(street, BESIDE_SARANG)
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_greet_tulu")
	var line := Content.dialogue.get_line("sarang_greet_tulu")
	assert_eq(line["cards"][0]["text_id"], "card.sarang_greet.teach")
	Content.dialogue.choose(0)
	# From here the tree is paused under the lesson: no awaits until it closes.
	var screen: Control = sarang.song_screen()
	assert_not_null(screen, "the card opened the lesson")
	assert_true(get_tree().paused, "the street waits")
	assert_eq(screen.bar_id(), "bar_one")
	assert_eq(screen.phase(), screen.Phase.LISTEN)
	assert_eq(screen.line_text(), Strings.t("line.sarang_lesson"), "his words head the lesson")
	assert_eq(screen.get_node("%Speaker").text, Strings.t("speaker.sarang"))
	_assert_no_digits(screen, "listening")
	assert_false(GameState.has_flag("sarang_taught_bar"), "not taught until played")
	_play_perfectly(screen)
	_assert_no_digits(screen, "answering")
	assert_eq(screen.phase(), screen.Phase.ANSWER)
	assert_almost_eq(screen.quality(), 1.0, 0.02)
	assert_eq(screen.line_text(), Strings.t("song.answer.full"), "the full line")
	assert_true(GameState.has_flag("sarang_taught_bar"), "the bar's flag, from the song data")
	assert_true(GameState.journey_lines.has("journey.sarang.first_bar"))
	assert_signal_emitted(sarang, "lesson_finished")
	screen.advance(screen.listen_seconds() + screen.ANSWER_SECONDS + 1.0)
	assert_null(sarang.song_screen(), "the screen closed")
	assert_false(get_tree().paused, "and the street goes on")
	await wait_frames(2)
	assert_false(street.cards().visible, "the lesson line was dismissed with it")
	assert_false(Content.dialogue.is_running())
	# Taught, he offers it again and the next bar.
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_after")
	Content.dialogue.choose(1)
	screen = sarang.song_screen()
	assert_not_null(screen)
	assert_eq(screen.bar_id(), "bar_two", "the second bar from the data")
	screen.advance(screen.listen_seconds() + 0.05)
	screen.finish_turn()
	assert_true(GameState.has_flag("sarang_taught_bar_two"), "any quality teaches")
	assert_eq(screen.line_text(), Strings.t("song.answer.quiet"))
	screen.advance(screen.ANSWER_SECONDS + 0.1)
	assert_null(sarang.song_screen())
	assert_false(get_tree().paused)
	await wait_frames(1)


func test_the_string_from_nandas_flat_is_handed_over_once_and_strings_the_gap() -> void:
	var street := _street()
	var mended: Node3D = street.get_node("SarangCorner/StringMended")
	assert_false(mended.visible, "the gap is empty")
	await _put(street, BESIDE_SARANG)
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_greet", "nothing to hand over yet")
	Content.dialogue.choose(1)
	GameState.set_flag("has_sarang_string")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_string", "he sees the string")
	Content.dialogue.choose(1)  # not yet
	assert_false(GameState.has_flag("sarang_string_given"))
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "sarang_string", "still offered until given")
	Content.dialogue.choose(0)  # here, it's yours
	assert_true(GameState.has_flag("sarang_string_given"), "the card sets the flag")
	assert_eq(Content.dialogue.current_line_id(), "sarang_thanks", "and his thanks follow")
	assert_true(GameState.has_flag("sarang_thanked"), "the thanks mark themselves said")
	assert_true(mended.visible, "the instrument is strung")
	Content.dialogue.choose(0)
	assert_eq(Content.dialogue.current_line_id(), "sarang_thanks_play")
	Content.dialogue.dismiss()
	await _press(street)
	assert_eq(
		Content.dialogue.current_line_id(),
		"sarang_greet",
		"neither the hand-over nor the thanks come twice"
	)
	Content.dialogue.choose(1)


func test_a_lesson_closed_under_the_pause_menu_leaves_the_world_paused() -> void:
	var street := _street()
	var sarang: Node3D = street.get_node("%Sarang")
	street.pause()
	var screen: Control = sarang.open_lesson("bar_one")
	assert_true(get_tree().paused)
	screen._close()
	await wait_frames(1)
	assert_true(get_tree().paused, "the pause menu still holds the world")
	assert_true(street.is_paused())
	street.resume()
	assert_false(get_tree().paused)


func test_the_cards_ignore_the_number_keys_under_the_pause_menu() -> void:
	var street := _street()
	assert_true(Content.dialogue.start("sarang_greet"))
	street.pause()
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	street.cards()._unhandled_input(key)
	assert_eq(
		Content.dialogue.current_line_id(), "sarang_greet", "the key was the menu's, not a card"
	)
	street.resume()
	Content.dialogue.dismiss()
