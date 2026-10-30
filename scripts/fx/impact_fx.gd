extends Node3D

var kind: StringName
var age := 0.0
var duration := 0.6
var normal := Vector3.UP

func _ready() -> void:
	var smoke := kind == &"smoke"
	var sparks := kind in [&"metal", &"hit"]
	duration = 0.25 if sparks else 0.6
	var particles := CPUParticles3D.new()
	particles.amount = 7 if sparks else 5
	particles.lifetime = duration
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.direction = normal
	particles.spread = 35.0
	particles.gravity = Vector3(0, 0.3 if smoke else -0.8, 0)
	particles.initial_velocity_min = 1.0 if sparks else 0.15
	particles.initial_velocity_max = 2.5 if sparks else 0.7
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1, 0.8, 0.3, 0.9) if sparks else Color(0.62, 0.59, 0.53, 0.32)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.035 if sparks else 0.16)
	quad.material = material
	particles.mesh = quad
	add_child(particles)
	particles.emitting = true

func _process(delta: float) -> void:
	age += delta
	if age > duration + 0.1:
		queue_free()
