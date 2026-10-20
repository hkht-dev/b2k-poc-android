## The people are not one person reskinned.
##
## Owner review 2026-10-20: "I hope for everybody who knew not use the same
## kind of characters." Every human in the game was Kenney's one
## `characterMedium` body at 1.75 m with a different texture painted on, so
## the whole street shared a silhouette. The named characters — the ones the
## player stands in front of and talks to — now carry their own body, their
## own skin and their own height (Quaternius' Universal Base Characters, CC0,
## docs/RIGHTS_REGISTER.md), on the same universal rig as the walk clips.
##
## PLACEHOLDER, like everything else about the bodies: GDD §10 replaces all
## of them with the painted characters.
extends GutTest

const NAMED := {
	"Madhuri": "res://scenes/npc/Madhuri.tscn",
	"Vasanti": "res://scenes/npc/Vasanti.tscn",
	"Dhanpal": "res://scenes/npc/Dhanpal.tscn",
	"Gopal": "res://scenes/npc/Gopal.tscn",
	"Sarang": "res://scenes/npc/Sarang.tscn",
	"CountingMan": "res://scenes/npc/CountingMan.tscn",
}
## Two people of the same height read as the same person at a distance.
const HEIGHT_APART := 0.02


func _figure(path: String) -> Node3D:
	var person: Node3D = add_child_autofree((load(path) as PackedScene).instantiate())
	return person.get_node("%Figure")


func test_each_named_character_has_their_own_body_skin_and_height() -> void:
	var looks: Array[String] = []
	var heights: Array[float] = []
	for who: String in NAMED:
		var figure: Node3D = _figure(NAMED[who])
		assert_not_null(figure.body, "%s has a body" % who)
		assert_not_null(figure.skin, "%s has a skin" % who)
		assert_gt(figure.height, 1.0, "%s stands at a human height" % who)
		assert_not_null(figure.hair, "%s has their own hair" % who)
		looks.append(
			(
				"%s|%s|%s"
				% [
					figure.body.resource_path,
					figure.skin.resource_path,
					figure.hair.resource_path if figure.hair != null else ""
				]
			)
		)
		for other: float in heights:
			assert_gt(
				absf(other - figure.height),
				HEIGHT_APART,
				"%s is not the height of someone else" % who
			)
		heights.append(figure.height)
	var seen: Array[String] = []
	for look: String in looks:
		assert_false(seen.has(look), "no two named characters wear the same body, skin and hair")
		seen.append(look)


func test_the_bodies_are_rigged_and_carry_the_shared_clips() -> void:
	for who: String in NAMED:
		var figure: Node3D = _figure(NAMED[who])
		await wait_frames(2)
		var skeletons: Array[Node] = figure.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, "%s is one rigged body; the hair is a plain mesh" % who)
		assert_gt((skeletons[0] as Skeleton3D).get_bone_count(), 20, "%s has a real skeleton" % who)
		var players: Array[Node] = figure.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, "%s has one animation player" % who)
		assert_gt(
			(players[0] as AnimationPlayer).get_animation_list().size(),
			2,
			"%s walks, idles and runs from the shared library" % who
		)
