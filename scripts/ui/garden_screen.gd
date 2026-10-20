## The garden, drawn: rows of soil, seeds as dots, saplings as stems, fruit
## as warm circles, weeds as grey tufts, the creeper as a vine up the wall on
## the right. Touch a plant and the sentence it came from is shown below; a
## weed offers *Pull*.
##
## GDD §6 "The Garden": "No numbers, no bars, no comparisons." Nothing on
## this screen is a count; a thicker stem is a habit, a taller vine is a
## creeper that was watered, and the only text a plant has is its sentence.
## Seeds of every kind look alike, and so does every fruit: what was planted
## is said by the sentence, not painted on (the garden shows consequence,
## never a verdict). The GDD places the plot in the Grove; until the Grove
## is built this opens from the pause menu (docs/DECISIONS.md).
extends Control

signal closed
signal plant_focused(id: String)

const PLANTS_PER_ROW := 4
const MIN_ROWS := 3
## The wall the creeper climbs takes this share of the plot's width.
const WALL_SHARE := 0.22
const TAP_RADIUS := 80.0
const SAPLING_HEIGHT := 70.0
const FRUITING_HEIGHT := 95.0
const CREEPER_ID := "creeper"
## GDD §10, Hollow Vale: earth, timber, plaster and one warm fruit. No
## peacock blue, no magenta.
const SOIL := Color(0.33, 0.24, 0.16)
const FURROW := Color(0.24, 0.17, 0.11)
const RIDGE := Color(0.42, 0.31, 0.21)
const SEED := Color(0.16, 0.11, 0.07)
const STEM := Color(0.36, 0.52, 0.27)
const LEAF := Color(0.46, 0.64, 0.33)
const FRUIT := Color(0.93, 0.62, 0.27)
const FRUIT_LIGHT := Color(0.98, 0.8, 0.52)
const SHADE := Color(0.5, 0.55, 0.45)
const WEED := Color(0.56, 0.56, 0.53)
const SCAR := Color(0.18, 0.12, 0.08, 0.55)
const WALL := Color(0.84, 0.77, 0.64)
const WALL_EDGE := Color(0.7, 0.62, 0.5)
const VINE := Color(0.27, 0.45, 0.24)
const FOCUS := Color(1.0, 0.93, 0.8, 0.9)

var _focused := ""
var _plants: Array[Dictionary] = []
## Where each plant stands, in the plot's own coordinates.
var _positions: Dictionary = {}

@onready var _title: Label = %Title
@onready var _plot: Control = %Plot
@onready var _sentence: Label = %Sentence
@onready var _pull: Button = %PullButton
@onready var _close: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Opening the garden on a new calendar date is that day's first play.
	Garden.advance_day(GameState)
	_title.text = Strings.t("garden.title")
	_close.text = Strings.t("garden.close")
	_pull.text = Strings.t("garden.pull")
	_close.pressed.connect(func() -> void: closed.emit())
	_pull.pressed.connect(_on_pull)
	_plot.draw.connect(_draw_plot)
	_plot.resized.connect(_on_plot_resized)
	_plot.gui_input.connect(_on_plot_input)
	refresh()
	_close.grab_focus()


## Rebuilds the plot from the journey.
func refresh() -> void:
	_plants = Garden.plot(GameState)
	_layout()
	_show_focus()
	_plot.queue_redraw()


func plot_control() -> Control:
	return _plot


func focused_id() -> String:
	return _focused


func sentence_text() -> String:
	return _sentence.text


func pull_button() -> Button:
	return _pull


## Where a plant (or the creeper) stands in the plot, for taps and tests.
func plant_position(id: String) -> Vector2:
	return _positions.get(id, Vector2.ZERO)


## Shows a plant's sentence. An empty id clears the focus.
func focus_plant(id: String) -> void:
	_focused = id
	_show_focus()
	_plot.queue_redraw()
	plant_focused.emit(id)


# -- layout -------------------------------------------------------------------


func _rows() -> int:
	return maxi(MIN_ROWS, ceili(float(_plants.size()) / PLANTS_PER_ROW))


func _soil_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_plot.size.x * (1.0 - WALL_SHARE) - 16.0, _plot.size.y))


func _wall_rect() -> Rect2:
	var left := _plot.size.x * (1.0 - WALL_SHARE)
	return Rect2(Vector2(left, 0.0), Vector2(_plot.size.x - left, _plot.size.y))


func _layout() -> void:
	_positions.clear()
	var soil := _soil_rect()
	var cell := Vector2(soil.size.x / PLANTS_PER_ROW, soil.size.y / _rows())
	for i in _plants.size():
		var col := i % PLANTS_PER_ROW
		var row := floori(i / float(PLANTS_PER_ROW))
		_positions[_plants[i]["id"]] = (
			soil.position + Vector2((col + 0.5) * cell.x, (row + 0.8) * cell.y)
		)
	if Garden.creeper_given(GameState):
		var wall := _wall_rect()
		_positions[CREEPER_ID] = Vector2(wall.get_center().x, wall.end.y - wall.size.y * 0.3)


func _on_plot_resized() -> void:
	_layout()
	_plot.queue_redraw()


func _plant(id: String) -> Dictionary:
	for plant in _plants:
		if plant["id"] == id:
			return plant
	return {}


# -- the sentence and the pull ------------------------------------------------


func _show_focus() -> void:
	_pull.visible = false
	if _focused == CREEPER_ID and Garden.creeper_given(GameState):
		_sentence.text = Strings.t(str(Garden.creeper_data().get("sentence_id", "")))
		return
	var plant := _plant(_focused)
	if plant.is_empty():
		_sentence.text = Strings.t("garden.empty" if _plants.is_empty() else "garden.hint")
		return
	_sentence.text = Strings.t(plant["sentence_id"])
	if plant["stage"] == Garden.STAGE_PULLED:
		_sentence.text += "\n" + Strings.t("garden.pulled")
	_pull.visible = plant["stage"] == Garden.STAGE_WEED


func _on_pull() -> void:
	if Garden.pull(GameState, _focused):
		refresh()
		_close.grab_focus()


func _on_plot_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var pressed := false
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if touch != null and touch.pressed:
		at = touch.position
		pressed = true
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		at = click.position
		pressed = true
	if not pressed:
		return
	var best := ""
	var best_distance := TAP_RADIUS
	for id in _positions:
		# A plant stands above the spot it is planted in.
		var distance: float = (_positions[id] + Vector2(0.0, -30.0)).distance_to(at)
		if distance < best_distance:
			best = id
			best_distance = distance
	focus_plant(best)
	_plot.accept_event()


# -- drawing ------------------------------------------------------------------


func _draw_plot() -> void:
	var soil := _soil_rect()
	_plot.draw_rect(soil, SOIL)
	var row_height := soil.size.y / _rows()
	for r in _rows():
		var y := soil.position.y + (r + 0.8) * row_height + 10.0
		var left := Vector2(soil.position.x + 8.0, y)
		var right := Vector2(soil.end.x - 8.0, y)
		_plot.draw_line(left, right, FURROW, 6.0)
		_plot.draw_line(left + Vector2(0.0, -5.0), right + Vector2(0.0, -5.0), RIDGE, 2.0)
	_draw_wall(_wall_rect())
	for plant in _plants:
		_draw_plant(plant, _positions[plant["id"]])
	if not _focused.is_empty() and _positions.has(_focused):
		var at: Vector2 = _positions[_focused]
		_plot.draw_arc(at + Vector2(0.0, -32.0), 52.0, 0.0, TAU, 48, FOCUS, 3.0, true)


func _draw_plant(plant: Dictionary, at: Vector2) -> void:
	var width := clampf(3.0 + 2.0 * (int(plant["thickness"]) - 1), 3.0, 11.0)
	match plant["stage"]:
		Garden.STAGE_SEED:
			_plot.draw_circle(at + Vector2(0.0, -7.0), 7.0, SEED)
		Garden.STAGE_SAPLING:
			_draw_stem(at, SAPLING_HEIGHT, width, STEM, LEAF)
		Garden.STAGE_FRUITING:
			_draw_stem(at, FRUITING_HEIGHT, width, STEM, LEAF)
			_plot.draw_circle(at + Vector2(0.0, -FRUITING_HEIGHT - 10.0), 15.0, FRUIT)
			_plot.draw_circle(at + Vector2(-5.0, -FRUITING_HEIGHT - 15.0), 5.0, FRUIT_LIGHT)
		Garden.STAGE_SHADED:
			_draw_stem(at, SAPLING_HEIGHT, width, SHADE, SHADE)
			var top := at + Vector2(0.0, -SAPLING_HEIGHT)
			_plot.draw_line(top, top + Vector2(16.0, 14.0), SHADE, width)
		Garden.STAGE_WEED:
			for k in 5:
				var angle := -PI / 2.0 + (k - 2) * 0.35
				_plot.draw_line(at, at + Vector2.from_angle(angle) * 42.0, WEED, 3.0)
		Garden.STAGE_PULLED:
			_plot.draw_circle(at, 5.0, SCAR)


func _draw_stem(at: Vector2, height: float, width: float, colour: Color, leaf: Color) -> void:
	_plot.draw_line(at, at + Vector2(0.0, -height), colour, width)
	var node := at + Vector2(0.0, -height * 0.55)
	_plot.draw_line(node, node + Vector2(-18.0, -12.0), leaf, 3.0)
	_plot.draw_line(node + Vector2(0.0, -14.0), node + Vector2(18.0, -26.0), leaf, 3.0)


## The wall on the right and the creeper on it: nothing until the seed is
## given, a seed at its foot once it is, one segment per watered play-day,
## and past the top it climbs out of sight (GDD §6 "The creeper").
func _draw_wall(wall: Rect2) -> void:
	_plot.draw_rect(wall, WALL)
	_plot.draw_rect(Rect2(wall.position, Vector2(wall.size.x, 10.0)), WALL_EDGE)
	for r in 6:
		var y := wall.position.y + wall.size.y * (r + 1) / 7.0
		_plot.draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), WALL_EDGE, 1.5)
	if not Garden.creeper_given(GameState):
		return
	var base := Vector2(wall.get_center().x, wall.end.y - 10.0)
	var steps := Garden.creeper_steps(GameState)
	if steps == 0:
		_plot.draw_circle(base, 7.0, SEED)
		return
	var step_height := wall.size.y / float(int(Garden.creeper_data().get("shade_steps", 3)) + 2)
	var from := base
	for i in steps:
		var sway := 14.0 if i % 2 == 0 else -14.0
		var to := Vector2(base.x + sway, from.y - step_height)
		if to.y < wall.position.y:
			break
		_plot.draw_line(from, to, VINE, 5.0)
		_plot.draw_circle(to, 8.0, LEAF)
		from = to
