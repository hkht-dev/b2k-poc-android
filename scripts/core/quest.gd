## A quest as data, and the small machine that walks it against the journey.
##
## GDD §7 "Quest data fields": id, giver, start_condition, steps[] (id,
## objective_text_id, complete_when, flags_set), branches[], end_condition,
## flags_set_on_end, journey_line_id. A quest step references lines, never
## contains them.
##
## Nothing about progress is saved. It is derived from flags and events every
## time (GDD §12: nothing is conditional on anything but flags and the beat),
## so a loaded journey simply re-walks the quest and lands where it was.
class_name Quest
extends RefCounted

signal started
signal step_completed(step_id: String)
signal ended(branch_id: String)

enum Status { INACTIVE, ACTIVE, ENDED }

const REQUIRED := ["id", "giver", "start_condition", "steps", "end_condition"]
const STEP_REQUIRED := ["id", "objective_text_id", "complete_when"]
const BRANCH_REQUIRED := ["id", "when"]
## How many times reconcile may loop while flags it sets keep changing things.
## A quest that needs more than this is cycling, which is a data bug.
const MAX_PASSES := 16

var id := ""
var giver := ""
var start_condition := "true"
var steps: Array[Dictionary] = []
var branches: Array[Dictionary] = []
var end_condition := "false"
var flags_set_on_end := PackedStringArray()
var journey_line_id := ""

var _state: Node = null
var _status := Status.INACTIVE
var _step_index := 0
var _ended_branch := ""
var _reconciling := false
var _dirty := false


## Builds a quest from parsed JSON. Returns null, with the reason pushed as an
## error naming [param source], when the data is not usable.
static func from_dict(data: Dictionary, source: String) -> Quest:
	for key in REQUIRED:
		if not data.has(key):
			push_error("Quest %s: missing '%s'" % [source, key])
			return null
	var quest := Quest.new()
	quest.id = str(data["id"])
	quest.giver = str(data["giver"])
	quest.start_condition = str(data["start_condition"])
	quest.end_condition = str(data["end_condition"])
	quest.flags_set_on_end = _strings(data.get("flags_set_on_end", []))
	quest.journey_line_id = str(data.get("journey_line_id", ""))

	for expr in [quest.start_condition, quest.end_condition]:
		if not Condition.is_well_formed(expr):
			push_error("Quest %s: bad condition '%s'" % [source, expr])
			return null

	for raw in data["steps"]:
		var step := _step(raw, source)
		if step.is_empty():
			return null
		quest.steps.append(step)

	for raw in data.get("branches", []):
		var branch := _branch(raw, source)
		if branch.is_empty():
			return null
		quest.branches.append(branch)
	return quest


# -- runtime ------------------------------------------------------------------


## Binds the quest to the journey and walks it to wherever the flags say it is.
func attach(state: Node) -> void:
	_state = state
	state.flag_changed.connect(func(_f: String, _s: bool) -> void: reconcile())
	state.event_fired.connect(func(_e: String) -> void: reconcile())
	state.wiped.connect(_on_wiped)
	reconcile()


func status() -> Status:
	return _status


func current_step_id() -> String:
	if _status != Status.ACTIVE or _step_index >= steps.size():
		return ""
	return steps[_step_index]["id"]


## The condition the quest is waiting on, for the debug panel. Empty when the
## quest is not active or every step is done.
func waiting_on() -> String:
	if _status != Status.ACTIVE or _step_index >= steps.size():
		return ""
	return steps[_step_index]["complete_when"]


func ended_branch() -> String:
	return _ended_branch


## The objective text id of the current step, for the pause menu's one line.
func current_objective_text_id() -> String:
	if _status != Status.ACTIVE or _step_index >= steps.size():
		return ""
	return steps[_step_index]["objective_text_id"]


## Re-derives status from the journey. Flags this sets re-enter here through
## the journey's signals; the guard turns that into one more pass rather than
## a recursion.
func reconcile() -> void:
	if _state == null:
		return
	if _reconciling:
		_dirty = true
		return
	_reconciling = true
	var passes := 0
	while passes < MAX_PASSES:
		passes += 1
		_dirty = false
		_pass()
		if not _dirty:
			break
	if passes >= MAX_PASSES:
		push_error("Quest %s: still changing after %d passes; the data cycles" % [id, passes])
	_reconciling = false


func _pass() -> void:
	if _status == Status.ENDED:
		return
	if _status == Status.INACTIVE:
		if not _holds(start_condition):
			return
		_status = Status.ACTIVE
		started.emit()

	for branch in branches:
		if _holds(branch["when"]):
			_end(branch["id"], branch["flags_set"], branch["journey_line_id"])
			return

	while _step_index < steps.size() and _holds(steps[_step_index]["complete_when"]):
		var step: Dictionary = steps[_step_index]
		_step_index += 1
		for flag in step["flags_set"]:
			_state.set_flag(flag)
		step_completed.emit(step["id"])
		if _status != Status.ACTIVE:
			return
		# Flags this step set may have made a branch true. Branches are checked
		# at the top of a pass, so hand back to reconcile for a fresh one rather
		# than letting end_condition below claim the ending first.
		if _dirty:
			return

	if _holds(end_condition):
		_end("", flags_set_on_end, journey_line_id)


func _end(branch_id: String, flags: PackedStringArray, line_id: String) -> void:
	_status = Status.ENDED
	_ended_branch = branch_id
	for flag in flags:
		_state.set_flag(flag)
	if not line_id.is_empty():
		_state.add_journey_line(line_id)
	ended.emit(branch_id)


func _holds(expr: String) -> bool:
	return Condition.evaluate(expr, _state.flags, _state.events)


func _on_wiped() -> void:
	_status = Status.INACTIVE
	_step_index = 0
	_ended_branch = ""
	reconcile()


# -- introspection ------------------------------------------------------------


## Every flag this quest reads or sets, for the debug panel's listing.
func known_flags() -> PackedStringArray:
	var names := PackedStringArray()
	names.append_array(Condition.referenced_names(start_condition, Condition.FLAG_PREFIX))
	names.append_array(Condition.referenced_names(end_condition, Condition.FLAG_PREFIX))
	names.append_array(flags_set_on_end)
	for step in steps:
		names.append_array(Condition.referenced_names(step["complete_when"], Condition.FLAG_PREFIX))
		names.append_array(step["flags_set"])
	for branch in branches:
		names.append_array(Condition.referenced_names(branch["when"], Condition.FLAG_PREFIX))
		names.append_array(branch["flags_set"])
	return names


func known_events() -> PackedStringArray:
	var names := PackedStringArray()
	var prefix := Condition.EVENT_PREFIX
	names.append_array(Condition.referenced_names(start_condition, prefix))
	names.append_array(Condition.referenced_names(end_condition, prefix))
	for step in steps:
		names.append_array(Condition.referenced_names(step["complete_when"], prefix))
	for branch in branches:
		names.append_array(Condition.referenced_names(branch["when"], prefix))
	return names


# -- parsing ------------------------------------------------------------------


static func _step(raw: Variant, source: String) -> Dictionary:
	if not raw is Dictionary:
		push_error("Quest %s: a step is not an object" % source)
		return {}
	for key in STEP_REQUIRED:
		if not raw.has(key):
			push_error("Quest %s: step missing '%s'" % [source, key])
			return {}
	var when := str(raw["complete_when"])
	if not Condition.is_well_formed(when):
		push_error("Quest %s: step '%s' has bad complete_when '%s'" % [source, raw["id"], when])
		return {}
	return {
		"id": str(raw["id"]),
		"objective_text_id": str(raw["objective_text_id"]),
		"complete_when": when,
		"flags_set": _strings(raw.get("flags_set", [])),
	}


static func _branch(raw: Variant, source: String) -> Dictionary:
	if not raw is Dictionary:
		push_error("Quest %s: a branch is not an object" % source)
		return {}
	for key in BRANCH_REQUIRED:
		if not raw.has(key):
			push_error("Quest %s: branch missing '%s'" % [source, key])
			return {}
	var when := str(raw["when"])
	if not Condition.is_well_formed(when):
		push_error("Quest %s: branch '%s' has bad when '%s'" % [source, raw["id"], when])
		return {}
	return {
		"id": str(raw["id"]),
		"when": when,
		"flags_set": _strings(raw.get("flags_set", [])),
		"journey_line_id": str(raw.get("journey_line_id", "")),
	}


static func _strings(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array:
		for item in value:
			out.append(str(item))
	return out
