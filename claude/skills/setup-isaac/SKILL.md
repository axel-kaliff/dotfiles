---
name: setup-isaac
description: Set up a Python 3.11 virtualenv with Isaac Sim + project dependencies for RTX rendering. Use when needing to run Isaac Sim renderer or before isaac_sim smoke tests.
user-invocable: true
allowed-tools: Bash, Read
---

# Setup Isaac Sim Environment

Creates a Python 3.11 venv with Isaac Sim packages for RTX ray tracing / path tracing.

## Steps

1. **Run uv sync**:
```bash
UV_PROJECT_ENVIRONMENT=.venv-isaac uv sync --project src/simulation/isaac_sim
```

2. **If it fails**, check:
   - Is Python 3.11 available? (`uv python list | grep 3.11`)
   - Is an RTX GPU present? (`nvidia-smi --query-gpu=name --format=csv,noheader`)
   - Is there enough disk space? (~15GB needed)

3. **Report the result**: Show which packages were installed and the venv path.

## Key facts
- Isaac Sim 5.x requires Python 3.11 (not 3.12+)
- Packages come from `https://pypi.nvidia.com`
- numpy must be pinned to 1.26.0 (numba compatibility)
- EULA acceptance: set `OMNI_KIT_ACCEPT_EULA=YES`
- `SimulationApp` must be instantiated before any `omni`/`pxr`/`mujoco.usd` imports
