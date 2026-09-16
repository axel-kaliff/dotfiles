import json
import subprocess
import tempfile
from pathlib import Path

import tomllib

adapter=str(Path(__file__).resolve().parent / '.codex/personal-hooks/hook_adapter.py')
config = tomllib.loads((Path.home() / '.codex/config.toml').read_text())
standalone_roles = {
    tomllib.loads(path.read_text())['name']
    for path in (Path.home() / '.codex/agents').glob('*.toml')
}
duplicate_roles = standalone_roles.intersection(config.get('agents', {}))
assert not duplicate_roles, f'duplicate custom-agent registrations: {sorted(duplicate_roles)}'
with tempfile.TemporaryDirectory(prefix='codex-hooks-test-') as temp:
    root=Path(temp)
    subprocess.run(['git','init','-q',temp],check=True,timeout=10)
    (root/'.claude').mkdir()
    (root/'.claude/frozen-paths').write_text('protected.py\nfrozen/*\n')
    (root/'protected.py').write_text('value = 1\n')
    (root/'bad.py').write_text('print(undefined_name)\n')
    (root/'.venv').symlink_to(Path.cwd()/'.venv',target_is_directory=True)
    def run(mode,tool,command,event='PreToolUse'):
        return subprocess.run(['python3',adapter,mode], input=json.dumps({'hook_event_name':event,'tool_name':tool,'tool_input':{'command':command},'cwd':temp,'session_id':'test'}),capture_output=True,text=True,timeout=100,check=False)
    for command in ['*** Begin Patch\n*** Update File: protected.py\n@@\n-value = 1\n+value = 2\n*** End Patch',
                    '*** Begin Patch\n*** Update File: bad.py\n*** Move to: frozen/new.py\n@@\n*** End Patch']:
        result=run('before','apply_patch',command)
        assert result.returncode==2,result
    assert run('before','Bash','rm -r demo').returncode==2
    assert run('before','Bash','git status --short').returncode==0
    result=run('after','apply_patch','*** Begin Patch\n*** Update File: bad.py\n@@\n*** End Patch','PostToolUse')
    assert result.returncode==0,result.stderr
    assert 'undefined_name' in json.loads(result.stdout)['hookSpecificOutput']['additionalContext'],result.stdout
    assert run('start','','','SessionStart').returncode==0
print('Passed: unique custom agents, frozen update, frozen move destination, recursive deletion block, read-only shell, Python lint feedback, session hook.')
