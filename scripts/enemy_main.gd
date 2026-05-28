extends CharacterBody2D


@export var SPEED_NORMAL = 350.0 # Más rápido
@export var SPEED_ATTACK = 700.0 # Embestida letal
@export var SPEED_DIAGONAL = 1000.0 
@export var JUMP_FORCE = -700.0
@export var ATTACK_COOLDOWN = 1.5 # Ataca muy seguido
@export var TURN_DELAY = 0.2     # Gira casi instantáneamente

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var player = get_tree().root.find_child("Player", true, false)

# --- ESTADOS ---
var current_state = "NORMAL"
var attack_timer = 1.0
var turn_timer = 0.0
var last_direction : float = -1.0 
var vida = 3
var esta_herido = false
var esta_muerto = false

func _init():
	last_direction = -1.0

func _physics_process(delta: float) -> void:
	if not is_on_floor() and current_state != "AIR_ATTACK":
		velocity += get_gravity() * delta

	if esta_muerto:
		velocity.x = move_toward(velocity.x, 0, 10.0)
	elif esta_herido:
		velocity.x = move_toward(velocity.x, 0, 15.0)
	else:
		if current_state == "NORMAL":
			controlar_temporizador_ataques(delta)
			perseguir_veloz(delta)
		match current_state:
			"EMBESTIDA": logica_embestida()
			"AIR_ATTACK": logica_picado_aereo()
			"PRE_JUMP":
				velocity.x = move_toward(velocity.x, 0, 5.0)
				if velocity.y > 0: current_state = "NORMAL"

	move_and_slide()
	gestionar_animaciones()

func perseguir_veloz(delta: float):
	if not player: return
	var diff = player.global_position.x - global_position.x
	var current_player_side = sign(diff)
	
	# Giro casi inmediato
	if current_player_side != last_direction and current_player_side != 0:
		turn_timer += delta
		if turn_timer >= TURN_DELAY:
			last_direction = current_player_side
			turn_timer = 0.0
	
	velocity.x = last_direction * SPEED_NORMAL if abs(diff) > 40 else 0.0

func controlar_temporizador_ataques(delta: float):
	attack_timer -= delta
	if attack_timer <= 0:
		if global_position.distance_to(player.global_position) < 300:
			if randf() < 0.6: iniciar_ataque_aereo()
			else: iniciar_embestida_tierra()
		attack_timer = ATTACK_COOLDOWN

func iniciar_ataque_aereo():
	if not is_on_floor(): return
	current_state = "PRE_JUMP"
	velocity.y = JUMP_FORCE
	await get_tree().create_timer(0.3).timeout
	if player and current_state == "PRE_JUMP":
		current_state = "AIR_ATTACK"
		var target_dir = (player.global_position - global_position).normalized()
		velocity = target_dir * SPEED_DIAGONAL
		last_direction = sign(target_dir.x)

func iniciar_embestida_tierra():
	if is_on_floor():
		current_state = "EMBESTIDA"

func logica_embestida():
	if not player: return
	if animated_sprite_2d.animation == "attackEnemyMain":
		velocity.x = move_toward(velocity.x, 0, 20.0)
	else:
		velocity.x = last_direction * SPEED_ATTACK

	if abs(player.global_position.x - global_position.x) < 120.0:
		if animated_sprite_2d.animation != "attackEnemyMain": 
			animated_sprite_2d.play("attackEnemyMain")
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i).get_collider()
		if col.name == "Player":
			if col.has_method("recibir_daño_enemigo"):
				col.recibir_daño_enemigo(last_direction)
			finalizar_ataque()
	
	if animated_sprite_2d.animation == "attackEnemyMain" and not animated_sprite_2d.is_playing():
		finalizar_ataque()
		
func finalizar_ataque():
	current_state = "NORMAL"
	attack_timer = ATTACK_COOLDOWN
	
func recibir_golpe(direccion_ataque: float):
	if esta_herido or esta_muerto: return 
	vida -= 1
	if vida <= 0:
		morir_jefe(direccion_ataque)
		return
	esta_herido = true
	animated_sprite_2d.play("mainEnemyH")
	animated_sprite_2d.flip_h = (direccion_ataque == 1) 
	velocity.x = direccion_ataque * 800.0 # Menos retroceso (es pesado)
	await get_tree().create_timer(0.3).timeout
	esta_herido = false

func morir_jefe(dir: float):
	esta_muerto = true
	animated_sprite_2d.play("mainEnemyLose")
	animated_sprite_2d.flip_h = (dir == -1)
	print("¡EL JEFE FINAL HA CAÍDO!")

func logica_picado_aereo():
	if is_on_floor(): finalizar_ataque()
	for i in get_slide_collision_count():
		var col = get_slide_collision(i).get_collider()
		if col.name == "Player":
			if col.has_method("recibir_daño_enemigo"):
				col.recibir_daño_enemigo(sign(velocity.x))
			finalizar_ataque() 


func gestionar_animaciones():
	if esta_muerto or esta_herido: return

	# --- LÓGICA DE ATAQUE ---
	if animated_sprite_2d.animation == "attackEnemyMain" and animated_sprite_2d.is_playing():
		# Si mira a la DERECHA originalmente:
		# Para mirar a la IZQUIERDA (last_direction == -1), flip_h debe ser TRUE.
		animated_sprite_2d.flip_h = (last_direction == -1) 
		return 

	# --- LÓGICA DE MOVIMIENTO ---
	if not is_on_floor():
		animated_sprite_2d.play("mainEnemyJump")
		# Si salta mirando a la IZQUIERDA originalmente:
		# Para mirar a la DERECHA (last_direction == 1), flip_h debe ser TRUE.
		animated_sprite_2d.flip_h = (last_direction == 1) 
	else:
		if abs(velocity.x) > 10:
			animated_sprite_2d.play("mainEnemyRun")
			# Si corre mirando a la IZQUIERDA originalmente:
			animated_sprite_2d.flip_h = (last_direction == 1) 
		else:
			animated_sprite_2d.play("mainEnemyStatic")
			animated_sprite_2d.flip_h = (last_direction == 1)
