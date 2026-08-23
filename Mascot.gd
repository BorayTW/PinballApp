extends TextureRect

# ==========================================
# 🍮 吉祥物控制腳本 (Mascot.gd)
# ==========================================
@export_group("動畫參數設定")
@export var dance_speed: float = 12.0  # 果凍抖動頻率
@export var flip_interval: float = 1.2 # 左右鏡像翻轉間隔 (秒)

var dance_time: float = 0.0
var flip_timer: float = 0.0

func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)

func _process(delta: float) -> void:
	dance_time += delta * dance_speed
	flip_timer += delta
	
	# 果凍史萊姆彈跳抖動 (Squash & Stretch)
	var squash_y = 1.0 + sin(dance_time) * 0.08
	var squash_x = 1.0 - sin(dance_time) * 0.05
	
	if flip_timer >= flip_interval:
		flip_timer = 0.0
		flip_h = not flip_h
		
	scale = Vector2(squash_x, squash_y)

func set_mascot_texture(tex: Texture2D) -> void:
	if tex:
		texture = tex
