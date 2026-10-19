## Tests that the title screen takes every word it shows from the string table.
##
## CLAUDE_CODE_BRIEF.md §10: "Every flag, every string id and every quest step
## is data, never a literal in code." The text set in the .tscn is only editor
## scaffolding; what a player reads must come from data/strings/.
extends GutTest

const TITLE_SCREEN := preload("res://scenes/ui/TitleScreen.tscn")
const MAIN := preload("res://scenes/core/Main.tscn")


func test_title_text_comes_from_the_string_table() -> void:
	var screen: Control = autofree(TITLE_SCREEN.instantiate())
	add_child_autofree(screen)
	assert_eq(screen.get_node("%Title").text, Strings.t("app.title"))
	assert_eq(screen.get_node("%BeginButton").text, Strings.t("title.begin"))


func test_build_label_names_the_project_version() -> void:
	var screen: Control = autofree(TITLE_SCREEN.instantiate())
	add_child_autofree(screen)
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	assert_ne(version, "", "project.godot carries a version for testers to quote")
	assert_true(
		screen.get_node("%BuildLabel").text.contains(version),
		"the build label names the version a tester would report"
	)


func test_begin_emits_a_signal_rather_than_loading_a_scene_itself() -> void:
	var screen: Control = autofree(TITLE_SCREEN.instantiate())
	add_child_autofree(screen)
	watch_signals(screen)
	screen.get_node("%BeginButton").pressed.emit()
	assert_signal_emitted(screen, "begin_pressed")


func test_main_opens_on_the_title_screen() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	assert_not_null(main.current_screen(), "Main shows a screen on boot")
	assert_true(main.current_screen().has_signal("begin_pressed"), "that screen is the title")


func test_main_swaps_screens_on_begin() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	var title: Node = main.current_screen()
	main.show_screen(main.FIRST_PLAY_SCREEN)
	await get_tree().process_frame
	assert_ne(main.current_screen(), title, "the screen changed")
	assert_false(is_instance_valid(title), "the screen it replaced was freed, not orphaned")


func test_main_refuses_a_missing_scene_without_losing_the_current_one() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	var before: Node = main.current_screen()
	assert_null(main.show_screen("res://scenes/ui/NoSuchScreen.tscn"))
	assert_eq(main.current_screen(), before, "a bad path leaves the player where they were")


func test_main_refuses_a_resource_that_is_not_a_scene() -> void:
	# A material loads fine and is not a PackedScene. Without the cast guard
	# this reached instantiate() and took the whole screen down.
	var main: Node = add_child_autofree(MAIN.instantiate())
	var before: Node = main.current_screen()
	assert_null(main.show_screen("res://assets/materials/plaster_ochre.tres"))
	assert_eq(main.current_screen(), before, "a non-scene resource changes nothing")
