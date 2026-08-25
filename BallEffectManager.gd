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
@export_range(0.0, 1.0) var lightning_impact_chance: float = 0.8 # 碰撞觸發電弧機率 (0.0 ~ 1.0)
@export var lightning_impact_lifetime: float = 0.35              # 碰撞電弧殘留/閃爍時間 (秒)
@export var lightning_target_radius: float = 160.0                # 電弧延伸隨機終點半徑
@export var lightning_segments: int = 8                          # 鋸齒電弧折線段數
@export var lightning_color: Color = Color("#00E5FF")            # 電弧顏色 (亮青/藍白)
@export var lightning_line_width: float = 2.5                    # 電弧線條粗細

@export_group("🔴 雷射彈珠特效設定")
@export_range(0.0, 1.0) var laser_impact_chance: float = 0.35 # 碰撞發射雷射機率 (50%)
@export var laser_max_bounces: int = 4                       # 雷射最大反彈次數
@export var laser_max_distance: float = 600.0                # 雷射光束單段最大延伸距離
@export var laser_lifetime: float = 0.52                     # 雷射光殘留/閃爍時間 (秒)
@export var laser_color: Color = Color("#00FF66")            # 雷射主色 (高亮霓虹綠)
@export var laser_light_color: Color = Color("#80FFAA")      # 第二組外層粒子淺色 (淺亮螢光綠)
@export var laser_line_width: float = 3.0                    # 雷射線條粗細

@export_subgroup("第一組粒子流")
@export var laser_particle_count: int = 12                   # 第一組粒子數量
@export var laser_orbit_radius: float = 15.0                 # 第一組粒子軌道半徑
@export var laser_particle_size: float = 3.5                 # 第一組粒子基礎大小

@export_subgroup("第二組高速外層粒子流")
@export var laser_particle_count2: int = 16                  # 第二組粒子數量
@export var laser_orbit_radius2: float = 17.0                # 第二組粒子軌道半徑
@export var laser_particle_size2: float = 2.8                # 第二組粒子基礎大小
@export var laser_orbit_speed2: float = 12.0                 # 第二組環繞速度

@export_group("🌌 時空彈珠特效設定")
@export_range(0.0, 1.0) var chrono_impact_chance: float = 0.25 # 碰撞引發時空混亂機率 (預設 20%)
@export var chrono_min_duration: float = 0.5                   # 時空混亂最短隱形時間 (秒)
@export var chrono_max_duration: float = 1.2                   # 時空混亂最長隱形時間 (秒)
@export var chrono_stars_count: int = 6                        # 本體內部星空點數量
@export var chrono_glow_color: Color = Color("#00E5FF")        # 本體外層高亮環顏色 (亮青)
@export var chrono_teleport_color: Color = Color("#7C4DFF")    # 傳送粒子顏色 (深紫/霓虹紫)
@export var chrono_particle_amount: int = 16                   # 瞬移爆發粒子數量
@export var chrono_afterimage_count: int = 5                   # 現身時鋪滿路徑的多重殘影數量
@export var chrono_afterimage_lifetime: float = 0.25           # 多重殘影停留/淡出時間 (秒，預設 0.25 秒)

# --- 內部資料快取結構 ---
var ball_trails: Dictionary = {}        
var phantom_ghosts: Array[Dictionary] = [] 
var phantom_spawn_timers: Dictionary = {} 

var active_impact_flames: Array[CPUParticles2D] = []
var active_impact_lightnings: Array[Dictionary] = []
var active_impact_lasers: Array[Dictionary] = []

# 時空彈珠混亂字典 { ball: RigidBody2D -> { "ghost_pos": Vector2, "timer": float } }
var chrono_glitch_data: Dictionary = {}

# 多重現身殘影陣列 [ { "pos": Vector2, "life": float, "max_life": float, "seed_id": int } ]
var active_chrono_afterimages: Array[Dictionary] = []

# ==========================================
# 🚀 1. 每影格動態計算與歷史軌跡更新
# ==========================================
func process_effects(delta: float, active_balls: Array[RigidBody2D], ball_style_type: int, ball_texture_map: Dictionary) -> void:
	# A. 幻影滷蛋殘影採樣 (模式 2)
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
			if g["life"] <= 0:
				phantom_ghosts.remove_at(i)
			i -= 1

	# B. 彩虹軌跡採樣 (模式 3)
	if ball_style_type == 3:
		for ball in active_balls:
			if is_instance_valid(ball):
				if not ball_trails.has(ball):
					ball_trails[ball] = []
				var trail: Array = ball_trails[ball]
				trail.append(ball.position)
				if trail.size() > rainbow_trail_length:
					trail.pop_front()

	# C. 清理過期/停止發射的火焰粒子
	var f_idx = active_impact_flames.size() - 1
	while f_idx >= 0:
		var flame = active_impact_flames[f_idx]
		if not is_instance_valid(flame) or not flame.emitting:
			active_impact_flames.remove_at(f_idx)
		f_idx -= 1

	# D. 更新並清理碰撞鋸齒電弧壽命
	var l_idx = active_impact_lightnings.size() - 1
	while l_idx >= 0:
		var lightning = active_impact_lightnings[l_idx]
		lightning["life"] -= delta
		if lightning["life"] <= 0:
			active_impact_lightnings.remove_at(l_idx)
		l_idx -= 1

	# E. 更新並清理雷射光殘留壽命
	var laser_idx = active_impact_lasers.size() - 1
	while laser_idx >= 0:
		var laser = active_impact_lasers[laser_idx]
		laser["life"] -= delta
		if laser["life"] <= 0:
			active_impact_lasers.remove_at(laser_idx)
		laser_idx -= 1

	# 🌌 F. 時空混亂倒數計時與恢復處理
	for ball in chrono_glitch_data.keys():
		if not is_instance_valid(ball):
			chrono_glitch_data.erase(ball)
			continue
		
		var data = chrono_glitch_data[ball]
		data["timer"] -= delta
		
		if data["timer"] <= 0:
			# 時間到：取消混亂，在本體與殘影間鋪滿多重殘影並釋放現身傳送粒子
			var current_parent = ball.get_parent()
			var ghost_pos: Vector2 = data["ghost_pos"]
			var current_pos: Vector2 = ball.global_position
			
			if current_parent:
				_spawn_teleport_burst(current_parent, current_pos)
			
			# 瞬間鋪滿多重現身殘影 (同時出現，停留 chrono_afterimage_lifetime 秒)
			for step in range(chrono_afterimage_count + 1):
				var lerp_ratio = float(step) / float(max(1, chrono_afterimage_count))
				var afterimage_pos = ghost_pos.lerp(current_pos, lerp_ratio)
				active_chrono_afterimages.append({
					"pos": afterimage_pos,
					"life": chrono_afterimage_lifetime,
					"max_life": chrono_afterimage_lifetime,
					"seed_id": ball.get_instance_id()
				})
			
			chrono_glitch_data.erase(ball)

	# 🌌 G. 更新並淡出多重現身殘影壽命
	var afterimage_idx = active_chrono_afterimages.size() - 1
	while afterimage_idx >= 0:
		var afterimage = active_chrono_afterimages[afterimage_idx]
		afterimage["life"] -= delta
		if afterimage["life"] <= 0:
			active_chrono_afterimages.remove_at(afterimage_idx)
		afterimage_idx -= 1

# ==========================================
# 🚀 2. 發射掛載：統一處理彈珠生成時的附加粒子
# ==========================================
func on_ball_spawned(ball: RigidBody2D, style_type: int, ball_radius: float) -> void:
	if style_type == 4: # 火焰彈珠 (模式 4)
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

# ==========================================
# 🚀 3. 碰撞觸發：統一攔截物理碰撞點並按樣式分流
# ==========================================
func on_ball_impact(parent_node: Node, ball: RigidBody2D, contact_pos: Vector2, style_type: int) -> void:
	match style_type:
		4: spawn_impact_fire(parent_node, contact_pos)          # 火焰彈珠碰撞
		5: spawn_impact_lightning(contact_pos)                 # 閃電彈珠碰撞
		6: spawn_impact_laser(parent_node, contact_pos)        # 🔴 雷射彈珠碰撞
		7: spawn_impact_chrono(parent_node, ball)              # 🌌 時空彈珠碰撞

# 生成原地方向燃燒火焰粒子
func spawn_impact_fire(parent_node: Node, contact_pos: Vector2) -> void:
	if randf() > fire_impact_chance: return
	var flame = CPUParticles2D.new()
	flame.position = contact_pos
	flame.amount = 20; flame.lifetime = 0.6; flame.one_shot = false; flame.explosiveness = 0.1
	flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 1.5 * fire_impact_scale
	flame.direction = Vector2(0, -1); flame.spread = 20.0; flame.gravity = Vector2(0, -35)
	flame.initial_velocity_min = 6.0 * fire_impact_scale; flame.initial_velocity_max = 16.0 * fire_impact_scale
	flame.scale_amount_min = 3.0 * fire_impact_scale; flame.scale_amount_max = 6.0 * fire_impact_scale
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4)); scale_curve.add_point(Vector2(0.3, 1.0)); scale_curve.add_point(Vector2(1.0, 0.0))
	flame.scale_amount_curve = scale_curve
	flame.color = Color("#FF6D00")

	parent_node.add_child(flame)
	active_impact_flames.append(flame)

	var tween = flame.create_tween()
	tween.tween_interval(fire_impact_lifetime)
	tween.tween_callback(flame.set_emitting.bind(false))
	tween.tween_interval(1.0)
	tween.tween_callback(flame.queue_free)

# 生成從碰撞接點延伸的鋸齒閃電電弧
func spawn_impact_lightning(contact_pos: Vector2) -> void:
	if randf() > lightning_impact_chance: return
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
			"points": pts, "life": lightning_impact_lifetime, "max_life": lightning_impact_lifetime
		})

# 🔴 機率性瞬間計算光學反彈路徑
func spawn_impact_laser(parent_node: Node, contact_pos: Vector2) -> void:
	if randf() > laser_impact_chance: return

	var space_state = parent_node.get_world_2d().direct_space_state
	var current_pos = contact_pos
	var current_dir = Vector2.UP.rotated(randf_range(0, TAU))
	var points: Array[Vector2] = [current_pos]

	for _bounce in range(laser_max_bounces + 1):
		var ray_query = PhysicsRayQueryParameters2D.create(
			current_pos + current_dir * 1.5,
			current_pos + current_dir * laser_max_distance
		)
		ray_query.collision_mask = 1

		var result = space_state.intersect_ray(ray_query)
		if result:
			var hit_point: Vector2 = result.position
			var hit_normal: Vector2 = result.normal
			points.append(hit_point)

			current_dir = current_dir.bounce(hit_normal).normalized()
			current_pos = hit_point
		else:
			points.append(current_pos + current_dir * laser_max_distance)
			break

	active_impact_lasers.append({
		"points": points,
		"life": laser_lifetime,
		"max_life": laser_lifetime
	})

# 🌌 20% 機率觸發時空混亂：以彈珠中心（球體位置）原地留下殘影，本體隱形，並引爆傳送粒子
func spawn_impact_chrono(parent_node: Node, ball: RigidBody2D) -> void:
	if randf() > chrono_impact_chance: return
	if chrono_glitch_data.has(ball): return # 避開重複進入混亂狀態

	var duration = randf_range(chrono_min_duration, chrono_max_duration)
	var spawn_pos = ball.global_position # 💡 以彈珠中心（球體位置）原地生成殘影，杜絕穿牆與非連貫感

	chrono_glitch_data[ball] = {
		"ghost_pos": spawn_pos,
		"timer": duration
	}

	# 在彈珠原地中心爆發第一道「殘留傳送粒子」
	_spawn_teleport_burst(parent_node, spawn_pos)

# 🌌 傳送粒子爆發輔助函式
func _spawn_teleport_burst(parent_node: Node, burst_pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.position = burst_pos
	particles.amount = chrono_particle_amount
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 8.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = chrono_teleport_color

	parent_node.add_child(particles)
	
	var tween = particles.create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(particles.queue_free)

# ==========================================
# 🚀 4. 全域視覺繪製：彙整本體與頂/底層特效
# ==========================================
func draw_all_ball_visuals(canvas: CanvasItem, active_balls: Array[RigidBody2D], ball_style_type: int, ball_radius: float, time_sec: float, egg_scale: float, ball_color: Color, fire_ball_color: Color, lightning_ball_color: Color, egg_textures: Array[Texture2D], ball_texture_map: Dictionary) -> void:
	# A. 繪製底層殘影 (幻影滷蛋)
	if ball_style_type == 2:
		for g in phantom_ghosts:
			var alpha = clamp(g["life"] / g["max_life"], 0.0, 1.0) * 0.45
			var ball_size = Vector2(ball_radius * 2.0 * egg_scale, ball_radius * 2.0 * egg_scale)
			var ghost_tex: Texture2D = g.get("tex", null)
			canvas.draw_set_transform(g["pos"], g["rot"], Vector2.ONE)
			if ghost_tex: canvas.draw_texture_rect(ghost_tex, Rect2(-ball_size / 2.0, ball_size), false, Color(1, 1, 1, alpha))
			else: canvas.draw_circle(Vector2.ZERO, ball_radius * egg_scale, Color(0.55, 0.43, 0.39, alpha))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# B. 繪製底層拖尾 (彩虹拖尾)
	if ball_style_type == 3:
		for ball in ball_trails.keys():
			if is_instance_valid(ball):
				var trail: Array = ball_trails[ball]
				for t_idx in range(trail.size()):
					var alpha = float(t_idx + 1) / float(trail.size()) * 0.45
					var hue = fmod(time_sec * 0.5 + float(t_idx) * 0.03, 1.0)
					canvas.draw_circle(trail[t_idx], ball_radius * (0.3 + 0.7 * alpha), Color.from_hsv(hue, 0.8, 1.0, alpha))

	# C. 繪製特殊環境光/環繞 (閃電環繞)
	if ball_style_type == 5:
		for ball in active_balls:
			if is_instance_valid(ball):
				_draw_ball_electric_ring(canvas, ball.position, ball_radius, time_sec, ball.get_instance_id())

	# 🌌 D. 繪製時空彈珠留在原地的半透明殘影
	if ball_style_type == 7:
		for ball in chrono_glitch_data.keys():
			if is_instance_valid(ball):
				var ghost_pos = chrono_glitch_data[ball]["ghost_pos"]
				_draw_chrono_ghost_ball(canvas, ghost_pos, ball_radius, time_sec, ball.get_instance_id(), 0.45)

	# 🌌 D2. 繪製恢復狀態時鋪滿路徑的多重淡出殘影
	for afterimage in active_chrono_afterimages:
		var alpha_ratio = clamp(afterimage["life"] / afterimage["max_life"], 0.0, 1.0) * 0.5
		_draw_chrono_ghost_ball(canvas, afterimage["pos"], ball_radius, time_sec, afterimage["seed_id"], alpha_ratio)

	# E. 繪製所有彈珠本體
	for ball in active_balls:
		if is_instance_valid(ball):
			# 若彈珠處於時空混亂狀態，本體完全透明不繪製
			if ball_style_type == 7 and chrono_glitch_data.has(ball):
				continue

			if ball_style_type in [1, 2]: # 滷蛋/幻影滷蛋
				var ball_size = Vector2(ball_radius * 2.0 * egg_scale, ball_radius * 2.0 * egg_scale)
				var fallback_tex: Texture2D = egg_textures[0] if egg_textures.size() > 0 else null
				var b_tex: Texture2D = ball_texture_map.get(ball, fallback_tex)
				canvas.draw_set_transform(ball.position, ball.rotation, Vector2.ONE)
				if b_tex: canvas.draw_texture_rect(b_tex, Rect2(-ball_size / 2.0, ball_size), false)
				else: canvas.draw_circle(Vector2.ZERO, ball_radius * egg_scale, Color("#8D6E63"))
				canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif ball_style_type == 3: # 彩虹漸變本體
				canvas.draw_circle(ball.position, ball_radius, Color.from_hsv(fmod(time_sec * 0.6 + ball.get_instance_id() * 0.1, 1.0), 0.85, 1.0))
			elif ball_style_type == 4: # 火焰本體
				canvas.draw_circle(ball.position, ball_radius, fire_ball_color)
			elif ball_style_type == 5: # 閃電本體
				canvas.draw_circle(ball.position, ball_radius, lightning_ball_color)
			elif ball_style_type == 6: # 雷射本體
				_draw_laser_ball(canvas, ball.position, ball_radius, time_sec, ball.get_instance_id())
			elif ball_style_type == 7: # 🌌 時空彈珠本體 (高亮外環 + 深藍中心 + 星空點)
				_draw_chrono_ball(canvas, ball.position, ball_radius, time_sec, ball.get_instance_id(), 1.0)
			else: # 普通彈珠 (0)
				canvas.draw_circle(ball.position, ball_radius, ball_color)

	# F. 繪製頂層碰撞特效 (鋸齒電弧)
	for lightning in active_impact_lightnings:
		var alpha = clamp(lightning["life"] / lightning["max_life"], 0.0, 1.0)
		if randf() > 0.15:
			var draw_col = lightning_color; draw_col.a *= alpha
			var points: Array = lightning["points"]
			for p_idx in range(points.size() - 1):
				canvas.draw_line(points[p_idx], points[p_idx + 1], draw_col, lightning_line_width)

	# G. 繪製直線反彈雷射光條
	for laser in active_impact_lasers:
		var alpha = clamp(laser["life"] / laser["max_life"], 0.0, 1.0)
		var draw_col = laser_color
		draw_col.a *= alpha
		var pts: Array[Vector2] = laser["points"]
		for p_idx in range(pts.size() - 1):
			canvas.draw_line(pts[p_idx], pts[p_idx + 1], draw_col, laser_line_width)
			canvas.draw_circle(pts[p_idx], laser_line_width * 1.2, Color(1, 1, 1, alpha))

# 繪製環繞彈珠本體的微型閃電環
func _draw_ball_electric_ring(canvas: CanvasItem, center: Vector2, radius: float, time_sec: float, seed_id: int) -> void:
	var ring_points_count = 6; var angle_step = TAU / ring_points_count
	var base_angle = time_sec * 8.0 + float(seed_id * 17 % 100)
	var pts: PackedVector2Array = []
	for i in range(ring_points_count + 1):
		pts.append(center + Vector2(cos(base_angle + i * angle_step), sin(base_angle + i * angle_step)) * (radius + 2.0 + randf_range(-3.0, 5.0)))
	for i in range(pts.size() - 1):
		canvas.draw_line(pts[i], pts[i + 1], Color(lightning_color.r, lightning_color.g, lightning_color.b, randf_range(0.4, 1.0)), 1.8)

# 繪製雙組交錯粒子流雷射彈珠本體
func _draw_laser_ball(canvas: CanvasItem, pos: Vector2, radius: float, time_sec: float, seed_id: int) -> void:
	var core_radius = radius * (0.35 + sin(time_sec * 12.0 + seed_id) * 0.05)
	canvas.draw_circle(pos, core_radius * 1.4, Color(laser_color.r, laser_color.g, laser_color.b, 0.4))
	canvas.draw_circle(pos, core_radius, Color.WHITE)

	var step1 = TAU / float(max(1, laser_particle_count))
	var rot1 = time_sec * 5.0 + float(seed_id * 13 % 100)
	for i in range(laser_particle_count):
		var angle = rot1 + i * step1
		var p_pos = pos + Vector2(cos(angle), sin(angle)) * (laser_orbit_radius + sin(time_sec * 8.0 + i * 2.0) * 1.5)
		var alpha = clamp(0.35 + sin(time_sec * 15.0 + i * 3.0) * 0.45 + randf_range(-0.1, 0.1), 0.15, 0.95)
		var p_size = laser_particle_size * (0.7 + sin(time_sec * 10.0 + i) * 0.3)
		var col = laser_color; col.a = alpha
		canvas.draw_circle(p_pos, p_size, col)

	var step2 = TAU / float(max(1, laser_particle_count2))
	var rot2 = -time_sec * laser_orbit_speed2 + float(seed_id * 19 % 100)
	for i in range(laser_particle_count2):
		var angle = rot2 + i * step2
		var wave = sin(time_sec * 12.0 + i * 2.5) * 2.0
		var p_pos = pos + Vector2(cos(angle), sin(angle)) * (laser_orbit_radius2 + wave)
		var alpha = clamp(0.2 + sin(time_sec * 20.0 + i * 4.0) * 0.5 + randf_range(-0.15, 0.15), 0.1, 0.85)
		var p_size = laser_particle_size2 * (0.6 + sin(time_sec * 14.0 + i) * 0.4)
		var col = laser_light_color; col.a = alpha
		canvas.draw_circle(p_pos, p_size, col)

# 🌌 繪製時空彈珠本體 (高亮圈 -> 漸層深藍 -> 星空點)
func _draw_chrono_ball(canvas: CanvasItem, pos: Vector2, radius: float, time_sec: float, seed_id: int, alpha_multiplier: float = 1.0) -> void:
	# 1. 外層高亮圈
	var outer_color = chrono_glow_color
	outer_color.a *= alpha_multiplier
	canvas.draw_circle(pos, radius + 1.5, outer_color)

	# 2. 中間向內漸層深藍色核心 (分多層疊加漸層效果)
	var step_count = 4
	for i in range(step_count, 0, -1):
		var r_ratio = float(i) / float(step_count)
		var current_r = radius * r_ratio
		var layer_color = Color("#0A192F").lerp(Color("#020612"), 1.0 - r_ratio)
		layer_color.a *= alpha_multiplier
		canvas.draw_circle(pos, current_r, layer_color)

	# 3. 閃爍星空白點 (根據 seed_id 固定隨機分佈位置)
	for i in range(chrono_stars_count):
		var angle = float(seed_id * 11 + i * 137)
		var dist = fmod(float(seed_id * 7 + i * 31), radius * 0.75)
		var star_pos = pos + Vector2(cos(angle), sin(angle)) * dist
		
		var star_alpha = clamp(0.3 + sin(time_sec * 8.0 + i * 2.0) * 0.6, 0.1, 1.0) * alpha_multiplier
		var star_color = Color(1.0, 1.0, 1.0, star_alpha)
		canvas.draw_circle(star_pos, 1.2, star_color)

# 🌌 繪製時空彈珠半透明殘影
func _draw_chrono_ghost_ball(canvas: CanvasItem, pos: Vector2, radius: float, time_sec: float, seed_id: int, base_alpha: float = 0.45) -> void:
	var ghost_alpha = base_alpha + sin(time_sec * 15.0) * 0.05
	_draw_chrono_ball(canvas, pos, radius, time_sec, seed_id, ghost_alpha)

# ==========================================
# 🚀 5. 全域清理與卸載
# ==========================================
func clear_all(active_balls: Array[RigidBody2D]) -> void:
	ball_trails.clear(); phantom_ghosts.clear(); phantom_spawn_timers.clear()
	
	for f in active_impact_flames:
		if is_instance_valid(f): f.queue_free()
	active_impact_flames.clear()
	active_impact_lightnings.clear()
	active_impact_lasers.clear()
	chrono_glitch_data.clear()
	active_chrono_afterimages.clear()

	for ball in active_balls:
		if is_instance_valid(ball):
			for child in ball.get_children():
				if child is CPUParticles2D: child.queue_free()
