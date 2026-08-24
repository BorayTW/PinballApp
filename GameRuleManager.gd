class_name GameRuleManager
extends Node

# ==========================================
# 💾 遊戲規則與資料記憶管理器 (GameRuleManager.gd)
# ==========================================
const SAVE_PATH = "user://settings.cfg"
const PRESETS_SAVE_PATH = "user://presets.cfg"

# 💡 首次安裝 App 時自動寫入的內建預設名單
var built_in_default_presets: Dictionary = {
	"預設名單": [
		"1點", "3點", "1點",
		"2點", "1點", "1點",
		"2點", "1點", "3點"
	]
}

var prize_list: Array[String] = [
	"1點",
	"3點",
	"1點",
	"2點",
	"1點",
	"1點",
	"2點",
	"1點",
	"3點"
]

var total_ball_count: int = 5
var max_ball_count_limit: int = 50
var ui_font_size: int = 26
var slot_font_size: int = 30
var sound_volume: int = 100
var current_bg_color: Color = Color("#1F242E")
var enable_slot_effects: bool = true
var ball_style_type: int = 0

## 確保 presets.cfg 檔案存在，若是首次安裝則寫入內建預設名單
func _ensure_presets_file_exists() -> void:
	if not FileAccess.file_exists(PRESETS_SAVE_PATH):
		var config = ConfigFile.new()
		for preset_name in built_in_default_presets.keys():
			config.set_value("presets", preset_name, built_in_default_presets[preset_name])
		config.save(PRESETS_SAVE_PATH)

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
	_ensure_presets_file_exists() # 檢查並初始化
	var names: Array[String] = []
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section("presets"):
		for key in config.get_section_keys("presets"):
			names.append(key)
	return names

func save_preset(preset_name: String) -> void:
	if preset_name == "" or prize_list.size() == 0: return
	_ensure_presets_file_exists() # 檢查並初始化
	var config = ConfigFile.new()
	config.load(PRESETS_SAVE_PATH)
	config.set_value("presets", preset_name, prize_list)
	config.save(PRESETS_SAVE_PATH)

func delete_preset(preset_name: String) -> bool:
	_ensure_presets_file_exists() # 檢查並初始化
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section_key("presets", preset_name):
		config.erase_section_key("presets", preset_name)
		config.save(PRESETS_SAVE_PATH)
		return true
	return false

func load_preset(preset_name: String) -> bool:
	_ensure_presets_file_exists() # 檢查並初始化
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section_key("presets", preset_name):
		var loaded = config.get_value("presets", preset_name)
		if loaded is Array:
			prize_list.clear()
			for it in loaded:
				prize_list.append(str(it))
			return true
	return false
