---
name: validate-robot
description: Run dynamics validation and smoke tests on a robosuite robot XML. Use when porting robots, tuning dynamics, or after any XML/physics changes.
argument-hint: "<robot-name> [xml-path]"
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
---

# Validate Robosuite Robot

Run the dynamics validation toolkit on a robot. This catches:
- Solver instability (robosuite's impratio=20 + cone=elliptic conflicts)
- Placeholder inertias (diaginertia="1 1 1")
- Gravity instability (arm flies away with zero control)
- Stuck actuators (ctrlrange too low)
- NaN/Inf in extended simulation

## Steps

1. **Find the robot XML**: If `$ARGUMENTS[1]` is provided, use that path. Otherwise look for the cached XML at `~/.cache/zombiesnack/robosuite/robots/$ARGUMENTS[0]/robot.xml`, or the source in `src/simulation/robosuite_sim/`.

2. **Determine joint names and init_qpos**: Read the robot's `*_robot.py` registration file to find `_INIT_QPOS` and the joint names from the XML.

3. **Run dynamics validation**:
```bash
uv run python -m simulation.robosuite_sim.tools validate \
    --xml <xml_path> \
    --joints <comma-separated-joint-names> \
    --init-qpos="<comma-separated-values>"
```

4. **If the robot is registered, also run smoke tests**:
```bash
uv run python -m simulation.robosuite_sim.tools smoke-test --robot $ARGUMENTS[0]
```

5. **Report results clearly**: List each check as PASS/FAIL with the key metric. If any check fails, suggest specific fixes based on the failure mode:
   - `solver_stability` FAIL → equality constraints incompatible with robosuite's impratio=20; simplify gripper
   - `gravity_stability` FAIL → check masses, armature, damping values
   - `mass_sanity` FAIL → replace placeholder inertias with realistic estimates
   - `actuator_response` FAIL → increase ctrlrange
   - `osc_movement` FAIL → tune kp, output_max, damping for OSC controller
