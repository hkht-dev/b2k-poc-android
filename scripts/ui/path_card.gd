## The Path card (GDD §16a "Path card"): at the chapter's end, one image of
## the way the player walked about the block and what they noticed, the size
## of a phone story, saved to the device for the player to share however they
## like. Nothing on it is a number: no distance, no time, no count.
##
## Drawn on the CPU into an Image rather than through a viewport: the test
## runner is headless and has no renderer, and an Image draws the same on
## every platform. The route is an ink brush stamped along the way, the block
## is the minimap's footprints laid down faintly, and the text is shaped by
## the TextServer with its glyph bitmaps blended in. docs/DECISIONS.md "The
## Path card" records the trade.
##
## PLACEHOLDER: paper and ink stand in for the illustrated card of GDD §10
## (the painted style, the hand-lettered title) once an artist draws it.
class_name PathCard
extends RefCounted

const WIDTH := 1080
const HEIGHT := 1920
const DEFAULT_SAVE_PATH := "user://path_card.png"
## The street block in metres (x, z), as tools/gen_street.py lays it out.
const BLOCK := Rect2(-65.0, -45.0, 130.0, 90.0)
## Where the block sits on the card, in the block's own proportions.
const MAP_RECT := Rect2(90.0, 300.0, 900.0, 623.0)
const MARGIN := 90.0
const TEXT_WIDTH := WIDTH - 2.0 * MARGIN

## The minimap's paper and ink (scripts/ui/minimap.gd), opaque.
const PAPER := Color(0.957, 0.925, 0.847)
const INK := Color(0.42, 0.31, 0.208)
const ROUTE_INK := Color(0.2, 0.16, 0.1)
## How far a footprint steps from the paper toward its colour.
const FAINT := 0.3
const BORDER := 3
const ROUTE_RADIUS := 5
## Pixels between brush stamps along a segment.
const ROUTE_STEP := 3.0
const END_DOT_RADIUS := 11
const RING_WIDTH := 4

const TITLE_SIZE := 68
const SUBTITLE_SIZE := 34
const HEADING_SIZE := 40
const END_LINE_SIZE := 36
const BODY_SIZE := 34
const LINE_GAP := 10.0
const TITLE_Y := 110.0
const TEXT_Y := 980.0
const END_LINE_Y := 1700.0
## Body text stops here so the end line always has its room.
const TEXT_FLOOR := 1620.0

const HEADING_FONT := preload("res://assets/ui/font_heading.tres")
const BODY_FONT := preload("res://assets/ui/font_body.tres")

## The block's footprints as the street's minimap collected them: world XZ
## rects and a colour. Kept here because the street is gone by the time the
## end screen draws the card.
static var _blocks: Array[Dictionary] = []

var _image: Image = null
var _labels := PackedStringArray()
## Tinted glyph bitmaps by font, size, glyph and colour.
var _glyphs: Dictionary = {}
## The card's own copies of the UI fonts, by the font they copy.
var _fonts: Dictionary = {}


## The street remembers its footprints for the card (place.gd, on the street).
static func remember_blocks(footprints: Array[Dictionary]) -> void:
	_blocks.clear()
	for entry in footprints:
		_blocks.append(entry.duplicate())


static func blocks() -> Array[Dictionary]:
	return _blocks


## A point on the street (x, z in metres) to a point on the card.
static func to_card(world_xz: Vector2) -> Vector2:
	var unit := ((world_xz - BLOCK.position) / BLOCK.size).clamp(Vector2.ZERO, Vector2.ONE)
	return MAP_RECT.position + unit * MAP_RECT.size


## The journey's route as points, oldest first.
static func route_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for entry in GameState.route:
		if entry is Array and entry.size() >= 2:
			out.append(Vector2(float(entry[0]), float(entry[1])))
	return out


## What the player noticed (GDD §6 "Tells", §16a "Noticed"), when the journey
## keeps such a list. This slice's journey does not; the card leaves the room.
static func noticed_sentences() -> PackedStringArray:
	var out := PackedStringArray()
	if not "noticed" in GameState:
		return out
	var noticed: Variant = GameState.get("noticed")
	if not noticed is Array:
		return out
	for entry in noticed:
		var sentence := _sentence_of(entry)
		if not sentence.is_empty():
			out.append(sentence)
	return out


## A noticed entry is a string id, a sentence, or a record holding one.
static func _sentence_of(entry: Variant) -> String:
	if entry is Dictionary:
		for key in ["text_id", "line_id", "id"]:
			if entry.has(key) and Strings.has_id(str(entry[key])):
				return Strings.t(str(entry[key]))
		for key in ["text", "sentence"]:
			if entry.has(key):
				return str(entry[key])
		return ""
	var text := str(entry)
	return Strings.t(text) if Strings.has_id(text) else text


## Draws the card from the journey. Returns the image; image() keeps it.
func render() -> Image:
	_labels.clear()
	_image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	_image.fill(PAPER)
	var y := _draw_text(
		Strings.t("app.title"), HEADING_FONT, TITLE_SIZE, INK, TITLE_Y, true, HEIGHT
	)
	var place_name := Strings.t(Places.name_id_of(GameState.ROUTE_PLACE))
	var subtitle := Strings.t("end.card_subtitle") % place_name
	_draw_text(subtitle, BODY_FONT, SUBTITLE_SIZE, INK, y + LINE_GAP, true, HEIGHT)
	_draw_block()
	_draw_route(route_points())
	y = TEXT_Y
	var journey := PackedStringArray()
	for line_id in GameState.journey_lines:
		journey.append(Strings.t(line_id))
	if not journey.is_empty():
		y = _draw_text(Strings.t("pause.journey"), HEADING_FONT, HEADING_SIZE, INK, y, false)
		y = _draw_lines(journey, y)
	var noticed := noticed_sentences()
	if not noticed.is_empty():
		var heading := Strings.t("end.card_noticed")
		y = _draw_text(heading, HEADING_FONT, HEADING_SIZE, INK, y + 2.0 * LINE_GAP, false)
		y = _draw_lines(noticed, y)
	_draw_text(Strings.t("end.line"), HEADING_FONT, END_LINE_SIZE, INK, END_LINE_Y, true, HEIGHT)
	return _image


func image() -> Image:
	return _image


## Every piece of text drawn on the card, in order. Tests read it; nothing
## on it may be a number.
func labels() -> PackedStringArray:
	return _labels


## Saves the card as a PNG, rendering first if nothing has been.
func save_png(path: String = DEFAULT_SAVE_PATH) -> bool:
	if _image == null:
		render()
	var error := _image.save_png(path)
	if error != OK:
		push_error("PathCard: could not write %s (%d)" % [path, error])
		return false
	return true


# -- the block and the route --------------------------------------------------


## The block, faint, from the footprints the street's minimap collected, with
## a thin frame around the map.
func _draw_block() -> void:
	for entry in _blocks:
		var world: Rect2 = entry.get("rect", Rect2())
		var colour: Color = entry.get("color", INK)
		var a := to_card(world.position)
		var b := to_card(world.end)
		var rect := Rect2(a, b - a).abs().intersection(MAP_RECT)
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			continue
		_image.fill_rect(Rect2i(rect), PAPER.lerp(Color(colour, 1.0), FAINT))
	_stroke(Rect2i(MAP_RECT.grow(BORDER)), BORDER, PAPER.lerp(INK, 0.5))


## The outline of a rectangle, [param width] pixels in, as four fills.
func _stroke(rect: Rect2i, width: int, colour: Color) -> void:
	var across := Vector2i(rect.size.x, width)
	var down := Vector2i(width, rect.size.y)
	_image.fill_rect(Rect2i(rect.position, across), colour)
	_image.fill_rect(Rect2i(rect.position + Vector2i(0, rect.size.y - width), across), colour)
	_image.fill_rect(Rect2i(rect.position, down), colour)
	_image.fill_rect(Rect2i(rect.position + Vector2i(rect.size.x - width, 0), down), colour)


## The route as one ink line: a ring where the walk began, a dot where it
## ended. Nothing is written beside it.
func _draw_route(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var brush := _brush(ROUTE_RADIUS, ROUTE_INK)
	var start := to_card(points[0])
	var last := start
	_stamp(brush, last)
	for i in range(1, points.size()):
		var next := to_card(points[i])
		var steps := maxi(1, ceili(last.distance_to(next) / ROUTE_STEP))
		for step in range(1, steps + 1):
			_stamp(brush, last.lerp(next, float(step) / steps))
		last = next
	_stamp(_brush(END_DOT_RADIUS, ROUTE_INK), start)
	_stamp(_brush(END_DOT_RADIUS - RING_WIDTH, PAPER), start)
	_stamp(_brush(END_DOT_RADIUS, ROUTE_INK), last)


func _stamp(brush: Image, centre: Vector2) -> void:
	var half := brush.get_width() / 2
	var at := Vector2i(centre.round()) - Vector2i(half, half)
	_image.blend_rect(brush, Rect2i(Vector2i.ZERO, brush.get_size()), at)


## A round brush with a one-pixel soft edge, as ink from a pen.
static func _brush(radius: int, colour: Color) -> Image:
	var side := radius * 2 + 1
	var brush := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var distance := Vector2(x - radius, y - radius).length()
			var coverage := clampf(radius + 0.5 - distance, 0.0, 1.0)
			brush.set_pixel(x, y, Color(colour, colour.a * coverage))
	return brush


# -- text ---------------------------------------------------------------------


## Draws a paragraph wrapped to the text width, centred or from the left
## margin, from [param y] down. Returns the y below it. Lines that would
## cross [param floor_y] are not drawn.
func _draw_text(
	text: String,
	font: Font,
	size: int,
	colour: Color,
	y: float,
	centred: bool,
	floor_y: float = TEXT_FLOOR
) -> float:
	_labels.append(text)
	var ts := TextServerManager.get_primary_interface()
	var card_font := _card_font(font)
	var shaped := ts.create_shaped_text()
	var features := card_font.get_opentype_features()
	ts.shaped_text_add_string(
		shaped, text, card_font.get_rids(), size, features, Strings.get_locale()
	)
	var breaks := ts.shaped_text_get_line_breaks(shaped, TEXT_WIDTH)
	for i in range(0, breaks.size(), 2):
		var line := ts.shaped_text_substr(shaped, breaks[i], breaks[i + 1] - breaks[i])
		var ascent := ts.shaped_text_get_ascent(line)
		var descent := ts.shaped_text_get_descent(line)
		if y + ascent + descent > floor_y:
			ts.free_rid(line)
			break
		var indent := (TEXT_WIDTH - ts.shaped_text_get_width(line)) * 0.5 if centred else 0.0
		var pen := Vector2(MARGIN + indent, y + ascent)
		for glyph: Dictionary in ts.shaped_text_get_glyphs(line):
			for _repeat in int(glyph["repeat"]):
				_blit_glyph(ts, glyph, pen, colour)
				pen.x += float(glyph["advance"])
		y += ascent + descent + LINE_GAP * 0.5
		ts.free_rid(line)
	ts.free_rid(shaped)
	return y


func _draw_lines(lines: PackedStringArray, y: float) -> float:
	for line in lines:
		y = _draw_text(line, BODY_FONT, BODY_SIZE, INK, y + LINE_GAP, false)
	return y


## Blends one shaped glyph onto the card at the pen.
func _blit_glyph(ts: TextServer, glyph: Dictionary, pen: Vector2, colour: Color) -> void:
	var rid: RID = glyph["font_rid"]
	if not rid.is_valid():
		return
	var index := int(glyph["index"])
	var size := Vector2i(int(glyph["font_size"]), 0)
	var key := "%d/%d/%d/%s" % [rid.get_id(), size.x, index, colour.to_html()]
	var sprite: Image = _glyphs.get(key)
	if sprite == null:
		sprite = _glyph_sprite(ts, rid, size, index, colour)
		_glyphs[key] = sprite
	if sprite.is_empty():
		return
	var at: Vector2 = pen + glyph["offset"] + ts.font_get_glyph_offset(rid, size, index)
	_image.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(at.round()))


## The glyph's coverage bitmap cut from the font's atlas, in the ink colour.
## An empty image for a glyph with no bitmap (a space).
func _glyph_sprite(ts: TextServer, rid: RID, size: Vector2i, index: int, colour: Color) -> Image:
	var uv := Rect2i(ts.font_get_glyph_uv_rect(rid, size, index))
	var texture := ts.font_get_glyph_texture_idx(rid, size, index)
	if texture < 0 or uv.size.x <= 0 or uv.size.y <= 0:
		return Image.new()
	var atlas: Image = ts.font_get_texture_image(rid, size, texture)
	if atlas == null or atlas.is_empty():
		return Image.new()
	var region := atlas.get_region(uv)
	var logical := Vector2i(ts.font_get_glyph_size(rid, size, index).round())
	if logical.x > 0 and logical.y > 0 and logical != uv.size:
		region.resize(logical.x, logical.y, Image.INTERPOLATE_BILINEAR)
	region.convert(Image.FORMAT_RGBA8)
	var coverage := region.get_data()
	var sprite := Image.create(region.get_width(), region.get_height(), false, Image.FORMAT_RGBA8)
	sprite.fill(Color(colour, 1.0))
	var data := sprite.get_data()
	for i in range(3, data.size(), 4):
		data[i] = int(coverage[i] * colour.a)
	sprite.set_data(region.get_width(), region.get_height(), false, Image.FORMAT_RGBA8, data)
	return sprite


## The card's copy of a UI font, rasterised one to one. The UI fonts follow
## the window's scale (oversampling: a thirtieth of a pixel headless, the
## phone's ratio on a phone); the card is always 1080 wide.
func _card_font(font: Font) -> Font:
	if _fonts.has(font):
		return _fonts[font]
	var out := FontVariation.new()
	var variation := font as FontVariation
	if variation == null:
		out.base_font = _unscaled(font)
	else:
		out.base_font = _unscaled(variation.base_font)
		var fallbacks: Array[Font] = []
		for fallback in variation.fallbacks:
			fallbacks.append(_unscaled(fallback))
		out.fallbacks = fallbacks
	_fonts[font] = out
	return out


static func _unscaled(font: Font) -> Font:
	var file := font as FontFile
	if file == null:
		return font
	var copy: FontFile = file.duplicate()
	copy.oversampling = 1.0
	return copy
