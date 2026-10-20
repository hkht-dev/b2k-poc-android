## A heading strip at the top of the HUD: which way the player is facing.
##
## Owner request 2026-10-20 ("navigation should show which direction it is
## heading"). It shows the compass points as they pass the centre tick, and
## nothing else: no destination, no marker, no distance (GDD §6 "What is
## deliberately absent" rules out markers; a heading is not one, see
## docs/DECISIONS.md). Letters come from the string table. On by default;
## the settings screen can hide it.
extends Control

const SETTING := "compass"
const WIDTH := 420.0
const HEIGHT := 44.0
## Degrees of heading shown either side of the centre.
const SPAN := 70.0
const PAPER := Color(0.957, 0.925, 0.847, 0.6)
const INK := Color(0.42, 0.31, 0.208, 0.95)
const FAINT := Color(0.42, 0.31, 0.208, 0.4)
const POINTS := {0: "compass.north", 90: "compass.east", 180: "compass.south", 270: "compass.west"}

var _heading := 0.0
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	_font = get_theme_default_font()
	refresh_visibility()


static func enabled() -> bool:
	return GameState.settings.get(SETTING, true) == true


func refresh_visibility() -> void:
	visible = enabled()


## The facing as a body yaw: 0 looks north (-Z), and turning left is positive.
func set_heading(yaw: float) -> void:
	if not is_equal_approx(yaw, _heading):
		_heading = yaw
		queue_redraw()


## Compass bearing in degrees, 0 north, 90 east, clockwise.
func bearing_degrees() -> float:
	return fposmod(-rad_to_deg(_heading), 360.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), PAPER)
	var bearing := bearing_degrees()
	var centre := WIDTH * 0.5
	var per_degree := WIDTH / (SPAN * 2.0)
	for tick in range(0, 360, 15):
		var offset := fposmod(tick - bearing + 180.0, 360.0) - 180.0
		if absf(offset) > SPAN:
			continue
		var x := centre + offset * per_degree
		var strength := 1.0 - absf(offset) / SPAN
		if POINTS.has(tick):
			var letter: String = Strings.t(POINTS[tick])
			var width := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
			var colour := Color(INK, INK.a * strength)
			draw_string(
				_font,
				Vector2(x - width * 0.5, 30.0),
				letter,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				22,
				colour
			)
		else:
			var tall := tick % 45 == 0
			draw_line(
				Vector2(x, HEIGHT - (14.0 if tall else 8.0)),
				Vector2(x, HEIGHT - 2.0),
				Color(FAINT, FAINT.a * strength),
				2.0
			)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(centre - 7.0, 0.0), Vector2(centre + 7.0, 0.0), Vector2(centre, 9.0)]
		),
		INK
	)
