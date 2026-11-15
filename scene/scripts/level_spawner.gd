extends Node2D

const YOUKAI_SCENE = preload("res://entities/youkai.tscn")
const HEALTH_HUD_SCRIPT = preload("res://scene/scripts/health_hud.gd")
const SPAWN_POSITIONS = [
	Vector2(170, 64),
	Vector2(310, 64),
	Vector2(460, 64),
	Vector2(570, 64),
	Vector2(650, 64),
	Vector2(780, 64),
	Vector2(920, 64),
	Vector2(1060, 64),
	Vector2(1160, 64),
]
const YOUKAI_TYPES = [
	"Gotoku", "Gotoku", "Onre", "Gotoku", "Yurei",
	"Onre", "Gotoku", "Onre", "Yurei",
]
const RANGED_YOUKAI = [false, false, false, false, false, true, false, true, false]

@onready var player: CharacterBody2D = $player


func _ready() -> void:
	var hud_layer := CanvasLayer.new()
	var health_hud := Node2D.new()
	hud_layer.name = "HUD"
	health_hud.set_script(HEALTH_HUD_SCRIPT)
	health_hud.position = Vector2(8.0, 8.0)
	hud_layer.add_child(health_hud)
	add_child(hud_layer)
	player.health_changed.connect(_update_health_label.bind(health_hud))
	_update_health_label(player.get_max_health(), player.get_max_health(), health_hud)

	for index in range(SPAWN_POSITIONS.size()):
		var youkai := YOUKAI_SCENE.instantiate()
		youkai.position = SPAWN_POSITIONS[index]
		youkai.set_youkai_type(YOUKAI_TYPES[index])
		youkai.set_ranged(RANGED_YOUKAI[index])
		add_child(youkai)
		youkai.set_player(player)


func _update_health_label(current_health: int, maximum_health: int, health_hud: Node2D) -> void:
	health_hud.call("update_health", current_health, maximum_health)
