# Project: Godot 4.7 Tower Defense Expansion ("Башенки v2")

## Architecture
- **Engine**: Godot 4.7 (`4.7.stable.official.5b4e0cb0f`) console headless execution.
- **Core Loop**:
  - `GameManager` (`scripts/game_manager.gd`): Orchestrates gold, lives, mana, active path, game state, victory/defeat.
  - `MonsterBase` (`scripts/monster_base.gd`): Monster unit handling movement along `Path2D`, girl kidnapping loop, health, damage absorption, status effects, and rewards.
  - `TowerBase` (`scripts/tower_base.gd`): Tower structure handling target acquisition, firing, buffs, evolutions, and level scaling.
  - `BuildSpot` (`scripts/build_spot.gd`): Interactive tower placement, evolution preview UI, upgrade handling.
  - `WaveController` (`scripts/wave_controller.gd`): Wave spawning, event triggers (`wave_event`), boss orchestration.
  - `MetaManager` (`scripts/meta_manager.gd`): Persistent player progression, Glory points, unlockable meta-tree, map star ratings, save migrations.
- **Data-Driven Architecture**:
  - All content defined in `data/*.json` (towers, enemies, waves, tech_tree, spells, artifacts, synergies, challenges, achievements).
  - Versioned save format (`schema_version`) with automated migration hooks.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Unified Damage Pipeline | `calculate_actual_damage(raw, type)` in `monster_base.gd` with 7 damage types | M1 | R1 (DONE) |
| 2 | Armor & Resistances | Armor scaling `clamp(armor/100, 0, 0.85)` + elemental resistance/immunity maps | M1 | R1 (DONE) |
| 3 | True Damage Bypass | `true` damage bypasses armor, elemental resistances, and shield barriers | M1 | R1 (DONE) |
| 4 | Modular Status Effects | Container managing `burn`, `freeze`, `poison`, `stun`, `slow` with stacks & durations | M1 | R1 (DONE) |
| 5 | Tower Buff System | `apply_buff(type, duration, multiplier)` affecting DPS, range, and attack speed | M1 | R1 (DONE) |
| 6 | Zero-Crash Guardrails | Defensive checks (`is_instance_valid`, target death, projectile targeting) | M1 | R1 (DONE) |
| 7 | Towers Content Expansion | Expand `data/towers.json` to 17 towers (3 levels each) | M1 | R2 (DONE) |
| 8 | Enemies Content Expansion | Expand `data/enemies.json` to 20 enemies (flight, stealth, split-on-death flags) | M1 | R2 (DONE) |
| 9 | Waves Content Expansion | Expand `data/waves.json` to 25 waves with explicit `wave_event` entries | M1 | R2 (DONE) |
| 10 | Tech Tree Expansion | Expand `data/tech_tree.json` to 20 nodes with mutual lockouts | M1 | R2 (DONE) |
| 11 | Spells Expansion | Expand `data/spells_database.json` to 8 spells with costs and cooldowns | M1 | R2 (DONE) |
| 12 | Save Schema & Migrations | Add `schema_version` and migration hooks in `meta_manager.gd` | M1 | R2 (DONE) |
| 13 | Tower Evolution Logic | Non-reversible dual specialization branches (`evolution_a`/`evolution_b`) in `tower_base.gd` | M2 | R3 |
| 14 | Evolution Preview UI | Interactive preview modal in `build_spot.gd` and HUD for Level 4 branches | M2 | R3 |
| 15 | Boss Phase Controller | `boss_phase_controller.gd` with HP threshold transitions (summons, shields, enrage) | M2 | R4 |
| 16 | Saboteur Burrowers | Tunneling enemies untargetable by ground towers while underground | M2 | R4 |
| 17 | Saboteur Totem Buffers | Enemies projecting protective auras to nearby units | M2 | R4 |
| 18 | Saboteur Reflectors | Enemies reflecting non-true damage back toward attacking towers | M2 | R4 |
| 19 | Saboteur Gold Thieves | Enemies siphoning player gold on contact | M2 | R4 |
| 20 | Split-on-Death Enemies | Units spawning smaller sub-monsters upon elimination | M2 | R4 |
| 21 | World Map & Biomes | `world_map.gd` with 5 biomes (Plains, Forest, Mountain, Swamp, Volcanic) | M3 | R5 |
| 22 | Dynamic Route Levers | Interactive levers altering monster path navigation in levels | M3 | R5 |
| 23 | Environmental Hazards | Level hazards (mud slows, lava burns, storm winds) affecting units | M3 | R5 |
| 24 | Powder Barrels | Clickable interactive barrels triggering localized area explosions | M3 | R5 |
| 25 | 3-Star Rating System | Map completion ratings tracked in `meta_manager.gd` | M3 | R5 |
| 26 | Artifact Manager | `artifact_manager.gd` with 30 equippable artifacts in 3 unlockable slots | M3 | R6 |
| 27 | Meta-Tree Expansion | Expand meta-tree progression to 20 nodes | M3 | R6 |
| 28 | Traveling Merchant | Merchant offering periodic gold/glory item and relic trades | M3 | R6 |
| 29 | Combo Tracker | Rapid kill streak tracker granting gold and mana rewards | M3 | R6 |
| 30 | Tower Synergies | `synergy_manager.gd` calculating adjacent tower combos from `synergies.json` | M4 | R7 |
| 31 | Weather System | `weather_system.gd` providing 6 level-wide weather conditions | M4 | R7 |
| 32 | Challenge Mode | `challenge_manager.gd` implementing 20 mutator challenges | M4 | R8 |
| 33 | Nightmare Mode | `nightmare_controller.gd` providing 1-life hardcore mode | M4 | R8 |
| 34 | Endless Mode | `endless_controller.gd` with procedural wave scaling and high scores | M4 | R8 |
| 35 | Lore System | `lore_system.gd` handling contextual speaker dialogue popups | M5 | R9 |
| 36 | Interactive Bestiary | `bestiary.tscn` displaying enemy models, lore, stats, and discovery progress | M5 | R9 |
| 37 | Achievement System | `achievement_system.gd` tracking 40+ achievements with rewards | M5 | R9 |
| 38 | Projectile Object Pooling | `projectile_pool.gd` recycling projectile instances to eliminate GC spikes | M5 | R10 |
| 39 | Headless Wave Simulator | `wave_simulator.gd` running automated Monte Carlo balance simulations | M5 | R10 |
| 40 | Automated Regression QA | End-to-end regression suites ensuring zero crashes across all systems | M5 | R10 |
| 41 | E2E Test Suite | Comprehensive 4-tier requirement-driven opaque-box test suite | M_E2E | Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Combat & Content Foundation | Stages 1 & 2 (Features 1–12): `calculate_actual_damage`, 7 damage types, status effects, tower buffs, zero-crash hardening, 17 towers, 20 enemies, 25 waves, 20 tech nodes, 8 spells, save migrations | None | DONE |
| M2 | Tower Evolutions & Advanced Enemies | Stages 3 & 4 (Features 13–20): Level 4 dual evolution branches, evolution UI, `boss_phase_controller.gd`, saboteurs (burrower, totem, reflector, thief), split-on-death | M1 | IN_PROGRESS |
| M3 | World Map, Campaign & Meta-Progression | Stages 5 & 6 (Features 21–29): `world_map.gd`, 5 biomes, dynamic route levers, powder barrels, 3-star ratings, `artifact_manager.gd` (30 artifacts), meta-tree (20 nodes), merchant, combo tracker | M1 | PLANNED |
| M4 | Dynamic Systems & Game Modes | Stages 7 & 8 (Features 30–34): `synergy_manager.gd`, `weather_system.gd`, `challenge_manager.gd` (20 challenges), `nightmare_controller.gd`, `endless_controller.gd` | M1, M2, M3 | PLANNED |
| M5 | Narrative, Bestiary & Simulation QA | Stages 9 & 10 (Features 35–40): `lore_system.gd`, `bestiary.tscn`, `achievement_system.gd`, `projectile_pool.gd`, `wave_simulator.gd`, automated regression suites | M1, M2, M3, M4 | PLANNED |
| M_E2E | E2E Testing Track | Feature 41: Opaque-box E2E test suite (Tiers 1–4), `TEST_INFRA.md`, publishing `TEST_READY.md`, final acceptance & hardening | None (Independent Track) | IN_PROGRESS |

## Interface Contracts
### Combat Pipeline: `TowerBase` / `Projectile` ↔ `MonsterBase`
- `monster.calculate_actual_damage(raw_amount: float, damage_type: String) -> float`:
  - `damage_type` in `["physical", "magic", "poison", "fire", "cold", "lightning", "true"]`
  - Returns positive float of actual health/shield reduction after armor, resistance, and immunity.
- `monster.take_damage(amount: float, damage_type: String, source: Node = null) -> void`:
  - Delegates to `calculate_actual_damage`, applies status effects, triggers death signals safely.
- `monster.apply_status_effect(type: StatusEffect.Type, duration: float, intensity: float) -> void`:
  - Safe stack increment, duration refresh, tick processing.
- `tower.apply_buff(buff_type: String, duration: float, multiplier: float) -> void`:
  - Types: `"damage"`, `"range"`, `"attack_speed"`. Recomputes effective stats cleanly, expires on timer.

### Evolution Contract: `BuildSpot` ↔ `TowerBase`
- `tower.can_evolve() -> bool`: Returns true if `current_level == 3` and evolution is not yet chosen.
- `tower.apply_evolution(branch: String) -> void`:
  - `branch`: `"evolution_a"` or `"evolution_b"`.
  - Sets `evolution_chosen = branch`, applies new stats/abilities, updates visuals. Irreversible.

### Boss & Saboteur Contract: `WaveController` ↔ `BossPhaseController` ↔ `MonsterBase`
- `boss_controller.check_phase_transition(current_hp: float, max_hp: float) -> void`:
  - Triggers summons, shields, or enrage buffs at 75%, 50%, 25% thresholds.

### Meta & Progression Contract: `MetaManager` ↔ Save Storage
- `meta_manager.save_data() -> Dictionary`:
  - Includes `"schema_version": 2`, `"glory_points": int`, `"upgrades": Dictionary`, `"map_stars": Dictionary`, `"unlocked_artifacts": Array`.
- `meta_manager.load_data() -> void`:
  - Performs migration pipeline if loaded `schema_version < 2`.

## Code Layout
- `scripts/`:
  - Core: `game_manager.gd`, `meta_manager.gd`, `wave_controller.gd`
  - Entities: `monster_base.gd`, `tower_base.gd`, `build_spot.gd`, `status_effect.gd`
  - Combat & Bosses: `boss_phase_controller.gd`, `projectile.gd`, `projectile_pool.gd`
  - Systems: `artifact_manager.gd`, `synergy_manager.gd`, `weather_system.gd`, `lore_system.gd`, `achievement_system.gd`
  - Modes: `challenge_manager.gd`, `nightmare_controller.gd`, `endless_controller.gd`
  - Simulation: `wave_simulator.gd`
- `data/`:
  - `towers.json`, `enemies.json`, `waves.json`, `tech_tree.json`, `spells_database.json`, `artifacts.json`, `synergies.json`, `challenges.json`, `achievements.json`, `biomes.json`
- `scenes/`:
  - `game.tscn`, `world_map.tscn`, `bestiary.tscn`, `meta_tree.tscn`, `help_modal.tscn`, `tech_tree_modal.tscn`
- `tests/`:
  - Harness: `test_base.gd`, `test_runner.gd`
  - Suites: `test_data_integrity.gd`, `test_combat_pipeline.gd`, `test_boss_and_special_enemies.gd`, `test_world_and_meta.gd`, `test_synergies_and_weather.gd`, `test_game_modes.gd`, `test_narrative_and_achievements.gd`, `test_simulation_and_pooling.gd`
