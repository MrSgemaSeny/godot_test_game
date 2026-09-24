class_name TestCampaign59Stages
extends TestBase

const CampaignManagerScript = preload("res://scripts/campaign_manager.gd")

var cm: Node = null

func before_each() -> void:
	cm = CampaignManagerScript.new()

func after_each() -> void:
	if is_instance_valid(cm):
		cm.free()
		cm = null

func test_all_59_stages_structure_and_ids() -> void:
	assert_true(FileAccess.file_exists("res://data/campaign.json"), "campaign.json must exist")
	var file = FileAccess.open("res://data/campaign.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "campaign.json must be valid JSON")
	var data: Dictionary = json.data
	
	var chapters: Array = data.get("chapters", [])
	assert_eq(chapters.size(), 5, "Campaign must have exactly 5 chapters")
	
	var expected_stage_counts = [10, 10, 12, 12, 15]
	var total_stages = 0
	
	for i in range(5):
		var ch = chapters[i]
		var stages: Array = ch.get("maps", ch.get("stages", []))
		assert_eq(stages.size(), expected_stage_counts[i], "Chapter %d must have %d stages" % [i + 1, expected_stage_counts[i]])
		total_stages += stages.size()
		
		# Check sequential IDs
		for s_idx in range(stages.size()):
			var st = stages[s_idx]
			var expected_id = "c%d_%02d" % [i + 1, s_idx + 1]
			assert_eq(st.get("id"), expected_id, "Stage ID mismatch in chapter %d" % [i + 1])
			assert_true(st.has("name"), "Stage %s must have name" % expected_id)
			assert_gt(int(st.get("waves", st.get("wave_count", 0))), 0, "Stage %s wave_count must be > 0" % expected_id)
			assert_true(st.has("star_conditions"), "Stage %s must have star_conditions" % expected_id)
			
	assert_eq(total_stages, 59, "Campaign must have exactly 59 stages across 5 chapters")

func test_stage_level_caps() -> void:
	var chapters: Array = cm.campaign_data.get("chapters", [])
	for ch in chapters:
		var ch_num = int(ch.get("chapter_num", ch.get("chapter", 1)))
		var expected_cap = 3
		if ch_num in [3, 4]:
			expected_cap = 4
		elif ch_num == 5:
			expected_cap = 5
			
		assert_eq(int(ch.get("max_tower_level", 0)), expected_cap, "Chapter %d level cap mismatch" % ch_num)
		for st in ch.get("maps", ch.get("stages", [])):
			var st_cap = int(st.get("max_tower_level", ch.get("max_tower_level", expected_cap)))
			assert_eq(st_cap, expected_cap, "Stage %s level cap mismatch" % st.get("id"))

func test_stage_star_conditions_and_rewards() -> void:
	var stage_c1_01 = cm.get_stage_data("c1_01")
	assert_false(stage_c1_01.is_empty(), "Stage c1_01 must be found")
	var conds = stage_c1_01.get("star_conditions", [])
	assert_ge(conds.size(), 3, "Must have at least 3 star conditions")
	
	var bonus_gold = int(stage_c1_01.get("bonus_gold", 0))
	assert_gt(bonus_gold, 0, "Bonus gold must be positive")

func test_campaign_manager_progression() -> void:
	# Initial unlock: c1_01
	assert_true(cm.is_stage_unlocked("c1_01"), "First stage must be unlocked")
	
	# Complete c1_01 with 3 stars
	cm.record_stage_completion("c1_01", 3)
	assert_eq(cm.get_stage_stars("c1_01"), 3)
	assert_true(cm.is_stage_unlocked("c1_02"), "Next stage c1_02 must unlock after completing c1_01")
	
	# Stage layout lookup
	var layout = cm.get_stage_layout("c1_01")
	assert_true(layout.has("curve"), "Stage layout must provide curve")
	assert_true(layout.has("spots"), "Stage layout must provide spots")
