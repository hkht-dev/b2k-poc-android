#!/usr/bin/env python3
"""Check that every data file under data/ parses and carries what the game expects.

CLAUDE_CODE_BRIEF.md §10 keeps strings, flags and quest steps in data rather
than code. That only holds if a malformed data file fails the build instead of
reaching a tester as blank text, so CI runs this on every push.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

# String ids the P0 build renders. Each phase adds the ids it needs.
REQUIRED_STRING_IDS = [
    "app.title",
    "title.begin",
    "title.build_label",
]


def fail(message: str) -> None:
    print(f"check_data: {message}", file=sys.stderr)


def main() -> int:
    problems = 0
    json_files = sorted(DATA.rglob("*.json"))

    if not json_files:
        fail("no JSON files under data/ — the game has no content to load")
        return 1

    for path in json_files:
        rel = path.relative_to(ROOT)
        try:
            parsed = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(f"{rel}: {error}")
            problems += 1
            continue
        if not isinstance(parsed, dict):
            fail(f"{rel}: top level must be an object, found {type(parsed).__name__}")
            problems += 1
            continue
        print(f"ok  {rel} ({len(parsed)} keys)")

    problems += check_strings()

    if problems:
        fail(f"{problems} problem(s)")
        return 1
    print("check_data: all data files are good")
    return 0


def check_strings() -> int:
    """Every locale must carry the same ids, so no language renders a blank."""
    locales = sorted((DATA / "strings").glob("*.json"))
    if not locales:
        fail("data/strings/ has no locale files")
        return 1

    problems = 0
    tables: dict[str, dict] = {}
    for path in locales:
        try:
            tables[path.stem] = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue  # already reported above

    english = tables.get("en")
    if english is None:
        fail("data/strings/en.json is missing; English is the source locale")
        return 1

    for required in REQUIRED_STRING_IDS:
        if required not in english:
            fail(f"data/strings/en.json is missing the id '{required}'")
            problems += 1

    for locale, table in tables.items():
        if locale == "en":
            continue
        for key in english:
            if key not in table:
                fail(f"data/strings/{locale}.json is missing the id '{key}'")
                problems += 1
        for key in table:
            if key not in english:
                fail(f"data/strings/{locale}.json has '{key}', which English does not")
                problems += 1

    return problems


if __name__ == "__main__":
    sys.exit(main())
