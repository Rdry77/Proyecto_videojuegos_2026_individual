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
var esta_herido = false
var esta_muerto = false

func _physics_process(delta: float) -> void:
	if not is_on_floor() and current_state != "AIR_ATTACK":
		velocity += get_gravity() * delta

	if esta_muerto:
		velocity.x = move_toward(velocity.x, 0, 10.0)
	elif esta_herido:
		velocity.x = move_toward(velocity.x, 0, 15.0)

	move_and_slide()
