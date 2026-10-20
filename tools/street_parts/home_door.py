"""Act 5: the way Home, *Step into the water* at the basin's edge (GDD §3 Act 5).

A Door (scenes/places/Door.tscn) to the place `home`, spawn `bank`, offered
only once `remembered` is set: the `requires` on its Interactable, data on the
node. It stands on the south-east corner step beside the Remembrance point.
The lip is 0.6 m above the pavement and the climb out is the only way over it
(docs/DECISIONS.md "The fountain"), so a door on the basin floor could not be
reached; and where the hum was held is where the water is stepped into.
Before `remembered` only *Hum here* is offered on that step; after it, only
this.
"""

from scenegen import xf

STEP_Y = -0.15
CORNER = (5.55, STEP_Y, 5.55)


def build(b) -> None:
    b.door("HomeDoor", "Fountain", "home", "bank", "verb.step_in", CORNER, size=(3.0, 2.4, 3.0))
    b.nodes.append(
        '[node name="Use" parent="Fountain/HomeDoor" index="0"]\n'
        'requires = PackedStringArray("remembered")\n\n'
    )
