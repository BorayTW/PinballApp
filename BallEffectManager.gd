class_name BallEffectManager
extends Node

# ==========================================
# 🎆 彈珠特效與軌跡繪製管理器 (BallEffectManager.gd)
# ==========================================
@export_group("特效與殘影設定")
@export var rainbow_trail_length: int = 30           # 彩虹拖尾長度
@export var phantom_egg_spawn_interval: float = 0.08 # 殘影生成間隔 (秒)
@export var phantom_egg_lifetime: float = 0.45       # 殘影壽命 (秒)

var ball_trails: Dictionary = {}        
var phantom_ghosts: Array[Dictionary] = [] 
var phantom_spawn_timers: Dictionary = {} 

func process_effects(delta: float, active_balls: Array[RigidBody2D], ball_style_type: int, ball_texture_map: Dictionary) -> void:
	# 幻影滷蛋殘影採樣 (模式 2)
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

	# 彩虹軌跡採樣 (模式 3)
	if ball_style_type == 3:
		for ball in active_balls:
			if is_instance_valid(ball):
				if not ball_trails.has(ball): ball_trails[ball] = []
				var trail: Array = ball_trails[ball]
				trail.append(ball.position)
				if trail.size() > rainbow_trail_length: trail.pop_front()

func draw_effects(canvas: CanvasItem, ball_style_type: int, ball_radius: float, time_sec: float, egg_scale: float = 1.0) -> void:
	# 繪製幻影殘影 (套用 egg_scale 放大係數)
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

	# 繪製彩虹拖尾
	if ball_style_type == 3:
		for ball in ball_trails.keys():
			if is_instance_valid(ball):
				var trail: Array = ball_trails[ball]
				for t_idx in range(trail.size()):
					var alpha = float(t_idx + 1) / float(trail.size()) * 0.45
					var hue = fmod(time_sec * 0.5 + float(t_idx) * 0.03, 1.0)
					var rainbow_col = Color.from_hsv(hue, 0.8, 1.0, alpha)
					canvas.draw_circle(trail[t_idx], ball_radius * (0.3 + 0.7 * alpha), rainbow_col)

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

func clear_all() -> void:
	ball_trails.clear()
	phantom_ghosts.clear()
	phantom_spawn_timers.clear()
