#!/usr/bin/env python3
"""
© 2026 sics.ai

Semantic code duplication checker.

Uses griffe to extract class/dataclass/protocol definitions from Python
packages, then computes pairwise field overlap to find types that should
be consolidated.

Usage:
    # Compare all types in two packages
    dedup-check world simulation.robosuite_sim

    # Compare new branch code against the full codebase
    dedup-check --branch-diff src/

    # Check a single package against everything
    dedup-check --against src/ simulation.robosuite_sim

Requires: griffe (install via `uv tool install griffe`)
"""

from __future__ import annotations

import argparse
import json
import logging
import subprocess
import sys
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from pathlib import Path

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class TypeDef:
    """Extracted definition of a class/dataclass/protocol."""

    name: str
    path: str  # e.g. 'world.robot_cell.RobotBodySpec'
    filepath: str
    lineno: int
    kind: str  # 'dataclass', 'protocol', 'class'
    fields: frozenset[str] = field(default_factory=frozenset)
    methods: frozenset[str] = field(default_factory=frozenset)


@dataclass(frozen=True)
class Overlap:
    """Overlap between two type definitions."""

    a: TypeDef
    b: TypeDef
    shared_fields: frozenset[str]
    fuzzy_matches: tuple[tuple[str, str], ...]  # (field_a, field_b) pairs
    score: float  # 0.0 to 1.0


# ---------------------------------------------------------------------------
# Griffe integration
# ---------------------------------------------------------------------------

GRIFFE_CMD = 'griffe'


def _run_griffe(packages: list[str], search_paths: list[str]) -> dict[str, object]:
    """Run griffe dump and return parsed JSON."""
    cmd = [GRIFFE_CMD, 'dump', '--full']
    for sp in search_paths:
        cmd.extend(['-s', sp])
    cmd.extend(packages)

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        logger.warning('griffe failed: %s', result.stderr[:500])
        return {}

    stdout = result.stdout.strip()
    if not stdout:
        return {}
    return json.loads(stdout)


def _expr_to_str(expr: dict[str, object] | str | None) -> str:
    """Convert a griffe annotation expression to a readable string."""
    if expr is None:
        return ''
    if isinstance(expr, str):
        return expr
    cls = expr.get('cls', '')
    if cls == 'ExprName':
        return str(expr.get('name', ''))
    if cls == 'ExprSubscript':
        left = _expr_to_str(expr.get('left'))
        sl = _expr_to_str(expr.get('slice'))
        return f'{left}[{sl}]'
    if cls == 'ExprBinOp':
        left = _expr_to_str(expr.get('left'))
        right = _expr_to_str(expr.get('right'))
        return f'{left} | {right}'
    if cls == 'ExprTuple':
        elems = [_expr_to_str(e) for e in expr.get('elements', [])]
        return ', '.join(elems)
    if cls == 'ExprConstant':
        return str(expr.get('value', ''))
    return str(expr.get('name', expr.get('cls', '?')))


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------


def _extract_types_from_member(
    member: dict[str, object],
    filepath: str,
) -> list[TypeDef]:
    """Recursively extract TypeDefs from a griffe member dict."""
    results: list[TypeDef] = []
    kind = member.get('kind')

    if kind == 'class':
        labels = member.get('labels', [])
        members = member.get('members', {})

        # Determine class kind
        if 'dataclass' in labels:
            cls_kind = 'dataclass'
        elif 'protocol' in labels or _is_protocol(member):
            cls_kind = 'protocol'
        else:
            cls_kind = 'class'

        # Extract fields (attributes) and methods
        fields: set[str] = set()
        methods: set[str] = set()
        for mname, mval in members.items():
            if isinstance(mval, dict):
                mkind = mval.get('kind')
                if mkind == 'attribute' and not mname.startswith('_'):
                    fields.add(mname)
                elif mkind == 'function' and not mname.startswith('_'):
                    methods.add(mname)

        if fields or methods:
            results.append(TypeDef(
                name=member.get('name', '?'),
                path=member.get('path', '?'),
                filepath=filepath,
                lineno=member.get('lineno', 0),
                kind=cls_kind,
                fields=frozenset(fields),
                methods=frozenset(methods),
            ))

    # Recurse into module members
    if kind == 'module':
        mod_filepath = member.get('filepath', filepath)
        for mval in member.get('members', {}).values():
            if isinstance(mval, dict):
                results.extend(_extract_types_from_member(mval, str(mod_filepath)))

    return results


def _is_protocol(member: dict[str, object]) -> bool:
    """Check if a class member inherits from Protocol."""
    bases = member.get('bases', [])
    for base in bases:
        if isinstance(base, dict):
            name = base.get('name', '')
            if name == 'Protocol':
                return True
        elif isinstance(base, str) and 'Protocol' in base:
            return True
    return False


def extract_types(griffe_data: dict[str, object]) -> list[TypeDef]:
    """Extract all TypeDefs from griffe dump output."""
    results: list[TypeDef] = []
    for pkg_data in griffe_data.values():
        if isinstance(pkg_data, dict):
            results.extend(_extract_types_from_member(pkg_data, ''))
    return results


# ---------------------------------------------------------------------------
# Overlap computation
# ---------------------------------------------------------------------------

# Common field name synonyms that indicate semantic equivalence
SYNONYMS: list[tuple[str, str]] = [
    ('name', 'label'),
    ('body_name', 'site_name'),
    ('ee_body_name', 'ee_site_name'),
    ('tracker_body_name', 'ee_body_name'),
    ('ctrl_index', 'actuator_index'),
    ('range_min', 'min'),
    ('range_max', 'max'),
]


def _fuzzy_field_match(a: str, b: str) -> bool:
    """Check if two field names are semantically similar."""
    if a == b:
        return True

    # Check synonym pairs
    for s1, s2 in SYNONYMS:
        if (s1 in a and s2 in b) or (s2 in a and s1 in b):
            return True

    # Check suffix match (e.g. 'gripper_range_min' ≈ 'range_min')
    a_parts = a.split('_')
    b_parts = b.split('_')
    if len(a_parts) >= 2 and len(b_parts) >= 2:
        if a_parts[-2:] == b_parts[-2:]:
            return True

    # Sequence similarity
    ratio = SequenceMatcher(None, a, b).ratio()
    return ratio > 0.75


def compute_overlap(a: TypeDef, b: TypeDef) -> Overlap | None:
    """Compute field overlap between two types. Returns None if no overlap."""
    if a.path == b.path:
        return None

    # Exact field matches
    shared = a.fields & b.fields

    # Fuzzy matches (excluding already-matched exact fields)
    a_remaining = a.fields - shared
    b_remaining = b.fields - shared
    fuzzy: list[tuple[str, str]] = []
    used_b: set[str] = set()

    for fa in sorted(a_remaining):
        for fb in sorted(b_remaining - used_b):
            if _fuzzy_field_match(fa, fb):
                fuzzy.append((fa, fb))
                used_b.add(fb)
                break

    total_matches = len(shared) + len(fuzzy)
    if total_matches == 0:
        return None

    # Jaccard-like score: matches / union of all fields
    union_size = len(a.fields | b.fields)
    score = total_matches / union_size if union_size > 0 else 0.0

    return Overlap(
        a=a,
        b=b,
        shared_fields=shared,
        fuzzy_matches=tuple(fuzzy),
        score=score,
    )


def find_overlaps(
    types: list[TypeDef],
    min_score: float = 0.3,
    min_fields: int = 2,
) -> list[Overlap]:
    """Find all pairwise overlaps above the threshold."""
    overlaps: list[Overlap] = []

    for i, a in enumerate(types):
        for b in types[i + 1:]:
            # Skip if same module (internal overlaps are expected)
            a_module = '.'.join(a.path.split('.')[:-1])
            b_module = '.'.join(b.path.split('.')[:-1])
            if a_module == b_module:
                continue

            overlap = compute_overlap(a, b)
            if overlap is None:
                continue

            total_matches = len(overlap.shared_fields) + len(overlap.fuzzy_matches)
            if overlap.score >= min_score and total_matches >= min_fields:
                overlaps.append(overlap)

    overlaps.sort(key=lambda o: o.score, reverse=True)
    return overlaps


# ---------------------------------------------------------------------------
# Git integration
# ---------------------------------------------------------------------------


def get_new_files_on_branch(main_branch: str = 'master') -> list[str]:
    """Get Python files added on the current branch vs main."""
    result = subprocess.run(
        ['git', 'diff', '--diff-filter=A', '--name-only', f'{main_branch}..HEAD', '--', '*.py'],
        capture_output=True, text=True,
    )
    return [f for f in result.stdout.strip().splitlines() if f]


def get_changed_files_on_branch(main_branch: str = 'master') -> list[str]:
    """Get Python files changed on the current branch vs main."""
    result = subprocess.run(
        ['git', 'diff', '--name-only', f'{main_branch}..HEAD', '--', '*.py'],
        capture_output=True, text=True,
    )
    return [f for f in result.stdout.strip().splitlines() if f]


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


def format_report(overlaps: list[Overlap], types: list[TypeDef]) -> str:
    """Format overlap findings as a readable report."""
    lines: list[str] = []
    lines.append('## Dedup Check Report')
    lines.append('')

    if not overlaps:
        lines.append(f'No significant overlaps found among {len(types)} types.')
        lines.append('')
        lines.append('### Types Checked')
        for t in sorted(types, key=lambda t: t.path):
            lines.append(f'- `{t.path}` ({t.kind}, {len(t.fields)} fields)')
        return '\n'.join(lines)

    lines.append(f'Found {len(overlaps)} potential duplication(s) among {len(types)} types:')
    lines.append('')

    for i, ov in enumerate(overlaps, 1):
        pct = int(ov.score * 100)
        lines.append(f'### {i}. {ov.a.name} ↔ {ov.b.name} ({pct}% overlap)')
        lines.append('')

        rel_a = _relative_path(ov.a.filepath)
        rel_b = _relative_path(ov.b.filepath)
        lines.append(f'- **{ov.a.name}** (`{rel_a}:{ov.a.lineno}`) — '
                      f'{ov.a.kind} with {len(ov.a.fields)} fields')
        lines.append(f'- **{ov.b.name}** (`{rel_b}:{ov.b.lineno}`) — '
                      f'{ov.b.kind} with {len(ov.b.fields)} fields')
        lines.append('')

        if ov.shared_fields:
            lines.append(f'  **Exact matches**: {", ".join(sorted(ov.shared_fields))}')

        if ov.fuzzy_matches:
            fuzzy_strs = [f'{a}≈{b}' for a, b in ov.fuzzy_matches]
            lines.append(f'  **Fuzzy matches**: {", ".join(fuzzy_strs)}')

        # Show fields unique to each
        all_matched_a = ov.shared_fields | {f[0] for f in ov.fuzzy_matches}
        all_matched_b = ov.shared_fields | {f[1] for f in ov.fuzzy_matches}
        only_a = ov.a.fields - all_matched_a
        only_b = ov.b.fields - all_matched_b
        if only_a:
            lines.append(f'  **Only in {ov.a.name}**: {", ".join(sorted(only_a))}')
        if only_b:
            lines.append(f'  **Only in {ov.b.name}**: {", ".join(sorted(only_b))}')

        lines.append('')

    return '\n'.join(lines)


def _relative_path(filepath: str) -> str:
    """Convert absolute path to relative from cwd."""
    try:
        return str(Path(filepath).relative_to(Path.cwd()))
    except ValueError:
        return filepath


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    """Run the dedup checker."""
    parser = argparse.ArgumentParser(
        prog='dedup-check',
        description='Find semantic code duplication via field overlap analysis.',
    )
    parser.add_argument(
        'packages',
        nargs='*',
        help='Python packages to compare (e.g. world simulation.robosuite_sim)',
    )
    parser.add_argument(
        '-s', '--search-path',
        action='append',
        default=[],
        dest='search_paths',
        help='Search paths for griffe (e.g. src/)',
    )
    parser.add_argument(
        '--min-score',
        type=float,
        default=0.3,
        help='Minimum overlap score to report (0.0-1.0, default: 0.3)',
    )
    parser.add_argument(
        '--min-fields',
        type=int,
        default=2,
        help='Minimum matching fields to report (default: 2)',
    )
    parser.add_argument(
        '--branch-diff',
        action='store_true',
        help='Auto-detect changed packages from git branch diff',
    )
    parser.add_argument(
        '--main-branch',
        default='master',
        help='Main branch name for --branch-diff (default: master)',
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Show all extracted types',
    )

    args = parser.parse_args(argv)

    # Determine search paths
    search_paths = args.search_paths or ['src']

    # Determine packages to scan
    packages = list(args.packages)
    if not packages and args.branch_diff:
        # Auto-detect from git diff
        changed = get_changed_files_on_branch(args.main_branch)
        pkg_set: set[str] = set()
        for f in changed:
            parts = Path(f).parts
            if len(parts) >= 2 and parts[0] == 'src':
                # Extract top-level package under src/
                pkg_set.add(parts[1])
        packages = sorted(pkg_set)
        if not packages:
            print('No changed Python packages found on branch.')
            return 0
        print(f'Branch packages: {", ".join(packages)}', file=sys.stderr)

        # Also scan shared layers for comparison
        for shared in ('world', 'utils'):
            if shared not in packages:
                packages.append(shared)

    if not packages:
        parser.error('Provide package names or use --branch-diff')
        return 1

    # Run griffe
    print(f'Scanning: {", ".join(packages)}', file=sys.stderr)
    griffe_data = _run_griffe(packages, search_paths)
    if not griffe_data:
        print('Error: griffe returned no data', file=sys.stderr)
        return 1

    # Extract types
    types = extract_types(griffe_data)
    print(f'Extracted {len(types)} types', file=sys.stderr)

    if args.verbose:
        for t in sorted(types, key=lambda t: t.path):
            print(f'  {t.kind:10s} {t.path} — fields: {sorted(t.fields)}', file=sys.stderr)

    # Find overlaps
    overlaps = find_overlaps(types, min_score=args.min_score, min_fields=args.min_fields)

    # Report
    report = format_report(overlaps, types)
    print(report)

    return 1 if overlaps else 0


if __name__ == '__main__':
    sys.exit(main())
