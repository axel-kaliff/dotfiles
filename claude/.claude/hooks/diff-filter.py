#!/usr/bin/env python3
"""Filter linter output to only show violations on lines changed in the working tree.

Reads `git diff --unified=0 HEAD` to build a set of (file, line) pairs that were
added or modified.  Then filters stdin (ruff/ty output in `file:line:...` format)
to only pass through lines whose file:line falls within a changed hunk.

Usage:
    ruff check file1.py file2.py | python3 diff-filter.py
    ty check --output-format concise file1.py | python3 diff-filter.py
"""

from __future__ import annotations

import re
import subprocess
import sys


def _get_changed_lines() -> dict[str, set[int]]:
    """Parse git diff to get changed line numbers per file."""
    result = subprocess.run(
        ['git', 'diff', '--unified=0', 'HEAD'],
        capture_output=True,
        text=True,
    )
    changed: dict[str, set[int]] = {}
    current_file: str | None = None

    for line in result.stdout.splitlines():
        if line.startswith('+++ b/'):
            current_file = line[6:]
        elif line.startswith('@@') and current_file is not None:
            # Parse @@ -old,count +new,count @@ format
            match = re.search(r'\+(\d+)(?:,(\d+))?', line)
            if match:
                start = int(match.group(1))
                count = int(match.group(2)) if match.group(2) else 1
                if current_file not in changed:
                    changed[current_file] = set()
                changed[current_file].update(range(start, start + count))

    return changed


def main() -> None:
    changed = _get_changed_lines()
    # file:line: pattern (covers both ruff and ty output)
    line_pattern = re.compile(r'^(.+?):(\d+):')

    for line in sys.stdin:
        match = line_pattern.match(line)
        if match:
            filepath = match.group(1)
            lineno = int(match.group(2))
            if filepath in changed and lineno in changed[filepath]:
                sys.stdout.write(line)
        # Pass through non-file:line lines (summaries, etc) — skip them
        # to only output matching violations


if __name__ == '__main__':
    main()
