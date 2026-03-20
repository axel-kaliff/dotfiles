#!/usr/bin/env python3
"""
© 2026 sics.ai

Test separation checker — AST-based validation of unit/integration test boundaries.

Implements rules TS-001 through TS-008:
  TS-001  ERROR  File in tests/unit/ contains integration signal imports
  TS-002  ERROR  File in tests/unit/ has @pytest.mark.integration
  TS-003  ERROR  File has both @pytest.mark.unit and @pytest.mark.integration
  TS-004  WARN   File in tests/integration/ has no @pytest.mark.integration marker
  TS-005  WARN   File in tests/integration/ looks like a unit test
  TS-006  WARN   Test file not in tests/unit/ or tests/integration/
  TS-007  ERROR  tests/unit/conftest.py contains integration signal imports
  TS-008  WARN   tests/integration/conftest.py defines mock-returning fixtures

Usage:
    python check_test_sep.py [path | file | 'changed']
    python check_test_sep.py tests/
    python check_test_sep.py tests/unit/test_foo.py
"""

from __future__ import annotations

import ast
import argparse
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Integration signal patterns (module-level imports that indicate I/O)
# ---------------------------------------------------------------------------

INTEGRATION_IMPORT_MODULES: frozenset[str] = frozenset({
    'psycopg', 'psycopg2', 'asyncpg', 'pymongo', 'redis',
    'testcontainers', 'docker',
    'socket', 'urllib.request',
})

INTEGRATION_IMPORT_NAMES: frozenset[tuple[str, str]] = frozenset({
    ('sqlalchemy', 'create_engine'),
    ('subprocess', 'run'),
    ('subprocess', 'Popen'),
    ('subprocess', 'call'),
    ('subprocess', 'check_call'),
    ('subprocess', 'check_output'),
})

INTEGRATION_FULL_MODULES: frozenset[str] = frozenset({
    'subprocess',
})

# Patterns detected via AST call analysis (not just imports)
INTEGRATION_CALL_PATTERNS: frozenset[str] = frozenset({
    'requests.get', 'requests.post', 'requests.put',
    'requests.delete', 'requests.patch', 'requests.Session',
    'httpx.Client', 'httpx.AsyncClient',
    'subprocess.run', 'subprocess.Popen',
    'socket.connect',
})

MOCK_NAMES: frozenset[str] = frozenset({
    'patch', 'MagicMock', 'AsyncMock', 'Mock',
})


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Violation:
    """A single rule violation."""

    code: str
    severity: str  # 'ERROR' or 'WARN'
    message: str
    line: int


@dataclass(frozen=True)
class FileResult:
    """Analysis result for a single file."""

    path: str
    location: str  # 'unit', 'integration', or 'unclassified'
    violations: tuple[Violation, ...]


# ---------------------------------------------------------------------------
# AST visitors
# ---------------------------------------------------------------------------


@dataclass
class _FileAnalysis:
    """Mutable accumulator used during AST walk."""

    has_mark_integration: bool = False
    has_mark_unit: bool = False
    integration_imports: list[tuple[int, str]] = field(default_factory=list)
    mock_count: int = 0
    has_integration_calls: bool = False
    mock_fixture_lines: list[int] = field(default_factory=list)


def _is_pytest_mark(node: ast.Attribute, marker: str) -> bool:
    """Check if an attribute chain matches pytest.mark.<marker>."""
    # pytest.mark.integration or pytest.mark.unit
    if not (isinstance(node, ast.Attribute) and node.attr == marker):
        return False
    mid = node.value
    if not (isinstance(mid, ast.Attribute) and mid.attr == 'mark'):
        return False
    base = mid.value
    return isinstance(base, ast.Name) and base.id == 'pytest'


def _walk_decorators(
    decorators: list[ast.expr],
    marker: str,
) -> bool:
    """Check if any decorator is pytest.mark.<marker> or its call variant."""
    for dec in decorators:
        target = dec.func if isinstance(dec, ast.Call) else dec
        if isinstance(target, ast.Attribute) and _is_pytest_mark(target, marker):
            return True
    return False


def _check_import_integration(node: ast.Import) -> list[tuple[int, str]]:
    """Check a plain import statement for integration signals."""
    hits: list[tuple[int, str]] = []
    for alias in node.names:
        mod = alias.name
        if mod in INTEGRATION_IMPORT_MODULES or mod in INTEGRATION_FULL_MODULES:
            hits.append((node.lineno, f'import {mod}'))
        # Check parent packages (e.g. 'psycopg.sql' matches 'psycopg')
        parts = mod.split('.')
        for i in range(1, len(parts)):
            parent = '.'.join(parts[:i])
            if parent in INTEGRATION_IMPORT_MODULES:
                hits.append((node.lineno, f'import {mod}'))
                break
    return hits


def _check_importfrom_integration(
    node: ast.ImportFrom,
) -> list[tuple[int, str]]:
    """Check a from...import statement for integration signals."""
    hits: list[tuple[int, str]] = []
    mod = node.module or ''

    # Full module match
    if mod in INTEGRATION_IMPORT_MODULES or mod in INTEGRATION_FULL_MODULES:
        hits.append((node.lineno, f'from {mod} import ...'))
        return hits

    # Parent package match
    parts = mod.split('.')
    for i in range(1, len(parts)):
        parent = '.'.join(parts[:i])
        if parent in INTEGRATION_IMPORT_MODULES:
            hits.append((node.lineno, f'from {mod} import ...'))
            return hits

    # Specific name match (e.g. from sqlalchemy import create_engine)
    for alias in node.names:
        if (mod, alias.name) in INTEGRATION_IMPORT_NAMES:
            hits.append((node.lineno, f'from {mod} import {alias.name}'))

    return hits


def _count_mock_usage(source: str) -> int:
    """Count mock-related patterns in source text (covers decorators and calls)."""
    count = 0
    for line in source.splitlines():
        stripped = line.strip()
        for name in MOCK_NAMES:
            if name in stripped:
                count += 1
                break  # count each line at most once
    return count


def _check_mock_fixtures(tree: ast.Module) -> list[int]:
    """Find fixtures in conftest that return MagicMock/AsyncMock."""
    lines: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        # Check if it has @pytest.fixture decorator
        is_fixture = False
        for dec in node.decorator_list:
            target = dec.func if isinstance(dec, ast.Call) else dec
            if isinstance(target, ast.Attribute) and target.attr == 'fixture':
                is_fixture = True
            elif isinstance(target, ast.Name) and target.id == 'fixture':
                is_fixture = True
        if not is_fixture:
            continue

        # Check return statements for MagicMock / AsyncMock
        for child in ast.walk(node):
            if isinstance(child, (ast.Return, ast.Yield)):
                val = child.value
                if val is None:
                    continue
                # Check for MagicMock() or AsyncMock() call
                if isinstance(val, ast.Call) and isinstance(val.func, ast.Name):
                    if val.func.id in ('MagicMock', 'AsyncMock'):
                        lines.append(node.lineno)
                        break
                # Check for MagicMock / AsyncMock name reference
                if isinstance(val, ast.Name) and val.id in ('MagicMock', 'AsyncMock'):
                    lines.append(node.lineno)
                    break
    return lines


# ---------------------------------------------------------------------------
# File analysis
# ---------------------------------------------------------------------------


def _classify_location(filepath: str) -> str:
    """Classify a file as 'unit', 'integration', or 'unclassified'."""
    parts = Path(filepath).parts
    for i, part in enumerate(parts):
        if part == 'tests' and i + 1 < len(parts):
            next_part = parts[i + 1]
            if next_part == 'unit':
                return 'unit'
            if next_part == 'integration':
                return 'integration'
    return 'unclassified'


def _is_conftest(filepath: str) -> bool:
    """Check if a file is a conftest.py."""
    return Path(filepath).name == 'conftest.py'


def analyse_file(filepath: str) -> FileResult:
    """Analyse a single test file for separation violations."""
    source = Path(filepath).read_text(encoding='utf-8')
    try:
        tree = ast.parse(source, filename=filepath)
    except SyntaxError:
        return FileResult(
            path=filepath,
            location=_classify_location(filepath),
            violations=(Violation('PARSE', 'ERROR', 'syntax error — cannot parse', 0),),
        )

    analysis = _FileAnalysis()

    # Walk top-level and nested nodes
    for node in ast.walk(tree):
        # Check markers on functions/classes
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            if _walk_decorators(node.decorator_list, 'integration'):
                analysis.has_mark_integration = True
            if _walk_decorators(node.decorator_list, 'unit'):
                analysis.has_mark_unit = True

        # Check imports
        if isinstance(node, ast.Import):
            analysis.integration_imports.extend(_check_import_integration(node))
        elif isinstance(node, ast.ImportFrom):
            analysis.integration_imports.extend(_check_importfrom_integration(node))

    # Count mocks (text-based for reliability with decorators like @patch)
    analysis.mock_count = _count_mock_usage(source)

    # Check conftest mock fixtures
    if _is_conftest(filepath):
        analysis.mock_fixture_lines = _check_mock_fixtures(tree)

    location = _classify_location(filepath)
    violations = _build_violations(filepath, location, analysis)

    return FileResult(
        path=filepath,
        location=location,
        violations=tuple(violations),
    )


def _build_violations(
    filepath: str,
    location: str,
    analysis: _FileAnalysis,
) -> list[Violation]:
    """Apply rules TS-001 through TS-008 and return violations."""
    violations: list[Violation] = []
    is_conftest = _is_conftest(filepath)

    # TS-001: unit file with integration imports
    if location == 'unit' and not is_conftest and analysis.integration_imports:
        for line, desc in analysis.integration_imports:
            violations.append(Violation(
                'TS-001', 'ERROR',
                f'integration import: {desc}',
                line,
            ))

    # TS-002: unit file with @pytest.mark.integration
    if location == 'unit' and analysis.has_mark_integration:
        violations.append(Violation(
            'TS-002', 'ERROR',
            'has @pytest.mark.integration',
            0,
        ))

    # TS-003: both markers on same file
    if analysis.has_mark_unit and analysis.has_mark_integration:
        violations.append(Violation(
            'TS-003', 'ERROR',
            'has both @pytest.mark.unit and @pytest.mark.integration',
            0,
        ))

    # TS-004: integration file without marker
    if location == 'integration' and not is_conftest and not analysis.has_mark_integration:
        violations.append(Violation(
            'TS-004', 'WARN',
            'no @pytest.mark.integration marker found',
            0,
        ))

    # TS-005: integration file that looks like a unit test
    if (
        location == 'integration'
        and not is_conftest
        and analysis.mock_count >= 3
        and not analysis.integration_imports
        and not analysis.has_mark_integration
    ):
        violations.append(Violation(
            'TS-005', 'WARN',
            f'looks like a unit test: {analysis.mock_count}x mock usage, '
            f'no integration imports, no marker',
            0,
        ))

    # TS-006: unclassified test file
    if location == 'unclassified':
        violations.append(Violation(
            'TS-006', 'WARN',
            'not in tests/unit/ or tests/integration/',
            0,
        ))

    # TS-007: unit conftest with integration imports
    if location == 'unit' and is_conftest and analysis.integration_imports:
        for line, desc in analysis.integration_imports:
            violations.append(Violation(
                'TS-007', 'ERROR',
                f'integration import in unit conftest: {desc}',
                line,
            ))

    # TS-008: integration conftest with mock-returning fixtures
    if location == 'integration' and is_conftest and analysis.mock_fixture_lines:
        for line in analysis.mock_fixture_lines:
            violations.append(Violation(
                'TS-008', 'WARN',
                'fixture returns MagicMock/AsyncMock',
                line,
            ))

    return violations


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------


def _find_test_files(path: Path) -> list[str]:
    """Recursively find test files under a directory."""
    excludes = {'.venv', '__pycache__', 'build', 'node_modules', '.git'}
    results: list[str] = []
    for p in path.rglob('*.py'):
        if any(ex in p.parts for ex in excludes):
            continue
        name = p.name
        if name.startswith('test_') or name.endswith('_test.py') or name == 'conftest.py':
            results.append(str(p))
    return sorted(results)


def _get_changed_test_files() -> list[str]:
    """Get test files changed in working tree (staged + unstaged)."""
    changed = subprocess.run(
        ['git', 'diff', '--name-only', 'HEAD'],
        capture_output=True, text=True,
    )
    staged = subprocess.run(
        ['git', 'diff', '--cached', '--name-only'],
        capture_output=True, text=True,
    )
    all_files: set[str] = set()
    for output in (changed.stdout, staged.stdout):
        for f in output.strip().splitlines():
            if f.endswith('.py') and ('tests/' in f or 'test_' in f):
                all_files.add(f)
    return sorted(all_files)


def resolve_targets(arg: str | None) -> list[str]:
    """Resolve CLI argument to a list of test file paths."""
    if arg is None or arg == 'changed':
        return _get_changed_test_files()

    target = Path(arg)
    if target.is_file():
        return [str(target)]
    if target.is_dir():
        return _find_test_files(target)

    # Try as glob
    matches = list(Path('.').glob(arg))
    return sorted(str(m) for m in matches if m.is_file() and m.suffix == '.py')


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


def format_report(results: list[FileResult]) -> str:
    """Format results as a fixed-width table + violations list."""
    lines: list[str] = []

    # Counts
    unit_files = [r for r in results if r.location == 'unit']
    integ_files = [r for r in results if r.location == 'integration']
    unclass_files = [r for r in results if r.location == 'unclassified']

    unit_violations = sum(len(r.violations) for r in unit_files)
    integ_violations = sum(len(r.violations) for r in integ_files)

    lines.append(f'Test separation: {len(results)} file(s) checked')
    lines.append('─' * 50)

    # Unit row
    unit_status = f'{unit_violations} violation(s)' if unit_violations else 'clean'
    lines.append(f'  unit/           {len(unit_files)} file(s), {unit_status}')

    # Integration row
    integ_status = f'{integ_violations} violation(s)' if integ_violations else 'clean'
    lines.append(f'  integration/    {len(integ_files)} file(s), {integ_status}')

    # Unclassified row
    if unclass_files:
        lines.append(f'  unclassified    {len(unclass_files)} file(s)')
    else:
        lines.append('  unclassified    none')

    lines.append('─' * 50)

    # Violations detail
    files_with_violations = [r for r in results if r.violations]
    if files_with_violations:
        lines.append('')
        lines.append('violations:')
        for result in files_with_violations:
            lines.append(f'  {result.path}:')
            for i, v in enumerate(result.violations):
                if i >= 5:
                    remaining = len(result.violations) - 5
                    lines.append(f'    ... and {remaining} more')
                    break
                line_ref = f' (line {v.line})' if v.line else ''
                lines.append(f'    {v.code} {v.severity:5s}  {v.message}{line_ref}')

    return '\n'.join(lines)


def summarise(results: list[FileResult]) -> str:
    """One-line summary of findings."""
    errors = sum(
        1 for r in results for v in r.violations if v.severity == 'ERROR'
    )
    warns = sum(
        1 for r in results for v in r.violations if v.severity == 'WARN'
    )
    if errors == 0 and warns == 0:
        return 'All test files are properly separated.'
    parts: list[str] = []
    if errors:
        parts.append(f'{errors} error(s)')
    if warns:
        parts.append(f'{warns} warning(s)')
    return f'{", ".join(parts)} — review violations above.'


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    """Run the test separation checker."""
    parser = argparse.ArgumentParser(
        prog='check-test-sep',
        description='Check that unit and integration tests are properly separated.',
    )
    parser.add_argument(
        'target',
        nargs='?',
        default='changed',
        help='File, directory, or "changed" (default: changed)',
    )

    args = parser.parse_args(argv)
    targets = resolve_targets(args.target)

    if not targets:
        print('No test files to check.')
        return 0

    results = [analyse_file(f) for f in targets]

    print(format_report(results))
    print()
    print(summarise(results))

    has_errors = any(
        v.severity == 'ERROR' for r in results for v in r.violations
    )
    return 1 if has_errors else 0


if __name__ == '__main__':
    sys.exit(main())
