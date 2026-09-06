# Git, security, testing

- Do not bundle unrelated changes in one commit; prefix messages with `feat:`, `fix:`, `refactor:`, `test:`, or `docs:`. Why: history is read and reverted one change at a time.
- Never commit secrets, credentials, or API keys. Why: a leaked key is a rotation and an incident, not a revert.
- Do not use external input unvalidated, build SQL by string concatenation, or unpickle, eval, or exec untrusted data. Why: each is an injection or remote-code path.
- Do not make a network call or start a subprocess without a timeout, and do not read a large input whole when it can be streamed. Why: hung jobs and out-of-memory kills in long-running runs.
- Do not change behaviour without a test that exercises the changed lines, and do not mock a real service on a critical data path when the real one is available. Why: mocks keep passing while the integration breaks.
