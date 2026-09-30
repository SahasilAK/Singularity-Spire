# Singularity-Spire/

## Project Overview

Godot 4.7 isometric sci-fi endless tower-defense game written in GDScript. `project.godot` launches `scenes/main.tscn`; gameplay is driven by `scripts/main.gd`, with deterministic progression helpers covered by a headless test suite.

## Subfolders
- `scenes/` — Godot scene entry points. See [`scenes/KNOWLEDGE.md`](scenes/KNOWLEDGE.md).
- `scripts/` — Gameplay, rendering, progression, and balancing logic. See [`scripts/KNOWLEDGE.md`](scripts/KNOWLEDGE.md).
- `tests/` — Headless Godot rules tests. See [`tests/KNOWLEDGE.md`](tests/KNOWLEDGE.md).

## Files
### `project.godot`
Godot project configuration, display settings, main scene, renderer, and input bindings.

### `README.md`
Player-facing premise, controls, and commands for running and testing the game.

### `LICENSE`
MIT license for the project.

### `.kbignore`
Excludes Godot's generated `.godot` cache from knowledge-base scans.

### `.gitignore`
Excludes local environment files, build binaries, and Godot-generated cache data from version control.

### `.gitattributes`
Defines repository-level Git attribute behavior.
