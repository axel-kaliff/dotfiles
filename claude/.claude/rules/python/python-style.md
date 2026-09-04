---
paths: ["**/*.py"]
---
# Python

The ai-dev conventions, ruff, and ty own naming, structure, imports, error handling, and testing style. This file keeps only what tools do not enforce.

## /analyse loop
After writing or editing a Python file, run /analyse and fix every violation before moving on. Feed the raw tool output into the fix, take 3 to 5 issues per pass, then re-run. Extract helpers until radon CC is 10 or under and cognitive complexity 15 or under. Run new tests immediately.

## Linter and type errors
Never silence an error: no bare `# type: ignore`, `# noqa`, `cast()`, `isinstance` shims, or `Any`, and never widen a signature or add a runtime guard to dodge a checker. Fix the type where it originates. The one exception is a third-party stub bug, which gets `# type: ignore[code]` with a comment citing the upstream issue.

## Forbidden patterns
| Pattern | Use instead |
|---|---|
| `Any` | Specific type, `object`, `Protocol`, generic `T` |
| bare `# type: ignore` | `# type: ignore[code]` with explanation |
| `dict` as a catch-all | `TypedDict`, dataclass, or pydantic model |
| `isinstance()` / `hasattr()` | `Protocol`, `@overload`, `match/case` on typed unions |
| `eval()` / `exec()` | Never |
| `pickle` for untrusted data | `json`, `msgpack`, or protobuf |
| bare `except:` | `except SpecificError:` |
| `os.path` for path construction | `pathlib.Path` |
| `datetime.now()` | `datetime.now(tz=UTC)` |
| `global` | Module constants or explicit state |
| mutable default args | `None` default, create inside |
| nested comprehensions, 4+ chained calls, dense one-line returns | Named helpers and intermediate variables |

## Dependencies
Justify every new dependency: prefer stdlib or an existing dep, never add one for a single utility function, and check the transitive tree with pipdeptree, pip-audit, and deptry before adopting.
