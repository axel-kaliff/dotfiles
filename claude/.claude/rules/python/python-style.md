# Strict Python Style Guide

## Code Quality Feedback Loop — MANDATORY

After writing or editing any Python file:

1. Run `/analyse` on the file
2. Fix ALL reported violations before declaring the task done — do not defer
3. If complexity warnings appear (radon CC > 10 or cognitive CC > 15), extract helpers until they are clean
4. Only move to the next file or task when the scorecard is clean for the current file

This applies to every implementation task, not just final review. The feedback loop runs per-file, not per-PR.

When fixing violations from `/analyse` output:
- Feed the raw tool output verbatim into your fix — do not summarize or paraphrase errors
- Fix 3–5 issues per pass, then re-run `/analyse` — fixing all at once divides attention and causes regressions
- After writing tests, run them immediately — do not defer execution to the stop hook

## Type System — Zero Tolerance

- Type hints on ALL function signatures (parameters AND return types)
- **NEVER use `Any`** — find or create the correct type. If truly polymorphic, use `object`, generics (`T`), `Protocol`, or `Union`
- **NEVER use `# type: ignore`** without an explicit error code (e.g., `# type: ignore[override]`) and a comment explaining why
- Use `TypeAlias` for complex type expressions: `JsonValue: TypeAlias = str | int | float | bool | None | list["JsonValue"] | dict[str, "JsonValue"]`
- Use `TypeVar` and `ParamSpec` for generic functions — never fall back to `Any`
- Use `Protocol` over `ABC` when you only need structural subtyping
- Prefer `X | Y` union syntax (3.10+) over `Union[X, Y]` and `X | None` over `Optional[X]`
- Collections: use `list[int]`, `dict[str, V]`, `tuple[int, ...]` (lowercase builtins, 3.9+)
- Use `@overload` when a function's return type depends on input types
- Callable types: prefer `Protocol` with `__call__` over `Callable[[...], ...]` for anything non-trivial
- Use `Final` for constants: `MAX_RETRIES: Final = 3`
- Use `Literal` for fixed string/int options: `mode: Literal["read", "write"]`

## Naming

- snake_case for functions, methods, variables, modules
- PascalCase for classes, type aliases, protocols
- UPPER_SNAKE for module-level constants
- Leading underscore for private/internal (`_helper`, `_cache`)
- No single-letter variables except: `i/j/k` for indices, `x/y/z` for coordinates, `T/K/V` for generics, `_` for discarded values
- Name boolean variables/parameters as predicates: `is_valid`, `has_data`, `should_retry`

## Functions & Methods

- Max 30 lines per function — split if longer
- Max 5 parameters — use a dataclass/TypedDict for more
- Pure functions preferred: no side effects, deterministic output
- No mutable default arguments (`def f(items: list[str] = [])` is a bug)
- Use `*` to force keyword-only arguments: `def fetch(url: str, *, timeout: int = 30)`
- Return early to reduce nesting — avoid deep if/else chains
- One return type per function (no `str | None` unless the function is a lookup/search)

## Classes

- Prefer `@dataclass(frozen=True)` or pydantic `BaseModel` for data containers
- No god classes — max ~100 lines per class
- Use `__slots__` on non-dataclass classes that will be instantiated frequently
- Prefer composition over inheritance
- Use `Protocol` for dependency injection, not ABC

## Error Handling

- Define domain-specific exceptions — never raise bare `Exception` or `ValueError` for business logic
- Never use bare `except:` or `except Exception:` without re-raising or logging
- Use `raise ... from err` to preserve exception chains
- No silent swallowing: every except block must log, re-raise, or return a meaningful value
- Prefer returning `Result` types (or explicit `None`) over exceptions for expected failure modes

## Imports

- Group: stdlib, blank line, third-party, blank line, local
- No wildcard imports (`from module import *`)
- No relative imports beyond one level (`from . import x` is fine, `from ...` is not)
- Import modules, not individual names, when there's ambiguity: `import datetime` not `from datetime import datetime`

## Data Handling

- Use `Enum` or `StrEnum` for fixed sets of values — never magic strings
- Use `TypedDict` for typed dictionary schemas (e.g., API responses)
- Prefer `tuple` over `list` for fixed-length, immutable sequences
- Use `frozenset` when set contents won't change
- Use `Decimal` for financial/precise math — never `float`

## Strings & Formatting

- f-strings only — no `.format()`, no `%`
- Use raw strings for regex: `re.compile(r"\d+")`
- Multi-line strings: use `textwrap.dedent` or parenthesized string concatenation

## Dependencies

- **Justify every new dependency.** Before adding a package, ask: can this be done with stdlib or an existing dep?
- Prefer packages with zero or minimal transitive dependencies over feature-rich but heavy alternatives
- Use extras/optional deps (`package[extra]`) to isolate heavy dependencies from lightweight consumers
- Pin direct dependencies to exact versions in applications (`==`); use compatible ranges (`~=`, `>=,<`) in libraries
- Run `pipdeptree` to inspect the full tree before and after adding a dep — watch for fan-out
- Run `pip-audit` to check for known vulnerabilities before adopting a package
- Run `deptry` to detect unused deps, missing deps, and imports that rely on transitive (undeclared) deps
- Audit transitive depth: a package pulling in 30+ sub-dependencies is a red flag — look for lighter alternatives
- Never add a dependency for a single utility function — copy or rewrite the 5 lines instead
- Remove unused dependencies immediately — don't let them accumulate

### Dependency & quality tools (install once, user-scoped)

```bash
# Install as isolated user tools via uv (does not affect project venvs or other users)
uv tool install ruff
uv tool install mypy
uv tool install radon
uv tool install complexipy
uv tool install pipdeptree
uv tool install deptry
uv tool install import-linter
uv tool install pip-audit
```

## Performance (Python-specific)

- Use generators (`yield`) over list construction for pipelines processing large or unbounded data
- Prefer `collections.deque` over `list` for queue/FIFO patterns
- Use `itertools` (islice, chain, groupby) over manual loops for sequence operations
- For numerical work: vectorized numpy/pandas operations, never row-level `for` loops or `.apply()` with Python lambdas
- Use `functools.lru_cache` or `functools.cache` for expensive pure-function calls with hashable args
- Prefer `dict.get(key, default)` over `try/except KeyError` for hot paths
- When building strings in a loop, use `list.append()` + `"".join()` — never `+=` concatenation

## Async

- Never mix sync and async I/O in the same call chain
- Use `asyncio.TaskGroup` (3.11+) over `gather` for structured concurrency
- Always set timeouts on async operations

## Testing (Python-specific)

- Use `pytest` exclusively — no `unittest.TestCase`
- Parametrize tests over writing repetitive test functions
- Type-hint test functions (parameters and return `None`)
- Use `tmp_path` fixture over `tempfile` module
- Prefer `pytest.raises(ExactException, match=...)` with match pattern
- Use `hypothesis` for property-based tests on pure functions and data transformations
- Prefer property-based tests over example-based tests when inputs have large domains

## Documentation

- Docstrings on all public functions/classes/modules (Google style)
- No docstrings on private/internal functions unless the logic is non-obvious
- Type information goes in annotations, NOT in docstrings
- Keep docstrings to 1-3 lines unless the function is genuinely complex

## Responding to Linter/Type Errors — MANDATORY

When mypy, ruff, or any linter reports an error:

1. **NEVER silence the error.** Do not add `# type: ignore`, `# noqa`, `cast()`, `assert isinstance()` shims, or `Any` to make it go away
2. **NEVER weaken a type signature** to satisfy the checker (e.g., widening `str` to `str | Any`, adding `Optional` where None isn't valid)
3. **NEVER add runtime workarounds** to dodge a type error (e.g., wrapping in `try/except TypeError`, adding defensive `isinstance` guards for types that shouldn't occur)
4. **FIX THE ACTUAL TYPE.** The error means the types are wrong — trace back to where the wrong type originates and fix it there
5. If the error is in a third-party library's stubs, use `# type: ignore[specific-code]` with a comment citing the upstream issue — this is the ONLY acceptable ignore case

This applies equally to:
- Adding `except Exception` to catch type-related runtime errors
- Inserting `assert` statements to narrow types that shouldn't need narrowing
- Replacing typed structures with `dict[str, Any]` to avoid modeling the real type
- Any other creative avoidance of the actual fix

## Forbidden Patterns

These should NEVER appear in code:

| Pattern | Use Instead |
|---|---|
| `Any` | Specific type, `object`, `Protocol`, generic `T` |
| `# type: ignore` (bare) | `# type: ignore[specific-code]` with explanation |
| `dict` as a catch-all | `TypedDict`, dataclass, or pydantic model |
| `isinstance()` chains | Pattern matching (`match/case`), visitor, or `Protocol` |
| `eval()` / `exec()` | Never — security risk |
| `pickle` for untrusted data | `json`, `msgpack`, or protobuf |
| `from X import *` | Explicit imports |
| Bare `except:` | `except SpecificError:` |
| `os.path` | `pathlib.Path` |
| `datetime.now()` | `datetime.now(tz=UTC)` — always timezone-aware |
| `global` | Module-level constants or pass state explicitly |
| Mutable default args | `None` default + create inside function |
| `hasattr()` | Use `Protocol`, `isinstance()` with a typed class, or direct attribute access with proper typing |
| Nested comprehensions (2+ levels) | Extract to named helper — low cyclomatic but high cognitive complexity |
| Long chained method calls (4+) | Break into named intermediate variables — improves readability and debuggability |
| Dense single-expression returns | Split into steps with named locals — one operation per line for complex logic |

## Ruff Configuration (Baseline)

```toml
[tool.ruff]
target-version = "py312"
line-length = 99

[tool.ruff.lint]
select = [
    "E", "W",       # pycodestyle
    "F",             # pyflakes
    "I",             # isort
    "N",             # pep8-naming
    "UP",            # pyupgrade
    "ANN",           # flake8-annotations
    "B",             # flake8-bugbear
    "A",             # flake8-builtins
    "C4",            # flake8-comprehensions
    "C901",          # mccabe complexity
    "SIM",           # flake8-simplify
    "TCH",           # flake8-type-checking
    "RUF",           # ruff-specific
    "PT",            # flake8-pytest-style
    "RET",           # flake8-return
    "PTH",           # flake8-use-pathlib
    "S",             # flake8-bandit (security: eval, exec, pickle, assert, hardcoded passwords)
    "PLR0911",       # too many return statements
    "PLR0912",       # too many branches
    "PLR0913",       # too many arguments
    "PLR0915",       # too many statements
]

[tool.ruff.lint.mccabe]
max-complexity = 10

[tool.ruff.lint.pylint]
max-args = 5
max-returns = 4
max-branches = 8
max-statements = 30

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["ANN", "S101"]  # relax annotations and allow assert in tests

[tool.ruff.lint.flake8-annotations]
allow-star-arg-any = false
suppress-none-returning = false
```

## Mypy Configuration (Baseline)

```toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unreachable = true
disallow_any_explicit = true
disallow_any_generics = true
disallow_untyped_defs = true
disallow_untyped_calls = true
disallow_incomplete_defs = true
no_implicit_optional = true
```
