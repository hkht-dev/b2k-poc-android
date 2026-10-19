#!/usr/bin/env python3
"""Generate the README's QR code for the latest sideloadable build.

CLAUDE_CODE_BRIEF.md §8 asks for "a QR code image (generated in CI with a
checked-in script) linking to the latest APK release".

The QR encodes GitHub's permanent /releases/latest URL rather than a specific
build, so the image never goes stale and CI never has to push to main. CI runs
this with --check, which fails if the committed image no longer matches what
this script would produce.

    python3 tools/gen_qr.py            # write the image
    python3 tools/gen_qr.py --check    # fail if the committed image is stale
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

import qrcode

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "docs" / "assets" / "qr-latest-release.png"
RELEASES_URL = "https://github.com/hkht-dev/b2k-poc-android/releases/latest"


def render() -> bytes:
    code = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=4,
    )
    code.add_data(RELEASES_URL)
    code.make(fit=True)
    # Timber brown on parchment cream, the UI palette of GDD §10.
    image = code.make_image(fill_color="#6B4F35", back_color="#F4ECD8")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the committed image differs from a fresh render",
    )
    args = parser.parse_args()

    fresh = render()

    if args.check:
        if not OUTPUT.exists():
            print(f"gen_qr: {OUTPUT.relative_to(ROOT)} is missing", file=sys.stderr)
            return 1
        if OUTPUT.read_bytes() != fresh:
            print(
                f"gen_qr: {OUTPUT.relative_to(ROOT)} is out of date; "
                "run tools/gen_qr.py and commit the result",
                file=sys.stderr,
            )
            return 1
        print(f"gen_qr: {OUTPUT.relative_to(ROOT)} is current ({RELEASES_URL})")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(fresh)
    print(f"gen_qr: wrote {OUTPUT.relative_to(ROOT)} -> {RELEASES_URL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
