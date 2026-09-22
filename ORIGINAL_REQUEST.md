# Original User Request

## Initial Request — 2026-09-22T10:13:23Z

Expand the Godot 4.7 single-player Tower Defense game from its current prototype (~3.5k lines) into a feature-complete, highly replayable game (~50k lines of clean GDScript and data-driven JSON), strictly executing all 10 stages of the expansion roadmap.

Working directory: c:\Users\murat\IdeaProjects\new_world\game-dev\test_game
Integrity mode: development

## Requirements

### R1. Stage 1 — Combat & Damage Pipeline Stabilization
Implement unified `calculate_actual_damage(raw, type)` in `monster_base.gd` supporting 7 damage types (`physical`, `magic`, `poison`, `fire`, `cold`, `lightning`, `true`), armor, resistances, and immunities. Implement modular status effects (`burn`, `freeze`, `poison`, `stun`, `slow`) and tower buff system (`apply_buff`). Implement defensive zero-crash checks across all node references.

### R2. Stage 2 — Content Expansion (Data-driven JSON)
Expand `towers.json` to 17 towers, `enemies.json` to 20 enemies (with flight, stealth, split-on-death flags), `waves.json` to 25 waves with `wave_event`, `tech_tree.json` to 20 nodes with mutual locks, and `spells_database.json` to 8 spells. Implement `schema_version` and migration hooks in save handling.

### R3. Stage 3 — Level 4 Tower Evolution Branches
Add non-reversible dual specialization branches (`evolution_a` / `evolution_b`) for all towers with preview UI in `build_spot.gd` and logic in `tower_base.gd`.

### R4. Stage 4 — Multi-Phase Bosses and Specialized Enemies
Implement `boss_phase_controller.gd` with HP threshold transitions (minion summoning, shields, enrage) and introduce saboteur enemies (burrowers, totem buffers, reflectors, gold thieves).

### R5. Stage 5 — World Map, Biomes, and Multi-Front
Implement `world_map.gd` with 5 biomes, dynamic route levers, environmental hazards, powder barrels, and a 3-star rating system tracked in `meta_manager.gd`.

### R6. Stage 6 — Meta-Progression and Artifact System
Implement `artifact_manager.gd` with 30 equippable artifacts in 3 unlockable slots, expand meta-tree to 20 nodes, add traveling merchant and combo tracker.

### R7. Stage 7 — Tower Synergies and Weather System
Implement `synergy_manager.gd` for adjacent tower combos defined in `synergies.json`, and `weather_system.gd` for 6 level-wide weather conditions.

### R8. Stage 8 — Replayability Game Modes
Implement `challenge_manager.gd` (20 challenges with custom mutators), `nightmare_controller.gd` (1 life, hardcore mode), and `endless_controller.gd` with procedural wave scaling and high scores.

### R9. Stage 9 — Narrative, Bestiary, and Achievements
Implement `lore_system.gd` with in-game contextual speaker dialogues, interactive `bestiary.tscn` with enemy discovery progression, and `achievement_system.gd` with 40+ checkable achievements.

### R10. Stage 10 — Simulation Tools, Object Pooling, and QA
Implement object pooling for projectiles, headless wave balance simulator, save migrations, and automated regression test suites.

## Acceptance Criteria

### Combat & Mechanics Verification
- [ ] Automated tests verify `calculate_actual_damage` correctly applies armor, resistances, immunities, and true damage bypass.
- [ ] Status effects correctly tick, expire, and respect maximum stack limits.
- [ ] Tower buffs expire cleanly and affect effective DPS, range, and attack speed without residual state leaks.

### Zero-Crash & Data Integrity
- [ ] No null pointer or invalid instance errors when enemies die while targeted by towers or projectiles.
- [ ] All JSON databases validate with 0 syntax errors or missing required keys via startup validation and `test_data_integrity.gd`.
- [ ] Save/load cycle preserves all progression data and handles schema upgrades seamlessly.

### Campaign & Systems Completeness
- [ ] All 10 stages implemented with dedicated test scripts verifying each subsystem.
- [ ] All 5 campaign maps, endless mode, nightmare mode, and challenges are playable from start to finish.
