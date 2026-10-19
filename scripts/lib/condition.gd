## Evaluates the tiny condition language quest data uses.
##
## CLAUDE_CODE_BRIEF.md §5: `complete_when` is "a small expression over flags
## and world events ... Write a tiny evaluator; no scripting language." This is
## that evaluator, and it stays tiny on purpose:
##
##     true                      always
##     false                     never
##     flag:heard_tulu           the flag is set
##     event:can_placed          the world event has happened
##     not flag:heard_tulu       negation of one term
##     a and b                   both; binds tighter than or
##     a or b                    either
##
## No parentheses, no nesting. If a quest ever needs more than this, the quest
## is too clever: split it into steps or flags instead.
class_name Condition
extends RefCounted

const FLAG_PREFIX := "flag:"
const EVENT_PREFIX := "event:"


## [param flags] and [param events] are the two sets a condition can read.
static func evaluate(expr: String, flags: FlagStore, events: FlagStore) -> bool:
	var text := expr.strip_edges()
	if text.is_empty():
		push_error("Condition: empty expression")
		return false
	for alternative in text.split(" or "):
		if _all_of(alternative, flags, events):
			return true
	return false


## True when every known term in the data could at least be parsed. Used by
## the loaders so a typo in a quest file fails at load, not mid-playtest.
static func is_well_formed(expr: String) -> bool:
	var text := expr.strip_edges()
	if text.is_empty():
		return false
	for alternative in text.split(" or "):
		for term in alternative.split(" and "):
			if not _term_is_well_formed(term.strip_edges()):
				return false
	return true


## Every flag or event name an expression reads, for the debug panel's listing.
static func referenced_names(expr: String, prefix: String) -> PackedStringArray:
	var names := PackedStringArray()
	for alternative in expr.split(" or "):
		for term in alternative.split(" and "):
			var bare := term.strip_edges().trim_prefix("not ").strip_edges()
			if bare.begins_with(prefix):
				names.append(bare.trim_prefix(prefix))
	return names


static func _all_of(conjunction: String, flags: FlagStore, events: FlagStore) -> bool:
	for term in conjunction.split(" and "):
		if not _term(term.strip_edges(), flags, events):
			return false
	return true


static func _term(term: String, flags: FlagStore, events: FlagStore) -> bool:
	if term.begins_with("not "):
		return not _term(term.trim_prefix("not ").strip_edges(), flags, events)
	if term == "true":
		return true
	if term == "false":
		return false
	if term.begins_with(FLAG_PREFIX):
		return flags.has(term.trim_prefix(FLAG_PREFIX))
	if term.begins_with(EVENT_PREFIX):
		return events.has(term.trim_prefix(EVENT_PREFIX))
	push_error("Condition: unknown term '%s'" % term)
	return false


static func _term_is_well_formed(term: String) -> bool:
	var bare := term.trim_prefix("not ").strip_edges()
	# A term is one token. Whitespace inside it means syntax this language does
	# not have — "flag:a && flag:b" must fail here, not read as one odd flag.
	for ch in [" ", "\t"]:
		if bare.contains(ch):
			return false
	if bare == "true" or bare == "false":
		return true
	for prefix in [FLAG_PREFIX, EVENT_PREFIX]:
		if bare.begins_with(prefix):
			return bare.length() > prefix.length()
	return false
