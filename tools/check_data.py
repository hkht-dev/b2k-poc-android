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
    "sub.tulu_hum",
    "sub.player_hum",
    "now.boy_humming",
    "now.boy_led",
]

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
        if key.startswith(("line.", "card.")) and len(str(text).split()) > MAX_WORDS:
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


if __name__ == "__main__":
    sys.exit(main())
