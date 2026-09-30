# Singularity Spire

An endless isometric sci-fi tower-defense roguelite for Godot 4.7.

## Premise

At the end of time, the last human archive hangs above a manufactured black hole. The autonomous Custodian has one directive: rebuild the Spire in every collapsing timeline and hold back the Null Swarm for one wave longer.

## Play

- Choose a tower with `1`, `2`, or `3`, then click an empty tile to build.
- Click an existing tower to upgrade it. Tower levels and costs scale without a cap.
- Every third cleared wave, choose one of three stackable Protocol upgrades.
- Press `Space` to toggle time warp and `P` to pause.
- On defeat, Memory Shards permanently improve tower power for future timelines.

Run the project with:

```powershell
& "D:\LET'S PLAY\DOWNLOADS\Godot_v4.7.2\Godot_v4.7.2-stable_win64.exe" --path "D:\WORK\AI\codex\Singularity-Spire"
```

Run the automated rules tests with the console executable:

```powershell
& "D:\LET'S PLAY\DOWNLOADS\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
```
