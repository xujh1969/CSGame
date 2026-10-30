extends Node3D
## Sample-only atmosphere. Visual smoke never changes damage/LOS queries.

var particles: Array[CPUParticles3D] = []
var environment: Environment
var flame_light: OmniLight3D
var low_quality := false
var elapsed := 0.0

func _ready() -> void:
	var level := get_parent().get_parent()
	environment = level.get_node("WorldEnvironment").environment
	_smoke(Vector3(-3.2, .95, -16.8), 28, 8, 1.9, Color(.24, .22, .19, .45))
	_smoke(Vector3(-3.0, 8, -28), 32, 10, 4.2, Color(.20, .19, .17, .55))
	_smoke(Vector3(0, 1.7, -9.2), 26, 12, .10, Color(.80, .72, .60, .16), true)
	_fire(Vector3(-3.15, .8, -16.8))
	level.get_node("BattlePresentation").quality_changed.connect(set_low_quality)
	set_low_quality(false)

func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, .3, 1])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, .75), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5, .5)
	texture.fill_to = Vector2(1, .5)
	texture.gradient = gradient
	return texture

func _emitter(position_value: Vector3, amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.position = position_value
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.preprocess = lifetime
	emitter.local_coords = false
	emitter.use_fixed_seed = true
	emitter.seed = 20261029 + particles.size()
	emitter.direction = Vector3.UP
	emitter.spread = 22
	emitter.gravity = Vector3(.06, .05, 0)
	emitter.initial_velocity_min = .45
	emitter.initial_velocity_max = .9
	emitter.scale_amount_min = .6
	emitter.scale_amount_max = 1.4
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = size * .15
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * 1.2)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _radial_texture()
	material.no_depth_test = false
	quad.material = material
	emitter.mesh = quad
	particles.append(emitter)
	add_child(emitter)
	return emitter

func _smoke(position_value: Vector3, amount: int, lifetime: float, size: float, color: Color, dust := false) -> void:
	var emitter := _emitter(position_value, amount, lifetime, size)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0, .2, .75, 1])
	ramp.colors = PackedColorArray([Color(color, 0), color, Color(color, color.a * .6), Color(color, 0)])
	emitter.color_ramp = ramp
	var growth := Curve.new()
	growth.add_point(Vector2(0, .3))
	growth.add_point(Vector2(1, 1.6))
	emitter.scale_amount_curve = growth
	if dust:
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(3, 1.2, 10)
		emitter.direction = Vector3(.8, .1, -.2)
		emitter.gravity = Vector3.ZERO
		emitter.initial_velocity_min = .08
		emitter.initial_velocity_max = .2
	else:
		var material := emitter.mesh.material as StandardMaterial3D
		material.albedo_texture = load("res://assets/textures/task008/smoke_puff_v001.png")

func _fire(position_value: Vector3) -> void:
	var emitter := _emitter(position_value, 9, .8, .55)
	emitter.initial_velocity_min = .7
	emitter.initial_velocity_max = 1.4
	emitter.spread = 12
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, .53, .12, .85), Color(.65, .10, .01, 0)])
	emitter.color_ramp = ramp
	var material := emitter.mesh.material as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color(1, .25, .025)
	material.emission_energy_multiplier = 2
	flame_light = OmniLight3D.new()
	flame_light.position = position_value + Vector3.UP * .5
	flame_light.light_color = Color(1, .35, .08)
	flame_light.light_energy = 1.2
	flame_light.omni_range = 3.5
	flame_light.shadow_enabled = false
	add_child(flame_light)

func set_low_quality(low: bool) -> void:
	low_quality = low
	environment.volumetric_fog_enabled = not low
	environment.glow_enabled = not low
	for emitter in particles:
		emitter.emitting = not low
		emitter.visible = not low
		emitter.process_mode = Node.PROCESS_MODE_DISABLED if low else Node.PROCESS_MODE_INHERIT
	flame_light.visible = not low
	set_process(not low)

func _process(delta: float) -> void:
	elapsed += delta
	flame_light.light_energy = 1.1 + .12 * sin(elapsed * 13) + .08 * sin(elapsed * 29)
