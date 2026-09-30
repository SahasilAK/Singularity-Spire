# scripts/

Runtime gameplay and independently testable endless-scaling rules.

## Files
### `main.gd`
Owns the complete playable loop: isometric rendering, placement and upgrades, waves, targeting, combat, protocols, persistence, HUD, controls, and run reset.
- Depends on: `wave_math.gd`, `upgrade_math.gd`, `targeting.gd`, `progression.gd`

### `wave_math.gd`
Defines endless enemy-count, health, speed, mutation-tier, and spawn-rate scaling.
- Exports: `WaveMath`

### `upgrade_math.gd`
Defines uncapped tower cost, power, and range curves.
- Exports: `UpgradeMath`

### `targeting.gd`
Selects the leading living enemy from eligible targets.
- Exports: `Targeting`

### `progression.gd`
Defines end-of-run shard rewards and persistent meta-power bonuses.
- Exports: `Progression`

Godot-generated `.uid` files pair scripts with stable editor resource identifiers and should not be edited manually.

