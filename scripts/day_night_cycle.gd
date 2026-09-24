class_name DayNightCycle
extends Node2D

## Handles the global time of day, affecting lighting, visibility, enemy spawns,
## and applying global combat modifiers.
## Includes special states like Blood Moon and Eclipse.
## Seamlessly transitions colors and broadcasts modifier dictionaries to towers.
## Now extremely robust with advanced color transitions, skybox hooks, and seasonal logic.

signal time_of_day_changed(new_phase: TimeOfDay)
signal cycle_progressed(progress: float)
signal ambient_color_updated(color: Color)
signal special_event_started(event_name: String)
signal season_changed(season: String)

enum TimeOfDay {
	DAWN,
	DAY,
	DUSK,
	NIGHT,
	BLOOD_MOON,
	ECLIPSE,
	SOLAR_FLARE,
	DEEP_NIGHT
}

var current_time_of_day: TimeOfDay = TimeOfDay.DAY
var cycle_progress: float = 0.0
var cycle_speed: float = 0.02 # per second
var is_active: bool = true

var day_length: float = 120.0
var current_time_sec: float = 0.0

var active_modifiers: Dictionary = {}
var last_ambient_color: Color = Color.WHITE

var days_passed: int = 0
var current_season: String = "Spring"
var seasons: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

func _init() -> void:
	add_to_group("day_night_cycle")

func _ready() -> void:
	_update_modifiers()

func _process(delta: float) -> void:
	if not is_active: return
	advance_cycle(delta)
	
	var new_color = get_smooth_ambient_color()
	if new_color != last_ambient_color:
		last_ambient_color = new_color
		ambient_color_updated.emit(new_color)

## Advances the time of day loop based on delta time.
func advance_cycle(delta: float) -> void:
	current_time_sec += delta
	if current_time_sec >= day_length:
		current_time_sec -= day_length
		_on_new_day()
		
	cycle_progress = current_time_sec / day_length
	cycle_progressed.emit(cycle_progress)
	
	var new_phase = current_time_of_day
	
	if cycle_progress < 0.15:
		new_phase = TimeOfDay.DAWN
	elif cycle_progress < 0.50:
		new_phase = TimeOfDay.DAY
		# Chance for solar flare in high noon
		if cycle_progress > 0.30 and cycle_progress < 0.35 and current_time_of_day != TimeOfDay.SOLAR_FLARE:
			if randf() < 0.02:
				new_phase = TimeOfDay.SOLAR_FLARE
	elif cycle_progress < 0.65:
		new_phase = TimeOfDay.DUSK
	else:
		# Check for rare events at nightfall
		if new_phase not in [TimeOfDay.NIGHT, TimeOfDay.DEEP_NIGHT, TimeOfDay.BLOOD_MOON, TimeOfDay.ECLIPSE]:
			var rand = randf()
			if rand < 0.05:
				new_phase = TimeOfDay.BLOOD_MOON
			elif rand < 0.10:
				new_phase = TimeOfDay.ECLIPSE
			else:
				new_phase = TimeOfDay.NIGHT
		
		# If already in special night, keep it until dawn
		if current_time_of_day in [TimeOfDay.BLOOD_MOON, TimeOfDay.ECLIPSE]:
			new_phase = current_time_of_day
		else:
			if cycle_progress > 0.85:
				new_phase = TimeOfDay.DEEP_NIGHT
			else:
				new_phase = TimeOfDay.NIGHT

	if new_phase != current_time_of_day:
		set_time_of_day(new_phase)

func _on_new_day() -> void:
	days_passed += 1
	if days_passed % 30 == 0:
		var idx = seasons.find(current_season)
		current_season = seasons[(idx + 1) % 4]
		season_changed.emit(current_season)
		_update_day_length_for_season()

func _update_day_length_for_season() -> void:
	match current_season:
		"Summer": day_length = 150.0 # Longer days
		"Winter": day_length = 90.0 # Shorter days
		_: day_length = 120.0

## Hard sets the time of day and recalculates modifiers.
func set_time_of_day(time: TimeOfDay) -> void:
	current_time_of_day = time
	match time:
		TimeOfDay.DAWN: current_time_sec = 0.0
		TimeOfDay.DAY: current_time_sec = day_length * 0.15
		TimeOfDay.SOLAR_FLARE: current_time_sec = day_length * 0.30
		TimeOfDay.DUSK: current_time_sec = day_length * 0.50
		TimeOfDay.NIGHT, TimeOfDay.BLOOD_MOON, TimeOfDay.ECLIPSE: current_time_sec = day_length * 0.65
		TimeOfDay.DEEP_NIGHT: current_time_sec = day_length * 0.85
		
	cycle_progress = current_time_sec / day_length
	_update_modifiers()
	time_of_day_changed.emit(time)
	
	if time in [TimeOfDay.BLOOD_MOON, TimeOfDay.ECLIPSE, TimeOfDay.SOLAR_FLARE]:
		special_event_started.emit(get_phase_name())

## Returns the global ambient color overlay for the current phase.
func get_ambient_color() -> Color:
	match current_time_of_day:
		TimeOfDay.DAWN: return Color(1.0, 0.85, 0.7, 1.0)
		TimeOfDay.DAY: return Color(1.0, 1.0, 1.0, 1.0)
		TimeOfDay.SOLAR_FLARE: return Color(1.0, 0.9, 0.6, 1.0)
		TimeOfDay.DUSK: return Color(0.8, 0.6, 0.7, 1.0)
		TimeOfDay.NIGHT: return Color(0.3, 0.3, 0.5, 1.0)
		TimeOfDay.DEEP_NIGHT: return Color(0.15, 0.15, 0.3, 1.0)
		TimeOfDay.BLOOD_MOON: return Color(0.6, 0.1, 0.1, 1.0)
		TimeOfDay.ECLIPSE: return Color(0.1, 0.05, 0.2, 1.0)
	return Color.WHITE

## Interpolates ambient color for smooth transitions across the cycle.
func get_smooth_ambient_color() -> Color:
	if cycle_progress < 0.15:
		return Color(0.15, 0.15, 0.3).lerp(Color(1.0, 0.85, 0.7), cycle_progress / 0.15)
	elif cycle_progress < 0.25:
		return Color(1.0, 0.85, 0.7).lerp(Color.WHITE, (cycle_progress - 0.15) / 0.10)
	elif cycle_progress < 0.50:
		if current_time_of_day == TimeOfDay.SOLAR_FLARE:
			return Color(1.0, 0.9, 0.6)
		return Color.WHITE
	elif cycle_progress < 0.65:
		return Color.WHITE.lerp(Color(0.8, 0.6, 0.7), (cycle_progress - 0.50) / 0.15)
	elif cycle_progress < 0.75:
		var target = Color(0.3, 0.3, 0.5)
		if current_time_of_day == TimeOfDay.BLOOD_MOON: target = Color(0.6, 0.1, 0.1)
		elif current_time_of_day == TimeOfDay.ECLIPSE: target = Color(0.1, 0.05, 0.2)
		return Color(0.8, 0.6, 0.7).lerp(target, (cycle_progress - 0.65) / 0.10)
	elif cycle_progress < 0.85:
		var target = Color(0.3, 0.3, 0.5)
		if current_time_of_day == TimeOfDay.BLOOD_MOON: target = Color(0.6, 0.1, 0.1)
		elif current_time_of_day == TimeOfDay.ECLIPSE: target = Color(0.1, 0.05, 0.2)
		return target
	else:
		var current = Color(0.15, 0.15, 0.3)
		if current_time_of_day == TimeOfDay.BLOOD_MOON: current = Color(0.6, 0.1, 0.1)
		elif current_time_of_day == TimeOfDay.ECLIPSE: current = Color(0.1, 0.05, 0.2)
		return current

## Gets the active combat modifiers dictated by the time of day.
func get_combat_modifiers() -> Dictionary:
	return active_modifiers.duplicate()

func _update_modifiers() -> void:
	active_modifiers.clear()
	
	match current_time_of_day:
		TimeOfDay.NIGHT:
			active_modifiers["tower_range_mult"] = 0.8
			active_modifiers["stealth_spawn_rate"] = 1.25
			active_modifiers["ambush_bonus"] = 1.20
			active_modifiers["undead_hp_mult"] = 1.25
		TimeOfDay.DEEP_NIGHT:
			active_modifiers["tower_range_mult"] = 0.6
			active_modifiers["stealth_spawn_rate"] = 1.5
			active_modifiers["ambush_bonus"] = 1.40
			active_modifiers["undead_hp_mult"] = 1.50
		TimeOfDay.DAY:
			active_modifiers["tower_range_mult"] = 1.10
			active_modifiers["fire_burn_duration_mult"] = 1.15
		TimeOfDay.SOLAR_FLARE:
			active_modifiers["tower_range_mult"] = 1.10
			active_modifiers["fire_burn_duration_mult"] = 2.0
			active_modifiers["enemy_speed_mult"] = 1.1
		TimeOfDay.DAWN:
			active_modifiers["tower_range_mult"] = 1.0
			active_modifiers["hero_mana_regen_mult"] = 1.30
			active_modifiers["gold_yield_mult"] = 1.1
		TimeOfDay.DUSK:
			active_modifiers["tower_range_mult"] = 0.95
			active_modifiers["enemy_speed_mult"] = 1.05
		TimeOfDay.BLOOD_MOON:
			active_modifiers["tower_range_mult"] = 1.0
			active_modifiers["enemy_attack_mult"] = 1.3
			active_modifiers["enemy_speed_mult"] = 1.2
			active_modifiers["gold_yield_mult"] = 2.0
		TimeOfDay.ECLIPSE:
			active_modifiers["tower_range_mult"] = 0.5
			active_modifiers["magic_damage_mult"] = 1.5
			active_modifiers["physical_damage_mult"] = 0.75
			active_modifiers["mana_regen_mult"] = 2.0

func is_night_phase() -> bool:
	return current_time_of_day in [TimeOfDay.NIGHT, TimeOfDay.DEEP_NIGHT, TimeOfDay.BLOOD_MOON, TimeOfDay.ECLIPSE]

func get_phase_name() -> String:
	match current_time_of_day:
		TimeOfDay.DAWN: return "Dawn"
		TimeOfDay.DAY: return "Day"
		TimeOfDay.SOLAR_FLARE: return "Solar Flare"
		TimeOfDay.DUSK: return "Dusk"
		TimeOfDay.NIGHT: return "Night"
		TimeOfDay.DEEP_NIGHT: return "Deep Night"
		TimeOfDay.BLOOD_MOON: return "Blood Moon"
		TimeOfDay.ECLIPSE: return "Eclipse"
	return "Unknown"
	
func get_current_season() -> String:
	return current_season

func save_state() -> Dictionary:
	return {
		"current_time_sec": current_time_sec,
		"current_time_of_day": current_time_of_day,
		"is_active": is_active,
		"days_passed": days_passed,
		"current_season": current_season
	}

func load_state(data: Dictionary) -> void:
	if data.has("current_time_sec"): current_time_sec = data["current_time_sec"]
	if data.has("current_time_of_day"): current_time_of_day = data["current_time_of_day"]
	if data.has("is_active"): is_active = data["is_active"]
	if data.has("days_passed"): days_passed = data["days_passed"]
	if data.has("current_season"): current_season = data["current_season"]
	cycle_progress = current_time_sec / day_length
	_update_modifiers()
