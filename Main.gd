extends Control

# ==========================================
# ⚙️ 可調整參數區 (Inspector 面板可直接選色)
# ==========================================
@export_group("系統與預設字體大小")
@export var default_ui_font_size: int = 18          # 一般 UI 按鈕與選單預設大小
@export var default_slot_font_size: int = 12        # 獎品區文字預設大小
@export var item_list_font_offset: int = -4         # 獎項列表字體縮放偏移量

@export_group("色彩與視覺設定 (Colors & Visuals)")
@export var bg_color_palette: Array[Color] = [
	Color("#1F242E"), # 預設暗藍灰
	Color("#14141A"), # 極夜純黑
	Color("#2E1F33"), # 夢幻深紫
	Color("#1A332E"), # 森林墨綠
	Color("#382424"), # 典雅酒紅
	Color("#404047")  # 質感簡約灰
]
@export var board_bg_darken_factor: float = 0.25    # 彈珠台內部背景自動加深/變亮係數
@export var board_border_color: Color = Color("cccccc") # 彈珠台邊框顏色
@export var peg_color: Color = Color("ffd700")          # 釘子填滿顏色
@export var peg_outline_color: Color = Color("8b6508")  # 釘子描邊顏色
@export var peg_outline_width: float = 2.0              # 釘子描邊粗細
@export var ball_color: Color = Color("1e90ff")         # 彈珠顏色
@export var fire_ball_color: Color = Color("#FF3D00")    # 火焰彈珠專用球體顏色

@export_group("獎品區特效與色彩 (Slot FX)")
@export var enable_slot_effects: bool = true        # 獎品區特效勾選框
@export var slot_outline_width: int = 3             # 獎品區文字描邊厚度
@export var slot_color_normal: Color = Color("#FFFFFF")   # 無彈珠顏色 (白色)
@export var slot_color_single: Color = Color("#FFF59D")   # 1顆彈珠顏色 (淡黃色)
@export var slot_color_multiple: Color = Color("#00E5FF") # 2顆以上彈珠顏色 (亮青色)
@export var slot_shake_speed: float = 15.0          # 統一文字晃動速度 (Hz)

@export_group("彈珠樣式與特效 (Ball Style)")
# 0: 普通, 1: 滷蛋, 2: 幻影滷蛋, 3: 彩虹, 4: 火焰 (已刪除幻影彈珠)
@export_enum("普通彈珠", "滷蛋彈珠", "幻影滷蛋", "彩虹彈珠", "火焰彈珠") var ball_style_type: int = 0
@export var rainbow_trail_length: int = 30           # 彩虹拖尾長度
@export var phantom_egg_spawn_interval: float = 0.08 # 幻影滷蛋殘影生成間隔 (秒)
@export var phantom_egg_lifetime: float = 0.45       # 每個幻影滷蛋殘影的獨立壽命 (秒)
@export var egg_texture_path: String = "res://egg_ball.png" # 滷蛋圖片路徑

@export_group("彈珠台尺寸與位置 (Board Size)")
@export var board_width: float = 800.0     # 彈珠台寬度
@export var board_height: float = 520.0    # 彈珠台高度
@export var board_top_margin: float = 60.0 # 全域頂部留白距離

@export_group("釘子與間距 (Pegs)")
@export var peg_rows: int = 5               # 釘子列數
@export var peg_cols: int = 15              # 釘子行數
@export var peg_radius: float = 8.0         # 釘子半徑大小
@export var peg_bounce: float = 0.7         # 釘子彈性 (0.0~1.0)
@export var peg_top_padding: float = 120.0  # 上邊框到最上排釘子的距離
@export var peg_bottom_padding: float = 80.0# 最下排釘子到獎項區的距離

@export_group("獎項小格子 (Slots)")
@export var slot_height: float = 70.0       # 獨立小格子的高度
@export var prize_list: Array[String] = [
	"特獎: 1000點",
	"三獎: 100點",
	"普獎: 10點",
	"大獎: 500點",
	"普獎: 10點",
	"二獎: 200點"
]

@export_group("彈珠與發射機制 (Ball & Launch)")
@export var total_ball_count: int = 10      # 可使用的彈珠總數量
@export var max_ball_count_limit: int = 99  # 彈珠數量上限
@export var ball_radius: float = 12.0       # 彈珠半徑
@export var ball_bounce: float = 0.6        # 彈珠彈性
@export var ball_mass: float = 1.0          # 彈珠質量
@export var ball_gravity_scale: float = 1.2 # 重力倍率
@export var spawn_x_offset: float = 15.0    # 發射初始位置隨機 X 軸偏移範圍
@export var launch_cooldown: float = 0.2    # 最短發射間隔時間 (秒)

# --- 內部狀態與記憶檔路徑 ---
const SAVE_PATH = "user://settings.cfg"
const PRESETS_SAVE_PATH = "user://presets.cfg"

var remaining_ball_count: int = 10
var ui_font_size: int
var slot_font_size: int
var sound_volume: int = 100
var current_bg_color: Color
var is_initializing: bool = true
var pending_delete_preset_name: String = ""

# 紀錄流水號與結果對應字典
var ball_records: Array[Dictionary] = []
var current_ball_counter: int = 0

# 獨立殘影與彩虹軌跡資料結構
var ball_trails: Dictionary = {}        # 彩虹彈珠軌跡：{ ball: [Vector2] }
var phantom_ghosts: Array[Dictionary] = [] # 幻影滷蛋獨立殘影：[{ pos, rot, alpha, life, max_life }]
var phantom_spawn_timers: Dictionary = {} # 每個滷蛋生成殘影的計時器：{ ball: float }

var egg_texture: Texture2D = null

# --- 節點引用 ---
@onready var ball_spawner: Marker2D = $BallSpawner
@onready var board_node: StaticBody2D = $Board
@onready var pegs_container: Node2D = $Pegs
@onready var slots_container: Node2D = $Slots

@onready var launch_button: Button = $UI/BottomVBox/HBoxContainer/LaunchButton
@onready var clear_button: Button = $UI/BottomVBox/HBoxContainer/ClearButton
@onready var result_log_text: RichTextLabel = $UI/ResultPanel/VBox/ResultLogText
@onready var version_label: Label = $UI/VersionLabel

@onready var restart_button: Button = $UI/TopLeftVBox/RestartButton
@onready var quit_button: Button = $UI/TopLeftVBox/QuitButton
@onready var display_settings_button: Button = $UI/TopRightVBox/DisplaySettingsButton
@onready var settings_button: Button = $UI/TopRightVBox/SettingsButton

@onready var display_panel: PanelContainer = $UI/DisplayPanel
@onready var settings_panel: PanelContainer = $UI/SettingsPanel
@onready var delete_confirm_panel: PanelContainer = $UI/DeleteConfirmPanel
@onready var delete_confirm_text: Label = $UI/DeleteConfirmPanel/VBox/ConfirmText

# 獎品名單設定 UI
@onready var add_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/InputHBox/AddInput
@onready var add_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/InputHBox/AddButton
@onready var item_list: ItemList = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ItemList
@onready var delete_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ActionHBox/DeleteButton
@onready var shuffle_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ActionHBox/ShuffleButton
@onready var preset_name_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSaveHBox/PresetNameInput
@onready var save_preset_button: Button = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSaveHBox/SavePresetButton
@onready var preset_option: OptionButton = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSelectHBox/PresetOption
@onready var delete_preset_button: Button = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSelectHBox/DeletePresetButton

# 彈珠數量控制項 UI
@onready var ball_count_minus_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/MinusButton
@onready var ball_count_plus_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/PlusButton
@onready var ball_count_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/BallCountInput

# 畫面設定 UI
@onready var bg_color_hbox: HBoxContainer = $UI/DisplayPanel/VBox/BGColorHBox
@onready var ui_font_slider: HSlider = $UI/DisplayPanel/VBox/UIFontSlider
@onready var slot_font_slider: HSlider = $UI/DisplayPanel/VBox/SlotFontSlider
@onready var sound_label: Label = $UI/DisplayPanel/VBox/SoundLabel
@onready var sound_slider: HSlider = $UI/DisplayPanel/VBox/SoundSlider
@onready var slot_effect_check: CheckBox = $UI/DisplayPanel/VBox/EffectHBox/SlotEffectCheck
@onready var ball_style_option: OptionButton = $UI/DisplayPanel/VBox/EffectHBox/BallStyleOption

var custom_font: Font = null
var active_balls: Array[RigidBody2D] = []
var can_launch: bool = true
var launch_timer: float = 0.0

func _ready() -> void:
	is_initializing = true
	
	if ResourceLoader.exists("res://NotoSansTC-VariableFont_wght.ttf"):
		custom_font = load("res://NotoSansTC-VariableFont_wght.ttf")

	if ResourceLoader.exists(egg_texture_path):
		egg_texture = load(egg_texture_path)

	_setup_ball_style_option_ui()
	_load_settings()
	remaining_ball_count = total_ball_count
	_setup_system_buttons()
	_setup_version_label()
	_setup_bg_color_buttons()
	_refresh_preset_options()

	preset_option.item_selected.connect(_on_preset_selected)
	add_button.pressed.connect(_on_add_button_pressed)
	add_input.text_submitted.connect(func(_t): _on_add_button_pressed())
	item_list.item_selected.connect(_on_item_list_item_selected)
	delete_button.pressed.connect(_on_delete_button_pressed)
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	save_preset_button.pressed.connect(_on_save_preset_button_pressed)
	delete_preset_button.pressed.connect(_on_delete_preset_button_pressed)

	ball_count_minus_button.pressed.connect(func(): _update_total_ball_count(total_ball_count - 1))
	ball_count_plus_button.pressed.connect(func(): _update_total_ball_count(total_ball_count + 1))
	ball_count_input.text_submitted.connect(_on_ball_count_input_submitted)

	$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmOkButton.pressed.connect(_on_delete_confirm_ok_pressed)
	$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmCancelButton.pressed.connect(_on_delete_confirm_cancel_pressed)

	ui_font_slider.value_changed.connect(_on_ui_font_slider_value_changed)
	slot_font_slider.value_changed.connect(_on_slot_font_slider_value_changed)
	sound_slider.value_changed.connect(_on_sound_slider_value_changed)
	slot_effect_check.toggled.connect(func(val): enable_slot_effects = val; _save_settings())
	ball_style_option.item_selected.connect(_on_ball_style_selected)
	
	_update_ui_font_size(ui_font_size)
	_refresh_item_list_ui()
	_update_launch_button_ui()
	_update_result_log_ui()
	_setup_board_boundaries()
	_generate_pegs()
	_generate_slots()

	var view_size = get_viewport_rect().size
	ball_spawner.position = Vector2(view_size.x / 2.0, board_top_margin + 20)

	is_initializing = false

func _setup_ball_style_option_ui() -> void:
	ball_style_option.clear()
	ball_style_option.add_item("普通彈珠")   # 0
	ball_style_option.add_item("滷蛋彈珠")   # 1
	ball_style_option.add_item("幻影滷蛋")   # 2
	ball_style_option.add_item("彩虹彈珠")   # 3
	ball_style_option.add_item("火焰彈珠")   # 4

func _on_ball_style_selected(idx: int) -> void:
	ball_style_type = idx
	_clean_ball_particles_and_trails()
	
	if ball_style_type == 4: # 火焰彈珠
		for ball in active_balls:
			if is_instance_valid(ball) and not ball.has_node("FireParticles"):
				_attach_fire_particle_effect(ball)

	_save_settings()

func _process(delta: float) -> void:
	if not can_launch:
		launch_timer -= delta
		if launch_timer <= 0:
			can_launch = true
			if not _is_any_panel_open() and remaining_ball_count > 0:
				launch_button.disabled = false

	active_balls = active_balls.filter(func(b): return is_instance_valid(b))

	# 1. 獨立殘影生命週期與生成控制 (幻影滷蛋: 模式 2)
	if ball_style_type == 2:
		for ball in active_balls:
			var speed = ball.linear_velocity.length()
			if speed > 15.0: # 移動中才定時釋放殘影
				var t = phantom_spawn_timers.get(ball, 0.0) + delta
				if t >= phantom_egg_spawn_interval:
					t = 0.0
					phantom_ghosts.append({
						"pos": ball.position,
						"rot": ball.rotation,
						"life": phantom_egg_lifetime,
						"max_life": phantom_egg_lifetime
					})
				phantom_spawn_timers[ball] = t

		# 更新所有舊殘影的獨立壽命
		var i = phantom_ghosts.size() - 1
		while i >= 0:
			var g = phantom_ghosts[i]
			g["life"] -= delta
			if g["life"] <= 0:
				phantom_ghosts.remove_at(i)
			i -= 1

	# 2. 彩虹彈珠軌跡採樣 (模式 3)
	if ball_style_type == 3:
		for ball in active_balls:
			if not ball_trails.has(ball):
				ball_trails[ball] = []
			var trail: Array = ball_trails[ball]
			trail.append(ball.position)
			if trail.size() > rainbow_trail_length:
				trail.pop_front()

	queue_redraw()

func _clean_ball_particles_and_trails() -> void:
	ball_trails.clear()
	phantom_ghosts.clear()
	phantom_spawn_timers.clear()
	for ball in active_balls:
		if is_instance_valid(ball):
			for child in ball.get_children():
				if child is CPUParticles2D:
					child.queue_free()

func _update_result_log_ui() -> void:
	var log_text = ""
	for item in ball_records:
		log_text += "(%d) %s\n" % [item["id"], item["prize"]]
	result_log_text.text = log_text

func _update_total_ball_count(new_val: int) -> void:
	total_ball_count = clamp(new_val, 1, max_ball_count_limit)
	ball_count_input.text = str(total_ball_count)
	_clear_all_balls()
	_save_settings()

func _on_ball_count_input_submitted(txt: String) -> void:
	if txt.is_valid_int():
		_update_total_ball_count(txt.to_int())
	else:
		ball_count_input.text = str(total_ball_count)

func _update_launch_button_ui() -> void:
	launch_button.text = "發射彈珠 (" + str(remaining_ball_count) + ")"
	var is_open = _is_any_panel_open()
	if remaining_ball_count > 0 and not is_open and can_launch:
		launch_button.disabled = false
	else:
		launch_button.disabled = true

func _save_settings() -> void:
	if is_initializing: return
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

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	var default_bg = bg_color_palette[0] if bg_color_palette.size() > 0 else Color("#1F242E")

	if err == OK:
		ui_font_size = config.get_value("display", "ui_font_size", default_ui_font_size)
		slot_font_size = config.get_value("display", "slot_font_size", default_slot_font_size)
		sound_volume = config.get_value("display", "sound_volume", 100)
		current_bg_color = config.get_value("display", "bg_color", default_bg)
		enable_slot_effects = config.get_value("display", "enable_slot_effects", true)
		ball_style_type = config.get_value("display", "ball_style_type", 0)
		prize_list = config.get_value("gameplay", "prize_list", prize_list)
		total_ball_count = config.get_value("gameplay", "total_ball_count", total_ball_count)
	else:
		ui_font_size = default_ui_font_size
		slot_font_size = default_slot_font_size
		sound_volume = 100
		current_bg_color = default_bg

	ui_font_slider.value = ui_font_size
	slot_font_slider.value = slot_font_size
	sound_slider.value = sound_volume
	sound_label.text = "遊戲音效: " + str(sound_volume)
	slot_effect_check.button_pressed = enable_slot_effects
	ball_style_option.select(ball_style_type)
	ball_count_input.text = str(total_ball_count)

func _setup_bg_color_buttons() -> void:
	for c in bg_color_hbox.get_children():
		c.queue_free()

	for c in bg_color_palette:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		
		var style = StyleBoxFlat.new()
		style.bg_color = c
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color.WHITE if c == current_bg_color else Color(0.4, 0.4, 0.4, 0.5)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.pressed.connect(func(): _on_bg_color_selected(c))
		bg_color_hbox.add_child(btn)

func _on_bg_color_selected(color: Color) -> void:
	current_bg_color = color
	_setup_bg_color_buttons()
	_save_settings()

func _refresh_preset_options() -> void:
	preset_option.clear()
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section("presets"):
		for key in config.get_section_keys("presets"):
			preset_option.add_item(key)

	var has_presets = preset_option.item_count > 0
	delete_preset_button.disabled = not has_presets
	if not has_presets:
		preset_option.add_item("(無歷史名單)")
		preset_option.disabled = true
	else:
		preset_option.disabled = false

func _on_save_preset_button_pressed() -> void:
	var name_txt = preset_name_input.text.strip_edges()
	if name_txt == "" or prize_list.size() == 0: return

	var config = ConfigFile.new()
	config.load(PRESETS_SAVE_PATH)
	config.set_value("presets", name_txt, prize_list)
	config.save(PRESETS_SAVE_PATH)

	preset_name_input.clear()
	_refresh_preset_options()

func _on_delete_preset_button_pressed() -> void:
	if preset_option.disabled or preset_option.selected < 0: return
	pending_delete_preset_name = preset_option.get_item_text(preset_option.selected)
	delete_confirm_text.text = "確定要刪除預設名單：\n【 " + pending_delete_preset_name + " 】嗎？"
	delete_confirm_panel.show()

func _on_delete_confirm_ok_pressed() -> void:
	delete_confirm_panel.hide()
	if pending_delete_preset_name != "":
		var config = ConfigFile.new()
		if config.load(PRESETS_SAVE_PATH) == OK and config.has_section_key("presets", pending_delete_preset_name):
			config.erase_section_key("presets", pending_delete_preset_name)
			config.save(PRESETS_SAVE_PATH)
			_refresh_preset_options()
		pending_delete_preset_name = ""

func _on_delete_confirm_cancel_pressed() -> void:
	delete_confirm_panel.hide()
	pending_delete_preset_name = ""

func _on_preset_selected(idx: int) -> void:
	if preset_option.disabled or idx < 0: return
	var key = preset_option.get_item_text(idx)
	var config = ConfigFile.new()
	if config.load(PRESETS_SAVE_PATH) == OK and config.has_section_key("presets", key):
		var loaded = config.get_value("presets", key)
		if loaded is Array:
			prize_list.clear()
			for it in loaded:
				prize_list.append(str(it))
			_refresh_item_list_ui()
			_clear_all_balls()
			_rebuild_slots()
			_save_settings()

func _setup_system_buttons() -> void:
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	quit_button.pressed.connect(func(): get_tree().quit())
	launch_button.pressed.connect(_on_launch_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)

	display_settings_button.pressed.connect(_on_display_settings_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	$UI/DisplayPanel/VBox/CloseDisplayButton.pressed.connect(_close_all_panels)
	$UI/SettingsPanel/VBox/CloseSettingsButton.pressed.connect(_close_all_panels)

func _setup_version_label() -> void:
	var ver = ProjectSettings.get_setting("application/config/version", "1.0.0")
	version_label.text = "v" + str(ver)

func _on_display_settings_button_pressed() -> void:
	if display_panel.visible: _close_all_panels()
	else:
		settings_panel.hide()
		display_panel.show()
		_update_action_buttons_state()

func _on_settings_button_pressed() -> void:
	if settings_panel.visible: _close_all_panels()
	else:
		display_panel.hide()
		settings_panel.show()
		_update_action_buttons_state()

func _close_all_panels() -> void:
	display_panel.hide()
	settings_panel.hide()
	delete_confirm_panel.hide()
	_update_action_buttons_state()

func _is_any_panel_open() -> bool:
	return display_panel.visible or settings_panel.visible or delete_confirm_panel.visible

func _update_action_buttons_state() -> void:
	var is_open = _is_any_panel_open()
	launch_button.disabled = is_open or not can_launch or remaining_ball_count <= 0
	clear_button.disabled = is_open

func _on_ui_font_slider_value_changed(val: float) -> void:
	if is_initializing: return
	ui_font_size = int(val)
	_update_ui_font_size(ui_font_size)
	_save_settings()

func _on_slot_font_slider_value_changed(val: float) -> void:
	if is_initializing: return
	slot_font_size = int(val)
	queue_redraw()
	_save_settings()

func _on_sound_slider_value_changed(val: float) -> void:
	sound_volume = int(val)
	sound_label.text = "遊戲音效: " + str(sound_volume)
	if not is_initializing:
		_save_settings()

func _update_ui_font_size(new_size: int) -> void:
	var ui_nodes = [
		restart_button, quit_button, display_settings_button, settings_button,
		launch_button, clear_button,
		$UI/SettingsPanel/VBox/Title, $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/LeftTitle,
		$UI/SettingsPanel/VBox/ContentHBox/RightVBox/RightTitle, preset_name_input, save_preset_button,
		preset_option, delete_preset_button, add_input, add_button, delete_button, shuffle_button,
		$UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/BallCountLabel,
		ball_count_minus_button, ball_count_plus_button, ball_count_input,
		$UI/SettingsPanel/VBox/CloseSettingsButton, $UI/DisplayPanel/VBox/Title,
		$UI/DisplayPanel/VBox/BGColorLabel, $UI/DisplayPanel/VBox/UIFontLabel,
		$UI/DisplayPanel/VBox/SlotFontLabel, sound_label,
		$UI/DisplayPanel/VBox/EffectHBox/SlotEffectCheck,
		$UI/DisplayPanel/VBox/EffectHBox/BallStyleLabel, ball_style_option,
		$UI/DisplayPanel/VBox/CloseDisplayButton, $UI/DeleteConfirmPanel/VBox/Title,
		delete_confirm_text, $UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmOkButton,
		$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmCancelButton,
		$UI/ResultPanel/VBox/Title
	]
	for node in ui_nodes:
		if node:
			node.add_theme_font_size_override("font_size", new_size)
			if custom_font:
				node.add_theme_font_override("font", custom_font)

	if item_list:
		item_list.add_theme_font_size_override("font_size", max(10, new_size + item_list_font_offset))
		if custom_font: item_list.add_theme_font_override("font", custom_font)
		
	if result_log_text:
		result_log_text.add_theme_font_size_override("normal_font_size", max(12, new_size - 2))
		if custom_font: result_log_text.add_theme_font_override("normal_font", custom_font)

func _refresh_item_list_ui() -> void:
	item_list.clear()
	for p in prize_list: item_list.add_item(p)
	add_button.text = "新增"

func _on_item_list_item_selected(index: int) -> void:
	add_input.text = prize_list[index]
	add_button.text = "修改"

func _on_add_button_pressed() -> void:
	var txt = add_input.text.strip_edges()
	if txt == "": return
	var selected = item_list.get_selected_items()
	if selected.size() > 0:
		prize_list[selected[0]] = txt
		item_list.deselect_all()
	else:
		prize_list.append(txt)
	add_input.clear()
	_refresh_item_list_ui()
	_clear_all_balls()
	_rebuild_slots()
	_save_settings()

func _on_delete_button_pressed() -> void:
	var selected = item_list.get_selected_items()
	if selected.size() > 0:
		prize_list.remove_at(selected[0])
		add_input.clear()
		item_list.deselect_all()
		_refresh_item_list_ui()
		_clear_all_balls()
		_rebuild_slots()
		_save_settings()

func _on_shuffle_button_pressed() -> void:
	if prize_list.size() > 1:
		prize_list.shuffle()
		item_list.deselect_all()
		add_input.clear()
		_refresh_item_list_ui()
		_clear_all_balls()
		_rebuild_slots()
		_save_settings()

func _clear_all_balls() -> void:
	_clean_ball_particles_and_trails()
	for ball in active_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	active_balls.clear()
	ball_records.clear()
	current_ball_counter = 0
	
	remaining_ball_count = total_ball_count
	can_launch = true
	launch_timer = 0.0
	
	_update_launch_button_ui()
	_update_result_log_ui()

func _rebuild_slots() -> void:
	for c in slots_container.get_children(): c.queue_free()
	for c in board_node.get_children():
		if c.name.begins_with("SlotWall"): c.queue_free()
	_generate_slots()

func _setup_board_boundaries() -> void:
	var center_x = get_viewport_rect().size.x / 2.0
	_create_wall_rect(Vector2(center_x - board_width / 2.0 - 10, board_top_margin + board_height / 2.0), Vector2(20, board_height), "WallLeft")
	_create_wall_rect(Vector2(center_x + board_width / 2.0 + 10, board_top_margin + board_height / 2.0), Vector2(20, board_height), "WallRight")
	_create_wall_rect(Vector2(center_x, board_top_margin + board_height + 5), Vector2(board_width, 10), "WallBottom")

func _create_wall_rect(pos: Vector2, rect_size: Vector2, wall_name: String = "Wall") -> void:
	var col = CollisionShape2D.new()
	col.name = wall_name
	var shape = RectangleShape2D.new()
	shape.size = rect_size
	col.shape = shape
	col.position = pos
	board_node.add_child(col)

func _generate_pegs() -> void:
	var center_x = get_viewport_rect().size.x / 2.0
	var start_y = board_top_margin + peg_top_padding
	var available_height = board_height - peg_top_padding - peg_bottom_padding - slot_height
	var spacing_x = board_width / (peg_cols + 1)
	var spacing_y = available_height / max(1, (peg_rows - 1)) if peg_rows > 1 else 0.0

	for r in range(peg_rows):
		var offset_x = (spacing_x / 2.0) if (r % 2 == 1) else 0.0
		var cols_in_row = peg_cols - 1 if (r % 2 == 1) else peg_cols

		for c in range(cols_in_row):
			var peg_x = (center_x - board_width / 2.0) + spacing_x * (c + 1) + offset_x
			var peg_y = start_y + spacing_y * r

			var peg = StaticBody2D.new()
			peg.position = Vector2(peg_x, peg_y)

			var col = CollisionShape2D.new()
			var circle_shape = CircleShape2D.new()
			circle_shape.radius = peg_radius
			col.shape = circle_shape
			peg.add_child(col)

			var phys_mat = PhysicsMaterial.new()
			phys_mat.bounce = peg_bounce
			phys_mat.friction = 0.1
			peg.physics_material_override = phys_mat

			pegs_container.add_child(peg)

func _generate_slots() -> void:
	var center_x = get_viewport_rect().size.x / 2.0
	var current_count = max(1, prize_list.size())
	var slot_width = board_width / current_count
	var bottom_y = board_top_margin + board_height

	for i in range(current_count):
		var slot_left = (center_x - board_width / 2.0) + i * slot_width
		var slot_center_x = slot_left + slot_width / 2.0

		if i > 0:
			_create_wall_rect(Vector2(slot_left, bottom_y - slot_height / 2.0), Vector2(8, slot_height), "SlotWall_" + str(i))

		var area = Area2D.new()
		area.position = Vector2(slot_center_x, bottom_y - 12)
		area.name = "SlotArea_" + str(i)

		var col = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(slot_width - 8, 16)
		col.shape = rect_shape
		area.add_child(col)

		var prize_name = prize_list[i]
		area.body_entered.connect(func(body): _on_slot_entered(body, prize_name, area))

		slots_container.add_child(area)

func _on_launch_button_pressed() -> void:
	if not can_launch or _is_any_panel_open() or remaining_ball_count <= 0: return

	remaining_ball_count -= 1
	_update_launch_button_ui()

	can_launch = false
	launch_timer = launch_cooldown
	if remaining_ball_count <= 0:
		launch_button.disabled = true

	var ball = RigidBody2D.new()
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = ball_bounce
	phys_mat.friction = 0.05
	ball.physics_material_override = phys_mat
	ball.mass = ball_mass
	ball.gravity_scale = ball_gravity_scale
	
	ball.linear_damp = 0.8
	ball.angular_damp = 0.8

	var col = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = ball_radius
	col.shape = circle_shape
	ball.add_child(col)

	# 火焰粒子效果 (模式 4)
	if ball_style_type == 4:
		_attach_fire_particle_effect(ball)

	var spawn_pos = ball_spawner.global_position
	spawn_pos.x += randf_range(-spawn_x_offset, spawn_x_offset)
	ball.position = spawn_pos

	add_child(ball)
	active_balls.append(ball)

	current_ball_counter += 1
	ball_records.append({
		"id": current_ball_counter,
		"ball": ball,
		"prize": "滾動中..."
	})
	_update_result_log_ui()

func _attach_fire_particle_effect(ball: RigidBody2D) -> void:
	var particles = CPUParticles2D.new()
	particles.name = "FireParticles"
	particles.amount = 25
	particles.lifetime = 0.4
	particles.explosiveness = 0.05
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = ball_radius * 0.7
	particles.direction = Vector2(0, -1)
	particles.spread = 25.0
	particles.gravity = Vector2(0, -250)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = Color("#FF5722")
	ball.add_child(particles)

func _on_clear_button_pressed() -> void:
	if _is_any_panel_open(): return
	_clear_all_balls()

func _on_slot_entered(body: Node2D, prize_name: String, _area: Area2D) -> void:
	if body is RigidBody2D and body in active_balls:
		for rec in ball_records:
			if rec["ball"] == body:
				rec["prize"] = prize_name
				_update_result_log_ui()
				break

func _get_balls_in_slot(slot_idx: int, slot_width: float, center_x: float, bottom_y: float) -> int:
	var slot_left = (center_x - board_width / 2.0) + slot_idx * slot_width
	var slot_right = slot_left + slot_width
	var count = 0
	for ball in active_balls:
		if is_instance_valid(ball):
			if ball.position.x >= slot_left and ball.position.x <= slot_right and ball.position.y >= (bottom_y - slot_height):
				count += 1
	return count

func _draw() -> void:
	var view_size = get_viewport_rect().size
	var center_x = view_size.x / 2.0
	var time_sec = Time.get_ticks_msec() / 1000.0

	# 1. 全域背景
	draw_rect(Rect2(Vector2.ZERO, view_size), current_bg_color, true)

	# 2. 彈珠台背景與外框
	var calculated_board_bg = current_bg_color.darkened(board_bg_darken_factor) if board_bg_darken_factor >= 0 else current_bg_color.lightened(abs(board_bg_darken_factor))
	var board_rect = Rect2(center_x - board_width / 2.0, board_top_margin, board_width, board_height)
	draw_rect(board_rect, calculated_board_bg, true)
	draw_rect(board_rect, board_border_color, false, 4.0)

	# 3. 釘子
	for peg in pegs_container.get_children():
		if peg_outline_width > 0.0:
			draw_circle(peg.position, peg_radius + peg_outline_width, peg_outline_color)
		draw_circle(peg.position, peg_radius, peg_color)

	# 4. 獨立壽命殘影繪製 (模式 2: 幻影滷蛋)
	if ball_style_type == 2:
		for g in phantom_ghosts:
			var alpha_ratio = clamp(g["life"] / g["max_life"], 0.0, 1.0) * 0.45
			var ball_size = Vector2(ball_radius * 2.0, ball_radius * 2.0)
			draw_set_transform(g["pos"], g["rot"], Vector2.ONE)
			if egg_texture:
				draw_texture_rect(egg_texture, Rect2(-ball_size / 2.0, ball_size), false, Color(1, 1, 1, alpha_ratio))
			else:
				draw_circle(Vector2.ZERO, ball_radius, Color(0.55, 0.43, 0.39, alpha_ratio))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5. 彩虹拖尾繪製 (模式 3)
	if ball_style_type == 3:
		for ball in active_balls:
			if is_instance_valid(ball) and ball_trails.has(ball):
				var trail: Array = ball_trails[ball]
				for t_idx in range(trail.size()):
					var alpha = float(t_idx + 1) / float(trail.size()) * 0.45
					var hue = fmod(time_sec * 0.5 + float(t_idx) * 0.03, 1.0)
					var rainbow_col = Color.from_hsv(hue, 0.8, 1.0, alpha)
					var radius = ball_radius * (0.3 + 0.7 * alpha)
					draw_circle(trail[t_idx], radius, rainbow_col)

	# 6. 彈珠本體繪製
	for ball in active_balls:
		if is_instance_valid(ball):
			if ball_style_type in [1, 2]: # 1: 滷蛋彈珠, 2: 幻影滷蛋
				var ball_size = Vector2(ball_radius * 2.0, ball_radius * 2.0)
				draw_set_transform(ball.position, ball.rotation, Vector2.ONE)
				if egg_texture:
					draw_texture_rect(egg_texture, Rect2(-ball_size / 2.0, ball_size), false)
				else:
					draw_circle(Vector2.ZERO, ball_radius, Color("#8D6E63"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif ball_style_type == 3: # 3: 彩虹彈珠本體
				var current_hue = fmod(time_sec * 0.6 + ball.get_instance_id() * 0.1, 1.0)
				var rainbow_color = Color.from_hsv(current_hue, 0.85, 1.0)
				draw_circle(ball.position, ball_radius, rainbow_color)
			elif ball_style_type == 4: # 4: 火焰彈珠本體
				draw_circle(ball.position, ball_radius, fire_ball_color)
			else: # 0: 普通彈珠
				draw_circle(ball.position, ball_radius, ball_color)

	# 7. 獎項文字與動態特效渲染
	var current_count = max(1, prize_list.size())
	var slot_width = board_width / current_count
	var bottom_y = board_top_margin + board_height
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font

	for i in range(current_count):
		var slot_left = (center_x - board_width / 2.0) + i * slot_width
		if i > 0:
			draw_line(Vector2(slot_left, bottom_y - slot_height), Vector2(slot_left, bottom_y), Color.WHITE, 2.0)
		
		var prize_name = prize_list[i]
		var balls_in_this_slot = _get_balls_in_slot(i, slot_width, center_x, bottom_y)
		
		var text_color = slot_color_normal
		var draw_font_size: int = slot_font_size
		var text_offset_y = 0.0

		if enable_slot_effects and balls_in_this_slot > 0:
			text_offset_y = sin(time_sec * slot_shake_speed) * 2.0
			if balls_in_this_slot == 1:
				text_color = slot_color_single
				draw_font_size = roundi(slot_font_size * 1.15)
			else:
				text_color = slot_color_multiple
				draw_font_size = roundi(slot_font_size * 1.25)
				prize_name += " x" + str(balls_in_this_slot)

		var text_pos = Vector2(slot_left + 2, bottom_y - 10 + text_offset_y)
		if enable_slot_effects and balls_in_this_slot > 0 and slot_outline_width > 0:
			draw_string_outline(font_to_use, text_pos, prize_name, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, draw_font_size, slot_outline_width, Color.BLACK)
		
		draw_string(font_to_use, text_pos, prize_name, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, draw_font_size, text_color)
