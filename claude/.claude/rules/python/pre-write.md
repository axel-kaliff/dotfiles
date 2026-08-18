---
# Pre-Write Checklist — MANDATORY before implementing any function

Run this checklist mentally before writing each function. Do NOT start writing until all points are resolved.

## 1. Find and mirror existing patterns

Before writing anything new, look for a sibling module or similar function in the codebase:
- Same package? Read an adjacent module and match its structure, naming, and type style
- New service/handler/processor? Find an existing one and follow its skeleton
- Claude mirrors what it sees in context — providing a typed example shifts output quality

If no existing pattern applies, proceed. Otherwise, use it as the template.

## 2. Define the signature first

Write the full typed signature before any body:
```python
def name(param: Type, *, keyword: Type = default) -> ReturnType:
```
- No `Any`, no bare `dict`, no `Optional` where `None` isn't a valid domain value
- If you need more than 5 parameters, define a `@dataclass(frozen=True)` or `TypedDict` first and use that

## 3. Estimate complexity before writing

Answer these before writing the body:
- Roughly how many lines? If > 30 → split now, not later
- How many branches (if/elif/else/for/while/try/match)? If > 8 → extract helpers first
- Max nesting depth needed? If > 2 levels → redesign with early returns or helpers

If uncertain, write a range (e.g. `CC ≈ 5–12`) and set the decomposition trigger at the upper bound.

## 4. Identify and name helpers before the main function

If the main function needs sub-steps, name each helper explicitly:
```
_validate_input(...)
_transform_record(...)
_write_output(...)
```
Write helpers first, main function last. This prevents nesting and length violations.

## 5. Choose the right data contract

Before the function, confirm:
- Input shape: is it a typed dataclass/TypedDict/model, or a primitive? Never accept raw `dict`
- Output shape: defined type, not `dict[str, Any]` or `tuple` without aliases
- Error mode: domain exception, `X | None` for lookups only, never `None` for failures

## 6. Verify before writing

Only proceed when:
- [ ] Full typed signature written
- [ ] Line count estimate ≤ 30 (or helpers are named and pre-defined)
- [ ] Branch count ≤ 8, nesting depth ≤ 2
- [ ] No `Any`, no bare `dict`, no mutable defaults
- [ ] Return type is unambiguous

## After writing a module or group of functions

Run `/analyse` on the file and fix all violations before moving to the next task. Do not defer violations.
