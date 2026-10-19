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

const FADE_SPEED := 8.0

var _verb_id := ""
var _shown := 0.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)


func _process(delta: float) -> void:
	var wanted := 1.0 if _verb_id != "" else 0.0
	_shown = move_toward(_shown, wanted, FADE_SPEED * delta)
	modulate.a = _shown
	visible = _shown > 0.01


## Shows the button labelled with [param verb_id], a string id resolved through
## the string table — never a literal (CLAUDE_CODE_BRIEF.md §10).
func show_verb(verb_id: String) -> void:
	if verb_id == _verb_id:
		return
	_verb_id = verb_id
	if verb_id != "":
		text = Strings.t(verb_id)


func clear_verb() -> void:
	show_verb("")


func current_verb() -> String:
	return _verb_id


func _on_pressed() -> void:
	if _verb_id != "":
		verb_used.emit(_verb_id)
