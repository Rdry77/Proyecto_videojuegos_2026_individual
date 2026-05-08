extends CharacterBody2D


@export var SPEED_NORMAL = 250.0
@export var SPEED_ATTACK = 550.0
@export var SPEED_DIAGONAL = 900.0
@export var JUMP_FORCE = -600.0
@export var ATTACK_COOLDOWN = 3.5     # Tiempo entre decisiones de ataque
@export var TURN_DELAY = 1.0          # Retraso para girar (1 segundo)

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
# Asegúrate de que tu nodo jugador se llame "Player" en la escena
@onready var player = get_tree().root.find_child("Player", true, false)

# --- variables de estado ---
var current_state = "NORMAL"
var attack_timer = 2.0
var turn_timer = 0.0
var last_direction = -1
var strike_done = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor() and current_state != "AIR_ATTACK":
		velocity += get_gravity() * delta

	# --- Estados ---
	match current_state:
		"NORMAL":
			perseguir_con_retraso(delta)
			controlar_temporizador_ataques(delta)
		"EMBESTIDA":
			logica_embestida(delta)
		"AIR_ATTACK":
			logica_picado_aereo()
		"PRE_JUMP":
			# Mientras sube, frenamos un poco el movimiento horizontal
			velocity.x = move_toward(velocity.x, 0, 5.0)
			if velocity.y > 0: # Si empieza a caer y no ha atacado, vuelve a normal
				current_state = "NORMAL"

	move_and_slide()
	gestionar_animaciones()
	
	
# --- Comportamiento de seguimiento ---
func perseguir_con_retraso(delta: float):
	if not player: return
	
	var diff = player.global_position.x - global_position.x
	var current_player_side = sign(diff)
	
	# Lógica de retraso de 1 segundo para girar
	if current_player_side != last_direction and current_player_side != 0:
		turn_timer += delta
		if turn_timer >= TURN_DELAY:
			last_direction = current_player_side
			turn_timer = 0.0
	else:
		turn_timer = 0.0

	# Movimiento horizontal simple
	if abs(diff) > 30:
		velocity.x = last_direction * SPEED_NORMAL
	else:
		velocity.x = 0

# --- Comportamiento de ataque ---
func controlar_temporizador_ataques(delta: float):
	attack_timer -= delta
	if attack_timer <= 0:
		var decision = randf()
		if decision < 0.4:
			iniciar_ataque_aereo()
		elif decision < 0.7:
			iniciar_embestida_tierra()
		
		attack_timer = ATTACK_COOLDOWN

func iniciar_embestida_tierra():
	if is_on_floor():
		current_state = "EMBESTIDA"
		strike_done = false
		print("¡Enemigo inicia embestida terrestre!")
		
	
func iniciar_ataque_aereo():
	if not is_on_floor(): return
	current_state = "PRE_JUMP"
	velocity.y = JUMP_FORCE
	strike_done = false
	
	# Pausa en el aire antes del picado
	await get_tree().create_timer(0.5).timeout
	
	if player and current_state == "PRE_JUMP":
		current_state = "AIR_ATTACK"
		# Vector directo al Player
		var target_dir = (player.global_position - global_position).normalized()
		velocity = target_dir * SPEED_DIAGONAL
		last_direction = sign(target_dir.x)
		print("¡PICADO DIAGONAL!")

func logica_embestida(_delta: float):
	if not player: return
	
	# 1. MOVIMIENTO: Si ya empezó la animación de ataque, frenamos un poco para que se vea el golpe
	if animated_sprite_2d.animation == "attackEnemy":
		velocity.x = move_toward(velocity.x, 0, 15.0)
	else:
		velocity.x = last_direction * SPEED_ATTACK
	
	# 2. DETECCIÓN POR DISTANCIA
	var distancia = abs(player.global_position.x - global_position.x)
	if distancia < 80.0: # Aumenté un poco el rango para dar tiempo a la animación
		if animated_sprite_2d.animation != "attackEnemy":
			animated_sprite_2d.play("attackEnemy")
			print("¡Iniciando animación de ataque terrestre!")

	# 3. DETECCIÓN POR COLISIÓN (DAÑO)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().name == "Player" and not strike_done:
			print("¡COLISIÓN TERRESTRE! - Daño al Player detectado")
			strike_done = true
	
	# 4. CONDICIÓN DE FINALIZACIÓN CORREGIDA
	# Solo finaliza si ya pasó el peligro y la animación terminó (o si no está atacando ya)
	if animated_sprite_2d.animation == "attackEnemy" and not animated_sprite_2d.is_playing():
		finalizar_ataque()
		
	if is_on_wall(): 
		finalizar_ataque()

func logica_picado_aereo():
	# 1. Si toca el suelo antes de alcanzar al Player, el ataque termina
	if is_on_floor():
		finalizar_ataque()
		return

	if player:
		var distancia = global_position.distance_to(player.global_position)
		
		# 2. CAMBIO DE ANIMACIÓN POR CERCANÍA
		# Solo si está a menos de 150 píxeles (puedes ajustar este número)
		if distancia < 150.0:
			if animated_sprite_2d.animation != "attackEnemy":
				animated_sprite_2d.play("attackEnemy")
				print("¡Enemigo lo suficientemente cerca, iniciando animación de ataque!")

	# 3. DETECCIÓN DE COLISIÓN (DAÑO)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().name == "Player" and not strike_done:
			print("¡EL PLAYER RECIBIÓ IMPACTO DIAGONAL!")
			strike_done = true
			# Opcional: puedes hacer que el ataque termine justo al golpear
			# finalizar_ataque()
		
func finalizar_ataque():
	current_state = "NORMAL"
	attack_timer = ATTACK_COOLDOWN
	
	
func gestionar_animaciones():
	# REGLA DE ORO: Si ya estamos reproduciendo el ataque, NO HACER NADA MÁS
	# Esto evita que 'enemyRun' o 'enemyStatic' interrumpan el golpe.
	if animated_sprite_2d.animation == "attackEnemy" and animated_sprite_2d.is_playing():
		animated_sprite_2d.flip_h = (last_direction == -1)
		return # <--- IMPORTANTE: Salimos de la función aquí

	# REGLA 2: Si el estado es de ataque pero la animación no ha empezado, la forzamos
	if (current_state == "EMBESTIDA" or current_state == "AIR_ATTACK"):
		var distancia = global_position.distance_to(player.global_position)
		# Si ya estamos muy cerca, aseguramos que se quede en attackEnemy
		if distancia < 100.0:
			if animated_sprite_2d.animation != "attackEnemy":
				animated_sprite_2d.play("attackEnemy")
			animated_sprite_2d.flip_h = (last_direction == -1)
			return

	# REGLA 3: Si estamos en el aire (Picado), usamos el salto
	if not is_on_floor():
		animated_sprite_2d.play("enemyJump")
		animated_sprite_2d.flip_h = (last_direction == 1)
	
	# REGLA 4: Movimiento normal en suelo
	else:
		if abs(velocity.x) > 10:
			animated_sprite_2d.play("enemyRun")
			animated_sprite_2d.flip_h = (last_direction == 1)
			# Velocidad de animación rápida en embestida
			animated_sprite_2d.speed_scale = 2.0 if current_state == "EMBESTIDA" else 1.0
		else:
			animated_sprite_2d.play("enemyStatic")
			animated_sprite_2d.speed_scale = 1.0
