## The one contextual button, lower right.
##
## GDD §6 "Interaction": it appears only when something usable is near and is
## labelled with that thing's verb — Talk, Pick up, Place, Look, Listen. It is
## the only button in the game.
##
## P1 ships the mechanism with no verbs wired to it: the climb out of the
## fountain is automatic on approach (GDD §6, "no jump button"), so nothing in
## the P1 street is usable yet and the button correctly never appears. Its first
## real verb is *Listen* in P3. See docs/DECISIONS.md.
extends Button

## Emitted on a press, carrying the string id of the verb that was showing, so
## the caller never has to read the label text back.
signal verb_used(verb_id: String)
## Emitted when the button is held with no verb showing: the Call (GDD §6).
signal hummed

const FADE_SPEED := 8.0
## How long a press with nothing near must last to become a hum.
const HUM_HOLD := 0.5
## With nothing near, the button stays as a faint mark so a hold has somewhere
## to land (GDD §6 "Call": "hold the interact button with nothing nearby").
const IDLE_ALPHA := 0.35

var _verb_id := ""
var _shown := 0.0
var _held := 0.0
var _holding := false
var _hum_fired := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = Strings.t("verb.idle")
	modulate.a = IDLE_ALPHA
	pressed.connect(_on_pressed)
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _process(delta: float) -> void:
	var wanted := 1.0 if _verb_id != "" else IDLE_ALPHA
	_shown = move_toward(_shown, wanted, FADE_SPEED * delta)
	modulate.a = _shown
	if _holding and _verb_id == "" and not _hum_fired:
		_held += delta
		if _held >= HUM_HOLD:
			_hum_fired = true
			hummed.emit()


func _on_down() -> void:
	_holding = true
	_held = 0.0
	_hum_fired = false


func _on_up() -> void:
	_holding = false


## Simulates a held press for tests and the desktop E key.
func hold_for(seconds: float) -> void:
	_on_down()
	_held = seconds
	_process(0.0)
	_on_up()


## Shows the button labelled with [param verb_id], a string id resolved through
## the string table — never a literal (CLAUDE_CODE_BRIEF.md §10).
func show_verb(verb_id: String) -> void:
	if verb_id == _verb_id:
		return
	_verb_id = verb_id
	text = Strings.t(verb_id if verb_id != "" else "verb.idle")


func clear_verb() -> void:
	show_verb("")


func current_verb() -> String:
	return _verb_id


func _on_pressed() -> void:
	if _verb_id != "":
		verb_used.emit(_verb_id)
