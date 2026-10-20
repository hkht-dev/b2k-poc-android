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
##
## Off touch it wears a small key badge in its corner — "E", or the gamepad's
## face button — so a player at a keyboard knows what presses it (GDD §11
## "Controls"; owner request 2026-10-20). The badge is a word from the string
## table, set by TouchControls with the scheme; on touch it is never shown.
extends Button

## Emitted on a press, carrying the string id of the verb that was showing, so
## the caller never has to read the label text back.
signal verb_used(verb_id: String)
## Emitted when the button is held with no verb showing: the Call (GDD §6).
signal hummed

const FADE_SPEED := 8.0
## How long a press with nothing near must last to become a hum.
const HUM_HOLD := 0.5
## The one verb a hold reaches past: emptying the hand is a tap, and the
## Call must stay available wherever the player is standing.
const PUT_DOWN_VERB := "verb.put_down"
## With nothing near, the button stays as a faint mark so a hold has somewhere
## to land (GDD §6 "Call": "hold the interact button with nothing nearby").
const IDLE_ALPHA := 0.35
const BADGE_SIZE := 32.0
const BADGE_INSET := 8.0
const BADGE_FONT_SIZE := 16
const BADGE_INK := Color(0.42, 0.31, 0.208, 1.0)
const BADGE_PAPER := Color(0.957, 0.925, 0.847, 1.0)

var _verb_id := ""
var _shown := 0.0
var _held := 0.0
var _holding := false
var _hum_fired := false
var _badge: Label = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = Strings.t("verb.idle")
	modulate.a = IDLE_ALPHA
	pressed.connect(_on_pressed)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	_badge = _make_badge()
	add_child(_badge)


func _process(delta: float) -> void:
	var wanted := 1.0 if _verb_id != "" else IDLE_ALPHA
	_shown = move_toward(_shown, wanted, FADE_SPEED * delta)
	modulate.a = _shown
	if _holding and _hums_through() and not _hum_fired:
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


## True when a hold on the button is the Call rather than the verb: with
## nothing near, and with the *Put down* fallback, which is a tap only.
func _hums_through() -> bool:
	return _verb_id == "" or _verb_id == PUT_DOWN_VERB


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


## The key that presses this button, already resolved from the string table
## by the caller; empty hides the badge (touch has no key).
func set_key_badge(key_text: String) -> void:
	_badge.text = key_text
	_badge.visible = not key_text.is_empty()


func key_badge_text() -> String:
	return _badge.text


func key_badge_visible() -> bool:
	return _badge.visible


func _make_badge() -> Label:
	var badge := Label.new()
	badge.name = "KeyBadge"
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.position = Vector2(BADGE_INSET, BADGE_INSET)
	badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	badge.add_theme_color_override("font_color", BADGE_PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = BADGE_INK
	box.set_corner_radius_all(6)
	box.set_content_margin_all(2.0)
	badge.add_theme_stylebox_override("normal", box)
	return badge


func _on_pressed() -> void:
	if _verb_id != "":
		verb_used.emit(_verb_id)
