---
name: check-test-separation
description: Check that integration tests and unit tests are not mixed — verifies directory placement, markers, and import patterns in changed or specified test files.
argument-hint: "[path | file | 'changed' (default)]"
user-invocable: true
---

# Test Separation Checker

Validates that unit tests and integration tests are properly separated. Catches misplaced files, missing markers, and wrong import patterns. No fixes — reporting only.

## Conventions

The checker enforces these separation rules:

### Directory structure
```
tests/
  unit/          ← fast, isolated, no I/O
  integration/   ← real services, databases, network, filesystem
```

Files outside both directories (e.g. `tests/test_foo.py` at the top level) are flagged as **unclassified**.

### Pytest markers
- Files in `tests/unit/` must NOT have `@pytest.mark.integration`
- Files in `tests/integration/` must have at least one `@pytest.mark.integration` on a test function or class
- A file with both `@pytest.mark.unit` and `@pytest.mark.integration` is always a violation

### Import signals

**Integration signals** — imports/patterns that do NOT belong in `tests/unit/`:
- Database clients: `psycopg`, `asyncpg`, `sqlalchemy.create_engine`, `pymongo`, `redis`
- HTTP clients making real calls: `httpx.Client(`, `httpx.AsyncClient(` without `transport=`, `requests.get(`, `requests.post(`, `requests.Session(`
- Docker/testcontainers: `testcontainers`, `docker`
- Real filesystem I/O beyond `tmp_path`: `open(` with hardcoded paths, `pathlib.Path("/`
- Subprocess calls: `subprocess.run`, `subprocess.Popen`
- Network: `socket.connect`, `urllib.request`

**Unit signals** — patterns that suggest a file in `tests/integration/` is actually a unit test:
- Heavy mocking: 3+ uses of `@patch`, `MagicMock`, `AsyncMock`, `mocker.patch` in a single file
- No integration marker AND no integration imports AND contains `Mock` or `patch`

### Conftest scope
- `tests/unit/conftest.py` must NOT contain integration signals
- `tests/integration/conftest.py` must NOT set up mocks as fixtures (defining `@pytest.fixture` that returns `MagicMock` or `AsyncMock`)

## 1. Determine target files

If `$ARGUMENTS` is a path or file, use it directly.

Otherwise default to **git-changed test files**:
```bash
changed_py=$(git diff --name-only HEAD 2>/dev/null | grep '\.py$' | grep -E '(^tests/|test_)' || true)
staged_py=$(git diff --cached --name-only 2>/dev/null | grep '\.py$' | grep -E '(^tests/|test_)' || true)
targets=$(echo -e "$changed_py\n$staged_py" | sort -u | grep -v '^$')
```

If `$ARGUMENTS` is a directory, find all `test_*.py` and `*_test.py` files under it recursively, excluding `.venv`, `__pycache__`, and `build`.

If no targets found, report "no test files to check" and exit cleanly.

## 2. Classify each file

For each target file:

1. **Determine location**: is it under `tests/unit/`, `tests/integration/`, or elsewhere?
2. **Scan for markers**: grep for `pytest.mark.integration`, `pytest.mark.unit`
3. **Scan for integration signal imports/patterns**: check for the integration signals listed above
4. **Scan for heavy mocking**: count occurrences of `@patch`, `MagicMock`, `AsyncMock`, `mocker.patch`
5. **Check conftest scope** if the file is a `conftest.py`

## 3. Flag violations

A violation is any of:

| Code | Severity | Description |
|------|----------|-------------|
| `TS-001` | ERROR | File in `tests/unit/` contains integration signal imports |
| `TS-002` | ERROR | File in `tests/unit/` has `@pytest.mark.integration` |
| `TS-003` | ERROR | File has both `@pytest.mark.unit` and `@pytest.mark.integration` |
| `TS-004` | WARN  | File in `tests/integration/` has no `@pytest.mark.integration` marker |
| `TS-005` | WARN  | File in `tests/integration/` looks like a unit test (heavy mocking, no integration imports) |
| `TS-006` | WARN  | Test file not in `tests/unit/` or `tests/integration/` — unclassified |
| `TS-007` | ERROR | `tests/unit/conftest.py` contains integration signal imports |
| `TS-008` | WARN  | `tests/integration/conftest.py` defines mock-returning fixtures |

## 4. Present report

Output a fixed-width table:

```
Test separation: <N> file(s) checked
──────────────────────────────────────────
  unit/           <N> file(s), <N> violation(s)  |  clean
  integration/    <N> file(s), <N> violation(s)  |  clean
  unclassified    <N> file(s)                    |  none
──────────────────────────────────────────
```

After the table, print a **violations section** grouped by file:

```
violations:
  tests/unit/test_orders.py:
    TS-001 ERROR  integration import: from sqlalchemy import create_engine (line 5)
    TS-002 ERROR  has @pytest.mark.integration (line 12)

  tests/integration/test_cache.py:
    TS-005 WARN   looks like a unit test: 4x MagicMock, no integration imports, no marker

  tests/test_utils.py:
    TS-006 WARN   not in tests/unit/ or tests/integration/
```

Limit to 5 violations per file. If more, add `  ... and N more`.

## 5. Summarise

One sentence: how many errors, how many warnings, what needs attention. If clean, say so.

Do NOT fix anything. Do NOT move files. Do NOT add markers. Reporting only.
