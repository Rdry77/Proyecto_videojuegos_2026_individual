extends CharacterBody2D

@export var speed = 700.0
var direction = 1 

func _physics_process(delta: float) -> void:
	# Movimiento constante
	var velocity_vector = Vector2(speed * direction * delta, 0)
	var collision = move_and_collide(velocity_vector)
	
	if collision:
		queue_free()

func set_direction(dir):
	direction = dir
	
	# Usamos get_node para buscarlo directamente. 
	
	var sprite = get_node_or_null("Sprite2D")
	
	if sprite:
		sprite.flip_h = (dir < 0)
	else:
		# Si sigue fallando, imprimimos la ruta para saber dónde quedó el nodo
		print("No encontré el Sprite2D. Revisa la jerarquía de la escena.")

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
