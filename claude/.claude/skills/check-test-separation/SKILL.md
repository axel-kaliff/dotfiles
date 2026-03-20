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

### Violation codes

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

## Phase 1: Deterministic analysis (AST script)

Run the AST-based checker:

```bash
python ~/.claude/skills/check-test-separation/check_test_sep.py $ARGUMENTS
```

The script handles:
- Target resolution (`changed`, file, directory)
- AST-based marker and import detection
- All TS-001 through TS-008 rules
- Formatted table + violations output

Present the script output verbatim. If the script exits with code 0 (no errors), report clean and stop.

## Phase 2: LLM semantic review (only if Phase 1 found violations)

If Phase 1 found violations, read each violated file and check for **false positives**:

- Imports inside `TYPE_CHECKING` blocks are NOT integration signals
- `subprocess` imports used only via mocks (e.g., `mocker.patch('subprocess.run')`) are NOT integration signals
- `httpx.Client` with `transport=` parameter is a mock transport, not a real call

For each false positive identified, note it alongside the violation. Present adjusted counts.

## Output format

Present the script's table and violations, then any Phase 2 adjustments:

```
Test separation: <N> file(s) checked
──────────────────────────────────────────
  unit/           <N> file(s), clean
  integration/    <N> file(s), 1 violation(s)
  unclassified    none
──────────────────────────────────────────

violations:
  tests/integration/test_cache.py:
    TS-005 WARN   looks like a unit test: 4x mock usage, no integration imports, no marker

Phase 2 adjustments: none
```

Do NOT fix anything. Do NOT move files. Do NOT add markers. Reporting only.
