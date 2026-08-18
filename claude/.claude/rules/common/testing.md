# Testing

- Write tests before or alongside implementation
- Minimum 80% coverage target — enforced via `diff-cover` on changed lines in pre-merge
- Test edge cases and error paths, not just happy path
- Use fixtures for shared test setup
- Prefer integration tests against real services for critical data paths
- Use mocks for unit tests and when real services are unavailable or impractical
