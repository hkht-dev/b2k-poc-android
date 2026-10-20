#!/usr/bin/env python3
"""Check that every data file under data/ parses and carries what the game expects.

CLAUDE_CODE_BRIEF.md §10 keeps strings, flags and quest steps in data rather
than code. That only holds if a malformed data file fails the build instead of
reaching a tester as blank text, so CI runs this on every push.

Mirrors the loaders in scripts/core (quest.gd, dialogue.gd, strings.gd) and
the condition grammar in scripts/lib/condition.gd. If one changes, change the
other.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

# String ids the build renders outside any data file. Each phase adds its own.
REQUIRED_STRING_IDS = [
    "app.title",
    "title.begin",
    "title.build_label",
    "verb.listen",
    "debug.title",
    "debug.flags",
    "debug.events",
    "debug.quests",
    "debug.lines",
    "debug.journey",
    "debug.fire",
    "debug.play",
    "debug.wipe",
    "debug.close",
    "debug.quest_inactive",
    "debug.quest_waiting",
    "debug.quest_ended",
    "debug.empty",
    "controls.title",
    "controls.got_it",
    "controls.close",
    "controls.hint.walk",
    *[f"controls.diagram.{k}" for k in ("move", "look", "tap", "use")],
    *[
        f"controls.{scheme}.{k}"
        for scheme in ("touch", "desktop", "gamepad")
        for k in ("move", "look", "walk_there", "use", "hum")
    ],
    "pause.title",
    "pause.resume",
    "pause.controls",
    "pause.map_on",
    "pause.map_off",
    "verb.idle",
    "verb.talk",
    "verb.look",
    "verb.pick_up",
    "verb.place",
    "speaker.gopal",
    "speaker.fountain",
    "sub.can_placed",
    "journey.glimpse.traffic_light",
    "pause.journey",
    "pause.settings",
    "verb.sit",
    "end.line",
    "end.play_again",
    "settings.title",
    "settings.close",
    *[f"settings.{k}" for k in ("joystick_side", "joystick_size", "joystick_opacity", "camera_sensitivity", "camera_invert_y", "large_text", "subtitle_box", "sound_cues", "tap_to_walk")],
    "sub.tulu_hum",
    "sub.player_hum",
    "now.boy_humming",
    "now.boy_led",
    "verb.enter",
    "verb.leave",
    "settings.compass",
    *[f"compass.{k}" for k in ("north", "east", "south", "west")],
    *[f"controls.{scheme}.places" for scheme in ("touch", "desktop", "gamepad")],
    # the expansion's stages (docs/DECISIONS.md "The world grows")
    "pause.garden",
    *[f"garden.{k}" for k in ("title", "close", "pull", "pulled", "hint", "empty", "creeper")],
    "journey.stray_cows",
    "quest.stray_cows.both",
    *[f"journey.glimpse.{k}" for k in ("tower", "stairwell", "garden", "chai_stall")],
    "speaker.counting_man",
    *[f"count.{k}" for k in ("hint", "total", "stop", "done")],
    "sub.counting_man_laugh",
    "sub.counting_man_note",
    "verb.try_on",
    *[f"wardrobe.{k}" for k in ("title", "done", "prev", "next")],
    "speaker.dhanpal",
    "sign.hall",
    "pause.set_lamp",
    "lamp.title",
    "lamp.cancel",
    "pause.noticed",
    "sign.chai",
    "speaker.chai_seller",
    "speaker.tulu",
    "sub.tulu_points",
    *[f"veil.line.{k}" for k in ("easy", "harder", "never_closed")],
    "speaker.vasanti",
    "verb.fix",
    "sign.garden",
    "sign.garden_rule",
    "verb.drive",
    "verb.exit",
    *[f"controls.{scheme}.drive" for scheme in ("touch", "desktop", "gamepad")],
    "sign.nanda",
    "speaker.rukma",
    "speaker.bhima",
    "speaker.nanda",
    "speaker.thought",
    "speaker.madhuri",
    "speaker.photo",
    "place.shrine",
    "sub.madhuri_chant",
    "sign.office",
    "place.office",
    "place.nanda_flat",
    "wisdom.close",
    "wisdom.read_more",
    "wisdom.lotus",
    *[f"scroll.{k}" for k in ("back", "close", "turn", "roll_up")],
    "sign.tale_seat",
    *[f"tale.sitting.{n}" for n in (1, 2, 3)],
    "verb.hum_here",
    "verb.step_in",
    "verb.garland",
    "place.home",
    "journey.act4.street_listened",
    "journey.act4.alone",
    "journey.act5.home",
    "sign.nanda_brother",
    "journey.dawn.played",
    "journey.dawn.kept",
    "place.grove",
    *[f"verb.{k}" for k in ("dive", "descend", "pet", "push")],
    "sub.lalita_laughs",
    "speaker.lalita",
    "speaker.kuvera",
    "speaker.bubble",
    "end.share",
    "end.card_subtitle",
    "end.card_noticed",
    "controls.key.desktop_use",
    "controls.key.gamepad_use",
]
MAX_PANEL_WORDS = 40
SKINS = {"humanFemaleA", "humanMaleA", "criminalMaleA", "skaterFemaleA", "skaterMaleA", "survivorFemaleA", "survivorMaleB"}
VIGNETTE_REQUIRED = ["id", "giver_name_id", "skin", "spot", "lines", "journey_line_id", "outcomes"]
SEED_SOURCE = re.compile(r"^(flag:\S+|choice:\S+:\d+)$")
PLACE_REQUIRED = ["scene", "name_id"]

QUEST_REQUIRED = ["id", "giver", "start_condition", "steps", "end_condition"]
STEP_REQUIRED = ["id", "objective_text_id", "complete_when"]
BRANCH_REQUIRED = ["id", "when"]
LINE_REQUIRED = ["speaker", "text_id", "cards", "review_status"]
CARD_REQUIRED = ["text_id", "next"]
REVIEW_STATUSES = {"draft", "panel_approved", "final"}
# GDD §8 "Writing rules": lines under 20 words.
MAX_WORDS = 19
TERM = re.compile(r"^(not )?(true|false|flag:\S+|event:\S+)$")


def fail(message: str) -> None:
    print(f"check_data: {message}", file=sys.stderr)


def load(path: Path) -> dict | None:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)}: {error}")
        return None
    if not isinstance(parsed, dict):
        fail(f"{path.relative_to(ROOT)}: top level must be an object")
        return None
    return parsed


def condition_ok(expr: str) -> bool:
    """The tiny grammar of condition.gd: terms joined by ' and ' and ' or '."""
    if not isinstance(expr, str) or not expr.strip():
        return False
    for alternative in expr.strip().split(" or "):
        for term in alternative.split(" and "):
            if not TERM.match(term.strip()):
                return False
    return True


def main() -> int:
    problems = 0
    strings = check_strings()
    if strings is None:
        return 1
    problems += check_quests(strings)
    problems += check_dialogue(strings)
    problems += check_places(strings)
    problems += check_daylight()
    problems += check_vignettes(strings)
    problems += check_garden(strings)
    problems += check_outfits(strings)
    problems += check_lamp_lines(strings)
    problems += check_tells(strings)
    problems += check_wisdom(strings)
    problems += check_tales(strings)
    if problems:
        fail(f"{problems} problem(s)")
        return 1
    print("check_data: all data files are good")
    return 0


def check_strings() -> dict | None:
    """Every locale must carry the same ids, so no language renders a blank."""
    locales = sorted((DATA / "strings").glob("*.json"))
    if not locales:
        fail("data/strings/ has no locale files")
        return None
    tables = {p.stem: load(p) for p in locales}
    english = tables.get("en")
    if english is None:
        fail("data/strings/en.json is missing or malformed; English is the source locale")
        return None
    print(f"ok  data/strings/en.json ({len(english)} ids)")

    problems = 0
    for required in REQUIRED_STRING_IDS:
        if required not in english:
            fail(f"data/strings/en.json is missing the id '{required}'")
            problems += 1
    for key, text in english.items():
        spoken = key.startswith(("line.", "card.")) or re.match(r"^vignette\.[^.]+\.(line|card)\.", key)
        if spoken and len(str(text).split()) > MAX_WORDS:
            fail(f"'{key}' is {len(str(text).split())} words; GDD §8 keeps lines under 20")
            problems += 1
    for locale, table in tables.items():
        if locale == "en" or table is None:
            continue
        for key in english.keys() - table.keys():
            fail(f"data/strings/{locale}.json is missing the id '{key}'")
            problems += 1
        for key in table.keys() - english.keys():
            fail(f"data/strings/{locale}.json has '{key}', which English does not")
            problems += 1
    return None if problems else english


def check_quests(strings: dict) -> int:
    problems = 0
    paths = sorted((DATA / "quests").glob("*.json"))
    if not paths:
        fail("data/quests/ is empty")
        return 1
    seen_ids: set[str] = set()
    for path in paths:
        rel = path.relative_to(ROOT)
        quest = load(path)
        if quest is None:
            problems += 1
            continue
        for key in QUEST_REQUIRED:
            if key not in quest:
                fail(f"{rel}: missing '{key}'")
                problems += 1
        if quest.get("id") in seen_ids:
            fail(f"{rel}: duplicate quest id '{quest.get('id')}'")
            problems += 1
        seen_ids.add(quest.get("id"))
        for key in ("start_condition", "end_condition"):
            if key in quest and not condition_ok(quest[key]):
                fail(f"{rel}: bad {key} '{quest[key]}'")
                problems += 1
        for step in quest.get("steps", []):
            for key in STEP_REQUIRED:
                if key not in step:
                    fail(f"{rel}: step missing '{key}'")
                    problems += 1
            if "complete_when" in step and not condition_ok(step["complete_when"]):
                fail(f"{rel}: step '{step.get('id')}' has bad complete_when")
                problems += 1
            text_id = step.get("objective_text_id", "")
            if text_id and text_id not in strings:
                fail(f"{rel}: step '{step.get('id')}' objective text '{text_id}' not in strings")
                problems += 1
        for branch in quest.get("branches", []):
            for key in BRANCH_REQUIRED:
                if key not in branch:
                    fail(f"{rel}: branch missing '{key}'")
                    problems += 1
            if "when" in branch and not condition_ok(branch["when"]):
                fail(f"{rel}: branch '{branch.get('id')}' has bad when")
                problems += 1
            line_id = branch.get("journey_line_id", "")
            if line_id and line_id not in strings:
                fail(f"{rel}: branch '{branch.get('id')}' journey line '{line_id}' not in strings")
                problems += 1
        line_id = quest.get("journey_line_id", "")
        if line_id and line_id not in strings:
            fail(f"{rel}: journey line '{line_id}' not in strings")
            problems += 1
        print(f"ok  {rel} ({len(quest.get('steps', []))} steps, {len(quest.get('branches', []))} branches)")
    return problems


def check_dialogue(strings: dict) -> int:
    problems = 0
    paths = sorted((DATA / "dialogue").glob("*.json"))
    if not paths:
        fail("data/dialogue/ is empty")
        return 1
    for path in paths:
        rel = path.relative_to(ROOT)
        table = load(path)
        if table is None:
            problems += 1
            continue
        for line_id, line in table.items():
            if not isinstance(line, dict):
                fail(f"{rel}: line '{line_id}' is not an object")
                problems += 1
                continue
            for key in LINE_REQUIRED:
                if key not in line:
                    fail(f"{rel}: line '{line_id}' missing '{key}'")
                    problems += 1
            if line.get("review_status") not in REVIEW_STATUSES:
                fail(f"{rel}: line '{line_id}' review_status '{line.get('review_status')}'")
                problems += 1
            if line.get("text_id") not in strings:
                fail(f"{rel}: line '{line_id}' text '{line.get('text_id')}' not in strings")
                problems += 1
            speaker = line.get("speaker", "")
            if speaker and f"speaker.{speaker}" not in strings:
                fail(f"{rel}: line '{line_id}' speaker 'speaker.{speaker}' not in strings")
                problems += 1
            cards = line.get("cards", [])
            if len(cards) not in (0, 2, 3):
                fail(f"{rel}: line '{line_id}' offers {len(cards)} cards; GDD §6 allows two or three")
                problems += 1
            for card in cards:
                for key in CARD_REQUIRED:
                    if key not in card:
                        fail(f"{rel}: line '{line_id}' card missing '{key}'")
                        problems += 1
                if card.get("text_id") not in strings:
                    fail(f"{rel}: line '{line_id}' card text '{card.get('text_id')}' not in strings")
                    problems += 1
                nxt = card.get("next", "")
                if nxt and nxt not in table:
                    fail(f"{rel}: line '{line_id}' points at missing line '{nxt}'")
                    problems += 1
        print(f"ok  {rel} ({len(table)} lines)")
    return problems


def check_places(strings: dict) -> int:
    """data/places.json: every place names a scene that exists and a name id."""
    path = DATA / "places.json"
    if not path.exists():
        fail("data/places.json is missing")
        return 1
    places = load(path)
    if places is None:
        return 1
    problems = 0
    if "street" not in places:
        fail("data/places.json: no 'street' place")
        problems += 1
    for place_id, entry in places.items():
        if not isinstance(entry, dict):
            fail(f"data/places.json: '{place_id}' is not an object")
            problems += 1
            continue
        for key in PLACE_REQUIRED:
            if key not in entry:
                fail(f"data/places.json: '{place_id}' is missing '{key}'")
                problems += 1
        scene = str(entry.get("scene", ""))
        if not scene.startswith("res://") or not (ROOT / scene[len("res://"):]).exists():
            fail(f"data/places.json: '{place_id}' names a scene that does not exist: {scene}")
            problems += 1
        if entry.get("name_id") not in strings:
            fail(f"data/places.json: '{place_id}' name id '{entry.get('name_id')}' is not a string")
            problems += 1
    if not problems:
        print(f"ok  data/places.json ({len(places)} places)")
    return problems

def check_daylight() -> int:
    """data/daylight.json: ordered stages chosen by flags, the first always on."""
    path = DATA / "daylight.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    problems = 0
    if not isinstance(data.get("transition_seconds"), (int, float)):
        fail("data/daylight.json: 'transition_seconds' must be a number")
        problems += 1
    stages = data.get("stages")
    if not isinstance(stages, list) or not stages:
        fail("data/daylight.json: 'stages' must be a non-empty list")
        return problems + 1
    seen = set()
    for i, stage in enumerate(stages):
        sid = stage.get("id") if isinstance(stage, dict) else None
        if not isinstance(stage, dict) or not sid:
            fail(f"data/daylight.json: stage {i} needs an id")
            problems += 1
            continue
        if sid in seen:
            fail(f"data/daylight.json: stage id '{sid}' repeats")
            problems += 1
        seen.add(sid)
        if not condition_ok(str(stage.get("when", ""))):
            fail(f"data/daylight.json: stage '{sid}' has a bad 'when'")
            problems += 1
        if i == 0 and str(stage.get("when", "")).strip() != "true":
            fail("data/daylight.json: the first stage's 'when' must be 'true'")
            problems += 1
        for key in ("sun_colour", "fog_colour", "sky_tint"):
            value = stage.get(key)
            if not (isinstance(value, list) and len(value) == 3 and all(isinstance(v, (int, float)) and 0 <= v <= 1 for v in value)):
                fail(f"data/daylight.json: stage '{sid}' '{key}' must be three floats in 0..1")
                problems += 1
        for key in ("sun_energy", "sun_elevation_degrees", "sun_azimuth_degrees", "ambient_energy", "fog_density"):
            if not isinstance(stage.get(key), (int, float)):
                fail(f"data/daylight.json: stage '{sid}' '{key}' must be a number")
                problems += 1
        if not isinstance(stage.get("lamps_on"), bool):
            fail(f"data/daylight.json: stage '{sid}' 'lamps_on' must be true or false")
            problems += 1
    if not problems:
        print(f"ok  data/daylight.json ({len(stages)} stages)")
    return problems

def check_lines_table(table: dict, strings: dict, rel: str, dialogue_ids: set | None = None) -> int:
    """The shape of data/dialogue lines, reused for vignette files."""
    problems = 0
    for line_id, line in table.items():
        if not isinstance(line, dict):
            fail(f"{rel}: line '{line_id}' is not an object")
            problems += 1
            continue
        for key in LINE_REQUIRED:
            if key not in line:
                fail(f"{rel}: line '{line_id}' is missing '{key}'")
                problems += 1
        if f"speaker.{line.get('speaker')}" not in strings:
            fail(f"{rel}: line '{line_id}' speaker '{line.get('speaker')}' has no speaker.* string")
            problems += 1
        if line.get("text_id") not in strings:
            fail(f"{rel}: line '{line_id}' text '{line.get('text_id')}' not in strings")
            problems += 1
        if line.get("review_status") not in REVIEW_STATUSES:
            fail(f"{rel}: line '{line_id}' review_status must be one of {sorted(REVIEW_STATUSES)}")
            problems += 1
        cards = line.get("cards", [])
        if not isinstance(cards, list) or len(cards) not in (0, 2, 3):
            fail(f"{rel}: line '{line_id}' offers {len(cards) if isinstance(cards, list) else '?'} cards; GDD §6 allows two or three")
            problems += 1
            cards = cards if isinstance(cards, list) else []
        for card in cards:
            if not isinstance(card, dict):
                fail(f"{rel}: line '{line_id}' has a card that is not an object")
                problems += 1
                continue
            for key in CARD_REQUIRED:
                if key not in card:
                    fail(f"{rel}: line '{line_id}' card is missing '{key}'")
                    problems += 1
            if card.get("text_id") not in strings:
                fail(f"{rel}: line '{line_id}' card text '{card.get('text_id')}' not in strings")
                problems += 1
            nxt = card.get("next", "")
            if nxt and nxt not in table and not (dialogue_ids and nxt in dialogue_ids):
                fail(f"{rel}: line '{line_id}' points at missing line '{nxt}'")
                problems += 1
    return problems


def check_vignettes(strings: dict) -> int:
    """data/vignettes/*.json: one stranger a day, its lines in the dialogue shape."""
    folder = DATA / "vignettes"
    if not folder.is_dir():
        return 0
    dialogue = load(DATA / "dialogue" / "en.json") or {}
    problems = 0
    count = 0
    for path in sorted(folder.glob("*.json")):
        rel = path.relative_to(ROOT)
        data = load(path)
        if data is None:
            problems += 1
            continue
        count += 1
        for key in VIGNETTE_REQUIRED:
            if key not in data:
                fail(f"{rel}: missing '{key}'")
                problems += 1
        vid = str(data.get("id", ""))
        if vid != path.stem:
            fail(f"{rel}: id '{vid}' must equal the file name")
            problems += 1
        if data.get("spot") not in ("a", "b", "c"):
            fail(f"{rel}: spot must be a, b or c")
            problems += 1
        if data.get("skin") not in SKINS:
            fail(f"{rel}: skin '{data.get('skin')}' is not a Kenney skin")
            problems += 1
        for key in ("giver_name_id", "journey_line_id"):
            if data.get(key) not in strings:
                fail(f"{rel}: '{key}' '{data.get(key)}' not in strings")
                problems += 1
        lines = data.get("lines", {})
        if not isinstance(lines, dict) or not lines:
            fail(f"{rel}: 'lines' must be a non-empty object")
            problems += 1
            continue
        problems += check_lines_table(lines, strings, str(rel), set(dialogue))
        set_flags = set()
        for line_id, line in lines.items():
            if not line_id.startswith(f"vignette_{vid}_"):
                fail(f"{rel}: line id '{line_id}' must start with 'vignette_{vid}_'")
                problems += 1
            if line_id in dialogue:
                fail(f"{rel}: line id '{line_id}' clashes with data/dialogue/en.json")
                problems += 1
            for card in line.get("cards", []) if isinstance(line, dict) else []:
                for flag in card.get("sets", []) if isinstance(card, dict) else []:
                    set_flags.add(flag)
        outcomes = set(data.get("outcomes", []))
        if outcomes != set_flags:
            fail(f"{rel}: outcomes {sorted(outcomes)} must be exactly the flags the cards set {sorted(set_flags)}")
            problems += 1
    if not problems:
        print(f"ok  data/vignettes ({count} vignettes)")
    return problems


def check_garden(strings: dict) -> int:
    """data/garden.json: seeds from flags and choices, the creeper, the waters."""
    path = DATA / "garden.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    problems = 0
    seeds = data.get("seeds")
    if not isinstance(seeds, list) or not seeds:
        fail("data/garden.json: 'seeds' must be a non-empty list")
        return problems + 1
    for seed in seeds:
        if not isinstance(seed, dict):
            fail("data/garden.json: a seed is not an object")
            problems += 1
            continue
        if not SEED_SOURCE.match(str(seed.get("source", ""))):
            fail(f"data/garden.json: seed source '{seed.get('source')}' must be flag:<name> or choice:<line>:<index>")
            problems += 1
        if seed.get("kind") not in ("sweet", "bitter", "weed"):
            fail(f"data/garden.json: seed '{seed.get('source')}' kind must be sweet, bitter or weed")
            problems += 1
        if seed.get("sentence_id") not in strings:
            fail(f"data/garden.json: seed sentence '{seed.get('sentence_id')}' not in strings")
            problems += 1
    creeper = data.get("creeper", {})
    if not isinstance(creeper, dict) or creeper.get("sentence_id") not in strings or not creeper.get("given_flag"):
        fail("data/garden.json: 'creeper' needs a sentence_id in strings and a given_flag")
        problems += 1
    waters = data.get("waters", {}).get("flags") if isinstance(data.get("waters"), dict) else None
    if not isinstance(waters, list) or not all(isinstance(f, str) for f in waters):
        fail("data/garden.json: 'waters.flags' must be a list of flag names")
        problems += 1
    growth = data.get("growth", {})
    for key in ("sapling_after_days", "fruiting_after_days"):
        if not isinstance(growth, dict) or not isinstance(growth.get(key), int):
            fail(f"data/garden.json: 'growth.{key}' must be an integer")
            problems += 1
    if not problems:
        print(f"ok  data/garden.json ({len(seeds)} seeds)")
    return problems

def check_outfits(strings: dict) -> int:
    """data/outfits.json: what the showroom's wardrobe offers."""
    path = DATA / "outfits.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    problems = 0
    outfits = data.get("outfits")
    if not isinstance(outfits, list) or not outfits:
        fail("data/outfits.json: 'outfits' must be a non-empty list")
        return 1
    ids = []
    for outfit in outfits:
        if not isinstance(outfit, dict) or not all(k in outfit for k in ("id", "name_id", "skin")):
            fail("data/outfits.json: every outfit needs id, name_id and skin")
            problems += 1
            continue
        ids.append(outfit["id"])
        if outfit["name_id"] not in strings:
            fail(f"data/outfits.json: '{outfit['id']}' name '{outfit['name_id']}' not in strings")
            problems += 1
        skin = str(outfit["skin"])
        if not skin.startswith("res://assets/thirdparty/kenney/") or not (ROOT / skin[len("res://"):]).exists():
            fail(f"data/outfits.json: '{outfit['id']}' skin '{skin}' is not a Kenney skin in the repository")
            problems += 1
    if len(set(ids)) != len(ids):
        fail("data/outfits.json: outfit ids repeat")
        problems += 1
    if data.get("default") not in ids:
        fail("data/outfits.json: 'default' must be one of the outfit ids")
        problems += 1
    if not problems:
        print(f"ok  data/outfits.json ({len(ids)} outfits)")
    return problems


def check_lamp_lines(strings: dict) -> int:
    """data/lamp_lines.json: twelve preset lines, nothing free-text."""
    path = DATA / "lamp_lines.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    problems = 0
    lines = data.get("lines")
    if not isinstance(lines, list) or len(lines) != 12:
        fail("data/lamp_lines.json: exactly twelve 'lines' (GDD §16a)")
        problems += 1
        lines = lines if isinstance(lines, list) else []
    for line_id in lines:
        if line_id not in strings:
            fail(f"data/lamp_lines.json: line '{line_id}' not in strings")
            problems += 1
    for key in ("days", "max_per_place", "seconds_per_day"):
        if not isinstance(data.get(key), int) or data.get(key) <= 0:
            fail(f"data/lamp_lines.json: '{key}' must be a positive integer")
            problems += 1
    if not problems:
        print(f"ok  data/lamp_lines.json ({len(lines)} lines)")
    return problems


def check_tells(strings: dict) -> int:
    """data/tells.json: small wrongnesses, each with its sentence and place."""
    path = DATA / "tells.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    places = load(DATA / "places.json") or {}
    problems = 0
    tells = data.get("tells")
    if not isinstance(tells, list) or not tells:
        fail("data/tells.json: 'tells' must be a non-empty list")
        return 1
    ids = set()
    for tell in tells:
        if not isinstance(tell, dict) or not tell.get("id"):
            fail("data/tells.json: every tell needs an id")
            problems += 1
            continue
        if tell["id"] in ids:
            fail(f"data/tells.json: id '{tell['id']}' repeats")
            problems += 1
        ids.add(tell["id"])
        if tell.get("sentence_id") not in strings:
            fail(f"data/tells.json: '{tell['id']}' sentence '{tell.get('sentence_id')}' not in strings")
            problems += 1
        if tell.get("place") not in places:
            fail(f"data/tells.json: '{tell['id']}' place '{tell.get('place')}' is not in data/places.json")
            problems += 1
        if "requires_humming" in tell and not isinstance(tell["requires_humming"], bool):
            fail(f"data/tells.json: '{tell['id']}' requires_humming must be true or false")
            problems += 1
    for key in strings:
        if key.startswith("tell.") and key[len("tell."):] not in ids:
            fail(f"data/tells.json: string '{key}' has no tell row")
            problems += 1
    if not problems:
        print(f"ok  data/tells.json ({len(ids)} tells)")
    return problems

def check_wisdom(strings: dict) -> int:
    """data/wisdom.json: optional cards, each with a trigger and four strings."""
    path = DATA / "wisdom.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    problems = 0
    cards = data.get("cards")
    if not isinstance(cards, list) or not cards:
        fail("data/wisdom.json: 'cards' must be a non-empty list")
        return 1
    ids = set()
    for card in cards:
        if not isinstance(card, dict) or not card.get("id"):
            fail("data/wisdom.json: every card needs an id")
            problems += 1
            continue
        cid = card["id"]
        if cid in ids:
            fail(f"data/wisdom.json: card id '{cid}' repeats")
            problems += 1
        ids.add(cid)
        for key in ("trigger", "verse_id", "meaning_id", "more_id", "source_id"):
            if key not in card:
                fail(f"data/wisdom.json: card '{cid}' is missing '{key}'")
                problems += 1
        if not condition_ok(str(card.get("trigger", ""))):
            fail(f"data/wisdom.json: card '{cid}' has a bad trigger")
            problems += 1
        for key in ("verse_id", "meaning_id", "more_id", "source_id"):
            if card.get(key) not in strings:
                fail(f"data/wisdom.json: card '{cid}' {key} '{card.get(key)}' not in strings")
                problems += 1
        meaning = str(strings.get(card.get("meaning_id", ""), ""))
        if len([s for s in re.split(r"[.!?]+", meaning) if s.strip()]) > 2:
            fail(f"data/wisdom.json: card '{cid}' meaning runs past two sentences (GDD §6)")
            problems += 1
        if card.get("review_status") not in REVIEW_STATUSES:
            fail(f"data/wisdom.json: card '{cid}' review_status must be one of {sorted(REVIEW_STATUSES)}")
            problems += 1
    if not problems:
        print(f"ok  data/wisdom.json ({len(ids)} cards)")
    return problems


def check_tales(strings: dict) -> int:
    """data/tales.json: tales told on a scroll, in sittings of short panels."""
    path = DATA / "tales.json"
    if not path.exists():
        return 0
    data = load(path)
    if data is None:
        return 1
    problems = 0
    tales = data.get("tales")
    if not isinstance(tales, list) or not tales:
        fail("data/tales.json: 'tales' must be a non-empty list")
        return 1
    for tale in tales:
        if not isinstance(tale, dict) or not tale.get("id"):
            fail("data/tales.json: every tale needs an id")
            problems += 1
            continue
        tid = tale["id"]
        for key in ("title_id", "source_id", "journey_line_id"):
            if tale.get(key) not in strings:
                fail(f"data/tales.json: tale '{tid}' {key} '{tale.get(key)}' not in strings")
                problems += 1
        if tale.get("review_status") not in REVIEW_STATUSES:
            fail(f"data/tales.json: tale '{tid}' review_status must be one of {sorted(REVIEW_STATUSES)}")
            problems += 1
        sittings = tale.get("sittings")
        if not isinstance(sittings, list) or not sittings or not all(isinstance(s, list) and s for s in sittings):
            fail(f"data/tales.json: tale '{tid}' needs non-empty sittings of panels")
            problems += 1
            continue
        for sitting in sittings:
            for panel_id in sitting:
                if panel_id not in strings:
                    fail(f"data/tales.json: tale '{tid}' panel '{panel_id}' not in strings")
                    problems += 1
                elif len(str(strings[panel_id]).split()) > MAX_PANEL_WORDS:
                    fail(f"data/tales.json: panel '{panel_id}' runs past {MAX_PANEL_WORDS} words")
                    problems += 1
    if not problems:
        print(f"ok  data/tales.json ({len(tales)} tales)")
    return problems


if __name__ == "__main__":
    sys.exit(main())
