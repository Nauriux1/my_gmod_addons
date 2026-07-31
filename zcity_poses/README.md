# zb_poses – layered poses on Z-City Q radial

Poses play as **layered VCD gestures** on top of movement — you can still walk/run.

## Use

1. Hold **Q**
2. **Poses** → **RMB** for list, **LMB** to stop
3. Walk around while the pose stays active

## Technical

- `AddVCDSequenceToGestureSlot(GESTURE_SLOT_VCD, ...)` / `AnimRestartGesture`
- Hold poses re-fire when the sequence ends (Think loop)
- No `CalcMainActivity` lock — locomotion stays normal
- Radial via `hook.Add("radialOptions", ...)` like stock Z-City

## Console

- `zb_pose <id>` / `zb_pose stop` / `zb_pose_list`
