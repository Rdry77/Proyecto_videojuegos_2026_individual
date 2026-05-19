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

# --- VARIABLES DE VIDA
var vida = 3
var esta_herido = false
var esta_muerto = false
static var enemigos_totales_creados = 1
var limite_enemigos = 4

func _init():
	last_direction = -1.0

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
			logica_embestida()
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
		var dist_al_player = global_position.distance_to(player.global_position)
		if dist_al_player < 800:
			var decision = randf()
			if decision < 0.4:
				iniciar_ataque_aereo()
			else:
				iniciar_embestida_tierra()
		
		attack_timer = ATTACK_COOLDOWN

func iniciar_embestida_tierra():
	if is_on_floor():
		current_state = "EMBESTIDA"
		strike_done = false
		animated_sprite_2d.play("enemyRun") 

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

func logica_embestida():
	if not player: return
	
	if animated_sprite_2d.animation == "attackEnemy":
		velocity.x = move_toward(velocity.x, 0, 15.0)
	else:
		velocity.x = last_direction * SPEED_ATTACK
	
	var distancia = abs(player.global_position.x - global_position.x)
	# Activar animación de ataque al estar cerca
	if distancia < 100.0 and animated_sprite_2d.animation != "attackEnemy":
		animated_sprite_2d.play("attackEnemy")
	
	# Detectar colisión con Player para terminar
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider().name == "Player":
			finalizar_ataque()
	
	# 4. CONDICIÓN DE FINALIZACIÓN CORREGIDA
	# Solo finaliza si ya pasó el peligro y la animación terminó (o si no está atacando ya)
	if animated_sprite_2d.animation == "attackEnemy" and not animated_sprite_2d.is_playing():
		finalizar_ataque()
		
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var objeto = col.get_collider()
		
		if objeto.name == "Player":
			if objeto.has_method("recibir_daño_enemigo"):
				# Le pasamos 'last_direction' para saber hacia dónde empujarlo
				objeto.recibir_daño_enemigo(last_direction)
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
	

func recibir_golpe(direccion_ataque: float):
	vida -= 1
	if vida <= 0:
		morir(direccion_ataque)
		return
	
	esta_herido = true
	velocity.y = -150.0
	velocity.x = direccion_ataque * 600.0 
	animated_sprite_2d.play("enemyH")
	animated_sprite_2d.flip_h = (direccion_ataque == 1)
	await get_tree().create_timer(0.4).timeout
	esta_herido = false
	current_state = "NORMAL"
	last_direction = -sign(direccion_ataque) 

func morir(direccion_ataque: float):
	esta_muerto = true
	velocity.x = direccion_ataque * 400.0
	velocity.y = -200.0
	animated_sprite_2d.play("enemyLose")
	animated_sprite_2d.flip_h = (direccion_ataque == 1)
	
	# Si es el último enemigo, avisamos al sistema de diálogos
	if enemigos_totales_creados == limite_enemigos:
		# Buscamos el nodo que maneja los diálogos (usualmente el Player o un Manager)
		if player and player.has_method("iniciar_dialogo_final"):
			player.iniciar_dialogo_final()
	
	await get_tree().create_timer(0.5).timeout
	if enemigos_totales_creados < limite_enemigos:
		reaparecer_enemigo()
	queue_free()

func reaparecer_enemigo():
	var nuevo_enemigo = load(self.scene_file_path).instantiate()
	nuevo_enemigo.global_position = Vector2(player.global_position.x + 1300, player.global_position.y - 50)
	enemigos_totales_creados += 1
	get_parent().add_child(nuevo_enemigo)

func gestionar_animaciones():
	if esta_muerto:
		animated_sprite_2d.play("enemyLose")
		return
	
	if esta_herido:
		animated_sprite_2d.play("enemyH")
		return
	
	if animated_sprite_2d.animation == "attackEnemy" and animated_sprite_2d.is_playing():
		animated_sprite_2d.flip_h = (last_direction == -1)
		return # <--- IMPORTANTE: Salimos de la función aquí

	
	if (current_state == "EMBESTIDA" or current_state == "AIR_ATTACK"):
		var distancia = global_position.distance_to(player.global_position)
		# Si ya estamos muy cerca, aseguramos que se quede en attackEnemy
		if distancia < 100.0:
			if animated_sprite_2d.animation != "attackEnemy":
				animated_sprite_2d.play("attackEnemy")
			animated_sprite_2d.flip_h = (last_direction == -1)
			return

	if not is_on_floor():
		animated_sprite_2d.play("enemyJump")
		# Si el salto sale de espaldas, cambia '==' por '!='
		animated_sprite_2d.flip_h = (last_direction == 1)
	else:
		if abs(velocity.x) > 10:
			animated_sprite_2d.play("enemyRun")
			# USAMOS UNA LÓGICA DIFERENTE PARA CORRER
			# Si 'last_direction == -1' (izquierda) lo hace correr de reversa, 
			# cámbialo por 'last_direction == 1'
			animated_sprite_2d.flip_h = (last_direction == 1) 
			
			animated_sprite_2d.speed_scale = 2.0 if current_state == "EMBESTIDA" else 1.0
		else:
			animated_sprite_2d.play("enemyStatic")
			# Para que al estar quieto mire al último lado al que caminó
			animated_sprite_2d.flip_h = (last_direction == 1)
			animated_sprite_2d.speed_scale = 1.0
