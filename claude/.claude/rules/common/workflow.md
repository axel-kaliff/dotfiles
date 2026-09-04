# Git, security, testing

- Conventional commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`), one logical change per commit.
- Never commit secrets, credentials, or API keys.
- Validate external input, use parameterized queries, and flag pickle, eval, and exec as security risks.
- Set explicit timeouts on network calls and subprocesses; stream large inputs instead of loading them whole.
- Write tests before or alongside implementation, covering edge cases and error paths. Target 80% coverage on changed lines.
- Use fixtures for shared setup. Prefer integration tests against real services for critical data paths; mock when they are unavailable.
