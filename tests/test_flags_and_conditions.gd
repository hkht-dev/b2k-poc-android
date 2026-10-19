## Tests the flag set and the condition language.
##
## GDD §12: flags are strings in a set and nothing else is conditional. The
## evaluator is deliberately tiny (CLAUDE_CODE_BRIEF.md §5); these tests are
## its whole specification.
extends GutTest


func _flags(names: Array) -> FlagStore:
	var store := FlagStore.new()
	for name in names:
		store.set_flag(name)
	return store


func test_a_flag_is_set_or_it_is_not() -> void:
	var store := FlagStore.new()
	assert_false(store.has("heard_tulu"))
	assert_true(store.set_flag("heard_tulu"), "first set is a change")
	assert_true(store.has("heard_tulu"))
	assert_false(store.set_flag("heard_tulu"), "setting it again is not a change")
	assert_true(store.clear_flag("heard_tulu"))
	assert_false(store.clear_flag("heard_tulu"), "clearing a clear flag is not a change")


func test_only_real_transitions_are_announced() -> void:
	var store := FlagStore.new()
	watch_signals(store)
	store.set_flag("a")
	store.set_flag("a")
	store.clear_flag("b")
	assert_signal_emit_count(store, "changed", 1, "one set, one duplicate set, one no-op clear")


func test_the_empty_name_is_never_a_flag() -> void:
	var store := FlagStore.new()
	assert_false(store.set_flag(""))
	assert_eq(store.size(), 0)


func test_all_is_sorted_so_saves_and_listings_are_stable() -> void:
	var store := _flags(["zeta", "alpha", "mid"])
	assert_eq(Array(store.all()), ["alpha", "mid", "zeta"])


func test_replace_all_restores_without_announcing() -> void:
	var store := FlagStore.new()
	watch_signals(store)
	store.replace_all(PackedStringArray(["a", "b", ""]))
	assert_signal_not_emitted(store, "changed", "loading a save is not a change")
	assert_eq(store.size(), 2, "and the empty name is dropped")


func test_true_and_false() -> void:
	var none := FlagStore.new()
	assert_true(Condition.evaluate("true", none, none))
	assert_false(Condition.evaluate("false", none, none))


func test_flag_and_event_terms_read_their_own_sets() -> void:
	var flags := _flags(["heard_tulu"])
	var events := _flags(["can_placed"])
	assert_true(Condition.evaluate("flag:heard_tulu", flags, events))
	assert_false(Condition.evaluate("event:heard_tulu", flags, events), "a flag is not an event")
	assert_true(Condition.evaluate("event:can_placed", flags, events))
	assert_false(Condition.evaluate("flag:can_placed", flags, events), "an event is not a flag")


func test_not_negates_one_term() -> void:
	var flags := _flags(["a"])
	var none := FlagStore.new()
	assert_false(Condition.evaluate("not flag:a", flags, none))
	assert_true(Condition.evaluate("not flag:b", flags, none))


func test_and_binds_tighter_than_or() -> void:
	var flags := _flags(["a"])
	var none := FlagStore.new()
	# (a and b) or a  ->  false or true  -> true
	assert_true(Condition.evaluate("flag:a and flag:b or flag:a", flags, none))
	# a or (b and c) -> true or false -> true ; and with a unset:
	assert_false(Condition.evaluate("flag:b or flag:c and flag:a", flags, none))


func test_the_dry_fountain_take_branch_reads_as_written() -> void:
	var events := _flags(["can_taken_from_shop"])
	var expr := "event:can_taken_from_shop and not flag:gopal_will_carry"
	assert_true(Condition.evaluate(expr, FlagStore.new(), events), "took, never agreed to carry")
	assert_false(
		Condition.evaluate(expr, _flags(["gopal_will_carry"]), events),
		"took after agreeing to carry is not the take branch"
	)


func test_malformed_expressions_are_rejected_at_load_not_at_play() -> void:
	assert_true(Condition.is_well_formed("flag:a and not event:b or true"))
	assert_false(Condition.is_well_formed(""))
	assert_false(Condition.is_well_formed("flag:"), "a prefix with no name")
	assert_false(Condition.is_well_formed("heard_tulu"), "a bare name has no namespace")
	assert_false(Condition.is_well_formed("flag:a && flag:b"), "no other syntax is accepted")


func test_referenced_names_lists_what_an_expression_reads() -> void:
	var expr := "flag:a and not flag:b or event:c"
	assert_eq(Array(Condition.referenced_names(expr, "flag:")), ["a", "b"])
	assert_eq(Array(Condition.referenced_names(expr, "event:")), ["c"])
