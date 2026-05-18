extends CharacterBody2D

@onready var ataque_area_collision: CollisionShape2D = $AtaqueArea/CollisionShape2D

# --- REFERENCIAS Y ESCENAS ---
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var boquilla: Marker2D = $Boquilla 

# --- VARIABLES DE SALUD ---
var salud_max = 5
var salud_actual = 5
@onready var health_bar: ProgressBar = get_tree().root.find_child("ProgressBar", true, false)
@onready var game_over_label: Label = get_tree().root.find_child("GameOverLabel", true, false)

# --- VARIABLES DE DIÁLOGO ---
@onready var panel_dialogo = get_tree().root.find_child("PanelDialogo", true, false)
@onready var label_texto = get_tree().root.find_child("TextoDialogo", true, false)

var frases_finales = [
	"¡Increíble! Has derrotado a todas las amenazas de este sector.",
	"Pero no te confíes... esto es solo el principio de la invasión.",
	"Prepárate, el verdadero desafío comienza ahora."
]
var indice_frase = 0
var dialogo_activo = false

const BALA_SCENE = preload("res://scenes/bullet.tscn") 

# --- CONSTANTES DE MOVIMIENTO ---
const SPEED = 300.0
const JUMP_VELOCITY = -600.0
const ATTACK_IMPULSE = 700.0
const DIAGONAL_IMPULSE_Y = 600.0 # Fuerza hacia abajo

# --- VARIABLES DE ESTADO ---
var is_attacking = false
var esta_cayendo = false

func _ready():
	# Inicializar barra
	if health_bar:
		health_bar.max_value = salud_max
		health_bar.value = salud_actual
	if game_over_label:
		game_over_label.visible = false
	# Nos aseguramos de que el área esté apagada al empezar
	ataque_area_collision.disabled = true
	
	if panel_dialogo: panel_dialogo.visible = false

func _physics_process(delta: float) -> void:
	
	if esta_cayendo:
		move_and_slide() # Para que se aplique el empuje
		return
	
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
	if esta_cayendo:
		animated_sprite_2d.play("fall")
		return # No procesa nada más mientras cae
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
			if esta_cayendo == false:
				animated_sprite_2d.play("static-r")
	else:
		if animated_sprite_2d.animation != "jump" and esta_cayendo == false:
			animated_sprite_2d.play("fall") # o static-r

# --- FUNCIONES DE ACCIÓN ---

func ejecutar_ataque():
	is_attacking = true
	var dir = -1 if animated_sprite_2d.flip_h else 1
	
	# ACTIVAR DAÑO
	ataque_area_collision.disabled = false 
	
	if not is_on_floor():
		# --- ATAQUE DIAGONAL ---
		animated_sprite_2d.play("attackDiag")
		velocity.x = dir * ATTACK_IMPULSE * 1.2
		velocity.y = DIAGONAL_IMPULSE_Y
	else:
		# --- ATAQUE NORMAL ---
		animated_sprite_2d.play("attack")
		velocity.x = dir * ATTACK_IMPULSE
	
	# Temporizador para apagar el área (ajusta el tiempo a la duración de tu animación)
	await get_tree().create_timer(0.3).timeout
	ataque_area_collision.disabled = true

func disparar():
	var nueva_bala = BALA_SCENE.instantiate()
	var dir = -1 if animated_sprite_2d.flip_h else 1
	nueva_bala.set_direction(dir)
	nueva_bala.global_position = boquilla.global_position
	get_tree().root.add_child(nueva_bala)
	
func recibir_daño_enemigo(direccion_ataque_enemigo: float):
	if esta_cayendo or salud_actual <= 0: return
	
	# Reducir salud
	salud_actual -= 1
	if health_bar:
		health_bar.value = salud_actual
	
	# Verificar muerte
	if salud_actual <= 0:
		morir_player()
		return
	
	esta_cayendo = true
	is_attacking = false
	animated_sprite_2d.play("fall")
	velocity.x = direccion_ataque_enemigo * 500.0
	velocity.y = -300.0
	
	await get_tree().create_timer(0.6).timeout
	esta_cayendo = false

func morir_player():
	esta_cayendo = true
	animated_sprite_2d.play("fall") # O una animación de muerte si tienes
	if game_over_label:
		game_over_label.visible = true
	
	print("Game Over")
	
func _on_ataque_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemigos"):
		var dir_empuje = -1 if animated_sprite_2d.flip_h else 1
		if body.has_method("recibir_golpe"):
			body.recibir_golpe(dir_empuje)
