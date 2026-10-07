#!/usr/bin/env python3
"""Fail if a pull-request body is missing Definition-of-Ready inputs.

Required headings (must match the PR template):
  Spec / PRD, Acceptance criteria, Design plan, Test

A section is filled when it has text that is not only whitespace or
HTML comments. "N/A" plus a reason counts as filled.

Does not judge whether the spec is good. It only makes a missing
input visible.

Usage:
  PR_BODY="..." python3 check_definition_of_ready.py
  python3 check_definition_of_ready.py < body.md
"""

from __future__ import annotations

import os
import re
import sys

HEADINGS = [
    "Spec / PRD",
    "Acceptance criteria",
    "Design plan",
    "Test",
]

HEADING_RE = re.compile(r"^#{1,6}\s+(?P<title>.+?)\s*$", re.MULTILINE)
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def sections(body: str) -> dict[str, str]:
    matches = list(HEADING_RE.finditer(body))
    found: dict[str, str] = {}
    for i, match in enumerate(matches):
        title = match.group("title").strip()
        start = match.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        found[title] = body[start:end]
    return found


def filled(text: str) -> bool:
    stripped = COMMENT_RE.sub("", text).strip()
    return bool(stripped)


def main() -> int:
    body = os.environ.get("PR_BODY")
    if body is None:
        body = sys.stdin.read()
    if body is None:
        body = ""

    found = sections(body)
    missing: list[str] = []
    for heading in HEADINGS:
        content = found.get(heading)
        if content is None:
            missing.append(f"{heading} (heading missing)")
        elif not filled(content):
            missing.append(f"{heading} (empty)")

    if missing:
        print("Definition of Ready failed. Fill every section in the PR body:")
        for item in missing:
            print(f"  - {item}")
        print("Use N/A plus one line of reason when a section does not apply.")
        return 1

    print("Definition of Ready passed. Spec, acceptance criteria, design plan, and test are present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
