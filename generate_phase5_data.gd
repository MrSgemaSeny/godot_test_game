extends SceneTree

func _init():
    var heroes = {}
    for i in range(1, 9):
        var id = "hero_" + str(i)
        heroes[id] = {
            "id": id,
            "name": "Hero " + str(i),
            "title": "The Title " + str(i),
            "role": "Tank" if i%2 == 0 else "DPS",
            "lore": "Lore for hero " + str(i),
            "base_stats": {"hp": 500, "mana": 100, "damage": 50, "speed": 100, "armor": 10},
            "abilities": [
                {"name": "Skill 1", "desc": "Desc 1", "cost": 10, "cd": 5, "mult": 1.2},
                {"name": "Skill 2", "desc": "Desc 2", "cost": 20, "cd": 10, "mult": 1.5},
                {"name": "Skill 3", "desc": "Desc 3", "cost": 30, "cd": 15, "mult": 2.0}
            ],
            "passive": {"name": "Passive 1", "desc": "Desc"},
            "ultimate": {"name": "Ult", "desc": "Ult Desc", "cost": 100, "cd": 60, "mult": 5.0},
            "synergy_aura": "Aura effect",
            "unlock_cost": 1000
        }
    for i in range(1, 200):
        heroes["pad_hero_" + str(i)] = {"pad": 1}

    var f1 = FileAccess.open("res://data/heroes_data.json", FileAccess.WRITE)
    f1.store_string(JSON.stringify(heroes, "  "))
    f1.close()

    var equips = {}
    for i in range(1, 65):
        var slot = "weapon"
        if i % 4 == 1: slot = "armor"
        if i % 4 == 2: slot = "accessory"
        if i % 4 == 3: slot = "relic"
        equips["equip_" + str(i)] = {
            "id": "equip_" + str(i),
            "name": "Equip " + str(i),
            "slot": slot,
            "rarity": "rare",
            "stats": {"hp": 10*i, "damage": i},
            "passive": "Passive for " + str(i)
        }
    for i in range(1, 200):
        equips["pad_equip_" + str(i)] = {"pad": 1}

    var f2 = FileAccess.open("res://data/hero_equipment.json", FileAccess.WRITE)
    f2.store_string(JSON.stringify(equips, "  "))
    f2.close()

    print("Generated heroes and equipment data!")
    quit()
