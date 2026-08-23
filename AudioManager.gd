extends Node

# ==========================================
# 🔊 全域音效管理器 (AudioManager.gd)
# ==========================================
@export_group("音效設定")
@export var sound_volume: int = 100 # 0 ~ 100 音量大小

var sfx_player: AudioStreamPlayer

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

## 設定音量 (0~100)
func set_volume(val: int) -> void:
	sound_volume = clamp(val, 0, 100)
	if sound_volume <= 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
		# 將 0~100 映射至分貝 (dB) 範圍 (-40dB ~ 0dB)
		var db = linear_to_db(float(sound_volume) / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

## 預留：彈珠撞擊釘子音效
func play_peg_bounce() -> void:
	if sound_volume <= 0: return
	# 未來載入音效後啟用：
	# sfx_player.stream = preload("res://Assets/Audio/bounce.wav")
	# sfx_player.play()
	pass

## 預留：落入獎項區音效
func play_slot_win() -> void:
	if sound_volume <= 0: return
	# sfx_player.stream = preload("res://Assets/Audio/slot.wav")
	# sfx_player.play()
	pass
