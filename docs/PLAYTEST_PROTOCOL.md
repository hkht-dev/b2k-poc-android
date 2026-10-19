# Playtest protocol — Slice 1

From GDD §16, narrowed to the slice. Half of every cohort must be people with
no connection to Krishna consciousness.

## Running a session

1. The tester plays on **their own phone**, not ours. Sideload the build before
   they arrive (README has the steps).
2. Say one thing and nothing else: **"Play until you want to stop."**
   - No explanation of the controls.
   - No mention of the story, the fountain, the boy or what to look for.
   - Do not say the words *Krishna*, *spiritual*, *devotional* or *religious*
     at any point before the interview is over.
3. **Observe silently.** Do not answer questions during play. If asked what to
   do, say "whatever you like" and nothing more.
4. Note, without interrupting: when they first move; whether they look around
   or walk straight; whether they find the boy; whether they use *Listen*;
   whether they take the can, carry it, or ignore the fountain; whether they
   look at the traffic light; whether they pick up the feather; where they
   stop.
5. Let it end when they stop. Then interview.

## The questions, asked verbatim

Record the answers in the tester's own words. Do not paraphrase into our
vocabulary.

1. **What was this game about, in your own words?**
2. **Did any choice feel like it mattered? Which one?**
3. **Did you notice anyone unusual? What did you think they were?**
4. **How did you know where to go?**

Questions 3 and 4 are specific to this slice: they are the two things the slice
exists to test. Ask 1 and 2 first and let the tester volunteer the Glimpse
before question 3 names it.

## What a session records

| Field | |
|---|---|
| Tester | first name or initials only |
| Prior connection to Krishna consciousness | none / some / devotee |
| Device | model, Android version |
| Build | the `Build …` line on the title screen |
| Time played | minutes |
| Reached the end screen | yes / no |
| Found Tulu | yes / no |
| Used *Listen* | yes / no |
| Fountain | gave / took / ignored |
| Saw the Glimpse | yes / no / not applicable (did not give) |
| Picked up the feather | yes / no |
| Answers | verbatim, all four |
| Crashes or stalls | what and when |
| Median / lowest fps | from the device matrix in the README |

## Signals that mean a redesign, not a tweak

From GDD §16, plus the slice-specific one:

- **More than 3 of 10 testers say "religious game" before "story" or
  "mystery": pillar 1 is failing.** This is the slice's own gate.
- Testers describe the game as "a religious game" before describing it as a
  story: pillar 1 is failing.
- Testers believe one of the fountain outcomes is the wrong answer and feel
  punished: pillar 3 is failing; review the cards and the lighting steps.
- Nobody opens a wisdom card: fine. Everybody opens them and finds them
  confusing: rewrite the glosses. *(Not testable in Slice 1 — no wisdom cards.)*
- Testers do not notice the Song's return at beat 12: the stem mix or the
  blue-light cue needs to be stronger. *(Not testable in Slice 1.)*

## What the slice is trying to prove

> Does a player follow sound instead of instructions, notice a figure nobody
> else sees, and make one choice that feels like it matters — without anyone
> telling them this is a spiritual game?

Three readings of the result:

- **Follows sound.** Did they find Tulu without a marker? Answer to question 4
  should mention the humming, the boy, or sound — not "I just walked around".
- **Notices the figure.** Did the Glimpse land? Answer to question 3 should be
  unprompted and uncertain ("someone on the traffic light", "a guy with a
  flute?"). Certainty either way is a problem: too vague means they missed it,
  too confident means we over-signposted.
- **One choice that mattered.** Answer to question 2 should name the water can.
  If they name nothing, the three outcomes are not reading as different.

## What is deliberately not measured

No score. No completion percentage shown to the tester. No in-game
questionnaire — this document is the questionnaire, and it lives outside the
build (`CLAUDE_CODE_BRIEF.md` §4.6). No analytics of any kind are in the slice.
