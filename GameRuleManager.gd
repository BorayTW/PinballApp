class_name GameRuleManager
extends Node

# ==========================================
# 💾 遊戲規則與資料記憶管理器 (GameRuleManager.gd)
# ==========================================
const SAVE_PATH = "user://settings.cfg"
const PRESETS_SAVE_PATH = "user://presets.cfg"

var prize_list: Array[String] = [
	"特獎: 1000點",
	"三獎: 100點",
	"普獎: 10點",
	"大獎: 500點",
	"普獎: 10點",
	"二獎: 200點"
]

var total_ball_count: int = 10
var max_ball_count_limit: int = 99
var ui_font_size: int = 18
var slot_font_size: int = 12
var sound_volume: int = 100
var current_bg_color: Color = Color("#1F242E")
var enable_slot_effects: bool = true
var ball_style_type: int = 0

func load_settings(default_bg: Color) -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		ui_font_size = config.get_value("display", "ui_font_size", 18)
		slot_font_size = config.get_value("display", "slot_font_size", 12)
		sound_volume = config.get_value("display", "sound_volume", 100)
		current_bg_color = config.get_value("display", "bg_color", default_bg)
		enable_slot_effects = config.get_value("display", "enable_slot_effects", true)
		ball_style_type = config.get_value("display", "ball_style_type", 0)
		prize_list = config.get_value("gameplay", "prize_list", prize_list)
		total_ball_count = config.get_value("gameplay", "total_ball_count", total_ball_count)
	else:
		current_bg_color = default_bg
	
	if AudioManager:
		AudioManager.set_volume(sound_volume)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "ui_font_size", ui_font_size)
	config.set_value("display", "slot_font_size", slot_font_size)
	config.set_value("display", "sound_volume", sound_volume)
	config.set_value("display", "bg_color", current_bg_color)
	config.set_value("display", "enable_slot_effects", enable_slot_effects)
	config.set_value("display", "ball_style_type", ball_style_type)
	config.set_value("gameplay", "prize_list", prize_list)
	config.set_value("gameplay", "total_ball_count", total_ball_count)
	config.save(SAVE_PATH)

func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section("presets"):
		for key in config.get_section_keys("presets"):
			names.append(key)
	return names

func save_preset(preset_name: String) -> void:
	if preset_name == "" or prize_list.size() == 0: return
	var config = ConfigFile.new()
	config.load(PRESETS_SAVE_PATH)
	config.set_value("presets", preset_name, prize_list)
	config.save(PRESETS_SAVE_PATH)

func delete_preset(preset_name: String) -> bool:
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section_key("presets", preset_name):
		config.erase_section_key("presets", preset_name)
		config.save(PRESETS_SAVE_PATH)
		return true
	return false

func load_preset(preset_name: String) -> bool:
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section_key("presets", preset_name):
		var loaded = config.get_value("presets", preset_name)
		if loaded is Array:
			prize_list.clear()
			for it in loaded:
				prize_list.append(str(it))
			return true
	return false
