class_name BallEffectManager
extends Node

# ==========================================
# 🎆 彈珠特效與軌跡繪製管理器 (BallEffectManager.gd)
# ==========================================
@export_group("特效與殘影設定")
@export var rainbow_trail_length: int = 30             # 彩虹拖尾長度
@export var phantom_egg_spawn_interval: float = 0.08 # 殘影生成間隔 (秒)
@export var phantom_egg_lifetime: float = 0.45       # 殘影壽命 (秒)

@export_group("火焰彈珠碰撞火焰設定")
@export_range(0.0, 1.0) var fire_impact_chance: float = 0.4 # 碰撞觸發火焰機率 (0.0 ~ 1.0)
@export var fire_impact_lifetime: float = 3.0              # 殘留火焰維持時間 (秒)
@export var fire_impact_scale: float = 1.3                 # 殘留火焰大小倍率

@export_group("閃電彈珠特效設定")
@export_range(0.0, 1.0) var lightning_impact_chance: float = 0.6 # 碰撞觸發電弧機率 (0.0 ~ 1.0)
@export var lightning_impact_lifetime: float = 0.35              # 碰撞電弧殘留/閃爍時間 (秒)
@export var lightning_target_radius: float = 60.0                # 電弧延伸隨機終點半徑
@export var lightning_segments: int = 5                          # 鋸齒電弧折線段數
@export var lightning_color: Color = Color("#00E5FF")            # 電弧顏色 (亮青/藍白)
@export var lightning_line_width: float = 2.5                    # 電弧線條粗細

var ball_trails: Dictionary = {}        
var phantom_ghosts: Array[Dictionary] = [] 
var phantom_spawn_timers: Dictionary = {} 

var active_impact_flames: Array[CPUParticles2D] = []
var active_impact_lightnings: Array[Dictionary] = []

func process_effects(delta: float, active_balls: Array[RigidBody2D], ball_style_type: int, ball_texture_map: Dictionary) -> void:
	# 1. 幻影滷蛋殘影採樣 (模式 2)
	if ball_style_type == 2:
		for ball in active_balls:
			if is_instance_valid(ball) and ball.linear_velocity.length() > 15.0:
				var t = phantom_spawn_timers.get(ball, 0.0) + delta
				if t >= phantom_egg_spawn_interval:
					t = 0.0
					phantom_ghosts.append({
						"pos": ball.position, "rot": ball.rotation,
						"tex": ball_texture_map.get(ball, null),
						"life": phantom_egg_lifetime, "max_life": phantom_egg_lifetime
					})
				phantom_spawn_timers[ball] = t

		var i = phantom_ghosts.size() - 1
		while i >= 0:
			var g = phantom_ghosts[i]
			g["life"] -= delta
			if g["life"] <= 0: phantom_ghosts.remove_at(i)
			i -= 1

	# 2. 彩虹軌跡採樣 (模式 3)
	if ball_style_type == 3:
		for ball in active_balls:
			if is_instance_valid(ball):
				if not ball_trails.has(ball): ball_trails[ball] = []
				var trail: Array = ball_trails[ball]
				trail.append(ball.position)
				if trail.size() > rainbow_trail_length: trail.pop_front()

	# 3. 清理已結束的殘留火焰粒子
	var f_idx = active_impact_flames.size() - 1
	while f_idx >= 0:
		var flame = active_impact_flames[f_idx]
		if not is_instance_valid(flame) or not flame.emitting:
			active_impact_flames.remove_at(f_idx)
		f_idx -= 1

	# 4. 更新並清理碰撞電弧壽命
	var l_idx = active_impact_lightnings.size() - 1
	while l_idx >= 0:
		var lightning = active_impact_lightnings[l_idx]
		lightning["life"] -= delta
		if lightning["life"] <= 0:
			active_impact_lightnings.remove_at(l_idx)
		l_idx -= 1

func draw_effects(canvas: CanvasItem, ball_style_type: int, ball_radius: float, time_sec: float, egg_scale: float = 1.0) -> void:
	# 1. 繪製幻影殘影
	if ball_style_type == 2:
		for g in phantom_ghosts:
			var alpha_ratio = clamp(g["life"] / g["max_life"], 0.0, 1.0) * 0.45
			var ball_size = Vector2(ball_radius * 2.0 * egg_scale, ball_radius * 2.0 * egg_scale)
			var ghost_tex: Texture2D = g.get("tex", null)
			canvas.draw_set_transform(g["pos"], g["rot"], Vector2.ONE)
			if ghost_tex:
				canvas.draw_texture_rect(ghost_tex, Rect2(-ball_size / 2.0, ball_size), false, Color(1, 1, 1, alpha_ratio))
			else:
				canvas.draw_circle(Vector2.ZERO, ball_radius * egg_scale, Color(0.55, 0.43, 0.39, alpha_ratio))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. 繪製彩虹拖尾
	if ball_style_type == 3:
		for ball in ball_trails.keys():
			if is_instance_valid(ball):
				var trail: Array = ball_trails[ball]
				for t_idx in range(trail.size()):
					var alpha = float(t_idx + 1) / float(trail.size()) * 0.45
					var hue = fmod(time_sec * 0.5 + float(t_idx) * 0.03, 1.0)
					var rainbow_col = Color.from_hsv(hue, 0.8, 1.0, alpha)
					canvas.draw_circle(trail[t_idx], ball_radius * (0.3 + 0.7 * alpha), rainbow_col)

	# ⚡ 3. 繪製閃電彈珠本體周圍的動態電流環繞 (模式 5)
	if ball_style_type == 5:
		for ball in canvas.active_balls:
			if is_instance_valid(ball):
				_draw_ball_electric_ring(canvas, ball.position, ball_radius, time_sec, ball.get_instance_id())

	# ⚡ 4. 繪製碰撞時產生的殘留鋸齒電弧
	for lightning in active_impact_lightnings:
		var alpha = clamp(lightning["life"] / lightning["max_life"], 0.0, 1.0)
		if randf() > 0.15: # 高頻閃爍感
			var draw_col = lightning_color
			draw_col.a *= alpha
			var points: Array = lightning["points"]
			for p_idx in range(points.size() - 1):
				canvas.draw_line(points[p_idx], points[p_idx + 1], draw_col, lightning_line_width)

# ⚡ 繪製環繞彈珠本體的微型閃電環
func _draw_ball_electric_ring(canvas: CanvasItem, center: Vector2, radius: float, time_sec: float, seed_id: int) -> void:
	var ring_points_count = 6
	var angle_step = TAU / ring_points_count
	var base_angle = time_sec * 8.0 + float(seed_id * 17 % 100)
	var pts: PackedVector2Array = []
	
	for i in range(ring_points_count + 1):
		var curr_angle = base_angle + i * angle_step
		var r_offset = randf_range(-3.0, 5.0)
		var pt = center + Vector2(cos(curr_angle), sin(curr_angle)) * (radius + 2.0 + r_offset)
		pts.append(pt)
		
	for i in range(pts.size() - 1):
		var alpha = randf_range(0.4, 1.0)
		canvas.draw_line(pts[i], pts[i + 1], Color(lightning_color.r, lightning_color.g, lightning_color.b, alpha), 1.8)

func attach_fire_particles(ball: RigidBody2D, ball_radius: float) -> void:
	var particles = CPUParticles2D.new()
	particles.name = "FireParticles"
	particles.amount = 25; particles.lifetime = 0.4; particles.explosiveness = 0.05
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = ball_radius * 0.7
	particles.direction = Vector2(0, -1); particles.spread = 25.0
	particles.gravity = Vector2(0, -250)
	particles.initial_velocity_min = 40.0; particles.initial_velocity_max = 80.0
	particles.scale_amount_min = 3.0; particles.scale_amount_max = 7.0
	particles.color = Color("#FF5722")
	ball.add_child(particles)

func spawn_impact_fire(parent_node: Node, contact_pos: Vector2) -> void:
	if randf() > fire_impact_chance:
		return

	var flame = CPUParticles2D.new()
	flame.position = contact_pos
	flame.amount = 20
	flame.lifetime = 0.6
	flame.one_shot = false
	flame.explosiveness = 0.1
	flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 1.5 * fire_impact_scale
	flame.direction = Vector2(0, -1)
	flame.spread = 20.0
	flame.gravity = Vector2(0, -35)
	flame.initial_velocity_min = 6.0 * fire_impact_scale
	flame.initial_velocity_max = 16.0 * fire_impact_scale
	flame.scale_amount_min = 3.0 * fire_impact_scale
	flame.scale_amount_max = 6.0 * fire_impact_scale
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	flame.scale_amount_curve = scale_curve
	flame.color = Color("#FF6D00")

	parent_node.add_child(flame)
	active_impact_flames.append(flame)

	var tween = flame.create_tween()
	tween.tween_interval(fire_impact_lifetime)
	tween.tween_callback(flame.set_emitting.bind(false))
	tween.tween_interval(1.0)
	tween.tween_callback(flame.queue_free)

# ⚡ 碰撞時生成由碰撞點往周圍隨機點延伸的鋸齒電弧
func spawn_impact_lightning(contact_pos: Vector2) -> void:
	if randf() > lightning_impact_chance:
		return

	var arc_count = randi_range(1, 2)
	for a in range(arc_count):
		var random_angle = randf_range(0, TAU)
		var dist = randf_range(25.0, lightning_target_radius)
		var target_pos = contact_pos + Vector2(cos(random_angle), sin(random_angle)) * dist
		
		var pts: Array[Vector2] = [contact_pos]
		var seg_vec = (target_pos - contact_pos) / float(lightning_segments)
		
		for i in range(1, lightning_segments):
			var mid_p = contact_pos + seg_vec * float(i)
			var normal = Vector2(-seg_vec.y, seg_vec.x).normalized()
			var offset_dist = randf_range(-12.0, 12.0)
			pts.append(mid_p + normal * offset_dist)
			
		pts.append(target_pos)
		
		active_impact_lightnings.append({
			"points": pts,
			"life": lightning_impact_lifetime,
			"max_life": lightning_impact_lifetime
		})

func clear_all() -> void:
	ball_trails.clear()
	phantom_ghosts.clear()
	phantom_spawn_timers.clear()
	for f in active_impact_flames:
		if is_instance_valid(f):
			f.queue_free()
	active_impact_flames.clear()
	active_impact_lightnings.clear()
