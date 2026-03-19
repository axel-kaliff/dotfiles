# Debugging & Problem Solving

## Root Cause First — MANDATORY

When encountering ANY error, failure, or unexpected behavior:

1. **STOP before writing any fix.** Do not patch symptoms.
2. **Trace the problem to its origin.** Read the actual source code where the error occurs. Follow the call chain. Understand WHY it fails, not just WHAT fails.
3. **Use the Five Whys.** Ask "why?" iteratively — drill through immediate cause → contributing factor → design decision → underlying assumption → root cause. Stop when fixing would prevent the entire class of problems.
4. **Generate competing hypotheses.** Don't fixate on the first explanation — consider 2-3 alternatives with likelihood ratings before gathering evidence.
5. **Prefer the simplest fix at the source** over a workaround downstream. A one-line fix at the root is better than a 20-line workaround elsewhere.
6. **Assess scope honestly.** If the root fix is adjacent or out-of-scope, present it to the user with trade-offs rather than silently applying a workaround.
7. **Never add defensive code to mask a bug.** If something shouldn't be None, fix why it's None — don't add `if x is not None` guards.

## Red Flags — You're Doing a Workaround

Stop and reconsider if you find yourself:
- Adding try/except around code that "shouldn't" fail
- Adding None checks for values that should always exist
- Converting types because upstream sends the wrong type
- Adding special-case branches for "edge cases" that are really bugs
- Writing more than 10 lines to fix a 1-line problem
- Touching more than 2 files for what should be a simple fix

## When Stuck

- Use `/debug` skill to enforce a structured root-cause analysis (includes Five Whys, hypothesis generation, evidence gathering, and scope assessment)
- Read the actual failing code, don't guess from error messages alone
- Check git blame / git log to understand when/why the code was written this way
