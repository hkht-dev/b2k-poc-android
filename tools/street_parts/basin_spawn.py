"""The fountain basin as somewhere to arrive: the spawn point the Veil's fall
ends on.

GDD §3 Act 2 "Falling" ends in the dry fountain, and §3a Act 2 has the
player "climb a rope (hold up): out of the dry fountain into traffic". The
Grove's Dive door (tools/gen_grove.py) leads into the Veil ("veil_down",
built apart), whose end names this spawn; the player lands exactly where a
fresh journey starts them, facing north, so the climb out is the same
either way.
"""


def build(b) -> None:
    b.spawn("SpawnBasin", "Fountain", "fountain_basin", (2.4, -0.4, 2.0), 0.0)
