#!/usr/bin/env python3
"""Translate Codex patch events into the existing personal Claude hook contracts."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent


def run(script, payload):
    result = subprocess.run(['bash', str(ROOT / script)], input=json.dumps(payload), text=True,
                            capture_output=True, cwd=payload.get('cwd') or None, timeout=90)
    if result.stderr:
        print(result.stderr, file=sys.stderr, end='')
    if result.returncode == 2:
        raise SystemExit(2)
    if result.returncode:
        raise RuntimeError(f'{script} exited {result.returncode}')
    return result.stdout


def paths(payload):
    command = payload.get('tool_input', {}).get('command', '')
    cwd = Path(payload.get('cwd') or Path.cwd())
    found = re.findall(r'^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$', command, re.M)
    return list(dict.fromkeys(str((cwd / name).resolve()) for name in found))


def feedback(event, text):
    if text.strip():
        print(json.dumps({'hookSpecificOutput': {'hookEventName': event, 'additionalContext': text}}))


def main():
    mode = sys.argv[1]
    payload = json.load(sys.stdin)
    event = payload.get('hook_event_name', '')
    tool = payload.get('tool_name', '')
    if mode in ('working', 'waiting', 'done', 'before'):
        state = 'working' if mode == 'before' else mode
        try:
            subprocess.run(['bash', str(ROOT / 'status.sh'), state], check=False, timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except subprocess.TimeoutExpired:
            pass  # Pane decoration must not prevent command protection.
    if mode == 'start':
        feedback('SessionStart', run('announce-handoff.sh', payload))
    elif mode == 'before' and tool == 'Bash':
        command = payload.get('tool_input', {}).get('command', '')
        # These are the user's Claude deny/ask rules, absent from Claude's hook script.
        forbidden = [r'\brm\s+(?:-[^\s]*[rR]|--recursive)', r'\bgit\s+(?:clean|restore)\b',
                     r'\bgit\s+reset\s+--hard\b', r'\bgit\s+checkout\s+--\s']
        if any(re.search(pattern, command) for pattern in forbidden):
            print('Blocked by personal command policy. Recursive deletion/destructive git commands are denied; PR creation requires explicit approval and a separately approved execution path.', file=sys.stderr)
            raise SystemExit(2)
        run('bash-pretool.sh', payload)
    elif tool == 'apply_patch' and mode in ('before', 'after'):
        context = []
        for file in paths(payload):
            item = dict(payload, tool_input={'file_path': file})
            if mode == 'before':
                run('protect-frozen.sh', item)
            else:
                output = run('python-check.sh', item)
                if output.strip():
                    context.append(json.loads(output)['hookSpecificOutput']['additionalContext'])
        feedback(event, '\n'.join(context))


if __name__ == '__main__':
    main()
