extends Control

# ==========================================
# ⚙️ 可調整參數區 (Inspector 面板可直接選色)
# ==========================================
@export_group("系統與預設字體大小")
@export var default_ui_font_size: int = 18          # 一般 UI 按鈕與選單預設大小
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
@export var board_bg_color: Color = Color("333842")     # 彈珠台內部背景色
@export var board_border_color: Color = Color("cccccc") # 彈珠台邊框顏色
@export var peg_color: Color = Color("ffd700")          # 釘子填滿顏色
@export var peg_outline_color: Color = Color("8b6508")  # 釘子描邊顏色
@export var peg_outline_width: float = 2.0              # 釘子描邊粗細
@export var ball_color: Color = Color("1e90ff")         # 彈珠顏色

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
@export var max_ball_count_limit: int = 20  # 3. 彈珠數量上限（防止輸入過大數值）
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
var current_bg_color: Color
var is_initializing: bool = true
var pending_delete_preset_name: String = ""

# --- 節點引用 ---
@onready var ball_spawner: Marker2D = $BallSpawner
@onready var board_node: StaticBody2D = $Board
@onready var pegs_container: Node2D = $Pegs
@onready var slots_container: Node2D = $Slots

@onready var launch_button: Button = $UI/BottomVBox/HBoxContainer/LaunchButton
@onready var clear_button: Button = $UI/BottomVBox/HBoxContainer/ClearButton
@onready var result_label: Label = $UI/BottomVBox/ResultLabel
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

# 1. 彈珠數量控制項 UI 引用
@onready var ball_count_minus_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/MinusButton
@onready var ball_count_plus_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/PlusButton
@onready var ball_count_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/BallCountInput

# 畫面設定 UI
@onready var bg_color_hbox: HBoxContainer = $UI/DisplayPanel/VBox/BGColorHBox
@onready var ui_font_slider: HSlider = $UI/DisplayPanel/VBox/UIFontSlider

var custom_font: Font = null
var active_balls: Array[RigidBody2D] = []
var can_launch: bool = true
var launch_timer: float = 0.0

func _ready() -> void:
	is_initializing = true
	
	if ResourceLoader.exists("res://NotoSansTC-VariableFont_wght.ttf"):
		custom_font = load("res://NotoSansTC-VariableFont_wght.ttf")

	_load_settings()
	remaining_ball_count = total_ball_count
	_setup_system_buttons()
	_setup_version_label()
	_setup_bg_color_buttons()
	_refresh_preset_options()

	# 訊號對接
	preset_option.item_selected.connect(_on_preset_selected)
	add_button.pressed.connect(_on_add_button_pressed)
	add_input.text_submitted.connect(func(_t): _on_add_button_pressed())
	item_list.item_selected.connect(_on_item_list_item_selected)
	delete_button.pressed.connect(_on_delete_button_pressed)
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	save_preset_button.pressed.connect(_on_save_preset_button_pressed)
	delete_preset_button.pressed.connect(_on_delete_preset_button_pressed)

	# 1. 彈珠數量控制按鈕綁定
	ball_count_minus_button.pressed.connect(func(): _update_total_ball_count(total_ball_count - 1))
	ball_count_plus_button.pressed.connect(func(): _update_total_ball_count(total_ball_count + 1))
	ball_count_input.text_submitted.connect(_on_ball_count_input_submitted)

	$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmOkButton.pressed.connect(_on_delete_confirm_ok_pressed)
	$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmCancelButton.pressed.connect(_on_delete_confirm_cancel_pressed)

	ui_font_slider.value_changed.connect(_on_ui_font_slider_value_changed)
	
	_update_ui_font_size(ui_font_size)
	_refresh_item_list_ui()
	_update_launch_button_ui()
	_setup_board_boundaries()
	_generate_pegs()
	_generate_slots()

	var view_size = get_viewport_rect().size
	ball_spawner.position = Vector2(view_size.x / 2.0, board_top_margin + 20)
	result_label.text = "請點擊『發射彈珠』開始抽獎！"

	is_initializing = false

func _process(delta: float) -> void:
	if not can_launch:
		launch_timer -= delta
		if launch_timer <= 0:
			can_launch = true
			if not _is_any_panel_open() and remaining_ball_count > 0:
				launch_button.disabled = false

	active_balls = active_balls.filter(func(b): return is_instance_valid(b))
	queue_redraw()

# --- 1 & 3. 彈珠數量設定邏輯 ---
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

# --- 2. 動態更新發射按鈕文字 ---
func _update_launch_button_ui() -> void:
	launch_button.text = "發射彈珠 (" + str(remaining_ball_count) + ")"
	# 只要剩餘數量大於 0 且沒有打開彈窗，就解鎖按鈕
	if remaining_ball_count > 0 and not _is_any_panel_open():
		launch_button.disabled = false
	else:
		launch_button.disabled = true

# --- 記憶檔案讀取與儲存邏輯 ---
func _save_settings() -> void:
	if is_initializing: return
	var config = ConfigFile.new()
	config.set_value("display", "ui_font_size", ui_font_size)
	config.set_value("display", "bg_color", current_bg_color)
	config.set_value("gameplay", "prize_list", prize_list)
	config.set_value("gameplay", "total_ball_count", total_ball_count)
	config.save(SAVE_PATH)

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	var default_bg = bg_color_palette[0] if bg_color_palette.size() > 0 else Color("#1F242E")

	if err == OK:
		ui_font_size = config.get_value("display", "ui_font_size", default_ui_font_size)
		current_bg_color = config.get_value("display", "bg_color", default_bg)
		prize_list = config.get_value("gameplay", "prize_list", prize_list)
		total_ball_count = config.get_value("gameplay", "total_ball_count", total_ball_count)
	else:
		ui_font_size = default_ui_font_size
		current_bg_color = default_bg

	ui_font_slider.value = ui_font_size
	ball_count_input.text = str(total_ball_count)

# --- 背景顏色選項選單 ---
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

# --- 預設名單記憶系統 ---
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

# --- 按鈕與 UI 功能 ---
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

func _update_ui_font_size(new_size: int) -> void:
	var ui_nodes = [
		restart_button, quit_button, display_settings_button, settings_button,
		launch_button, clear_button, result_label,
		$UI/SettingsPanel/VBox/Title, $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/LeftTitle,
		$UI/SettingsPanel/VBox/ContentHBox/RightVBox/RightTitle, preset_name_input, save_preset_button,
		preset_option, delete_preset_button, add_input, add_button, delete_button, shuffle_button,
		$UI/SettingsPanel/VBox/ContentHBox/RightVBox/BallCountHBox/BallCountLabel,
		ball_count_minus_button, ball_count_plus_button, ball_count_input,
		$UI/SettingsPanel/VBox/CloseSettingsButton, $UI/DisplayPanel/VBox/Title,
		$UI/DisplayPanel/VBox/BGColorLabel, $UI/DisplayPanel/VBox/UIFontLabel,
		$UI/DisplayPanel/VBox/CloseDisplayButton, $UI/DeleteConfirmPanel/VBox/Title,
		delete_confirm_text, $UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmOkButton,
		$UI/DeleteConfirmPanel/VBox/HBox/DeleteConfirmCancelButton
	]
	for node in ui_nodes:
		if node:
			node.add_theme_font_size_override("font_size", new_size)
			if custom_font:
				node.add_theme_font_override("font", custom_font)

	if item_list:
		item_list.add_theme_font_size_override("font_size", max(10, new_size + item_list_font_offset))
		if custom_font: item_list.add_theme_font_override("font", custom_font)

# --- 獎品列表編輯邏輯 ---
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

# 4. 清空彈珠並全數恢復可發射數量
func _clear_all_balls() -> void:
	for ball in active_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	active_balls.clear()
	remaining_ball_count = total_ball_count
	can_launch = true # 確保冷卻狀態歸零
	_update_launch_button_ui() # 會自動恢復發射按鈕為可點擊狀態

func _rebuild_slots() -> void:
	for c in slots_container.get_children(): c.queue_free()
	for c in board_node.get_children():
		if c.name.begins_with("SlotWall"): c.queue_free()
	_generate_slots()

# --- 物理與發射機制 ---
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

		var col = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(slot_width - 8, 16)
		col.shape = rect_shape
		area.add_child(col)

		var prize_name = prize_list[i]
		area.body_entered.connect(func(body): _on_slot_entered(body, prize_name))

		slots_container.add_child(area)

func _on_launch_button_pressed() -> void:
	if not can_launch or _is_any_panel_open() or remaining_ball_count <= 0: return

	# 扣減數量並更新按鈕 UI
	remaining_ball_count -= 1
	_update_launch_button_ui()

	can_launch = false
	launch_timer = launch_cooldown
	launch_button.disabled = true
	result_label.text = "彈珠滾動中..."

	var ball = RigidBody2D.new()
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = ball_bounce
	phys_mat.friction = 0.05
	ball.physics_material_override = phys_mat
	ball.mass = ball_mass
	ball.gravity_scale = ball_gravity_scale

	var col = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = ball_radius
	col.shape = circle_shape
	ball.add_child(col)

	var spawn_pos = ball_spawner.global_position
	spawn_pos.x += randf_range(-spawn_x_offset, spawn_x_offset)
	ball.position = spawn_pos

	add_child(ball)
	active_balls.append(ball)

func _on_clear_button_pressed() -> void:
	if _is_any_panel_open(): return
	_clear_all_balls()
	result_label.text = "已清空場上所有彈珠！"

func _on_slot_entered(body: Node2D, prize_name: String) -> void:
	if body is RigidBody2D and body in active_balls:
		result_label.text = "🎉 恭喜獲得：" + prize_name + "！"

func _draw() -> void:
	var view_size = get_viewport_rect().size
	var center_x = view_size.x / 2.0

	draw_rect(Rect2(Vector2.ZERO, view_size), current_bg_color, true)

	var board_rect = Rect2(center_x - board_width / 2.0, board_top_margin, board_width, board_height)
	draw_rect(board_rect, board_bg_color, true)
	draw_rect(board_rect, board_border_color, false, 4.0)

	for peg in pegs_container.get_children():
		if peg_outline_width > 0.0:
			draw_circle(peg.position, peg_radius + peg_outline_width, peg_outline_color)
		draw_circle(peg.position, peg_radius, peg_color)

	for ball in active_balls:
		if is_instance_valid(ball): draw_circle(ball.position, ball_radius, ball_color)

	var current_count = max(1, prize_list.size())
	var slot_width = board_width / current_count
	var bottom_y = board_top_margin + board_height
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font

	for i in range(current_count):
		var slot_left = (center_x - board_width / 2.0) + i * slot_width
		if i > 0:
			draw_line(Vector2(slot_left, bottom_y - slot_height), Vector2(slot_left, bottom_y), Color.WHITE, 2.0)
		var prize_name = prize_list[i]
		draw_string(font_to_use, Vector2(slot_left + 2, bottom_y - 10), prize_name, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, 12, Color.WHITE)
