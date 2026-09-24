class_name AudioSFXSynthesizer
extends Node

## Синтезатор процедурных звуковых эффектов (Фаза 10)
## Генерирует сочный отклик на выстрелы, взрывы, звон монет и клики

enum SoundType {
	CLICK,
	COIN,
	SHOOT_ARROW,
	CANNON_BOOM,
	ICE_FREEZE,
	MAGIC_SPELL,
	CRITICAL_HIT,
	MONSTER_ROAR,
	GIRL_SAVED,
	VICTORY_FANFARE
}

var sfx_volume: float = 1.0
var music_volume: float = 0.8
var is_muted: bool = false

var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE = 8

func _init() -> void:
	_init_player_pool()

func _ready() -> void:
	add_to_group("audio_synthesizer")

func _init_player_pool() -> void:
	if not audio_players.is_empty():
		return
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		audio_players.append(p)

func play_sfx(type: SoundType, pitch_mod: float = 1.0) -> void:
	if is_muted or sfx_volume <= 0.0:
		return
		
	var player = _get_available_player()
	if not player:
		return
		
	player.pitch_scale = clamp(pitch_mod + randf_range(-0.08, 0.08), 0.5, 2.0)
	player.volume_db = linear_to_db(sfx_volume)
	
	# Generate procedural beep / chirp for zero-dependency sound
	var stream = _generate_tone(type)
	if stream:
		player.stream = stream
		if player.is_inside_tree():
			player.play()

func _get_available_player() -> AudioStreamPlayer:
	if audio_players.is_empty():
		_init_player_pool()
	if audio_players.is_empty():
		return null
	for p in audio_players:
		if not p.playing:
			return p
	return audio_players[0]

func _generate_tone(type: SoundType) -> AudioStream:
	var sample_rate = 22050
	var duration = 0.15
	var freq = 440.0
	
	match type:
		SoundType.CLICK:
			freq = 800.0
			duration = 0.05
		SoundType.COIN:
			freq = 1200.0
			duration = 0.20
		SoundType.SHOOT_ARROW:
			freq = 600.0
			duration = 0.08
		SoundType.CANNON_BOOM:
			freq = 120.0
			duration = 0.35
		SoundType.CRITICAL_HIT:
			freq = 950.0
			duration = 0.18
		SoundType.GIRL_SAVED:
			freq = 1400.0
			duration = 0.30
		_:
			freq = 440.0
			duration = 0.10
			
	var frames = int(sample_rate * duration)
	var pcm = PackedByteArray()
	pcm.resize(frames)
	
	for i in range(frames):
		var t = float(i) / sample_rate
		var wave = sin(t * freq * TAU)
		var envelope = 1.0 - (float(i) / frames)
		var val = int(clamp((wave * envelope * 120.0) + 128.0, 0, 255))
		pcm[i] = val
		
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_8_BITS
	sample.mix_rate = sample_rate
	sample.data = pcm
	return sample

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)

func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)

func toggle_mute() -> bool:
	is_muted = not is_muted
	return is_muted
