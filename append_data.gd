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
    
    # Enemies
    var ef = FileAccess.open("res://data/enemies.json", FileAccess.READ)
    var ef_str = ef.get_as_text()
    ef.close()
    
    var json = JSON.new()
    json.parse(ef_str)
    var out_enemies = json.get_data()
    
    # Events
    var evf = FileAccess.open("res://data/world_events.json", FileAccess.READ)
    var ev_str = evf.get_as_text()
    evf.close()
    
    json.parse(ev_str)
    var out_events = json.get_data()
    if not out_events.has("events"):
        out_events["events"] = []
    
    var idx = 0
    for reg in regions.keys():
        for en in regions[reg]:
            idx += 1
            if not out_enemies.has(en):
                out_enemies[en] = {
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
                    "split_enemy_type": "",
                    "split_count": 0,
                    "resistances": {},
                    "immunities": []
                }
            
            # Events
            var event_id = "event_" + str(idx) + "_" + en
            var has_ev = false
            for ev in out_events.events:
                if ev.id == event_id:
                    has_ev = true
                    break
            
            if not has_ev:
                out_events.events.append({
                    "id": event_id,
                    "region": reg,
                    "title": "Encounter " + en.replace("_", " ").capitalize(),
                    "description": "You face a " + en,
                    "choices": [
                        {"id": "fight", "text": "Fight", "reward": "gold"},
                        {"id": "flee", "text": "Flee", "reward": "none"}
                    ]
                })

    var out_ef = FileAccess.open("res://data/enemies.json", FileAccess.WRITE)
    out_ef.store_string(JSON.stringify(out_enemies, "  "))
    out_ef.close()
    
    var out_evf = FileAccess.open("res://data/world_events.json", FileAccess.WRITE)
    out_evf.store_string(JSON.stringify(out_events, "  "))
    out_evf.close()
    
    print("Appended data!")
    quit()
