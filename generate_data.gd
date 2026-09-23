extends SceneTree

func _init():
    var regions = {
        "Valley": ["peasant_rebel", "wild_boar", "wolf_alpha", "valley_bandit", "harvest_golem"],
        "Swamp": ["bog_lurker", "toxic_slime", "swamp_hydra", "witch_of_mists", "leech_broodmother"],
        "Greenwood": ["treant_sapling", "elder_ent", "thorn_spriggan", "shadow_panther", "forest_guardian"],
        "Stone Suburbs": ["catapult_crew", "stone_golem", "shieldwall_knight", "siege_ram", "mercenary_crossbow"],
        "Royal Highway": ["royal_inquisitor", "mounted_outrider", "bounty_hunter", "highwayman", "iron_chariot"],
        "Crystal Caves": ["geode_crawler", "crystal_resonance_bat", "quartz_crusher", "void_stalker", "prism_elemental"],
        "Frost Peak": ["frost_yeti", "glacial_wurm", "ice_revenant", "blizzard_harpy", "frost_titan"],
        "Ash Wastes": ["ash_crawler", "charred_skeleton", "cinder_hound", "obsidian_titan", "fire_drake"],
        "Fire Chasms": ["magma_elemental", "volcanic_imp", "infernal_juggernaut", "lava_serpent", "pyroclast_behemoth"],
        "Sunken Kingdom": ["drowned_mariner", "abyssal_angler", "coral_spire_crab", "siren_temptress", "kraken_spawn"],
        "Astral Ruins": ["phase_shifter", "stellar_anomaly", "void_walker", "chrono_serpent", "singularity_horror"],
        "Royal Heart": ["crimson_praetorian", "high_templar", "archon_of_light", "king_dreadnought", "sun_colossus"]
    }
    
    var out = {}
    var out_events = {"events": []}
    var idx = 0
    for reg in regions.keys():
        for en in regions[reg]:
            idx += 1
            out[en] = {
                "name": en.replace("_", " ").capitalize(),
                "description": "A dangerous enemy from " + reg,
                "max_health": 100 * idx,
                "speed": 80.0,
                "armor": 5,
                "gold_reward": 15,
                "color": "#ff0000",
                "size": 20,
                "is_boss": false,
                "is_flyer": ("bat" in en or "harpy" in en or "drake" in en),
                "is_stealth": ("stalker" in en or "shifter" in en),
                "is_invisible": ("invisible" in en),
                "split_on_death": ("slime" in en),
                "resistances": {},
                "immunities": []
            }
            out_events.events.append({
                "id": "event_" + str(idx),
                "region": reg,
                "title": "Encounter " + en.replace("_", " ").capitalize(),
                "description": "You face a " + en,
                "choices": [
                    {"id": "fight", "text": "Fight", "reward": "gold"},
                    {"id": "flee", "text": "Flee", "reward": "none"}
                ]
            })
            
    # Also add existing enemies just in case tests depend on them
    var legacy_enemies = ["grunt", "boss_grunt", "cavalry", "flying_scout", "stealth_assassin", "shaman", "troll", "necromancer", "spider", "archmage", "berserker", "flying_pumpkin"]
    
    for legacy in legacy_enemies:
        out[legacy] = {
            "name": legacy.capitalize(),
            "description": "Legacy enemy",
            "max_health": 80,
            "speed": 85.0,
            "armor": 0,
            "gold_reward": 10,
            "color": "#4d7c0f",
            "size": 18,
            "is_boss": "boss" in legacy,
            "is_flyer": "fly" in legacy,
            "is_stealth": "stealth" in legacy,
            "is_invisible": false,
            "split_on_death": false,
            "resistances": {},
            "immunities": []
        }

    var file = FileAccess.open("res://data/enemies.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(out, "  "))
    
    var evt_file = FileAccess.open("res://data/world_events.json", FileAccess.WRITE)
    evt_file.store_string(JSON.stringify(out_events, "  "))
    
    print("Generated data files with legacy enemies!")
    quit()
