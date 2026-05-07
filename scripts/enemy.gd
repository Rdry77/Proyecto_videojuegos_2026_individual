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


	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED_NORMAL
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED_NORMAL)

	move_and_slide()
