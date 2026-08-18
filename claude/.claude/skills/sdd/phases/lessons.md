# Lessons Phase

**Mode:** Both capture learnings

## Reflection Prompts

Ask:
1. "What went well in this implementation?"
2. "What was harder than expected?"
3. "What would you do differently next time?"
4. "Were there any surprises in the codebase?"
5. "Should any lessons update CONSTITUTION.md or ARCHITECTURE.md?"

## Auto-Capture

Note from the process:
- Tasks that required revision
- Tests that caught bugs
- Spec ambiguities that caused confusion
- Patterns that worked well
- Decisions that proved good/bad

## LESSONS.md Format

```markdown
# Lessons Learned

## [Date] - [Feature Name]

### What Worked
- [List]

### What Didn't Work
- [List]

### For Next Time
- [List]

### Patterns Discovered
- [List]

### Suggested Updates
- [ ] ARCHITECTURE.md: [suggestion]
- [ ] CONSTITUTION.md: [suggestion]
- [ ] CLAUDE.md: [suggestion]

---
```

## Commands

### `/sdd lessons`
Start the reflection dialogue using the prompts above. Append findings to LESSONS.md.

### `/sdd lessons add "[lesson]"`
Quick-add a lesson to LESSONS.md without the full dialogue.

## Governing Document Updates

### ARCHITECTURE.md
"I noticed we discovered [pattern]. Should I add this to ARCHITECTURE.md?"

### CONSTITUTION.md
"This implementation revealed a security consideration: [description]. Should we add a constraint to CONSTITUTION.md?"

### CLAUDE.md
"This project has a specific convention: [description]. Should I add this to CLAUDE.md for future sessions?"
