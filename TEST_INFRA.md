# E2E Test Infra: Godot 4.7 Tower Defense ("Башенки v2")

## Test Philosophy
- **Opaque-box, requirement-driven**: Tests derive directly from `ORIGINAL_REQUEST.md` and user specifications, exercising the engine through headless execution.
- **Methodology**: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.
- **Engine Command**:
  `& "C:\Users\murat\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless -s tests/test_runner.gd`

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | Unified Damage Pipeline (7 types) | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 2 | Armor, Resistances, Immunities | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 3 | True Damage Bypass | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 4 | Modular Status Effects (5 types) | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 5 | Tower Buff System (apply_buff) | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 6 | Zero-Crash Node Guards | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 7 | Towers Expansion (17 towers) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 8 | Enemies Expansion (20 enemies) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 9 | Waves Expansion (25 waves, events) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 10 | Tech Tree Expansion (20 nodes) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 11 | Spells Expansion (8 spells) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 12 | Save Migrations (schema_version) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 13 | Level 4 Tower Evolutions (A/B) | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 14 | Evolution Preview UI | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 15 | Boss Phase Controller (HP triggers) | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 16 | Saboteur Enemies (4 types) | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 17 | Split-on-Death Enemies | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 18 | World Map & 5 Biomes | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |
| 19 | Route Levers & Hazards | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |
| 20 | Powder Barrels & 3-Star Rating | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |
| 21 | Artifact System (30 artifacts, 3 slots) | ORIGINAL_REQUEST §R6 | 5 | 5 | ✓ |
| 22 | Meta-Tree (20 nodes) & Merchant | ORIGINAL_REQUEST §R6 | 5 | 5 | ✓ |
| 23 | Tower Synergies (synergies.json) | ORIGINAL_REQUEST §R7 | 5 | 5 | ✓ |
| 24 | Weather System (6 conditions) | ORIGINAL_REQUEST §R7 | 5 | 5 | ✓ |
| 25 | Challenge Modes (20 mutators) | ORIGINAL_REQUEST §R8 | 5 | 5 | ✓ |
| 26 | Nightmare & Endless Modes | ORIGINAL_REQUEST §R8 | 5 | 5 | ✓ |
| 27 | Lore System & Context Dialogues | ORIGINAL_REQUEST §R9 | 5 | 5 | ✓ |
| 28 | Interactive Bestiary (bestiary.tscn) | ORIGINAL_REQUEST §R9 | 5 | 5 | ✓ |
| 29 | Achievement System (40+ achievements)| ORIGINAL_REQUEST §R9 | 5 | 5 | ✓ |
| 30 | Projectile Object Pooling | ORIGINAL_REQUEST §R10 | 5 | 5 | ✓ |
| 31 | Headless Wave Balance Simulator | ORIGINAL_REQUEST §R10 | 5 | 5 | ✓ |

## Test Architecture
- **Test Runner**: `tests/test_runner.gd` extending `SceneTree`. Runs all registered test suites and terminates cleanly via `quit(0)` on success or `quit(1)` on failure.
- **Assertion Harness**: `tests/test_base.gd` providing non-crashing assertions (`assert_eq`, `assert_true`, `assert_almost_eq`, etc.).
- **Directory Layout**:
  - `tests/`: Individual subsystem test suites (`test_data_integrity.gd`, `test_combat_pipeline.gd`, `test_boss_and_special_enemies.gd`, etc.).
  - `tests/simulations/`: Monte Carlo balance tools (`wave_simulator.gd`) and pooling tests (`test_projectile_pool.gd`).
  - `run_tests.ps1` / `run_tests.bat`: Convenience CLI execution wrappers.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Full Campaign Run: Plains Biome (Waves 1–5) | F1, F2, F7, F8, F9, F20 | Medium |
| 2 | Boss Encounter: Multi-Phase Warchief in Forest Biome | F1, F2, F15, F16, F18 | High |
| 3 | Weather Shock: Mountain Blizzard with Cold Synergy Towers | F4, F23, F24, F13 | High |
| 4 | Volcanic Levers & Powder Barrel Trap Chain | F19, F20, F8, F14 | High |
| 5 | Nightmare Mode Hardcore 1-Life Survival Run | F26, F21, F22, F1 | Extreme |
| 6 | Endless Mode 50-Wave Procedural Scaling & Pool Stress | F26, F30, F31, F6 | Extreme |
| 7 | Full Meta-Progression & Save Migration Cycle | F12, F21, F22, F29 | Medium |

## Coverage Thresholds
- **Tier 1 (Feature Coverage)**: ≥5 per feature = 31 × 5 = 155 test cases
- **Tier 2 (Boundary & Corner Cases)**: ≥5 per feature = 31 × 5 = 155 test cases
- **Tier 3 (Cross-Feature Combinations)**: ≥31 pairwise combination test cases
- **Tier 4 (Real-World Application Scenarios)**: 7 full game workload scenarios
- **Total Minimum Target**: ~348+ test cases across the comprehensive test suite
