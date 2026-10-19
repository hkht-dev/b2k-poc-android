## A simple drawn diagram for the controls card: a phone with two thumb zones
## and the one button, or a keyboard-and-mouse, or a gamepad.
##
## Drawn rather than an image so it costs nothing to ship and uses the same
## strings as the card. docs/BRIEF_AMENDMENT_1.md §A5.
extends Control

const INK := Color(0.42, 0.31, 0.208, 1.0)
const PAPER := Color(0.957, 0.925, 0.847, 1.0)
const FAINT := Color(0.42, 0.31, 0.208, 0.25)

var scheme := "touch"


func _draw() -> void:
	match scheme:
		"touch":
			_draw_phone()
		"gamepad":
			_draw_gamepad()
		_:
			_draw_desktop()


func _label(text: String, at: Vector2, size: int = 18) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string(
		font, at + Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, INK
	)


func _draw_phone() -> void:
	var w := size.x
	var h := size.y
	var phone := Rect2(w * 0.5 - h * 0.28, 8.0, h * 0.56, h - 16.0)
	draw_rect(phone, FAINT, false, 3.0)
	var zone_split := phone.position.x + phone.size.x * 0.45
	draw_line(Vector2(zone_split, phone.position.y), Vector2(zone_split, phone.end.y), FAINT, 2.0)
	var left := Vector2(
		phone.position.x + phone.size.x * 0.22, phone.position.y + phone.size.y * 0.66
	)
	var right := Vector2(
		phone.position.x + phone.size.x * 0.72, phone.position.y + phone.size.y * 0.5
	)
	draw_circle(left, 30.0, FAINT)
	draw_circle(left, 12.0, INK)
	draw_arc(right, 26.0, 0.6, 5.6, 32, INK, 3.0, true)
	var button := Rect2(phone.end.x - 70.0, phone.end.y - 56.0, 54.0, 30.0)
	draw_rect(button, INK, false, 2.0)
	_label(Strings.t("controls.diagram.move"), left + Vector2(0.0, 58.0))
	_label(Strings.t("controls.diagram.look"), right + Vector2(0.0, -40.0))
	_label(Strings.t("controls.diagram.tap"), right + Vector2(0.0, 58.0))
	_label(
		Strings.t("controls.diagram.use"),
		Vector2(button.get_center().x, button.position.y - 12.0),
		16
	)


func _draw_desktop() -> void:
	var w := size.x
	var h := size.y
	var origin := Vector2(w * 0.5 - 150.0, h * 0.5 - 20.0)
	for key_pos: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)]:
		draw_rect(Rect2(origin + key_pos * 48.0, Vector2(42.0, 42.0)), INK, false, 2.0)
	_label("W", origin + Vector2(69.0, 28.0))
	_label("A", origin + Vector2(21.0, 76.0))
	_label("S", origin + Vector2(69.0, 76.0))
	_label("D", origin + Vector2(117.0, 76.0))
	draw_rect(Rect2(origin + Vector2(190.0, 0.0), Vector2(42.0, 42.0)), INK, false, 2.0)
	_label("E", origin + Vector2(211.0, 28.0))
	var mouse := Rect2(origin + Vector2(290.0, -4.0), Vector2(44.0, 72.0))
	draw_rect(mouse, INK, false, 2.0)
	draw_line(mouse.position + Vector2(22.0, 0.0), mouse.position + Vector2(22.0, 30.0), INK, 2.0)
	_label(Strings.t("controls.diagram.move"), origin + Vector2(69.0, 118.0))
	_label(Strings.t("controls.diagram.use"), origin + Vector2(211.0, 72.0), 16)
	_label(Strings.t("controls.diagram.look"), mouse.get_center() + Vector2(0.0, 62.0))


func _draw_gamepad() -> void:
	var c := size * 0.5
	draw_rect(Rect2(c + Vector2(-150.0, -50.0), Vector2(300.0, 100.0)), FAINT, false, 3.0)
	draw_circle(c + Vector2(-90.0, -8.0), 22.0, INK)
	draw_circle(c + Vector2(50.0, 22.0), 22.0, INK)
	draw_circle(c + Vector2(100.0, -14.0), 12.0, INK)
	_label(Strings.t("controls.diagram.move"), c + Vector2(-90.0, 40.0))
	_label(Strings.t("controls.diagram.look"), c + Vector2(50.0, 66.0))
	_label(Strings.t("controls.diagram.use"), c + Vector2(100.0, -34.0), 16)
