extends Control

# ==========================================
# ⚙️ 可調整參數區 (Inspector 面板可直接選色)
# ==========================================
@export_group("色彩與視覺設定 (Colors & Visuals)")
@export var bg_color: Color = Color("1f242e")            # 全域背景色
@export var board_bg_color: Color = Color("333842")      # 彈珠台內部背景色
@export var board_border_color: Color = Color("cccccc")  # 彈珠台邊框顏色
@export var peg_color: Color = Color("ffd700")           # 釘子填滿顏色 (金色)
@export var peg_outline_color: Color = Color("8b6508")   # 釘子描邊顏色
@export var peg_outline_width: float = 2.0               # 釘子描邊粗細
@export var ball_color: Color = Color("1e90ff")          # 彈珠顏色 (道奇藍)

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
@export var slot_count: int = 10            # 獎項數量
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
@export var ball_radius: float = 12.0       # 彈珠半徑
@export var ball_bounce: float = 0.6        # 彈珠彈性
@export var ball_mass: float = 1.0          # 彈珠質量
@export var ball_gravity_scale: float = 1.2 # 重力倍率
@export var spawn_x_offset: float = 15.0    # 發射初始位置隨機 X 軸偏移範圍
@export var launch_cooldown: float = 0.2    # 最短發射間隔時間 (秒)

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

# 獎品名單設定 UI 引用
@onready var add_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/InputHBox/AddInput
@onready var add_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/InputHBox/AddButton
@onready var item_list: ItemList = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ItemList
@onready var delete_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ActionHBox/DeleteButton
@onready var shuffle_button: Button = $UI/SettingsPanel/VBox/ContentHBox/RightVBox/ActionHBox/ShuffleButton
@onready var preset_name_input: LineEdit = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSaveHBox/PresetNameInput
@onready var save_preset_button: Button = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSaveHBox/SavePresetButton
@onready var preset_option: OptionButton = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSelectHBox/PresetOption
@onready var delete_preset_button: Button = $UI/SettingsPanel/VBox/ContentHBox/LeftVBox/PresetSelectHBox/DeletePresetButton

# 畫面設定 UI 引用
@onready var bg_color_picker: ColorPickerButton = $UI/DisplayPanel/VBox/BGColorPicker
@onready var font_size_slider: HSlider = $UI/DisplayPanel/VBox/UIFontSlider

var active_balls: Array[RigidBody2D] = []
var can_launch: bool = true
var launch_timer: float = 0.0
var presets_dict: Dictionary = {}

func _ready() -> void:
	# 綁定頂部基本按鈕
	restart_button.pressed.connect(_on_restart_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	launch_button.pressed.connect(_on_launch_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)

	# 1 & 2. 彈窗開啟/關閉控制 (互斥 & 禁用發射)
	display_settings_button.pressed.connect(_on_display_settings_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	$UI/DisplayPanel/VBox/CloseDisplayButton.pressed.connect(_close_all_panels)
	$UI/SettingsPanel/VBox/CloseSettingsButton.pressed.connect(_close_all_panels)

	# 綁定獎品名單設定邏輯
	add_button.pressed.connect(_on_add_button_pressed)
	add_input.text_submitted.connect(func(_text): _on_add_button_pressed())
	delete_button.pressed.connect(_on_delete_button_pressed)
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	save_preset_button.pressed.connect(_on_save_preset_button_pressed)
	delete_preset_button.pressed.connect(_on_delete_preset_button_pressed)
	preset_option.item_selected.connect(_on_preset_selected)

	# 綁定畫面設定邏輯
	bg_color_picker.color = bg_color
	bg_color_picker.color_changed.connect(func(c): bg_color = c)

	# 設定版號
	var auto_version = ProjectSettings.get_setting("application/config/version", "v1.0.0")
	version_label.text = "v" + str(auto_version) if not str(auto_version).begins_with("v") else str(auto_version)

	_refresh_item_list_ui()
	_setup_board_boundaries()
	_generate_pegs()
	_generate_slots()
	
	var view_size = get_viewport_rect().size
	ball_spawner.position = Vector2(view_size.x / 2.0, board_top_margin + 20)
	result_label.text = "請點擊『發射彈珠』開始抽獎！"

func _process(delta: float) -> void:
	if not can_launch:
		launch_timer -= delta
		if launch_timer <= 0:
			can_launch = true
			if not _is_any_panel_open():
				launch_button.disabled = false

	active_balls = active_balls.filter(func(b): return is_instance_valid(b))
	queue_redraw()

# --- 1 & 2. 彈窗控制與按鈕狀態切換 ---
func _on_display_settings_button_pressed() -> void:
	if display_panel.visible:
		_close_all_panels()
	else:
		settings_panel.hide()
		display_panel.show()
		_update_action_buttons_state()

func _on_settings_button_pressed() -> void:
	if settings_panel.visible:
		_close_all_panels()
	else:
		display_panel.hide()
		settings_panel.show()
		_update_action_buttons_state()

func _close_all_panels() -> void:
	display_panel.hide()
	settings_panel.hide()
	_update_action_buttons_state()

func _is_any_panel_open() -> bool:
	return display_panel.visible or settings_panel.visible

func _update_action_buttons_state() -> void:
	var is_open = _is_any_panel_open()
	launch_button.disabled = is_open or not can_launch
	clear_button.disabled = is_open

# --- 4. 獎品名單編輯邏輯 ---
func _refresh_item_list_ui() -> void:
	item_list.clear()
	for p in prize_list:
		item_list.add_item(p)
	slot_count = prize_list.size()

func _on_add_button_pressed() -> void:
	var txt = add_input.text.strip_edges()
	if txt != "":
		prize_list.append(txt)
		add_input.clear()
		_refresh_item_list_ui()
		_rebuild_slots()

func _on_delete_button_pressed() -> void:
	var selected = item_list.get_selected_items()
	if selected.size() > 0:
		var idx = selected[0]
		prize_list.remove_at(idx)
		_refresh_item_list_ui()
		_rebuild_slots()

func _on_shuffle_button_pressed() -> void:
	prize_list.shuffle()
	_refresh_item_list_ui()
	_rebuild_slots()

# --- 預設名單儲存/載入 ---
func _on_save_preset_button_pressed() -> void:
	var name_txt = preset_name_input.text.strip_edges()
	if name_txt != "":
		presets_dict[name_txt] = prize_list.duplicate()
		preset_name_input.clear()
		_update_preset_option_ui()

func _on_delete_preset_button_pressed() -> void:
	if preset_option.selected >= 0:
		var key = preset_option.get_item_text(preset_option.selected)
		presets_dict.erase(key)
		_update_preset_option_ui()

func _on_preset_selected(idx: int) -> void:
	var key = preset_option.get_item_text(idx)
	if presets_dict.has(key):
		prize_list = presets_dict[key].duplicate()
		_refresh_item_list_ui()
		_rebuild_slots()

func _update_preset_option_ui() -> void:
	preset_option.clear()
	for k in presets_dict.keys():
		preset_option.add_item(k)

# --- 動態重建獎項分格 ---
func _rebuild_slots() -> void:
	for c in slots_container.get_children():
		c.queue_free()
	_generate_slots()

# --- 實體與畫圖機制 ---
func _setup_board_boundaries() -> void:
	var center_x = get_viewport_rect().size.x / 2.0
	_create_wall_rect(Vector2(center_x - board_width / 2.0 - 10, board_top_margin + board_height / 2.0), Vector2(20, board_height))
	_create_wall_rect(Vector2(center_x + board_width / 2.0 + 10, board_top_margin + board_height / 2.0), Vector2(20, board_height))
	_create_wall_rect(Vector2(center_x, board_top_margin + board_height + 5), Vector2(board_width, 10))

func _create_wall_rect(pos: Vector2, rect_size: Vector2) -> void:
	var col = CollisionShape2D.new()
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
			_create_wall_rect(Vector2(slot_left, bottom_y - slot_height / 2.0), Vector2(8, slot_height))

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
	if not can_launch or _is_any_panel_open():
		return

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
	for ball in active_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	active_balls.clear()
	result_label.text = "已清空場上所有彈珠！"

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_slot_entered(body: Node2D, prize_name: String) -> void:
	if body in active_balls:
		result_label.text = "🎉 恭喜獲得：" + prize_name + "！"

func _draw() -> void:
	var view_size = get_viewport_rect().size
	var center_x = view_size.x / 2.0

	draw_rect(Rect2(Vector2.ZERO, view_size), bg_color, true)

	var board_rect = Rect2(center_x - board_width / 2.0, board_top_margin, board_width, board_height)
	draw_rect(board_rect, board_bg_color, true)
	draw_rect(board_rect, board_border_color, false, 4.0)

	for peg in pegs_container.get_children():
		if peg_outline_width > 0.0:
			draw_circle(peg.position, peg_radius + peg_outline_width, peg_outline_color)
		draw_circle(peg.position, peg_radius, peg_color)

	for ball in active_balls:
		if is_instance_valid(ball):
			draw_circle(ball.position, ball_radius, ball_color)

	var current_count = max(1, prize_list.size())
	var slot_width = board_width / current_count
	var bottom_y = board_top_margin + board_height
	for i in range(current_count):
		var slot_left = (center_x - board_width / 2.0) + i * slot_width
		if i > 0:
			draw_line(Vector2(slot_left, bottom_y - slot_height), Vector2(slot_left, bottom_y), Color.WHITE, 2.0)
		
		var prize_name = prize_list[i]
		draw_string(ThemeDB.fallback_font, Vector2(slot_left + 2, bottom_y - 10), prize_name, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4, 12, Color.WHITE)
