## The tester's panel: every flag, every event, every quest, every line.
##
## CLAUDE_CODE_BRIEF.md §0 item 6: "A debug panel (hidden behind a 5-tap on the
## title) listing all flags and allowing a tester to set them." GDD §12: the
## flag model keeps "the whole game inspectable with a debug panel".
##
## Wording rule (CLAUDE_CODE_BRIEF.md §0): no score, meter, points or correct
## answer anywhere, this panel included. Quests say what they are waiting on,
## never how far along they are.
extends Control

signal closed

const ROW_HEIGHT := 64.0

@onready var _title: Label = %Title
@onready var _close: Button = %CloseButton
@onready var _sections: VBoxContainer = %Sections
@onready var _cards: Control = %Cards


func _ready() -> void:
	_title.text = Strings.t("debug.title")
	_close.text = Strings.t("debug.close")
	_close.pressed.connect(func() -> void: closed.emit())
	_cards.bind(Content.dialogue)
	GameState.flag_changed.connect(func(_f: String, _s: bool) -> void: _refresh_later())
	GameState.event_fired.connect(func(_e: String) -> void: _refresh_later())
	GameState.journey_line_added.connect(func(_l: String) -> void: _refresh_later())
	GameState.wiped.connect(_refresh_later)
	refresh()
	_close.grab_focus()


func _exit_tree() -> void:
	_cards.unbind()


## Rebuilds every section from data. Cheap at this scale, and simpler than
## keeping widgets in sync one by one.
func refresh() -> void:
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()

	_heading("debug.flags")
	var flags := Content.known_flags()
	if flags.is_empty():
		_note("debug.empty")
	for flag in flags:
		_sections.add_child(_flag_row(flag))

	_heading("debug.events")
	var events := Content.known_events()
	if events.is_empty():
		_note("debug.empty")
	for event in events:
		_sections.add_child(_event_row(event))

	_heading("debug.quests")
	for id in Content.quest_ids():
		_sections.add_child(_quest_row(Content.quest(id)))

	_heading("debug.lines")
	for line_id in Content.dialogue.line_ids():
		_sections.add_child(_line_row(line_id))

	_heading("debug.journey")
	if GameState.journey_lines.is_empty():
		_note("debug.empty")
	for line_id in GameState.journey_lines:
		_sections.add_child(_plain(Strings.t(line_id)))

	var wipe := Button.new()
	wipe.text = Strings.t("debug.wipe")
	wipe.pressed.connect(GameState.wipe)
	_sections.add_child(wipe)


func flag_toggle(flag: String) -> CheckButton:
	return _sections.find_child("flag_" + flag, true, false) as CheckButton


func _refresh_later() -> void:
	# Deferred so a toggle finishes its own press before its widget is rebuilt.
	refresh.call_deferred()


func _flag_row(flag: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = "flag_" + flag
	toggle.text = flag
	toggle.button_pressed = GameState.has_flag(flag)
	toggle.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	toggle.toggled.connect(
		func(on: bool) -> void:
			if on:
				GameState.set_flag(flag)
			else:
				GameState.clear_flag(flag)
	)
	return toggle


func _event_row(event: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = event
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var fire := Button.new()
	fire.name = "event_" + event
	fire.text = Strings.t("debug.fire")
	fire.disabled = GameState.has_event(event)
	fire.pressed.connect(func() -> void: GameState.fire_event(event))
	row.add_child(fire)
	return row


func _quest_row(quest: Quest) -> Label:
	var state: String
	match quest.status():
		Quest.Status.INACTIVE:
			state = Strings.t("debug.quest_inactive")
		Quest.Status.ENDED:
			state = Strings.t("debug.quest_ended") % quest.ended_branch()
		_:
			var waiting := quest.waiting_on()
			state = Strings.t("debug.quest_waiting") % waiting if waiting != "" else "—"
	return _plain("%s — %s" % [quest.id, state])


func _line_row(line_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = line_id
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var play := Button.new()
	play.name = "line_" + line_id
	play.text = Strings.t("debug.play")
	play.disabled = not Content.dialogue.is_available(line_id, GameState.flags)
	play.pressed.connect(func() -> void: Content.dialogue.start(line_id))
	row.add_child(play)
	return row


func _heading(text_id: String) -> void:
	var label := Label.new()
	label.text = Strings.t(text_id)
	label.add_theme_font_size_override("font_size", 24)
	_sections.add_child(label)


func _note(text_id: String) -> void:
	_sections.add_child(_plain(Strings.t(text_id)))


func _plain(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Escape, or a pad's B, closes the panel as the Close button does.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
