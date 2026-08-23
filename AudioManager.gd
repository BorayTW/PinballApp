extends Node

# ==========================================
# 🔊 全域音效管理器 (AudioManager.gd)
# ==========================================
@export_group("音效設定")
@export var sound_volume: int = 100 # 音量大小 (0 ~ 100)
@export var bounce_cooldown: float = 0.08 # 碰撞音效觸發最短間隔 (秒)，防止高頻發聲刺耳

var sfx_bounce: AudioStream
var sfx_slot: AudioStream

var bounce_player: AudioStreamPlayer
var slot_player: AudioStreamPlayer

var last_bounce_time: float = 0.0

func _ready() -> void:
	bounce_player = AudioStreamPlayer.new()
	slot_player = AudioStreamPlayer.new()
	add_child(bounce_player)
	add_child(slot_player)

	# 動態載入音效檔
	if ResourceLoader.exists("res://Assets/Audio/sfx_bounce.wav"):
		sfx_bounce = load("res://Assets/Audio/sfx_bounce.wav") as AudioStream
		bounce_player.stream = sfx_bounce

	if ResourceLoader.exists("res://Assets/Audio/sfx_slot.wav"):
		sfx_slot = load("res://Assets/Audio/sfx_slot.wav") as AudioStream
		slot_player.stream = sfx_slot

## 設定全域音量 (0~100)
func set_volume(val: int) -> void:
	sound_volume = clamp(val, 0, 100)
	if sound_volume <= 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
		var db = linear_to_db(float(sound_volume) / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

## 彈珠撞擊釘子/彈珠互撞音效 (含防吵冷卻與變調機制)
func play_peg_bounce() -> void:
	if sound_volume <= 0 or not bounce_player.stream: return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_bounce_time >= bounce_cooldown:
		last_bounce_time = current_time
		bounce_player.pitch_scale = randf_range(0.88, 1.12) # 微幅音高隨機，聽起來更自然
		bounce_player.play()

## 落入獎項區中獎音效
func play_slot_win() -> void:
	if sound_volume <= 0 or not slot_player.stream: return
	slot_player.pitch_scale = randf_range(0.98, 1.02)
	slot_player.play()
