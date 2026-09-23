extends SceneTree

func _init():
    var file = FileAccess.open("res://scripts/monster_base.gd", FileAccess.READ)
    var content = file.get_as_text()
    file.close()

    var custom_draw = """
	var m_lower = monster_type.to_lower()
	if "slime" in m_lower or "lurker" in m_lower or "leech" in m_lower:
		# Slimes (wobbling jelly body, floating nuclei, translucent outer rim)
		var wobble_x = sin(walk_anim * 3.0) * bs * 0.2
		var wobble_y = cos(walk_anim * 4.0) * bs * 0.1
		draw_circle(Vector2(wobble_x, bounce + wobble_y), bs * 1.1, Color(draw_col.r, draw_col.g, draw_col.b, 0.6))
		draw_circle(Vector2(-wobble_x*0.5, bounce - wobble_y*0.5), bs * 0.4, draw_col.darkened(0.2))
		draw_circle(Vector2(wobble_x*0.3, bounce + wobble_y*0.8), bs * 0.2, draw_col.lightened(0.2))
		_draw_hp_bar(bs, bounce)
		return
	elif "treant" in m_lower or "sapling" in m_lower or "spriggan" in m_lower or "ent" in m_lower or "guardian" in m_lower:
		# Treants & Plants (wooden bark texture, leafy crests, glowing branch eyes, thorns)
		draw_circle(Vector2(0, bounce), bs * 0.9, Color(0.4, 0.25, 0.1))
		draw_circle(Vector2(0, bounce - bs * 0.8), bs * 0.6, Color(0.1, 0.5, 0.1, 0.8))
		draw_circle(Vector2(-bs*0.4, bounce - bs * 0.5), bs * 0.4, Color(0.1, 0.6, 0.1, 0.8))
		draw_circle(Vector2(bs*0.4, bounce - bs * 0.5), bs * 0.4, Color(0.1, 0.6, 0.1, 0.8))
		draw_circle(Vector2(-bs*0.2, bounce - bs*0.1), bs*0.15, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(bs*0.2, bounce - bs*0.1), bs*0.15, Color(1.0, 0.8, 0.2))
		_draw_hp_bar(bs, bounce)
		return
	elif "hydra" in m_lower or "serpent" in m_lower:
		# Hydras & Serpents (undulating serpentine segments, dual or triple heads)
		for i in range(4):
			var seg_x = sin(walk_anim * 2.0 - i * 0.5) * bs * 0.5
			draw_circle(Vector2(seg_x, bounce + i * bs * 0.4), bs * (0.8 - i*0.1), draw_col.darkened(i*0.1))
		draw_circle(Vector2(sin(walk_anim*2.0)*bs*0.5 - bs*0.3, bounce - bs*0.5), bs*0.4, draw_col)
		draw_circle(Vector2(sin(walk_anim*2.0)*bs*0.5 + bs*0.3, bounce - bs*0.5), bs*0.4, draw_col)
		_draw_hp_bar(bs, bounce)
		return
	elif "golem" in m_lower or "titan" in m_lower or "ram" in m_lower or "crusher" in m_lower:
		# Golems & Titans (faceted heavy stone/crystal polygons, runic cracks, heavy shoulder pauldrons)
		var pts = PackedVector2Array([
			Vector2(-bs, bounce - bs), Vector2(bs, bounce - bs),
			Vector2(bs*1.2, bounce), Vector2(bs*0.8, bounce + bs),
			Vector2(-bs*0.8, bounce + bs), Vector2(-bs*1.2, bounce)
		])
		draw_polygon(pts, PackedColorArray([draw_col, draw_col, draw_col, draw_col, draw_col, draw_col]))
		draw_polyline(pts, Color(0.8, 0.8, 0.8), 2.0)
		draw_circle(Vector2(-bs*0.8, bounce-bs), bs*0.5, draw_col.darkened(0.2))
		draw_circle(Vector2(bs*0.8, bounce-bs), bs*0.5, draw_col.darkened(0.2))
		_draw_hp_bar(bs, bounce)
		return
	elif "drake" in m_lower or "wurm" in m_lower or "harpy" in m_lower:
		# Drakes, Wyrms & Harpies (flapping wings, fire/frost breath trails, barbed tails)
		var wing_y = sin(walk_anim * 4.0) * bs * 0.5
		var wl = PackedVector2Array([Vector2(0, bounce), Vector2(-bs*2.0, bounce + wing_y - bs*0.5), Vector2(-bs, bounce + wing_y + bs*0.5)])
		var wr = PackedVector2Array([Vector2(0, bounce), Vector2(bs*2.0, bounce + wing_y - bs*0.5), Vector2(bs, bounce + wing_y + bs*0.5)])
		draw_polygon(wl, PackedColorArray([draw_col.darkened(0.3), draw_col.darkened(0.3), draw_col.darkened(0.3)]))
		draw_polygon(wr, PackedColorArray([draw_col.darkened(0.3), draw_col.darkened(0.3), draw_col.darkened(0.3)]))
		draw_circle(Vector2(0, bounce), bs * 0.7, draw_col)
		_draw_hp_bar(bs, bounce)
		return
	elif "elemental" in m_lower or "imp" in m_lower or "juggernaut" in m_lower or "behemoth" in m_lower:
		# Elementals (swirling core with orbiting fragments)
		draw_circle(Vector2(0, bounce), bs * 0.6, draw_col)
		for i in range(5):
			var ang = walk_anim * 3.0 + i * (TAU / 5.0)
			var px = cos(ang) * bs * 1.2
			var py = sin(ang) * bs * 1.2 + bounce
			draw_circle(Vector2(px, py), bs * 0.3, draw_col.lightened(0.4))
		_draw_hp_bar(bs, bounce)
		return
	elif "crab" in m_lower or "crawler" in m_lower or "angler" in m_lower or "spider" in m_lower:
		# Crustaceans & Insects
		draw_circle(Vector2(0, bounce), bs * 0.8, draw_col)
		for i in range(3):
			var leg_ang = PI/4 + i * 0.2
			draw_line(Vector2(0, bounce), Vector2(cos(leg_ang)*bs*1.5, bounce + sin(leg_ang)*bs*1.5), draw_col.darkened(0.4), 3.0)
			draw_line(Vector2(0, bounce), Vector2(-cos(leg_ang)*bs*1.5, bounce + sin(leg_ang)*bs*1.5), draw_col.darkened(0.4), 3.0)
		_draw_hp_bar(bs, bounce)
		return
	elif "void" in m_lower or "stellar" in m_lower or "shifter" in m_lower or "horror" in m_lower or "anomaly" in m_lower:
		# Void Entities
		draw_circle(Vector2(0, bounce), bs * 0.9, Color(0, 0, 0))
		draw_arc(Vector2(0, bounce), bs * 1.1, 0, TAU, 24, Color(0.6, 0.1, 0.8, 0.8), 3.0)
		for i in range(4):
			var ang = walk_anim * 2.0 + i * (TAU/4.0)
			draw_line(Vector2(0, bounce), Vector2(cos(ang)*bs*1.5, bounce + sin(ang)*bs*1.5), Color(0.5, 0.0, 0.7), 2.0)
		_draw_hp_bar(bs, bounce)
		return
	elif "knight" in m_lower or "praetorian" in m_lower or "inquisitor" in m_lower or "archon" in m_lower or "templar" in m_lower or "dreadnought" in m_lower or "chariot" in m_lower or "outrider" in m_lower:
		# Armored Knights & Praetorians
		draw_rect(Rect2(-bs*0.6, bounce - bs, bs*1.2, bs*2.0), Color(0.7, 0.7, 0.75))
		draw_circle(Vector2(0, bounce - bs*1.2), bs*0.5, Color(0.6, 0.6, 0.65))
		draw_line(Vector2(-bs*0.2, bounce - bs*1.2), Vector2(bs*0.2, bounce - bs*1.2), Color(0, 1, 1), 3.0) # Visor
		draw_rect(Rect2(bs*0.6, bounce - bs*0.2, bs*0.8, bs*1.2), Color(0.2, 0.2, 0.8)) # Shield
		_draw_hp_bar(bs, bounce)
		return
	elif "wolf" in m_lower or "boar" in m_lower or "hound" in m_lower or "panther" in m_lower:
		# Beasts & Wolves
		draw_circle(Vector2(0, bounce), bs * 0.8, draw_col)
		draw_circle(Vector2(bs*0.8, bounce - bs*0.3), bs * 0.5, draw_col)
		draw_line(Vector2(bs*1.2, bounce - bs*0.3), Vector2(bs*1.5, bounce + bs*0.2), Color(1,1,1), 2.0) # Fang
		draw_line(Vector2(-bs*0.8, bounce), Vector2(-bs*1.5, bounce - bs*0.5), draw_col.darkened(0.2), 4.0) # Tail
		_draw_hp_bar(bs, bounce)
		return

	match monster_type:
"""
    var target = "match monster_type:"
    var new_content = content.replace(target, custom_draw)
    
    var f = FileAccess.open("res://scripts/monster_base.gd", FileAccess.WRITE)
    f.store_string(new_content)
    f.close()
    print("Patched monster_base.gd")
    quit()
