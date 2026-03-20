---
name: smoke-render
description: Render smoke test frames from a robosuite environment using MuJoCo or Isaac Sim renderer. Use to visually verify rendering pipelines.
argument-hint: "[mujoco|isaac_sim] [output-dir]"
user-invocable: true
allowed-tools: Bash, Read
---

# Render Smoke Test

Renders RGB and depth frames from a robosuite Lift environment and displays the results.

## Steps

1. **Determine renderer**: Use `$ARGUMENTS[0]` if provided, default to `mujoco`.

2. **Determine output dir**: Use `$ARGUMENTS[1]` if provided, default to `/tmp/render_smoke_frames`.

3. **Run the render tool**:

   For **MuJoCo** (default):
   ```bash
   uv run python -m simulation.robosuite_sim.tools render \
       --renderer mujoco --output <output-dir>
   ```

   For **Isaac Sim**:
   ```bash
   OMNI_KIT_ACCEPT_EULA=YES CUDA_VISIBLE_DEVICES=0 \
       .venv-isaac/bin/python -m simulation.robosuite_sim.tools render \
       --renderer isaac_sim --output <output-dir>
   ```
   If `.venv-isaac` doesn't exist, tell the user to run `/setup-isaac` first.

4. **Display the rendered frames**: Use the Read tool to show the PNG files from the output directory. Show at minimum the `agentview_initial_rgb.png` and `robot0_eye_in_hand_initial_rgb.png`.

5. **Report**: Frame dimensions, depth ranges, renderer used, and output location.
