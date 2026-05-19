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
var last_direction : float = -1.0 
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
			pass
		match current_state:
			"EMBESTIDA": logica_embestida()
			"AIR_ATTACK": logica_picado_aereo()
			"PRE_JUMP":
				velocity.x = move_toward(velocity.x, 0, 5.0)
				if velocity.y > 0: current_state = "NORMAL"

	move_and_slide()

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
	pass
	
func logica_picado_aereo():
	pass 
