"""Act 5: the way Home, *Step into the water* at the basin's edge (GDD §3 Act 5).

A Door (scenes/places/Door.tscn) offered only once `remembered` is set: the
`requires` on its Interactable, data on the node. It stands on the south-east
corner step beside the Remembrance point. The lip is 0.6 m above the pavement
and the climb out is the only way over it (docs/DECISIONS.md "The fountain"),
so a door on the basin floor could not be reached; and where the hum was held
is where the water is stepped into. Before `remembered` only *Hum here* is
offered on that step; after it, only this.

It leads into the ascent, not straight to the bank: GDD §3 Act 5 is "Rising"
and then "Home", and the rise is scenes/places/VeilUp.tscn ("veil_up"), which
hands the player on to `home`/`bank` when the stars have gone by. Until the
owner's second review the door named `home` directly, so the Pool of Worlds
had an entrance going down and none coming up and the whole of Act 5's rise
was unreachable (docs/DECISIONS.md "The loops close").
"""

from scenegen import xf

STEP_Y = -0.15
CORNER = (5.55, STEP_Y, 5.55)
# The passage, and the spawn it hands on to beyond itself (Home's "bank").
PLACE, SPAWN = "veil_up", "bank"


def build(b) -> None:
    b.door("HomeDoor", "Fountain", PLACE, SPAWN, "verb.step_in", CORNER, size=(3.0, 2.4, 3.0))
    b.nodes.append(
        '[node name="Use" parent="Fountain/HomeDoor" index="0"]\n'
        'requires = PackedStringArray("remembered")\n\n'
    )
