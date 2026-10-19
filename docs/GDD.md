Journey Back to Krishna — Game Design Document

Revised 19 October 2026

## 1. Vision and design pillars

Journey Back to Krishna is a 15–20 minute third-person narrative adventure for Android in which the player, a soul (jiva) who once lived in loving relationship with Krishna, chooses independence, forgets, and is gently drawn home. The MVP is one polished chapter, free, with paid chapters to follow if players respond.

**One-line pitch:** You left home to be the hero of your own story. Something keeps calling you back.

**Design pillars** (every feature must serve at least one; any feature that violates one is cut):

- **Enjoyable without belief.** A player who has never heard of Krishna must want to keep playing because the world, characters and choices are good.

- **Meaning emerges from play.** Philosophy arrives through what the player does and sees, never through a compulsory lecture. All explanatory text is optional and skippable.

- **Devotion is never a transaction.** No points for piety, no purchasable grace, no power-ups from Krishna. The ending is earned narratively, not numerically.

- **Krishna is present throughout.** Not only in the final scene: through sound, memory, the example of others, and moments of unexpected help.

- **Honest about what is fiction.** Game scenarios are clearly artistic interpretation; scriptural references are accurate, reviewed and cited.

**What the MVP must prove** (go/no-go for Stage 3 funding):

- 60%+ of first-time testers finish the chapter in one sitting.

- 70%+ can describe the central conflict in their own words without prompting.

- 50%+ say they would play a second chapter; 10%+ say they would pay for it.

- Devotee reviewers approve the philosophical content without a major objection.

**Assumed decisions** (from the earlier concept work; change these if they are wrong): audience is worldwide teens and adults including non-devotees; Android first, PC/browser later; stylized 3D, achievable for a small team; dual objective of outreach plus commercial sustainability; working title *Journey Back to Krishna*, pending trademark and store-name checks.

## 2. The world and its cosmology

The game translates the Gaudiya Vaishnava picture of the soul’s journey into three playable realms. Names below are fictional game names, chosen so that a non-devotee reads them as places, not doctrine. Optional in-game notes connect each to its traditional concept.

| Game realm | Traditional concept it interprets | What it feels like to play | Role in the MVP |
| --- | --- | --- | --- |
| **The Grove** (Vrinda) | The spiritual world; Krishna’s eternal pastimes with His devotees | An eternal rose-gold dusk that never ends. Flowing water, cows, friends, music that never resolves into tension. Small luminous bubbles drift everywhere: each one is a world. Everyone is doing something for someone else. | Act 1 and Act 5. One small environment, reused with a different time of day and a transformed player model. |
| **The Pool of Worlds** | The border between spiritual and material existence; the moment of forgetting. The bubbles are the game’s picture of the innumerable material universes (brahmandas) | A still pond at the Grove’s edge in which the night sky is visible, as if the water held a galaxy. The player dives in; the descent is a fall through stars while the Song loses its instruments one by one. | A short descent sequence, not a full area; reused in reverse for the return. |
| **Hollow Vale** | The material world (samsara); the attempt to be the enjoyer and controller | A riverside neighbourhood of a modern city, any city: a market street, flats with barred windows, a chai stall, a dry public fountain, a rooftop with a billboard tower taller than the buildings, traffic that never stops. Beautiful but subtly wrong: locks everywhere, phones everywhere, people who hold things tightly. The player climbs out of a dry fountain to arrive. The setting is deliberately contemporary so that a player anywhere recognises their own street. | Act 2–4. The one large environment of the MVP, one city block. |

**The world-bubbles.** The clips the team shared show small glass spheres holding a galaxy, floating orbs, and a lake that reflects a nebula. This becomes the game’s single most recognisable image. In the Grove, bubbles drift past constantly; a player can *Look* at one and see a tiny world turning inside it. Kuvera holds one up at the whisper. The Pool is where they all come from and go back to. In Hollow Vale no bubbles exist, except once: at beat 12 a single bubble drifts past the tower and the player, if they *Look*, sees the Grove inside it.

**The central metaphor: the Song.** In the Grove, a melody is always playing; it belongs to Krishna’s flute and every creature can hear it. In Hollow Vale the melody is gone, but fragments survive: a hummed tune, a broken instrument, a child who sings without knowing why. The player’s journey is the gradual re-hearing of the Song. This gives the philosophy a form that can be *played*: you follow sound, not instructions.

**How the jiva is shown.** In the Grove the player is young, barefoot and simply dressed, with a soft inner glow (emissive rim), a flower in their hair or at their neck, and bright, open eyes. On surfacing in Hollow Vale the body becomes an ordinary traveler: heavier, coated, with the glow gone and the eyes dulled. Returning in Act 5, the glow and the flower come back. The clips use both a girl with a braid and a boy with a scarf as the soul; the player picks one of two Grove looks at the start (appearance only, no gameplay difference), so that every player can see themselves walking toward Krishna. Section 4 carries the cost.

**How Krishna is shown.** Krishna is met directly only in Act 1 (at a distance, playing the flute under a tree with cows at the pink sunset) and Act 5 (the embrace). In Hollow Vale He is never met, but He is *glimpsed*: sitting on a rooftop, standing on the tower’s unreachable upper beam, leaning in a doorway, always far, always gone by the time the player arrives, and never noticed by any villager. The clips show this exactly: Krishna on a lamp post above a city street, on a parapet at sunset, in a corridor that nobody looks down. The game calls this system *Glimpses* (section 6). He is present throughout, as the brief requires, but He is never a quest-giver, a shop or a boss, and the player can never walk up to Him before the end.

**What the game deliberately leaves out.** Karma as a visible score, reincarnation as a game mechanic, hell realms, demigods as powers, and any depiction of Radha or Krishna’s intimate pastimes. These are either outside the MVP’s scope or inappropriate to gamify. The reviewers’ list in section 15 governs additions.

**Honesty note shown once on first launch (skippable):** “This story is an artistic interpretation inspired by the Bhagavad-gita and the Vaishnava tradition. Optional notes marked with a lotus explain what is traditional teaching and what is game fiction.”

## 2a. The season: three worlds and the direct path

The full game is a season of four chapters shaped on the Bhagavatam’s picture of the material creation as lower, middle and upper worlds, with the spiritual world beyond all three. The player moves through the worlds by effort, which is real and rewarding and never arrives; and in every chapter the direct way home is open the moment they turn to the water. This is the game’s structural statement of the difference between the gradual path and bhakti (Bhagavad-gita 9.21, 9.25, 8.16), made by play rather than by text.

| Chapter | World | Setting | What it feels like | What the player learns by doing |
| --- | --- | --- | --- | --- |
| 1 · *The Forgotten Song* | The Middle | Hollow Vale, a riverside neighbourhood of a modern city (sections 3–8) | Ordinary life, a little too tight; the Song in fragments; Krishna glimpsed | What they are, by remembering; home by the basin |
| 2 · *The Lower* | The lower worlds | The undercity beneath the Street: metro tunnels where no train comes, markets by lamplight, flats below the river line | Fear and craving; the Song inaudible; Glimpses rare and precious; traversal is climbing out | That the bottom is not hell and is not abandoned; the basin is here too |
| 3 · *The Heights* | The upper worlds | The gilded tower district above the smog: gardens on roofs, music everywhere, every door open | Everything given; rooftop running at its most exhilarating; the music is beautiful and, the player slowly notices, a recording of the Song | That the pleasant is temporary: the hospitality ends, “your account is settled”, and the player wakes on the Street again (Bg 9.21 as an experience) |
| 4 · *Home* | The Grove | The riverbank, the Pool, and a wider Grove than Chapter 1 showed | The embrace, with everything carried from three worlds; friends from the Street arrive | That no one climbs there; one is carried |

**The direct path.** In every chapter the stone basin exists, can be filled, and works. A player can go home from the Lower, from the Heights, from anywhere, by stopping and turning to the water. From the top of the tallest tower in the Heights the Grove is visible above the clouds and cannot be reached by climbing; the only way there is down into the water and up. The game never hides, delays or penalises the direct exit, and a player who takes it in Chapter 2 sees the same embrace as one who climbs through Chapter 3.

**Rules for the three worlds.**

- No visible karma score. The Heights’ credit is narrated by its hosts and never counted; the player’s standing in any world is shown only by how people treat them.

- The Lower is frightening and never hopeless; its people are the same people as the Street’s, worse off. Madhuri has a counterpart there.

- The Heights are good, not a trap to be sneered at. The fall is gentle and sad, not a punishment.

- Each world adds an instrument to the Song, a traversal element (climbing in the Lower, running in the Heights) and a new stray-cow problem.

- The panel reviews each world’s picture against the Fifth Canto before production, and the first-launch note names the three worlds as an artistic reading of that picture.

## 3. The story, beat by beat

The chapter runs about 18 minutes for a first-time player. Timings are targets for the MVP; the full game would expand Acts 3 and 4 into several chapters each.

### Act 1 — The Grove (≈3 min)

- **Waking.** The player (unnamed; the game calls them “you”) wakes on warm grass beside a river in an eternal rose-gold dusk. The Song is playing. A calf nudges them. Bubbles drift past; a *Look* at one shows a tiny world turning inside. Tutorial: move, look, interact.

- **The gathering.** Friends are preparing a feast on the riverbank. Three playful tasks teach the verbs of the game: carry a pot of water to Lalita (carry/interact), coax a wandering calf back with a tune (hold-to-call), and thread a garland of jasmine and rose for someone who is not yet here (simple pattern puzzle; the garland is kept and matters at the end). Each task is for someone else; nobody is keeping score.

- **The glimpse.** From across the river the player sees Krishna at a distance, leaning against a tree, flute raised, cows around Him, the sun low and pink behind. The Song swells. Friends sit with the player on the bank and look up: the dusk sky is full of stars and slow bubbles. The player can approach the water but cannot cross; friends call them back to the feast. This denial is deliberate: the player should want to be nearer.

- **The whisper.** At the feast, Kuvera catches a drifting bubble and holds it up so the player can see a world turning inside: a city, a crowd, a tower. “Everyone here looks at Him. In there, they would look at you.” He lets it go; it drifts to the Pool at the Grove’s edge, where the water holds the night sky.

- **The choice.** The player walks to the Pool. A soft prompt: *Stay* / *Dive*. Choosing *Stay* returns to the feast and the prompt reappears after a short loop (staying is honored twice; the third time a bubble bursts against the player and they fall). Choosing *Dive* enters the Pool. On the bank behind them, unnoticed, Krishna turns and watches them go.

### Act 2 — The Pool of Worlds (≈1.5 min)

- **Falling.** The player sinks through water that becomes stars. The friends’ voices call from the surface, growing faint. With each few seconds the Song loses an instrument. The player’s glow trails off them like ribbons and dissolves into the dark (the clips’ image of a figure unravelling into streamers toward the sun). A single brief text appears: *“**It is easy to leave. Remembering the way back is harder.**”*

- **Surfacing.** Darkness, then a circle of grey daylight above and the noise of traffic. The player climbs out of the dry basin of a public fountain into a city street at rush hour, in an ordinary coat, with a face and no glow. Nobody looks at them. They cannot remember the Grove; the player does, which creates the dramatic irony that drives the chapter. The fountain is dry because the world is.

### Act 3 — Hollow Vale (≈9 min)

- **Arrival.** The street is Hollow Vale, a riverside neighbourhood: market stalls, flats, a chai stall, and above everything a billboard tower on the tallest roof. Everyone is busy, everyone is on a phone. A boy, Tulu, is humming three notes of the Song at the fountain’s edge. The player can follow him or ignore him.

- **The Forgotten Song (main quest).** The local landlord, Dhanpal, owns the billboard tower and announces a contest: an old instrument, the Veena of the Vale, found when the shrine room behind the chai stall was opened, will be played from the top of his tower at dawn by whoever gets there first, livestreamed to the whole city with their name on the billboard. Four neighbours are competing and sabotaging each other. The player is invited to compete. The quest branches:

- *Compete:* the player gathers advantages (the roof access key, a bribe, a shortcut through the back stairs) through small quests that each ask them to take from someone.

- *Mediate:* the player talks to the competitors, learns what each actually wants (respect, a sick child, a lost brother, to be left alone) and finds solutions that do not need the tower.

- *Investigate:* the player follows Tulu to the shrine room and learns from its old photographs and from the keeper, Madhuri, that the instrument was never meant to be won; it was played *for* the street every dawn from the fountain steps, before the tower. All three paths are playable to the end; they change what the player sees, who trusts them and what the ending feels like. None is a dead end.

- **Side encounters** (optional; see section 7): a shopkeeper hoarding water during a shortage; a woman fencing the community garden; a man at the bus stop who cannot stop counting.

- **The dawn climb.** Whatever path was taken, the player ends up on the roof at dawn with the Veena in reach and the whole city below. If they competed, they won it. If they mediated, the others yield it. If they investigated, Madhuri sends them up. This is the chapter’s second real choice:

- *Play it for the street* (the instrument is held outward toward the waking city).

- *Keep it* (the instrument is held close; the player descends with it). Both are allowed. The game does not punish *Keep*; it shows its consequence.

### Act 4 — Remembrance (≈3 min)

- **The melody.** If the player plays for the village: the Veena’s melody is the Song. The valley stops; the tense music resolves; Tulu finishes his three notes. A single bubble drifts past the tower; inside it, for a moment, the Grove. The player’s memory flashes: the river, the calf, the flute across the water. Madhuri, below, is heard chanting softly (the maha-mantra, low in the mix). For the first time the player’s eyes brighten. If the player keeps it: they descend and sit alone with the Veena at the overlook; no one is watching. They try to play it and the three notes come out on their own. The flash happens anyway, smaller. Madhuri finds them and says nothing, only sits.

- **The teaching moment (optional).** Madhuri offers one verse (Bhagavad-gita 18.66 by default; section 9 lists alternates). The player can listen, read more, or simply ask “Where does the Song come from?” Madhuri: “You already know. You’ve been humming it since you climbed out of that well.”

- **The service and the reflection.** Madhuri asks for one small thing: carry water to the shrine’s lamp so it will burn through the night. It is the same verb as carrying the pot in Act 1. As the player sets the water down, the lamp flares, and the stone basin beside it fills and goes still. The player leans over it and sees their reflection: not the traveler’s face but the Grove face, glowing, flower at the neck. The Song returns in full. The basin holds the night sky.

### Act 5 — Home (≈1.5 min)

- **Rising.** The player steps into the basin and rises through stars toward a rose-gold light; with each few seconds an instrument returns. The coat unravels into ribbons and falls away; the glow returns; the garland from beat 2 is in their hands.

- **The embrace.** The player breaks the surface of the Pool and wades to the bank. Friends, the calf, the feast still laid; nobody has aged a moment. Krishna is no longer across the river. He walks the distance and stops. He bows His head. The player places the garland from Act 1 around His neck (one tap; the only interaction in the scene). Then He embraces them. The player weeps; He does not let go. No dialogue. The Song, complete. Hold on this for a full ten seconds before any UI returns. Final shot: an overhead view of the two lying in the grass, the friends’ circle widening around them.

- **The invitation.** A single screen: *“**The journey back begins again wherever you are.**”* Below it: Play again · Learn more · Chapter 2 (coming). Credits scroll over the overhead shot as the dusk deepens and the bubbles rise.

### Narrative rules the writers must keep

- The player is never told they were wrong to leave. The leaving is the premise, not the sin.

- Krishna never speaks in Hollow Vale. His help arrives as circumstance, song, and other people.

- No character is a villain. Dhanpal is proud, not evil; Kuvera is a tempter only in the sense of voicing a desire the player already has.

- Every important moment is repeated in a transformed way (carrying water, the three notes, the far bank). Recognition, not explanation, carries the meaning.

## 3a. What the player actually does, scene by scene

The story in section 3 is what the player sees. This is what their hands do, what it is in the fiction, and what it means. The whole game is ten verbs: carry, listen, hum, run, guide, notice, sit, choose, plant and pull, and once, garland.

### Act 1 — the Grove (3 min)

| What the hands do | What it is in the story | What it means |
| --- | --- | --- |
| Tilt the stick, drag to look, tap the calf | Wake by the river; the calf nudges you | Learning to move in a world where nothing threatens you |
| Hold the button: the character hums | The calf and birds come | Your voice is heard here; remember this |
| Pick up a pot, walk it to Lalita, place it | Water for the feast | Carrying for someone else is the main verb; it returns at the end |
| Hum a short pattern to match the calf’s wandering | Coax the calf home | First touch of the rhythm skill |
| Tap flowers in order, matching a pattern | Thread a garland for someone not yet here | Making something for Him before knowing Him; it is kept |
| Tap a drifting bubble: *Look* | A tiny world turning inside | Curiosity about the material worlds, planted gently |
| Walk to the bank, try to cross | Krishna across the water with the flute and cows | Desire to be nearer; the refusal makes the wanting |
| Sit; choose “It doesn’t matter” or “no one” | Kuvera: “Who was looking at you?” | The first weed: the wish to be seen |
| Walk to the Pool; tap *Dive* (or *Stay*, twice) | Leaving | The one choice the whole game turns on |

### Act 2 — the Pool (90 s)

| What the hands do | What it is | What it means |
| --- | --- | --- |
| Nothing but tilting the view | Falling through stars; the Song losing instruments; the glow unravelling | Forgetting, watched from inside |
| Climb a rope (hold up) | Out of the dry fountain into traffic | Birth into a world that does not look up |

### Act 3 — the Street (9 min, the core play)

| What the hands do | What it is | What it means |
| --- | --- | --- |
| Walk the street; tap *Listen* on Tulu | A boy humming three notes | Following sound instead of instructions; the first watering |
| Talk to Dhanpal; pick a card | The contest for the billboard tower | The world’s offer: be seen by everyone |
| Choose an approach by what you do next, never by menu: take a key, talk to two rivals, or follow Tulu | Compete, mediate, investigate | How you pursue what you want is who you are |
| Pick up a water can; carry it to the fountain, or keep it | *The Dry Fountain* | Taking plants a bitter seed, giving a sweet one; neither is seen yet |
| Talk, choose, carry fruit, find the thief | *The Fence* | Trust against locks |
| Tap coins in a 30-second count, or sit | *The Counting Man* | A stuck person can still hear the Song |
| Hold to sprint; time jumps at ledges and cables | Rooftop running to where Krishna was glimpsed | Skill and attention rewarded with closeness, never with power |
| Walk ahead of two cows and hum to steer them through traffic | *Stray cows* | Care for what nobody else sees |
| Tap *Look* at a window, a clock, a puddle | Tells | Noticing the dream |
| Sit with Madhuri; tap to turn a painted scroll | Puranjana, in three sittings | Hearing: what cuts knots, felt as story |
| Carry a can into the shrine room; set it by the lamp | Service asked with no reward | The Act 1 verb, repeated where it costs |
| Climb the tower at dawn: ladder, four landings | The roof | Effort, real and enjoyable |
| Hold, slide and release on the Veena’s strings | Play the Song | The chapter’s skill test: beauty, not points |
| Tap *Play it for the street* or *Take it and go* | The dawn choice | What the instrument is for |

### Act 4 — Remembrance (3 min)

| What the hands do | What it is | What it means |
| --- | --- | --- |
| Hold the hum while the street listens, or sit alone with it | The melody is the Song; a bubble passes; the eyes brighten | Remembering; the first pink in the sky |
| Tap the lotus, read, or ask Madhuri | Gita 18.66, optional | Knowledge offered after the feeling |
| Carry water to the lamp; place it; lean over the basin | The Grove face in the reflection; Madhuri gives a seed | Grace: the creeper’s seed cannot be earned |

### Act 5 — Home (90 s)

| What the hands do | What it is | What it means |
| --- | --- | --- |
| Step into the basin; watch | Rising through stars; instruments returning; the coat falling away | Carried, not climbing |
| Wade to the bank; one tap: the garland | Krishna bows; you garland Him; He embraces you | What was made in the first three minutes was for Him |

### After the chapter: a typical ten-minute day in the living world

- Open the game in the Grove; walk to the plot; see what sprouted from yesterday’s choices, each with its sentence.

- Pull a weed (tap and hold); water the creeper by sitting with a friend for a three-minute tale or humming with the calf.

- Taste a ripe fruit: a vignette waits in the Street.

- Enter the Street: today’s dawn vignette (a stranger’s problem, or a witness tale beside Prahlada or Dhruva), one cow route, one rooftop run; a companion may drop in to hum a chord together.

- Set down a lamp; sit at someone else’s; leave.

- On festival days the whole Grove is shared and everyone plays one part of the Song.

## 4. Characters

Twelve characters for the MVP: one player, one Krishna, two Grove friends, one guide, one elder, four competitors, two optional encounters. Names are fictional except Krishna; avoid names of scriptural figures so that no game character is mistaken for a scriptural one.

| Character | Role | Want (surface) | Need (true) | Voice and look | Art cost |
| --- | --- | --- | --- | --- | --- |
| **The player (the jiva)** | Protagonist, silent | To be seen | To belong | Grove form: luminous, slender, androgynous, no face detail. Traveler form: ordinary, warm skin tones, brown coat, satchel. Two models, shared rig. | Custom, both forms |
| **Krishna** | The destination | — | — | Seen at distance (Act 1) and close (Act 5). Dark-blue skin, yellow cloth, peacock feather, flute. Never stylized as cute or as a superhero. Animation: walking, raising flute, embrace. | Custom, highest priority |
| **Lalita** | Grove friend, tutorial giver | The feast ready | Everyone fed | Bright, bossy, laughing. Gives the water-carrying task. | Licensed base + custom head |
| **Kuvera** | Grove friend, the whisper | Admired | Admired | Handsome, slightly apart from the group. Voices the desire to be the center. Not a demon; a mirror. | Licensed base + custom head |
| **Tulu** | Child in Hollow Vale, the thread | To find who taught him the tune | To hear it whole | Eight years old, barefoot, hums three notes. Follows the player if ignored. | Licensed child model |
| **Madhuri** | Keeper of the shrine; the devotee | To keep the lamp lit | For someone to play the Veena for the valley | Old, calm, unhurried, often chanting under her breath. Never preaches unless asked. The only character who treats the player as already known. | Licensed base + custom clothing |
| **Dhanpal** | Village elder, master of the tower | The contest to succeed | To be respected without the tower | Broad, loud, decent underneath. Built the tower to be seen from the next valley. | Licensed base |
| **Rukma** | Competitor: the climber | To win | To be told she is enough | Athletic, dismissive, sabotages the rope. Mediation: hears that nobody needs her to win. | Licensed base |
| **Bhima Lal** | Competitor: the strong one | To win for his sick daughter | Medicine, which the merchant has | Gentle giant. Mediation route connects him to the merchant quest. | Licensed base |
| **Sarang** | Competitor: the musician | To play the Veena | To hear it played at all | Thin, nervous, the only one who cares about the music. Investigation route: he knows the melody’s first bar. | Licensed base |
| **Old Nanda** | Competitor: the recluse | To be left alone | To belong again (lost his brother on the tower years ago) | Lives at the valley’s edge. Reveals the tower’s history. | Licensed base |
| **The merchant (Gopal Seth)** | Optional encounter | To hoard water | To stop being afraid | Jovial, hoards. Side quest *The Full Well*. | Licensed base |
| **Vasanti** | Optional encounter | To fence the fruit tree | To trust again | Side quest *The Fence*. | Licensed base |

**Grove form options (added from the reference clips).** The clips cast the soul as a bright-eyed young person: a girl with a jasmine braid and a bindi, a boy with a loose scarf and a curious face. The MVP offers both as the player’s Grove look, chosen on the first screen, with the traveler form derived from each (same rig, a different head and coat). This adds one head and one coat to the art list, not a new character. Krishna’s two friends at the feast use the same two heads so the Grove reads as a company of children.

**Casting rule for Krishna.** His model, animation and the Act 5 embrace are reviewed by the devotee panel at blockout, at first animation pass and at final. Reference: traditional Vrindavan iconography, not film or comic depictions. No slow-motion hero shots; the embrace is tender and unhurried.

**Voice.** The MVP ships with text dialogue and emotive vocal gestures (hums, laughs, a sigh) rather than full voice acting, to keep localization cheap. Madhuri’s chanting and Tulu’s three notes are recorded by real voices. Full voice acting is a Stage 3 decision.

## 5. Environments and locations

The MVP has two built environments and one corridor. Everything else is a camera, a lighting change or a cinematic. Target: no more than 20 unique environment assets beyond licensed packs.

| Location | Size | Used in | Key landmarks and interactions | Lighting and mood |
| --- | --- | --- | --- | --- |
| **The Grove riverbank** | ≈80 × 60 m playable | Act 1, Act 5, end credits | River with far bank (unreachable), feast clearing, calf meadow, flower garden, kadamba tree with a swing, the tree Krishna leans on across the water, the Pool at the Grove’s edge, drifting bubbles. | Eternal rose-gold dusk: a low pink sun, long warm shadows, a sky with visible stars. Act 5: the same, slightly warmer. Credits: the dusk deepens, lamps lit. |
| **The Pool of Worlds** | A 12 m pond plus a 90-second descent sequence | Act 2 (down), Act 5 (up) | Still water that reflects a galaxy instead of the sky; the dive; a fall through stars with bubbles passing; no interactions, no steering. | Descent: colour drains to blue-black, the glow unravels. Ascent: the same path reversed, warming to rose-gold. One particle system, two directions. |
| **Hollow Vale** (one city block) | ≈200 × 150 m playable: one market street, a riverside walk, two alleys, four enterable interiors | Act 3, Act 4 | The dry fountain (the player’s arrival point), the billboard tower on Dhanpal’s roof (reachable by stairs and a ladder, 4 landings; a top beam no one can reach), the shrine room behind Madhuri’s chai stall (old photographs, a lamp, a stone basin), Dhanpal’s office, Nanda’s flat at the end of the alley, the community garden, Sarang’s corner with a broken instrument, the riverside overlook, three rooftops, one traffic light and one doorway reserved for Glimpses. Traffic and crowds are looping background, not simulated. | Arrival: overcast midday, flat, no pink anywhere, sodium-orange street lamps. Shifts toward dusk as quests complete. Dawn climb: cold blue to warm over the river. Act 4: dusk, lamplit, the first rose tint allowed into the sky. |
| **Rooftop** | Single platform under the billboard | Beat 11 | The Veena on its stand, the whole city below, the river and far hills where the Grove would be, the top beam above where Krishna has been glimpsed. | Dawn, wind, the only place in the block with open sky. |

**Hollow Vale layout principles.**

- The billboard tower is visible from everywhere and the player naturally orients toward it; the shrine room is tucked behind the chai stall, found by following Tulu or Sarang’s music.

- Locks, grilles, CCTV cameras and phones appear in every household and shop; nothing in the Grove had a lock.

- The fountain is at the centre and dry; the shop beside it is full of water cans. This is the first thing a curious player will notice.

- The city is any city: signage is in an invented script, vehicles and clothes are generic, so a player in Bengaluru, São Paulo or Manchester reads it as home. Licensed stylized-city packs cover buildings, props and vehicles; traffic and crowds are looping ambience, never simulated.

- Sound design carries the player: each competitor has a motif, Tulu’s three notes play when he is near, and the shrine room leaks a faint drone of Madhuri’s chanting under the traffic.

**Reuse plan.** The Grove is built once and relit for Act 5 and credits. The Veil is one corridor with two lighting profiles. Hollow Vale uses a licensed village pack for buildings and props; custom work is limited to the tower, the shrine interior, the Veena, and the fruit tree.

**Environment art targets (mobile).** Under 150k triangles on screen, 2048 texture atlases, baked lighting with one real-time directional light, no real-time shadows on mid-range devices. Grass and petals as GPU-instanced billboards.

## 6. Core gameplay systems

The player does five things: move, interact, carry, call, and choose. There is no combat, no inventory screen, no stats. Progress is story progress.

### Movement and camera

- Left-thumb virtual joystick; right-thumb drag to orbit the camera; auto-run after 0.5 s of full tilt.

- Context-sensitive climb: approach a ledge or ladder and the character climbs; no jump button.

- Camera is a soft-follow third person at 3.5 m; cinematic moments take control with a brief letterbox.

### Interaction

- One contextual button appears when near something usable: *Talk*, *Pick up*, *Place*, *Look*, *Listen*.

- *Listen* is unique to this game: near a sound source (Tulu, the shrine, the Veena, a carving) the button plays the sound and the camera drifts toward its origin. The player learns to follow sound.

### Carry

- The player can hold one object (pot, rope, fruit, water skin, the Veena). Carrying slows movement slightly and changes the idle animation.

- Carrying something *to* someone is the game’s most repeated verb. Act 1, every side quest and Act 4 all end in a carry-and-place.

### Call

- Hold the interact button with nothing nearby: the character hums. In the Grove the calf and birds respond. In Hollow Vale nothing responds at first; after beat 12, Tulu answers with his three notes from wherever he is. A small, non-essential system that makes the world feel alive and rewards the player for remembering.

### Choice

- Two or three options, full sentences, shown as cards. No timer. No option is labeled good or bad, and no icon hints at a correct answer.

- Choices change: who speaks to the player, which doors are open, the weather, and the Act 4 variant. They never change a hidden score.

- Every choice can be read back in the pause menu under *Your journey* as plain narrative (“You helped Bhima Lal find medicine”), so the player sees their path as a story, not a tally.

### Remembering Krishna (the narrative system)

Not a meter. A set of flagged moments the game tracks silently to shape presentation:

| Trigger | What the game records | What changes |
| --- | --- | --- |
| Player uses *Listen* on Tulu | heard_tulu | Tulu’s notes become audible in more places |
| Player resolves any encounter without taking | gave_[quest] | That character appears at the dawn climb, watching |
| Player visits the shrine before the climb | saw_shrine | Madhuri’s Act 4 lines reference what the player read |
| Player chooses *Play it for the village* | played_for_others | Full Act 4 variant; the valley resolves |
| Player chooses *Keep it* | kept_veena | Quiet Act 4 variant; Madhuri sits with them |
| Player hums (Call) in Hollow Vale at least three times | hummed | Memory flash in beat 12 is longer |

The flags change texture, not access. A player who takes everything and keeps the Veena still reaches the embrace. This is the game’s statement that grace is not earned by score, and it must survive every design review.

### Glimpses (Krishna hidden in plain sight)

The reference clips place Krishna inside the ordinary world without anyone noticing: on a lamp post over traffic, on a parapet at sunset, in a corridor as a guard walks past. The game does the same in Hollow Vale.

- Five fixed Glimpse points: the top beam of the billboard tower, the traffic light at the crossing, the doorway of Nanda’s stairwell, the far end of the community garden, and the roof of the chai stall. At each, under a condition, Krishna’s silhouette (flute, feather, yellow cloth) is visible for 4–6 seconds, always far, always backlit; once, two cows cross the street behind Him and no car slows.

- Conditions are tied to the player’s state, never to a timer: after the first *give* choice; after using *Listen* on Tulu; on first visiting the overlook; after refusing to take the roof key; at dawn before the climb.

- Approaching a Glimpse point ends it: by the time the player arrives, the spot is empty, and a single peacock feather or a jasmine flower lies there. The player can pick it up (carry) and nothing happens; it is simply the proof that He was here.

- No one on the street ever reacts to a Glimpse. Tulu is the exception: once, he looks up at the traffic light at the same moment as the player and smiles.

- Glimpses are never counted, never rewarded and never required. The *Your journey* page records them only as “You thought you saw someone on the traffic light.”

- Rule for the panel: a Glimpse is always Krishna watching with affection, never Krishna testing, judging or hiding on purpose. The look on His face, when it is visible at all, is the one in the clips: amused and kind.

### Tells (small wrongnesses only the player can notice)

The Street is a dream the player has forgotten; the game lets it show. A Tell is a tiny, silent wrongness: a shop window that reflects the player’s Grove glow for a second; a clock that stops while the hum is held right; a cow standing in a shoe shop; a bubble world in a puddle; a poster whose figure has a peacock feather if you look twice. Tells are never explained, never counted toward anything, and never acknowledged by anyone but Tulu. They go into the *Noticed* list with the sentence they were seen in. Forty in Chapter 1, placed where a player who looks around is rewarded for it. The kinship with the “glitch” of films like The Matrix is structural only: nothing is referenced, quoted or imitated, and the tone is affectionate, not paranoid; the world is not a prison but a place the player chose, watched over by someone who wants them back.

### The Garden: seeds, fruit and the creeper (the game’s picture of karma and bhakti)

The game does not show karma as points. It shows it as a garden, following the Caitanya-caritamrita’s image of the bhakti-lata-bija (Madhya 19.151 onward) joined to the Gita’s teaching that pious and impious fruit both bind. Each player has a plot in the Grove. It is the only place the garden is ever seen: never on the HUD, never during play, never as a number.

- **Seeds.** Every desire voiced and every choice made in the Street drops a seed into the plot, with the sentence it came from. Taking, pride and holding plant bitter seeds; giving, patience and help plant sweet ones. Seeds look alike at first.

- **Saplings.** They grow over real days. Repeating the same kind of choice feeds the same sapling: a habit is a thicker trunk.

- **Fruit.** When a sapling fruits, a vignette arrives in the Street: sweet fruit as a gift, a stranger’s kindness, an easy day; bitter fruit as a loss, a locked door, a hard day. Fruit must be tasted; the vignette cannot be skipped. Tasting clears the fruit and almost always plants a new seed, because enjoyment wants more and suffering wants revenge. This is how the garden teaches, without a word, that both kinds of fruit bind.

- **Weeds.** Desires that look like devotion (to be seen, to profit, to be free of trouble) sprout beside the creeper, after the text’s unwanted creepers. Kuvera’s whisper is the first weed. The player pulls them by hand; left alone they wrap the creeper and stop it.

- **The creeper.** Its seed is given, never found, earned or bought: Madhuri gives it with the lamp water (beat 14). It is watered by hearing (sitting for a tale), chanting (humming or playing the Song; Madhuri’s maha-mantra heard in the shrine), remembering (Listen, Glimpses, Tells) and service (carrying for others). It climbs the garden wall slowly, and as it rises it shades the saplings, which stop fruiting and wither. Past the wall it climbs out of sight toward the Grove’s great tree. The panel approves the wording for what the creeper does to the saplings (the sources: the creeper climbs beyond the material worlds; bhakti burns karma, SB 11.14.19).

- **The next life.** At each chapter’s end the garden shows itself and the player wakes where the fruit has taken them: the Lower, the Street again, or the Heights. The player never chooses a life; they choose what they plant and what they pull. If the creeper has cleared the wall, the player may go home instead, from anywhere. The basin stays open regardless: grace does not wait for the garden (Gajendra, Ajamila).

- **Roots.** Every repetition of the same kind of choice deepens that sapling’s roots. Shallow saplings wither as soon as the creeper shades them; deep-rooted ones do not: their knots must be cut, and only hearing and knowledge cut knots. Each sitting for a tale or a verse loosens one knot on one deep root, so a desire fed twenty times needs many sittings. Slowness is the point.

- **Regrowth.** An uprooted desire can return: tasting its fruit, or repeating the choice, replants the seed. The garden keeps the old root scar visible, so the player knows what to be careful of.

- **Neglect.** If the player keeps feeding saplings and stops watering the creeper, the roots wrap it and pull it down, and the creeper is lost. Madhuri gives the seed again, without reproach, and it starts from the seed stage. Garden time passes only on days the player plays, so the garden can never punish absence, only choices.

**Rules.** No numbers, no bars, no comparisons between players (Circles may visit each other’s gardens, never rank them). No purchase touches the garden. Nothing dies if the player stays away. The embrace never depends on the creeper’s height. The first-launch note says the garden is a picture of the tradition’s teaching, not a measure of anyone’s soul.

**Why this and not a meter.** A number turns action into transaction and reveals the designer’s verdict; a garden shows consequence as growth over real days, which is how karma feels, and it carries the one truth no morality meter has ever shown: the sweet fruit also roots you.

### Quests

- One main quest (The Forgotten Song) with three approaches; three side quests; six micro-interactions. All are listed in section 7.

- No quest log with checkboxes. A single line at the top of the pause menu says what the player is doing now, in the character’s voice (“Dawn is coming. The tower is waiting.”).

- Quests are data (section 12): a designer edits a text file, not code.

### Optional wisdom

- After specific beats a lotus icon pulses at the screen edge for 8 seconds. Tapping opens a card: one verse, a two-sentence plain-language meaning, and *Read more* (opens a longer note in-app, offline). Ignoring it has no effect. Section 9 lists every card.

### What is deliberately absent

Combat, death, fail states, timers, currency, experience points, crafting, a map with markers, daily rewards, push notifications. Each was considered and cut because it would turn the journey into a chore or the philosophy into a score.

## 7. Complete quest design

### Main quest: The Forgotten Song

**Giver:** Dhanpal, at the hall, on arrival. **Goal shown to player:** “Be on the tower at dawn.” **Real goal:** decide what the Veena is for.

| Approach | How it starts | Steps | What the player learns | Dawn outcome |
| --- | --- | --- | --- | --- |
| **Compete** | Accept Dhanpal’s invitation | 1. Get Rukma’s roof key (take it from her bag while she sleeps at the bus stop, or trade the shopkeeper’s water for it). 2. Learn the back-stairs shortcut from Nanda (he tells you if you let him talk; or find it yourself). 3. Climb first. | Each advantage is taken from someone. The street gets darker and more barred as you progress. | You arrive first. The others watch from the pavement. |
| **Mediate** | Talk to any two competitors before accepting | 1. Rukma: ask why she needs to win; carry her message to Dhanpal (she wants to be named manager of the building). 2. Bhima Lal: get medicine from the shopkeeper (links to *The Dry Fountain*). 3. Sarang: bring him the broken instrument’s missing string (found at Nanda’s flat). 4. Nanda: sit and listen; he tells you about his brother. | What each one needed had nothing to do with the tower. | The competitors stand aside and ask you to go up. |
| **Investigate** | Use *Listen* on Tulu and follow him | 1. Reach the shrine room behind the chai stall. 2. Look at three old photographs (a crowd at the fountain at dawn; the tower being built; a lamp kept lit). 3. Meet Madhuri; carry water for the lamp (first time). 4. Sarang teaches you the first bar. | The Veena was played *for* the street every dawn from the fountain steps until the tower was built. | Madhuri sends you up before the others wake. |

Approaches can mix: a player who starts competing can switch to mediating after one taken item, and the valley lightens again. The flags, not a path variable, determine the result.

### Side quests

**The Dry Fountain** — *Giver:* the dry fountain itself (interact). *Situation:* during a water shortage Gopal Seth has carried every can of water into his shop because he fears it will run out. The street is thirsty and the fountain is dry. *Options:* (a) take a can for yourself; (b) talk until he admits what he fears, then carry one can to the fountain with him; (c) ignore. *Outcome of (b):* the fountain runs during the night; Bhima Lal’s daughter can be treated; Gopal stands on the pavement at the dawn climb. *Length:* 2 min.

**The Fence** — *Giver:* Vasanti, padlocking the community garden gate. *Situation:* she is fencing the garden that everyone picks from because someone took more than their share. *Options:* (a) help her fix the fence (she gives you fruit); (b) find who took the fruit (Tulu; he was hungry and gave it to Nanda) and tell her; (c) pick fruit for her first, then talk. *Outcome of (b) or (c):* she takes the padlock off; the garden stays open; fruit appears at the Act 5 feast. *Length:* 2 min.

**The Counting Man** — *Giver:* a man at the bus stop who cannot stop counting coins. *Situation:* he has lost count and will not board a bus until he knows the total. *Options:* (a) count with him (a 30-second mini-game; the total is 108); (b) give him one coin so the count is round; (c) sit with him until he laughs. *Outcome:* any option frees him; he walks off down the street and later hums one note of the Song. This quest exists to show that the Song can reach anyone. *Length:* 1 min.

### Micro-interactions (no giver, no reward)

- Pet the calf in the Grove: it follows you until the Veil.

- Push the swing on the kadamba tree: Lalita laughs.

- Touch a Hollow Vale fence: a one-line thought (“Nothing in the Grove had a lock.”) appears only if the player has pet the calf, which proves they explored.

- Sit at the dawn overlook before the climb: the far hills are shaped like the Grove’s treeline.

- Read Nanda’s brother’s name carved on the tower’s second landing.

- Hum near the shrine: Madhuri’s chant rises to meet the note.

### Quest data fields (for the quest file)

id, giver, start_condition, steps[] (each: id, objective_text, complete_when, flags_set), branches[], end_condition, flags_set_on_end, journey_line (the plain-narrative sentence shown in *Your journey*). Dialogue is in a separate file keyed by line_id; a quest step references lines, never contains them.

## 8. Key scene scripts and sample dialogue

Six scenes carry the chapter’s meaning. These are first drafts for the writer and the review panel; the tone to keep is plain, warm, and short. Nobody explains the philosophy; they talk about water, rope and songs.

### Scene A — The whisper (Act 1, beat 4)

*The feast. Laughter. Across the river, the flute. Kuvera sits beside the player, looking at the far bank.*

**Kuvera:** Look at them. Every eye on Him. *(beat)* **Kuvera:** You carried the water. You brought the calf home. Who was looking at you? *(The player can answer:** **“**It doesn’t matter.**”** **/** **“**…no one.**”** **Either way:)* **Kuvera:** There’s a place where it would matter. *(He nods at the mist.)* I’ve never gone. But the path is always there.

### Scene B — The Veil (Act 2, beat 6)

*Sinking. Water becomes stars. The Song loses the flute, then the drums, then the voices. The player’s glow pulls off them in ribbons and dissolves upward. Text, white on dark, one line at a time:*

It is easy to leave. Remembering the way back is harder. But it is never closed.

### Scene C — Dhanpal’s contest (Act 3, beat 9)

**Dhanpal:** Traveler! You’ve come on the right day. Tomorrow at dawn, the first to reach the top of my tower plays the Veena of the Valley, and the whole valley hears it and knows their name. **Player:** *(cards)* “What’s a Veena?” / “Why does the name matter?” / “Count me in.” — *“**Why does the name matter?**”* **Dhanpal:** *(laughs, then doesn’t)* Because it’s the only thing that lasts up here. Ask old Nanda. Or don’t; he’ll only talk about his brother.

### Scene D — Madhuri at the shrine (Act 3, investigate route)

*A small room, one lamp nearly out, carvings on the walls. Madhuri is refilling the lamp from an empty jar. She does not turn around.*

**Madhuri:** You’re the one he’s been following. **Player:** “Tulu?” **Madhuri:** He hums it at everyone. Most people hear noise. *(turns)* You stopped. *(She holds out the empty jar.)* **Madhuri:** The well is dry and the lamp wants water. If you’re going somewhere anyway. *(No reward is mentioned. If the player returns with water:)* **Madhuri:** *(setting it down)* There. Now it’ll see the dawn. **Player:** *(card)* “What is the Veena for?” **Madhuri:** For the valley. Every morning, before the tower. Someone climbed the rock and played, and the day began. Then someone built a tower so that everyone would see who was playing. *(beat)* **Madhuri:** It’s a good tower. He’s a good man. It’s just the wrong direction to face.

### Scene E — The dawn choice (Act 3, beat 11)

*Tower top. Wind. The Veena on its stand. Below, whoever the player’s flags brought: competitors, Gopal, Vasanti, Tulu. The valley is grey-blue.*

*Cards:* **Play it for the valley.** / **Take it and go.**

*If played: the camera pulls back from the player to the whole valley as the melody — the Song — resolves the tense score. Light arrives from the far hills first. Tulu, tiny below, finishes his three notes. Cut to the player’s hands, then to a memory: hands carrying a pot by a river.*

*If taken: the player descends the far stairs with the Veena held to their chest. Nobody follows. They sit at the dawn overlook. The sun rises anyway. Their hands move on the strings without asking and the three notes come out. Madhuri sits down beside them and says nothing for a full eight seconds. Then:* **Madhuri:** It still works, you see. Even here.

### Scene F — The embrace (Act 5, beat 16)

*No dialogue. The player breaks the surface of the Pool, glowing again, the garland from the feast in their hands, and wades to the bank. The feast is still laid; nobody has aged a moment. Lalita sees them first and does not run; she just smiles and looks past them. The player turns. Krishna is on this side of the river. He walks the distance and stops, close. He lowers His head. One tap: the garland goes around His neck. He looks up, and embraces the player. The player’s shoulders shake; He holds on. The calf arrives and leans against them both. The friends gather in a loose circle. The camera rises straight up: two figures in the grass, a ring of friends, the rose-gold dusk, bubbles rising. Hold. Fade to the single line:*

The journey back begins again wherever you are.

### Writing rules

- Lines under 20 words. Nobody monologues except Madhuri, once, and only when asked.

- No Sanskrit in spoken dialogue except names and the maha-mantra; Sanskrit lives in the optional cards.

- Humor is allowed everywhere except the Veil and the embrace.

- Every line in the dialogue file carries a review_status of *draft* / *panel_approved* / *final*.

## 9. Wisdom encounters

Seven optional cards, each tied to a beat the player has just lived through, so the verse explains an experience rather than introducing an idea. The verse text itself is not written here: the published translation must be chosen and licensed (Srila Prabhupada’s *Bhagavad-gita As It Is* requires BBT permission; see section 15), and the exact wording goes in only after panel approval. The plain-language gloss below is the game’s own and must also be reviewed.

| # | Beat | Verse | Plain-language gloss (draft) | Why here |
| --- | --- | --- | --- | --- |
| 1 | After the whisper (Act 1) | Bg 2.13 | The self is not the body it wears; it moves through bodies as a person moves through ages. | Prepares the transformation at the Veil without explaining it. |
| 2 | Arrival in Hollow Vale | Bg 15.7 | Every living being is an eternal part of Krishna, struggling in the material world with mind and senses. | Names the condition the player is now in. |
| 3 | After any *take* choice | Bg 2.62–63 | Dwelling on objects breeds attachment; attachment, desire; desire, anger; and from there, loss of memory and intelligence. | Describes the valley’s fences without judging the player. |
| 4 | After any *give* choice | Bg 3.9 | Work done as an offering frees; work done for oneself binds. | Reframes the carry-and-place verb. |
| 5 | At the shrine, after carrying water | Bg 9.26 | A leaf, a flower, fruit or water offered with love is accepted. | The lamp water is exactly this. |
| 6 | After beat 12 (the melody) | Bg 18.66 | Give up all other paths and surrender to Me; I will free you from all reactions; do not fear. | The chapter’s thesis, offered only after the player has felt it. |
| 7 | After the embrace (credits) | Bg 9.22 | For those who worship Me with devotion, I carry what they lack and preserve what they have. | The last word is Krishna’s care, not the player’s effort. |

**Card format.** Verse reference · the licensed translation · a two-sentence gloss · *Read more* (a 200–300 word note written for someone with no background, offline in the app) · a *Sources* line naming the translation and edition. Cards are 20 seconds to read; the game pauses while one is open.

**Rules.**

- Never more than one card per beat; never a card during the Veil or the embrace.

- A card never comments on the player’s choice (“You chose well”). It comments on the situation.

- The maha-mantra appears as sound (Madhuri’s chanting) and once as text, in the *Read more* of card 6, with a one-line explanation of what it is. It is not a collectible, a password or a power.

- Where a game idea is fiction (the Song, the Veil, the Veena), the *Read more* says so explicitly: “The Song is the game’s way of picturing the pull of Krishna’s flute; the tradition describes this in the Tenth Canto of Srimad-Bhagavatam.”

- Every card has a *Learn more* link to a page the team controls (chosen in section 17), so the outreach path exists but is never forced.

## 9a. Tales from the Srimad-Bhagavatam

The Bhagavatam is the game’s second source after the Gita, used in two ways: as *tales told* by characters, and as the situations behind the daily vignettes. The rule in both: no one plays a scriptural character, Krishna’s pastimes are never a level, and every tale carries its canto and chapter on its card and passes the panel like a verse.

**Tales told.** Two-minute painted-scroll interludes (static hand-painted frames with light movement, narrated by the character who tells them), heard when the player sits with someone. Skippable, collected in *Your journey*.

| Tale | Source | Who tells it, where | Why here |
| --- | --- | --- | --- |
| **Puranjana**, the king who forgets himself in a city of nine gates | Canto 4, ch. 25–29 | Madhuri, in the shrine room, across three sittings | The frame story of the whole game: it is the player’s own situation, and the city is the body |
| **Dhruva**, the child who wanted a throne higher than his father’s | Canto 4, ch. 8–12 | Nanda, on the stairs, about his brother | Kuvera’s whisper and the tower contest in one story: he set out to earn a seat and found something else |
| **Gajendra**, when strength fails and the call goes out | Canto 8, ch. 2–4 | Madhuri, after the *Keep it* ending | The companion tale to sitting alone with the Veena |
| **Ajamila**, a name said at the end, meant for a son | Canto 6, ch. 1–2 | The Counting Man, later, at the bus stop | The first explanation of the holy name, without a lecture |
| **Bharata and the deer**, attachment to something good is still attachment | Canto 5, ch. 7–8 | Vasanti, at the garden gate | The lost-pet vignette’s companion |
| **Sudama**, the friend who brought a handful of rice | Canto 10, ch. 80–81 | Lalita, at the feast, Chapter 4 | The garland offered at the end |
| **Narada’s childhood** and **Bali** | Canto 1, ch. 5–6; Canto 8, ch. 19–23 | Chapters 2 and 3 | The Lower and the Heights |

**The twenty-four teachers.** The avadhuta’s teachers in Canto 11, chapters 7–9 (the earth, the air, the sky, water, fire, the moon, the sun, the pigeon, the python, the sea, the moth, the honeybee, the elephant, the honey-thief, the deer, the fish, the courtesan Pingala, the kurara bird, the child, the maiden with the bangles, the arrow-maker, the serpent, the spider, the wasp) become twenty-four Street vignettes in which an ordinary thing teaches something: a pigeon’s nest on a ledge, a man carrying a python’s weight of possessions, a child playing alone and content, a woman who removes her bangles one by one so they stop clashing. Each is a situation the player acts in, never a sermon; the tale card afterwards names the source. These seed the daily vignette pool (section 16a) and are the model for writing the rest.

**Witness companions.** The richest vignettes put the player inside a tale as someone beside the mahajana, never as the mahajana. The canonical events are fixed; the player’s own situation rhymes with them; what they learn is theirs. First set: a student in Prahlada’s class, pressed by the same teachers to flatter the king, who watches what Prahlada does and chooses what to do (Canto 7, ch. 5); a village child who sees Dhruva leave for the forest and faces his own smaller slight at home (Canto 4, ch. 8); a neighbour of Sudama who watches him set out with a handful of rice and must decide what to do with her own little (Canto 10, ch. 80); a boy in the Gokula of the Govardhana story who has to decide whether to run or to stand under the hill with the others (Canto 10, ch. 24–25; Krishna is seen only as the others see Him, lifting). No player ever controls a scriptural character, no pastime is a level, and nothing the player does can change what the mahajana does.

**Cost.** One 2D artist for the scrolls (about 70 painted frames for Chapter 1), writing time, and panel review. The gain is depth, authenticity, a content engine for the living world, and a *Learn more* path that leads somewhere real.

## 10. Art direction, music and sound

**Visual style: painted stylized 3D.** Soft, hand-painted textures, simplified geometry, strong silhouettes, no photorealism. This reads well on small screens, ages slowly, runs on mid-range Android, and keeps Krishna’s depiction in the register of devotional painting rather than action games. Reference points for the team (for mood only, never copied): Indian miniature painting palettes; the Pattachitra line; the warm pastoral light of Vrindavan at Kartik.

**Palette by realm.**

| Realm | Dominant | Accent | Forbidden |
| --- | --- | --- | --- |
| Grove | Rose-gold dusk: magenta sky, warm amber light on skin, river reflecting pink | Peacock blue (Krishna only), jasmine white, marigold | Grey, hard black, overcast light of any kind |
| Pool of Worlds | Blue-black with nebula violet and star white | The player’s own glow, unravelling | Any warm colour on the way down; any cold colour on the way up |
| Hollow Vale | Ochre, dust, timber brown, flat overcast white | Rust red on fences and the tower | Peacock blue and magenta (both reserved for the Song’s return and for Glimpses) |

Colour is a storytelling tool. The Grove’s pink sunset is the signature of home; the first time any pink appears in Hollow Vale is at beat 12, as a thin band on the horizon, and the first time peacock blue appears is on the Veena’s strings in the same moment. A Glimpse silhouette is always backlit by a warm source that the rest of the scene does not have.

**Cinematography (from the reference clips).** The clips are built from a small number of repeating shots, and the game’s cinematics use the same grammar so that the trailer and the play look like one work: a slow push-in on a face lit from the side; a figure small against a huge sunset; an overhead shot straight down on people in grass; hands (offering a flower, reaching for another hand, threading a garland); a reflection or a sphere that holds a sky. Every Timeline cinematic in the MVP is composed from these five shots and nothing else.

**Characters.** Proportions slightly elongated, faces simple with large expressive eyes (the eyes carry the state of the soul: bright in the Grove, dulled in the Vale, bright again at beat 12), hand-painted cloth, real jewellery detail on Krishna only. The Grove form of the player glows from within (emissive rim); the traveler form has no emissive at all. Krishna: dark-blue skin, yellow cloth, tilak, peacock feather, a jasmine garland, and the only model with a subtle particle aura, used sparingly.

**Music.** One composer; a single theme (the Song) written first, then everything else derived from it:

- *The Song* — flute lead, tabla, tanpura drone, a sung line without words. Complete only in Act 1 and Act 5.

- *Veil* — the Song with instruments removed one by one (Act 2) or returned one by one (Act 5). Same recording, mixed differently.

- *Hollow Vale* — the Song’s chord changes played by a string quartet in a minor mode, tense, with the melody missing. Players should feel they almost know it.

- *Character motifs* — four bars each for the four competitors, all built from fragments of the Song.

- *Tulu’s three notes* — the first three notes of the Song, sung by a child.

- *Dawn* — the moment the string quartet and the flute meet.

Total: about 12 minutes of unique music, adaptive via vertical layers (stems) rather than many tracks. Licensing: original composition owned outright; no traditional bhajan recordings in the MVP to avoid rights uncertainty.

**Sound.** Water, cowbells and birds are the Grove’s bed; wind, hammering and counting are Hollow Vale’s. Madhuri’s chanting is recorded by a devotee with permission and credited. The maha-mantra is mixed low under the shrine and rises only at beat 12 and beat 14.

**UI art.** Minimal, cream parchment panels, a single serif for headings and a clean sans for body (both with Devanagari and extended Latin coverage for localization). The lotus icon is the only ornament.

**Asset sourcing plan.** Licensed packs: village buildings, foliage, cows, generic villager bases, animation sets (walk, carry, sit, climb). Custom: player (two forms), Krishna, the tower, the shrine interior, the Veena, the kadamba tree, all character heads, all UI. Concept art may use AI tools for ideation; no AI-generated asset ships, and every shipped asset has a rights record.

## 11. UI, controls, accessibility and localization

**Screens.** Title · first-launch note · settings · the game (HUD) · pause (*Your journey*, settings, quit) · wisdom card · end screen. No inventory, no map, no shop in the MVP.

**HUD.** Empty by default. Joystick fades in on touch; the contextual button appears only near something usable; the lotus icon pulses only when a card is available. Nothing else is on screen during play.

**Controls.**

| Action | Touch | Gamepad (PC later) |
| --- | --- | --- |
| Move | Left-thumb joystick | Left stick |
| Camera | Right-thumb drag | Right stick |
| Interact / Carry / Listen | Contextual button (right, lower) | A |
| Call (hum) | Hold the contextual button with nothing nearby | Hold A |
| Choice | Tap a card | D-pad + A |
| Pause | Top-left corner | Start |

Joystick side, size and opacity are adjustable. Camera sensitivity and inversion are adjustable. An *auto-walk to target* option lets the player tap a destination instead of steering.

**Accessibility (MVP commitments).**

- All text 16 dp minimum at default; a large-text option to 22 dp.

- Subtitles for every vocal sound, including hums and chanting, with speaker labels and an optional background box.

- A *sound cues as visuals* option: when a *Listen* source is active, a soft ripple appears at its origin, so a player who cannot hear can still follow sound.

- Color is never the only signal (the blue of the Song is paired with light and motion).

- No flashing above 3 Hz; the Veil’s white flash is a 0.5 s fade.

- Screen-reader labels on all menu elements.

- No timed input anywhere; the counting mini-game can be skipped.

**Localization.** All strings externalized with string IDs; no text baked into textures or cinematics. Ship English; ready Hindi and Spanish next (large audiences, strong devotee communities). Dialogue is written to be translatable: no English puns, no idioms in key lines. Verse translations are licensed per language, not machine-translated. Fonts cover Latin extended, Devanagari and Bengali from day one so the first three expansions need no font work.

**Content rating.** Target PEGI 3 / ESRB Everyone / IARC equivalent. Nothing in the MVP contradicts this.

**Privacy.** No account. No personal data collected. Optional, opt-in anonymous analytics (section 16) with a plain one-screen explanation. Complies with Google Play’s Families policy if the team chooses to opt into the Designed for Families programme, which should be decided before launch.

## 12. Technical design

**Engine: Unity, confirmed by a one-week bake-off** in weeks 1–2 (the same Grove blockout built in Unity and Godot 4, tested on three Android devices). Unity is the default because of its mobile track record, asset-store coverage for this style, and the size of the hiring pool in India; Godot wins only if it matches performance and the team prefers it. Unreal is not evaluated for the MVP: its strengths are not the MVP’s needs and its mobile build sizes are a cost.

**Target devices.** Android 9+, 3 GB RAM, Adreno 610 / Mali-G52 class GPU (2020 mid-range). 30 fps locked on these; 60 fps optional on flagships. Install size under 350 MB. Test devices: one 2020 mid-range, one 2023 mid-range, one flagship, one 2019 low-end to define the floor.

**Architecture.**

| Layer | Choice | Reason |
| --- | --- | --- |
| Rendering | Universal Render Pipeline, baked lightmaps, one real-time directional light, forward rendering | Mobile cost; painted style needs no deferred features |
| Scene structure | Three scenes (Grove, Veil, Vale) loaded additively with a persistent *Core* scene for managers | Lets the Grove relight without a reload |
| Game state | A single serializable JourneyState: current beat, set of flags, choice history, settings | One object to save, one to inspect, one to reset |
| Quests and dialogue | Data-driven: quests in YAML/JSON, dialogue in a spreadsheet exported to JSON, keyed by line_id | Writers and the review panel work without the editor |
| Dialogue runtime | Yarn Spinner or Ink (pick in week 1; both open-source, both support branching and localization tags) | Avoids writing a dialogue engine |
| Cinematics | Unity Timeline, in-engine, real time | No video files; relit scenes reuse assets |
| Audio | FMOD (free tier under the revenue threshold) or Unity Audio with stems; adaptive layers for the Song | The Song’s remove/return-an-instrument effect is a stem mix |
| Save | Local JSON, autosave at every beat and choice, one slot plus *New journey* | No account, no backend |
| Localization | Unity Localization package, string tables, font fallback chain | Day-one multi-script support |
| Analytics | Opt-in only; a small event list (section 16) sent to a privacy-respecting provider or a self-hosted endpoint | Minimal data, clear disclosure |
| Build | Android App Bundle; Gradle on a CI runner (GitHub Actions) producing a signed internal build per merge | Reproducible builds from day one |

**Flag model.** Flags are strings in a set; beats are an ordered enum. A beat can require flags to enter (dawn_climb requires at_tower_top) and set flags on exit. Branching dialogue reads flags; nothing else in the game is conditional on anything but flags and the current beat. This keeps the whole game inspectable with a debug panel that lists flags and lets a tester set them.

**Content pipeline.** Blender → FBX → Unity with a naming convention and an import preset; one atlas per character, one per environment set. Every asset carries a row in the rights register (source, licence, proof of purchase, reviewer sign-off for Krishna-related assets).

**Performance budget per frame (mid-range target).** Draw calls under 150; triangles under 150k; texture memory under 300 MB; GC allocations zero during play (object pools for petals, sparks and UI).

**What is explicitly not built.** No backend, no accounts, no multiplayer, no live AI dialogue, no in-app purchase in the MVP (the Chapter 2 button opens a wishlist page). IAP is added in Stage 3 once there is a chapter to sell.

**Risks and mitigations.**

- *Krishna’s embrace animation looks wrong.* Mitigate: motion reference shot with two actors in week 3; blockout reviewed by the panel in week 6; final by week 12.

- *Low-end devices stutter in Hollow Vale.* Mitigate: a quality tier that halves foliage and disables the aura; tested from the first prototype build.

- *Dialogue engine fights localization.* Mitigate: decide Yarn vs Ink by a localization test, not a feature list.

## 13. Production plan

A four-person core team can deliver the MVP in 16 weeks, with weeks 17–24 held in reserve for release work and slippage. Nothing after the fun gate is funded until testers say they want more.

**Phases and gates.**

| Phase | Weeks | Focus | Gate at the end |
| --- | --- | --- | --- |
| Pre-production | 1–2 | Engine bake-off; story and art lock | Engine chosen (same scene, 3 devices) |
| Prototype | 3–6 | Grove + one quest, grey-box build | Fun gate: do testers want more? |
| Production | 7–12 | Both worlds built, all quests, music | — |
| Testing | 13–16 | Device, player and panel testing | Panel sign-off: content approved |
| Release prep | 17–24 | Store listing, soft launch | Stage 3 decision: section 1 metrics met? |

Each gate is a decision, not a ceremony: fail the fun gate and the team reworks the prototype rather than starting production art.

**Core team.**

| Role | Weeks | Owns | Can be |
| --- | --- | --- | --- |
| Producer / designer | 1–24 | Scope, quest data, dialogue, playtests, this document | The founder, if they can give it most of their week |
| Unity engineer | 1–20 | Movement, camera, interaction, flags, save, cinematics, builds, performance | One experienced mobile developer |
| 3D artist / animator | 2–16 | Player, Krishna, tower, shrine, Veena, heads, environment dressing, animation | One generalist with a strong painted style; a second for weeks 7–12 if budget allows |
| Composer / sound designer | 3–14 | The Song and all derived music, sound beds, stems, mix | Contract, milestone-based |
| Writer | 1–10 | Scene scripts, dialogue file, wisdom glosses | Part-time; may be the producer |
| Review panel (3–5 devotees) | 2, 6, 12, 15 | Philosophical and depiction review at each gate | Volunteer or honorarium; one must be a senior devotee with scriptural authority |
| QA / device testers | 13–20 | Device matrix, bug triage, accessibility checks | A paid contractor plus volunteer community testers |

**Deliverables by phase.**

- *Pre-production (1–2):* engine bake-off report; locked story (section 3); art bible with three key paintings (Grove, Vale, embrace); dialogue engine chosen; rights register opened; panel briefed.

- *Prototype (3–6):* grey-box Grove with the three tutorial tasks; grey-box Vale with *The Full Well* only; working choice cards and flags; the Song recorded as a piano sketch; motion reference for the embrace. Playtest with 8 outsiders.

- *Production (7–12):* all environments dressed; all 12 characters; all quests and dialogue; Timeline cinematics for the Veil, dawn and embrace; full music and stems; wisdom cards with placeholder verse text; localization pipeline proven with one Hindi string table.

- *Testing (13–16):* device matrix pass; 20-person external playtest against the section 1 metrics; panel final review; accessibility audit; verse text licensed and inserted; bug bar reached (no crash, no blocker, no progression break).

- *Release prep (17–24, as needed):* store listing, screenshots, trailer cut from in-engine footage, privacy disclosure, IARC rating, closed-track rollout to 500 players, then open release.

**Working rhythm.** One-week sprints; a playable build every Friday from week 3; a 30-minute panel call every other week; a written playtest report after every test.

## 14. Budget and monetization

The recommended first funding target is ₹12 lakh for the polished MVP, inside the ₹8–18 lakh range from the earlier plan. Figures are planning estimates for an India-based team in 2026, not quotations; the three-stage structure means only Stage 1 is committed before the fun gate.

| Stage | Spend | Weeks | Released when |
| --- | --- | --- | --- |
| 1 · Technical prototype | ₹1–3 lakh | 1–6 | Now |
| 2 · Polished MVP | ₹8–18 lakh (plan ₹12 lakh) | 7–24 | Fun gate passed |
| 3 · Chapters 2–4, localization, marketing | ₹25–60 lakh+ | 6–12 months after launch | Section 1 metrics met |

**₹12 lakh MVP allocation** (unchanged from the earlier plan; it still fits this design): development ₹4.2 lakh · art and animation ₹2.4 lakh · sound and music ₹0.8 lakh · story and philosophical review ₹0.6 lakh · testing and devices ₹0.8 lakh · launch and marketing ₹1.0 lakh · contingency ₹2.2 lakh. The contingency exists mainly for the Krishna model and the embrace animation, which are the assets most likely to need a second pass.

**What this design adds or removes against that budget.** Two character forms for the player (+ one model); twelve characters instead of “a few” (mostly licensed bases, so + heads only); a stem-based adaptive score (within the ₹0.8 lakh if the composer owns the mix); no IAP, no backend, no voice acting (− cost). Net: the ₹12 lakh plan holds.

**Tools and fees (verify before committing; these change).** Unity Personal is free under its revenue and funding threshold; Godot is free; Blender is free; a dialogue engine (Yarn Spinner or Ink) is free; FMOD is free under its indie threshold; Google Play registration is a one-time fee; licensed asset packs ₹0.5–1.5 lakh total; verse translation licence from BBT: terms to be requested in week 1.

**Monetization (Stage 3, not MVP).**

- Chapter 1 is free forever, including the embrace. The spiritual message is never behind a paywall.

- Chapters 2+ are sold as a one-time unlock per chapter (test price ₹199–₹499 in India, localized elsewhere) or as a season pass. Price is a hypothesis to test on the soft-launch cohort.

- Optional cosmetics only if they do not touch Krishna, the Grove form, or any devotional element: a traveler’s coat colour, yes; a peacock feather, no.

- A clearly separated *Support the project* link, outside the game’s economy, to a page the team controls. No in-game reward for supporting.

- No ads anywhere. No loot boxes, streaks, energy, timers or notifications.

**Unit economics reminder.** At 100,000 installs, a 3% conversion and ₹299 per chapter, net revenue after store fees is roughly ₹7.6 lakh: less than the MVP cost. Sustainability needs several chapters, lower acquisition cost through community and temple channels, or grant and donor funding for the outreach half of the mission. The MVP’s job is to produce the numbers that make that case, which is why the analytics in section 16 matter.

## 15. Philosophical review process and safeguards

Religious integrity is a gate in the schedule, not a final proofread. A panel of three to five devotees, at least one with recognized scriptural authority, reviews at weeks 2, 6, 12 and 15 and can block release on a depiction or doctrinal point.

**What the panel reviews, and when.**

| Week | Material | Panel decides |
| --- | --- | --- |
| 2 | This document: story, cosmology, character list, the seven verse choices, the first-launch honesty note | Is the frame acceptable? Are any names, scenes or metaphors inappropriate? |
| 6 | Krishna concept art and model blockout; embrace motion reference; Madhuri’s chanting recording; all Scene A–F drafts | Is the depiction respectful and traditional? Is any line doctrinally wrong? |
| 12 | Playable build; all dialogue; wisdom glosses; *Read more* notes; verse translations as licensed | Line-by-line approval; every dialogue row moves from *draft* to *panel_approved*. |
| 15 | Release candidate; store listing text; trailer | Final sign-off. Anything not approved is cut, not shipped pending review. |

**Standing safeguards (design commitments that survive every review).**

- No score, meter, rank, badge or unlock measures devotion or spiritual progress. The flag system is invisible and changes texture only.

- Every ending reaches the embrace. A player who takes everything and keeps the Veena is embraced too. This is the point.

- Krishna never gives quests, items, powers or rewards. He is never purchasable, collectible, skinnable or defeatable.

- Krishna’s image follows traditional Vrindavan iconography; no film or comic styling; no violence, no romance, no Radha or rasa-lila content in the MVP.

- Game fiction (the Song, the Veil, Hollow Vale, every named character except Krishna) is labeled as such in the first-launch note and in every *Read more*.

- Scriptural text appears only as a licensed translation with edition named; the game never paraphrases a verse as if it were the verse.

- No guilt, fear or shame mechanics. No character tells the player they are sinful, fallen or lost.

- Playing is never equated with practice. The end screen’s *Learn more* points to hearing, chanting, association and service, not to “complete Chapter 2.”

- Donations are outside the game’s economy and buy nothing in it.

- No AI-generated theological text at runtime. All text is authored, reviewed and fixed at build time.

**Rights and permissions to secure (week 1 start).** BBT permission for verse translations in each shipped language; a recorded release from the devotee who chants; an attribution line for any tradition-specific artwork used as reference; trademark search on the title; a check that no character name coincides with a scriptural figure in a way the panel finds misleading.

**Escalation.** If the panel and the design team disagree on a point of depiction or doctrine, the panel wins. If they disagree on a point of gameplay, the design team wins. The producer records every decision and its reason in a review log attached to this document.

## 16. Playtesting plan and success metrics

Three rounds of outside testing decide whether the game works, and half of every cohort must be people with no connection to Krishna consciousness.

| Round | Week | Who | Build | What is measured |
| --- | --- | --- | --- | --- |
| 1 · Fun gate | 6 | 8 people: 4 non-devotees, 2 devotees, 2 regular mobile gamers | Grey-box Grove + one Vale quest | Do they explore unprompted? Do they understand the choice cards? Do they ask what happens next? |
| 2 · Meaning | 12 | 12 people, same mix, none from round 1 | Full chapter, placeholder verse text | Completion rate; can they retell the story; which ending they chose and why; did they open any wisdom card; what they thought the Song was |
| 3 · Release | 15 | 20 people plus a 500-player closed track | Release candidate | All section 1 metrics; crash rate; device coverage; store-listing comprehension |

**Session protocol.** Observe silently on the tester’s own phone; no instructions beyond “play until you want to stop”; a 10-minute interview after; the four questions below asked verbatim and recorded.

- What was this game about, in your own words?

- Did any choice feel like it mattered? Which one?

- What did the ending mean to you?

- Would you play a second chapter? Would you pay ₹299 for it?

**Go / no-go metrics for Stage 3** (from section 1, measured in round 3 and the closed track).

- Completion in one sitting ≥ 60%.

- Central conflict retold correctly ≥ 70%.

- Would play Chapter 2 ≥ 50%; would pay ≥ 10%.

- Panel approval with no open major objection.

- Crash-free sessions ≥ 99% on the device matrix.

- Median session 15–25 minutes (shorter means skipping; longer means lost).

**Opt-in analytics events** (the complete list; nothing else is sent): session start/end, beat reached, choice made (card id only), wisdom card opened/closed, side quest started/completed, *Listen* used, Call used, crash. No identifiers beyond a random install id; no location; no demographics.

**Signals that mean a redesign, not a tweak.**

- Testers describe the game as “a religious game” before describing it as a story: pillar 1 is failing.

- Testers believe *Keep it* is the wrong answer and feel punished: pillar 3 is failing; review Scene E.

- Nobody opens a wisdom card: fine. Everybody opens them and finds them confusing: rewrite the glosses.

- Testers do not notice the Song’s return at beat 12: the stem mix or the blue-light cue needs to be stronger.

## 16a. Engagement redesign: the living Grove, the Song as skill, companions, and return

The first draft of this document produced a game that is strong on story, agency and aesthetics and weak on mastery, social, return and replay. This section adds a second layer of game around the story so that all four become strengths, without breaking the pillars in section 1 or the safeguards in section 15. Model: Sky: Children of the Light and Animal Crossing (a living home plus daily change), Journey (wordless companions), Dark Souls and Sky (asynchronous messages).

### Two layers

| Layer | What it is | Purpose |
| --- | --- | --- |
| **Story chapters** | Finite, emotional, authored; Chapter 1 as described in sections 3–8 | The reason people recommend the game |
| **The living world** | The Grove as a home that grows, the Street that changes every day, companions and lamps | The reason people come back |

### Challenge and mastery: the Song as a skill

- **Playing** is a real mechanic. A touch rhythm-and-pitch system (hold, slide, release along a string or across holes) drives the flute in the Grove, the hum in the Street and the Veena at dawn. Easy to do; hard to do beautifully. Accuracy is shown in the world, never as a number: more birds land, the calf dances, the crowd at the fountain grows, the dawn sky warms further, a companion’s hum resolves into harmony.

- **Rooftop running.** The Street gains a flow-traversal layer: momentum, ledges, cables, awnings, timing (the clips’ image of Krishna across the rooftops). Glimpse points and hidden Street stories are reachable only by good runs. Falling drops the player to the pavement; nothing is lost.

- **Stray cows.** Cows from the Grove wander the city unseen. Guiding them through traffic to the fountain is a timing-and-path puzzle: 40 handmade layouts in the first release, then a generator. Difficulty rises by crossing, bus timing and lane count.

- **Rule.** Mastery is craft, never devotion. The player gets better at playing for others and at reaching places. Grace stays unconditional: the embrace never depends on skill, and no skill result is ever called spiritual.

### Session and return: the Grove lives, the Street changes

- After the credits the Grove stays open as a home: a garden to plant, the feast to cook, the calf to raise, a swing and a riverbank to decorate with what was found in the Street. Friends have sixty small stories (three minutes each) that unlock as real days pass. Nothing decays and nothing dies if the player stays away.

- **Dawn vignettes.** Every real day, the Street has one new 2–4 minute encounter from a rotating pool (120 at launch, written as short moral situations in the voice of section 8) and one new cow route. Missed days queue; nothing is lost.

- **Festival events** on real dates (Janmashtami, Kartik, Holi, Gaura Purnima, Ratha-yatra): the Grove changes dress, a story arrives, lamps from the whole community are visible for the festival’s duration. These are the only time-limited content, and they are calendar-true.

- **No streaks, no energy, no countdown timers, no notifications except an optional festival reminder.** Return is pulled by novelty and home, never pushed by loss.

### Social: companions, lamps and circles, with no accounts and no feeds

- **Lamps** (asynchronous, first release). Anywhere in the Street or Grove the player can set down a lamp with one of twelve preset lines (“Someone was kind here”, “Look up”, “I kept it, and I’m sorry”, “Sit a while”). Others see lamps as small lights, can sit by them and leave a flower. No free text, so no moderation burden; lamps fade after thirty days unless re-lit.

- **Companions** (live, Season 1). Another player’s glowing traveler appears in the Street or Grove, matched anonymously by region and language, with an opt-out. Companions can hum together (two humming resolves a chord no one can alone), carry together (some water cans need two), run rooftops together and sit together at a lamp. Gestures and the hum only; no chat, no names, no profiles.

- **Circles** (Season 1). An invite link forms a group of up to twelve (a family, a temple youth group, a class). Circles see each other’s Grove gardens, leave lamps for one another, and grow one shared kadamba tree in a shared clearing as the Circle plays. Circle goals are acts of service in the Street, never devotion counts.

- **Path card** (first release). At every chapter’s end, a shareable image of the player’s route and what they noticed, built for Instagram, WhatsApp and Shorts. The social layer that lives outside the app.

- **Rule.** No leaderboards, no global rankings, no follower counts. A Circle can see its own members’ best cow and rooftop runs; no one else can.

### Multiplayer spine

- **Companions, two at a time (first release, not Season 1).** Another player’s glowing traveler appears in the Street or Grove; two hums make a chord one voice cannot; some cans need two carriers; cows are easier with two herders; rooftop runs become races against each other or against a Circle member’s recorded ghost. Matched by region, language and chapter; drop-in, drop-out, opt-out.

- **Circles, up to twelve.** Shared garden visits, lamps for each other, a kadamba tree that grows as the Circle plays, witness tales cast from the Circle.

- **Festival gathering, up to fifty (the sankirtan mechanic).** On real festival days the Grove is shared: every lamp and traveler visible, and the Song played together, each player holding one part, so that the full Song sounds only when enough people play it well. This is sankirtan as play, and the only large-group feature.

- **Temple mode.** A big screen and phones in one room: the room plays one Street, projected, each phone a traveler, for festivals, youth programmes and classrooms.

- **Underneath.** A small backend with anonymous install ids (Firebase, PlayFab or Nakama); a relay that syncs positions, gestures and hum notes, which is tiny data that survives Indian mobile networks; presence in gatherings is lightweight (others shown as lights and travelers, not fully simulated). No free text, no voice, no names, so there is almost nothing to moderate and it stays safe for children. Running cost scales with concurrent players, not installs; moving companions into the first release adds roughly ₹6–8 lakh and six weeks.

### Replayability: variation, collection, second journeys

- Three approaches × two dawn choices × two Grove looks give six distinct Chapter 1 runs with different scenes, lines and dawn crowds; the *Your journey* page shows which the player has seen.

- **Noticed.** Every Glimpse, bubble world, feather and jasmine, cow and lamp is kept in *Your journey* with the sentence it was seen in: 70 things in the first release.

- **Second journey.** After finishing, the Street can be re-entered any day with a different stranger’s problem (the vignette pool), and rooftop and cow challenges are rated against the player’s own best only.

- Each new chapter adds a district, an instrument to the Song, and a traversal element.

### What this changes elsewhere in the document

| Section | Change |
| --- | --- |
| 6 (systems) | Add Playing, Rooftop running and Stray cows as core verbs beside move, carry, call, choose, listen |
| 12 (technical) | A minimal backend: anonymous install ids, lamps store, festival calendar, vignette delivery; matchmaking and Circles in Season 1. Privacy stays as in section 11; no personal data, no accounts |
| 13 (plan) | First release 26–32 weeks; a fifth core person (gameplay and network engineer); the fun gate now tests the rhythm mechanic and a cow route as well as the story |
| 14 (budget) | First release ₹20–26 lakh; backend running cost ₹15–40k per month at launch scale; Season 1 (companions, Circles) ₹25–60 lakh as before |
| 15 (safeguards) | Add: no skill result is ever described as spiritual progress; no leaderboards; lamps are preset lines only; festival events are the only timed content |
| 16 (metrics) | Add: day-7 return ≥ 25%, day-30 return ≥ 10%, lamps per player ≥ 2, path cards shared ≥ 5% of finishers, median mastery improvement on cow routes across three attempts |

### Reanalysis after the redesign

| Element | Before | After | How |
| --- | --- | --- | --- |
| Core loop | Yes | Stronger | Explore → play/run/guide → choose → see the world answer |
| Challenge/mastery | Weak | Strong | Rhythm playing, rooftop running, cow routes with rising difficulty |
| Social | Missing | Strong (first release: lamps and path cards; Season 1: companions and Circles) | Wordless companionship, shared lamps, small circles, no feeds |
| Session/return | Weak | Strong | Living Grove, daily vignettes, calendar festivals; no manipulation |
| Replayability | Partial | Strong | Six runs, 70 things to notice, second journeys, generated cow routes |
| Narrative, aesthetics, agency | Strong | Unchanged | — |
| Pillars (section 1) | Intact | Intact | Mastery is craft; grace is free; social is service |

The honest cost of the redesign: it moves the first release from a ₹12 lakh, 16-week story to a ₹20–26 lakh, 26–32-week game with a small backend. The alternative, shipping the story alone and adding the living world in Season 1, is cheaper but will show poor launch retention and make Stage 3 funding harder to raise. The recommendation is to ship the story chapter with the rhythm mechanic, a minimal living Grove, lamps, path cards and the daily vignette pool, and to hold companions and Circles for Season 1.

## 17. Open decisions and next steps

Ten decisions are yours to make before week 1; everything else in this document can proceed on the assumptions stated. The last two were added after the reference clips (Appendix A).

**Decisions needed.**

- ☐ Confirm the title, or choose another, after a trademark and Play Store name check.

- ☐ Confirm the player is unnamed and silent (recommended), or give them a name and a voice.

- ☐ Confirm the dual ending (*Play for the valley* / *Keep it*), or require the giving choice. The panel should weigh in; the design recommendation is to keep both.

- ☐ Choose the verse translation and edition to license, and who approaches BBT.

- ☐ Name the review panel: three to five people, one with scriptural authority, available at weeks 2, 6, 12 and 15.

- ☐ Choose where *Learn more* links go (an existing temple or outreach site, or a new page the team controls).

- ☐ Decide whether to opt into Google Play’s Designed for Families programme (affects analytics and store rules).

- ☐ Confirm the first three languages after English (recommended: Hindi, Spanish, then Russian or Portuguese based on community size).

- ☒ **Setting of the material world: decided, a modern city block.** Chosen for adoption: a contemporary street with Krishna hidden in plain sight is the image a stranger stops for, and players recognise their own lives in it. Hollow Vale is now a riverside neighbourhood (sections 2, 5, 7). Cost is held by keeping it to one block built from licensed stylized-city packs, with traffic and crowds as looping ambience. The village version is retired.

- ☐ **Two Grove looks for the player** (girl with braid, boy with scarf), or one neutral form. Two looks match the clips and cost one extra head and coat.

**First two weeks.**

- Hire or confirm the Unity engineer and the artist; brief the composer.

- Run the engine bake-off: the Grove riverbank blocked out in Unity and Godot 4, on three Android devices, with a one-page result.

- Lock the story in section 3 with the writer and send sections 2, 3, 4, 8 and 9 to the panel.

- Commission the three key paintings (Grove, Hollow Vale, the embrace).

- Open the rights register and request BBT terms.

- Set up the repository, CI build and the quest/dialogue data files with one placeholder quest each.

- Shoot motion reference for the embrace with two actors and a phone.

- Recruit the eight round-1 testers.

**What this document does not yet contain** (to be added as the work produces them): the art bible, the full dialogue file, the quest JSON, the rights register, the panel review log, playtest reports, and the Chapter 2 outline. Each should live alongside this document so the team keeps one source of truth.

## Appendix A — Reference clips and what the design took from them

Seven short films were shared on 19 October 2026. They are not the game’s assets and nothing from them is copied; they are the team’s shared picture of how the story should feel. What follows is what each clip establishes and where it now lives in this document.

| Clip | What it shows | Taken into the design |
| --- | --- | --- |
| 1 (94 s) | A rose offered on the grass; Krishna with tilak and garland; an old woman’s calm face; a dark sphere holding a nebula; hands threading a jasmine-and-rose garland; a girl offering it; Krishna bowing His head to receive it; friends holding each other. | The garland threaded in Act 1 and placed on Krishna in Act 5 (beats 2 and 16). Madhuri’s look and manner. The world-bubble as the game’s signature image (section 2). Krishna bowing to receive the offering before the embrace. |
| 2 (69 s) | Krishna playing the flute against a tree at a pink sunset with cows; a girl with bright eyes; a figure unravelling into dark ribbons and flying toward the sun; a small glass sphere in the grass; a family walking on the horizon; the girl and Krishna face to face; an overhead shot of a circle of people around them. | The Grove’s eternal rose-gold dusk (sections 5 and 10). Beat 3 exactly. The unravelling-into-ribbons transformation in the Pool (beats 6 and 15). The overhead final shot with the friends’ circle (beat 16). The eyes as the carrier of the soul’s state (section 10). |
| 3 (82 s) | A girl alone on a hillside in grief; Krishna comes to her by water; their hands reaching; Krishna standing among planets; Krishna silhouetted with the flute on the roof of a city building at sunset. | The *Keep it* ending where Madhuri sits beside the player by the water (beat 12). The hands shot in the cinematography grammar. Glimpses: Krishna far and backlit on a high place (section 6). |
| 4 (59 s) | A lake seen from above that holds a galaxy; a modern-dressed boy meets Krishna; a figure floating underwater among stars; a face seen in reflection; Krishna sitting on a street lamp over an ordinary street. | The Pool of Worlds and the descent through stars (section 2, beats 5–7). The reflection in the basin (beat 14). The second Grove look (the boy). Glimpses on an everyday perch (section 6). |
| 5 (59 s) | A smiling child; Krishna leaning on a tree with friends; three friends sitting and looking up at a galaxy sky; a figure diving into a pond at sunset. | Beat 3: friends sitting with the player looking at the star-filled dusk. The dive as the way out of the Grove (beat 5). The Grove as a company of children (section 4). |
| 6 (65 s) | Krishna walking away through trees at sunset; a child’s hand reaching into a cosmic dark; the unravelling figure again; a boy standing still as adults walk past; the boy’s face in wonder; a crying child held by Krishna; the two lying together in the grass seen from above. | Krishna turning to watch the player go (beat 5). Hollow Vale’s crowd that never looks up (section 5, Glimpses). The tears in the embrace and the overhead closing shot (beat 16 and Scene F). |
| 7 (23 s, widescreen) | Krishna running across city rooftops; a flute in close-up; cows leaping across a skyline; Krishna in an office corridor as a guard passes; a taxi; Krishna on a traffic light; walking down an avenue at sunset with cows. | Not in the MVP. The whole clip is the proposed Chapter 2 setting: a city where the Song is almost inaudible, where cows appear in traffic and nobody sees them, and where the Glimpse system becomes the main mechanic. Recorded here so the decision in section 17 is made with the picture in view. |

**Chapters 2 and 3, from the clips.** The city rooftops, the traffic light, the office corridor and the cows on the avenue in clip 7 belong to *The Heights* (Chapter 3), where rooftop running is at its most exhilarating and Krishna is glimpsed on cranes and in metro-window glass with cows that nobody sees. The underwater and night-sky frames of clips 4 and 6 belong to *The Lower* (Chapter 2). The season structure is in section 2a; the embrace is withheld until Chapter 4 so that Chapter 1 remains the complete, free experience of the whole arc.

**What was deliberately not taken.** The clips are live-action and photoreal with real actors; the game stays painted and stylized (section 10), both for cost and so that Krishna’s depiction remains in the register of devotional art. Nothing is rotoscoped or traced from the films. If the films’ makers are known to the team, their permission to use the films as internal reference should be recorded in the rights register.

## Appendix B — Adoption and competitive brief

**Why people will try it.** A fantasy village reads as “an Indian religious game” to someone with no background; a rush-hour street where a blue boy sits on a traffic light and nobody looks up reads as a mystery. The city setting makes the trailer a question (who is he, why does no one see him?), and Chapter 1 answers it for free, with the embrace included, so the whole emotional arc is the marketing.

**Where it competes.** Short, beautiful, emotional mobile games (Journey, Sky, Monument Valley, Gris, Florence) prove the audience exists and pays. This game matches their length and polish and adds what they lack: a story people recognise themselves in and argue about. Against existing religious games it competes by being a real game first: free, no ads, no points for piety, no lecture.

**Stages.**

| Stage | When | What happens | Measure |
| --- | --- | --- | --- |
| 1 · Seed | Months 0–6 | Build and test with temples and non-devotee friends; panel sign-off; a 60-second vertical trailer cut from the real game (the traffic light, the dive, the embrace). | Section 1 metrics in playtests |
| 2 · Launch | Month 6–7, timed to Janmashtami or Diwali | Free Chapter 1 on Android; trailer on Reels, Shorts and TikTok; ISKCON and temple networks share worldwide; press angle: a devotional game that isn’t preachy. | 100k installs in 90 days; 60% completion |
| 3 · Spread | Months 7–12 | Hindi, Spanish, Portuguese, Russian; creators and streamers (the ending is built for reaction videos); iOS and PC; the “which ending did you choose” conversation. | Share rate; organic install share above 50% |
| 4 · Deepen | Year 2 | Paid chapters as a season; the city grows; *Learn more* links to a short free course (hear, chant, associate, serve) run by the community, so the game is a door, not the room. | 10% paid conversion; course sign-ups |
| 5 · Belong | Year 2 onward | Community playthroughs at temples and festivals, youth programmes, a classroom edition; people learn by playing together, then by being invited further. | Groups formed; returning players |

**What would make it fail.** A trailer that leads with the Gita instead of the mystery; a paywall before the embrace; a city that looks like one specific country; ads; a release not timed to a festival; no non-devotees in the playtests.