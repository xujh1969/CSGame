extends StaticBody3D

@onready var health = $HealthComponent
@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	mesh.material_override = mesh.material_override.duplicate()
	health.health_changed.connect(_update_health)
	_update_health(health.current_health, health.max_health)

func _update_health(current: int, maximum: int) -> void:
	label.text = "%s\n%d / %d" % [name, current, maximum]
	mesh.material_override.albedo_color = Color(0.15, 0.15, 0.15) if current <= 0 else Color(0.05, 0.8, 0.9)
	if current <= 0:
		label.text = "%s\nDOWN - reset to restore" % name
