extends Control

# ==========================================
# ⚙️ 可調整參數區 (Inspector 面板可直接選色與微調)
# ==========================================
@export_group("系統與預設字體大小")
@export var default_ui_font_size: int = 20          # 一般 UI 按鈕與選單預設大小
@export var default_slot_font_size: int = 42        # 獎品區文字預設大小
@export var item_list_font_offset: int = -4         # 獎項列表字體縮放偏移量

@export_group("畫面設定 - 字體 Bar 上下限設定")
@export var ui_font_min: float = 12.0               # UI 字體最小值
@export var ui_font_max: float = 40.0               # UI 字體最大值
@export var slot_font_min: float = 16.0             # 獎品區字體最小值
@export var slot_font_max: float = 80.0             # 獎品區字體最大值

@export_group("色彩與視覺設定 (Colors & Visuals)")
@export var bg_color_palette: Array[Color] = [
	Color("#1F242E"), Color("#14141A"), Color("#2E1F33"),
	Color("#1A332E"), Color("#382424"), Color("#404047")
]
@export var board_bg_darken_factor: float = -0.08    # 彈珠台內部背景自動加深/變亮係數
@export var board_border_color: Color = Color("cccccc") # 彈珠台邊框顏色
@export var peg_color: Color = Color("ffd700")          # 釘子填滿顏色
@export var peg_outline_color: Color = Color("8b6508")  # 釘子描邊顏色
@export var peg_outline_width: float = 0.0              # 釘子描邊粗細
@export var ball_color: Color = Color("1e90ff")         # 彈珠顏色
@export var fire_ball_color: Color = Color("#FF3D00")   # 火焰彈珠專用球體顏色
@export var lightning_ball_color: Color = Color("#E0F7FA") # ⚡ 閃電彈珠專用球體顏色 (冰藍白)

@export_group("獎品區特效與色彩 (Slot FX)")
@export var slot_outline_width: int = 15             # 獎品區文字描邊厚度
@export var slot_color_normal: Color = Color("#FFFFFF")   # 無彈珠顏色 (白色)
@export var slot_color_single: Color = Color("#ffeb3a")   # 1顆彈珠顏色 (淡黃色)
@export var slot_color_multiple: Color = Color("#00E5FF") # 2顆彈珠顏色 (亮青色)
@export var slot_color_triple: Color = Color("#E040FB")   # 3顆彈珠顏色 (淡紫色)
@export var slot_color_quad: Color = Color("#FF1744")     # 4顆以上彈珠顏色 (亮紅色)
@export var slot_shake_speed: float = 10.0          # 統一文字晃動速度 (Hz)

@export_group("彈珠樣式與特效 (Ball Style)")
@export var egg_ball_scale: float = 2.0             # 滷蛋彈珠圖片顯示放大倍率
@export var egg_folder_path: String = "res://Assets/EggBall/" # 滷蛋圖庫資料夾路徑

@export_group("彈珠台尺寸與位置 (Board Size)")
@export var board_width: float = 720.0     # 彈珠台寬度
@export var board_height: float = 560.0    # 彈珠台高度
@export var board_top_margin: float = 40.0 # 全域頂部留白距離

@export_group("釘子與間距 (Pegs)")
@export var peg_rows: int = 5               # 釘子列數
@export var peg_cols: int = 11              # 釘子行數
@export var peg_radius: float = 10.0         # 釘子半徑大小
@export var peg_bounce: float = 0.7         # 釘子彈性 (0.0~1.0)
@export var peg_top_padding: float = 120.0  # 上邊框到最上排釘子的距離
@export var peg_bottom_padding: float = 80.0# 最下排釘子到獎項區的距離

@export_group("獎項小格子 (Slots)")
@export var slot_height: float = 70.0       # 獨立小格子的高度

@export_group("彈珠與發射機制 (Ball & Launch)")
@export var ball_radius: float = 14.0       # 彈珠半徑
@export var ball_bounce: float = 0.6        # 彈珠彈性
@export var ball_mass: float = 1.0          # 彈珠質量
@export var ball_gravity_scale: float = 1.2 # 重力倍率
@export var spawn_x_offset: float = 130.0    # 發射初始位置隨機 X 軸偏移範圍
@export var launch_cooldown: float = 0.15    # 最短發射間隔時間 (秒)

# --- 內部模組與狀態 ---
var rule_mgr: GameRuleManager = GameRuleManager.new()
var fx_mgr: BallEffectManager = BallEffectManager.new()

var remaining_ball_count: int = 10
var is_initializing: bool = true
var pending_delete_preset_name: String = ""

var ball_records: Array[Dictionary] = []
var current_ball_counter: int = 0
var egg_textures: Array[Texture2D] = []
var ball_texture_map: Dictionary = {} 

# --- 節點引用 ---
@onready var ball_spawner: Marker2D = $BallSpawner
@onready var board_node: StaticBody2D = $Board
@onready var pegs_container: Node2D = $Pegs
@onready var slots_container: Node2D = $Slots
@onready var mascot_node: TextureRect = $UI/MascotRect

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

@onready var add_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/InputHBox/AddInput
@onready var add_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/InputHBox/AddButton
@onready var item_list: ItemList = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ItemList
@onready var delete_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ActionHBox/DeleteButton
@onready var shuffle_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ActionHBox/ShuffleButton
@onready var preset_name_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSaveHBox/PresetNameInput
@onready var save_preset_button: Button = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSaveHBox/SavePresetButton
@onready var preset_option: OptionButton = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSelectHBox/PresetOption
@onready var delete_preset_button: Button = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSelectHBox/DeletePresetButton

@onready var ball_count_minus_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/MinusButton
@onready var ball_count_plus_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/PlusButton
@onready var ball_count_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/BallCountInput

@onready var bg_color_hbox: HBoxContainer = $UI/DisplayPanel/VBox/BGColorHBox
@onready var ui_font_label: Label = $UI/DisplayPanel/VBox/UIFontLabel
@onready var ui_font_slider: HSlider = $UI/DisplayPanel/VBox/UIFontSlider
@onready var slot_font_label: Label = $UI/DisplayPanel/VBox/SlotFontLabel
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
	add_child(rule_mgr)
	add_child(fx_mgr)
	
	_setup_panel_opaque_styles()

	if ResourceLoader.exists("res://NotoSansTC-VariableFont_wght.ttf"):
		custom_font = load("res://NotoSansTC-VariableFont_wght.ttf")

	_load_egg_textures()
	_setup_ball_style_option_ui()
	
	var default_bg = bg_color_palette[0] if bg_color_palette.size() > 0 else Color("#1F242E")
	rule_mgr.load_settings(default_bg)

	ui_font_slider.min_value = ui_font_min
	ui_font_slider.max_value = ui_font_max
	slot_font_slider.min_value = slot_font_min
	slot_font_slider.max_value = slot_font_max

	_apply_loaded_settings()
	
	remaining_ball_count = rule_mgr.total_ball_count
	_setup_system_buttons()
	_setup_version_label()
	_setup_bg_color_buttons()
	_refresh_preset_options()

	# 💡 選單事件：支援點選其他項目與強制點選當前項目刷新
	preset_option.item_selected.connect(_on_preset_selected)
	preset_option.get_popup().index_pressed.connect(_on_preset_item_clicked)
	
	add_button.pressed.connect(_on_add_button_pressed)
	add_input.text_submitted.connect(_on_add_input_submitted)
	item_list.item_selected.connect(_on_item_list_item_selected)
	delete_button.pressed.connect(_on_delete_button_pressed)
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	save_preset_button.pressed.connect(_on_save_preset_button_pressed)
	delete_preset_button.pressed.connect(_on_delete_preset_button_pressed)

	ball_count_minus_button.pressed.connect(_on_ball_count_minus_pressed)
	ball_count_plus_button.pressed.connect(_on_ball_count_plus_pressed)
	ball_count_input.text_submitted.connect(_on_ball_count_input_submitted)

	$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmOkButton.pressed.connect(_on_delete_confirm_ok_pressed)
	$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmCancelButton.pressed.connect(_on_delete_confirm_cancel_pressed)

	ui_font_slider.value_changed.connect(_on_ui_font_slider_value_changed)
	slot_font_slider.value_changed.connect(_on_slot_font_slider_value_changed)
	sound_slider.value_changed.connect(_on_sound_slider_value_changed)
	
	slot_effect_check.toggled.connect(_on_slot_effect_check_toggled)
	ball_style_option.item_selected.connect(_on_ball_style_selected)
	
	_update_ui_font_size(rule_mgr.ui_font_size)
	_refresh_item_list_ui()
	_update_launch_button_ui()
	_update_result_log_ui()
	_reset_mascot_to_default()
	
	_setup_board_boundaries()
	_generate_pegs()
	_generate_slots()

	var view_size = get_viewport_rect().size
	ball_spawner.position = Vector2(view_size.x / 2.0, board_top_margin + 20)
	is_initializing = false

# 💡 確保點擊原本就選中的選項也能重置/回檔
func _on_preset_item_clicked(index: int) -> void:
	if preset_option.selected == index:
		_on_preset_selected(index)

func _on_add_input_submitted(_text: String) -> void: _on_add_button_pressed()
func _on_ball_count_minus_pressed() -> void: _update_total_ball_count(rule_mgr.total_ball_count - 1)
func _on_ball_count_plus_pressed() -> void: _update_total_ball_count(rule_mgr.total_ball_count + 1)
func _on_slot_effect_check_toggled(val: bool) -> void: rule_mgr.enable_slot_effects = val; rule_mgr.save_settings()

func _setup_panel_opaque_styles() -> void:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.17, 0.22, 1.0)
	style_box.corner_radius_top_left = 12; style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12; style_box.corner_radius_bottom_right = 12
	style_box.content_margin_left = 16; style_box.content_margin_top = 16
	style_box.content_margin_right = 16; style_box.content_margin_bottom = 16

	settings_panel.add_theme_stylebox_override("panel", style_box)
	display_panel.add_theme_stylebox_override("panel", style_box)
	delete_confirm_panel.add_theme_stylebox_override("panel", style_box)

func _apply_loaded_settings() -> void:
	ui_font_slider.value = rule_mgr.ui_font_size
	slot_font_slider.value = rule_mgr.slot_font_size
	ui_font_label.text = "一般 UI 按鈕與選單大小: " + str(rule_mgr.ui_font_size)
	slot_font_label.text = "獎品區文字大小: " + str(rule_mgr.slot_font_size)
	sound_label.text = "遊戲音效: " + str(rule_mgr.sound_volume)
	sound_slider.value = rule_mgr.sound_volume
	
	if AudioManager: AudioManager.set_volume(rule_mgr.sound_volume)
	slot_effect_check.button_pressed = rule_mgr.enable_slot_effects
	ball_style_option.select(rule_mgr.ball_style_type)
	ball_count_input.text = str(rule_mgr.total_ball_count)

func _load_egg_textures() -> void:
	egg_textures.clear()
	if DirAccess.dir_exists_absolute(egg_folder_path):
		var dir = DirAccess.open(egg_folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			var loaded_files: Array[String] = []
			while file_name != "":
				if not dir.current_is_dir():
					var clean_name = file_name.replace(".remap", "").replace(".import", "")
					if clean_name.ends_with(".png") or clean_name.ends_with(".jpg"):
						if not clean_name in loaded_files: loaded_files.append(clean_name)
				file_name = dir.get_next()
			dir.list_dir_end()
			
			loaded_files.sort()
			for f in loaded_files:
				var full_path = egg_folder_path.path_join(f)
				var tex = load(full_path) as Texture2D
				if tex and not egg_textures.has(tex): egg_textures.append(tex)
	
	if egg_textures.size() == 0 and ResourceLoader.exists("res://egg_ball.png"):
		var single_tex = load("res://egg_ball.png") as Texture2D
		if single_tex: egg_textures.append(single_tex)

func _reset_mascot_to_default() -> void:
	if egg_textures.size() > 0 and mascot_node and mascot_node.has_method("set_mascot_texture"):
		mascot_node.set_mascot_texture(egg_textures[0])

func _setup_ball_style_option_ui() -> void:
	ball_style_option.clear()
	ball_style_option.add_item("普通彈珠")   # 0
	ball_style_option.add_item("滷蛋彈珠")   # 1
	ball_style_option.add_item("幻影滷蛋")   # 2
	ball_style_option.add_item("彩虹彈珠")   # 3
	ball_style_option.add_item("火焰彈珠")   # 4
	ball_style_option.add_item("閃電彈珠")   # 5
	ball_style_option.add_item("雷射彈珠")   # 6
	ball_style_option.add_item("時空彈珠")   # 7

func _on_ball_style_selected(idx: int) -> void:
	rule_mgr.ball_style_type = idx
	fx_mgr.clear_all(active_balls)
	ball_texture_map.clear()
	
	for ball in active_balls:
		if is_instance_valid(ball):
			fx_mgr.on_ball_spawned(ball, rule_mgr.ball_style_type, ball_radius)
	rule_mgr.save_settings()

func _process(delta: float) -> void:
	if not can_launch:
		launch_timer -= delta
		if launch_timer <= 0:
			can_launch = true
			_update_action_buttons_state()

	active_balls = active_balls.filter(func(b): return is_instance_valid(b))
	if is_instance_valid(fx_mgr) and fx_mgr.has_method("process_effects"):
		fx_mgr.process_effects(delta, active_balls, rule_mgr.ball_style_type, ball_texture_map)
	queue_redraw()

func _update_result_log_ui() -> void:
	var log_text = ""
	for item in ball_records: log_text += "(%d) %s\n" % [item["id"], item["prize"]]
	result_log_text.text = log_text

func _update_total_ball_count(new_val: int) -> void:
	rule_mgr.total_ball_count = clamp(new_val, 1, rule_mgr.max_ball_count_limit)
	ball_count_input.text = str(rule_mgr.total_ball_count)
	_clear_all_balls(); rule_mgr.save_settings()

func _on_ball_count_input_submitted(txt: String) -> void:
	if txt.is_valid_int(): _update_total_ball_count(txt.to_int())
	else: ball_count_input.text = str(rule_mgr.total_ball_count)

func _update_launch_button_ui() -> void:
	launch_button.text = "發射彈珠 (" + str(remaining_ball_count) + ")"
	_update_action_buttons_state()

func _setup_bg_color_buttons() -> void:
	for c in bg_color_hbox.get_children(): c.queue_free()
	for c in bg_color_palette:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		var style = StyleBoxFlat.new()
		style.bg_color = c
		style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
		style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
		style.border_color = Color.WHITE if c == rule_mgr.current_bg_color else Color(0.4, 0.4, 0.4, 0.5)
		btn.add_theme_stylebox_override("normal", style); btn.add_theme_stylebox_override("hover", style); btn.add_theme_stylebox_override("pressed", style)
		btn.pressed.connect(_on_bg_color_selected.bind(c))
		bg_color_hbox.add_child(btn)

func _on_bg_color_selected(color: Color) -> void:
	rule_mgr.current_bg_color = color
	_setup_bg_color_buttons(); rule_mgr.save_settings()

func _refresh_preset_options() -> void:
	preset_option.clear()
	var names = rule_mgr.get_preset_names()
	for n in names: preset_option.add_item(n)
	var has_presets = preset_option.item_count > 0
	delete_preset_button.disabled = not has_presets
	if not has_presets:
		preset_option.add_item("(無歷史名單)"); preset_option.disabled = true
	else: preset_option.disabled = false

func _on_save_preset_button_pressed() -> void:
	var name_txt = preset_name_input.text.strip_edges()
	if name_txt == "": return
	rule_mgr.save_preset(name_txt)
	preset_name_input.clear(); _refresh_preset_options()

func _on_delete_preset_button_pressed() -> void:
	if preset_option.disabled or preset_option.selected < 0: return
	pending_delete_preset_name = preset_option.get_item_text(preset_option.selected)
	delete_confirm_text.text = "確定要刪除預設名單：\n【 " + pending_delete_preset_name + " 】嗎？"
	delete_confirm_panel.show(); _update_action_buttons_state()

func _on_delete_confirm_ok_pressed() -> void:
	delete_confirm_panel.hide()
	if pending_delete_preset_name != "":
		if rule_mgr.delete_preset(pending_delete_preset_name): _refresh_preset_options()
		pending_delete_preset_name = ""
	_update_action_buttons_state()

func _on_delete_confirm_cancel_pressed() -> void:
	delete_confirm_panel.hide(); pending_delete_preset_name = ""
	_update_action_buttons_state()

func _on_preset_selected(idx: int) -> void:
	if preset_option.disabled or idx < 0: return
	var key = preset_option.get_item_text(idx)
	if rule_mgr.load_preset(key):
		_refresh_item_list_ui(); _clear_all_balls(); _rebuild_slots(); rule_mgr.save_settings()

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
	else: settings_panel.hide(); delete_confirm_panel.hide(); display_panel.show(); _update_action_buttons_state()

func _on_settings_button_pressed() -> void:
	if settings_panel.visible: _close_all_panels()
	else: display_panel.hide(); delete_confirm_panel.hide(); settings_panel.show(); _update_action_buttons_state()

func _close_all_panels() -> void:
	display_panel.hide(); settings_panel.hide(); delete_confirm_panel.hide(); _update_action_buttons_state()

func _is_any_panel_open() -> bool:
	return display_panel.visible or settings_panel.visible or delete_confirm_panel.visible

func _update_action_buttons_state() -> void:
	var is_open = _is_any_panel_open()
	launch_button.disabled = is_open or not can_launch or remaining_ball_count <= 0
	clear_button.disabled = is_open

func _on_ui_font_slider_value_changed(val: float) -> void:
	if is_initializing: return
	rule_mgr.ui_font_size = int(val); ui_font_label.text = "一般 UI 按鈕與選單大小: " + str(rule_mgr.ui_font_size)
	_update_ui_font_size(rule_mgr.ui_font_size); rule_mgr.save_settings()

func _on_slot_font_slider_value_changed(val: float) -> void:
	if is_initializing: return
	rule_mgr.slot_font_size = int(val); slot_font_label.text = "獎品區文字大小: " + str(rule_mgr.slot_font_size)
	queue_redraw(); rule_mgr.save_settings()

func _on_sound_slider_value_changed(val: float) -> void:
	rule_mgr.sound_volume = int(val); sound_label.text = "遊戲音效: " + str(rule_mgr.sound_volume)
	if AudioManager: AudioManager.set_volume(rule_mgr.sound_volume)
	if not is_initializing: rule_mgr.save_settings()

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
		$UI/DisplayPanel/VBox/BGColorLabel, ui_font_label,
		slot_font_label, sound_label,
		$UI/DisplayPanel/VBox/EffectHBox/SlotEffectCheck,
		$UI/DisplayPanel/VBox/EffectHBox/BallStyleLabel, ball_style_option,
		$UI/DisplayPanel/VBox/CloseDisplayButton, $UI/DeleteConfirmPanel/VBox/Title,
		delete_confirm_text, $UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmOkButton,
		$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmCancelButton, $UI/ResultPanel/VBox/Title
	]
	for node in ui_nodes:
		if node:
			node.add_theme_font_size_override("font_size", new_size)
			if custom_font: node.add_theme_font_override("font", custom_font)

	if item_list:
		item_list.add_theme_font_size_override("font_size", max(10, new_size + item_list_font_offset))
		if custom_font: item_list.add_theme_font_override("font", custom_font)
		
	if result_log_text:
		result_log_text.add_theme_font_size_override("normal_font_size", max(12, new_size - 2))
		if custom_font: result_log_text.add_theme_font_override("normal_font", custom_font)

func _refresh_item_list_ui() -> void:
	item_list.clear()
	for p in rule_mgr.prize_list: item_list.add_item(p)
	add_button.text = "新增"

func _on_item_list_item_selected(index: int) -> void:
	add_input.text = rule_mgr.prize_list[index]; add_button.text = "修改"

func _on_add_button_pressed() -> void:
	var txt = add_input.text.strip_edges()
	if txt == "": return
	var selected = item_list.get_selected_items()
	if selected.size() > 0: rule_mgr.prize_list[selected[0]] = txt; item_list.deselect_all()
	else: rule_mgr.prize_list.append(txt)
	add_input.clear(); _refresh_item_list_ui(); _clear_all_balls(); _rebuild_slots(); rule_mgr.save_settings()

func _on_delete_button_pressed() -> void:
	var selected = item_list.get_selected_items()
	if selected.size() > 0:
		rule_mgr.prize_list.remove_at(selected[0])
		add_input.clear(); item_list.deselect_all(); _refresh_item_list_ui(); _clear_all_balls(); _rebuild_slots(); rule_mgr.save_settings()

func _on_shuffle_button_pressed() -> void:
	if rule_mgr.prize_list.size() > 1:
		rule_mgr.prize_list.shuffle(); item_list.deselect_all(); add_input.clear()
		_refresh_item_list_ui(); _clear_all_balls(); _rebuild_slots(); rule_mgr.save_settings()

func _clear_all_balls() -> void:
	if is_instance_valid(fx_mgr) and fx_mgr.has_method("clear_all"):
		fx_mgr.clear_all(active_balls)
	for ball in active_balls:
		if is_instance_valid(ball): ball.queue_free()
	active_balls.clear(); ball_records.clear(); current_ball_counter = 0
	remaining_ball_count = rule_mgr.total_ball_count; can_launch = true; launch_timer = 0.0
	_reset_mascot_to_default(); _update_launch_button_ui(); _update_result_log_ui()

# 💡 隱形牆壁修復點：徹底清理所有包含 CollisionShape2D 的邊界，避免牆壁堆疊
func _rebuild_slots() -> void:
	# 1. 清除舊的 Area2D 格子
	for c in slots_container.get_children():
		c.queue_free()
		
	# 2. 清除 Board 節點下所有舊的 CollisionShape2D (包含 SlotWall 與 外圍邊界 Wall)
	for c in board_node.get_children():
		if c is CollisionShape2D:
			c.queue_free()
			
	# 3. 重新計算建立外圍邊界與小格子
	_setup_board_boundaries()
	_generate_slots()

func _setup_board_boundaries() -> void:
	var center_x = get_viewport_rect().size.x / 2.0
	_create_wall_rect(Vector2(center_x - board_width / 2.0 - 10, board_top_margin + board_height / 2.0), Vector2(20, board_height), "WallLeft")
	_create_wall_rect(Vector2(center_x + board_width / 2.0 + 10, board_top_margin + board_height / 2.0), Vector2(20, board_height), "WallRight")
	_create_wall_rect(Vector2(center_x, board_top_margin + board_height + 5), Vector2(board_width, 10), "WallBottom")

func _create_wall_rect(pos: Vector2, rect_size: Vector2, wall_name: String = "Wall") -> void:
	var col = CollisionShape2D.new(); col.name = wall_name
	var shape = RectangleShape2D.new(); shape.size = rect_size
	col.shape = shape; col.position = pos; board_node.add_child(col)

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
			var peg = RigidBody2D.new()
			peg.freeze = true; peg.position = Vector2(peg_x, peg_y); peg.max_contacts_reported = 3; peg.contact_monitor = true

			var col = CollisionShape2D.new(); var circle_shape = CircleShape2D.new()
			circle_shape.radius = peg_radius; col.shape = circle_shape; peg.add_child(col)

			var phys_mat = PhysicsMaterial.new(); phys_mat.bounce = peg_bounce; phys_mat.friction = 0.1
			peg.physics_material_override = phys_mat
			peg.body_entered.connect(_on_peg_body_entered)
			pegs_container.add_child(peg)

func _on_peg_body_entered(_body: Node) -> void:
	if AudioManager and AudioManager.has_method("play_peg_bounce"): AudioManager.play_peg_bounce()

func _generate_slots() -> void:
	var center_x = get_viewport_rect().size.x / 2.0
	var current_count = max(1, rule_mgr.prize_list.size())
	var slot_width = board_width / current_count
	var bottom_y = board_top_margin + board_height

	for i in range(current_count):
		var slot_left = (center_x - board_width / 2.0) + i * slot_width
		var slot_center_x = slot_left + slot_width / 2.0
		if i > 0: _create_wall_rect(Vector2(slot_left, bottom_y - slot_height / 2.0), Vector2(8, slot_height), "SlotWall_" + str(i))

		var area = Area2D.new(); area.position = Vector2(slot_center_x, bottom_y - 12); area.name = "SlotArea_" + str(i)
		var col = CollisionShape2D.new(); var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(slot_width - 8, 16); col.shape = rect_shape; area.add_child(col)

		var prize_name = rule_mgr.prize_list[i]
		area.body_entered.connect(_on_slot_entered.bind(prize_name, area))
		slots_container.add_child(area)

func _on_launch_button_pressed() -> void:
	if not can_launch or _is_any_panel_open() or remaining_ball_count <= 0: return

	remaining_ball_count -= 1; _update_launch_button_ui()
	can_launch = false; launch_timer = launch_cooldown
	if remaining_ball_count <= 0: launch_button.disabled = true

	var ball = RigidBody2D.new()
	ball.contact_monitor = true; ball.max_contacts_reported = 3
	var phys_mat = PhysicsMaterial.new(); phys_mat.bounce = ball_bounce; phys_mat.friction = 0.05
	ball.physics_material_override = phys_mat; ball.mass = ball_mass; ball.gravity_scale = ball_gravity_scale
	ball.linear_damp = 0.8; ball.angular_damp = 0.8

	var col = CollisionShape2D.new(); var circle_shape = CircleShape2D.new()
	circle_shape.radius = ball_radius; col.shape = circle_shape; ball.add_child(col)

	ball.body_entered.connect(_on_ball_body_entered.bind(ball))

	if egg_textures.size() > 0:
		var picked_tex = egg_textures.pick_random()
		ball_texture_map[ball] = picked_tex
		if mascot_node and mascot_node.has_method("set_mascot_texture"): mascot_node.set_mascot_texture(picked_tex)

	if is_instance_valid(fx_mgr) and fx_mgr.has_method("on_ball_spawned"):
		fx_mgr.on_ball_spawned(ball, rule_mgr.ball_style_type, ball_radius)

	var spawn_pos = ball_spawner.global_position
	spawn_pos.x += randf_range(-spawn_x_offset, spawn_x_offset)
	ball.position = spawn_pos

	add_child(ball); active_balls.append(ball)
	current_ball_counter += 1
	ball_records.append({"id": current_ball_counter, "ball": ball, "prize": "滾動中..."})
	_update_result_log_ui()

# 💡 安全的具名碰撞處理函式 (解決 Lambda 閉包 freed 報錯問題)
func _on_ball_body_entered(_body: Node, ball: RigidBody2D) -> void:
	if is_instance_valid(ball) and ball.linear_velocity.length() > 20.0:
		if AudioManager and AudioManager.has_method("play_peg_bounce"):
			AudioManager.play_peg_bounce()
		
		# 獲取精確碰撞點傳給特效總管
		var contact_pos = ball.global_position
		var state = PhysicsServer2D.body_get_direct_state(ball.get_rid())
		if state and state.get_contact_count() > 0:
			contact_pos = state.get_contact_local_position(0)
		
		# 無條件丟給特效經理分流
		if is_instance_valid(fx_mgr) and fx_mgr.has_method("on_ball_impact"):
			fx_mgr.on_ball_impact(self, ball, contact_pos, rule_mgr.ball_style_type)

func _on_clear_button_pressed() -> void:
	if _is_any_panel_open(): return
	_clear_all_balls()

func _on_slot_entered(body: Node2D, prize_name: String, _area: Area2D) -> void:
	if body is RigidBody2D and body in active_balls:
		for rec in ball_records:
			if rec["ball"] == body:
				if rec["prize"] == "滾動中..." and AudioManager and AudioManager.has_method("play_slot_win"):
					AudioManager.play_slot_win()
				rec["prize"] = prize_name; _update_result_log_ui(); break

func _get_balls_in_slot(slot_idx: int, slot_width: float, center_x: float, bottom_y: float) -> int:
	var slot_left = (center_x - board_width / 2.0) + slot_idx * slot_width
	var slot_right = slot_left + slot_width
	var count = 0
	for ball in active_balls:
		if is_instance_valid(ball) and ball.position.x >= slot_left and ball.position.x <= slot_right and ball.position.y >= (bottom_y - slot_height): count += 1
	return count

# 💡 渲染全部委任給特效管理員
func _draw() -> void:
	var view_size = get_viewport_rect().size; var center_x = view_size.x / 2.0; var time_sec = Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(Vector2.ZERO, view_size), rule_mgr.current_bg_color, true)

	var calculated_board_bg = rule_mgr.current_bg_color.darkened(board_bg_darken_factor) if board_bg_darken_factor >= 0 else rule_mgr.current_bg_color.lightened(abs(board_bg_darken_factor))
	var board_rect = Rect2(center_x - board_width / 2.0, board_top_margin, board_width, board_height)
	draw_rect(board_rect, calculated_board_bg, true); draw_rect(board_rect, board_border_color, false, 4.0)

	for peg in pegs_container.get_children():
		if peg_outline_width > 0.0: draw_circle(peg.position, peg_radius + peg_outline_width, peg_outline_color)
		draw_circle(peg.position, peg_radius, peg_color)

	if is_instance_valid(fx_mgr) and fx_mgr.has_method("draw_all_ball_visuals"):
		fx_mgr.draw_all_ball_visuals(self, active_balls, rule_mgr.ball_style_type, ball_radius, time_sec, egg_ball_scale, ball_color, fire_ball_color, lightning_ball_color, egg_textures, ball_texture_map)

	var current_count = max(1, rule_mgr.prize_list.size())
	var slot_width = board_width / current_count
	var bottom_y = board_top_margin + board_height
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font

	for i in range(current_count):
		var slot_left = (center_x - board_width / 2.0) + i * slot_width
		if i > 0: draw_line(Vector2(slot_left, bottom_y - slot_height), Vector2(slot_left, bottom_y), Color.WHITE, 2.0)
		
		var prize_name = rule_mgr.prize_list[i]
		var balls_in_this_slot = _get_balls_in_slot(i, slot_width, center_x, bottom_y)
		var text_color = slot_color_normal; var draw_font_size: int = rule_mgr.slot_font_size; var text_offset_y = 0.0

		if rule_mgr.enable_slot_effects and balls_in_this_slot > 0:
			text_offset_y = sin(time_sec * slot_shake_speed) * 2.0
			if balls_in_this_slot == 1: text_color = slot_color_single; draw_font_size = roundi(rule_mgr.slot_font_size * 1.15)
			elif balls_in_this_slot == 2: text_color = slot_color_multiple; draw_font_size = roundi(rule_mgr.slot_font_size * 1.25)
			elif balls_in_this_slot == 3: text_color = slot_color_triple; draw_font_size = roundi(rule_mgr.slot_font_size * 1.30)
			else: text_color = slot_color_quad; draw_font_size = roundi(rule_mgr.slot_font_size * 1.35)

		var text_pos = Vector2(slot_left + 2, bottom_y - 10 + text_offset_y)
		if slot_outline_width > 0:
			draw_string_outline(font_to_use, text_pos, prize_name, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, draw_font_size, slot_outline_width, Color.BLACK)
		draw_string(font_to_use, text_pos, prize_name, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, draw_font_size, text_color)

		if balls_in_this_slot > 1:
			var count_text = "x" + str(balls_in_this_slot)
			var count_font_size = max(12, roundi(rule_mgr.slot_font_size * 0.85))
			var count_pos = Vector2(slot_left + 2, bottom_y + count_font_size + 8)
			if slot_outline_width > 0:
				draw_string_outline(font_to_use, count_pos, count_text, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, count_font_size, max(2, slot_outline_width * 0.6), Color.BLACK)
			draw_string(font_to_use, count_pos, count_text, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, count_font_size, text_color)
