extends Control

# Pon aquí la ruta exacta de tu escena principal de juego
# Puedes arrastrar el archivo de tu nivel desde el sistema de archivos hasta aquí
@export var ESCENA_PRINCIPAL : String = "res://scenes/main.tscn" 

@onready var boton_iniciar: Button = $VBoxContainer/BotonIniciar
@onready var boton_salir: Button = $VBoxContainer/BotonSalir

func _ready() -> void:
	# Conectamos las señales "pressed" de los botones por código
	boton_iniciar.pressed.connect(_on_iniciar_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)

func _on_iniciar_pressed() -> void:
	# Cambia la escena actual por la del nivel principal
	var error = get_tree().change_scene_to_file(ESCENA_PRINCIPAL)
	
	if error != OK:
		print("Error al cargar la escena principal. Revisa la ruta de ESCENA_PRINCIPAL.")

func _on_salir_pressed() -> void:
	# Cierra el juego por completo
	get_tree().quit()
