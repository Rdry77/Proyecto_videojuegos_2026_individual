extends CharacterBody2D

# --- REFERENCIAS Y ESCENAS ---
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var boquilla: Marker2D = $Boquilla 

const BALA_SCENE = preload("res://scenes/bullet.tscn") 

# --- CONSTANTES DE MOVIMIENTO ---
const SPEED = 300.0
const JUMP_VELOCITY = -600.0
const ATTACK_IMPULSE = 700.0
const DIAGONAL_IMPULSE_Y = 600.0 # Fuerza hacia abajo

# --- VARIABLES DE ESTADO ---
var is_attacking = false

func _physics_process(delta: float) -> void:
	# --- GRAVEDAD ---
	# No aplicamos gravedad extra mientras atacamos para no alterar el trayecto diagonal
	if not is_on_floor() and not is_attacking:
		velocity += get_gravity() * delta

	# --- MANEJO DE ENTRADAS ---
	if Input.is_action_just_pressed("attack") and not is_attacking:
		ejecutar_ataque()
	
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY
		animated_sprite_2d.play("jump") 
		
	if Input.is_action_just_pressed("shoot") and not is_attacking:
		disparar()
		animated_sprite_2d.play("Shoot")

	# --- MOVIMIENTO Y VOLTEO ---
	var direction := Input.get_axis("left", "right")
	
	if not is_attacking:
		if direction:
			velocity.x = direction * SPEED
			if direction > 0:
				animated_sprite_2d.flip_h = false
				boquilla.position.x = abs(boquilla.position.x)
			elif direction < 0:
				animated_sprite_2d.flip_h = true
				boquilla.position.x = -abs(boquilla.position.x)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		# Fricción durante el ataque
		# Si es en el aire (attackDiag), casi no hay fricción hasta tocar suelo
		var friction = 2.0 if animated_sprite_2d.animation == "attackDiag" else 15.0
		velocity.x = move_toward(velocity.x, 0, friction)
		
		# Si toca el suelo durante el ataque diagonal, frenamos el impacto Y
		if is_on_floor():
			velocity.y = 0

	move_and_slide()
	gestionar_animaciones()

func gestionar_animaciones():
	# Prioridad de ataques
	if is_attacking:
		# Verificamos si cualquiera de las dos animaciones de ataque sigue activa
		if (animated_sprite_2d.animation == "attack" or animated_sprite_2d.animation == "attackDiag") and animated_sprite_2d.is_playing():
			return
		else:
			is_attacking = false

	# Prioridad de disparo
	if animated_sprite_2d.animation == "Shoot" and animated_sprite_2d.is_playing():
		return

	# Resto de estados (suelo/aire)
	if is_on_floor():
		if velocity.x != 0:
			animated_sprite_2d.play("run-r")
		else:
			animated_sprite_2d.play("static-r")
	else:
		if animated_sprite_2d.animation != "jump":
			animated_sprite_2d.play("static-r")

# --- FUNCIONES DE ACCIÓN ---

func ejecutar_ataque():
	is_attacking = true
	var dir = -1 if animated_sprite_2d.flip_h else 1
	
	if not is_on_floor():
		# --- ATAQUE DIAGONAL ---
		animated_sprite_2d.play("attackDiag")
		velocity.x = dir * ATTACK_IMPULSE * 1.2
		velocity.y = DIAGONAL_IMPULSE_Y
	else:
		# --- ATAQUE NORMAL ---
		animated_sprite_2d.play("attack")
		velocity.x = dir * ATTACK_IMPULSE

func disparar():
	var nueva_bala = BALA_SCENE.instantiate()
	var dir = -1 if animated_sprite_2d.flip_h else 1
	nueva_bala.set_direction(dir)
	nueva_bala.global_position = boquilla.global_position
	get_tree().root.add_child(nueva_bala)
